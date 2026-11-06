-- RikaTechno Bingo V5: execute UMA VEZ no SQL Editor do projeto existente.
-- Não exclui nem apaga as rodadas em andamento.
BEGIN;
ALTER TABLE public.bingo_games ADD COLUMN IF NOT EXISTS closed boolean NOT NULL DEFAULT false;
ALTER TABLE public.bingo_games ADD COLUMN IF NOT EXISTS round_number bigint NOT NULL DEFAULT 1;
CREATE TABLE IF NOT EXISTS public.bingo_round_history (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  round_number bigint NOT NULL UNIQUE,
  mode integer NOT NULL CHECK (mode IN (75,90)),
  drawn integer[] NOT NULL,
  closed_at timestamptz NOT NULL DEFAULT now(),
  closed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  winner_name text,
  notes text,
  CONSTRAINT non_empty_draw CHECK (cardinality(drawn)>0),
  CONSTRAINT valid_draw_count CHECK (cardinality(drawn)<=mode)
);
ALTER TABLE public.bingo_round_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bingo_round_history FROM anon, authenticated;
GRANT SELECT ON public.bingo_round_history TO authenticated;
DROP POLICY IF EXISTS "Admin can read bingo history" ON public.bingo_round_history;
CREATE POLICY "Admin can read bingo history" ON public.bingo_round_history FOR SELECT TO authenticated USING (public.bingo_is_admin());
-- Só a função protegida escreve no histórico. Trava da rodada para evitar duplicações.
CREATE OR REPLACE FUNCTION public.bingo_close(winner_name text DEFAULT NULL, notes text DEFAULT NULL)
RETURNS public.bingo_games LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE g public.bingo_games;
BEGIN
  IF NOT public.bingo_is_admin() THEN RAISE EXCEPTION 'Acesso não autorizado'; END IF;
  SELECT * INTO g FROM public.bingo_games WHERE id=1 FOR UPDATE;
  IF g.closed THEN RAISE EXCEPTION 'Esta cartela já está fechada'; END IF;
  IF cardinality(g.drawn)=0 THEN RAISE EXCEPTION 'Não é possível fechar uma cartela vazia'; END IF;
  INSERT INTO public.bingo_round_history(round_number,mode,drawn,closed_by,winner_name,notes)
  VALUES (g.round_number,g.mode,g.drawn,auth.uid(),NULLIF(left(btrim(winner_name),120),''),NULLIF(left(btrim(notes),500),''));
  UPDATE public.bingo_games SET closed=true,revision=g.revision+1,updated_at=now() WHERE id=1 RETURNING * INTO g;
  RETURN g;
END; $$;
CREATE OR REPLACE FUNCTION public.bingo_new_round()
RETURNS public.bingo_games LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE g public.bingo_games;
BEGIN
  IF NOT public.bingo_is_admin() THEN RAISE EXCEPTION 'Acesso não autorizado'; END IF;
  SELECT * INTO g FROM public.bingo_games WHERE id=1 FOR UPDATE;
  IF NOT g.closed AND cardinality(g.drawn)>0 THEN
    RAISE EXCEPTION 'Feche a cartela em andamento antes de iniciar outra';
  END IF;
  UPDATE public.bingo_games SET closed=false,drawn='{}'::integer[],round_number=g.round_number+1,revision=g.revision+1,updated_at=now() WHERE id=1 RETURNING * INTO g;
  RETURN g;
END; $$;
-- Protege a função antiga, usada em sites que ainda não foram atualizados.
CREATE OR REPLACE FUNCTION public.bingo_reset() RETURNS public.bingo_games
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
 RETURN public.bingo_new_round();
END; $$;
CREATE OR REPLACE FUNCTION public.bingo_draw() RETURNS public.bingo_games
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE g public.bingo_games; n integer; pool integer[]; i integer;
BEGIN
 IF NOT public.bingo_is_admin() THEN RAISE EXCEPTION 'Acesso não autorizado'; END IF;
 SELECT * INTO g FROM public.bingo_games WHERE id=1 FOR UPDATE;
 IF g.closed THEN RAISE EXCEPTION 'Cartela fechada. Inicie uma nova cartela'; END IF;
 IF cardinality(g.drawn)>=g.mode THEN RETURN g; END IF;
 SELECT array_agg(v) INTO pool FROM generate_series(1,g.mode) v WHERE NOT(v=any(g.drawn));
 i:=1+floor(random()*cardinality(pool))::integer;
 n:=pool[i];
 UPDATE public.bingo_games SET drawn=array_append(g.drawn,n),revision=g.revision+1,updated_at=now() WHERE id=1 RETURNING * INTO g;
 RETURN g;
END; $$;
CREATE OR REPLACE FUNCTION public.bingo_set_mode(new_mode integer) RETURNS public.bingo_games
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE g public.bingo_games;
BEGIN
 IF NOT public.bingo_is_admin() THEN RAISE EXCEPTION 'Acesso não autorizado'; END IF;
 IF new_mode NOT IN (75,90) THEN RAISE EXCEPTION 'Modo inválido'; END IF;
 SELECT * INTO g FROM public.bingo_games WHERE id=1 FOR UPDATE;
 IF g.closed OR cardinality(g.drawn)>0 THEN RAISE EXCEPTION 'Só é possível mudar o modo antes de começar a cartela'; END IF;
 UPDATE public.bingo_games SET mode=new_mode,revision=g.revision+1,updated_at=now() WHERE id=1 RETURNING * INTO g;
 RETURN g;
END; $$;
REVOKE ALL ON FUNCTION public.bingo_close(text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.bingo_new_round() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bingo_close(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bingo_new_round() TO authenticated;
COMMIT;
