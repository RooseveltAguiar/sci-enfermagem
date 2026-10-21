-- ============================================================
-- MIGRATION 20250601000016 [BASE]
-- BLOCO B — RLS policies de avaliacoes e historico
-- + Reescrita das 5 policies existentes com escopo professor_turmas
--   (Q-B10-2 Option B confirmado — professor escopado a "seus alunos")
-- ============================================================

-- ── Helper: verifica se professor tem vínculo ativo com o campo ──
-- Espelha auth_supervisiona_campo (mesmo padrão).
CREATE OR REPLACE FUNCTION public.auth_professor_do_campo(p_campo_id UUID)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.professor_turmas
        WHERE professor_id = auth.uid()
          AND campo_id     = p_campo_id
          AND deleted_at   IS NULL
          AND data_inicio  <= CURRENT_DATE
          AND (data_fim IS NULL OR data_fim >= CURRENT_DATE)
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.auth_professor_do_campo(UUID) FROM anon;


-- ── REESCRITA DE POLICIES EXISTENTES (criadas em v1.2 e sprint2) ──
-- Necessário para adicionar o escopo professor_turmas ao branch 'professor'.

-- 1. frequencias: select
DROP POLICY IF EXISTS "freq: select" ON public.frequencias;

CREATE POLICY "freq: select"
    ON public.frequencias FOR SELECT
    USING (
        (public.auth_get_perfil_jwt() = 'aluno'
            AND aluno_id = auth.uid()
            AND deleted_at IS NULL)
        OR
        (public.auth_get_perfil_jwt() = 'supervisor'
            AND deleted_at IS NULL
            AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = alocacao_id
                  AND public.auth_supervisiona_campo(al.campo_id)
            ))
        OR
        -- Q-B10-2 Option B: professor vê frequências de seus campos
        (public.auth_get_perfil_jwt() = 'professor'
            AND deleted_at IS NULL
            AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = alocacao_id
                  AND public.auth_professor_do_campo(al.campo_id)
            ))
        OR
        public.auth_get_perfil_jwt() = 'coordenacao'
    );

-- 2. atividades: select
DROP POLICY IF EXISTS "atividades: select" ON public.atividades;

CREATE POLICY "atividades: select"
    ON public.atividades FOR SELECT
    USING (
        (public.auth_get_perfil_jwt() = 'aluno'
            AND aluno_id = auth.uid()
            AND deleted_at IS NULL)
        OR
        (public.auth_get_perfil_jwt() = 'supervisor'
            AND deleted_at IS NULL
            AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = alocacao_id
                  AND public.auth_supervisiona_campo(al.campo_id)
            ))
        OR
        -- Q-B10-2 Option B: professor vê atividades de seus campos
        (public.auth_get_perfil_jwt() = 'professor'
            AND deleted_at IS NULL
            AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = alocacao_id
                  AND public.auth_professor_do_campo(al.campo_id)
            ))
        OR
        public.auth_get_perfil_jwt() IN ('coordenacao')
    );

-- 3. historico de frequencias: select
DROP POLICY IF EXISTS "historico: select" ON public.frequencias_historico_status;

CREATE POLICY "historico: select"
    ON public.frequencias_historico_status FOR SELECT
    USING (
        (public.auth_get_perfil_jwt() = 'aluno'
            AND EXISTS (
                SELECT 1 FROM public.frequencias f
                WHERE f.id = frequencia_id
                  AND f.aluno_id = auth.uid()
            ))
        OR
        (public.auth_get_perfil_jwt() = 'supervisor'
            AND EXISTS (
                SELECT 1
                FROM public.frequencias f
                JOIN public.alocacoes_alunos al ON al.id = f.alocacao_id
                WHERE f.id = frequencia_id
                  AND public.auth_supervisiona_campo(al.campo_id)
            ))
        OR
        -- Q-B10-2 Option B
        (public.auth_get_perfil_jwt() = 'professor'
            AND EXISTS (
                SELECT 1
                FROM public.frequencias f
                JOIN public.alocacoes_alunos al ON al.id = f.alocacao_id
                WHERE f.id = frequencia_id
                  AND public.auth_professor_do_campo(al.campo_id)
            ))
        OR
        public.auth_get_perfil_jwt() = 'coordenacao'
    );


-- ── POLICIES NOVAS: avaliacoes ────────────────────────────────
ALTER TABLE public.avaliacoes ENABLE ROW LEVEL SECURITY;

