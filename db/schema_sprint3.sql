-- ============================================================
-- SCI — schema_sprint3.sql · REVISÃO QA
-- Bloco A (Dívida Técnica) + Bloco B (Módulo de Avaliação)
-- ============================================================
-- Pré-requisito: Sprint 2 homologado (17 tabelas, RLS, auth_*,
-- pg_cron, bucket documentos-abono).
-- Executar no SQL Editor do Supabase Dashboard.
-- Git: /db/schema_sprint3.sql
--
-- Correções desta revisão vs. schema_sprint3.sql v1.0:
--   RLS-SPRINT3-01 · avaliador_id = auth.uid() em WITH CHECK
--   RLS-SPRINT3-02 · restrição de colunas via trigger BEFORE UPDATE
--   Achado 1 · policy professor com tipo e restrição de colunas
--   Achado 2 · professor_turmas completo (Q-B10-2 = Option B CONFIRMADO)
--   Achado 3 · combinação Q-SPRINT3-01 B + Q-B10-2 B coberta
--   5 policies existentes reescritas com escopo professor_turmas
--
-- Seções condicionais marcadas com:
--   [BASE] = sempre aplicar
--   [Q-SPRINT3-01 OPTION B] = aplicar SE professor valida (subm→valid)
--
-- EXCLUÍDO: migration 20250601000009 (DROP fn_distancia/fn_dentro)
-- CONF-SPRINT3-01 bloqueado aguardando Antigravity.
-- ============================================================


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


-- ============================================================
-- MIGRATION 20250601000009 — EXCLUÍDA
-- CONF-SPRINT3-01: remoção de fn_distancia_ao_campo e
-- fn_dentro_do_campo aguarda confirmação do Antigravity.
-- Aplicar separadamente quando desbloqueado.
-- ============================================================


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


-- ============================================================
-- MIGRATION 20250601000011 [BASE]
-- BLOCO B — Tabelas: avaliacoes + avaliacoes_historico_status
-- ============================================================

CREATE TABLE IF NOT EXISTS public.avaliacoes (
    id                   UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
    alocacao_id          UUID                  NOT NULL REFERENCES public.alocacoes_alunos(id),
    aluno_id             UUID                  NOT NULL REFERENCES public.usuarios(id),
    -- O estudante a quem a avaliação se refere (sempre).
    avaliador_id         UUID                  NOT NULL REFERENCES public.usuarios(id),
    -- Quem preenche o formulário.
    -- setorial/autoavaliacao: avaliador_id = aluno_id (enforçado via trigger).
    -- do_interno: avaliador_id é o supervisor ou professor.

    tipo                 tipo_avaliacao_enum   NOT NULL,
    periodo_referencia   DATE                  NOT NULL,
    -- Convenção: sempre o primeiro dia do mês (1º/MM/YYYY).

    status               status_avaliacao_enum NOT NULL DEFAULT 'rascunho',

    -- Conteúdo (nullable em rascunho; obrigatoriedade enforçada no submit)
    nota_geral           SMALLINT,
    pontos_positivos     TEXT,
    pontos_melhoria      TEXT,
    comentario_livre     TEXT,
    comentario_validacao TEXT,
    -- Coordenação preenche ao validar/aprovar (opcional) e
    -- obrigatoriamente ao devolver (≥ 20 chars — enforçado em trigger).

    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by  UUID         NOT NULL REFERENCES public.usuarios(id),
    updated_by  UUID         REFERENCES public.usuarios(id),
    deleted_at  TIMESTAMPTZ,

    CONSTRAINT chk_periodo_primeiro_dia CHECK (
        EXTRACT(DAY FROM periodo_referencia) = 1
    ),
    CONSTRAINT chk_nota_geral CHECK (
        nota_geral IS NULL OR nota_geral BETWEEN 1 AND 10
    ),
    CONSTRAINT chk_pontos_positivos_min CHECK (
        pontos_positivos IS NULL OR LENGTH(TRIM(pontos_positivos)) >= 20
    ),
    CONSTRAINT chk_pontos_melhoria_min CHECK (
        pontos_melhoria IS NULL OR LENGTH(TRIM(pontos_melhoria)) >= 20
    ),
    CONSTRAINT chk_comentario_validacao_min CHECK (
        comentario_validacao IS NULL
        OR LENGTH(TRIM(comentario_validacao)) >= 20
    )
);

