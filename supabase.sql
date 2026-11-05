-- Execute no SQL Editor do SEU projeto Supabase (uma única vez).
-- Uma rodada compartilhada em tempo real. Admin definido por auth.users.id.
create table if not exists public.bingo_games (
  id integer primary key default 1 check (id = 1),
  mode integer not null default 75 check(mode in (75,90)),
  drawn integer[] not null default '{}'::integer[],
  revision bigint not null default 0,
  updated_at timestamptz not null default now(),
  constraint drawn_valid check (cardinality(drawn) <= mode)
);
insert into public.bingo_games(id) values(1) on conflict(id) do nothing;
create table if not exists public.bingo_admins (user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.bingo_games enable row level security;
alter table public.bingo_admins enable row level security;
revoke all on public.bingo_games from anon,authenticated;
grant select on public.bingo_games to anon,authenticated;
revoke all on public.bingo_admins from anon,authenticated;
drop policy if exists "Everyone can view bingo" on public.bingo_games;
create policy "Everyone can view bingo" on public.bingo_games for select to anon,authenticated using(true);
-- SECURITY DEFINER functions validate authenticated identity and serialize writes.
create or replace function public.bingo_is_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and exists(select 1 from public.bingo_admins where user_id = auth.uid());
$$;
create or replace function public.bingo_draw() returns public.bingo_games language plpgsql security definer set search_path = '' as $$
declare g public.bingo_games; n integer; pool integer[]; i integer;
begin
 if not public.bingo_is_admin() then raise exception 'Acesso não autorizado'; end if;
 select * into g from public.bingo_games where id=1 for update;
 if cardinality(g.drawn)>=g.mode then return g; end if;
 select array_agg(v) into pool from generate_series(1,g.mode) v where not(v=any(g.drawn));
 i := 1 + floor(random()*cardinality(pool))::int;
 n := pool[i];
 update public.bingo_games set drawn=array_append(g.drawn,n),revision=g.revision+1,updated_at=now() where id=1 returning * into g;
 return g;
end; $$;
create or replace function public.bingo_reset() returns public.bingo_games language plpgsql security definer set search_path = '' as $$
declare g public.bingo_games;
begin
 if not public.bingo_is_admin() then raise exception 'Acesso não autorizado'; end if;
 select * into g from public.bingo_games where id=1 for update;
 update public.bingo_games set drawn='{}'::integer[],revision=g.revision+1,updated_at=now() where id=1 returning * into g;
 return g;
end; $$;
create or replace function public.bingo_set_mode(new_mode integer) returns public.bingo_games language plpgsql security definer set search_path = '' as $$
declare g public.bingo_games;
begin
 if not public.bingo_is_admin() then raise exception 'Acesso não autorizado'; end if;
 if new_mode not in (75,90) then raise exception 'Modo inválido'; end if;
 select * into g from public.bingo_games where id=1 for update;
 update public.bingo_games set mode=new_mode,drawn='{}'::integer[],revision=g.revision+1,updated_at=now() where id=1 returning * into g;
 return g;
end; $$;
revoke all on function public.bingo_is_admin() from public,anon;
revoke all on function public.bingo_draw() from public,anon;
revoke all on function public.bingo_reset() from public,anon;
revoke all on function public.bingo_set_mode(integer) from public,anon;
grant execute on function public.bingo_is_admin() to authenticated;
grant execute on function public.bingo_draw() to authenticated;
grant execute on function public.bingo_reset() to authenticated;
grant execute on function public.bingo_set_mode(integer) to authenticated;
-- Realtime: habilitar tabela apenas se ainda não estiver na publicação.
do $$ begin
 if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='bingo_games') then
  alter publication supabase_realtime add table public.bingo_games;
 end if;
end $$;
-- No Supabase Authentication > Users, crie seu usuário por e-mail e senha.
-- Depois execute o comando abaixo, substituindo o e-mail:
-- insert into public.bingo_admins(user_id)
-- select id from auth.users where email = 'SEU-EMAIL@EXEMPLO.COM'
-- on conflict (user_id) do nothing;
