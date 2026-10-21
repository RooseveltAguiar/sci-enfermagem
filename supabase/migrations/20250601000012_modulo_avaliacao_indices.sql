-- ============================================================
-- MIGRATION 20250601000012 [BASE]
-- BLOCO B — Índices
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_avaliacoes_aluno_periodo
    ON public.avaliacoes(aluno_id, periodo_referencia DESC)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_avaliacoes_avaliador
    ON public.avaliacoes(avaliador_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_avaliacoes_alocacao
    ON public.avaliacoes(alocacao_id, tipo)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_avaliacoes_status
    ON public.avaliacoes(status)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_avaliacoes_historico
    ON public.avaliacoes_historico_status(avaliacao_id, alterado_em DESC);

