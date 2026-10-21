-- ============================================================
-- MIGRATION: 05_us004_abonar_frequencia.sql
-- USER STORY: US-004 — ABONAR FREQUÊNCIA (Ator 2 e Ator 3)
-- ============================================================

-- ============================================================
-- 1. Validação de inserção no Abono (Check Constraint via Trigger)
-- Um abono só pode ser criado se o status da frequência for rejeitado ou ausente.
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_valida_insercao_abono()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_status status_frequencia_enum;
BEGIN
    SELECT status INTO v_status FROM public.frequencias WHERE id = NEW.frequencia_id;
    
    IF v_status NOT IN ('rejeitado', 'ausente') THEN
        RAISE EXCEPTION 'SCI: Abono só pode ser criado para frequências com status "rejeitado" ou "ausente". Status atual: %', v_status;
    END IF;
    
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_valida_insercao_abono ON public.abonos;
CREATE TRIGGER trg_valida_insercao_abono
    BEFORE INSERT ON public.abonos
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_valida_insercao_abono();

-- ============================================================
-- 2. Trigger pós-insert em abonos
-- Atualiza frequencias, notifica Ator 1 e Ator 3/4.
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_pos_abono_frequencia()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_aluno_id UUID;
    v_campo_id UUID;
    v_prof_coord_id UUID;
BEGIN
    -- Atualiza a frequência para pendente de ratificação
    UPDATE public.frequencias
    SET status = 'abonado_pend_ratificacao', updated_at = NOW(), updated_by = NEW.created_by
    WHERE id = NEW.frequencia_id AND status != 'abonado_pend_ratificacao';

    -- Busca aluno_id e campo_id
    SELECT f.aluno_id, al.campo_id INTO v_aluno_id, v_campo_id
    FROM public.frequencias f
    JOIN public.alocacoes_alunos al ON al.id = f.alocacao_id
    WHERE f.id = NEW.frequencia_id;

    -- Notifica o Ator 1
    INSERT INTO public.notificacoes (
        destinatario_id, tipo, titulo, corpo, referencia_tipo, referencia_id, created_by
    ) VALUES (
        v_aluno_id, 'freq_abonada', 'Ausência Abonada',
        'Uma justificativa de abono foi submetida e aguarda ratificação final.',
        'abono', NEW.id, NEW.abonado_por
    );

    -- Notifica os Atores 3 e 4
    -- Pega todos com perfil professor e coordenacao
    FOR v_prof_coord_id IN (
        SELECT id FROM public.usuarios 
        WHERE perfil IN ('professor', 'coordenacao') AND ativo = true AND deleted_at IS NULL
    ) LOOP
        INSERT INTO public.notificacoes (
            destinatario_id, tipo, titulo, corpo, referencia_tipo, referencia_id, created_by
        ) VALUES (
            v_prof_coord_id, 'abono_pendente_ratificacao', 'Abono Pendente',
            'Um abono requer ratificação.',
            'abono', NEW.id, NEW.abonado_por
        );
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pos_abono_frequencia ON public.abonos;
CREATE TRIGGER trg_pos_abono_frequencia
    AFTER INSERT ON public.abonos
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_pos_abono_frequencia();

-- ============================================================
-- 3. Storage Bucket 'documentos_abono' e RLS
-- ============================================================
-- Assegura que o bucket existe (privado)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('documentos_abono', 'documentos_abono', false) 
ON CONFLICT (id) DO NOTHING;

-- RLS para objetos do bucket
-- Habilitar RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Upload: Ator 2 e 3
CREATE POLICY "docs_abono_insert_sup_prof"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'documentos_abono'
        AND public.auth_get_perfil_jwt() IN ('supervisor', 'professor')
    );

-- Download/Ler Arquivo Físico: Ator 3 e 4
CREATE POLICY "docs_abono_select_prof_coord"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'documentos_abono'
        AND public.auth_get_perfil_jwt() IN ('professor', 'coordenacao')
    );

-- Deletar: Ator 3 e 4
CREATE POLICY "docs_abono_delete_prof_coord"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'documentos_abono'
        AND public.auth_get_perfil_jwt() IN ('professor', 'coordenacao')
    );

-- ============================================================
-- 4. Ajuste QA: Ator 1 pode ver METADATA (public.documentos_abono)
-- mas não pode baixar o arquivo (resolvido pois na storage.objects
-- o aluno não tem permissão de SELECT).
-- ============================================================
CREATE POLICY "docs_abono_metadata_aluno"
    ON public.documentos_abono FOR SELECT
    USING (
        public.auth_get_perfil_jwt() = 'aluno'
        AND EXISTS (
            SELECT 1 FROM public.abonos ab
            JOIN public.frequencias f ON f.id = ab.frequencia_id
            WHERE ab.id = abono_id AND f.aluno_id = auth.uid()
        )
    );
