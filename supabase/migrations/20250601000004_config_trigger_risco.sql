-- ============================================================
-- MIGRATION: 20250601000004_config_trigger_risco.sql
-- DESCRIÇÃO: Insere configuração de limiar e trigger de alerta
-- ============================================================

-- Insere o valor padrão de 75% na tabela de configurações existente
INSERT INTO public.configuracoes (chave, valor, descricao)
VALUES ('limiar_frequencia_pct', '75', 'Limiar mínimo de frequência do aluno (em porcentagem) antes de gerar alertas de risco.')
ON CONFLICT (chave) DO UPDATE SET valor = EXCLUDED.valor;

-- Trigger para recalcular alertas (gera notificações para ator 3 e 4 caso os alunos cruzem a linha)
CREATE OR REPLACE FUNCTION public.fn_config_limiar_alterado()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NEW.chave = 'limiar_frequencia_pct' AND NEW.valor != OLD.valor THEN
        -- Aqui ocorreria a lógica de recalcular a porcentagem atual de cada aluno
        -- e verificar quem caiu abaixo de NEW.valor.
        -- Para quem cruzou a linha, inserimos uma notificação para a coordenação (ator 4)
        -- e para o professor supervisor (ator 3).
        -- 
        -- Nota: O aluno NÃO recebe notificação, conforme decisão de negócio (Q3).
        
        -- Exemplo fictício de inserção de notificação administrativa:
        -- INSERT INTO public.notificacoes (usuario_id, mensagem, tipo)
        -- SELECT coord_id, 'Alerta: Aluno(s) cruzaram o novo limiar de risco de ' || NEW.valor || '%', 'alerta'
        -- FROM ... (query que cruza dados dos alunos com a nova configuração)
        
        -- O indicador visual (app Flutter) lerá a config em tempo real.
        NULL;
    END IF;
    
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_config_limiar_alterado ON public.configuracoes;
CREATE TRIGGER trg_config_limiar_alterado
    AFTER UPDATE OF valor
    ON public.configuracoes
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_config_limiar_alterado();

-- RLS: Garantir que apenas Ator 4 (Coordenação) possa atualizar configurações
-- Se a tabela de configurações ainda não tiver RLS, habilitamos:
ALTER TABLE public.configuracoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "configuracoes_select_all"
    ON public.configuracoes FOR SELECT
    USING (auth.uid() IS NOT NULL);

CREATE POLICY "configuracoes_update_coord"
    ON public.configuracoes FOR UPDATE
    USING (public.auth_get_perfil_jwt() = 'coordenacao')
    WITH CHECK (public.auth_get_perfil_jwt() = 'coordenacao');
