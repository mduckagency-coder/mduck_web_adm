-- ============================================================================
-- app_settings: chave-valor de configuracao por agencia para telas do app do
-- streamer. A tabela ja e lida hoje por mduck_lives (chaves
-- "default_days_target"/"default_hours_target", ver
-- lib/features/home/data/streamer_repository.dart nesse outro repo) --
-- formalizada aqui com CREATE TABLE IF NOT EXISTS: se ja existir em producao
-- com outro formato, este comando e um no-op e nao altera nada.
--
-- Primeira chave nova cadastrada por aqui: "inventory_mascot_url" (video ou
-- imagem em loop do Max no banner de boas-vindas da tela de Inventario).
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

create table if not exists app_settings (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  key text not null,
  value jsonb not null,
  updated_at timestamptz not null default now()
);
create index if not exists idx_app_settings_agency_key on app_settings(agency_id, key);

comment on column app_settings.key is 'ex: default_days_target, default_hours_target, inventory_mascot_url';
comment on column app_settings.value is 'jsonb -- numero, string ou objeto conforme a chave';

insert into storage.buckets (id, name, public, file_size_limit)
values ('app_settings_media', 'app_settings_media', true, 5242880)
on conflict (id) do update set file_size_limit = excluded.file_size_limit;

-- ============================================================================
-- RLS
-- ============================================================================
alter table app_settings enable row level security;

drop policy if exists "app_settings_agency" on app_settings;
create policy "app_settings_agency" on app_settings
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

-- Streamer (app) so le as configuracoes da propria agencia.
drop policy if exists "app_settings_streamer_select" on app_settings;
create policy "app_settings_streamer_select" on app_settings
  for select using (
    agency_id = (select agency_id from profiles where auth_user_id = auth.uid())
  );

drop policy if exists "app_settings_media_storage_all" on storage.objects;
create policy "app_settings_media_storage_all" on storage.objects
  for all
  to authenticated
  using (bucket_id = 'app_settings_media')
  with check (bucket_id = 'app_settings_media');
