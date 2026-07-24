-- ============================================================================
-- Anotacoes gerais do evento: mural de observacoes escritas manualmente
-- pelos gestores (diferente do Historico, que e um log automatico
-- read-only). Qualquer gestor da agencia ve, edita e exclui. Pode marcar
-- um streamer especifico ou deixar geral.
-- Rode manualmente no SQL Editor do Supabase. Aditivo.
-- ============================================================================
create table if not exists event_notes (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references agency_events(id) on delete cascade,
  streamer_id uuid references profiles(id),
  content text not null,
  created_by uuid references managers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz
);
create index if not exists idx_event_notes_event on event_notes(event_id, created_at);

alter table event_notes enable row level security;
drop policy if exists "event_notes_agency" on event_notes;
create policy "event_notes_agency" on event_notes
  for all using (exists (select 1 from agency_events e where e.id = event_notes.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())))
  with check (exists (select 1 from agency_events e where e.id = event_notes.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())));
