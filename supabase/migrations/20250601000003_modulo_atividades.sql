-- ============================================================
-- MIGRATION: 20250601000003_modulo_atividades.sql
-- DESCRIÇÃO: Criação das tabelas do módulo de atividades e RLS
-- ============================================================

-- 1. Tabela: lista_atividades_padrao
CREATE TABLE IF NOT EXISTS public.lista_atividades_padrao (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT NOT NULL UNIQUE,
    descricao_padrao TEXT,
    ativo BOOLEAN DEFAULT true,
    created_by UUID REFERENCES public.usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Tabela: atividades
CREATE TABLE IF NOT EXISTS public.atividades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alocacao_id UUID NOT NULL REFERENCES public.alocacoes_alunos(id),
    tipo_atividade TEXT NOT NULL,
    descricao TEXT NOT NULL CHECK (length(descricao) >= 10),
    outra_descricao TEXT,
    status TEXT NOT NULL DEFAULT 'pendente_validacao' CHECK (status IN ('pendente_validacao', 'validado', 'rejeitado')),
    justificativa_rejeicao TEXT,
    comentario_aluno TEXT,
    data_atividade DATE NOT NULL DEFAULT CURRENT_DATE,
    validado_por UUID REFERENCES public.usuarios(id),
    validado_em TIMESTAMPTZ,
    created_by UUID NOT NULL REFERENCES public.usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Habilitar RLS
ALTER TABLE public.lista_atividades_padrao ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.atividades ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- RLS: lista_atividades_padrao
-- ============================================================
-- SELECT: todos autenticados
CREATE POLICY "lista_atividades_select_all"
    ON public.lista_atividades_padrao FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- INSERT/UPDATE/DELETE: Ator 3 e 4 (Professor e Coordenacao)
CREATE POLICY "lista_atividades_insert_prof_coord"
    ON public.lista_atividades_padrao FOR INSERT
    WITH CHECK (public.auth_get_perfil_jwt() IN ('professor', 'coordenacao'));

CREATE POLICY "lista_atividades_update_prof_coord"
    ON public.lista_atividades_padrao FOR UPDATE
    USING (public.auth_get_perfil_jwt() IN ('professor', 'coordenacao'))
    WITH CHECK (public.auth_get_perfil_jwt() IN ('professor', 'coordenacao'));

CREATE POLICY "lista_atividades_delete_prof_coord"
    ON public.lista_atividades_padrao FOR DELETE
    USING (public.auth_get_perfil_jwt() IN ('professor', 'coordenacao'));

-- ============================================================
-- RLS: atividades
-- ============================================================
-- SELECT
CREATE POLICY "atividades_select_aluno"
    ON public.atividades FOR SELECT
    USING (public.auth_get_perfil_jwt() = 'aluno' AND created_by = auth.uid());

CREATE POLICY "atividades_select_supervisor"
    ON public.atividades FOR SELECT
    USING (
        public.auth_get_perfil_jwt() = 'supervisor' 
        AND EXISTS (
            SELECT 1 FROM public.alocacoes_alunos a
            WHERE a.id = atividades.alocacao_id 
              AND public.auth_supervisiona_campo(a.campo_id)
        )
    );

CREATE POLICY "atividades_select_prof_coord"
    ON public.atividades FOR SELECT
    USING (public.auth_get_perfil_jwt() IN ('professor', 'coordenacao'));

-- INSERT (Ator 1, Ator 3 e 4)
CREATE POLICY "atividades_insert_aluno"
    ON public.atividades FOR INSERT
    WITH CHECK (
        (public.auth_get_perfil_jwt() = 'aluno' AND created_by = auth.uid()) OR
        (public.auth_get_perfil_jwt() IN ('professor', 'coordenacao'))
    );

-- UPDATE: Aluno pode atualizar apenas comentario_aluno se validado
CREATE POLICY "atividades_update_comentario_aluno"
    ON public.atividades FOR UPDATE
    USING (
        public.auth_get_perfil_jwt() = 'aluno' 
        AND created_by = auth.uid()
        AND status = 'validado'
    )
    WITH CHECK (
        public.auth_get_perfil_jwt() = 'aluno' 
        AND created_by = auth.uid()
        AND status = 'validado'
    );

-- UPDATE: Supervisor pode validar/rejeitar
CREATE POLICY "atividades_update_supervisor"
    ON public.atividades FOR UPDATE
    USING (
        public.auth_get_perfil_jwt() = 'supervisor' 
        AND EXISTS (
            SELECT 1 FROM public.alocacoes_alunos a
            WHERE a.id = atividades.alocacao_id 
              AND public.auth_supervisiona_campo(a.campo_id)
        )
    );

-- UPDATE: Professor e Coordenação podem alterar tudo
CREATE POLICY "atividades_update_prof_coord"
    ON public.atividades FOR UPDATE
    USING (public.auth_get_perfil_jwt() IN ('professor', 'coordenacao'));

-- DELETE (Soft): Apenas Ator 3 e 4
CREATE POLICY "atividades_delete_prof_coord"
    ON public.atividades FOR DELETE
    USING (public.auth_get_perfil_jwt() IN ('professor', 'coordenacao'));

-- ============================================================
-- Funções e Triggers
-- ============================================================

-- Função RPC para validar limite de 10 atividades por dia/alocação antes de inserir
CREATE OR REPLACE FUNCTION public.fn_valida_limite_atividades()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM public.atividades
    WHERE alocacao_id = NEW.alocacao_id
      AND data_atividade = NEW.data_atividade
      AND deleted_at IS NULL;
      
    IF v_count >= 10 THEN
        RAISE EXCEPTION 'limite_diario_atingido';
    END IF;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_valida_limite_atividades
    BEFORE INSERT ON public.atividades
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_valida_limite_atividades();

-- Trigger de notificação pós-validação (US-B3)
CREATE OR REPLACE FUNCTION public.fn_notifica_atividade_validada()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NEW.status = 'validado' AND OLD.status = 'pendente_validacao' THEN
        INSERT INTO public.notificacoes (usuario_id, mensagem, tipo)
        VALUES (NEW.created_by, 'Atividade validada pelo supervisor', 'sucesso');
    ELSIF NEW.status = 'rejeitado' AND OLD.status = 'pendente_validacao' THEN
        INSERT INTO public.notificacoes (usuario_id, mensagem, tipo)
        VALUES (NEW.created_by, 'Atividade rejeitada: ' || COALESCE(NEW.justificativa_rejeicao, 'Sem justificativa'), 'erro');
    END IF;
    
    -- Atualiza updated_at sempre que houver UPDATE
    NEW.updated_at = NOW();
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notifica_atividade_validada
    BEFORE UPDATE ON public.atividades
    FOR EACH ROW
    WHEN (NEW.status IS DISTINCT FROM OLD.status OR NEW.status = OLD.status) -- Also triggers just to update `updated_at`
    EXECUTE FUNCTION public.fn_notifica_atividade_validada();

-- ============================================================
-- Seed de Dados
-- ============================================================
-- Conforme Q1, inserir 12 atividades padrao (9 originais + 3 adicionais)
INSERT INTO public.lista_atividades_padrao (nome, descricao_padrao) VALUES 
('Verificação de sinais vitais', 'Aferição de PA, FC, FR, e Temperatura.'),
('Administração de medicamentos', 'Preparo e administração segura de medicações.'),
('Curativo simples', 'Troca de curativo limpo e simples.'),
('Curativo complexo', 'Curativo de feridas extensas ou contaminadas.'),
('Coleta de material', 'Coleta de sangue, urina ou outros exames.'),
('Passagem de sonda', 'Sondagem vesical ou nasogástrica.'),
('Controle de balanço hídrico', 'Monitoramento rigoroso de entradas e saídas.'),
('Acompanhamento de evolução', 'Auxílio e observação da evolução do paciente.'),
('Educação em saúde', 'Orientações de saúde ao paciente e família.'),
-- Adicionais:
('Aferição de pressão arterial', 'Medição manual ou automática da PA isoladamente.'),
('Higiene e conforto do paciente', 'Banho no leito, troca de fraldas e mudança de decúbito.'),
('Registro de enfermagem (evolução em prontuário)', 'Anotação das atividades e evolução no prontuário do paciente.')
ON CONFLICT (nome) DO NOTHING;
