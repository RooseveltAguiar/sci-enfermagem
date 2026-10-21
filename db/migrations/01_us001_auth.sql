-- ============================================================
-- MIGRATION: 01_us001_auth.sql
-- USER STORY: US-001 — AUTENTICAÇÃO
-- ============================================================
-- 1. Injeção de perfil no JWT (app_metadata.perfil)
-- Trigger para manter a tabela public.usuarios e auth.users sincronizadas
-- ============================================================

-- Função que atualiza o app_metadata do auth.users com o perfil correto do usuario.
-- Roda com SECURITY DEFINER (como superuser) para acessar a auth.users.
CREATE OR REPLACE FUNCTION public.fn_sync_user_profile_to_auth()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql AS $$
BEGIN
    -- Atualiza app_metadata.perfil na tabela auth.users correspondente
    UPDATE auth.users
    SET raw_app_meta_data = 
        COALESCE(raw_app_meta_data, '{}'::jsonb) || 
        jsonb_build_object('perfil', NEW.perfil)
    WHERE id = NEW.id;
    
    RETURN NEW;
END;
$$;

-- Dispara sempre que o perfil for alterado ou um novo usuário for inserido
DROP TRIGGER IF EXISTS trg_sync_user_profile_to_auth ON public.usuarios;
CREATE TRIGGER trg_sync_user_profile_to_auth
    AFTER INSERT OR UPDATE OF perfil
    ON public.usuarios
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sync_user_profile_to_auth();

-- ============================================================
-- 2. Sessão de 8 horas
-- ============================================================
-- A expiração de 8h (28800 segundos) e o Refresh Token são configurados
-- nativamente no Dashboard do Supabase: 
-- Authentication > Policies > JWT expiry limit (set to 28800).
-- Adicionalmente, inserimos a revogação se houver logout:
CREATE OR REPLACE FUNCTION public.fn_logout_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.sessoes 
    SET revogada = true, revogada_em = NOW(), updated_at = NOW()
    WHERE usuario_id = auth.uid() AND revogada = false;
END;
$$;

-- ============================================================
-- 3. Confirmação das funções auth_* 
-- ============================================================
-- O schema_v1.2_delta.sql já contém a definição de auth_get_perfil_jwt()
-- Não há necessidade de re-declarar as políticas de RLS aqui, pois o delta
-- já realizou o bind para todas as 14 tabelas usando essa função.
