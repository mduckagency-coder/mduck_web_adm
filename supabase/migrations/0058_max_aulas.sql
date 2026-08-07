-- ============================================================================
-- MAX Aulas (Home Central > Configuracao Animacao APP > MAX Aulas)
-- Aulas cadastradas aqui aparecem no botao MAX do aplicativo do streamer.
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

create table if not exists max_lessons (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  title text not null,
  description text,
  category text not null check (category in ('geral', 'batalha', 'musico', 'games')),
  level text not null default 'iniciante' check (level in ('iniciante', 'veterano', 'pro')),
  cover_image_url text not null,
  video_source text not null check (video_source in ('upload', 'youtube')),
  video_url text not null,
  is_active boolean not null default true,
  created_by uuid references managers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_max_lessons_agency on max_lessons(agency_id, is_active);

insert into storage.buckets (id, name, public)
values ('max_lessons', 'max_lessons', true)
on conflict (id) do nothing;

-- ============================================================================
-- RLS
-- ============================================================================
alter table max_lessons enable row level security;

drop policy if exists "max_lessons_agency" on max_lessons;
create policy "max_lessons_agency" on max_lessons
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

-- Streamers (app) so leem aulas ativas da propria agencia.
drop policy if exists "max_lessons_streamer_select" on max_lessons;
create policy "max_lessons_streamer_select" on max_lessons
  for select using (
    is_active = true
    and agency_id = (select agency_id from profiles where auth_user_id = auth.uid())
  );

drop policy if exists "max_lessons_storage_all" on storage.objects;
create policy "max_lessons_storage_all" on storage.objects
  for all
  to authenticated
  using (bucket_id = 'max_lessons')
  with check (bucket_id = 'max_lessons');
