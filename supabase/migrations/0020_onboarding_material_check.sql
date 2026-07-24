-- ============================================================================
-- Check Materiais do Onboarding 0-15 Dias: lista de itens configuravel por
-- etapa (mesma engrenagem que ja configura o "Checklist desta etapa"), que
-- o gestor vai marcando conforme revisa os materiais com o streamer.
-- Separada do streamer_phase_checklist_items (que trava o avanco de etapa)
-- porque este check e so um acompanhamento, sem bloquear nada.
-- Rode manualmente no SQL Editor do Supabase. Aditivo.
-- ============================================================================

create table if not exists onboarding_material_check_items (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  phase_key text not null,
  stage_key text not null,
  item_key text not null,
  label text not null,
  order_index int not null default 999,
  created_at timestamptz not null default now(),
  unique (agency_id, phase_key, stage_key, item_key)
);
create index if not exists idx_onboarding_material_check_items_stage on onboarding_material_check_items(agency_id, phase_key, stage_key);

create table if not exists onboarding_material_check_progress (
  id uuid primary key default gen_random_uuid(),
  streamer_id uuid not null references profiles(id) on delete cascade,
  phase_key text not null,
  stage_key text not null,
  item_key text not null,
  done boolean not null default false,
  done_at timestamptz,
  done_by uuid references managers(id),
  unique (streamer_id, phase_key, stage_key, item_key)
);
create index if not exists idx_onboarding_material_check_progress_streamer on onboarding_material_check_progress(streamer_id, phase_key, stage_key);

alter table onboarding_material_check_items enable row level security;
drop policy if exists "onboarding_material_check_items_agency" on onboarding_material_check_items;
create policy "onboarding_material_check_items_agency" on onboarding_material_check_items
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

alter table onboarding_material_check_progress enable row level security;
drop policy if exists "onboarding_material_check_progress_agency" on onboarding_material_check_progress;
create policy "onboarding_material_check_progress_agency" on onboarding_material_check_progress
  for all using (
    exists (
      select 1 from streamer_phase_progress p
      join managers m on m.id = p.manager_id
      where p.streamer_id = onboarding_material_check_progress.streamer_id
      and p.phase_key = onboarding_material_check_progress.phase_key
      and m.agency_id = (select agency_id from managers where id = auth.uid())
    )
  )
  with check (true);
