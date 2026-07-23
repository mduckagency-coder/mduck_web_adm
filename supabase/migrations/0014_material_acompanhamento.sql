-- ============================================================================
-- Material Acompanhamento (area do Gestor): reaproveita a tabela
-- training_materials ja usada pelos Materiais do Recrutador, com um escopo
-- novo para nao misturar os dois quadros (o do recrutador usa colunas
-- livres via material_categories; este usa fases fixas do acompanhamento
-- do streamer + nicho opcional). Rode manualmente no SQL Editor do
-- Supabase, depois da 0013. Aditivo/idempotente.
-- ============================================================================

-- 1) Escopo: distingue material do quadro do Recrutador ("recrutamento",
-- default -- preserva todo material ja cadastrado) do quadro novo do
-- Gestor ("acompanhamento").
alter table training_materials add column if not exists scope text not null default 'recrutamento';
alter table training_materials drop constraint if exists chk_training_materials_scope;
alter table training_materials add constraint chk_training_materials_scope check (scope in ('recrutamento', 'acompanhamento'));

-- 2) Fase do acompanhamento (aba no Material Acompanhamento). So usado
-- quando scope = 'acompanhamento'; nulo para material de recrutamento.
alter table training_materials add column if not exists stage text;

-- 3) Nicho do streamer (filtro opcional dentro de cada aba). Nulo =
-- aparece para todos os nichos.
alter table training_materials add column if not exists niche text;
alter table training_materials drop constraint if exists chk_training_materials_niche;
alter table training_materials add constraint chk_training_materials_niche check (niche is null or niche in ('gamer', 'batalha', 'musico'));

create index if not exists idx_training_materials_scope_stage
  on training_materials(agency_id, scope, stage) where is_archived = false;
