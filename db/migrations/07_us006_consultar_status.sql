-- ============================================================
-- MIGRATION: 07_us006_consultar_status.sql
-- USER STORY: US-006 — CONSULTAR STATUS (todos os atores)
-- ============================================================

-- ============================================================
-- 1. vw_percentual_frequencia
-- Validar que 'abonado_pend_ratificacao' é tratado como ausência provisória.
-- A presença só é contada se o status for 'validado' ou 'ratificado'.
-- ============================================================
CREATE OR REPLACE VIEW public.vw_percentual_frequencia
WITH (security_invoker = on)
AS
SELECT 
    aluno_id,
    COUNT(*) AS total_frequencias_registradas,
    COUNT(*) FILTER (WHERE status IN ('validado', 'ratificado')) AS presencas_confirmadas,
    COUNT(*) FILTER (WHERE status = 'pendente_validacao') AS pendentes_validacao,
    COUNT(*) FILTER (WHERE status = 'abonado_pend_ratificacao') AS abonos_pendentes,
    COUNT(*) FILTER (WHERE status IN ('rejeitado', 'ausente')) AS ausencias_finais,
    ROUND(
        (COUNT(*) FILTER (WHERE status IN ('validado', 'ratificado'))::DECIMAL / GREATEST(COUNT(*), 1)) * 100, 
        2
    ) AS percentual_frequencia
FROM public.frequencias
WHERE deleted_at IS NULL
GROUP BY aluno_id;

-- ============================================================
-- 2. vw_trilha_auditoria_frequencia
-- Retorna para cada frequencia_id o histórico completo de ações
-- com os timestamps e atores responsáveis (criador, validador, etc.)
-- ============================================================
CREATE OR REPLACE VIEW public.vw_trilha_auditoria_frequencia
WITH (security_invoker = on)
AS
SELECT 
    h.frequencia_id,
    h.status_anterior,
    h.status_novo,
    h.alterado_em AS data_hora_alteracao,
    h.referencia_tipo AS acao_origem,
    u.nome AS alterado_por_nome,
    u.perfil AS alterado_por_perfil
FROM public.frequencias_historico_status h
LEFT JOIN public.usuarios u ON u.id = h.alterado_por
ORDER BY h.frequencia_id, h.alterado_em ASC;

-- ============================================================
-- 3. Confirmação das Políticas RLS nas Views
-- A diretiva "WITH (security_invoker = on)" (aplicada aqui e
-- no schema_v1.2_delta.sql) garante que qualquer consulta
-- executada nas views respeitará as políticas RLS das tabelas base,
-- que já isolam a visibilidade por ator.
-- ============================================================
