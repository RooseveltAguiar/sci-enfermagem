-- ============================================================
-- SCI — Sistema de Controle do Internato
-- schema_v1.1.sql · Sprint 1 · Supabase / PostgreSQL 15+
-- ============================================================
-- Execução: SQL Editor do Supabase Dashboard (execução única).
--   A partir do Sprint 2: migrar para Supabase CLI com versionamento.
-- Repositório: salvar este arquivo em /db/schema_v1.1.sql no Git.
--
-- Partes deste arquivo (executar na ordem):
--   1. EXTENSÕES
--   2. TIPOS ENUMERADOS
--   3. FUNÇÕES AUXILIARES (helpers de RLS e triggers)
--   4. TABELAS
--   5. ÍNDICES (incluindo índice espacial GiST para PostGIS)
--   6. MÁQUINA DE ESTADOS (tabela de transições permitidas)
--   7. TRIGGERS
--   8. ROW LEVEL SECURITY
--   9. VIEWS
--  10. SEED DATA
-- ============================================================


-- ============================================================
-- PARTE 1 — EXTENSÕES
-- ============================================================

-- UUID v4 nativo
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- PostGIS: tipos geoespaciais e funções de distância
-- Substitui completamente qualquer cálculo de Haversine.
-- Precisão: esférica (geografia), não plana — correto para GPS.
CREATE EXTENSION IF NOT EXISTS postgis;


-- ============================================================
-- PARTE 2 — TIPOS ENUMERADOS
-- ============================================================

-- Perfil do ator (mapeamento direto dos 4 atores do negócio)
CREATE TYPE perfil_ator_enum AS ENUM (
    'aluno',        -- Ator 1: registra presença
    'supervisor',   -- Ator 2: valida presença
    'professor',    -- Ator 3: abona e ratifica
    'coordenacao'   -- Ator 4: administração geral
);

-- Tipo de turno (AC-008-2)
-- ATENÇÃO: '12h' é serializado como 'doze_horas' no banco.
-- O backend (Supabase SDK) mapeia 'doze_horas' <-> '12h' na API.
-- Identificadores ENUM não devem iniciar com dígito.
CREATE TYPE tipo_turno_enum AS ENUM (
    'manha',
    'tarde',
    'noite',
    'doze_horas'   -- exposto como '12h' na API
);

-- Estados da máquina de frequência
-- Toda transição é controlada pelo trigger trg_valida_transicao_status.
CREATE TYPE status_frequencia_enum AS ENUM (
    'pendente_validacao',       -- estado inicial (Ator 1 registrou)
    'validado',                 -- Ator 2 confirmou
    'rejeitado',                -- Ator 2 negou OU Ator 3/4 recusou abono
    'ausente',                  -- aluno não registrou presença
    'abonado_pend_ratificacao', -- Ator 2/3 abonó a falta
    'ratificado'                -- Ator 3/4 ratificou — estado terminal
);

-- Decisão na ratificação
CREATE TYPE decisao_ratificacao_enum AS ENUM (
    'ratificado',
    'recusado'
);

-- Etapa em que a rejeição ocorreu (para audit trail)
CREATE TYPE etapa_rejeicao_enum AS ENUM (
    'validacao',    -- Ator 2 rejeitou o registro original
    'ratificacao'   -- Ator 3/4 recusou o abono
);


-- ============================================================
-- PARTE 3 — FUNÇÕES AUXILIARES
-- ============================================================

-- Retorna o perfil do usuário autenticado atual.
-- SECURITY DEFINER: executa com privilégios do owner (postgres),
-- evitando recursão nas policies RLS que consultam a própria tabela usuarios.
-- SET search_path = public: previne search_path injection.
CREATE OR REPLACE FUNCTION fn_perfil_usuario_atual()
RETURNS perfil_ator_enum
SECURITY DEFINER
SET search_path = public
LANGUAGE SQL STABLE AS $$
    SELECT perfil
    FROM public.usuarios
    WHERE id = auth.uid()
      AND ativo = true
      AND deleted_at IS NULL
    LIMIT 1
$$;

-- Verifica se o usuário atual é supervisor ativo de um campo específico.
-- Usado nas policies RLS de frequencias e abonos.
CREATE OR REPLACE FUNCTION fn_e_supervisor_do_campo(p_campo_id UUID)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE SQL STABLE AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.supervisor_campos
        WHERE supervisor_id = auth.uid()
          AND campo_id = p_campo_id
          AND deleted_at IS NULL
          AND data_inicio <= CURRENT_DATE
          AND (data_fim IS NULL OR data_fim >= CURRENT_DATE)
    )
$$;

-- Valida e calcula a distância GPS usando PostGIS.
-- Retorna a distância em metros entre um ponto GPS e o centro de um campo.
-- ST_MakePoint recebe (longitude, latitude) — ordem GIS padrão.
-- ::geography usa cálculo esférico (preciso para distâncias reais em metros).
CREATE OR REPLACE FUNCTION fn_distancia_ao_campo(
    p_lat   DECIMAL(9,6),
    p_lng   DECIMAL(9,6),
    p_campo_id UUID
)
RETURNS DECIMAL(8,2)
SECURITY DEFINER
SET search_path = public, topology
LANGUAGE SQL STABLE AS $$
    SELECT ST_Distance(
        ST_MakePoint(p_lng, p_lat)::geography,
        geom
    )::DECIMAL(8,2)
    FROM public.campos_estagio
    WHERE id = p_campo_id
      AND ativo = true
      AND deleted_at IS NULL
    LIMIT 1
$$;

