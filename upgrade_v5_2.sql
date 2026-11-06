-- RikaTechno Bingo V5.2 — executar DEPOIS dos upgrades V5 e V5.1.
-- Exclusão lógica: retira a cartela da lista sem apagar evidências nem
-- quebrar os vínculos de reabertura. Reversível manualmente no banco.
BEGIN;
ALTER TABLE public.bingo_round_history
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE public.bingo_round_history
  ADD COLUMN IF NOT EXISTS deleted_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.bingo_hide_history(history_id bigint)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE h public.bingo_round_history;
BEGIN
  IF NOT public.bingo_is_admin() THEN
    RAISE EXCEPTION 'Acesso não autorizado';
  END IF;
  IF history_id IS NULL THEN
    RAISE EXCEPTION 'ID da cartela obrigatório';
  END IF;

  SELECT * INTO h FROM public.bingo_round_history
  WHERE id = history_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cartela não encontrada';
  END IF;
  IF h.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'Esta cartela já foi removida do histórico';
  END IF;

  -- Uma rodada ativa pode ter sido restaurada a partir deste arquivo.
  -- Bloqueia sua remoção enquanto essa continuação ainda está aberta.
  IF EXISTS (
     SELECT 1 FROM public.bingo_games g
     WHERE g.id = 1
       AND g.restored_from_history_id = history_id
       AND NOT g.closed
  ) THEN
    RAISE EXCEPTION 'Esta cartela deu origem à rodada ativa. Feche a rodada antes de removê-la do histórico.';
  END IF;

  UPDATE public.bingo_round_history
    SET deleted_at = now(), deleted_by = auth.uid()
    WHERE id = history_id;
  RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION public.bingo_hide_history(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bingo_hide_history(bigint) TO authenticated;
COMMIT;
