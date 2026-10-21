-- ============================================================
-- MIGRATION: 20250601000017_legislacao_documentos.sql
-- DESCRIÇÃO: Bucket de armazenamento e metadados para documentos de legislação (PDF e DOC)
-- ============================================================

-- 1. Criação do Bucket Storage 'documentos-legislacao'
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) 
VALUES (
  'documentos-legislacao', 
  'documentos-legislacao', 
  true, 
  10485760, -- 10 MB
  ARRAY[
    'application/pdf', 
    'application/msword', 
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/octet-stream'
  ]
) 
ON CONFLICT (id) DO UPDATE 
SET public = true,
    file_size_limit = 10485760,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2. Habilita RLS em storage.objects (caso não esteja)
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 3. Políticas de Upload no Storage: Professor e Coordenação
DROP POLICY IF EXISTS "upload_legislacao_prof_coord" ON storage.objects;
CREATE POLICY "upload_legislacao_prof_coord" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'documentos-legislacao'
  AND (
    public.auth_get_perfil_jwt() IN ('professor', 'coordenacao')
    OR public.auth_get_perfil() IN ('professor', 'coordenacao')
  )
);

-- 4. Políticas de Download / Visualização Pública (Alunos, Supervisores, Professores e Coordenação)
DROP POLICY IF EXISTS "select_legislacao_publico" ON storage.objects;
CREATE POLICY "select_legislacao_publico" ON storage.objects
FOR SELECT TO authenticated, anon
USING (
  bucket_id = 'documentos-legislacao'
);

-- 5. Políticas de Atualização e Exclusão no Storage: Professor e Coordenação
DROP POLICY IF EXISTS "delete_legislacao_prof_coord" ON storage.objects;
CREATE POLICY "delete_legislacao_prof_coord" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'documentos-legislacao'
  AND (
    public.auth_get_perfil_jwt() IN ('professor', 'coordenacao')
    OR public.auth_get_perfil() IN ('professor', 'coordenacao')
  )
);

-- 6. Adição de colunas auxiliares em public.legislacoes (idempotente)
ALTER TABLE public.legislacoes
  ADD COLUMN IF NOT EXISTS arquivo_nome TEXT,
  ADD COLUMN IF NOT EXISTS arquivo_url TEXT,
  ADD COLUMN IF NOT EXISTS arquivo_tamanho INT,
  ADD COLUMN IF NOT EXISTS arquivo_extensao TEXT;
