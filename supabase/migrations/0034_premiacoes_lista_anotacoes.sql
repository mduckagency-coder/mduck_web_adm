-- ============================================================================
-- Premiacoes de programa passam a suportar varios itens (mesmo padrao ja
-- usado em Eventos > Premiacoes, migration 0025_event_awards_streamer_link)
-- e previsao de entrega; Anotacoes (bloco de notas livre por programa) no
-- lugar do antigo slot de Campanhas na tela do programa. Rode manualmente
-- no SQL Editor do Supabase. Aditivo: nao altera nem apaga dados existentes.
-- ============================================================================

alter table program_awards add column if not exists items jsonb not null default '[]'::jsonb;
alter table program_awards add column if not exists scheduled_delivery_date date;

update program_awards set items = jsonb_build_array(jsonb_build_object('name', title, 'quantity', 1, 'value', null))
where items = '[]'::jsonb and title is not null;

-- Anotacoes livres do gestor sobre o programa -- sem ciclo/mes, so uma lista
-- cronologica continua (substitui o slot da aba Campanhas na tela do
-- programa; o sistema de Campanhas Mensais em si continua existindo no
-- banco e no codigo, so nao fica mais acessivel por essa aba).
create table if not exists program_notes (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references development_programs(id) on delete cascade,
  agency_id uuid not null,
  author_id uuid references managers(id),
  body text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_program_notes_program on program_notes(program_id, created_at desc);

alter table program_notes enable row level security;
drop policy if exists "program_notes_agency" on program_notes;
create policy "program_notes_agency" on program_notes for all using (
  agency_id = (select agency_id from managers where id = auth.uid())
) with check (
  agency_id = (select agency_id from managers where id = auth.uid())
);
