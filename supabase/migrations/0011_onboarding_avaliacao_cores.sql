-- ============================================================================
-- Onboarding 0-15 Dias: cores por faixa de dias e etapa final de Avaliacao
-- (aprovado / revisao / desligado). Rode manualmente no SQL Editor do
-- Supabase, depois da 0010. Aditivo/idempotente.
-- ============================================================================

-- 1) Resultado da avaliacao final do onboarding.
alter table streamer_phase_progress add column if not exists outcome text check (outcome in ('aprovado', 'revisao', 'desligado'));

-- 2) Cores por faixa de dias nas colunas ja existentes (dia 0 / dias 1-3 /
-- dias 4-7 / dias 8-15), sobrescrevendo a cor unica usada ate agora.
update streamer_phase_stages set color = '#F2994A' where phase_key = 'onboarding_0_15' and stage_key = 'dia_0';
update streamer_phase_stages set color = '#2D9CDB' where phase_key = 'onboarding_0_15' and stage_key in ('dia_1', 'dia_2', 'dia_3');
update streamer_phase_stages set color = '#7A0BD4' where phase_key = 'onboarding_0_15' and stage_key in ('dia_4', 'dia_5', 'dia_6', 'dia_7');
update streamer_phase_stages set color = '#27AE60' where phase_key = 'onboarding_0_15' and stage_key in ('dia_8', 'dia_9', 'dia_10', 'dia_11', 'dia_12', 'dia_13', 'dia_14', 'dia_15');

-- 3) Renomeia dia_15 para nao duplicar o nome "Avaliacao Final" com a
-- nova etapa de decisao criada abaixo.
update streamer_phase_stages set name = 'Dia 15 - Ultimo Dia' where phase_key = 'onboarding_0_15' and stage_key = 'dia_15' and name = 'Dia 15 - Avaliacao Final';

-- 4) Nova etapa final "Avaliacao Final" (decisao do gestor: aprovado,
-- revisao ou desligado), depois do dia_15. Sem checklist obrigatorio --
-- e uma etapa de decisao, nao de tarefas.
do $$
declare
  ag record;
begin
  for ag in select distinct agency_id from managers where agency_id is not null loop
    insert into streamer_phase_stages (agency_id, phase_key, stage_key, name, order_index, color)
    values (ag.agency_id, 'onboarding_0_15', 'avaliacao', 'Avaliacao Final', 16, '#EB5757')
    on conflict (agency_id, phase_key, stage_key) do nothing;
  end loop;
end $$;