-- SELECT: visibilidade por ator
-- Ator 1: setorial/autoavaliacao sempre; do_interno só após validada/aprovada
-- Ator 2: setorial + do_interno do seu campo; NUNCA autoavaliacao
-- Ator 3: do_interno e setorial/autoavaliacao de seus campos (Q-B10-2 B)
-- Ator 4: tudo
CREATE POLICY "avaliacoes: select"
    ON public.avaliacoes FOR SELECT
    USING (
        (public.auth_get_perfil_jwt() = 'aluno'
            AND aluno_id = auth.uid()
            AND deleted_at IS NULL
            AND (tipo IN ('setorial', 'autoavaliacao')
                 OR status IN ('validada', 'aprovada')))
        OR
        (public.auth_get_perfil_jwt() = 'supervisor'
            AND deleted_at IS NULL
            AND tipo != 'autoavaliacao'
            AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = alocacao_id
                  AND public.auth_supervisiona_campo(al.campo_id)
            ))
        OR
        -- Q-B10-2 Option B: professor vê avaliações de seus campos
        (public.auth_get_perfil_jwt() = 'professor'
            AND deleted_at IS NULL
            AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = alocacao_id
                  AND public.auth_professor_do_campo(al.campo_id)
            ))
        OR
        public.auth_get_perfil_jwt() = 'coordenacao'
    );

-- INSERT Ator 1: cria setorial/autoavaliacao sobre si mesmo
CREATE POLICY "avaliacoes: insert aluno"
    ON public.avaliacoes FOR INSERT
    WITH CHECK (
        public.auth_get_perfil() = 'aluno'
        AND aluno_id     = auth.uid()
        AND avaliador_id = auth.uid()
        AND tipo IN ('setorial', 'autoavaliacao')
        AND status = 'rascunho'
        AND EXISTS (
            SELECT 1 FROM public.alocacoes_alunos al
            WHERE al.id         = avaliacoes.alocacao_id
              AND al.aluno_id   = auth.uid()
              AND al.deleted_at IS NULL
              AND al.data_inicio <= CURRENT_DATE
              AND (al.data_fim IS NULL OR al.data_fim >= CURRENT_DATE)
        )
    );

-- INSERT Ator 2 (do seu campo) e Ator 3 (do seu campo — Q-B10-2 B): criam do_interno
CREATE POLICY "avaliacoes: insert sup prof"
    ON public.avaliacoes FOR INSERT
    WITH CHECK (
        public.auth_get_perfil() IN ('supervisor', 'professor')
        AND avaliador_id = auth.uid()
        AND tipo = 'do_interno'
        AND status = 'rascunho'
        -- Supervisor: escopo via supervisor_campos
        -- Professor: escopo via professor_turmas (Q-B10-2 Option B)
        AND EXISTS (
            SELECT 1 FROM public.alocacoes_alunos al
            WHERE al.id       = avaliacoes.alocacao_id
              AND al.aluno_id = avaliacoes.aluno_id
              AND al.deleted_at IS NULL
        )
        AND (
            (public.auth_get_perfil() = 'supervisor'
             AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = avaliacoes.alocacao_id
                  AND public.auth_supervisiona_campo(al.campo_id)
             ))
            OR
            (public.auth_get_perfil() = 'professor'
             AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = avaliacoes.alocacao_id
                  AND public.auth_professor_do_campo(al.campo_id)
             ))
        )
    );

-- UPDATE Ator 1: edita e submete próprias setorial/autoavaliacao
CREATE POLICY "avaliacoes: update aluno"
    ON public.avaliacoes FOR UPDATE
    USING (
        public.auth_get_perfil() = 'aluno'
        AND aluno_id     = auth.uid()
        AND avaliador_id = auth.uid()
        AND status = 'rascunho'
        AND deleted_at IS NULL
    )
    WITH CHECK (
        tipo IN ('setorial', 'autoavaliacao')
        AND avaliador_id = auth.uid()
        AND status IN ('rascunho', 'submetida')
    );

-- UPDATE Ator 2/3: edita e submete do_interno que criaram
-- FIX RLS-SPRINT3-01: avaliador_id = auth.uid() adicionado em WITH CHECK
CREATE POLICY "avaliacoes: update sup prof"
    ON public.avaliacoes FOR UPDATE
    USING (
        public.auth_get_perfil() IN ('supervisor', 'professor')
        AND avaliador_id = auth.uid()
        AND status = 'rascunho'
        AND deleted_at IS NULL
        -- Escopo por campo (Q-B10-2 Option B)
        AND EXISTS (
            SELECT 1 FROM public.alocacoes_alunos al
            WHERE al.id = alocacao_id
              AND (
                  (public.auth_get_perfil() = 'supervisor'
                   AND public.auth_supervisiona_campo(al.campo_id))
                  OR
                  (public.auth_get_perfil() = 'professor'
                   AND public.auth_professor_do_campo(al.campo_id))
              )
        )
    )
    WITH CHECK (
        tipo = 'do_interno'
        AND avaliador_id = auth.uid()  -- FIX RLS-SPRINT3-01: impede spoofing de avaliador_id
        AND status IN ('rascunho', 'submetida')
    );

