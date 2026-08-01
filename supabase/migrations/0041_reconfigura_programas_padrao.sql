-- ============================================================================
-- Reconfigura os criterios dos programas padrao (Onboarding -> Novatos ->
-- Veteranos -> Top Ducker -> 150k -> Elite -> Placas de Merito), seguindo a
-- especificacao exata pedida:
--
--   onboarding_0_15:    prerequisito de ate 20 dias na agencia
--   onboarding_30:      prerequisito de ate 35 dias na agencia
--   novatos:             ate 90 dias na agencia, abaixo de 40k diamantes
--   novatos_destaque:    ate 90 dias na agencia, 40k+ diamantes (mes atual
--                         ou anterior -- quem bateu no mes passado ja entra,
--                         quem bater agora tambem entra na hora)
--   veteranos_20k:        mais de 90 dias, ate 20k diamantes -- prioriza o
--                         mes FECHADO (anterior); so usa o mes atual quando
--                         o streamer ainda nao tem mes anterior fechado
--   veteranos_40k:        mais de 90 dias, de 20k+1 ate 40k -- mesma regra
--                         de periodo do 20k
--   top_ducker_80k:       80k a 149.999k, mes atual ou anterior
--   programa_150k:        150k a 249.999k, mes atual ou anterior
--   elite:                250k a 499.999k, mes atual ou anterior
--   placa_merito_500k:    500k a 749.999k, mes atual ou anterior
--   medalha_750k:         750k a 999.999k, mes atual ou anterior
--   placa_merito_1m:      1M+, mes atual ou anterior
--
-- Cada faixa de diamantes tem um teto (max_diamonds) igual ao piso da
-- proxima faixa menos 1, pra um streamer nunca aparecer em duas faixas ao
-- mesmo tempo -- so na mais alta que ele bate.
--
-- "mes_anterior_prioritario" e um periodo novo (ver _resolveMetric em
-- program_eligibility_service.dart): usa o mes fechado quando existe, e so
-- cai pro mes atual (ainda em andamento) se o streamer nao tiver nenhum mes
-- fechado ainda -- evita que um numero parcial do mes atual empurre alguem
-- pra fora da faixa antes da hora.
--
-- Substitui por completo o criteria de cada um desses 11 program_keys (nao
-- faz merge) -- reflete exatamente a especificacao acima. Rode manualmente
-- no SQL Editor do Supabase. Requer a migration 0038 (coluna days_live em
-- streamer_stat_snapshots) ja aplicada.
-- ============================================================================

update development_programs
set criteria = '{"max_days_in_agency": 20}'::jsonb
where program_key = 'onboarding_0_15';

update development_programs
set criteria = '{"max_days_in_agency": 35}'::jsonb
where program_key = 'onboarding_30';

update development_programs
set criteria = '{
  "max_days_in_agency": 90,
  "max_diamonds": 39999,
  "diamonds_period": "mes_atual_ou_anterior",
  "membership_mode": "faixa"
}'::jsonb
where program_key = 'novatos';

update development_programs
set criteria = '{
  "max_days_in_agency": 90,
  "min_diamonds": 40000,
  "diamonds_period": "mes_atual_ou_anterior",
  "membership_mode": "faixa"
}'::jsonb
where program_key = 'novatos_destaque';

update development_programs
set criteria = '{
  "min_days": 91,
  "max_diamonds": 20000,
  "diamonds_period": "mes_anterior_prioritario",
  "membership_mode": "faixa"
}'::jsonb
where program_key = 'veteranos_20k';

update development_programs
set criteria = '{
  "min_days": 91,
  "min_diamonds": 20001,
  "max_diamonds": 40000,
  "diamonds_period": "mes_anterior_prioritario",
  "membership_mode": "faixa"
}'::jsonb
where program_key = 'veteranos_40k';

update development_programs
set criteria = '{
  "min_diamonds": 80000,
  "max_diamonds": 149999,
  "diamonds_period": "mes_atual_ou_anterior",
  "membership_mode": "faixa"
}'::jsonb
where program_key = 'top_ducker_80k';

update development_programs
set criteria = '{
  "min_diamonds": 150000,
  "max_diamonds": 249999,
  "diamonds_period": "mes_atual_ou_anterior",
  "membership_mode": "faixa"
}'::jsonb
where program_key = 'programa_150k';

update development_programs
set criteria = '{
  "min_diamonds": 250000,
  "max_diamonds": 499999,
  "diamonds_period": "mes_atual_ou_anterior",
  "membership_mode": "faixa"
}'::jsonb
where program_key = 'elite';

update development_programs
set criteria = '{
  "min_diamonds": 500000,
  "max_diamonds": 749999,
  "diamonds_period": "mes_atual_ou_anterior",
  "membership_mode": "faixa"
}'::jsonb
where program_key = 'placa_merito_500k';

update development_programs
set criteria = '{
  "min_diamonds": 750000,
  "max_diamonds": 999999,
  "diamonds_period": "mes_atual_ou_anterior",
  "membership_mode": "faixa"
}'::jsonb
where program_key = 'medalha_750k';

update development_programs
set criteria = '{
  "min_diamonds": 1000000,
  "diamonds_period": "mes_atual_ou_anterior",
  "membership_mode": "faixa"
}'::jsonb
where program_key = 'placa_merito_1m';
