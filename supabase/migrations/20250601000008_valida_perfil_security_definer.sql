-- ============================================================
-- MIGRATION 20250601000008 [BASE]
-- BLOCO A.1 — fn_valida_perfil_* → SECURITY DEFINER
-- Resolve BUG-DESIGN-001
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_valida_perfil_aluno()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
    IF (SELECT perfil FROM public.usuarios WHERE id = NEW.aluno_id) != 'aluno' THEN
        RAISE EXCEPTION
            'SCI: alocacoes_alunos.aluno_id deve ter perfil ''aluno''. ID: %',
            NEW.aluno_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_valida_perfil_supervisor()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
    IF (SELECT perfil FROM public.usuarios WHERE id = NEW.supervisor_id) != 'supervisor' THEN
        RAISE EXCEPTION
            'SCI: supervisor_campos.supervisor_id deve ter perfil ''supervisor''. ID: %',
            NEW.supervisor_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_valida_perfil_abonador()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE v_perfil perfil_ator_enum;
BEGIN
    SELECT perfil INTO v_perfil FROM public.usuarios WHERE id = NEW.abonado_por;
    IF v_perfil NOT IN ('supervisor', 'professor') THEN
        RAISE EXCEPTION
            'SCI: abonos.abonado_por deve ter perfil ''supervisor'' ou ''professor''. '
            'Perfil encontrado: %', v_perfil;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_valida_perfil_ratificador()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE v_perfil perfil_ator_enum;
BEGIN
    SELECT perfil INTO v_perfil FROM public.usuarios WHERE id = NEW.ratificado_por;
    IF v_perfil NOT IN ('professor', 'coordenacao') THEN
        RAISE EXCEPTION
            'SCI: ratificacoes.ratificado_por deve ter perfil ''professor'' ou ''coordenacao''. '
            'Perfil encontrado: %', v_perfil;
    END IF;
    RETURN NEW;
END;
$$;
-- Os triggers existentes continuam válidos — OR REPLACE não exige
-- recriar o CREATE TRIGGER correspondente.

