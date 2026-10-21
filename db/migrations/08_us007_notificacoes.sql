-- ============================================================
-- MIGRATION: 08_us007_notificacoes.sql
-- USER STORY: US-007 — NOTIFICAÇÕES IN-APP (todos os atores)
-- ============================================================

-- ============================================================
-- 1. Políticas RLS para Notificações
-- Cada ator só pode ver (SELECT) e interagir com suas próprias notificações.
-- Apenas funções SECURITY DEFINER / triggers internos podem INSERIR.
-- ============================================================
ALTER TABLE public.notificacoes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notif: select self" ON public.notificacoes;
CREATE POLICY "notif: select self"
    ON public.notificacoes FOR SELECT
    USING (destinatario_id = auth.uid() AND deleted_at IS NULL);

DROP POLICY IF EXISTS "notif: delete (archive) self" ON public.notificacoes;
CREATE POLICY "notif: delete (archive) self"
    ON public.notificacoes FOR DELETE
    USING (destinatario_id = auth.uid());
-- Nota: para soft delete, seria um UPDATE em deleted_at. Como a tabela 
-- possui soft delete, podemos criar uma policy de UPDATE ou usar DELETE lógico.

-- ============================================================
-- 2. Endpoint/Função: Marcar uma notificação como lida
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_marcar_notificacao_lida(p_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.notificacoes
    SET lida = true, lida_em = NOW(), updated_at = NOW()
    WHERE id = p_id 
      AND destinatario_id = auth.uid() 
      AND lida = false;
END;
$$;

-- ============================================================
-- 3. Endpoint/Função: Marcar TODAS as notificações como lidas
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_marcar_todas_notificacoes_lidas()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.notificacoes
    SET lida = true, lida_em = NOW(), updated_at = NOW()
    WHERE destinatario_id = auth.uid() 
      AND lida = false;
END;
$$;
