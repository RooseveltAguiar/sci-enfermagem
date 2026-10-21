-- ============================================================
-- MIGRATION 20250601000010 [BASE]
-- BLOCO B — ENUMs do módulo de avaliação
-- ============================================================

CREATE TYPE tipo_avaliacao_enum AS ENUM (
    'setorial',      -- aluno avalia o setor/campo
    'do_interno',    -- supervisor ou professor avalia o aluno
    'autoavaliacao'  -- aluno se autoavalia
);

CREATE TYPE status_avaliacao_enum AS ENUM (
    'rascunho',
    'submetida',
    'validada',
    'aprovada'
);

