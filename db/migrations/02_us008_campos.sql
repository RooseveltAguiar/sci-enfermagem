-- ============================================================
-- MIGRATION: 02_us008_campos.sql
-- USER STORY: US-008 — CAMPOS DE ESTÁGIO
-- ============================================================

-- ============================================================
-- 1. Trigger para validar ativação do campo de estágio
-- Um campo não pode ter ativo = true sem ao menos um turno ativo.
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_check_campo_ativo_com_turno()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    -- Se está tentando ativar o campo (ou inserir já ativo)
    IF NEW.ativo = true THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.turnos 
            WHERE campo_id = NEW.id 
              AND ativo = true 
              AND deleted_at IS NULL
        ) THEN
            RAISE EXCEPTION 'SCI: Um campo de estágio não pode ser ativado (ativo = true) sem possuir ao menos um turno ativo vinculado.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

-- O trigger é DEFERRED (ou check na constraint final) para permitir a inserção
-- do campo e dos turnos na mesma transação. Mas o Postgres só suporta DEFERRED em CONSTRAINT TRIGGERS.
-- Usaremos CONSTRAINT TRIGGER.
DROP TRIGGER IF EXISTS trg_check_campo_ativo_com_turno ON public.campos_estagio;
CREATE CONSTRAINT TRIGGER trg_check_campo_ativo_com_turno
    AFTER INSERT OR UPDATE OF ativo
    ON public.campos_estagio
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_check_campo_ativo_com_turno();

-- ============================================================
-- 2. Trigger de Soft Delete em Cascata e Inativação em Cascata
-- Quando um campo é desativado ou deletado logicamente, os turnos e alocações acompanham.
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_cascade_campo_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    -- Soft Delete (exclusão lógica)
    IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
        UPDATE public.turnos 
        SET deleted_at = NEW.deleted_at, updated_at = NOW(), updated_by = NEW.updated_by
        WHERE campo_id = NEW.id AND deleted_at IS NULL;
        
        UPDATE public.alocacoes_alunos
        SET deleted_at = NEW.deleted_at, updated_at = NOW(), updated_by = NEW.updated_by
        WHERE campo_id = NEW.id AND deleted_at IS NULL;
        
        UPDATE public.supervisor_campos
        SET deleted_at = NEW.deleted_at, updated_at = NOW(), updated_by = NEW.updated_by
        WHERE campo_id = NEW.id AND deleted_at IS NULL;
    END IF;

    -- Inativação (ativo = false)
    IF NEW.ativo = false AND OLD.ativo = true THEN
        UPDATE public.turnos
        SET ativo = false, updated_at = NOW(), updated_by = NEW.updated_by
        WHERE campo_id = NEW.id AND ativo = true AND deleted_at IS NULL;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cascade_campo_status ON public.campos_estagio;
CREATE TRIGGER trg_cascade_campo_status
    AFTER UPDATE OF ativo, deleted_at
    ON public.campos_estagio
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_cascade_campo_status();

-- ============================================================
-- 3. Confirmação das Políticas RLS
-- O schema v1.2 delta já aplicou corretamente INSERT/UPDATE/DELETE
-- em campos_estagio e turnos permitindo apenas o 'coordenacao'
-- (Ator 4) através da função `auth_get_perfil()`. O SELECT
-- já é liberado para todos os usuários autenticados, permitindo ao aluno ler.
-- ============================================================
