-- ============================================================================
-- Material Acompanhamento: vincular um material a um card especifico do
-- Onboarding 0-15 Dias (alem do filtro geral por fase/nicho ja existente
-- na 0014). Quando definido, o card mostra uma etiqueta "Material" que
-- leva direto a este material, sem precisar abrir a lista geral. Rode
-- manualmente no SQL Editor do Supabase, depois da 0014. Aditivo/idempotente.
-- ============================================================================

alter table training_materials add column if not exists target_streamer_id uuid references profiles(id) on delete cascade;
alter table training_materials add column if not exists target_lead_id uuid references leads(id) on delete cascade;

create index if not exists idx_training_materials_target_streamer on training_materials(target_streamer_id) where target_streamer_id is not null;
create index if not exists idx_training_materials_target_lead on training_materials(target_lead_id) where target_lead_id is not null;
