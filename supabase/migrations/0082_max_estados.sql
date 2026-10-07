-- ============================================================================
-- Max - Estados do personagem (Home > Configuracao Animacao APP > Max)
-- Define as midias e mensagens de cada estado do Max exibido no app do streamer.
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

create table if not exists max_state_media (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  state_key text not null check (state_key in ('regular', 'constante', 'inativo', 'caveira')),
  media_type text not null check (media_type in ('image', 'video')),
  name text not null,
  storage_path text not null,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_by uuid references managers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_max_state_media_lookup on max_state_media(agency_id, state_key, is_active, sort_order);

create table if not exists max_state_messages (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  state_key text not null check (state_key in ('regular', 'constante', 'inativo', 'caveira')),
  category text not null default 'geral' check (category in (
    'geral', 'inicio_mes', 'meio_mes', 'final_mes', 'frequencia', 'retorno', 'inatividade'
  )),
  message text not null,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_by uuid references managers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_max_state_messages_lookup on max_state_messages(agency_id, state_key, category, is_active, sort_order);

-- Preparado para o futuro: limites configuraveis por estado (dias sem live, lives no mes, etc).
-- Sem logica de decisao nem UI nesta fase - so a estrutura, para nao exigir nova migration depois.
create table if not exists max_state_rules (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  state_key text not null check (state_key in ('regular', 'constante', 'inativo', 'caveira')),
  min_days_without_live int,
  max_days_without_live int,
  min_lives_this_month int,
  max_lives_this_month int,
  extra_config jsonb not null default '{}'::jsonb,
  updated_by uuid references managers(id),
  updated_at timestamptz not null default now(),
  unique (agency_id, state_key)
);

insert into storage.buckets (id, name, public)
values ('max_states', 'max_states', true)
on conflict (id) do nothing;

-- ============================================================================
-- RLS
-- ============================================================================
alter table max_state_media enable row level security;
alter table max_state_messages enable row level security;
alter table max_state_rules enable row level security;

drop policy if exists "max_state_media_agency" on max_state_media;
create policy "max_state_media_agency" on max_state_media
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "max_state_media_streamer_select" on max_state_media;
create policy "max_state_media_streamer_select" on max_state_media
  for select using (
    is_active = true
    and agency_id = (select agency_id from profiles where auth_user_id = auth.uid())
  );

drop policy if exists "max_state_messages_agency" on max_state_messages;
create policy "max_state_messages_agency" on max_state_messages
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "max_state_messages_streamer_select" on max_state_messages;
create policy "max_state_messages_streamer_select" on max_state_messages
  for select using (
    is_active = true
    and agency_id = (select agency_id from profiles where auth_user_id = auth.uid())
  );

drop policy if exists "max_state_rules_agency" on max_state_rules;
create policy "max_state_rules_agency" on max_state_rules
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "max_states_storage_all" on storage.objects;
create policy "max_states_storage_all" on storage.objects
  for all
  to authenticated
  using (bucket_id = 'max_states')
  with check (bucket_id = 'max_states');
