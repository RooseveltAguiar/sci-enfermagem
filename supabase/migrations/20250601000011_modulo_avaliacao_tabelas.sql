-- ============================================================
-- MIGRATION 20250601000011 [BASE]
-- BLOCO B — Tabelas: avaliacoes + avaliacoes_historico_status
-- ============================================================

CREATE TABLE IF NOT EXISTS public.avaliacoes (
    id                   UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
    alocacao_id          UUID                  NOT NULL REFERENCES public.alocacoes_alunos(id),
    aluno_id             UUID                  NOT NULL REFERENCES public.usuarios(id),
    -- O estudante a quem a avaliação se refere (sempre).
    avaliador_id         UUID                  NOT NULL REFERENCES public.usuarios(id),
    -- Quem preenche o formulário.
    -- setorial/autoavaliacao: avaliador_id = aluno_id (enforçado via trigger).
    -- do_interno: avaliador_id é o supervisor ou professor.

    tipo                 tipo_avaliacao_enum   NOT NULL,
    periodo_referencia   DATE                  NOT NULL,
    -- Convenção: sempre o primeiro dia do mês (1º/MM/YYYY).

    status               status_avaliacao_enum NOT NULL DEFAULT 'rascunho',

    -- Conteúdo (nullable em rascunho; obrigatoriedade enforçada no submit)
    nota_geral           SMALLINT,
    pontos_positivos     TEXT,
    pontos_melhoria      TEXT,
    comentario_livre     TEXT,
    comentario_validacao TEXT,
    -- Coordenação preenche ao validar/aprovar (opcional) e
    -- obrigatoriamente ao devolver (≥ 20 chars — enforçado em trigger).

    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by  UUID         NOT NULL REFERENCES public.usuarios(id),
    updated_by  UUID         REFERENCES public.usuarios(id),
    deleted_at  TIMESTAMPTZ,

    CONSTRAINT chk_periodo_primeiro_dia CHECK (
        EXTRACT(DAY FROM periodo_referencia) = 1
    ),
    CONSTRAINT chk_nota_geral CHECK (
        nota_geral IS NULL OR nota_geral BETWEEN 1 AND 10
    ),
    CONSTRAINT chk_pontos_positivos_min CHECK (
        pontos_positivos IS NULL OR LENGTH(TRIM(pontos_positivos)) >= 20
    ),
    CONSTRAINT chk_pontos_melhoria_min CHECK (
        pontos_melhoria IS NULL OR LENGTH(TRIM(pontos_melhoria)) >= 20
    ),
    CONSTRAINT chk_comentario_validacao_min CHECK (
        comentario_validacao IS NULL
        OR LENGTH(TRIM(comentario_validacao)) >= 20
    )
);

-- Índice único parcial: 1 avaliação por tipo, por alocação, por período.
-- Parcial (WHERE deleted_at IS NULL) para permitir recriar após soft delete.
CREATE UNIQUE INDEX IF NOT EXISTS uq_avaliacoes_alocacao_tipo_periodo
    ON public.avaliacoes(alocacao_id, tipo, periodo_referencia)
    WHERE deleted_at IS NULL;

-- Histórico de transições — espelha frequencias_historico_status (Sprint 1).
-- Imutável por design: sem deleted_at, sem updated_by.
CREATE TABLE IF NOT EXISTS public.avaliacoes_historico_status (
    id              UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
    avaliacao_id    UUID                  NOT NULL REFERENCES public.avaliacoes(id),
    status_anterior status_avaliacao_enum,
    status_novo     status_avaliacao_enum NOT NULL,
    alterado_por    UUID                  NOT NULL REFERENCES public.usuarios(id),
    alterado_em     TIMESTAMPTZ           NOT NULL DEFAULT NOW(),
    referencia_tipo VARCHAR(50)
    -- 'devolucao' quando submetida→rascunho; NULL nos demais casos.
);

