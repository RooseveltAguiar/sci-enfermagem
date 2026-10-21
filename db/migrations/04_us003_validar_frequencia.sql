-- ============================================================
-- MIGRATION: 04_us003_validar_frequencia.sql
-- USER STORY: US-003 — VALIDAR FREQUÊNCIA (Ator 2)
-- ============================================================

-- ============================================================
-- 1. Confirmação das Políticas RLS
-- O schema v1.2 delta já aplicou a política "freq: update supervisor"
-- garantindo que apenas Ator 2 atualize frequencias dos seus campos.
-- A máquina de estados também já bloqueia transições inválidas.
-- ============================================================

-- ============================================================
-- 2. Trigger pós-rejeição para notificar o Ator 1
-- Dispara após inserção na tabela rejeicoes.
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_pos_rejeicao_notifica()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_aluno_id UUID;
BEGIN
    -- Atualiza o status da frequência para rejeitado (se já não estiver)
    UPDATE public.frequencias
    SET status = 'rejeitado', updated_at = NOW(), updated_by = NEW.created_by
    WHERE id = NEW.frequencia_id AND status != 'rejeitado';

    -- Busca o ID do aluno correspondente à frequência
    SELECT aluno_id INTO v_aluno_id
    FROM public.frequencias
    WHERE id = NEW.frequencia_id;

    -- Insere a notificação para o aluno (Ator 1)
    INSERT INTO public.notificacoes (
        destinatario_id, tipo, titulo, corpo, referencia_tipo, referencia_id, created_by
    ) VALUES (
        v_aluno_id,
        'freq_rejeitada',
        CASE WHEN NEW.etapa = 'validacao' THEN 'Frequência Rejeitada' ELSE 'Ratificação Recusada' END,
        'Sua frequência foi rejeitada. Motivo: ' || NEW.justificativa,
        'frequencia',
        NEW.frequencia_id,
        NEW.rejeitado_por
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pos_rejeicao_notifica ON public.rejeicoes;
CREATE TRIGGER trg_pos_rejeicao_notifica
    AFTER INSERT ON public.rejeicoes
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_pos_rejeicao_notifica();