-- Verifica se um ponto GPS está dentro do raio de um campo.
-- Equivalente a: distancia_ao_campo <= raio_metros.
-- ST_DWithin é otimizado com índice GiST — mais eficiente que ST_Distance+comparação.
CREATE OR REPLACE FUNCTION fn_dentro_do_campo(
    p_lat   DECIMAL(9,6),
    p_lng   DECIMAL(9,6),
    p_campo_id UUID
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public, topology
LANGUAGE SQL STABLE AS $$
    SELECT ST_DWithin(
        ST_MakePoint(p_lng, p_lat)::geography,
        geom,
        raio_metros
    )
    FROM public.campos_estagio
    WHERE id = p_campo_id
      AND ativo = true
      AND deleted_at IS NULL
    LIMIT 1
$$;

-- Trigger helper: seta updated_at = NOW() automaticamente.
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


-- ============================================================
-- PARTE 4 — TABELAS
-- (ordem topológica: sem FK quebrada)
-- ============================================================

-- ── 4.1 USUARIOS ─────────────────────────────────────────────
-- Vinculada ao Supabase Auth (auth.users).
-- usuarios.id = auth.users.id — mesmo UUID.
-- O processo de criação de usuário deve criar entrada em AMBAS as tabelas.
CREATE TABLE IF NOT EXISTS public.usuarios (
    id              UUID            PRIMARY KEY
                    REFERENCES auth.users(id),
    -- id vem do Supabase Auth, não gerado aqui.

    cpf             VARCHAR(11)     NOT NULL UNIQUE,
    -- Apenas dígitos, sem formatação.
    -- [LGPD] Dado pessoal — acesso via RLS.

    nome            VARCHAR(255)    NOT NULL,
    email           VARCHAR(255)    UNIQUE,
    -- Nullable: alunos sem e-mail institucional.

    perfil          perfil_ator_enum NOT NULL,
    -- Redundante com app_metadata do Supabase Auth para conveniência de queries.
    -- Mantido em sincronia via trigger ou processo de atualização.

    ativo           BOOLEAN         NOT NULL DEFAULT true,
    tentativas_login SMALLINT       NOT NULL DEFAULT 0,
    bloqueado_ate   TIMESTAMPTZ,
    -- AC-001-3: bloqueio de 5 min após 3 tentativas falhas.

    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by      UUID            REFERENCES public.usuarios(id),
    updated_by      UUID            REFERENCES public.usuarios(id),
    deleted_at      TIMESTAMPTZ
);

-- ── 4.2 SESSOES ──────────────────────────────────────────────
-- Controle de JWTs emitidos. Complementa o gerenciamento de sessão do Supabase Auth.
CREATE TABLE IF NOT EXISTS public.sessoes (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id      UUID            NOT NULL REFERENCES public.usuarios(id),
    token_hash      VARCHAR(255)    NOT NULL UNIQUE,
    -- [SecOps] Hash SHA-256 do JWT. Nunca o token em si.

    criado_em       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    expira_em       TIMESTAMPTZ     NOT NULL,
    -- AC-001-4: 8h de inatividade.

    revogada        BOOLEAN         NOT NULL DEFAULT false,
    revogada_em     TIMESTAMPTZ,
    -- AC-001-5: logout seta revogada = true.

    ip_origem       INET,
    -- [LGPD] IP é dado pessoal — retenção conforme política SecOps.
    user_agent      TEXT,

    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by      UUID            REFERENCES public.usuarios(id),
    updated_by      UUID            REFERENCES public.usuarios(id)
    -- Sem deleted_at: revogada=true é o estado final.
);

-- ── 4.3 CAMPOS_ESTAGIO ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.campos_estagio (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    nome            VARCHAR(255)    NOT NULL,
    endereco        TEXT            NOT NULL,

    -- Coordenadas do centro do campo (dado INSTITUCIONAL — sem restrição LGPD)
    -- ATENÇÃO: ST_MakePoint usa (longitude, latitude) — ordem GIS padrão.
    latitude        DECIMAL(9,6)    NOT NULL
                    CHECK (latitude  BETWEEN -90  AND 90),
    longitude       DECIMAL(9,6)    NOT NULL
                    CHECK (longitude BETWEEN -180 AND 180),
    raio_metros     INTEGER         NOT NULL
                    CHECK (raio_metros > 0),

    -- Coluna geoespacial calculada (mantida sincronizada via trigger)
    -- Usada por ST_DWithin e ST_Distance — requer índice GiST.
    geom            GEOGRAPHY(POINT, 4326),

    ativo           BOOLEAN         NOT NULL DEFAULT true,
    -- AC-008-4: false = campo não aparece para Ator 1.
    -- Semântica diferente de deleted_at:
    --   ativo=false: suspenso temporariamente (recuperável)
    --   deleted_at IS NOT NULL: excluído permanentemente

    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by      UUID            NOT NULL REFERENCES public.usuarios(id),
    updated_by      UUID            REFERENCES public.usuarios(id),
    deleted_at      TIMESTAMPTZ
);

-- ── 4.4 TURNOS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.turnos (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    campo_id        UUID            NOT NULL REFERENCES public.campos_estagio(id),
    tipo            tipo_turno_enum NOT NULL,
    hora_inicio     TIME            NOT NULL,
    hora_fim        TIME            NOT NULL,

    -- Dias da semana como bitmask INTEGER (portável entre engines)
    -- Bit 0 (valor   1) = Domingo
    -- Bit 1 (valor   2) = Segunda-feira
    -- Bit 2 (valor   4) = Terça-feira
    -- Bit 3 (valor   8) = Quarta-feira
    -- Bit 4 (valor  16) = Quinta-feira
    -- Bit 5 (valor  32) = Sexta-feira
    -- Bit 6 (valor  64) = Sábado
    -- Exemplos: Seg–Sex = 62 | Seg+Qua+Sex = 42 | Todos = 127
    dias_semana     SMALLINT        NOT NULL
                    CHECK (dias_semana > 0 AND dias_semana <= 127),

    atravessa_meia_noite BOOLEAN    NOT NULL DEFAULT false,
    -- TRUE quando hora_fim < hora_inicio (ex: 22:00–06:00).
    -- Lógica de validação de janela usa OR quando true.

    ativo           BOOLEAN         NOT NULL DEFAULT true,

    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by      UUID            NOT NULL REFERENCES public.usuarios(id),
    updated_by      UUID            REFERENCES public.usuarios(id),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT chk_turno_horario CHECK (
        atravessa_meia_noite = true OR hora_inicio < hora_fim
    )
);

-- ── 4.5 SUPERVISOR_CAMPOS ────────────────────────────────────
-- Vínculo Ator 2 (supervisor) ↔ campo de estágio.
-- [PO/BA] Entidade adicionada para resolver AC-003-1.
-- Confirmar: um supervisor pode ter múltiplos campos? (assumido: sim)
CREATE TABLE IF NOT EXISTS public.supervisor_campos (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    supervisor_id   UUID            NOT NULL REFERENCES public.usuarios(id),
    -- Perfil 'supervisor' enforçado via trigger trg_valida_perfil_supervisor.
    campo_id        UUID            NOT NULL REFERENCES public.campos_estagio(id),
    data_inicio     DATE            NOT NULL,
    data_fim        DATE,
    -- NULL = vínculo aberto (sem previsão de encerramento).

    UNIQUE (supervisor_id, campo_id, data_inicio),

    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by      UUID            NOT NULL REFERENCES public.usuarios(id),
    updated_by      UUID            REFERENCES public.usuarios(id),
    deleted_at      TIMESTAMPTZ
);

-- ── 4.6 ALOCACOES_ALUNOS ─────────────────────────────────────
-- Define quais alunos estão alocados em quais campos/turnos e em que período.
CREATE TABLE IF NOT EXISTS public.alocacoes_alunos (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    aluno_id        UUID            NOT NULL REFERENCES public.usuarios(id),
    -- Perfil 'aluno' enforçado via trigger trg_valida_perfil_aluno.
    campo_id        UUID            NOT NULL REFERENCES public.campos_estagio(id),
    turno_id        UUID            NOT NULL REFERENCES public.turnos(id),
    -- turno_id deve pertencer ao campo_id — enforçado via trigger.
    data_inicio     DATE            NOT NULL,
    data_fim        DATE,

    UNIQUE (aluno_id, turno_id, data_inicio),

    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by      UUID            NOT NULL REFERENCES public.usuarios(id),
    updated_by      UUID            REFERENCES public.usuarios(id),
    deleted_at      TIMESTAMPTZ
);

-- ── 4.7 FREQUENCIAS (tabela central) ─────────────────────────
CREATE TABLE IF NOT EXISTS public.frequencias (
    id              UUID                    PRIMARY KEY DEFAULT gen_random_uuid(),
    aluno_id        UUID                    NOT NULL REFERENCES public.usuarios(id),
    alocacao_id     UUID                    NOT NULL REFERENCES public.alocacoes_alunos(id),
    turno_id        UUID                    NOT NULL REFERENCES public.turnos(id),
    -- [D1] Desnormalizado de alocacao_id.turno_id para performance de queries.
    -- Consistência enforçada via trigger trg_valida_turno_alocacao.

    data_registro   DATE                    NOT NULL,
    -- Data da presença. Pode diferir do dia do timestamp_servidor
    -- para turnos noturnos que atravessam meia-noite.

    timestamp_servidor TIMESTAMPTZ          NOT NULL,
    -- Gerado pelo Supabase no recebimento. Fonte de verdade. (AC-002-6)
    timestamp_cliente  TIMESTAMPTZ,
    -- NULL para registros online.
    -- Preenchido para registros offline com o timestamp do dispositivo. (AC-002-9)
    sincronizado_em    TIMESTAMPTZ,
    -- NULL para online. Preenchido quando registro offline foi enviado.
    origem_offline     BOOLEAN              NOT NULL DEFAULT false,

    -- Localização do aluno no momento do registro — DADO PESSOAL (LGPD)
    -- [SecOps] Requer: base legal, política de retenção, controle de acesso.
    lat_registro    DECIMAL(9,6),
    -- NULL quando gps_disponivel = false.
    lng_registro    DECIMAL(9,6),
    -- NULL quando gps_disponivel = false.
    gps_disponivel  BOOLEAN                 NOT NULL DEFAULT true,
    gps_precisao_metros DECIMAL(8,2),
    -- Precisão reportada pelo dispositivo. Precisão > 150m → gps_disponivel = false.
    distancia_metros DECIMAL(8,2),
    -- [D3] Calculado pelo backend via fn_distancia_ao_campo().
    -- NULL quando gps_disponivel = false.

    status          status_frequencia_enum  NOT NULL DEFAULT 'pendente_validacao',
    -- Toda transição controlada por trg_valida_transicao_status.

    created_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    created_by      UUID                    NOT NULL REFERENCES public.usuarios(id),
    updated_by      UUID                    REFERENCES public.usuarios(id),
    deleted_at      TIMESTAMPTZ,

    UNIQUE (aluno_id, alocacao_id, data_registro),
    -- AC-002-7: um registro por aluno/alocação/dia.

    CONSTRAINT chk_gps_coords CHECK (
        (gps_disponivel = true  AND lat_registro IS NOT NULL AND lng_registro IS NOT NULL)
        OR
        (gps_disponivel = false AND lat_registro IS NULL     AND lng_registro IS NULL)
    )
);

-- ── 4.8 ABONOS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.abonos (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    frequencia_id   UUID            NOT NULL REFERENCES public.frequencias(id) UNIQUE,
    -- UNIQUE: apenas um abono ativo por frequência.
    abonado_por     UUID            NOT NULL REFERENCES public.usuarios(id),
    -- Perfil 'supervisor' ou 'professor' — enforçado via trigger.
    justificativa   TEXT            NOT NULL
                    CHECK (LENGTH(TRIM(justificativa)) >= 50),
    -- AC-004-2: mínimo 50 caracteres.

    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by      UUID            NOT NULL REFERENCES public.usuarios(id),
    updated_by      UUID            REFERENCES public.usuarios(id),
    deleted_at      TIMESTAMPTZ
);

-- ── 4.9 DOCUMENTOS_ABONO ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.documentos_abono (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    abono_id            UUID            NOT NULL REFERENCES public.abonos(id),
    nome_arquivo        VARCHAR(255)    NOT NULL,
    caminho_referencia  TEXT            NOT NULL,
    -- Path no Supabase Storage. NUNCA URL pública direta.
    -- Acesso via presigned URLs com expiração (geradas pelo backend).
    -- [SecOps] Bucket privado obrigatório.
    mime_type           VARCHAR(127)    NOT NULL
                        CHECK (mime_type IN ('application/pdf', 'image/jpeg', 'image/png')),
    tamanho_bytes       INTEGER         NOT NULL
                        CHECK (tamanho_bytes > 0 AND tamanho_bytes <= 5242880),
    -- AC-004-2: máximo 5 MB.

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          UUID            NOT NULL REFERENCES public.usuarios(id),
    updated_by          UUID            REFERENCES public.usuarios(id),
    deleted_at          TIMESTAMPTZ
);

-- ── 4.10 REJEICOES ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.rejeicoes (
    id              UUID                    PRIMARY KEY DEFAULT gen_random_uuid(),
    frequencia_id   UUID                    NOT NULL REFERENCES public.frequencias(id),
    -- Sem UNIQUE: pode haver rejeição na validação E na ratificação.
    rejeitado_por   UUID                    NOT NULL REFERENCES public.usuarios(id),
    etapa           etapa_rejeicao_enum     NOT NULL,
    justificativa   TEXT                    NOT NULL
                    CHECK (LENGTH(TRIM(justificativa)) >= 20),
    -- AC-003-3 e AC-005-3: mínimo 20 caracteres.

    created_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    created_by      UUID                    NOT NULL REFERENCES public.usuarios(id),
    updated_by      UUID                    REFERENCES public.usuarios(id),
    deleted_at      TIMESTAMPTZ
);

-- ── 4.11 RATIFICACOES ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ratificacoes (
    id              UUID                        PRIMARY KEY DEFAULT gen_random_uuid(),
    frequencia_id   UUID                        NOT NULL REFERENCES public.frequencias(id) UNIQUE,
    -- UNIQUE: estado terminal. Uma frequência tem no máximo uma ratificação.
    ratificado_por  UUID                        NOT NULL REFERENCES public.usuarios(id),
    -- Perfil 'professor' ou 'coordenacao' — enforçado via trigger.
    decisao         decisao_ratificacao_enum    NOT NULL,
    justificativa   TEXT,
    -- Obrigatória quando decisao = 'recusado'. (AC-005-3)

    CONSTRAINT chk_justificativa_recusa CHECK (
        decisao = 'ratificado'
        OR (decisao = 'recusado' AND LENGTH(TRIM(COALESCE(justificativa, ''))) >= 20)
    ),

    created_at      TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    created_by      UUID                        NOT NULL REFERENCES public.usuarios(id),
    updated_by      UUID                        REFERENCES public.usuarios(id),
    deleted_at      TIMESTAMPTZ
);

-- ── 4.12 FREQUENCIAS_HISTORICO_STATUS ────────────────────────
-- Registra cada transição de status. Imutável por design.
-- Necessário para AC-006-5 (trilha completa de auditoria).
CREATE TABLE IF NOT EXISTS public.frequencias_historico_status (
    id              UUID                    PRIMARY KEY DEFAULT gen_random_uuid(),
    frequencia_id   UUID                    NOT NULL REFERENCES public.frequencias(id),
    status_anterior status_frequencia_enum,
    -- NULL na inserção inicial (sem estado anterior).
    status_novo     status_frequencia_enum  NOT NULL,
    alterado_por    UUID                    NOT NULL REFERENCES public.usuarios(id),
    alterado_em     TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    referencia_tipo VARCHAR(50),
    -- 'abono', 'rejeicao', 'ratificacao' — que evento causou a mudança.
    referencia_id   UUID
    -- ID do objeto correspondente.
    -- Sem deleted_at, created_by, updated_by: histórico é imutável.
);

-- ── 4.13 NOTIFICACOES ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notificacoes (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    destinatario_id     UUID            NOT NULL REFERENCES public.usuarios(id),
    tipo                VARCHAR(100)    NOT NULL,
    -- Tipos Sprint 1: 'freq_rejeitada', 'freq_abonada', 'freq_ratificada',
    -- 'freq_pendente_validacao', 'freq_gps_indisponivel',
    -- 'abono_pendente_ratificacao', 'alerta_frequencia_baixa'
    titulo              VARCHAR(255)    NOT NULL,
    corpo               TEXT            NOT NULL,
    referencia_tipo     VARCHAR(50),
    referencia_id       UUID,
    -- Sem FK: notificação persiste mesmo com soft delete do objeto relacionado.
    lida                BOOLEAN         NOT NULL DEFAULT false,
    lida_em             TIMESTAMPTZ,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          UUID            NOT NULL REFERENCES public.usuarios(id),
    updated_by          UUID            REFERENCES public.usuarios(id),
    deleted_at          TIMESTAMPTZ
);

-- ── 4.14 CONFIGURACOES ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.configuracoes (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    chave           VARCHAR(100)    NOT NULL UNIQUE,
    valor           TEXT            NOT NULL,
    descricao       TEXT,
    escopo_id       UUID            REFERENCES public.campos_estagio(id),
    -- NULL = global. Preenchido = configuração específica para um campo.

    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by      UUID            REFERENCES public.usuarios(id),
    updated_by      UUID            REFERENCES public.usuarios(id),
    deleted_at      TIMESTAMPTZ
);


-- ============================================================
-- PARTE 5 — ÍNDICES
-- ============================================================

-- usuarios
CREATE INDEX IF NOT EXISTS idx_usuarios_cpf
    ON public.usuarios(cpf)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_usuarios_perfil
    ON public.usuarios(perfil)
    WHERE deleted_at IS NULL AND ativo = true;

-- sessoes
CREATE INDEX IF NOT EXISTS idx_sessoes_usuario_id
    ON public.sessoes(usuario_id);

CREATE INDEX IF NOT EXISTS idx_sessoes_token_hash
    ON public.sessoes(token_hash)
    WHERE revogada = false;
-- Índice parcial: apenas sessões ativas. Consulta crítica em toda requisição.

CREATE INDEX IF NOT EXISTS idx_sessoes_expira_em
    ON public.sessoes(expira_em)
    WHERE revogada = false;

-- campos_estagio
CREATE INDEX IF NOT EXISTS idx_campos_estagio_ativos
    ON public.campos_estagio(id)
    WHERE ativo = true AND deleted_at IS NULL;

-- Índice espacial GiST — necessário para ST_DWithin e ST_Distance com performance.
-- Sem este índice, validação GPS seria full scan.
CREATE INDEX IF NOT EXISTS idx_campos_estagio_geom
    ON public.campos_estagio USING GIST (geom);

-- turnos
CREATE INDEX IF NOT EXISTS idx_turnos_campo_id
    ON public.turnos(campo_id)
    WHERE deleted_at IS NULL AND ativo = true;

-- supervisor_campos
CREATE INDEX IF NOT EXISTS idx_supervisor_campos_supervisor
    ON public.supervisor_campos(supervisor_id)
    WHERE deleted_at IS NULL AND (data_fim IS NULL OR data_fim >= CURRENT_DATE);

CREATE INDEX IF NOT EXISTS idx_supervisor_campos_campo
    ON public.supervisor_campos(campo_id)
    WHERE deleted_at IS NULL;

-- alocacoes_alunos
CREATE INDEX IF NOT EXISTS idx_alocacoes_aluno_periodo
    ON public.alocacoes_alunos(aluno_id, data_inicio, data_fim)
    WHERE deleted_at IS NULL;
-- Consulta crítica: "aluno X está alocado hoje?" (AC-002-2)

CREATE INDEX IF NOT EXISTS idx_alocacoes_campo_ativo
    ON public.alocacoes_alunos(campo_id)
    WHERE deleted_at IS NULL AND (data_fim IS NULL OR data_fim >= CURRENT_DATE);

-- frequencias — índices de acesso crítico
CREATE INDEX IF NOT EXISTS idx_freq_aluno_data
    ON public.frequencias(aluno_id, data_registro DESC)
    WHERE deleted_at IS NULL;
-- AC-006-1: histórico cronológico do aluno.

CREATE INDEX IF NOT EXISTS idx_freq_alocacao_status
    ON public.frequencias(alocacao_id, status)
    WHERE deleted_at IS NULL;
-- AC-003-1: pendentes de validação do setor.

CREATE INDEX IF NOT EXISTS idx_freq_turno_status
    ON public.frequencias(turno_id, status)
    WHERE deleted_at IS NULL;
-- Consultas de validação por turno.

CREATE INDEX IF NOT EXISTS idx_freq_status
    ON public.frequencias(status)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_freq_data_status
    ON public.frequencias(data_registro DESC, status)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_freq_offline_pendentes
    ON public.frequencias(origem_offline, sincronizado_em)
    WHERE origem_offline = true AND sincronizado_em IS NULL;

-- frequencias_historico_status
CREATE INDEX IF NOT EXISTS idx_freq_historico_frequencia
    ON public.frequencias_historico_status(frequencia_id, alterado_em DESC);

-- notificacoes
CREATE INDEX IF NOT EXISTS idx_notif_nao_lidas
    ON public.notificacoes(destinatario_id, created_at DESC)
    WHERE lida = false AND deleted_at IS NULL;
-- Consulta mais frequente: badge de não lidas.

CREATE INDEX IF NOT EXISTS idx_notif_todas
    ON public.notificacoes(destinatario_id, created_at DESC)
    WHERE deleted_at IS NULL;

-- abonos
CREATE INDEX IF NOT EXISTS idx_abonos_frequencia
    ON public.abonos(frequencia_id)
    WHERE deleted_at IS NULL;

-- documentos_abono
CREATE INDEX IF NOT EXISTS idx_docs_abono_abono
    ON public.documentos_abono(abono_id)
    WHERE deleted_at IS NULL;

-- rejeicoes
CREATE INDEX IF NOT EXISTS idx_rejeicoes_frequencia
    ON public.rejeicoes(frequencia_id)
    WHERE deleted_at IS NULL;


-- ============================================================
-- PARTE 6 — MÁQUINA DE ESTADOS
-- (tabela de transições permitidas — enforçada via trigger)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.transicoes_status_permitidas (
    status_atual    status_frequencia_enum  NOT NULL,
    status_proximo  status_frequencia_enum  NOT NULL,
    PRIMARY KEY (status_atual, status_proximo)
);

-- Este INSERT é idempotente se executado após ON CONFLICT DO NOTHING.
INSERT INTO public.transicoes_status_permitidas (status_atual, status_proximo)
VALUES
    -- Ator 1 registrou → Ator 2 decide
    ('pendente_validacao',       'validado'),
    ('pendente_validacao',       'rejeitado'),
    -- Ator 2/3 abona a falta ou rejeição
    ('rejeitado',                'abonado_pend_ratificacao'),
    ('ausente',                  'abonado_pend_ratificacao'),
    -- Ator 3/4 ratifica ou recusa o abono
    ('abonado_pend_ratificacao', 'ratificado'),
    ('abonado_pend_ratificacao', 'rejeitado')
ON CONFLICT (status_atual, status_proximo) DO NOTHING;


-- ============================================================
-- PARTE 7 — TRIGGERS
-- ============================================================

-- ── 7.1 GEOM: sincroniza coluna geoespacial com lat/lng ──────
CREATE OR REPLACE FUNCTION fn_sync_campo_geom()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    -- ST_MakePoint(longitude, latitude) — longitude PRIMEIRO (padrão GIS/WGS84)
    NEW.geom = ST_MakePoint(NEW.longitude, NEW.latitude)::geography;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_sync_campo_geom
    BEFORE INSERT OR UPDATE OF latitude, longitude
    ON public.campos_estagio
    FOR EACH ROW
    EXECUTE FUNCTION fn_sync_campo_geom();


-- ── 7.2 MÁQUINA DE ESTADOS: valida transição de status ───────
CREATE OR REPLACE FUNCTION fn_valida_transicao_status()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status = NEW.status THEN
        RETURN NEW; -- sem mudança, permite UPDATE de outros campos
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.transicoes_status_permitidas
        WHERE status_atual   = OLD.status
          AND status_proximo  = NEW.status
    ) THEN
        RAISE EXCEPTION
            'SCI: transição de status inválida em frequencias: [%] → [%]. '
            'Consulte transicoes_status_permitidas.',
            OLD.status, NEW.status;
    END IF;

    -- Registrar no histórico
    INSERT INTO public.frequencias_historico_status
        (frequencia_id, status_anterior, status_novo, alterado_por, alterado_em)
    VALUES
        (NEW.id, OLD.status, NEW.status, COALESCE(NEW.updated_by, NEW.created_by), NOW());

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_valida_transicao_status
    BEFORE UPDATE OF status
    ON public.frequencias
    FOR EACH ROW
    EXECUTE FUNCTION fn_valida_transicao_status();

