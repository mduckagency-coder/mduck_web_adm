-- ============================================================================
-- Permite upload/leitura/exclusao de arquivos no bucket "program_banners"
-- (criado na 0033_imagem_programa) -- faltava a policy de RLS da
-- storage.objects, por isso o envio de imagem em Programas de
-- Desenvolvimento dava "new row violates row-level security policy" (403,
-- Unauthorized). Mesmo problema que ja tinha acontecido com
-- material_attachments (0019) e event_banners/event_attachments (0021).
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================
drop policy if exists "program_banners_all" on storage.objects;
create policy "program_banners_all" on storage.objects
  for all
  to authenticated
  using (bucket_id = 'program_banners')
  with check (bucket_id = 'program_banners');
