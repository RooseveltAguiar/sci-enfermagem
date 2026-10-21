-- ============================================================
-- MIGRATION 20250601000014 [BASE]
-- BLOCO B — Funções e Triggers
-- ============================================================

-- ── Fn de perfil do avaliador (SECURITY DEFINER — lição do
--    BUG-DESIGN-001 já aplicada desde o design desta entidade) ──
CREATE OR REPLACE FUNCTION public.fn_valida_perfil_avaliacao()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
    v_perfil_aluno     perfil_ator_enum;
    v_perfil_avaliador perfil_ator_enum;
BEGIN
    SELECT perfil INTO v_perfil_aluno
    FROM public.usuarios WHERE id = NEW.aluno_id;

    IF v_perfil_aluno != 'aluno' THEN
        RAISE EXCEPTION
            'SCI: avaliacoes.aluno_id deve ter perfil ''aluno''. ID: %',
            NEW.aluno_id;
    END IF;

    SELECT perfil INTO v_perfil_avaliador
    FROM public.usuarios WHERE id = NEW.avaliador_id;

    IF NEW.tipo IN ('setorial', 'autoavaliacao') THEN
        IF NEW.avaliador_id != NEW.aluno_id THEN
            RAISE EXCEPTION
                'SCI: avaliação tipo ''%'' exige avaliador_id = aluno_id. '
                'avaliador_id: % | aluno_id: %',
                NEW.tipo, NEW.avaliador_id, NEW.aluno_id;
        END IF;
    ELSIF NEW.tipo = 'do_interno' THEN
        IF v_perfil_avaliador NOT IN ('supervisor', 'professor') THEN
            RAISE EXCEPTION
                'SCI: avaliação ''do_interno'' exige avaliador ''supervisor'' '
                'ou ''professor''. Perfil encontrado: %', v_perfil_avaliador;
        END IF;
        IF NEW.avaliador_id = NEW.aluno_id THEN
            RAISE EXCEPTION
                'SCI: avaliação ''do_interno'' não pode ter avaliador_id = aluno_id.';
        END IF;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.alocacoes_alunos
        WHERE id = NEW.alocacao_id AND aluno_id = NEW.aluno_id
    ) THEN
        RAISE EXCEPTION
            'SCI: alocacao_id (%) não pertence ao aluno_id (%).',
            NEW.alocacao_id, NEW.aluno_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_valida_perfil_avaliacao
    BEFORE INSERT OR UPDATE OF aluno_id, avaliador_id, tipo, alocacao_id
    ON public.avaliacoes
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_valida_perfil_avaliacao();


-- ── Trigger A: imutabilidade pós-aprovação ────────────────────
-- Prefixo "a_" garante execução ANTES de trg_avaliacoes_b_*
-- (PostgreSQL: múltiplos BEFORE triggers disparam em ordem
-- alfabética pelo nome — ver documento de design, seção B.6).
CREATE OR REPLACE FUNCTION public.fn_avaliacoes_bloqueia_aprovada()
RETURNS TRIGGER
SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status = 'aprovada' THEN
        RAISE EXCEPTION
            'SCI: avaliação aprovada é imutável (id=%). '
            'Operação % bloqueada.',
            OLD.id, TG_OP;
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_avaliacoes_a_imutavel
    BEFORE UPDATE OR DELETE ON public.avaliacoes
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_avaliacoes_bloqueia_aprovada();


