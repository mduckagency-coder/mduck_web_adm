-- ============================================================================
-- Motor de classificacao automatica por faixa (Novatos/Veteranos/Top Ducker/
-- Elite/Placas de Merito) + tickets de sorteio automaticos. Rode manualmente
-- no SQL Editor do Supabase. Aditivo: nao apaga dados existentes; so
-- acrescenta colunas e mescla chaves especificas dentro do criteria jsonb
-- (o resto do que o gestor ja configurou continua intacto).
-- ============================================================================

-- Dedupe de ticket automatico por streamer/programa/mes ("2026-07").
alter table program_awards add column if not exists ticket_period_key text;

-- Correcao manual do gestor num programa "faixa" -- quando setado, o
-- sincronizador automatico (syncFaixaMembership) nunca mexe nesse card.
alter table streamer_phase_progress add column if not exists manual_override text check (manual_override in ('add', 'remove'));

-- Renomeia so se o nome ainda for o padrao antigo (preserva customizacao
-- ja feita manualmente).
update development_programs set name = 'Novatos 90 Dias', updated_at = now()
  where program_key = 'novatos' and name = 'Novatos (2o e 3o mes)';

update development_programs set name = 'Elite (250k+)', updated_at = now()
  where program_key = 'elite' and name = 'Elite';

-- Preenche os limiares descritos pelo gestor nos 4 programas que ja
-- existiam antes desta rodada (so mexe nas chaves citadas abaixo -- min_hours,
-- categorias, batalhas etc. que ja estavam configurados continuam do jeito
-- que estavam).
update development_programs
  set criteria = coalesce(criteria, '{}'::jsonb) || jsonb_build_object(
    'max_days_in_agency', 90,
    'max_diamonds', 40000,
    'diamonds_period', 'mes_atual_ou_anterior',
    'membership_mode', 'faixa'
  ),
  updated_at = now()
  where program_key = 'novatos';

update development_programs
  set criteria = coalesce(criteria, '{}'::jsonb) || jsonb_build_object(
    'min_diamonds', 80000,
    'diamonds_period', 'mes_atual_ou_anterior',
    'membership_mode', 'faixa'
  ),
  updated_at = now()
  where program_key = 'top_ducker_80k';

update development_programs
  set criteria = coalesce(criteria, '{}'::jsonb) || jsonb_build_object(
    'min_diamonds', 150000,
    'diamonds_period', 'mes_atual_ou_anterior',
    'membership_mode', 'faixa'
  ),
  updated_at = now()
  where program_key = 'programa_150k';

update development_programs
  set criteria = coalesce(criteria, '{}'::jsonb) || jsonb_build_object(
    'min_diamonds', 250000,
    'diamonds_period', 'mes_atual_ou_anterior',
    'membership_mode', 'faixa'
  ),
  updated_at = now()
  where program_key = 'elite';

-- Onboarding: so preenche a folga de dias se o gestor ainda nao tiver
-- configurado nada (nao sobrescreve customizacao existente).
update development_programs
  set criteria = coalesce(criteria, '{}'::jsonb) || jsonb_build_object('max_days_in_agency', 20), updated_at = now()
  where program_key = 'onboarding_0_15' and (criteria -> 'max_days_in_agency') is null;

update development_programs
  set criteria = coalesce(criteria, '{}'::jsonb) || jsonb_build_object('max_days_in_agency', 40), updated_at = now()
  where program_key = 'onboarding_30' and (criteria -> 'max_days_in_agency') is null;
