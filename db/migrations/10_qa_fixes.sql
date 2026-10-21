-- ============================================================
-- MIGRATION: 10_qa_fixes.sql
-- USER STORY: Correções do QA (Sprint 1)
-- ============================================================

-- ============================================================
-- 1. Criação do Bucket Storage 'documentos-abono' (com hífen)
-- QA apontou ausência. Subistituiremos o bucket anterior (se existir).
-- ============================================================

-- Insere o bucket com nome corrigido
INSERT INTO storage.buckets (id, name, public) 
VALUES ('documentos-abono', 'documentos-abono', false) 
ON CONFLICT (id) DO NOTHING;

-- Habilita RLS no bucket objects (caso não esteja)
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Upload: Ator 2 e 3
DROP POLICY IF EXISTS "docs_abono_insert_sup_prof" ON storage.objects;
CREATE POLICY "docs_abono_insert_sup_prof"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'documentos-abono'
        AND public.auth_get_perfil_jwt() IN ('supervisor', 'professor')
    );

-- Download/Ler Arquivo Físico: Ator 3 e 4
DROP POLICY IF EXISTS "docs_abono_select_prof_coord" ON storage.objects;
CREATE POLICY "docs_abono_select_prof_coord"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'documentos-abono'
        AND public.auth_get_perfil_jwt() IN ('professor', 'coordenacao')
    );

-- Deletar: Ator 3 e 4
DROP POLICY IF EXISTS "docs_abono_delete_prof_coord" ON storage.objects;
CREATE POLICY "docs_abono_delete_prof_coord"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'documentos-abono'
        AND public.auth_get_perfil_jwt() IN ('professor', 'coordenacao')
    );

-- ============================================================
-- 2. BUG-ARCH-001 (Soft Delete)
-- Remover policy de DELETE físico para evitar erro de FK.
-- O Flutter App usará um UPDATE setando deleted_at ao invés de DELETE.
-- ============================================================
DROP POLICY IF EXISTS "freq: delete" ON public.frequencias;

-- (A policy de UPDATE da Coordenação já abrange atualizar qualquer campo, 
--  portanto eles já podem fazer o UPDATE de deleted_at sem problemas).

-- ============================================================
-- 3. SEED DADOS (Reforço dos status pendentes que o QA reportou falta)
-- Inserimos mais duas frequências com datas ainda mais antigas
-- ============================================================
DO $$
DECLARE
    v_aluno_id UUID := '33333333-3333-3333-3333-333333333331';
    v_alocacao_id UUID := '44444444-4444-4444-4444-444444444444';
    v_turno_manha_id UUID := '22222222-2222-2222-2222-222222222221';
    v_data_atual DATE := CURRENT_DATE;
BEGIN
    -- Reforço: Rejeitado (D-6)
    INSERT INTO public.frequencias (id, aluno_id, alocacao_id, turno_id, data_registro, timestamp_servidor, lat_registro, lng_registro, gps_disponivel, distancia_metros, status, created_by)
    VALUES (gen_random_uuid(), v_aluno_id, v_alocacao_id, v_turno_manha_id, v_data_atual - INTERVAL '6 days', NOW() - INTERVAL '6 days', -3.79, -38.55, true, 5.0, 'rejeitado', v_aluno_id)
    ON CONFLICT DO NOTHING;

    -- Reforço: Abonado pendente ratificação (D-7)
    INSERT INTO public.frequencias (id, aluno_id, alocacao_id, turno_id, data_registro, timestamp_servidor, lat_registro, lng_registro, gps_disponivel, distancia_metros, status, created_by)
    VALUES (gen_random_uuid(), v_aluno_id, v_alocacao_id, v_turno_manha_id, v_data_atual - INTERVAL '7 days', NOW() - INTERVAL '7 days', -3.79, -38.55, true, 2.0, 'abonado_pend_ratificacao', v_aluno_id)
    ON CONFLICT DO NOTHING;
END $$;