-- Captura inserção inicial no histórico
CREATE OR REPLACE FUNCTION fn_registra_status_inicial()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO public.frequencias_historico_status
        (frequencia_id, status_anterior, status_novo, alterado_por, alterado_em)
    VALUES
        (NEW.id, NULL, NEW.status, NEW.created_by, NOW());
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_registra_status_inicial
    AFTER INSERT
    ON public.frequencias
    FOR EACH ROW
    EXECUTE FUNCTION fn_registra_status_inicial();


-- ── 7.3 CONSISTÊNCIA: turno_id de frequencias ────────────────
CREATE OR REPLACE FUNCTION fn_valida_turno_alocacao()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.alocacoes_alunos
        WHERE id = NEW.alocacao_id AND turno_id = NEW.turno_id
    ) THEN
        RAISE EXCEPTION
            'SCI: frequencias.turno_id (%) não corresponde ao turno da alocacao_id (%). '
            'Ambos devem referenciar o mesmo turno.',
            NEW.turno_id, NEW.alocacao_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_valida_turno_alocacao
    BEFORE INSERT OR UPDATE OF turno_id, alocacao_id
    ON public.frequencias
    FOR EACH ROW
    EXECUTE FUNCTION fn_valida_turno_alocacao();


-- ── 7.4 PERFIS: enforça perfil correto por tabela ─────────────
CREATE OR REPLACE FUNCTION fn_valida_perfil_aluno()
RETURNS TRIGGER
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

CREATE OR REPLACE TRIGGER trg_valida_perfil_aluno
    BEFORE INSERT OR UPDATE OF aluno_id ON public.alocacoes_alunos
    FOR EACH ROW EXECUTE FUNCTION fn_valida_perfil_aluno();

-- ---

CREATE OR REPLACE FUNCTION fn_valida_perfil_supervisor()
RETURNS TRIGGER
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

CREATE OR REPLACE TRIGGER trg_valida_perfil_supervisor
    BEFORE INSERT OR UPDATE OF supervisor_id ON public.supervisor_campos
    FOR EACH ROW EXECUTE FUNCTION fn_valida_perfil_supervisor();

-- ---

CREATE OR REPLACE FUNCTION fn_valida_perfil_abonador()
RETURNS TRIGGER
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

CREATE OR REPLACE TRIGGER trg_valida_perfil_abonador
    BEFORE INSERT ON public.abonos
    FOR EACH ROW EXECUTE FUNCTION fn_valida_perfil_abonador();

-- ---

CREATE OR REPLACE FUNCTION fn_valida_perfil_ratificador()
RETURNS TRIGGER
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

CREATE OR REPLACE TRIGGER trg_valida_perfil_ratificador
    BEFORE INSERT ON public.ratificacoes
    FOR EACH ROW EXECUTE FUNCTION fn_valida_perfil_ratificador();


-- ── 7.5 CONSISTÊNCIA: turno pertence ao campo da alocação ─────
CREATE OR REPLACE FUNCTION fn_valida_turno_campo_alocacao()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.turnos
        WHERE id = NEW.turno_id
          AND campo_id = NEW.campo_id
          AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'SCI: turno_id (%) não pertence ao campo_id (%) na alocação.',
            NEW.turno_id, NEW.campo_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_valida_turno_campo_alocacao
    BEFORE INSERT OR UPDATE ON public.alocacoes_alunos
    FOR EACH ROW EXECUTE FUNCTION fn_valida_turno_campo_alocacao();


-- ── 7.6 updated_at automático (todas as tabelas com o campo) ──
-- Instanciar para cada tabela com campo updated_at.

CREATE OR REPLACE TRIGGER trg_usuarios_updated_at
    BEFORE UPDATE ON public.usuarios
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE OR REPLACE TRIGGER trg_sessoes_updated_at
    BEFORE UPDATE ON public.sessoes
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE OR REPLACE TRIGGER trg_campos_updated_at
    BEFORE UPDATE ON public.campos_estagio
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE OR REPLACE TRIGGER trg_turnos_updated_at
    BEFORE UPDATE ON public.turnos
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE OR REPLACE TRIGGER trg_supervisor_campos_updated_at
    BEFORE UPDATE ON public.supervisor_campos
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE OR REPLACE TRIGGER trg_alocacoes_updated_at
    BEFORE UPDATE ON public.alocacoes_alunos
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE OR REPLACE TRIGGER trg_frequencias_updated_at
    BEFORE UPDATE ON public.frequencias
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE OR REPLACE TRIGGER trg_abonos_updated_at
    BEFORE UPDATE ON public.abonos
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE OR REPLACE TRIGGER trg_docs_abono_updated_at
    BEFORE UPDATE ON public.documentos_abono
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE OR REPLACE TRIGGER trg_rejeicoes_updated_at
    BEFORE UPDATE ON public.rejeicoes
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE OR REPLACE TRIGGER trg_ratificacoes_updated_at
    BEFORE UPDATE ON public.ratificacoes
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE OR REPLACE TRIGGER trg_notificacoes_updated_at
    BEFORE UPDATE ON public.notificacoes
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE OR REPLACE TRIGGER trg_configuracoes_updated_at
    BEFORE UPDATE ON public.configuracoes
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();