-- Índice único parcial: 1 avaliação por tipo, por alocação, por período.
-- Parcial (WHERE deleted_at IS NULL) para permitir recriar após soft delete.
CREATE UNIQUE INDEX IF NOT EXISTS uq_avaliacoes_alocacao_tipo_periodo
    ON public.avaliacoes(alocacao_id, tipo, periodo_referencia)
    WHERE deleted_at IS NULL;

-- Histórico de transições — espelha frequencias_historico_status (Sprint 1).
-- Imutável por design: sem deleted_at, sem updated_by.
CREATE TABLE IF NOT EXISTS public.avaliacoes_historico_status (
    id              UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
    avaliacao_id    UUID                  NOT NULL REFERENCES public.avaliacoes(id),
    status_anterior status_avaliacao_enum,
    status_novo     status_avaliacao_enum NOT NULL,
    alterado_por    UUID                  NOT NULL REFERENCES public.usuarios(id),
    alterado_em     TIMESTAMPTZ           NOT NULL DEFAULT NOW(),
    referencia_tipo VARCHAR(50)
    -- 'devolucao' quando submetida→rascunho; NULL nos demais casos.
);


-- ============================================================
-- MIGRATION 20250601000012 [BASE]
-- BLOCO B — Índices
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_avaliacoes_aluno_periodo
    ON public.avaliacoes(aluno_id, periodo_referencia DESC)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_avaliacoes_avaliador
    ON public.avaliacoes(avaliador_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_avaliacoes_alocacao
    ON public.avaliacoes(alocacao_id, tipo)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_avaliacoes_status
    ON public.avaliacoes(status)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_avaliacoes_historico
    ON public.avaliacoes_historico_status(avaliacao_id, alterado_em DESC);


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


-- ============================================================
-- MIGRATION 20250601000015 [BASE — Q-B10-2 OPTION B CONFIRMADO]
-- professor_turmas — vínculo professor ↔ campo de estágio
-- Espelha supervisor_campos (mesmo padrão de design, Sprint 1).
-- ============================================================

CREATE TABLE IF NOT EXISTS public.professor_turmas (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    professor_id  UUID        NOT NULL REFERENCES public.usuarios(id),
    -- perfil = 'professor' enforçado via trigger abaixo.
    campo_id      UUID        NOT NULL REFERENCES public.campos_estagio(id),
    data_inicio   DATE        NOT NULL,
    data_fim      DATE,
    -- NULL = vínculo aberto (sem previsão de encerramento).

    UNIQUE (professor_id, campo_id, data_inicio),

    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by    UUID        NOT NULL REFERENCES public.usuarios(id),
    updated_by    UUID        REFERENCES public.usuarios(id),
    deleted_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_professor_turmas_professor
    ON public.professor_turmas(professor_id)
    WHERE deleted_at IS NULL
      AND (data_fim IS NULL OR data_fim >= CURRENT_DATE);

CREATE INDEX IF NOT EXISTS idx_professor_turmas_campo
    ON public.professor_turmas(campo_id)
    WHERE deleted_at IS NULL;

-- Trigger de perfil (SECURITY DEFINER — mesmo fix do BUG-DESIGN-001)
CREATE OR REPLACE FUNCTION public.fn_valida_perfil_professor()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
    IF (SELECT perfil FROM public.usuarios WHERE id = NEW.professor_id) != 'professor'
    THEN
        RAISE EXCEPTION
            'SCI: professor_turmas.professor_id deve ter perfil ''professor''. '
            'ID: %', NEW.professor_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_valida_perfil_professor
    BEFORE INSERT OR UPDATE OF professor_id ON public.professor_turmas
    FOR EACH ROW EXECUTE FUNCTION public.fn_valida_perfil_professor();

CREATE OR REPLACE TRIGGER trg_professor_turmas_updated_at
    BEFORE UPDATE ON public.professor_turmas
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- RLS de professor_turmas
ALTER TABLE public.professor_turmas ENABLE ROW LEVEL SECURITY;

-- Ator 3: vê apenas os próprios vínculos
CREATE POLICY "professor_turmas: select professor"
    ON public.professor_turmas FOR SELECT
    USING (
        professor_id = auth.uid()
        AND deleted_at IS NULL
    );

-- Ator 4: vê todos, gerencia
CREATE POLICY "professor_turmas: select coordenacao"
    ON public.professor_turmas FOR SELECT
    USING (public.auth_get_perfil_jwt() = 'coordenacao');

CREATE POLICY "professor_turmas: insert"
    ON public.professor_turmas FOR INSERT
    WITH CHECK (public.auth_get_perfil() = 'coordenacao');

CREATE POLICY "professor_turmas: update"
    ON public.professor_turmas FOR UPDATE
    USING (public.auth_get_perfil() = 'coordenacao');


-- ============================================================
-- MIGRATION 20250601000016 [BASE]
-- BLOCO B — RLS policies de avaliacoes e historico
-- + Reescrita das 5 policies existentes com escopo professor_turmas
--   (Q-B10-2 Option B confirmado — professor escopado a "seus alunos")
-- ============================================================

-- ── Helper: verifica se professor tem vínculo ativo com o campo ──
-- Espelha auth_supervisiona_campo (mesmo padrão).
CREATE OR REPLACE FUNCTION public.auth_professor_do_campo(p_campo_id UUID)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.professor_turmas
        WHERE professor_id = auth.uid()
          AND campo_id     = p_campo_id
          AND deleted_at   IS NULL
          AND data_inicio  <= CURRENT_DATE
          AND (data_fim IS NULL OR data_fim >= CURRENT_DATE)
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.auth_professor_do_campo(UUID) FROM anon;


-- ── REESCRITA DE POLICIES EXISTENTES (criadas em v1.2 e sprint2) ──
-- Necessário para adicionar o escopo professor_turmas ao branch 'professor'.

-- 1. frequencias: select
DROP POLICY IF EXISTS "freq: select" ON public.frequencias;

CREATE POLICY "freq: select"
    ON public.frequencias FOR SELECT
    USING (
        (public.auth_get_perfil_jwt() = 'aluno'
            AND aluno_id = auth.uid()
            AND deleted_at IS NULL)
        OR
        (public.auth_get_perfil_jwt() = 'supervisor'
            AND deleted_at IS NULL
            AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = alocacao_id
                  AND public.auth_supervisiona_campo(al.campo_id)
            ))
        OR
        -- Q-B10-2 Option B: professor vê frequências de seus campos
        (public.auth_get_perfil_jwt() = 'professor'
            AND deleted_at IS NULL
            AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = alocacao_id
                  AND public.auth_professor_do_campo(al.campo_id)
            ))
        OR
        public.auth_get_perfil_jwt() = 'coordenacao'
    );

