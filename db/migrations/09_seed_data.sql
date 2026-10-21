-- ============================================================
-- MIGRATION: 09_seed_data.sql
-- USER STORY: SEED (Para QA) + Ajustes finais de RLS
-- ============================================================

-- ============================================================
-- 1. RLS da tabela ALOCACOES_ALUNOS (Ajuste QA)
-- ============================================================
ALTER TABLE public.alocacoes_alunos ENABLE ROW LEVEL SECURITY;

-- SELECT: 
-- Ator 1 vê apenas suas próprias
-- Ator 2 vê do seu campo
-- Ator 3 e 4 veem todas
DROP POLICY IF EXISTS "alocacoes_select" ON public.alocacoes_alunos;
CREATE POLICY "alocacoes_select"
    ON public.alocacoes_alunos FOR SELECT
    USING (
        (public.auth_get_perfil_jwt() = 'aluno' AND aluno_id = auth.uid())
        OR 
        (public.auth_get_perfil_jwt() = 'supervisor' AND public.fn_e_supervisor_do_campo(campo_id) = true)
        OR 
        (public.auth_get_perfil_jwt() IN ('professor', 'coordenacao'))
    );

-- INSERT/UPDATE/DELETE: apenas Ator 4 (coordenacao)
DROP POLICY IF EXISTS "alocacoes_all_coord" ON public.alocacoes_alunos;
CREATE POLICY "alocacoes_all_coord"
    ON public.alocacoes_alunos FOR ALL
    USING (public.auth_get_perfil_jwt() = 'coordenacao')
    WITH CHECK (public.auth_get_perfil_jwt() = 'coordenacao');

-- ============================================================
-- 2. SEED CONFIGURAÇÕES
-- ============================================================
INSERT INTO public.configuracoes (chave, valor, descricao)
VALUES ('limiar_frequencia_pct', '75', 'Percentual mínimo de frequência exigido')
ON CONFLICT (chave) DO UPDATE SET valor = EXCLUDED.valor;

-- ============================================================
-- 3. SEED DADOS (Mock Data para testes de QA)
-- ============================================================
DO $$
DECLARE
    v_campo_id UUID := '11111111-1111-1111-1111-111111111111';
    v_turno_manha_id UUID := '22222222-2222-2222-2222-222222222221';
    v_turno_noite_id UUID := '22222222-2222-2222-2222-222222222222';
    
    v_aluno_id UUID := '33333333-3333-3333-3333-333333333331';
    v_supervisor_id UUID := '33333333-3333-3333-3333-333333333332';
    v_prof_id UUID := '33333333-3333-3333-3333-333333333333';
    v_coord_id UUID := '33333333-3333-3333-3333-333333333334';
    
    v_alocacao_id UUID := '44444444-4444-4444-4444-444444444444';
    
    v_data_atual DATE := CURRENT_DATE;
