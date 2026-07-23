-- ============================================================================
-- Onboarding 0-15 Dias: card aparece assim que o convite e enviado pelo
-- recrutador, antes mesmo do streamer ser oficialmente vinculado ao
-- cadastro (leads.converted_streamer_id). Rode manualmente no SQL Editor
-- do Supabase, depois da 0011. Aditivo/idempotente.
--
-- Motivacao: ate agora o card do Onboarding so era criado depois que o
-- streamer ja estava vinculado (profiles.id valido). O gestor pedia pra
-- ver o streamer no card 0 assim que o convite fosse enviado -- antes
-- disso so existia a pagina separada "Proximos Agenciados". Para isso,
-- streamer_id vira opcional e passa a existir lead_id: um card pode
-- nascer "baseado no lead" (streamer_id null, lead_id preenchido) e
-- depois ser promovido pro streamer oficial (streamer_id preenchido,
-- lead_id fica null) quando o vinculo acontecer, sem duplicar a linha.
-- ============================================================================

-- 1) streamer_id deixa de ser obrigatorio; lead_id passa a existir como
-- referencia alternativa enquanto o streamer nao e oficialmente vinculado.
alter table streamer_phase_progress alter column streamer_id drop not null;
alter table streamer_phase_progress add column if not exists lead_id uuid references leads(id) on delete cascade;
alter table streamer_phase_progress drop constraint if exists chk_streamer_phase_progress_ref;
alter table streamer_phase_progress add constraint chk_streamer_phase_progress_ref check (streamer_id is not null or lead_id is not null);

-- Um lead so pode ter um card "pre-vinculo" por fase (evita duplicar se o
-- recrutador marcar/desmarcar convite_enviado varias vezes).
create unique index if not exists idx_streamer_phase_progress_lead_unique
  on streamer_phase_progress(lead_id, phase_key) where streamer_id is null;

-- 2) Mesma flexibilizacao no historico, que hoje tambem exige streamer_id
-- -- sem isso, nao daria pra registrar nada enquanto o card for so do lead.
alter table streamer_phase_history alter column streamer_id drop not null;
alter table streamer_phase_history add column if not exists lead_id uuid references leads(id) on delete cascade;
alter table streamer_phase_history drop constraint if exists chk_streamer_phase_history_ref;
alter table streamer_phase_history add constraint chk_streamer_phase_history_ref check (streamer_id is not null or lead_id is not null);