-- ============================================================
-- PARTE 8 — ROW LEVEL SECURITY (RLS)
-- ============================================================
-- Estratégia de implementação:
--   SELECT / INSERT: policies por role de usuário (auth.uid() + fn_perfil_usuario_atual())
--   UPDATE de status: via RPCs com SECURITY DEFINER (garante máquina de estados)
--   DELETE: apenas soft delete (UPDATE de deleted_at) com policies de UPDATE
--
-- O Supabase service_role bypassa RLS — usado apenas em operações administrativas
-- controladas (ex: jobs de background, seed, admin dashboard).
--
-- Princípio: cada ator vê apenas o que precisa para suas responsabilidades.
-- Menor privilégio possível em cada policy.
-- ============================================================

-- ── USUARIOS ─────────────────────────────────────────────────
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

-- Usuário vê apenas o próprio registro completo
CREATE POLICY "usuarios: select self"
    ON public.usuarios FOR SELECT
    USING (id = auth.uid());

-- Supervisores e professores veem nome + perfil dos alunos (sem CPF/email)
-- Implementado via view vw_usuarios_publico (abaixo).
-- Para a tabela base: apenas coordenação vê todos.
CREATE POLICY "usuarios: select coordenacao"
    ON public.usuarios FOR SELECT
    USING (fn_perfil_usuario_atual() = 'coordenacao');

-- Coordenação cria usuários
CREATE POLICY "usuarios: insert coordenacao"
    ON public.usuarios FOR INSERT
    WITH CHECK (fn_perfil_usuario_atual() = 'coordenacao');

-- Usuário atualiza próprio registro (ex: senha via Supabase Auth)
CREATE POLICY "usuarios: update self"
    ON public.usuarios FOR UPDATE
    USING (id = auth.uid());

-- Coordenação atualiza qualquer usuário
CREATE POLICY "usuarios: update coordenacao"
    ON public.usuarios FOR UPDATE
    USING (fn_perfil_usuario_atual() = 'coordenacao');


-- ── SESSOES ───────────────────────────────────────────────────
ALTER TABLE public.sessoes ENABLE ROW LEVEL SECURITY;

-- Usuário vê apenas as próprias sessões
CREATE POLICY "sessoes: select self"
    ON public.sessoes FOR SELECT
    USING (usuario_id = auth.uid());

-- Backend (service_role) gerencia sessões — sem policy de INSERT/UPDATE para usuários


-- ── CAMPOS_ESTAGIO ────────────────────────────────────────────
ALTER TABLE public.campos_estagio ENABLE ROW LEVEL SECURITY;

-- Todos os atores autenticados veem campos ativos
CREATE POLICY "campos: select todos ativos"
    ON public.campos_estagio FOR SELECT
    USING (auth.uid() IS NOT NULL AND ativo = true AND deleted_at IS NULL);

-- Coordenação vê também campos inativos/deletados (para gestão)
CREATE POLICY "campos: select coordenacao completo"
    ON public.campos_estagio FOR SELECT
    USING (fn_perfil_usuario_atual() = 'coordenacao');

-- Apenas coordenação cria e modifica campos
CREATE POLICY "campos: insert coordenacao"
    ON public.campos_estagio FOR INSERT
    WITH CHECK (fn_perfil_usuario_atual() = 'coordenacao');

CREATE POLICY "campos: update coordenacao"
    ON public.campos_estagio FOR UPDATE
    USING (fn_perfil_usuario_atual() = 'coordenacao');


-- ── TURNOS ────────────────────────────────────────────────────
ALTER TABLE public.turnos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "turnos: select todos"
    ON public.turnos FOR SELECT
    USING (auth.uid() IS NOT NULL AND deleted_at IS NULL);

CREATE POLICY "turnos: insert coordenacao"
    ON public.turnos FOR INSERT
    WITH CHECK (fn_perfil_usuario_atual() = 'coordenacao');

CREATE POLICY "turnos: update coordenacao"
    ON public.turnos FOR UPDATE
    USING (fn_perfil_usuario_atual() = 'coordenacao');


-- ── SUPERVISOR_CAMPOS ─────────────────────────────────────────
ALTER TABLE public.supervisor_campos ENABLE ROW LEVEL SECURITY;

-- Supervisor vê seus próprios vínculos
CREATE POLICY "supervisor_campos: select supervisor self"
    ON public.supervisor_campos FOR SELECT
    USING (
        supervisor_id = auth.uid()
        AND deleted_at IS NULL
    );

-- Professores e coordenação veem todos os vínculos
CREATE POLICY "supervisor_campos: select prof coordenacao"
    ON public.supervisor_campos FOR SELECT
    USING (fn_perfil_usuario_atual() IN ('professor', 'coordenacao'));

CREATE POLICY "supervisor_campos: insert coordenacao"
    ON public.supervisor_campos FOR INSERT
    WITH CHECK (fn_perfil_usuario_atual() = 'coordenacao');

CREATE POLICY "supervisor_campos: update coordenacao"
    ON public.supervisor_campos FOR UPDATE
    USING (fn_perfil_usuario_atual() = 'coordenacao');


-- ── ALOCACOES_ALUNOS ──────────────────────────────────────────
ALTER TABLE public.alocacoes_alunos ENABLE ROW LEVEL SECURITY;

-- Ator 1: vê apenas as próprias alocações
CREATE POLICY "alocacoes: select aluno self"
    ON public.alocacoes_alunos FOR SELECT
    USING (
        fn_perfil_usuario_atual() = 'aluno'
        AND aluno_id = auth.uid()
        AND deleted_at IS NULL
    );

-- Ator 2: vê alocações de alunos nos seus campos
CREATE POLICY "alocacoes: select supervisor"
    ON public.alocacoes_alunos FOR SELECT
    USING (
        fn_perfil_usuario_atual() = 'supervisor'
        AND fn_e_supervisor_do_campo(campo_id) = true
        AND deleted_at IS NULL
    );

-- Atores 3 e 4: veem todas as alocações
CREATE POLICY "alocacoes: select prof coordenacao"
    ON public.alocacoes_alunos FOR SELECT
    USING (fn_perfil_usuario_atual() IN ('professor', 'coordenacao'));

-- Apenas coordenação cria e modifica alocações
CREATE POLICY "alocacoes: insert coordenacao"
    ON public.alocacoes_alunos FOR INSERT
    WITH CHECK (fn_perfil_usuario_atual() = 'coordenacao');

CREATE POLICY "alocacoes: update coordenacao"
    ON public.alocacoes_alunos FOR UPDATE
    USING (fn_perfil_usuario_atual() = 'coordenacao');


-- ── FREQUENCIAS ───────────────────────────────────────────────
ALTER TABLE public.frequencias ENABLE ROW LEVEL SECURITY;

-- Ator 1: apenas as próprias frequências
CREATE POLICY "freq: select aluno self"
    ON public.frequencias FOR SELECT
    USING (
        fn_perfil_usuario_atual() = 'aluno'
        AND aluno_id = auth.uid()
        AND deleted_at IS NULL
    );

-- Ator 2: frequências de alunos nos seus campos
CREATE POLICY "freq: select supervisor setor"
    ON public.frequencias FOR SELECT
    USING (
        fn_perfil_usuario_atual() = 'supervisor'
        AND deleted_at IS NULL
        AND EXISTS (
            SELECT 1
            FROM public.alocacoes_alunos al
            WHERE al.id = alocacao_id
              AND fn_e_supervisor_do_campo(al.campo_id) = true
        )
    );

-- Atores 3 e 4: visibilidade ampla
CREATE POLICY "freq: select prof coordenacao"
    ON public.frequencias FOR SELECT
    USING (fn_perfil_usuario_atual() IN ('professor', 'coordenacao'));

-- Ator 1: registra apenas a própria frequência (AC-002-1)
CREATE POLICY "freq: insert aluno self"
    ON public.frequencias FOR INSERT
    WITH CHECK (
        fn_perfil_usuario_atual() = 'aluno'
        AND aluno_id = auth.uid()
    );

-- UPDATE de status: policies por transição permitida por role
-- A máquina de estados (trigger) valida a transição específica.
-- O RLS valida QUEM pode fazer cada transição.

-- Ator 2 pode mover de 'pendente_validacao' para 'validado' ou 'rejeitado'
CREATE POLICY "freq: update supervisor validacao"
    ON public.frequencias FOR UPDATE
    USING (
        fn_perfil_usuario_atual() = 'supervisor'
        AND status = 'pendente_validacao'
        AND deleted_at IS NULL
        AND EXISTS (
            SELECT 1 FROM public.alocacoes_alunos al
            WHERE al.id = alocacao_id
              AND fn_e_supervisor_do_campo(al.campo_id) = true
        )
    )
    WITH CHECK (status IN ('validado', 'rejeitado'));

-- Ator 2 e 3 podem mover de 'rejeitado'/'ausente' para 'abonado_pend_ratificacao'
CREATE POLICY "freq: update abono supervisor professor"
    ON public.frequencias FOR UPDATE
    USING (
        fn_perfil_usuario_atual() IN ('supervisor', 'professor')
        AND status IN ('rejeitado', 'ausente')
        AND deleted_at IS NULL
    )
    WITH CHECK (status = 'abonado_pend_ratificacao');

-- Ator 3 e 4 ratificam: 'abonado_pend_ratificacao' → 'ratificado' ou 'rejeitado'
CREATE POLICY "freq: update ratificacao prof coordenacao"
    ON public.frequencias FOR UPDATE
    USING (
        fn_perfil_usuario_atual() IN ('professor', 'coordenacao')
        AND status = 'abonado_pend_ratificacao'
        AND deleted_at IS NULL
    )
    WITH CHECK (status IN ('ratificado', 'rejeitado'));


-- ── ABONOS ────────────────────────────────────────────────────
ALTER TABLE public.abonos ENABLE ROW LEVEL SECURITY;

-- Ator 1 vê o próprio abono (via frequencia)
CREATE POLICY "abonos: select aluno self"
    ON public.abonos FOR SELECT
    USING (
        fn_perfil_usuario_atual() = 'aluno'
        AND EXISTS (
            SELECT 1 FROM public.frequencias f
            WHERE f.id = frequencia_id AND f.aluno_id = auth.uid()
        )
    );

-- Ator 2, 3, 4 veem abonos do seu escopo
CREATE POLICY "abonos: select sup prof coord"
    ON public.abonos FOR SELECT
    USING (fn_perfil_usuario_atual() IN ('supervisor', 'professor', 'coordenacao'));

-- Ator 2 e 3 criam abonos (AC-004)
CREATE POLICY "abonos: insert sup prof"
    ON public.abonos FOR INSERT
    WITH CHECK (fn_perfil_usuario_atual() IN ('supervisor', 'professor'));


-- ── DOCUMENTOS_ABONO ──────────────────────────────────────────
ALTER TABLE public.documentos_abono ENABLE ROW LEVEL SECURITY;

-- Qualquer ator autenticado vê documentos de abonos que tem acesso
-- (acesso herdado via abono → frequencia → scope do ator)
-- Simplificação: Atores 2, 3, 4 veem todos. Ator 1 vê os próprios.
CREATE POLICY "docs_abono: select aluno self"
    ON public.documentos_abono FOR SELECT
    USING (
        fn_perfil_usuario_atual() = 'aluno'
        AND EXISTS (
            SELECT 1
            FROM public.abonos ab
            JOIN public.frequencias f ON f.id = ab.frequencia_id
            WHERE ab.id = abono_id AND f.aluno_id = auth.uid()
        )
    );

CREATE POLICY "docs_abono: select sup prof coord"
    ON public.documentos_abono FOR SELECT
    USING (fn_perfil_usuario_atual() IN ('supervisor', 'professor', 'coordenacao'));

-- Ator 2 e 3 fazem upload de documentos
CREATE POLICY "docs_abono: insert sup prof"
    ON public.documentos_abono FOR INSERT
    WITH CHECK (fn_perfil_usuario_atual() IN ('supervisor', 'professor'));