BEGIN
    -- Inserir Usuários (bypass temporário de triggers caso auth.users não exista aqui)
    -- Em ambiente real, criaríamos no Supabase Auth também.
    INSERT INTO public.usuarios (id, cpf, nome, email, perfil, ativo) VALUES
        (v_aluno_id, '11111111111', 'Aluno Teste', 'aluno@sci.uece.br', 'aluno', true),
        (v_supervisor_id, '22222222222', 'Supervisor Teste', 'sup@sci.uece.br', 'supervisor', true),
        (v_prof_id, '33333333333', 'Professor Teste', 'prof@sci.uece.br', 'professor', true),
        (v_coord_id, '44444444444', 'Coord Teste', 'coord@sci.uece.br', 'coordenacao', true)
    ON CONFLICT (cpf) DO NOTHING;

    -- Inserir Campo de Estágio (UECE Itaperi approx)
    INSERT INTO public.campos_estagio (id, nome, endereco, latitude, longitude, raio_metros, created_by, ativo)
    VALUES (v_campo_id, 'Hospital Estadual', 'Av. Teste, 100', -3.79, -38.55, 150, v_coord_id, true)
    ON CONFLICT (id) DO NOTHING;

    -- Inserir Turnos
    INSERT INTO public.turnos (id, campo_id, tipo, hora_inicio, hora_fim, dias_semana, atravessa_meia_noite, created_by, ativo)
    VALUES 
        (v_turno_manha_id, v_campo_id, 'manha', '07:00:00', '13:00:00', 127, false, v_coord_id, true),
        (v_turno_noite_id, v_campo_id, 'noite', '19:00:00', '07:00:00', 127, true, v_coord_id, true)
    ON CONFLICT (id) DO NOTHING;

    -- Vínculo Supervisor -> Campo
    INSERT INTO public.supervisor_campos (supervisor_id, campo_id, data_inicio, created_by)
    VALUES (v_supervisor_id, v_campo_id, '2026-01-01', v_coord_id)
    ON CONFLICT DO NOTHING;

    -- Vínculo Aluno -> Alocação (Manhã)
    INSERT INTO public.alocacoes_alunos (id, aluno_id, campo_id, turno_id, data_inicio, created_by)
    VALUES (v_alocacao_id, v_aluno_id, v_campo_id, v_turno_manha_id, '2026-01-01', v_coord_id)
    ON CONFLICT DO NOTHING;

    -- ============================================================
    -- Inserir Frequências com diferentes estados (Ajuste QA)
    -- ============================================================
    
    -- Para burlar a constraint UNIQUE(aluno, alocacao, data) e permitir testar vários estados de uma vez, 
    -- vamos espalhar as datas (D-1, D-2, D-3, etc) ou usar alocações fictícias. Usaremos datas regressivas.

    -- 1. pendente_validacao (Hoje)
    INSERT INTO public.frequencias (id, aluno_id, alocacao_id, turno_id, data_registro, timestamp_servidor, lat_registro, lng_registro, gps_disponivel, distancia_metros, status, created_by)
    VALUES (gen_random_uuid(), v_aluno_id, v_alocacao_id, v_turno_manha_id, v_data_atual, NOW(), -3.79, -38.55, true, 10.5, 'pendente_validacao', v_aluno_id);

    -- 2. validado (D-1)
    INSERT INTO public.frequencias (id, aluno_id, alocacao_id, turno_id, data_registro, timestamp_servidor, lat_registro, lng_registro, gps_disponivel, distancia_metros, status, created_by)
    VALUES (gen_random_uuid(), v_aluno_id, v_alocacao_id, v_turno_manha_id, v_data_atual - INTERVAL '1 day', NOW() - INTERVAL '1 day', -3.79, -38.55, true, 12.0, 'validado', v_aluno_id);

    -- 3. rejeitado (D-2)
    INSERT INTO public.frequencias (id, aluno_id, alocacao_id, turno_id, data_registro, timestamp_servidor, lat_registro, lng_registro, gps_disponivel, distancia_metros, status, created_by)
    VALUES (gen_random_uuid(), v_aluno_id, v_alocacao_id, v_turno_manha_id, v_data_atual - INTERVAL '2 days', NOW() - INTERVAL '2 days', -3.79, -38.55, true, 5.0, 'rejeitado', v_aluno_id);

    -- 4. abonado_pend_ratificacao (D-3)
    INSERT INTO public.frequencias (id, aluno_id, alocacao_id, turno_id, data_registro, timestamp_servidor, lat_registro, lng_registro, gps_disponivel, distancia_metros, status, created_by)
    VALUES (gen_random_uuid(), v_aluno_id, v_alocacao_id, v_turno_manha_id, v_data_atual - INTERVAL '3 days', NOW() - INTERVAL '3 days', -3.79, -38.55, true, 2.0, 'abonado_pend_ratificacao', v_aluno_id);

    -- 5. gps_disponivel = false (D-4)
    INSERT INTO public.frequencias (id, aluno_id, alocacao_id, turno_id, data_registro, timestamp_servidor, gps_disponivel, status, created_by)
    VALUES (gen_random_uuid(), v_aluno_id, v_alocacao_id, v_turno_manha_id, v_data_atual - INTERVAL '4 days', NOW() - INTERVAL '4 days', false, 'pendente_validacao', v_aluno_id);

    -- 6. fora do raio (distância = 500m) (D-5)
    INSERT INTO public.frequencias (id, aluno_id, alocacao_id, turno_id, data_registro, timestamp_servidor, lat_registro, lng_registro, gps_disponivel, distancia_metros, status, created_by)
    VALUES (gen_random_uuid(), v_aluno_id, v_alocacao_id, v_turno_manha_id, v_data_atual - INTERVAL '5 days', NOW() - INTERVAL '5 days', -3.80, -38.56, true, 500.0, 'pendente_validacao', v_aluno_id);

END $$;