-- 2. atividades: select
DROP POLICY IF EXISTS "atividades: select" ON public.atividades;

CREATE POLICY "atividades: select"
    ON public.atividades FOR SELECT
    USING (
        (public.auth_get_perfil_jwt() = 'aluno'
            AND aluno_id = auth.uid()
            AND deleted_at IS NULL)
        OR
        (public.auth_get_perfil_jwt() = 'supervisor'
            AND deleted_at IS NULL
            AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = alocacao_id
                  AND public.auth_supervisiona_campo(al.campo_id)
            ))
        OR
        -- Q-B10-2 Option B: professor vê atividades de seus campos
        (public.auth_get_perfil_jwt() = 'professor'
            AND deleted_at IS NULL
            AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = alocacao_id
                  AND public.auth_professor_do_campo(al.campo_id)
            ))
        OR
        public.auth_get_perfil_jwt() IN ('coordenacao')
    );

-- 3. historico de frequencias: select
DROP POLICY IF EXISTS "historico: select" ON public.frequencias_historico_status;

CREATE POLICY "historico: select"
    ON public.frequencias_historico_status FOR SELECT
    USING (
        (public.auth_get_perfil_jwt() = 'aluno'
            AND EXISTS (
                SELECT 1 FROM public.frequencias f
                WHERE f.id = frequencia_id
                  AND f.aluno_id = auth.uid()
            ))
        OR
        (public.auth_get_perfil_jwt() = 'supervisor'
            AND EXISTS (
                SELECT 1
                FROM public.frequencias f
                JOIN public.alocacoes_alunos al ON al.id = f.alocacao_id
                WHERE f.id = frequencia_id
                  AND public.auth_supervisiona_campo(al.campo_id)
            ))
        OR
        -- Q-B10-2 Option B
        (public.auth_get_perfil_jwt() = 'professor'
            AND EXISTS (
                SELECT 1
                FROM public.frequencias f
                JOIN public.alocacoes_alunos al ON al.id = f.alocacao_id
                WHERE f.id = frequencia_id
                  AND public.auth_professor_do_campo(al.campo_id)
            ))
        OR
        public.auth_get_perfil_jwt() = 'coordenacao'
    );


