-- ============================================================
-- MIGRATION: 03_us002_registrar_frequencia.sql
-- USER STORY: US-002 — REGISTRAR FREQUÊNCIA COM GPS (Ator 1)
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_registrar_frequencia(
    p_alocacao_id UUID,
    p_turno_id UUID,
    p_lat DECIMAL(9,6),
    p_lng DECIMAL(9,6),
    p_gps_disponivel BOOLEAN,
    p_precisao_metros DECIMAL(8,2),
    p_is_mock BOOLEAN,
    p_velocidade_ms DECIMAL(8,3),
    p_altitude_metros DECIMAL(8,2)
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, topology
AS $$
DECLARE
    v_aluno_id UUID;
    v_campo_id UUID;
    v_campo_lat DECIMAL(9,6);
    v_campo_lng DECIMAL(9,6);
    v_campo_raio INTEGER;
    v_campo_geom GEOGRAPHY;
    v_turno_inicio TIME;
    v_turno_fim TIME;
    v_atravessa_meia_noite BOOLEAN;
    v_distancia DECIMAL(8,2) := NULL;
    v_hora_atual TIME;
    v_data_atual DATE := CURRENT_DATE;
    v_frequencia_id UUID;
    v_supervisor_id UUID;
    v_nivel_confianca SMALLINT := 2;
    v_fora_janela BOOLEAN := true;
BEGIN
    v_aluno_id := auth.uid();
    v_hora_atual := (NOW() AT TIME ZONE 'America/Fortaleza')::TIME;

    -- 1. Verificar se a alocação existe e está ativa para hoje
    SELECT campo_id INTO v_campo_id
    FROM public.alocacoes_alunos
    WHERE id = p_alocacao_id
      AND turno_id = p_turno_id
      AND aluno_id = v_aluno_id
      AND data_inicio <= v_data_atual
      AND (data_fim IS NULL OR data_fim >= v_data_atual)
      AND deleted_at IS NULL;

    IF v_campo_id IS NULL THEN
        RAISE EXCEPTION 'alocacao_invalida';
    END IF;

    -- 2. Verificar janela de turno
    SELECT hora_inicio, hora_fim, atravessa_meia_noite
    INTO v_turno_inicio, v_turno_fim, v_atravessa_meia_noite
    FROM public.turnos
    WHERE id = p_turno_id AND deleted_at IS NULL;

    IF v_atravessa_meia_noite THEN
        IF v_hora_atual >= v_turno_inicio OR v_hora_atual <= v_turno_fim THEN
            v_fora_janela := false;
        END IF;
    ELSE
        IF v_hora_atual >= v_turno_inicio AND v_hora_atual <= v_turno_fim THEN
            v_fora_janela := false;
        END IF;
    END IF;

    IF v_fora_janela THEN
        RAISE EXCEPTION 'fora_janela_turno';
    END IF;

    -- 3. Verificar duplicata
    IF EXISTS (
        SELECT 1 FROM public.frequencias
        WHERE aluno_id = v_aluno_id
          AND turno_id = p_turno_id
          AND data_registro = v_data_atual
          AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'registro_duplicado';
    END IF;

    -- 4 e 5. Lógica GPS e PostGIS
    IF p_gps_disponivel THEN
        SELECT latitude, longitude, raio_metros, geom
        INTO v_campo_lat, v_campo_lng, v_campo_raio, v_campo_geom
        FROM public.campos_estagio
        WHERE id = v_campo_id;

        IF ST_DWithin(ST_MakePoint(p_lng, p_lat)::geography, v_campo_geom, v_campo_raio) = false THEN
            RAISE EXCEPTION 'fora_do_campo';
        END IF;
        
        v_distancia := ST_Distance(ST_MakePoint(p_lng, p_lat)::geography, v_campo_geom)::DECIMAL(8,2);
    END IF;

    -- 6. Anti-spoofing
    IF NOT p_gps_disponivel THEN
        v_nivel_confianca := 0;
    ELSIF p_is_mock OR (p_velocidade_ms IS NOT NULL AND p_velocidade_ms > 8.3) THEN
        v_nivel_confianca := 1;
    END IF;

    -- 7 e 8. Inserir a Frequência
    INSERT INTO public.frequencias (
        aluno_id, alocacao_id, turno_id, data_registro, timestamp_servidor, timestamp_cliente,
        lat_registro, lng_registro, gps_disponivel, gps_precisao_metros, distancia_metros,
        status, mock_location_detectado, velocidade_ms, altitude_metros, nivel_confianca_gps,
        created_by
    ) VALUES (
        v_aluno_id, p_alocacao_id, p_turno_id, v_data_atual, NOW(), NOW(),
        p_lat, p_lng, p_gps_disponivel, p_precisao_metros, v_distancia,
        'pendente_validacao', COALESCE(p_is_mock, false), p_velocidade_ms, p_altitude_metros, v_nivel_confianca,
        v_aluno_id
    ) RETURNING id INTO v_frequencia_id;

    -- Se gps_disponivel = false ou mock (nivel_confianca_gps = 1), notifica Ator 2
    IF NOT p_gps_disponivel OR v_nivel_confianca = 1 THEN
        -- Busca todos os supervisores ativos deste campo
        FOR v_supervisor_id IN (
            SELECT supervisor_id FROM public.supervisor_campos
            WHERE campo_id = v_campo_id AND deleted_at IS NULL
              AND data_inicio <= CURRENT_DATE AND (data_fim IS NULL OR data_fim >= CURRENT_DATE)
        ) LOOP
            INSERT INTO public.notificacoes (
                destinatario_id, tipo, titulo, corpo, referencia_tipo, referencia_id, created_by
            ) VALUES (
                v_supervisor_id, 
                CASE WHEN NOT p_gps_disponivel THEN 'gps_indisponivel' ELSE 'gps_suspeito' END,
                'Validação Manual Requerida', 
                'Confirme presença manual para o registro da frequência.',
                'frequencia', v_frequencia_id, v_aluno_id
            );
        END LOOP;
    END IF;

    RETURN v_frequencia_id;
END;
$$;
