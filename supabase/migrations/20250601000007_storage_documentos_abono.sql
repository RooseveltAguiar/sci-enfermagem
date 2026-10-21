-- ============================================================
-- MIGRATION: 20250601000007_storage_documentos_abono.sql
-- DESCRIÇÃO: Criação do bucket documentos-abono, RLS e tabela
-- ============================================================

-- 1. Criação do Bucket Storage 'documentos-abono'
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) 
VALUES (
  'documentos-abono', 
  'documentos-abono', 
  false, 
  5242880, 
  ARRAY['application/pdf', 'image/jpeg', 'image/png']
) 
ON CONFLICT (id) DO UPDATE 
SET file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Upload: ator_2 e ator_3
DROP POLICY IF EXISTS "upload_abono" ON storage.objects;
CREATE POLICY "upload_abono" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'documentos-abono'
  AND public.auth_get_perfil_jwt() IN ('supervisor', 'professor')
);

-- Download: ator_3 e ator_4
DROP POLICY IF EXISTS "download_abono" ON storage.objects;
CREATE POLICY "download_abono" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'documentos-abono'
  AND public.auth_get_perfil_jwt() IN ('professor', 'coordenacao')
);

-- 2. Tabela Relacional: documentos_abono
CREATE TABLE IF NOT EXISTS public.documentos_abono (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    frequencia_id UUID NOT NULL REFERENCES public.frequencias(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,
    nome_arquivo TEXT NOT NULL,
    uploaded_by UUID NOT NULL REFERENCES public.usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS em documentos_abono
ALTER TABLE public.documentos_abono ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_metadata_ator1" ON public.documentos_abono;
CREATE POLICY "select_metadata_ator1" ON public.documentos_abono
FOR SELECT TO authenticated
USING (
  public.auth_get_perfil_jwt() = 'aluno'
  AND frequencia_id IN (
    SELECT id FROM public.frequencias
    WHERE aluno_id = auth.uid()
  )
);

-- Políticas adicionais para a tabela (Atores 2, 3 e 4)
DROP POLICY IF EXISTS "select_metadata_supervisores_etc" ON public.documentos_abono;
CREATE POLICY "select_metadata_supervisores_etc" ON public.documentos_abono
FOR SELECT TO authenticated
USING (public.auth_get_perfil_jwt() IN ('supervisor', 'professor', 'coordenacao'));

DROP POLICY IF EXISTS "insert_metadata_ator23" ON public.documentos_abono;
CREATE POLICY "insert_metadata_ator23" ON public.documentos_abono
FOR INSERT TO authenticated
WITH CHECK (public.auth_get_perfil_jwt() IN ('supervisor', 'professor'));