-- ── POLICIES NOVAS: avaliacoes ────────────────────────────────
ALTER TABLE public.avaliacoes ENABLE ROW LEVEL SECURITY;

-- SELECT: visibilidade por ator
-- Ator 1: setorial/autoavaliacao sempre; do_interno só após validada/aprovada
-- Ator 2: setorial + do_interno do seu campo; NUNCA autoavaliacao
-- Ator 3: do_interno e setorial/autoavaliacao de seus campos (Q-B10-2 B)
-- Ator 4: tudo
CREATE POLICY "avaliacoes: select"
    ON public.avaliacoes FOR SELECT
    USING (
        (public.auth_get_perfil_jwt() = 'aluno'
            AND aluno_id = auth.uid()
            AND deleted_at IS NULL
            AND (tipo IN ('setorial', 'autoavaliacao')
                 OR status IN ('validada', 'aprovada')))
        OR
        (public.auth_get_perfil_jwt() = 'supervisor'
            AND deleted_at IS NULL
            AND tipo != 'autoavaliacao'
            AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = alocacao_id
                  AND public.auth_supervisiona_campo(al.campo_id)
            ))
        OR
        -- Q-B10-2 Option B: professor vê avaliações de seus campos
        (public.auth_get_perfil_jwt() = 'professor'
            AND deleted_at IS NULL
            AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = alocacao_id
                  AND public.auth_professor_do_campo(al.campo_id)
            ))
        OR
        public.auth_get_perfil_jwt() = 'coordenacao'
    );

-- INSERT Ator 1: cria setorial/autoavaliacao sobre si mesmo
CREATE POLICY "avaliacoes: insert aluno"
    ON public.avaliacoes FOR INSERT
    WITH CHECK (
        public.auth_get_perfil() = 'aluno'
        AND aluno_id     = auth.uid()
        AND avaliador_id = auth.uid()
        AND tipo IN ('setorial', 'autoavaliacao')
        AND status = 'rascunho'
        AND EXISTS (
            SELECT 1 FROM public.alocacoes_alunos al
            WHERE al.id         = avaliacoes.alocacao_id
              AND al.aluno_id   = auth.uid()
              AND al.deleted_at IS NULL
              AND al.data_inicio <= CURRENT_DATE
              AND (al.data_fim IS NULL OR al.data_fim >= CURRENT_DATE)
        )
    );

