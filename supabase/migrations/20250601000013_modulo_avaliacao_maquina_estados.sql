-- ============================================================
-- MIGRATION 20250601000013 [BASE]
-- BLOCO B — Máquina de estados
-- ============================================================

CREATE TABLE IF NOT EXISTS public.avaliacoes_transicoes_permitidas (
    status_atual   status_avaliacao_enum NOT NULL,
    status_proximo status_avaliacao_enum NOT NULL,
    PRIMARY KEY (status_atual, status_proximo)
);

INSERT INTO public.avaliacoes_transicoes_permitidas
    (status_atual, status_proximo) VALUES
    ('rascunho',  'submetida'),  -- avaliador submete
    ('submetida', 'validada'),   -- coordenação valida [ou professor — Q-SPRINT3-01]
    ('validada',  'aprovada'),   -- coordenação aprova
    ('submetida', 'rascunho')    -- coordenação devolve com justificativa
ON CONFLICT (status_atual, status_proximo) DO NOTHING;

ALTER TABLE public.avaliacoes_transicoes_permitidas
    ENABLE ROW LEVEL SECURITY;

-- Mesmo fix aplicado em transicoes_status_permitidas (Sprint 2 BUG-CRIT-1):
-- RLS sem policy = SELECT negado para authenticated → trigger de validação
-- receberia zero linhas e rejeitaria TODAS as transições.
CREATE POLICY "transicoes_avaliacoes: select"
    ON public.avaliacoes_transicoes_permitidas FOR SELECT
    USING (auth.uid() IS NOT NULL);

