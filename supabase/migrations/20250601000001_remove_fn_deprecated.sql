-- ============================================================
-- MIGRATION: 20250601000001_remove_fn_deprecated.sql
-- DESCRIÇÃO: Remoção de funções obsoletas substituídas por auth_* no v1.2
-- ============================================================

DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_depend d
    JOIN pg_proc p ON p.oid = d.refobjid
    WHERE p.proname IN ('fn_perfil_usuario_atual', 'fn_e_supervisor_do_campo')
      AND d.deptype = 'n'
  ) THEN
    RAISE EXCEPTION 'Dependências ativas encontradas. DROP cancelado.';
  END IF;
END $$;

-- Só executa o DROP se o bloco acima não lançar exceção
DROP FUNCTION IF EXISTS public.fn_perfil_usuario_atual() CASCADE;
DROP FUNCTION IF EXISTS public.fn_e_supervisor_do_campo(uuid) CASCADE;