-- INSERT Ator 2 (do seu campo) e Ator 3 (do seu campo — Q-B10-2 B): criam do_interno
CREATE POLICY "avaliacoes: insert sup prof"
    ON public.avaliacoes FOR INSERT
    WITH CHECK (
        public.auth_get_perfil() IN ('supervisor', 'professor')
        AND avaliador_id = auth.uid()
        AND tipo = 'do_interno'
        AND status = 'rascunho'
        -- Supervisor: escopo via supervisor_campos
        -- Professor: escopo via professor_turmas (Q-B10-2 Option B)
        AND EXISTS (
            SELECT 1 FROM public.alocacoes_alunos al
            WHERE al.id       = avaliacoes.alocacao_id
              AND al.aluno_id = avaliacoes.aluno_id
              AND al.deleted_at IS NULL
        )
        AND (
            (public.auth_get_perfil() = 'supervisor'
             AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = avaliacoes.alocacao_id
                  AND public.auth_supervisiona_campo(al.campo_id)
             ))
            OR
            (public.auth_get_perfil() = 'professor'
             AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = avaliacoes.alocacao_id
                  AND public.auth_professor_do_campo(al.campo_id)
             ))
        )
    );

-- UPDATE Ator 1: edita e submete próprias setorial/autoavaliacao
CREATE POLICY "avaliacoes: update aluno"
    ON public.avaliacoes FOR UPDATE
    USING (
        public.auth_get_perfil() = 'aluno'
        AND aluno_id     = auth.uid()
        AND avaliador_id = auth.uid()
        AND status = 'rascunho'
        AND deleted_at IS NULL
    )
    WITH CHECK (
        tipo IN ('setorial', 'autoavaliacao')
        AND avaliador_id = auth.uid()
        AND status IN ('rascunho', 'submetida')
    );

-- UPDATE Ator 2/3: edita e submete do_interno que criaram
-- FIX RLS-SPRINT3-01: avaliador_id = auth.uid() adicionado em WITH CHECK
CREATE POLICY "avaliacoes: update sup prof"
    ON public.avaliacoes FOR UPDATE
    USING (
        public.auth_get_perfil() IN ('supervisor', 'professor')
        AND avaliador_id = auth.uid()
        AND status = 'rascunho'
        AND deleted_at IS NULL
        -- Escopo por campo (Q-B10-2 Option B)
        AND EXISTS (
            SELECT 1 FROM public.alocacoes_alunos al
            WHERE al.id = alocacao_id
              AND (
                  (public.auth_get_perfil() = 'supervisor'
                   AND public.auth_supervisiona_campo(al.campo_id))
                  OR
                  (public.auth_get_perfil() = 'professor'
                   AND public.auth_professor_do_campo(al.campo_id))
              )
        )
    )
    WITH CHECK (
        tipo = 'do_interno'
        AND avaliador_id = auth.uid()  -- FIX RLS-SPRINT3-01: impede spoofing de avaliador_id
        AND status IN ('rascunho', 'submetida')
    );

-- UPDATE Ator 4: valida, aprova, devolve
-- FIX RLS-SPRINT3-02: restrição de colunas enforçada via
-- trg_avaliacoes_c_restricao_colunas (OLD disponível em trigger,
-- não em RLS WITH CHECK). A policy define QUEM; o trigger define O QUÊ.
CREATE POLICY "avaliacoes: update coordenacao"
    ON public.avaliacoes FOR UPDATE
    USING (
        public.auth_get_perfil() = 'coordenacao'
        AND deleted_at IS NULL
    )
    WITH CHECK (
        -- Coordenação só pode mover para validada, aprovada ou rascunho (devolução)
        status IN ('validada', 'aprovada', 'rascunho')
    );


