-- ============================================================
-- MIGRATION 20250601000015 [BASE — Q-B10-2 OPTION B CONFIRMADO]
-- professor_turmas — vínculo professor ↔ campo de estágio
-- Espelha supervisor_campos (mesmo padrão de design, Sprint 1).
-- ============================================================

CREATE TABLE IF NOT EXISTS public.professor_turmas (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    professor_id  UUID        NOT NULL REFERENCES public.usuarios(id),
    -- perfil = 'professor' enforçado via trigger abaixo.
    campo_id      UUID        NOT NULL REFERENCES public.campos_estagio(id),
    data_inicio   DATE        NOT NULL,
    data_fim      DATE,
    -- NULL = vínculo aberto (sem previsão de encerramento).

    UNIQUE (professor_id, campo_id, data_inicio),

    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by    UUID        NOT NULL REFERENCES public.usuarios(id),
    updated_by    UUID        REFERENCES public.usuarios(id),
    deleted_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_professor_turmas_professor
    ON public.professor_turmas(professor_id)
    WHERE deleted_at IS NULL
      AND (data_fim IS NULL OR data_fim >= CURRENT_DATE);

CREATE INDEX IF NOT EXISTS idx_professor_turmas_campo
    ON public.professor_turmas(campo_id)
    WHERE deleted_at IS NULL;

-- Trigger de perfil (SECURITY DEFINER — mesmo fix do BUG-DESIGN-001)
CREATE OR REPLACE FUNCTION public.fn_valida_perfil_professor()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
    IF (SELECT perfil FROM public.usuarios WHERE id = NEW.professor_id) != 'professor'
    THEN
        RAISE EXCEPTION
            'SCI: professor_turmas.professor_id deve ter perfil ''professor''. '
            'ID: %', NEW.professor_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_valida_perfil_professor
    BEFORE INSERT OR UPDATE OF professor_id ON public.professor_turmas
    FOR EACH ROW EXECUTE FUNCTION public.fn_valida_perfil_professor();

CREATE OR REPLACE TRIGGER trg_professor_turmas_updated_at
    BEFORE UPDATE ON public.professor_turmas
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- RLS de professor_turmas
ALTER TABLE public.professor_turmas ENABLE ROW LEVEL SECURITY;

-- Ator 3: vê apenas os próprios vínculos
CREATE POLICY "professor_turmas: select professor"
    ON public.professor_turmas FOR SELECT
    USING (
        professor_id = auth.uid()
        AND deleted_at IS NULL
    );

-- Ator 4: vê todos, gerencia
CREATE POLICY "professor_turmas: select coordenacao"
    ON public.professor_turmas FOR SELECT
    USING (public.auth_get_perfil_jwt() = 'coordenacao');

CREATE POLICY "professor_turmas: insert"
    ON public.professor_turmas FOR INSERT
    WITH CHECK (public.auth_get_perfil() = 'coordenacao');

CREATE POLICY "professor_turmas: update"
    ON public.professor_turmas FOR UPDATE
    USING (public.auth_get_perfil() = 'coordenacao');

