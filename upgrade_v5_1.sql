-- V5.1: executar DEPOIS do upgrade_v5.sql, no mesmo projeto Supabase.
-- Preserva todos os registros já existentes e não modifica a rodada ativa.
BEGIN;
ALTER TABLE public.bingo_games
 ADD COLUMN IF NOT EXISTS restored_from_history_id bigint REFERENCES public.bingo_round_history(id) ON DELETE SET NULL;
ALTER TABLE public.bingo_round_history
 ADD COLUMN IF NOT EXISTS restored_from_history_id bigint REFERENCES public.bingo_round_history(id) ON DELETE SET NULL;
CREATE TABLE IF NOT EXISTS public.bingo_reopen_log (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 source_history_id bigint NOT NULL REFERENCES public.bingo_round_history(id) ON DELETE RESTRICT,
 new_round_number bigint NOT NULL,
 previous_round_number bigint NOT NULL,
 reopened_at timestamptz NOT NULL DEFAULT now(),
 reopened_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 CONSTRAINT bingo_reopen_unique_round UNIQUE(new_round_number)
);
ALTER TABLE public.bingo_reopen_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bingo_reopen_log FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.bingo_reopen_log TO authenticated;
DROP POLICY IF EXISTS "Admin can read reopen log" ON public.bingo_reopen_log;
CREATE POLICY "Admin can read reopen log" ON public.bingo_reopen_log FOR SELECT TO authenticated USING (public.bingo_is_admin());

-- Reabre por CÓPIA: rodada antiga permanece arquivada, e a continuação recebe novo número.
-- SELECT ... FOR UPDATE impede que dois organizadores restaurem simultaneamente.
CREATE OR REPLACE FUNCTION public.bingo_reopen(source_history_id bigint)
RETURNS public.bingo_games LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE g public.bingo_games; h public.bingo_round_history; new_round bigint;
BEGIN
 IF NOT public.bingo_is_admin() THEN RAISE EXCEPTION 'Acesso não autorizado'; END IF;
 SELECT * INTO g FROM public.bingo_games WHERE id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Rodada atual não encontrada'; END IF;
 IF NOT g.closed AND cardinality(g.drawn)>0 THEN
   RAISE EXCEPTION 'Existe cartela em andamento. Feche-a antes de recuperar outra.';
 END IF;
 SELECT * INTO h FROM public.bingo_round_history WHERE id=source_history_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Cartela arquivada não encontrada'; END IF;
 IF cardinality(h.drawn)=0 OR cardinality(h.drawn)>h.mode OR
    EXISTS(SELECT 1 FROM unnest(h.drawn) n WHERE n<1 OR n>h.mode) OR
    (SELECT count(DISTINCT x) FROM unnest(h.drawn) x) <> cardinality(h.drawn) THEN
    RAISE EXCEPTION 'Cartela arquivada possui números inválidos';
 END IF;
 new_round:=g.round_number+1;
 INSERT INTO public.bingo_reopen_log(source_history_id,new_round_number,previous_round_number,reopened_by)
 VALUES(h.id,new_round,g.round_number,auth.uid());
 UPDATE public.bingo_games SET mode=h.mode,drawn=h.drawn,closed=false,
    round_number=new_round,restored_from_history_id=h.id,
    revision=g.revision+1,updated_at=now() WHERE id=1 RETURNING * INTO g;
 RETURN g;
END; $$;

-- Mantém a origem da rodada recuperada no próximo fechamento.
CREATE OR REPLACE FUNCTION public.bingo_close(winner_name text DEFAULT NULL, notes text DEFAULT NULL)
RETURNS public.bingo_games LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE g public.bingo_games;
BEGIN
 IF NOT public.bingo_is_admin() THEN RAISE EXCEPTION 'Acesso não autorizado'; END IF;
 SELECT * INTO g FROM public.bingo_games WHERE id=1 FOR UPDATE;
 IF g.closed THEN RAISE EXCEPTION 'Esta cartela já está fechada'; END IF;
 IF cardinality(g.drawn)=0 THEN RAISE EXCEPTION 'Não é possível fechar cartela vazia'; END IF;
 INSERT INTO public.bingo_round_history(round_number,mode,drawn,closed_by,winner_name,notes,restored_from_history_id)
 VALUES(g.round_number,g.mode,g.drawn,auth.uid(),NULLIF(left(btrim(winner_name),120),''),
        NULLIF(left(btrim(notes),500),''),g.restored_from_history_id);
 UPDATE public.bingo_games SET closed=true,revision=g.revision+1,updated_at=now()
 WHERE id=1 RETURNING * INTO g;
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
 UPDATE public.bingo_games SET closed=false,drawn='{}'::integer[],
   restored_from_history_id=NULL,round_number=g.round_number+1,
   revision=g.revision+1,updated_at=now() WHERE id=1 RETURNING * INTO g;
 RETURN g;
END; $$;
REVOKE ALL ON FUNCTION public.bingo_reopen(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bingo_reopen(bigint) TO authenticated;
COMMIT;
