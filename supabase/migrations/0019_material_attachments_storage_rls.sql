-- ============================================================================
-- Permite upload/leitura/exclusao de arquivos no bucket
-- "material_attachments" (criado na 0017) -- faltava a policy de RLS da
-- storage.objects, por isso o envio de imagem/arquivo/video em Materiais
-- dava "new row violates row-level security policy" (403, Unauthorized).
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================
drop policy if exists "material_attachments_all" on storage.objects;
create policy "material_attachments_all" on storage.objects
  for all
  to authenticated
  using (bucket_id = 'material_attachments')
  with check (bucket_id = 'material_attachments');
