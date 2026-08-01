-- ============================================================================
-- Evolucao do Onboarding 0-15 Dias + preparo pro novo modulo Onboarding
-- 16-31 Dias.
--
-- 1) Renomeia a coluna final (stage_key "avaliacao") de "Avaliacao Final"
--    para "Conclusao do Onboarding" -- so o nome exibido, a stage_key
--    continua "avaliacao" (nao mexe em nenhum dado ja gravado por chave).
-- 2) Nova coluna is_recovery_stage em streamer_phase_stages, mesmo padrao
--    de is_evaluation_stage (0028) -- marca qual etapa e a de "Plano de
--    Recuperacao" de cada fase, sem precisar hardcode de string na UI.
-- 3) Semeia a stage "plano_recuperacao" (Plano de Recuperacao) logo apos a
--    conclusao, pra cada agencia que ja tem o Onboarding 0-15 configurado.
-- 4) Amplia o CHECK de streamer_phase_progress.outcome pra aceitar
--    'plano_recuperacao' -- mantem 'revisao' na lista so por causa de linhas
--    historicas antigas, a UI nao oferece mais essa opcao.
--
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

update streamer_phase_stages
set name = 'Conclusão do Onboarding'
where phase_key = 'onboarding_0_15' and stage_key = 'avaliacao';

alter table streamer_phase_stages
  add column if not exists is_recovery_stage boolean not null default false;

do $$
declare
  ag record;
  max_order int;
begin
  for ag in
    select distinct agency_id from streamer_phase_stages
    where phase_key = 'onboarding_0_15' and agency_id is not null
  loop
    select coalesce(max(order_index), 16) into max_order
    from streamer_phase_stages
    where agency_id = ag.agency_id and phase_key = 'onboarding_0_15';

    insert into streamer_phase_stages
      (agency_id, phase_key, stage_key, name, order_index, color, is_recovery_stage)
    values
      (ag.agency_id, 'onboarding_0_15', 'plano_recuperacao', 'Plano de Recuperação', max_order + 1, '#F2C94C', true)
    on conflict (agency_id, phase_key, stage_key) do nothing;
  end loop;
end $$;

alter table streamer_phase_progress
  drop constraint if exists streamer_phase_progress_outcome_check;

alter table streamer_phase_progress
  add constraint streamer_phase_progress_outcome_check
  check (outcome in ('aprovado', 'revisao', 'desligado', 'graduado', 'plano_recuperacao'));
