-- ============================================================
-- MIGRATION: 20250601000002_pg_cron_retencao_gps.sql
-- DESCRIÇÃO: Habilita pg_cron e agenda anonimização de GPS
-- ============================================================

-- Habilitar a extensão pg_cron (depende de privilégios de superuser ou ativação no painel)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Criar a função que realiza a limpeza
CREATE OR REPLACE FUNCTION public.fn_anonimizar_coordenadas_gps()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.frequencias
    SET lat_registro = NULL,
        lng_registro = NULL,
        coordenadas_anonimizadas_em = NOW()
    WHERE created_at < NOW() - INTERVAL '90 days'
      AND coordenadas_anonimizadas_em IS NULL;
END;
$$;

-- Agendar a CRON para rodar todo domingo à meia-noite (UTC)
SELECT cron.schedule(
    'retencao_gps_semanal', -- nome do job
    '0 0 * * 0',            -- todo domingo à meia-noite
    'SELECT public.fn_anonimizar_coordenadas_gps()'
);