-- ── REJEICOES ─────────────────────────────────────────────────
ALTER TABLE public.rejeicoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rejeicoes: select aluno self"
    ON public.rejeicoes FOR SELECT
    USING (
        fn_perfil_usuario_atual() = 'aluno'
        AND EXISTS (
            SELECT 1 FROM public.frequencias f
            WHERE f.id = frequencia_id AND f.aluno_id = auth.uid()
        )
    );

CREATE POLICY "rejeicoes: select sup prof coord"
    ON public.rejeicoes FOR SELECT
    USING (fn_perfil_usuario_atual() IN ('supervisor', 'professor', 'coordenacao'));

-- Ator 2 registra rejeição na validação
CREATE POLICY "rejeicoes: insert supervisor validacao"
    ON public.rejeicoes FOR INSERT
    WITH CHECK (
        fn_perfil_usuario_atual() = 'supervisor'
        AND etapa = 'validacao'
    );

-- Atores 3 e 4 registram rejeição na ratificação
CREATE POLICY "rejeicoes: insert prof coord ratificacao"
    ON public.rejeicoes FOR INSERT
    WITH CHECK (
        fn_perfil_usuario_atual() IN ('professor', 'coordenacao')
        AND etapa = 'ratificacao'
    );


-- ── RATIFICACOES ──────────────────────────────────────────────
ALTER TABLE public.ratificacoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ratificacoes: select aluno self"
    ON public.ratificacoes FOR SELECT
    USING (
        fn_perfil_usuario_atual() = 'aluno'
        AND EXISTS (
            SELECT 1 FROM public.frequencias f
            WHERE f.id = frequencia_id AND f.aluno_id = auth.uid()
        )
    );

CREATE POLICY "ratificacoes: select todos"
    ON public.ratificacoes FOR SELECT
    USING (fn_perfil_usuario_atual() IN ('supervisor', 'professor', 'coordenacao'));

CREATE POLICY "ratificacoes: insert prof coord"
    ON public.ratificacoes FOR INSERT
    WITH CHECK (fn_perfil_usuario_atual() IN ('professor', 'coordenacao'));


-- ── FREQUENCIAS_HISTORICO_STATUS ──────────────────────────────
ALTER TABLE public.frequencias_historico_status ENABLE ROW LEVEL SECURITY;

-- Ator 1 vê o histórico das próprias frequências
CREATE POLICY "historico: select aluno self"
    ON public.frequencias_historico_status FOR SELECT
    USING (
        fn_perfil_usuario_atual() = 'aluno'
        AND EXISTS (
            SELECT 1 FROM public.frequencias f
            WHERE f.id = frequencia_id AND f.aluno_id = auth.uid()
        )
    );

-- Demais atores veem o histórico (AC-006-5: trilha completa de auditoria)
CREATE POLICY "historico: select sup prof coord"
    ON public.frequencias_historico_status FOR SELECT
    USING (fn_perfil_usuario_atual() IN ('supervisor', 'professor', 'coordenacao'));

-- INSERT apenas via triggers (service_role) — sem policy de INSERT para usuários


-- ── NOTIFICACOES ──────────────────────────────────────────────
ALTER TABLE public.notificacoes ENABLE ROW LEVEL SECURITY;

-- Cada ator vê apenas as próprias notificações (AC-007)
CREATE POLICY "notificacoes: select self"
    ON public.notificacoes FOR SELECT
    USING (
        destinatario_id = auth.uid()
        AND deleted_at IS NULL
    );

-- Usuário marca como lida / exclui suas notificações
CREATE POLICY "notificacoes: update self"
    ON public.notificacoes FOR UPDATE
    USING (
        destinatario_id = auth.uid()
        AND deleted_at IS NULL
    );

-- INSERT de notificações: via service_role (backend cria notificações)


-- ── CONFIGURACOES ─────────────────────────────────────────────
ALTER TABLE public.configuracoes ENABLE ROW LEVEL SECURITY;

-- Todos os atores autenticados leem configurações
CREATE POLICY "config: select todos"
    ON public.configuracoes FOR SELECT
    USING (auth.uid() IS NOT NULL AND deleted_at IS NULL);

-- Apenas coordenação atualiza configurações
CREATE POLICY "config: update coordenacao"
    ON public.configuracoes FOR UPDATE
    USING (fn_perfil_usuario_atual() = 'coordenacao');


-- ============================================================
-- PARTE 9 — VIEWS
-- ============================================================

-- View pública de usuários (sem CPF, email, senha_hash)
-- Usada por outros atores para exibir nomes sem expor dados sensíveis.
CREATE OR REPLACE VIEW public.vw_usuarios_publico AS
SELECT
    id,
    nome,
    perfil,
    ativo
FROM public.usuarios
WHERE deleted_at IS NULL;
-- RLS da tabela base não se aplica a views por padrão.
-- Acesso controlado pela política de quem executa a query.


-- Alocações ativas hoje (responde AC-002-2)
CREATE OR REPLACE VIEW public.vw_alocacoes_ativas_hoje AS
SELECT
    al.id               AS alocacao_id,
    al.aluno_id,
    al.campo_id,
    al.turno_id,
    ce.nome             AS campo_nome,
    ce.latitude,
    ce.longitude,
    ce.raio_metros,
    t.tipo              AS turno_tipo,
    t.hora_inicio,
    t.hora_fim,
    t.atravessa_meia_noite,
    t.dias_semana       AS dias_semana_bitmask
FROM public.alocacoes_alunos al
JOIN public.campos_estagio ce
    ON ce.id = al.campo_id AND ce.ativo = true AND ce.deleted_at IS NULL
JOIN public.turnos t
    ON t.id = al.turno_id AND t.ativo = true AND t.deleted_at IS NULL
WHERE al.deleted_at IS NULL
  AND al.data_inicio <= CURRENT_DATE
  AND (al.data_fim IS NULL OR al.data_fim >= CURRENT_DATE);
-- Filtro de dia da semana via bitmask no backend:
-- (dias_semana_bitmask & (1 << EXTRACT(DOW FROM CURRENT_DATE)::INT)) > 0
-- DOW: 0=Dom, 1=Seg, ..., 6=Sab — alinhado com definição do bitmask.


-- Pendentes de validação por supervisor (responde AC-003-1)
CREATE OR REPLACE VIEW public.vw_pendentes_supervisor AS
SELECT
    f.id                AS frequencia_id,
    f.aluno_id,
    u.nome              AS aluno_nome,
    f.data_registro,
    f.timestamp_servidor,
    f.gps_disponivel,
    f.distancia_metros,
    f.status,
    al.campo_id,
    ce.nome             AS campo_nome,
    al.turno_id,
    t.tipo              AS turno_tipo,
    sc.supervisor_id,
    -- Distância recalculada via PostGIS para exibição em tempo real (opcional)
    -- Se o campo mudou de coordenadas após o registro, mostra a distância original.
    -- Para recalcular: ST_Distance(ST_MakePoint(f.lng_registro, f.lat_registro)::geography, ce.geom)
    CASE
        WHEN f.gps_disponivel = false THEN NULL
        ELSE f.distancia_metros
    END                 AS distancia_exibida_metros
FROM public.frequencias f
JOIN public.alocacoes_alunos al ON al.id = f.alocacao_id
JOIN public.campos_estagio ce   ON ce.id = al.campo_id
JOIN public.turnos t            ON t.id  = al.turno_id
JOIN public.usuarios u          ON u.id  = f.aluno_id
JOIN public.supervisor_campos sc
    ON sc.campo_id = al.campo_id
   AND sc.deleted_at IS NULL
   AND sc.data_inicio <= CURRENT_DATE
   AND (sc.data_fim IS NULL OR sc.data_fim >= CURRENT_DATE)
WHERE f.status = 'pendente_validacao'
  AND f.deleted_at IS NULL;
-- Ator 2 filtra por: WHERE supervisor_id = auth.uid()


-- Percentual de frequência (responde AC-005-4, AC-005-5, AC-006-1)
CREATE OR REPLACE VIEW public.vw_percentual_frequencia AS
SELECT
    f.aluno_id,
    al.campo_id,
    al.turno_id,
    DATE_TRUNC('month', f.data_registro)::DATE      AS mes_referencia,
    COUNT(*)                                         AS total_registros,
    COUNT(*) FILTER (
        WHERE f.status IN ('validado', 'ratificado')
    )                                                AS presencas_confirmadas,
    COUNT(*) FILTER (WHERE f.status = 'ausente')     AS ausencias,
    ROUND(
        COUNT(*) FILTER (
            WHERE f.status IN ('validado', 'ratificado')
        )::NUMERIC / NULLIF(COUNT(*), 0) * 100,
        2
    )                                                AS percentual_frequencia,
    (
        SELECT valor::NUMERIC
        FROM public.configuracoes
        WHERE chave = 'freq_limiar_pct'
          AND deleted_at IS NULL
          AND (escopo_id = al.campo_id OR escopo_id IS NULL)
        ORDER BY escopo_id NULLS LAST
        LIMIT 1
    )                                                AS limiar_configurado
FROM public.frequencias f
JOIN public.alocacoes_alunos al ON al.id = f.alocacao_id
WHERE f.deleted_at IS NULL
GROUP BY f.aluno_id, al.campo_id, al.turno_id,
         DATE_TRUNC('month', f.data_registro);
-- [S4 - pendente PO/BA] Apenas 'validado' e 'ratificado' contam como presença.
-- 'abonado_pend_ratificacao' conta como ausência até ratificação.


-- ============================================================
-- PARTE 10 — SEED DATA
-- ============================================================

-- Configuração: limiar de frequência (AC-005-5)
INSERT INTO public.configuracoes (chave, valor, descricao, escopo_id)
VALUES (
    'freq_limiar_pct',
    '75',
    'Percentual mínimo de frequência para aprovação. '
    'Padrão: 75%. Ajustável pelo Ator 4 em Sprint 2. '
    'escopo_id NULL = global.',
    NULL
)
ON CONFLICT (chave) DO NOTHING;


-- ============================================================
-- FIM DO SCHEMA
-- ============================================================
-- Versão:     v1.1
-- Engine:     Supabase (PostgreSQL 15+) + PostGIS
-- Execução:   SQL Editor do Supabase Dashboard
-- Repositório: /db/schema_v1.1.sql
-- Próxima versão: Sprint 2 via Supabase CLI com migrations versionadas
-- ============================================================
-- ============================================================
-- SCI — schema_v1.2_delta.sql
-- Delta v1.1 → v1.2 · Incorpora entregas SecOps Sprint 1
-- ============================================================
-- Pré-requisito: schema_v1.1.sql já aplicado com sucesso.
-- Executar no SQL Editor do Supabase Dashboard.
-- Git: /db/schema_v1.2_delta.sql
--
-- PARTES:
--   1. Novos campos em frequencias (anti-spoofing + retenção LGPD)
--   2. Novos campos em usuarios   (aceite de termos LGPD)
--   3. Funções helper auth_*      (RBAC padronizado pelo SecOps)
--   4. Fix: SET search_path nas funções de trigger (WARN do advisor)
--   5. Fix: policy SELECT em transicoes_status_permitidas (bug funcional)
--   6. Fix: security_invoker nas views (bypass RLS)
--   7. Fix: REVOKE EXECUTE anon nas funções SECURITY DEFINER
--   8. RLS policies v1.2 (drop v1.1 + criar versão SecOps)
-- ============================================================


-- ============================================================
-- PARTE 1 — NOVOS CAMPOS EM frequencias
-- Especificados pelo SecOps (seções 2.1 e 3.5)
-- Pré-requisito para Bloco 2 (US-002)
-- ============================================================

