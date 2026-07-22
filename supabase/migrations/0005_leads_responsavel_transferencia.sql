-- ============================================================================
-- Leads - Responsavel & Transferencia
-- Rode manualmente no SQL Editor do Supabase (mesmo padrao das migrations
-- 0001-0004: leads/lead_history/lead_kanban_stages/lead_categories ja
-- existem, criados direto no dashboard, entao aqui so criamos o que falta).
-- Aditivo: seguro rodar mesmo que as tabelas abaixo ja existam. Nao apaga
-- nem altera dados existentes, exceto o backfill idempotente da secao 3.
-- ============================================================================

-- 1) Registro estruturado de transferencias de lead entre recrutadores
--    (mesmo padrao de streamer_transfers para transferencia de streamers).
create table if not exists lead_transfers (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references leads(id) on delete cascade,
  previous_recruiter_id uuid references managers(id),
  new_recruiter_id uuid not null references managers(id),
  performed_by uuid not null references managers(id),
  reason text,
  transferred_at timestamptz not null default now()
);
create index if not exists idx_lead_transfers_lead on lead_transfers(lead_id);
create index if not exists idx_lead_transfers_new_recruiter on lead_transfers(new_recruiter_id);

alter table lead_transfers enable row level security;
drop policy if exists "lead_transfers_agency" on lead_transfers;
create policy "lead_transfers_agency" on lead_transfers
  for all using (
    exists (
      select 1 from leads l
      where l.id = lead_transfers.lead_id
      and l.agency_id = (select agency_id from managers where id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from leads l
      where l.id = lead_transfers.lead_id
      and l.agency_id = (select agency_id from managers where id = auth.uid())
    )
  );

-- 2) Todo lead deve ter responsavel. Confira antes se ha leads sem
-- responsavel (select count(*) from leads where recruiter_id is null); se
-- houver, atribua um responsavel manualmente e so entao descomente a linha
-- abaixo (nao aplicada automaticamente por seguranca).
-- alter table leads alter column recruiter_id set not null;

-- 3) Backfill idempotente: garante uma entrada "criacao" no historico para
-- leads que ja existiam antes desta funcionalidade (evita buraco no
-- historico de dados antigos). Seguro rodar mais de uma vez.
insert into lead_history (lead_id, action, detail, performed_by, created_at)
select l.id, 'criacao', 'Lead cadastrado', l.recruiter_id, l.created_at
from leads l
where not exists (
  select 1 from lead_history h where h.lead_id = l.id and h.action = 'criacao'
);
