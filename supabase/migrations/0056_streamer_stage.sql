-- ============================================================================
-- Gestao de Streamers: posicao atual do streamer no board (qual "coluna" ele
-- esta, por causa de uma acao registrada pelo gestor ou de um arrastar
-- manual). Substitui streamer_gestao_overrides (fixacao) -- aqui a posicao
-- SEMPRE eh explicita, nao existe mais calculo automatico por cima.
--
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

create table if not exists streamer_stage (
  id uuid primary key default gen_random_uuid(),
  streamer_id uuid not null references profiles(id) on delete cascade,
  agency_id uuid not null,
  -- Sem CHECK rigido de proposito (mesmo espirito de streamer_tasks.activity_type,
  -- migration 0045): mais facil adicionar um tipo de acao novo depois sem
  -- outra migration. Ausencia de linha == "painel_geral".
  stage_key text not null default 'painel_geral',
  note text,
  due_at timestamptz,
  set_by uuid references managers(id),
  set_at timestamptz not null default now(),
  unique (streamer_id)
);

create index if not exists streamer_stage_agency_idx on streamer_stage (agency_id);

alter table streamer_stage enable row level security;

drop policy if exists "streamer_stage_agency" on streamer_stage;
create policy "streamer_stage_agency" on streamer_stage
  for all
  using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));