-- Anti-spoofing GPS
ALTER TABLE public.frequencias
    ADD COLUMN IF NOT EXISTS mock_location_detectado BOOLEAN NOT NULL DEFAULT false,
    -- TRUE quando Flutter detecta isFromMockProvider() ou equivalente iOS.
    -- Registrado mesmo com gps_disponivel = true: o registro ocorre, mas
    -- o Ator 2 é notificado. O app NUNCA bloqueia — apenas sinaliza.

    ADD COLUMN IF NOT EXISTS velocidade_ms DECIMAL(8,3),
    -- Velocidade reportada pelo GPS no momento do registro (m/s).
    -- NULL se indisponível. Valor > 8.3 m/s (30 km/h) em ambiente
    -- hospitalar é suspeito e eleva nivel_confianca_gps para 1.

    ADD COLUMN IF NOT EXISTS altitude_metros DECIMAL(8,2),
    -- Altitude GPS. Hospitais têm altitude conhecida — desvio > 50m é suspeito.
    -- NULL se indisponível. Sinal auxiliar de detecção de spoofing.

    ADD COLUMN IF NOT EXISTS nivel_confianca_gps SMALLINT NOT NULL DEFAULT 2
        CONSTRAINT chk_nivel_confianca CHECK (nivel_confianca_gps BETWEEN 0 AND 3),
    -- Calculado pelo backend com base nos sinais recebidos:
    --   0 = GPS indisponível (gps_disponivel = false)
    --   1 = GPS suspeito (mock detectado OU velocidade anômala OU precisão exata demais)
    --   2 = GPS normal (padrão)
    --   3 = GPS verificado via Play Integrity API (Sprint 3)
    -- Nível 1 dispara notificação automática para Ator 2.

    ADD COLUMN IF NOT EXISTS motivo_rejeicao_sync VARCHAR(100),
    -- Preenchido quando sincronização offline é rejeitada pelo backend.
    -- Valores possíveis: 'timestamp_futuro', 'fora_janela_turno',
    -- 'sincronizacao_tardia', 'registro_duplicado'
    -- NULL = registro aceito (online ou offline válido).

    -- Controle de retenção LGPD (seção 3.5)
    ADD COLUMN IF NOT EXISTS coordenadas_anonimizadas_em TIMESTAMPTZ;
    -- NULL = coordenadas originais (precisão total).
    -- Preenchido na Fase 2 (90–365 dias): lat/lng truncado para 2 casas (~1km).
    -- lat/lng = NULL na Fase 3 (> 365 dias): exclusão completa das coordenadas.
    -- A frequência em si (status, data) é mantida por obrigação acadêmica.


-- ============================================================
-- PARTE 2 — NOVOS CAMPOS EM usuarios
-- Registro de aceite de termos (LGPD Art. 9 — checklist L-03)
-- ============================================================

ALTER TABLE public.usuarios
    ADD COLUMN IF NOT EXISTS data_aceite_termos   TIMESTAMPTZ,
    -- NULL = usuário ainda não completou o onboarding / aceite de termos.
    -- Preenchido pelo app Flutter na tela de onboarding informativo.
    -- Usuário sem aceite não deve ter acesso às funcionalidades principais.

    ADD COLUMN IF NOT EXISTS versao_termos_aceita VARCHAR(20);
    -- Versão dos termos aceitos (ex: '1.0', '1.1').
    -- Necessário para rastrear qual versão foi aceita quando os termos
    -- forem atualizados. NULL enquanto data_aceite_termos for NULL.


-- ============================================================
-- PARTE 3 — FUNÇÕES HELPER auth_* (nomenclatura SecOps)
-- Substituem fn_perfil_usuario_atual() e fn_e_supervisor_do_campo()
-- como funções primárias de RBAC nas policies.
-- As funções fn_* são mantidas como deprecated até Sprint 2.
-- ============================================================

-- ── auth_get_perfil(): lê perfil da TABELA (consistência garantida) ──
-- Usar em INSERT/UPDATE/DELETE onde consistência > performance.
-- SECURITY DEFINER + SET search_path: evita recursão RLS e injection.
CREATE OR REPLACE FUNCTION public.auth_get_perfil()
RETURNS perfil_ator_enum
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_perfil perfil_ator_enum;
BEGIN
    SELECT perfil INTO v_perfil
    FROM public.usuarios
    WHERE id          = auth.uid()
      AND ativo       = true
      AND deleted_at  IS NULL
    LIMIT 1;
    RETURN v_perfil;
END;
$$;

-- ── auth_get_perfil_jwt(): lê perfil do JWT (performance) ────────────
-- Usar em SELECT onde performance > consistência.
-- ATENÇÃO: pode estar desatualizado se o perfil mudou após emissão do JWT.
-- Pré-requisito: Dev/Antigravity deve popular app_metadata.perfil
-- via service_role ao criar/atualizar usuário.
-- Sem SECURITY DEFINER: apenas lê claim do JWT, sem acesso a tabelas.
CREATE OR REPLACE FUNCTION public.auth_get_perfil_jwt()
RETURNS TEXT
SET search_path = public
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN (auth.jwt() -> 'app_metadata' ->> 'perfil');
END;
$$;

-- ── auth_supervisiona_campo(): vínculo ativo supervisor ↔ campo ──────
-- Substitui fn_e_supervisor_do_campo() como função primária.
CREATE OR REPLACE FUNCTION public.auth_supervisiona_campo(p_campo_id UUID)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM public.supervisor_campos
        WHERE supervisor_id = auth.uid()
          AND campo_id      = p_campo_id
          AND deleted_at    IS NULL
          AND data_inicio   <= CURRENT_DATE
          AND (data_fim IS NULL OR data_fim >= CURRENT_DATE)
    );
END;
$$;

-- ── auth_aal2_ou_ator_menor(): verifica MFA para Atores 3 e 4 ────────
-- Atores 1 e 2 não precisam de MFA.
-- Atores 3 e 4 exigem AAL2 (TOTP completo) para operações sensíveis.
-- Pré-requisito: Dev deve implementar fluxo MFA via supabase_flutter ≥ 2.x.
CREATE OR REPLACE FUNCTION public.auth_aal2_ou_ator_menor()
RETURNS BOOLEAN
SET search_path = public
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN (
        (auth.jwt() -> 'app_metadata' ->> 'perfil') IN ('aluno', 'supervisor')
        OR
        (auth.jwt() ->> 'aal') = 'aal2'
    );
END;
$$;

-- Revogação de acesso anon nas novas funções (prevenir chamada pública)
REVOKE EXECUTE ON FUNCTION public.auth_get_perfil()            FROM anon;
REVOKE EXECUTE ON FUNCTION public.auth_get_perfil_jwt()        FROM anon;
REVOKE EXECUTE ON FUNCTION public.auth_supervisiona_campo(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION public.auth_aal2_ou_ator_menor()    FROM anon;


-- ============================================================
-- PARTE 4 — FIX: SET search_path nas funções de trigger
-- Resolve os WARNs "function_search_path_mutable" do advisor.
-- (Previne search_path injection — vetor de baixa probabilidade
-- mas custo de correção é zero.)
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
RETURNS TRIGGER
SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_sync_campo_geom()
RETURNS TRIGGER
SET search_path = public, topology
LANGUAGE plpgsql AS $$
BEGIN
    NEW.geom = ST_MakePoint(NEW.longitude, NEW.latitude)::geography;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_valida_transicao_status()
RETURNS TRIGGER
SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.transicoes_status_permitidas
        WHERE status_atual   = OLD.status
          AND status_proximo = NEW.status
    ) THEN
        RAISE EXCEPTION
            'SCI: transição de status inválida em frequencias: [%] → [%]. '
            'Consulte transicoes_status_permitidas.',
            OLD.status, NEW.status;
    END IF;

    INSERT INTO public.frequencias_historico_status
        (frequencia_id, status_anterior, status_novo, alterado_por, alterado_em)
    VALUES
        (NEW.id, OLD.status, NEW.status,
         COALESCE(NEW.updated_by, NEW.created_by), NOW());

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_registra_status_inicial()
RETURNS TRIGGER
SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO public.frequencias_historico_status
        (frequencia_id, status_anterior, status_novo, alterado_por, alterado_em)
    VALUES
        (NEW.id, NULL, NEW.status, NEW.created_by, NOW());
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_valida_turno_alocacao()
RETURNS TRIGGER
SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.alocacoes_alunos
        WHERE id = NEW.alocacao_id AND turno_id = NEW.turno_id
    ) THEN
        RAISE EXCEPTION
            'SCI: frequencias.turno_id (%) não corresponde ao turno da alocacao_id (%).',
            NEW.turno_id, NEW.alocacao_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_valida_turno_campo_alocacao()
RETURNS TRIGGER
SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.turnos
        WHERE id       = NEW.turno_id
          AND campo_id = NEW.campo_id
          AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'SCI: turno_id (%) não pertence ao campo_id (%) na alocação.',
            NEW.turno_id, NEW.campo_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_valida_perfil_aluno()
RETURNS TRIGGER
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

CREATE OR REPLACE FUNCTION public.fn_valida_janela_turno()
RETURNS TRIGGER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
    v_hora_inicio          TIME;
    v_hora_fim             TIME;
    v_atravessa_meia_noite BOOLEAN;
    v_hora_atual           TIME;
    v_valido               BOOLEAN := false;
BEGIN
    SELECT hora_inicio, hora_fim, atravessa_meia_noite
    INTO v_hora_inicio, v_hora_fim, v_atravessa_meia_noite
    FROM public.turnos
    WHERE id = NEW.turno_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'SCI: Turno não encontrado para turno_id = %. '
            'Verifique a integridade da alocação.',
            NEW.turno_id;
    END IF;

    v_hora_atual := (NEW.timestamp_servidor AT TIME ZONE 'America/Fortaleza')::TIME;

    IF v_atravessa_meia_noite THEN
        IF v_hora_atual >= v_hora_inicio OR v_hora_atual <= v_hora_fim THEN
            v_valido := true;
        END IF;
    ELSE
        IF v_hora_atual >= v_hora_inicio AND v_hora_atual <= v_hora_fim THEN
            v_valido := true;
        END IF;
    END IF;

    IF NOT v_valido THEN
        RAISE EXCEPTION
            'SCI: Check-in fora da janela permitida para o turno. '
            'Horário atual (Fortaleza): % | Janela: % – %',
            v_hora_atual, v_hora_inicio, v_hora_fim;
    END IF;

    RETURN NEW;
END;
$$;


-- ============================================================
-- PARTE 5 — FIX: Policy SELECT em transicoes_status_permitidas
-- CRÍTICO 1: sem esta policy, toda transição de status falha.
-- fn_valida_transicao_status() é INVOKER — roda como o usuário
-- que disparou o trigger. RLS sem policy = acesso negado.
-- ============================================================

CREATE POLICY "transicoes: select authenticated"
    ON public.transicoes_status_permitidas FOR SELECT
    USING (auth.uid() IS NOT NULL);
-- Tabela de referência (sem dados sensíveis). Leitura liberada
-- para qualquer usuário autenticado. Sem policy de INSERT/UPDATE/DELETE:
-- alterações apenas via service_role (migrations).


-- ============================================================
-- PARTE 6 — FIX: security_invoker nas views
-- Sem este fix, as views rodam com privilégios do owner (SECURITY
-- DEFINER implícito) e ignoram as RLS policies das tabelas subjacentes.
-- PostgreSQL 15+ suporta ALTER VIEW ... SET (security_invoker = on).
-- ============================================================

ALTER VIEW public.vw_usuarios_publico      SET (security_invoker = on);
ALTER VIEW public.vw_alocacoes_ativas_hoje SET (security_invoker = on);
ALTER VIEW public.vw_pendentes_supervisor  SET (security_invoker = on);
ALTER VIEW public.vw_percentual_frequencia SET (security_invoker = on);


-- ============================================================
-- PARTE 7 — FIX: REVOKE EXECUTE anon nas funções SECURITY DEFINER
-- Impede chamadas não autenticadas via REST /rpc/<fn>.
-- ============================================================

