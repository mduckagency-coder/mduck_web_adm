-- ============================================================================
-- Permite upload/leitura/exclusao de arquivos nos buckets "event_banners" e
-- "event_attachments" (criados na 0009_eventos) -- faltava a policy de RLS
-- da storage.objects, por isso o envio de banner/anexo em Eventos dava
-- "new row violates row-level security policy" (403, Unauthorized). Mesmo
-- problema que ja tinha acontecido com o bucket material_attachments
-- (0019_material_attachments_storage_rls).
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================
drop policy if exists "event_banners_all" on storage.objects;
create policy "event_banners_all" on storage.objects
  for all
  to authenticated
  using (bucket_id = 'event_banners')
  with check (bucket_id = 'event_banners');

drop policy if exists "event_attachments_all" on storage.objects;
create policy "event_attachments_all" on storage.objects
  for all
  to authenticated
  using (bucket_id = 'event_attachments')
  with check (bucket_id = 'event_attachments');
