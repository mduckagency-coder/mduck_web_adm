-- ============================================================================
-- Gestao - Onboarding 0-15 Dias (Fase 1 do acompanhamento por fases)
-- Rode manualmente no SQL Editor do Supabase (mesmo padrao das migrations
-- anteriores). Aditivo: nao altera nem apaga dados existentes.
--
-- Nomenclatura generica por fase (coluna phase_key) pensando nas proximas
-- fases (Acompanhamento 15-30, Novatos, etc.) reaproveitarem a mesma
-- estrutura sem migration nova. Nesta etapa so populamos phase_key =
-- 'onboarding_0_15'.
-- ============================================================================

-- 1) Colunas do Kanban por fase (editavel no futuro, mesmo padrao de
-- lead_kanban_stages).
create table if not exists streamer_phase_stages (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  phase_key text not null,
  stage_key text not null,
  name text not null,
  order_index int not null default 999,
  color text not null default '#7A0BD4',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (agency_id, phase_key, stage_key)
);
create index if not exists idx_streamer_phase_stages_phase on streamer_phase_stages(agency_id, phase_key, order_index);

-- 2) Itens obrigatorios de checklist por etapa.
create table if not exists streamer_phase_checklist_items (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  phase_key text not null,
  stage_key text not null,
  item_key text not null,
  label text not null,
  order_index int not null default 999,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (agency_id, phase_key, stage_key, item_key)
);
create index if not exists idx_streamer_phase_checklist_items_stage on streamer_phase_checklist_items(agency_id, phase_key, stage_key);

-- 3) O card em si: um streamer numa fase, numa etapa.
create table if not exists streamer_phase_progress (
  id uuid primary key default gen_random_uuid(),
  streamer_id uuid not null references profiles(id) on delete cascade,
  phase_key text not null,
  stage_key text not null,
  manager_id uuid references managers(id),
  started_at timestamptz not null default now(),
  stage_changed_at timestamptz not null default now(),
  completed_at timestamptz,
  created_by uuid references managers(id),
  unique (streamer_id, phase_key)
);
create index if not exists idx_streamer_phase_progress_manager on streamer_phase_progress(manager_id, phase_key) where completed_at is null;

-- 4) Marcacao de cada item do checklist (fica registrado mesmo apos avancar
-- de etapa, para historico).
create table if not exists streamer_phase_checklist_progress (
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

-- 5) Historico automatico desta fase (a Timeline do CRM tambem le esta
-- tabela, junto com lead_history/manager_assignment_history/etc).
create table if not exists streamer_phase_history (
  id uuid primary key default gen_random_uuid(),
  streamer_id uuid not null references profiles(id) on delete cascade,
  phase_key text not null,
  action text not null,
  detail text,
  performed_by uuid references managers(id),
  created_at timestamptz not null default now()
);
create index if not exists idx_streamer_phase_history_streamer on streamer_phase_history(streamer_id);

-- ============================================================================
-- RLS (mesmo padrao agency-scoped das migrations anteriores)
-- ============================================================================
alter table streamer_phase_stages enable row level security;
drop policy if exists "streamer_phase_stages_agency" on streamer_phase_stages;
create policy "streamer_phase_stages_agency" on streamer_phase_stages
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

alter table streamer_phase_checklist_items enable row level security;
drop policy if exists "streamer_phase_checklist_items_agency" on streamer_phase_checklist_items;
create policy "streamer_phase_checklist_items_agency" on streamer_phase_checklist_items
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

alter table streamer_phase_progress enable row level security;
drop policy if exists "streamer_phase_progress_agency" on streamer_phase_progress;
create policy "streamer_phase_progress_agency" on streamer_phase_progress
  for all using (
    exists (select 1 from managers m where m.id = streamer_phase_progress.manager_id and m.agency_id = (select agency_id from managers where id = auth.uid()))
    or streamer_phase_progress.manager_id is null
  )
  with check (
    exists (select 1 from managers m where m.id = streamer_phase_progress.manager_id and m.agency_id = (select agency_id from managers where id = auth.uid()))
    or streamer_phase_progress.manager_id is null
  );

