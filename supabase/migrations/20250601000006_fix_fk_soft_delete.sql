-- ============================================================
-- MIGRATION: 20250601000006_fix_fk_soft_delete.sql
-- DESCRIÇÃO: Correção FK para permitir soft delete e block de hard delete
-- ============================================================

-- Alterar FK para não bloquear soft delete (ou hard delete se fosse o caso)
ALTER TABLE frequencias_historico_status
DROP CONSTRAINT IF EXISTS frequencias_historico_status_frequencia_id_fkey;

ALTER TABLE frequencias_historico_status
ADD CONSTRAINT frequencias_historico_status_frequencia_id_fkey
FOREIGN KEY (frequencia_id)
REFERENCES frequencias(id)
ON DELETE CASCADE;

-- Garantir que soft delete em frequencias apenas seta deleted_at, nunca hard deleta
CREATE OR REPLACE FUNCTION fn_block_hard_delete_frequencias()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION
    'Hard delete não permitido em frequencias. Use soft delete (deleted_at = NOW()).';
END;
$$;

DROP TRIGGER IF EXISTS trg_block_hard_delete_frequencias ON frequencias;
CREATE TRIGGER trg_block_hard_delete_frequencias
BEFORE DELETE ON frequencias
FOR EACH ROW
EXECUTE FUNCTION fn_block_hard_delete_frequencias();