-- UPDATE Ator 4: valida, aprova, devolve
-- FIX RLS-SPRINT3-02: restrição de colunas enforçada via
-- trg_avaliacoes_c_restricao_colunas (OLD disponível em trigger,
-- não em RLS WITH CHECK). A policy define QUEM; o trigger define O QUÊ.
CREATE POLICY "avaliacoes: update coordenacao"
    ON public.avaliacoes FOR UPDATE
    USING (
        public.auth_get_perfil() = 'coordenacao'
        AND deleted_at IS NULL
    )
    WITH CHECK (
        -- Coordenação só pode mover para validada, aprovada ou rascunho (devolução)
        status IN ('validada', 'aprovada', 'rascunho')
    );


-- ── [Q-SPRINT3-01 OPTION B] Policy de validação pelo professor ──
-- APLICAR APENAS SE PO/BA confirmar: professor valida (submetida→validada).
-- Achado 1: tipo = 'do_interno' explícito; restrição de colunas via trigger c_.
-- Achado 3: escopo professor_turmas integrado (combinação Q-SPRINT3-01 B + Q-B10-2 B).
--
-- COMENTADO POR PADRÃO — descomentar após confirmação do PO/BA.
--
-- CREATE POLICY "avaliacoes: update professor validacao"
--     ON public.avaliacoes FOR UPDATE
--     USING (
--         public.auth_get_perfil() = 'professor'
--         AND tipo = 'do_interno'                  -- Achado 1a
--         AND status = 'submetida'
--         AND deleted_at IS NULL
--         -- Escopo: professor só valida avaliações de seus campos (Q-B10-2 B)
--         AND EXISTS (
--             SELECT 1 FROM public.alocacoes_alunos al
--             WHERE al.id = alocacao_id
--               AND public.auth_professor_do_campo(al.campo_id)
--         )
--     )
--     WITH CHECK (
--         status = 'validada'
--         AND tipo = 'do_interno'
--         -- Achado 1b: restrição de colunas enforçada via trigger c_
--     );


-- ── POLICIES NOVAS: avaliacoes_historico_status ───────────────
ALTER TABLE public.avaliacoes_historico_status ENABLE ROW LEVEL SECURITY;

-- 4. historico de avaliacoes: select (nova tabela — não tem DROP)
CREATE POLICY "historico_avaliacoes: select"
    ON public.avaliacoes_historico_status FOR SELECT
    USING (
        (public.auth_get_perfil_jwt() = 'aluno'
            AND EXISTS (
                SELECT 1 FROM public.avaliacoes a
                WHERE a.id = avaliacao_id
                  AND a.aluno_id = auth.uid()
                  AND (a.tipo IN ('setorial','autoavaliacao')
                       OR a.status IN ('validada','aprovada'))
            ))
        OR
        (public.auth_get_perfil_jwt() = 'supervisor'
            AND EXISTS (
                SELECT 1
                FROM public.avaliacoes a
                JOIN public.alocacoes_alunos al ON al.id = a.alocacao_id
                WHERE a.id = avaliacao_id
                  AND a.tipo != 'autoavaliacao'
                  AND public.auth_supervisiona_campo(al.campo_id)
            ))
        OR
        -- 5. Q-B10-2 Option B: professor escopado a seus campos
        (public.auth_get_perfil_jwt() = 'professor'
            AND EXISTS (
                SELECT 1
                FROM public.avaliacoes a
                JOIN public.alocacoes_alunos al ON al.id = a.alocacao_id
                WHERE a.id = avaliacao_id
                  AND public.auth_professor_do_campo(al.campo_id)
            ))
        OR
        public.auth_get_perfil_jwt() = 'coordenacao'
    );
-- INSERT apenas via triggers (service_role) — sem policy de INSERT.


-- ============================================================
-- FIM — schema_sprint3.sql (revisão QA)
-- ============================================================
-- Migrations aplicadas: 000008, 000010–000016
-- Migration excluída:   000009 (CONF-SPRINT3-01 aguarda Antigravity)
--
-- Correções desta revisão:
--   RLS-SPRINT3-01 ✅ avaliador_id = auth.uid() em WITH CHECK sup_prof
--   RLS-SPRINT3-02 ✅ trg_avaliacoes_c_restricao_colunas (trigger, não policy)
--   Achado 1       ✅ tipo = 'do_interno' + coluna c_ protegem professor
--   Achado 2       ✅ professor_turmas completo com RLS e fn_valida_perfil
--   Achado 3       ✅ policy professor_validacao usa auth_professor_do_campo
--   5 policies     ✅ freq/ativ/hist com branch professor escopado
--
-- Verificação pós-deploy recomendada (QA):
--   SELECT prosecdef FROM pg_proc
--   WHERE proname IN ('fn_valida_perfil_aluno','fn_valida_perfil_supervisor',
--     'fn_valida_perfil_abonador','fn_valida_perfil_ratificador',
--     'fn_valida_perfil_avaliacao','fn_valida_perfil_professor',
--     'fn_restricao_colunas_avaliacao','auth_professor_do_campo');
--   -- Esperado: prosecdef = true em todas as linhas.
-- ============================================================
