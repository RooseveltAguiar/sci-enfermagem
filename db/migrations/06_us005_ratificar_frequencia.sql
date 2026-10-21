-- ============================================================
-- MIGRATION: 06_us005_ratificar_frequencia.sql
-- USER STORY: US-005 — RATIFICAR FREQUÊNCIA (Ator 3 e Ator 4)
-- ============================================================

-- ============================================================
-- 1. Trigger de Imutabilidade (Bloqueio de UPDATE)
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_bloqueia_update_ratificado()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF OLD.status = 'ratificado' THEN
        -- Apenas o owner/postgres (coordenacao num cenário extremo manual) 
        -- poderia fazer bypass, mas em runtime comum é bloqueado.
        RAISE EXCEPTION 'SCI: Imutabilidade. Frequência % já está ratificada e não pode ser modificada.', OLD.id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bloqueia_update_ratificado ON public.frequencias;
CREATE TRIGGER trg_bloqueia_update_ratificado
    BEFORE UPDATE ON public.frequencias
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_bloqueia_update_ratificado();

-- ============================================================
-- 2. Trigger pós-ratificação 
-- Atualiza status da frequencia, notifica Ator 1 e checa % de presença.
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_pos_ratificacao()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_aluno_id UUID;
    v_novo_status status_frequencia_enum;
    v_pct_presenca DECIMAL(5,2);
    v_limiar_str TEXT;
    v_limiar DECIMAL(5,2) := 75.00;
    v_prof_coord_id UUID;
BEGIN
    -- Define o novo status com base na decisão (ratificado ou recusado -> rejeitado)
    v_novo_status := CASE WHEN NEW.decisao = 'ratificado' THEN 'ratificado'::status_frequencia_enum ELSE 'rejeitado'::status_frequencia_enum END;
    
    UPDATE public.frequencias
    SET status = v_novo_status, updated_at = NOW(), updated_by = NEW.created_by
    WHERE id = NEW.frequencia_id AND status != v_novo_status;

    SELECT aluno_id INTO v_aluno_id FROM public.frequencias WHERE id = NEW.frequencia_id;

    -- Notifica Ator 1
    INSERT INTO public.notificacoes (
        destinatario_id, tipo, titulo, corpo, referencia_tipo, referencia_id, created_by
    ) VALUES (
        v_aluno_id,
        CASE WHEN NEW.decisao = 'ratificado' THEN 'freq_ratificada' ELSE 'freq_rejeitada' END,
        CASE WHEN NEW.decisao = 'ratificado' THEN 'Abono Ratificado' ELSE 'Abono Recusado' END,
        CASE WHEN NEW.decisao = 'ratificado' 
             THEN 'Sua ausência foi ratificada com sucesso e computada como presença.'
             ELSE 'O abono foi recusado. Motivo: ' || COALESCE(NEW.justificativa, 'Não informado') END,
        'frequencia', NEW.frequencia_id, NEW.ratificado_por
    );

    -- Verifica limiar de frequência
    BEGIN
        SELECT valor INTO v_limiar_str FROM public.configuracoes WHERE chave = 'limiar_frequencia_pct' LIMIT 1;
        IF v_limiar_str IS NOT NULL THEN
            v_limiar := v_limiar_str::DECIMAL;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_limiar := 75.00;
    END;

    -- Tenta calcular o percentual do aluno (se a view já existir ou quando existir)
    -- O cálculo se baseia em (presenças + ratificadas) / total_frequencias_possiveis
    -- Como a view vw_percentual_frequencia pode calcular isso, nós fazemos um count rápido aqui:
    SELECT 
        (COUNT(*) FILTER (WHERE status IN ('validado', 'ratificado'))::DECIMAL / GREATEST(COUNT(*), 1)) * 100
    INTO v_pct_presenca
    FROM public.frequencias
    WHERE aluno_id = v_aluno_id AND deleted_at IS NULL;

    IF v_pct_presenca < v_limiar THEN
        -- Notifica Atores 3 e 4
        FOR v_prof_coord_id IN (
            SELECT id FROM public.usuarios 
            WHERE perfil IN ('professor', 'coordenacao') AND ativo = true AND deleted_at IS NULL
        ) LOOP
            INSERT INTO public.notificacoes (
                destinatario_id, tipo, titulo, corpo, referencia_tipo, referencia_id, created_by
            ) VALUES (
                v_prof_coord_id, 'alerta_frequencia_baixa', 'Alerta de Frequência Baixa',
                'O aluno atingiu um percentual de ' || ROUND(v_pct_presenca, 2) || '%, abaixo do limiar de ' || v_limiar || '%.',
                'usuario', v_aluno_id, NEW.ratificado_por
            );
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pos_ratificacao ON public.ratificacoes;
CREATE TRIGGER trg_pos_ratificacao
    AFTER INSERT ON public.ratificacoes
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_pos_ratificacao();