-- ── [Q-SPRINT3-01 OPTION B] Policy de validação pelo professor ──
-- APLICAR APENAS SE PO/BA confirmar: professor valida (submetida→validada).
-- Achado 1: tipo = 'do_interno' explícito; restrição de colunas via trigger c_.
-- Achado 3: escopo professor_turmas integrado (combinação Q-SPRINT3-01 B + Q-B10-2 B).
--
-- COMENTADO POR PADRÃO — descomentar após confirmação do PO/BA.
--
-- CREATE POLICY "avaliacoes: update professor validacao"
--     ON public.avaliacoes FOR UPDATE
--     USING (
--         public.auth_get_perfil() = 'professor'
--         AND tipo = 'do_interno'                  -- Achado 1a
--         AND status = 'submetida'
--         AND deleted_at IS NULL
--         -- Escopo: professor só valida avaliações de seus campos (Q-B10-2 B)
--         AND EXISTS (
--             SELECT 1 FROM public.alocacoes_alunos al
--             WHERE al.id = alocacao_id
--               AND public.auth_professor_do_campo(al.campo_id)
--         )
--     )
--     WITH CHECK (
--         status = 'validada'
--         AND tipo = 'do_interno'
--         -- Achado 1b: restrição de colunas enforçada via trigger c_
--     );


-- ── POLICIES NOVAS: avaliacoes_historico_status ───────────────
ALTER TABLE public.avaliacoes_historico_status ENABLE ROW LEVEL SECURITY;

-- 4. historico de avaliacoes: select (nova tabela — não tem DROP)
CREATE POLICY "historico_avaliacoes: select"
    ON public.avaliacoes_historico_status FOR SELECT
    USING (
        (public.auth_get_perfil_jwt() = 'aluno'
            AND EXISTS (
                SELECT 1 FROM public.avaliacoes a
                WHERE a.id = avaliacao_id
                  AND a.aluno_id = auth.uid()
                  AND (a.tipo IN ('setorial','autoavaliacao')
                       OR a.status IN ('validada','aprovada'))
            ))
        OR
        (public.auth_get_perfil_jwt() = 'supervisor'
            AND EXISTS (
                SELECT 1
                FROM public.avaliacoes a
                JOIN public.alocacoes_alunos al ON al.id = a.alocacao_id
                WHERE a.id = avaliacao_id
                  AND a.tipo != 'autoavaliacao'
                  AND public.auth_supervisiona_campo(al.campo_id)
            ))
        OR
        -- 5. Q-B10-2 Option B: professor escopado a seus campos
        (public.auth_get_perfil_jwt() = 'professor'
            AND EXISTS (
                SELECT 1
                FROM public.avaliacoes a
                JOIN public.alocacoes_alunos al ON al.id = a.alocacao_id
                WHERE a.id = avaliacao_id
                  AND public.auth_professor_do_campo(al.campo_id)
            ))
        OR
        public.auth_get_perfil_jwt() = 'coordenacao'
    );
-- INSERT apenas via triggers (service_role) — sem policy de INSERT.


-- ============================================================
-- FIM — schema_sprint3.sql (revisão QA)
-- ============================================================
-- Migrations aplicadas: 000008, 000010–000016
-- Migration excluída:   000009 (CONF-SPRINT3-01 aguarda Antigravity)
--
-- Correções desta revisão:
--   RLS-SPRINT3-01 ✅ avaliador_id = auth.uid() em WITH CHECK sup_prof
--   RLS-SPRINT3-02 ✅ trg_avaliacoes_c_restricao_colunas (trigger, não policy)
--   Achado 1       ✅ tipo = 'do_interno' + coluna c_ protegem professor
--   Achado 2       ✅ professor_turmas completo com RLS e fn_valida_perfil
--   Achado 3       ✅ policy professor_validacao usa auth_professor_do_campo
--   5 policies     ✅ freq/ativ/hist com branch professor escopado
--
-- Verificação pós-deploy recomendada (QA):
--   SELECT prosecdef FROM pg_proc
--   WHERE proname IN ('fn_valida_perfil_aluno','fn_valida_perfil_supervisor',
--     'fn_valida_perfil_abonador','fn_valida_perfil_ratificador',
--     'fn_valida_perfil_avaliacao','fn_valida_perfil_professor',
--     'fn_restricao_colunas_avaliacao','auth_professor_do_campo');
--   -- Esperado: prosecdef = true em todas as linhas.
-- ============================================================