REVOKE EXECUTE ON FUNCTION public.fn_perfil_usuario_atual()                         FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_e_supervisor_do_campo(UUID)                    FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_distancia_ao_campo(DECIMAL, DECIMAL, UUID)     FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_dentro_do_campo(DECIMAL, DECIMAL, UUID)        FROM anon;


-- ============================================================
-- PARTE 8 — RLS POLICIES v1.2
-- Drop das policies v1.1 + criação das versões revisadas pelo SecOps.
-- Principais mudanças:
--   - auth_get_perfil_jwt() em SELECTs (performance)
--   - auth_get_perfil()     em INSERT/UPDATE/DELETE (consistência)
--   - auth_supervisiona_campo() substitui fn_e_supervisor_do_campo()
--   - AAL2 obrigatório em ratificacoes INSERT
--   - Ator 2 vê alunos dos seus campos em usuarios SELECT
--   - Ator 1 NÃO vê documentos_abono (uploads são do Ator 2/3)
--   - Policy DELETE em notificacoes (arquivar notificação)
-- ============================================================

-- ── USUARIOS ─────────────────────────────────────────────────

DROP POLICY IF EXISTS "usuarios: select self"          ON public.usuarios;
DROP POLICY IF EXISTS "usuarios: select coordenacao"   ON public.usuarios;
DROP POLICY IF EXISTS "usuarios: insert coordenacao"   ON public.usuarios;
DROP POLICY IF EXISTS "usuarios: update self"          ON public.usuarios;
DROP POLICY IF EXISTS "usuarios: update coordenacao"   ON public.usuarios;

CREATE POLICY "usuarios: select"
    ON public.usuarios FOR SELECT
    USING (
        -- Cada ator vê o próprio registro
        id = auth.uid()
        OR
        -- Professor e coordenação veem todos
        auth_get_perfil_jwt() IN ('professor', 'coordenacao')
        OR
        -- Supervisor vê alunos alocados nos seus campos
        (
            auth_get_perfil_jwt() = 'supervisor'
            AND EXISTS (
                SELECT 1
                FROM public.alocacoes_alunos al
                JOIN public.supervisor_campos sc ON sc.campo_id = al.campo_id
                WHERE al.aluno_id      = usuarios.id
                  AND sc.supervisor_id = auth.uid()
                  AND sc.deleted_at    IS NULL
                  AND al.deleted_at    IS NULL
            )
        )
    );

CREATE POLICY "usuarios: insert"
    ON public.usuarios FOR INSERT
    WITH CHECK (auth_get_perfil() = 'coordenacao');

CREATE POLICY "usuarios: update"
    ON public.usuarios FOR UPDATE
    USING (id = auth.uid() OR auth_get_perfil() = 'coordenacao');

CREATE POLICY "usuarios: delete"
    ON public.usuarios FOR DELETE
    USING (auth_get_perfil() = 'coordenacao');


-- ── SESSOES ───────────────────────────────────────────────────

DROP POLICY IF EXISTS "sessoes: select self" ON public.sessoes;

CREATE POLICY "sessoes: select self"
    ON public.sessoes FOR SELECT
    USING (usuario_id = auth.uid());


-- ── CAMPOS_ESTAGIO ────────────────────────────────────────────

DROP POLICY IF EXISTS "campos: select ativos todos"      ON public.campos_estagio;
DROP POLICY IF EXISTS "campos: select coordenacao completo" ON public.campos_estagio;
DROP POLICY IF EXISTS "campos: insert coordenacao"       ON public.campos_estagio;
DROP POLICY IF EXISTS "campos: update coordenacao"       ON public.campos_estagio;

CREATE POLICY "campos: select"
    ON public.campos_estagio FOR SELECT
    USING (
        -- Todos veem campos ativos; coordenação vê também inativos/deletados
        (deleted_at IS NULL AND ativo = true)
        OR auth_get_perfil_jwt() IN ('professor', 'coordenacao')
    );

CREATE POLICY "campos: insert"
    ON public.campos_estagio FOR INSERT
    WITH CHECK (auth_get_perfil() = 'coordenacao');

CREATE POLICY "campos: update"
    ON public.campos_estagio FOR UPDATE
    USING (auth_get_perfil() = 'coordenacao');

CREATE POLICY "campos: delete"
    ON public.campos_estagio FOR DELETE
    USING (auth_get_perfil() = 'coordenacao');


-- ── TURNOS ────────────────────────────────────────────────────

DROP POLICY IF EXISTS "turnos: select todos"       ON public.turnos;
DROP POLICY IF EXISTS "turnos: insert coordenacao" ON public.turnos;
DROP POLICY IF EXISTS "turnos: update coordenacao" ON public.turnos;

CREATE POLICY "turnos: select"
    ON public.turnos FOR SELECT
    USING (auth.uid() IS NOT NULL AND deleted_at IS NULL);

CREATE POLICY "turnos: insert"
    ON public.turnos FOR INSERT
    WITH CHECK (auth_get_perfil() = 'coordenacao');

CREATE POLICY "turnos: update"
    ON public.turnos FOR UPDATE
    USING (auth_get_perfil() = 'coordenacao');


-- ── SUPERVISOR_CAMPOS ─────────────────────────────────────────

DROP POLICY IF EXISTS "supervisor_campos: select self"           ON public.supervisor_campos;
DROP POLICY IF EXISTS "supervisor_campos: select prof coordenacao" ON public.supervisor_campos;
DROP POLICY IF EXISTS "supervisor_campos: insert coordenacao"    ON public.supervisor_campos;
DROP POLICY IF EXISTS "supervisor_campos: update coordenacao"    ON public.supervisor_campos;

CREATE POLICY "supervisor_campos: select"
    ON public.supervisor_campos FOR SELECT
    USING (
        supervisor_id = auth.uid()
        OR auth_get_perfil_jwt() IN ('professor', 'coordenacao')
    );

CREATE POLICY "supervisor_campos: insert"
    ON public.supervisor_campos FOR INSERT
    WITH CHECK (auth_get_perfil() = 'coordenacao');

CREATE POLICY "supervisor_campos: update"
    ON public.supervisor_campos FOR UPDATE
    USING (auth_get_perfil() = 'coordenacao');


-- ── ALOCACOES_ALUNOS ──────────────────────────────────────────

DROP POLICY IF EXISTS "alocacoes: select aluno self"       ON public.alocacoes_alunos;
DROP POLICY IF EXISTS "alocacoes: select supervisor setor" ON public.alocacoes_alunos;
DROP POLICY IF EXISTS "alocacoes: select prof coordenacao" ON public.alocacoes_alunos;
DROP POLICY IF EXISTS "alocacoes: insert coordenacao"      ON public.alocacoes_alunos;
DROP POLICY IF EXISTS "alocacoes: update coordenacao"      ON public.alocacoes_alunos;

CREATE POLICY "alocacoes: select"
    ON public.alocacoes_alunos FOR SELECT
    USING (
        (auth_get_perfil_jwt() = 'aluno'      AND aluno_id = auth.uid() AND deleted_at IS NULL)
        OR
        (auth_get_perfil_jwt() = 'supervisor' AND auth_supervisiona_campo(campo_id) AND deleted_at IS NULL)
        OR
        auth_get_perfil_jwt() IN ('professor', 'coordenacao')
    );

CREATE POLICY "alocacoes: insert"
    ON public.alocacoes_alunos FOR INSERT
    WITH CHECK (auth_get_perfil() = 'coordenacao');

CREATE POLICY "alocacoes: update"
    ON public.alocacoes_alunos FOR UPDATE
    USING (auth_get_perfil() = 'coordenacao');


-- ── FREQUENCIAS ───────────────────────────────────────────────

DROP POLICY IF EXISTS "freq: select aluno self"             ON public.frequencias;
DROP POLICY IF EXISTS "freq: select supervisor setor"       ON public.frequencias;
DROP POLICY IF EXISTS "freq: select prof coordenacao"       ON public.frequencias;
DROP POLICY IF EXISTS "freq: insert aluno self"             ON public.frequencias;
DROP POLICY IF EXISTS "freq: update supervisor validacao"   ON public.frequencias;
DROP POLICY IF EXISTS "freq: update abono sup prof"         ON public.frequencias;
DROP POLICY IF EXISTS "freq: update ratificacao prof coord" ON public.frequencias;

-- SELECT unificado (performance: jwt para todos os branches)
CREATE POLICY "freq: select"
    ON public.frequencias FOR SELECT
    USING (
        (auth_get_perfil_jwt() = 'aluno'
            AND aluno_id = auth.uid()
            AND deleted_at IS NULL)
        OR
        (auth_get_perfil_jwt() = 'supervisor'
            AND deleted_at IS NULL
            AND EXISTS (
                SELECT 1 FROM public.alocacoes_alunos al
                WHERE al.id = alocacao_id
                  AND auth_supervisiona_campo(al.campo_id)
            ))
        OR
        auth_get_perfil_jwt() IN ('professor', 'coordenacao')
    );

-- INSERT: aluno registra apenas a própria frequência com alocação ativa
CREATE POLICY "freq: insert"
    ON public.frequencias FOR INSERT
    WITH CHECK (
        auth_get_perfil() = 'aluno'
        AND aluno_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.alocacoes_alunos al
            WHERE al.id         = frequencias.alocacao_id
              AND al.aluno_id   = auth.uid()
              AND al.deleted_at IS NULL
              AND al.data_inicio <= CURRENT_DATE
              AND (al.data_fim IS NULL OR al.data_fim >= CURRENT_DATE)
        )
    );

-- UPDATE de status: Ator 2 valida (pendente_validacao → validado | rejeitado)
CREATE POLICY "freq: update supervisor"
    ON public.frequencias FOR UPDATE
    USING (
        auth_get_perfil() = 'supervisor'
        AND EXISTS (
            SELECT 1 FROM public.alocacoes_alunos al
            WHERE al.id = alocacao_id
              AND auth_supervisiona_campo(al.campo_id)
        )
    );

-- UPDATE de status: Atores 3 e 4 (abono + ratificação)
CREATE POLICY "freq: update prof coord"
    ON public.frequencias FOR UPDATE
    USING (auth_get_perfil() IN ('professor', 'coordenacao'));

-- DELETE (soft): apenas coordenação em casos excepcionais
CREATE POLICY "freq: delete"
    ON public.frequencias FOR DELETE
    USING (auth_get_perfil() = 'coordenacao');


-- ── ABONOS ────────────────────────────────────────────────────

DROP POLICY IF EXISTS "abonos: select aluno self"    ON public.abonos;
DROP POLICY IF EXISTS "abonos: select sup prof coord" ON public.abonos;
DROP POLICY IF EXISTS "abonos: insert sup prof"      ON public.abonos;

CREATE POLICY "abonos: select"
    ON public.abonos FOR SELECT
    USING (
        (auth_get_perfil_jwt() = 'aluno'
            AND EXISTS (
                SELECT 1 FROM public.frequencias f
                WHERE f.id = frequencia_id AND f.aluno_id = auth.uid()
            ))
        OR
        auth_get_perfil_jwt() IN ('supervisor', 'professor', 'coordenacao')
    );

-- INSERT: Ator 2 abona apenas frequências dos seus campos; Ator 3 abona qualquer
CREATE POLICY "abonos: insert"
    ON public.abonos FOR INSERT
    WITH CHECK (
        auth_get_perfil() IN ('supervisor', 'professor')
        AND abonado_por = auth.uid()
        AND (
            auth_get_perfil() = 'professor'
            OR (
                auth_get_perfil() = 'supervisor'
                AND EXISTS (
                    SELECT 1
                    FROM public.frequencias f
                    JOIN public.alocacoes_alunos al ON al.id = f.alocacao_id
                    WHERE f.id = abonos.frequencia_id
                      AND auth_supervisiona_campo(al.campo_id)
                )
            )
        )
    );


