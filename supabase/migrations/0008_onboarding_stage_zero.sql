-- ============================================================================
-- Gestao - Onboarding 0-15 Dias: ajuste na Etapa 0
-- Rode manualmente no SQL Editor do Supabase, depois da 0007.
-- Aditivo/idempotente: nao apaga nem altera as 15 colunas (dia_1..dia_15)
-- ja criadas pela 0007, so adiciona uma nova coluna "0 - Proximos
-- Agenciados" antes delas (order_index 0, sem checklist obrigatorio, pra
-- o gestor poder arrastar o card livremente pra "Dia 1" quando quiser
-- comecar a contagem).
-- ============================================================================

do $$
declare
  ag record;
begin
  for ag in select distinct agency_id from managers where agency_id is not null loop
    insert into streamer_phase_stages (agency_id, phase_key, stage_key, name, order_index, color)
    values (ag.agency_id, 'onboarding_0_15', 'dia_0', '0 - Proximos Agenciados', 0, '#7A0BD4')
    on conflict (agency_id, phase_key, stage_key) do nothing;
  end loop;
end $$;
