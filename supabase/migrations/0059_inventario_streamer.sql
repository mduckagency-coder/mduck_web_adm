-- ============================================================================
-- Inventario do Streamer (Home Central > Operacoes APP > Inventario)
-- Substitui os menus separados "Conquistas" e "Brasoes e Titulos" (nunca
-- tiveram pagina/tabela propria) por um unico registro do que o streamer
-- fez/recebeu: treinamentos, acompanhamentos, premiacoes e conquistas.
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

create table if not exists streamer_inventory_entries (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  streamer_id uuid not null references profiles(id),
  category text not null check (category in ('treinamento', 'acompanhamento', 'premiacao', 'conquista')),
  title text not null,
  description text,
  occurred_at date not null default current_date,
  points integer,
  image_url text,
  -- Origem do registro: 'manual' (cadastrado direto aqui) ou o nome da tela
  -- que gerou automaticamente (ex: 'acompanhamento', 'programa', 'evento'),
  -- preparado pra quando outras paginas passarem a linkar pro inventario.
  source text not null default 'manual',
  source_id uuid,
  created_by uuid references managers(id),
  created_at timestamptz not null default now()
);
create index if not exists idx_streamer_inventory_streamer on streamer_inventory_entries(streamer_id, occurred_at desc);
create index if not exists idx_streamer_inventory_agency_category on streamer_inventory_entries(agency_id, category);

comment on column streamer_inventory_entries.points is 'XP/pontos ganhos no registro, exibido como "jogo" no app (opcional)';
comment on column streamer_inventory_entries.source is 'manual | nome da tela que criou automaticamente (uso futuro)';
comment on column streamer_inventory_entries.source_id is 'id do registro de origem na tela que criou automaticamente (uso futuro, sem FK pois a origem varia)';

insert into storage.buckets (id, name, public)
values ('streamer_inventory', 'streamer_inventory', true)
on conflict (id) do nothing;

-- ============================================================================
-- RLS
-- ============================================================================
alter table streamer_inventory_entries enable row level security;

drop policy if exists "streamer_inventory_agency" on streamer_inventory_entries;
create policy "streamer_inventory_agency" on streamer_inventory_entries
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

-- Streamer (app) so le o proprio inventario.
drop policy if exists "streamer_inventory_streamer_select" on streamer_inventory_entries;
create policy "streamer_inventory_streamer_select" on streamer_inventory_entries
  for select using (
    streamer_id in (select id from profiles where auth_user_id = auth.uid())
  );

drop policy if exists "streamer_inventory_storage_all" on storage.objects;
create policy "streamer_inventory_storage_all" on storage.objects
  for all
  to authenticated
  using (bucket_id = 'streamer_inventory')
  with check (bucket_id = 'streamer_inventory');