-- ── DOCUMENTOS_ABONO ──────────────────────────────────────────
-- [PO/BA] Ator 1 NÃO vê documentos (uploads feitos por Ator 2/3).
-- Confirmar com PO/BA se esta é a regra de negócio pretendida.

DROP POLICY IF EXISTS "docs_abono: select aluno self"    ON public.documentos_abono;
DROP POLICY IF EXISTS "docs_abono: select sup prof coord" ON public.documentos_abono;
DROP POLICY IF EXISTS "docs_abono: insert sup prof"      ON public.documentos_abono;

CREATE POLICY "docs_abono: select"
    ON public.documentos_abono FOR SELECT
    USING (
        (auth_get_perfil_jwt() = 'supervisor'
            AND EXISTS (
                SELECT 1
                FROM public.abonos ab
                JOIN public.frequencias f ON f.id = ab.frequencia_id
                JOIN public.alocacoes_alunos al ON al.id = f.alocacao_id
                WHERE ab.id = abono_id
                  AND auth_supervisiona_campo(al.campo_id)
            ))
        OR
        auth_get_perfil_jwt() IN ('professor', 'coordenacao')
        -- Ator 1 (aluno) NÃO vê documentos — uploads pertencem ao Ator 2/3.
    );

CREATE POLICY "docs_abono: insert"
    ON public.documentos_abono FOR INSERT
    WITH CHECK (auth_get_perfil() IN ('supervisor', 'professor'));


-- ── REJEICOES ─────────────────────────────────────────────────

DROP POLICY IF EXISTS "rejeicoes: select aluno self"    ON public.rejeicoes;
DROP POLICY IF EXISTS "rejeicoes: select sup prof coord" ON public.rejeicoes;
DROP POLICY IF EXISTS "rejeicoes: insert supervisor"    ON public.rejeicoes;
DROP POLICY IF EXISTS "rejeicoes: insert prof coord"    ON public.rejeicoes;

CREATE POLICY "rejeicoes: select"
    ON public.rejeicoes FOR SELECT
    USING (
        (auth_get_perfil_jwt() = 'aluno'
            AND EXISTS (
                SELECT 1 FROM public.frequencias f
                WHERE f.id = frequencia_id AND f.aluno_id = auth.uid()
            ))
        OR
        auth_get_perfil_jwt() IN ('supervisor', 'professor', 'coordenacao')
    );

CREATE POLICY "rejeicoes: insert supervisor"
    ON public.rejeicoes FOR INSERT
    WITH CHECK (
        auth_get_perfil() = 'supervisor'
        AND etapa = 'validacao'
    );

CREATE POLICY "rejeicoes: insert prof coord"
    ON public.rejeicoes FOR INSERT
    WITH CHECK (
        auth_get_perfil() IN ('professor', 'coordenacao')
        AND etapa = 'ratificacao'
    );


-- ── RATIFICACOES ──────────────────────────────────────────────

DROP POLICY IF EXISTS "ratificacoes: select aluno self"    ON public.ratificacoes;
DROP POLICY IF EXISTS "ratificacoes: select sup prof coord" ON public.ratificacoes;
DROP POLICY IF EXISTS "ratificacoes: insert prof coord"    ON public.ratificacoes;

CREATE POLICY "ratificacoes: select"
    ON public.ratificacoes FOR SELECT
    USING (
        auth_get_perfil_jwt() IN ('professor', 'coordenacao')
        OR (
            auth_get_perfil_jwt() = 'aluno'
            AND EXISTS (
                SELECT 1 FROM public.frequencias f
                WHERE f.id = frequencia_id AND f.aluno_id = auth.uid()
            )
        )
        OR (
            auth_get_perfil_jwt() = 'supervisor'
            AND EXISTS (
                SELECT 1
                FROM public.frequencias f
                JOIN public.alocacoes_alunos al ON al.id = f.alocacao_id
                WHERE f.id = frequencia_id
                  AND auth_supervisiona_campo(al.campo_id)
            )
        )
    );

-- INSERT: Ator 3 e 4 apenas + AAL2 obrigatório (MFA)
CREATE POLICY "ratificacoes: insert"
    ON public.ratificacoes FOR INSERT
    WITH CHECK (
        auth_get_perfil() IN ('professor', 'coordenacao')
        AND auth_aal2_ou_ator_menor()
        AND ratificado_por = auth.uid()
    );


-- ── FREQUENCIAS_HISTORICO_STATUS ──────────────────────────────

DROP POLICY IF EXISTS "historico: select aluno self"       ON public.frequencias_historico_status;
DROP POLICY IF EXISTS "historico: select sup prof coord"   ON public.frequencias_historico_status;

CREATE POLICY "historico: select"
    ON public.frequencias_historico_status FOR SELECT
    USING (
        auth_get_perfil_jwt() IN ('professor', 'coordenacao')
        OR (
            auth_get_perfil_jwt() = 'aluno'
            AND EXISTS (
                SELECT 1 FROM public.frequencias f
                WHERE f.id = frequencia_id AND f.aluno_id = auth.uid()
            )
        )
        OR (
            auth_get_perfil_jwt() = 'supervisor'
            AND EXISTS (
                SELECT 1
                FROM public.frequencias f
                JOIN public.alocacoes_alunos al ON al.id = f.alocacao_id
                WHERE f.id = frequencia_id
                  AND auth_supervisiona_campo(al.campo_id)
            )
        )
    );


-- ── NOTIFICACOES ──────────────────────────────────────────────

DROP POLICY IF EXISTS "notificacoes: select self" ON public.notificacoes;
DROP POLICY IF EXISTS "notificacoes: update self" ON public.notificacoes;

CREATE POLICY "notificacoes: select"
    ON public.notificacoes FOR SELECT
    USING (destinatario_id = auth.uid() AND deleted_at IS NULL);

CREATE POLICY "notificacoes: update"
    ON public.notificacoes FOR UPDATE
    USING (destinatario_id = auth.uid() AND deleted_at IS NULL)
    WITH CHECK (destinatario_id = auth.uid());

-- DELETE: destinatário pode arquivar notificações (soft delete via deleted_at)
CREATE POLICY "notificacoes: delete"
    ON public.notificacoes FOR DELETE
    USING (destinatario_id = auth.uid());


-- ── CONFIGURACOES ─────────────────────────────────────────────

DROP POLICY IF EXISTS "config: select todos"      ON public.configuracoes;
DROP POLICY IF EXISTS "config: update coordenacao" ON public.configuracoes;

CREATE POLICY "config: select"
    ON public.configuracoes FOR SELECT
    USING (auth.uid() IS NOT NULL AND deleted_at IS NULL);

CREATE POLICY "config: insert"
    ON public.configuracoes FOR INSERT
    WITH CHECK (auth_get_perfil() = 'coordenacao');

CREATE POLICY "config: update"
    ON public.configuracoes FOR UPDATE
    USING (auth_get_perfil() = 'coordenacao');


-- ============================================================
-- FIM DO DELTA v1.2
-- ============================================================
-- Versão:     v1.2
-- Baseado em: SecOps Sprint 1 v1.0
-- Executar:   SQL Editor do Supabase Dashboard
-- Git:        /db/schema_v1.2_delta.sql
--
-- PENDÊNCIAS (não são responsabilidade do DB Architect):
--
-- DEV / ANTIGRAVITY:
--   - JWT TTL = 900s + refresh rotation no Dashboard
--   - Popular app_metadata.perfil via service_role ao criar usuário
--     (pré-requisito para auth_get_perfil_jwt() funcionar)
--   - Edge Function de sync: validação de janela temporal offline
--   - Flutter: tela de onboarding com aceite de termos (US-001)
--   - Flutter: fluxo MFA TOTP para Ator 3/4 (supabase_flutter ≥ 2.x)
--   - Sprint 2: certificate pinning
--   - Sprint 3: Play Integrity API
--
-- PO/BA:
--   - L-01: regulamento do internato menciona verificação tecnológica?
--   - Confirmar: Ator 1 não vê documentos_abono (nova policy acima)
--   - L-15: atestados médicos são aceitos como docs de abono?
--
-- SPRINT 2 (jobs agendados):
--   - Fase 2 retenção: anonimização parcial (90 dias) via pg_cron
--   - Fase 3 retenção: exclusão de coordenadas (365 dias) via pg_cron
-- ============================================================
-- ============================================================
-- MIGRATION: 10_qa_fixes.sql
-- USER STORY: Correções do QA (Sprint 1)
-- ============================================================

-- ============================================================
-- 1. Criação do Bucket Storage 'documentos-abono' (com hífen)
-- QA apontou ausência. Subistituiremos o bucket anterior (se existir).
-- ============================================================

-- Insere o bucket com nome corrigido
INSERT INTO storage.buckets (id, name, public) 
VALUES ('documentos-abono', 'documentos-abono', false) 
ON CONFLICT (id) DO NOTHING;

-- Habilita RLS no bucket objects (caso não esteja)
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Upload: Ator 2 e 3
DROP POLICY IF EXISTS "docs_abono_insert_sup_prof" ON storage.objects;
CREATE POLICY "docs_abono_insert_sup_prof"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'documentos-abono'
        AND public.auth_get_perfil_jwt() IN ('supervisor', 'professor')
    );

-- Download/Ler Arquivo Físico: Ator 3 e 4
DROP POLICY IF EXISTS "docs_abono_select_prof_coord" ON storage.objects;
CREATE POLICY "docs_abono_select_prof_coord"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'documentos-abono'
        AND public.auth_get_perfil_jwt() IN ('professor', 'coordenacao')
    );

-- Deletar: Ator 3 e 4
DROP POLICY IF EXISTS "docs_abono_delete_prof_coord" ON storage.objects;
CREATE POLICY "docs_abono_delete_prof_coord"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'documentos-abono'
        AND public.auth_get_perfil_jwt() IN ('professor', 'coordenacao')
    );

-- ============================================================
-- 2. BUG-ARCH-001 (Soft Delete)
-- Remover policy de DELETE físico para evitar erro de FK.
-- O Flutter App usará um UPDATE setando deleted_at ao invés de DELETE.
-- ============================================================
DROP POLICY IF EXISTS "freq: delete" ON public.frequencias;

-- (A policy de UPDATE da Coordenação já abrange atualizar qualquer campo, 
--  portanto eles já podem fazer o UPDATE de deleted_at sem problemas).

-- ============================================================
-- 3. SEED DADOS (Reforço dos status pendentes que o QA reportou falta)
-- Inserimos mais duas frequências com datas ainda mais antigas
-- ============================================================
DO $$
DECLARE
    v_aluno_id UUID := '33333333-3333-3333-3333-333333333331';
    v_alocacao_id UUID := '44444444-4444-4444-4444-444444444444';
    v_turno_manha_id UUID := '22222222-2222-2222-2222-222222222221';
    v_data_atual DATE := CURRENT_DATE;
BEGIN
    -- Reforço: Rejeitado (D-6)
    INSERT INTO public.frequencias (id, aluno_id, alocacao_id, turno_id, data_registro, timestamp_servidor, lat_registro, lng_registro, gps_disponivel, distancia_metros, status, created_by)
    VALUES (gen_random_uuid(), v_aluno_id, v_alocacao_id, v_turno_manha_id, v_data_atual - INTERVAL '6 days', NOW() - INTERVAL '6 days', -3.79, -38.55, true, 5.0, 'rejeitado', v_aluno_id)
    ON CONFLICT DO NOTHING;

    -- Reforço: Abonado pendente ratificação (D-7)
    INSERT INTO public.frequencias (id, aluno_id, alocacao_id, turno_id, data_registro, timestamp_servidor, lat_registro, lng_registro, gps_disponivel, distancia_metros, status, created_by)
    VALUES (gen_random_uuid(), v_aluno_id, v_alocacao_id, v_turno_manha_id, v_data_atual - INTERVAL '7 days', NOW() - INTERVAL '7 days', -3.79, -38.55, true, 2.0, 'abonado_pend_ratificacao', v_aluno_id)
    ON CONFLICT DO NOTHING;
END $$;
