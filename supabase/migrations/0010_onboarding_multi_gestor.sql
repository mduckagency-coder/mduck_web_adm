-- ============================================================================
-- Onboarding 0-15 Dias: multiplos gestores por card, arquivamento por
-- periodo. Rode manualmente no SQL Editor do Supabase, depois da 0009.
-- Aditivo/idempotente: nao apaga dados, so migra o manager_id (singular)
-- existente para uma tabela N:N nova, sem perder vinculos.
--
-- Motivacao: hoje streamer_phase_progress.manager_id e 1:1, mas o negocio
-- ja opera com mais de um colaborador responsavel por streamer em outras
-- telas (lead_onboarding_gestores, N:N, no lado do recrutador). Alem disso
-- a RLS atual libera leitura quando manager_id is null sem checar agencia
-- -- corrigido aqui denormalizando agency_id direto no card.
-- ============================================================================

-- 1) Tabela de juncao gestores <-> card (mesmo padrao de lead_onboarding_gestores).
create table if not exists streamer_phase_progress_managers (
  id uuid primary key default gen_random_uuid(),
  progress_id uuid not null references streamer_phase_progress(id) on delete cascade,
  manager_id uuid not null references managers(id) on delete cascade,
  added_at timestamptz not null default now(),
  added_by uuid references managers(id),
  unique (progress_id, manager_id)
);
create index if not exists idx_spp_managers_progress on streamer_phase_progress_managers(progress_id);
create index if not exists idx_spp_managers_manager on streamer_phase_progress_managers(manager_id);

-- 2) Denormaliza agency_id no card. Corrige a brecha de RLS do
-- "manager_id is null" (que nao checava agencia) e simplifica a
-- autorizacao agora que o card pode ter varios gestores.
alter table streamer_phase_progress add column if not exists agency_id uuid;

update streamer_phase_progress p
set agency_id = coalesce(
  (select m.agency_id from managers m where m.id = p.manager_id),
  (select pr.agency_id from profiles pr where pr.id = p.streamer_id)
)
where agency_id is null;

create index if not exists idx_streamer_phase_progress_agency
  on streamer_phase_progress(agency_id, phase_key) where completed_at is null;

-- 3) Arquivamento por periodo: oculta do board principal mas mantem
-- consultavel (nao apaga).
alter table streamer_phase_progress add column if not exists archived_at timestamptz;
alter table streamer_phase_progress add column if not exists archived_by uuid references managers(id);

-- 4) Email do streamer usado no dialog "Novo Agenciado" (idempotente --
-- ja usado em outras telas, ex. streamer_detail_panel.dart).
alter table profiles add column if not exists email text;

-- ============================================================================
-- Migracao de dados: manager_id singular -> tabela N:N (idempotente).
-- ============================================================================
insert into streamer_phase_progress_managers (progress_id, manager_id)
select id, manager_id from streamer_phase_progress
where manager_id is not null
on conflict (progress_id, manager_id) do nothing;

-- ============================================================================
-- RLS
-- ============================================================================
drop policy if exists "streamer_phase_progress_agency" on streamer_phase_progress;
create policy "streamer_phase_progress_agency" on streamer_phase_progress
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

alter table streamer_phase_progress_managers enable row level security;
drop policy if exists "streamer_phase_progress_managers_agency" on streamer_phase_progress_managers;
create policy "streamer_phase_progress_managers_agency" on streamer_phase_progress_managers
  for all using (
    exists (
      select 1 from streamer_phase_progress p
      where p.id = streamer_phase_progress_managers.progress_id
      and p.agency_id = (select agency_id from managers where id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from streamer_phase_progress p
      where p.id = streamer_phase_progress_managers.progress_id
      and p.agency_id = (select agency_id from managers where id = auth.uid())
    )
  );

-- Simplifica checklist_progress para usar o agency_id do card (nao mais
-- depender do manager_id singular, que agora e legado).
drop policy if exists "streamer_phase_checklist_progress_agency" on streamer_phase_checklist_progress;
create policy "streamer_phase_checklist_progress_agency" on streamer_phase_checklist_progress
  for all using (
    exists (
      select 1 from streamer_phase_progress p
      where p.streamer_id = streamer_phase_checklist_progress.streamer_id
      and p.phase_key = streamer_phase_checklist_progress.phase_key
      and p.agency_id = (select agency_id from managers where id = auth.uid())
    )
  )
  with check (true);