-- ── Trigger B: validação de transição de status ───────────────
CREATE OR REPLACE FUNCTION public.fn_valida_transicao_avaliacao()
RETURNS TRIGGER
SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status = NEW.status THEN RETURN NEW; END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.avaliacoes_transicoes_permitidas
        WHERE status_atual   = OLD.status
          AND status_proximo = NEW.status
    ) THEN
        RAISE EXCEPTION
            'SCI: transição inválida em avaliacoes: [%] → [%]. '
            'Consulte avaliacoes_transicoes_permitidas.',
            OLD.status, NEW.status;
    END IF;

    -- Submissão exige conteúdo completo
    IF NEW.status = 'submetida' THEN
        IF NEW.nota_geral IS NULL
           OR NEW.pontos_positivos IS NULL
           OR NEW.pontos_melhoria IS NULL
        THEN
            RAISE EXCEPTION
                'SCI: submissão exige nota_geral, pontos_positivos '
                'e pontos_melhoria preenchidos.';
        END IF;
    END IF;

    -- Devolução exige justificativa
    IF NEW.status = 'rascunho' AND OLD.status = 'submetida' THEN
        IF NEW.comentario_validacao IS NULL
           OR LENGTH(TRIM(NEW.comentario_validacao)) < 20
        THEN
            RAISE EXCEPTION
                'SCI: devolução exige comentario_validacao '
                'com no mínimo 20 caracteres.';
        END IF;
    END IF;

    INSERT INTO public.avaliacoes_historico_status
        (avaliacao_id, status_anterior, status_novo,
         alterado_por, alterado_em, referencia_tipo)
    VALUES (
        NEW.id, OLD.status, NEW.status,
        COALESCE(auth.uid(), NEW.updated_by, NEW.created_by),
        NOW(),
        CASE WHEN NEW.status = 'rascunho' AND OLD.status = 'submetida'
             THEN 'devolucao' ELSE NULL END
    );

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_avaliacoes_b_transicao
    BEFORE UPDATE OF status ON public.avaliacoes
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_valida_transicao_avaliacao();


-- ── Trigger C: restrição de colunas por perfil ────────────────
-- FIX RLS-SPRINT3-02 e Achado 1.
-- Contexto: OLD não está disponível em WITH CHECK de policies RLS
-- (disponível apenas em triggers). Por isso esta restrição vive
-- aqui, não na policy — padrão já adotado em fn_soft_delete_frequencia.
--
-- Regra:
--   Coordenação    → NUNCA pode alterar campos de conteúdo,
--                    independentemente do status atual.
--   Professor      → pode alterar conteúdo SOMENTE quando é o próprio
--                    avaliador (avaliador_id = auth.uid()) E o status
--                    atual é 'rascunho'. Em qualquer outro caso
--                    (validando avaliação de outro), restrito a
--                    status + comentario_validacao.
--   Supervisor/Ator1 → não chegam a este trigger em fluxo de validação
--                    (suas policies só permitem atualizar rascunho próprio).
CREATE OR REPLACE FUNCTION public.fn_restricao_colunas_avaliacao()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
    v_perfil perfil_ator_enum;
BEGIN
    v_perfil := public.auth_get_perfil();

    -- Coordenação: nunca pode alterar campos de conteúdo
    IF v_perfil = 'coordenacao' THEN
        IF NEW.nota_geral          IS DISTINCT FROM OLD.nota_geral
        OR NEW.pontos_positivos    IS DISTINCT FROM OLD.pontos_positivos
        OR NEW.pontos_melhoria     IS DISTINCT FROM OLD.pontos_melhoria
        OR NEW.comentario_livre    IS DISTINCT FROM OLD.comentario_livre
        OR NEW.avaliador_id        IS DISTINCT FROM OLD.avaliador_id
        OR NEW.aluno_id            IS DISTINCT FROM OLD.aluno_id
        OR NEW.tipo                IS DISTINCT FROM OLD.tipo
        OR NEW.alocacao_id         IS DISTINCT FROM OLD.alocacao_id
        THEN
            RAISE EXCEPTION
                'SCI: coordenação pode alterar apenas status e '
                'comentario_validacao em avaliações. Campos de '
                'conteúdo são imutáveis.';
        END IF;
    END IF;

    -- Professor: restrição quando NÃO está editando rascunho próprio
    IF v_perfil = 'professor' THEN
        IF NOT (OLD.avaliador_id = auth.uid() AND OLD.status = 'rascunho') THEN
            IF NEW.nota_geral       IS DISTINCT FROM OLD.nota_geral
            OR NEW.pontos_positivos IS DISTINCT FROM OLD.pontos_positivos
            OR NEW.pontos_melhoria  IS DISTINCT FROM OLD.pontos_melhoria
            OR NEW.comentario_livre IS DISTINCT FROM OLD.comentario_livre
            OR NEW.avaliador_id     IS DISTINCT FROM OLD.avaliador_id
            OR NEW.aluno_id         IS DISTINCT FROM OLD.aluno_id
            OR NEW.tipo             IS DISTINCT FROM OLD.tipo
            OR NEW.alocacao_id      IS DISTINCT FROM OLD.alocacao_id
            THEN
                RAISE EXCEPTION
                    'SCI: professor pode alterar campos de conteúdo apenas '
                    'em avaliações próprias com status ''rascunho''. '
                    'Em outros contextos, apenas status e '
                    'comentario_validacao são permitidos.';
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_avaliacoes_c_restricao_colunas
    BEFORE UPDATE ON public.avaliacoes
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_restricao_colunas_avaliacao();
-- Nomenclatura "c_" garante execução APÓS a_ (imutabilidade) e b_ (transição).
-- Se "a_" já rejeitou a operação (aprovada), "c_" nunca dispara.


