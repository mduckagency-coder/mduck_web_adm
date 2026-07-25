-- ============================================================================
-- Onboarding 0-15 Dias: o gestor pode marcar um card como "streamer em
-- potencial" (candidato que se destaca) direto no dialog de Editar card.
-- Quando marcado, o board mostra uma estrela ao lado do icone de categoria
-- na foto pequena do card. Guardado no proprio card (streamer_phase_progress),
-- nao no cadastro do streamer/lead, porque e uma avaliacao do acompanhamento
-- desta fase, nao um dado permanente do streamer.
-- ============================================================================
alter table streamer_phase_progress add column if not exists is_potential boolean not null default false;
