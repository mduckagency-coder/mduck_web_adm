-- ============================================================================
-- Metas personalizadas, regra de aprovacao, motivo de reprovacao, registro de
-- alteracoes de configuracao e protecao contra duplicidade em ciclos
-- (Programas de Desenvolvimento). Rode manualmente no SQL Editor do
-- Supabase. Aditivo: nao altera nem apaga dados existentes.
--
-- OBS: metas habilitadas/obrigatorias e a regra de aprovacao (todas / so
-- obrigatorias / percentual minimo) NAO exigem coluna nova -- ficam dentro
-- do proprio jsonb development_programs.criteria, que ja existe. O
-- arquivamento automatico ao concluir/reprovar tambem NAO exige coluna nova
-- -- reaproveita archived_at/archived_by, que streamer_phase_progress ja tem
-- desde a migration 0010 (usados hoje pelo board do Onboarding 0-15 Dias).
-- ============================================================================

-- Motivo de reprovacao (so preenchido quando outcome = desligado) e
-- observacoes livres do gestor na avaliacao final (qualquer outcome).
alter table streamer_phase_progress add column if not exists outcome_reason text;
alter table streamer_phase_progress add column if not exists outcome_note text;

-- Registro de alteracoes de configuracao de um programa: quem mudou, o que,
-- valor anterior e novo. Generico o bastante pra qualquer programa futuro
-- (so referencia program_id, sem nenhum campo especifico de programa).
create table if not exists program_config_history (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references development_programs(id) on delete cascade,
  agency_id uuid not null,
  changed_by uuid references managers(id),
  field text not null,
  old_value text,
  new_value text,
  created_at timestamptz not null default now()
);
create index if not exists idx_program_config_history_program on program_config_history(program_id, created_at desc);

alter table program_config_history enable row level security;
drop policy if exists "program_config_history_agency" on program_config_history;
create policy "program_config_history_agency" on program_config_history for all using (
  agency_id = (select agency_id from managers where id = auth.uid())
) with check (
  agency_id = (select agency_id from managers where id = auth.uid())
);

-- Duplicidade: um streamer nao pode participar duas vezes do mesmo ciclo
-- mensal. O app (syncCycleParticipants) ja evita isso na pratica; esta
-- constraint e so a rede de seguranca no banco. Limpeza defensiva antes de
-- criar a constraint, caso ja exista alguma duplicata registrada.
delete from campaign_cycle_participants a
  using campaign_cycle_participants b
  where a.cycle_id = b.cycle_id
    and a.streamer_id = b.streamer_id
    and a.id > b.id;

alter table campaign_cycle_participants drop constraint if exists campaign_cycle_participants_cycle_streamer_key;
alter table campaign_cycle_participants add constraint campaign_cycle_participants_cycle_streamer_key unique (cycle_id, streamer_id);