alter table streamer_phase_checklist_progress enable row level security;
drop policy if exists "streamer_phase_checklist_progress_agency" on streamer_phase_checklist_progress;
create policy "streamer_phase_checklist_progress_agency" on streamer_phase_checklist_progress
  for all using (
    exists (
      select 1 from streamer_phase_progress p
      join managers m on m.id = p.manager_id
      where p.streamer_id = streamer_phase_checklist_progress.streamer_id
      and p.phase_key = streamer_phase_checklist_progress.phase_key
      and m.agency_id = (select agency_id from managers where id = auth.uid())
    )
  )
  with check (true);

alter table streamer_phase_history enable row level security;
drop policy if exists "streamer_phase_history_agency" on streamer_phase_history;
create policy "streamer_phase_history_agency" on streamer_phase_history
  for all using (true)
  with check (true);

-- ============================================================================
-- Categoria do streamer ganha icon_key (mesmo padrao de lead_categories),
-- para exibir emoji em destaque nos cards do Onboarding 0-15.
-- ============================================================================
alter table streamer_categories add column if not exists icon_key text;

update streamer_categories set icon_key = 'musico' where icon_key is null and name ilike '%music%';
update streamer_categories set icon_key = 'gamer' where icon_key is null and name ilike '%game%';
update streamer_categories set icon_key = 'batalha' where icon_key is null and name ilike '%batalha%';
update streamer_categories set icon_key = 'lifestyle' where icon_key is null and name ilike '%lifestyle%';
update streamer_categories set icon_key = 'entretenimento' where icon_key is null and (name ilike '%entreten%' or name ilike '%humor%');

-- ============================================================================
-- Seed das 15 colunas + checklist padrao (sugestao inicial, editavel no
-- futuro). Idempotente por agencia: so insere o que ainda nao existe.
-- ============================================================================
do $$
declare
  ag record;
  stage_titles text[][] := array[
    array['dia_1', 'Dia 1 - Boas-vindas'],
    array['dia_2', 'Dia 2 - Materiais'],
    array['dia_3', 'Dia 3 - Configuracao'],
    array['dia_4', 'Dia 4 - Primeira Live'],
    array['dia_5', 'Dia 5 - Primeiro Acompanhamento'],
    array['dia_6', 'Dia 6 - Duvidas'],
    array['dia_7', 'Dia 7 - Primeira Semana'],
    array['dia_8', 'Dia 8 - Engajamento'],
    array['dia_9', 'Dia 9 - Acompanhamento'],
    array['dia_10', 'Dia 10 - Correcoes'],
    array['dia_11', 'Dia 11 - Desenvolvimento'],
    array['dia_12', 'Dia 12 - Evolucao'],
    array['dia_13', 'Dia 13 - Preparacao'],
    array['dia_14', 'Dia 14 - Pre-avaliacao'],
    array['dia_15', 'Dia 15 - Avaliacao Final']
  ];
  checklist_items text[][] := array[
    array['material_enviado', 'Material enviado'],
    array['mensagem_enviada', 'Mensagem enviada'],
    array['confirmou_recebimento', 'Confirmou recebimento'],
    array['assistiu_materiais', 'Assistiu aos materiais'],
    array['tirou_duvidas', 'Tirou duvidas'],
    array['realizou_live', 'Realizou live'],
    array['feedback_registrado', 'Feedback registrado'],
    array['etapa_concluida', 'Etapa concluida']
  ];
  i int;
  j int;
begin
  for ag in select distinct agency_id from managers where agency_id is not null loop
    for i in 1 .. array_length(stage_titles, 1) loop
      insert into streamer_phase_stages (agency_id, phase_key, stage_key, name, order_index, color)
      values (ag.agency_id, 'onboarding_0_15', stage_titles[i][1], stage_titles[i][2], i, '#7A0BD4')
      on conflict (agency_id, phase_key, stage_key) do nothing;

      for j in 1 .. array_length(checklist_items, 1) loop
        insert into streamer_phase_checklist_items (agency_id, phase_key, stage_key, item_key, label, order_index)
        values (ag.agency_id, 'onboarding_0_15', stage_titles[i][1], checklist_items[j][1], checklist_items[j][2], j)
        on conflict (agency_id, phase_key, stage_key, item_key) do nothing;
      end loop;
    end loop;
  end loop;
end $$;
