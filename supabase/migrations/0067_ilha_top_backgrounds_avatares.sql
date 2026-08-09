-- ============================================================================
-- Ilha Top: banco de videos/imagens de fundo (com regra de horario e modo
-- fixo/aleatorio), banco de avatares "pato" e posicoes (x/y) de cada slot
-- da ilha (Top 1 destaque, Top 2..Top 10 fixos, Top 11+ area unica).
--
-- streamer_islands ja existe em producao (lida/gravada por
-- lib/features/ilha_top_duckers/ilha_top_duckers_page.dart) - so ganha a
-- coluna avatar_id aqui. Aditivo/idempotente, rode manualmente no SQL Editor
-- do Supabase.
-- ============================================================================

create table if not exists island_backgrounds (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  label text not null,
  media_url text not null,
  media_type text not null check (media_type in ('video','image')),
  start_time time not null default '00:00',
  end_time time not null default '23:59',
  mode text not null default 'fixed' check (mode in ('fixed','random')),
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_island_backgrounds_agency on island_backgrounds(agency_id, is_active);

comment on table island_backgrounds is 'Banco de videos/imagens de fundo da Ilha Top. start_time/end_time definem a janela de horario (pode cruzar meia-noite); mode=fixed sempre aparece na janela, mode=random e sorteado entre os que competem pela mesma janela.';

create table if not exists island_avatars (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  label text not null,
  media_url text not null,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists idx_island_avatars_agency on island_avatars(agency_id, is_active);

comment on table island_avatars is 'Banco de avatares "pato" (video em loop) que o streamer escolhe no app dele. O app grava a escolha em streamer_islands.avatar_id.';

create table if not exists island_slots (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  slot_key text not null,
  label text not null,
  pos_x numeric not null default 50,
  pos_y numeric not null default 50,
  scale numeric not null default 1,
  z_index int not null default 0,
  unique (agency_id, slot_key)
);

comment on table island_slots is 'Posicoes (% x/y sobre a imagem de fundo) de cada slot da ilha. slot_key: top_1..top_10, top_11_plus. Preenchido via editor visual no admin.';

alter table streamer_islands add column if not exists avatar_id uuid references island_avatars(id);

-- ============================================================================
-- Storage
-- ============================================================================
insert into storage.buckets (id, name, public, file_size_limit)
values ('island_media', 'island_media', true, 15728640)
on conflict (id) do update set file_size_limit = excluded.file_size_limit;

drop policy if exists "island_media_storage_all" on storage.objects;
create policy "island_media_storage_all" on storage.objects
  for all
  to authenticated
  using (bucket_id = 'island_media')
  with check (bucket_id = 'island_media');

-- ============================================================================
-- RLS
-- ============================================================================
alter table island_backgrounds enable row level security;
alter table island_avatars enable row level security;
alter table island_slots enable row level security;

drop policy if exists "island_backgrounds_agency" on island_backgrounds;
create policy "island_backgrounds_agency" on island_backgrounds
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "island_backgrounds_streamer_select" on island_backgrounds;
create policy "island_backgrounds_streamer_select" on island_backgrounds
  for select using (
    is_active and agency_id = (select agency_id from profiles where auth_user_id = auth.uid())
  );

drop policy if exists "island_avatars_agency" on island_avatars;
create policy "island_avatars_agency" on island_avatars
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "island_avatars_streamer_select" on island_avatars;
create policy "island_avatars_streamer_select" on island_avatars
  for select using (
    is_active and agency_id = (select agency_id from profiles where auth_user_id = auth.uid())
  );

drop policy if exists "island_slots_agency" on island_slots;
create policy "island_slots_agency" on island_slots
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "island_slots_streamer_select" on island_slots;
create policy "island_slots_streamer_select" on island_slots
  for select using (
    agency_id = (select agency_id from profiles where auth_user_id = auth.uid())
  );

-- Streamer pode gravar o proprio avatar escolhido (app mduck_lives).
drop policy if exists "streamer_islands_streamer_update_avatar" on streamer_islands;
create policy "streamer_islands_streamer_update_avatar" on streamer_islands
  for update using (
    streamer_id = (select id from profiles where auth_user_id = auth.uid())
  )
  with check (
    streamer_id = (select id from profiles where auth_user_id = auth.uid())
  );

-- ============================================================================
-- Funcao: escolhe o fundo certo pra um horario, respeitando fixo/aleatorio.
-- Usada tanto pelo admin (pre-visualizacao) quanto pelo app do streamer via
-- supabase.rpc('island_pick_background', {p_agency_id: ..., p_at: ...}).
-- ============================================================================
create or replace function island_pick_background(p_agency_id uuid, p_at timestamptz default now())
returns island_backgrounds
language plpgsql stable
as $$
declare
  v_time time := (p_at at time zone 'America/Sao_Paulo')::time;
  v_row island_backgrounds;
begin
  select * into v_row from island_backgrounds
  where agency_id = p_agency_id and is_active and mode = 'fixed'
    and (case when start_time <= end_time then v_time between start_time and end_time
              else v_time >= start_time or v_time <= end_time end)
  order by sort_order
  limit 1;
  if found then return v_row; end if;

  select * into v_row from island_backgrounds
  where agency_id = p_agency_id and is_active
    and (case when start_time <= end_time then v_time between start_time and end_time
              else v_time >= start_time or v_time <= end_time end)
  order by random()
  limit 1;
  if found then return v_row; end if;

  select * into v_row from island_backgrounds
  where agency_id = p_agency_id and is_active
  order by sort_order
  limit 1;
  return v_row;
end;
$$;
