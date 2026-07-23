-- ============================================================================
-- Cria o bucket de storage "material_attachments" -- usado pelo upload de
-- arquivo/imagem em Materiais (Recrutador, Cadastrar Materiais do
-- coordenador/admin e Material Acompanhamento do Gestor). O bucket nunca
-- foi criado, por isso o upload falhava com "Bucket not found" (404).
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente, mesmo
-- padrao da 0009 (storage buckets de eventos).
-- ============================================================================
insert into storage.buckets (id, name, public)
values ('material_attachments', 'material_attachments', true)
on conflict (id) do nothing;