-- ── Registro do estado inicial ────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_registra_status_inicial_avaliacao()
RETURNS TRIGGER
SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO public.avaliacoes_historico_status
        (avaliacao_id, status_anterior, status_novo, alterado_por, alterado_em)
    VALUES (
        NEW.id, NULL, NEW.status,
        COALESCE(auth.uid(), NEW.created_by), NOW()
    );
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_registra_status_inicial_avaliacao
    AFTER INSERT ON public.avaliacoes
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_registra_status_inicial_avaliacao();


-- ── updated_at automático ─────────────────────────────────────
CREATE OR REPLACE TRIGGER trg_avaliacoes_updated_at
    BEFORE UPDATE ON public.avaliacoes
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();


-- ── Notificações ──────────────────────────────────────────────
-- Submissão → notifica coordenação (e professor, se Q-SPRINT3-01 = B).
-- Validação/aprovação → notifica aluno avaliado.
-- Devolução → notifica quem preencheu (avaliador_id).
CREATE OR REPLACE FUNCTION public.fn_notifica_avaliacao()
RETURNS TRIGGER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
    v_dest RECORD;
BEGIN
    IF NEW.status = 'submetida' AND OLD.status = 'rascunho' THEN
        -- Notifica coordenação sempre.
        -- Professor só é notificado se Q-SPRINT3-01 = Option B (valida).
        -- Por ora: notifica coordenação + professor que é avaliador
        -- (avaliador_id já é professor/supervisor, pode ser útil para
        -- rastrear própria submissão; ajustar se PO/BA decidir diferente).
        FOR v_dest IN
            SELECT id FROM public.usuarios
            WHERE perfil = 'coordenacao'
              AND ativo = true AND deleted_at IS NULL
        LOOP
            INSERT INTO public.notificacoes
                (destinatario_id, tipo, titulo, corpo,
                 referencia_tipo, referencia_id, created_by)
            VALUES (
                v_dest.id, 'avaliacao_submetida',
                'Nova avaliação submetida',
                format('Avaliação ''%s'' aguarda validação.', NEW.tipo),
                'avaliacao', NEW.id,
                COALESCE(auth.uid(), NEW.updated_by)
            );
        END LOOP;

    ELSIF NEW.status IN ('validada', 'aprovada') THEN
        INSERT INTO public.notificacoes
            (destinatario_id, tipo, titulo, corpo,
             referencia_tipo, referencia_id, created_by)
        VALUES (
            NEW.aluno_id,
            CASE NEW.status
                WHEN 'validada' THEN 'avaliacao_validada'
                ELSE 'avaliacao_aprovada'
            END,
            CASE NEW.status
                WHEN 'validada' THEN 'Avaliação validada'
                ELSE 'Avaliação aprovada'
            END,
            format('Sua avaliação ''%s'' foi %s.',
                   NEW.tipo,
                   CASE NEW.status WHEN 'validada' THEN 'validada'
                                   ELSE 'aprovada' END),
            'avaliacao', NEW.id,
            COALESCE(auth.uid(), NEW.updated_by)
        );

    ELSIF NEW.status = 'rascunho' AND OLD.status = 'submetida' THEN
        INSERT INTO public.notificacoes
            (destinatario_id, tipo, titulo, corpo,
             referencia_tipo, referencia_id, created_by)
        VALUES (
            NEW.avaliador_id,
            'avaliacao_devolvida',
            'Avaliação devolvida',
            format('Sua avaliação ''%s'' foi devolvida: %s',
                   NEW.tipo, NEW.comentario_validacao),
            'avaliacao', NEW.id,
            COALESCE(auth.uid(), NEW.updated_by)
        );
    END IF;

    RETURN NEW;
END;
$$;

-- AFTER UPDATE: só dispara se os triggers BEFORE (a_, b_, c_) não
-- rejeitaram a operação — notificação só ocorre em transições válidas.
CREATE OR REPLACE TRIGGER trg_notifica_avaliacao
    AFTER UPDATE OF status ON public.avaliacoes
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notifica_avaliacao();

