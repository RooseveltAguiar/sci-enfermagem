-- ============================================================
-- SCI — Trigger de Validação de Janela de Turno (Sprint 1)
-- Requisito AC-002-3
-- ============================================================
-- Executar no SQL Editor do Supabase

CREATE OR REPLACE FUNCTION public.fn_valida_janela_turno()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_hora_inicio TIME;
    v_hora_fim TIME;
    v_atravessa_meia_noite BOOLEAN;
    v_hora_atual TIME;
    v_valido BOOLEAN := false;
BEGIN
    -- Busca os horários do turno associado
    SELECT hora_inicio, hora_fim, atravessa_meia_noite
    INTO v_hora_inicio, v_hora_fim, v_atravessa_meia_noite
    FROM public.turnos
    WHERE id = NEW.turno_id;

    -- Converte o timestamp para o fuso horário local (America/Fortaleza)
    v_hora_atual := (NEW.timestamp_servidor AT TIME ZONE 'America/Fortaleza')::TIME;

    -- Validação considerando plantões que viram a noite (ex: 19h às 07h)
    IF v_atravessa_meia_noite THEN
        IF v_hora_atual >= v_hora_inicio OR v_hora_atual <= v_hora_fim THEN
            v_valido := true;
        END IF;
    ELSE
        IF v_hora_atual >= v_hora_inicio AND v_hora_atual <= v_hora_fim THEN
            v_valido := true;
        END IF;
    END IF;

    IF NOT v_valido THEN
        RAISE EXCEPTION 'SCI: Check-in fora da janela permitida para o turno. Horário atual: %', v_hora_atual;
    END IF;

    RETURN NEW;
END;
$$;

-- Aplica o trigger na tabela frequencias ANTES do insert
CREATE OR REPLACE TRIGGER trg_valida_janela_turno
    BEFORE INSERT
    ON public.frequencias
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_valida_janela_turno();
