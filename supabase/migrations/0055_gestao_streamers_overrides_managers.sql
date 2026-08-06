-- ============================================================================
-- Gestao de Streamers: fixacao manual de bloco (drag-and-drop persistente) e
-- multiplos gestores por streamer (co-gestores, independente de onboarding).
--
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

-- 1) Fixacao manual de bloco -- quando o gestor arrasta um card pra outra
-- coluna, o streamer fica "travado" naquele bloco ate ser desafixado, em vez
-- de o calculo automatico (streamer_gestao_classifier.dart) reclassificar
-- ele de novo no proximo recarregamento.
create table if not exists streamer_gestao_overrides (
  id uuid primary key default gen_random_uuid(),
  streamer_id uuid not null references profiles(id) on delete cascade,
  agency_id uuid not null,
  bloco text not null check (bloco in ('inatividade', 'prioridadeMaxima', 'perdeuRitmo', 'emCrescimento', 'acompanharSemana', 'emDia')),
  pinned_by uuid references managers(id),
  pinned_at timestamptz not null default now(),
  unique (streamer_id)
);

create index if not exists streamer_gestao_overrides_agency_idx on streamer_gestao_overrides (agency_id);

alter table streamer_gestao_overrides enable row level security;

drop policy if exists "streamer_gestao_overrides_agency" on streamer_gestao_overrides;
create policy "streamer_gestao_overrides_agency" on streamer_gestao_overrides
  for all
  using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

-- 2) Multiplos gestores responsaveis por streamer -- mesmo padrao N:N de
-- streamer_phase_progress_managers (0010_onboarding_multi_gestor.sql), so
-- que chaveado direto por streamer_id em vez de um card de onboarding, pra
-- continuar valendo depois que o streamer se forma. Nao substitui
-- profiles.assigned_manager_id (continua sendo o gestor responsavel unico
-- usado no resto do CRM) -- e uma camada adicional de co-gestores.
create table if not exists streamer_managers (
  id uuid primary key default gen_random_uuid(),
  streamer_id uuid not null references profiles(id) on delete cascade,
  manager_id uuid not null references managers(id) on delete cascade,
  added_at timestamptz not null default now(),
  added_by uuid references managers(id),
  unique (streamer_id, manager_id)
);

create index if not exists streamer_managers_streamer_idx on streamer_managers (streamer_id);
create index if not exists streamer_managers_manager_idx on streamer_managers (manager_id);

alter table streamer_managers enable row level security;

drop policy if exists "streamer_managers_agency" on streamer_managers;
create policy "streamer_managers_agency" on streamer_managers
  for all
  using (
    exists (
      select 1 from profiles p
      where p.id = streamer_managers.streamer_id
      and p.agency_id = (select agency_id from managers where id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from profiles p
      where p.id = streamer_managers.streamer_id
      and p.agency_id = (select agency_id from managers where id = auth.uid())
    )
  );
