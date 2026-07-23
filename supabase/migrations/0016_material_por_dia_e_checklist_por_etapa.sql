-- ============================================================================
-- Onboarding 0-15 Dias: material 100% automatico por etapa (sem vinculo
-- manual a um card especifico) + checklist proprio por etapa. Rode
-- manualmente no SQL Editor do Supabase, depois da 0015. Aditivo/destrutivo
-- controlado: substitui os itens de checklist genericos (identicos em
-- todas as etapas) por um conjunto proprio de cada dia -- ver comentario
-- na secao 3.
-- ============================================================================

-- 1) Remove o vinculo manual material -> card especifico (0015): o gestor
-- nao deve mais escolher "para qual streamer" um material vale. A partir
-- de agora o material e automatico por dia da etapa (onboarding_stage_key)
-- + nicho opcional, igual ja funciona para as demais fases.
alter table training_materials drop column if exists target_streamer_id;
alter table training_materials drop column if exists target_lead_id;

-- 2) Dia da etapa (dia_1..dia_15) para material com scope='acompanhamento'
-- e stage='onboarding_15' -- e o que faz o material aparecer sozinho
-- quando o streamer estiver naquele dia, sem nenhuma vinculacao manual.
alter table training_materials add column if not exists onboarding_stage_key text;
create index if not exists idx_training_materials_onboarding_stage
  on training_materials(agency_id, stage, onboarding_stage_key) where is_archived = false;

-- ============================================================================
-- 3) Checklist proprio por etapa (streamer_phase_checklist_items).
-- Ate aqui todas as etapas (dia_1..dia_15) usavam o mesmo conjunto de 8
-- itens genericos (seed da migration 0007). Substitui por um conjunto
-- proprio de cada dia, para toda agencia ja existente. Historico de
-- checklist ja marcado (streamer_phase_checklist_progress) nao e apagado
-- -- fica orfao dos itens antigos removidos, sem efeito pratico (a tela so
-- le os itens ativos da etapa).
-- ============================================================================
delete from streamer_phase_checklist_items
where phase_key = 'onboarding_0_15' and stage_key in (
  'dia_1','dia_2','dia_3','dia_4','dia_5','dia_6','dia_7',
  'dia_8','dia_9','dia_10','dia_11','dia_12','dia_13','dia_14','dia_15'
);

do $$
declare
  ag record;
  stage_items text[][] := array[
    -- stage_key, item_key, label, order_index (como texto, convertido abaixo)
    array['dia_1', 'entrou_grupo', 'Entrou no grupo', '1'],
    array['dia_1', 'recebeu_boas_vindas', 'Recebeu boas-vindas', '2'],
    array['dia_1', 'confirmou_recebimento', 'Confirmou recebimento', '3'],

    array['dia_2', 'material_enviado', 'Material enviado', '1'],
    array['dia_2', 'confirmou_recebimento', 'Confirmou recebimento', '2'],

    array['dia_3', 'configurou_tiktok', 'Configurou TikTok', '1'],
    array['dia_3', 'configurou_obs', 'Configurou OBS', '2'],

    array['dia_4', 'realizou_primeira_live', 'Realizou a primeira live', '1'],
    array['dia_4', 'feedback_registrado', 'Feedback da live registrado', '2'],

    array['dia_5', 'acompanhamento_realizado', 'Acompanhamento realizado', '1'],
    array['dia_5', 'duvidas_registradas', 'Duvidas registradas', '2'],

    array['dia_6', 'duvidas_esclarecidas', 'Duvidas esclarecidas', '1'],
    array['dia_6', 'feedback_registrado', 'Feedback registrado', '2'],

    array['dia_7', 'resumo_semana_enviado', 'Resumo da semana enviado', '1'],
    array['dia_7', 'metas_proxima_semana', 'Metas da proxima semana definidas', '2'],

    array['dia_8', 'engajamento_verificado', 'Engajamento verificado', '1'],
    array['dia_8', 'dicas_conteudo_enviadas', 'Dicas de conteudo enviadas', '2'],

    array['dia_9', 'acompanhamento_realizado', 'Acompanhamento realizado', '1'],
    array['dia_9', 'feedback_registrado', 'Feedback registrado', '2'],

    array['dia_10', 'pontos_melhoria_identificados', 'Pontos de melhoria identificados', '1'],
    array['dia_10', 'correcoes_orientadas', 'Correcoes orientadas', '2'],

    array['dia_11', 'plano_desenvolvimento_definido', 'Plano de desenvolvimento definido', '1'],
    array['dia_11', 'acompanhamento_realizado', 'Acompanhamento realizado', '2'],

    array['dia_12', 'evolucao_verificada', 'Evolucao verificada', '1'],
    array['dia_12', 'feedback_registrado', 'Feedback registrado', '2'],

    array['dia_13', 'preparacao_avaliacao', 'Preparacao para avaliacao final', '1'],
    array['dia_13', 'duvidas_finais_esclarecidas', 'Duvidas finais esclarecidas', '2'],

    array['dia_14', 'pre_avaliacao_realizada', 'Pre-avaliacao realizada', '1'],
    array['dia_14', 'pontos_atencao_registrados', 'Pontos de atencao registrados', '2'],

    array['dia_15', 'avaliacao_final_preparada', 'Avaliacao final preparada', '1'],
    array['dia_15', 'resumo_onboarding_enviado', 'Resumo do onboarding enviado', '2']
  ];
  i int;
begin
  for ag in select distinct agency_id from managers where agency_id is not null loop
    for i in 1 .. array_length(stage_items, 1) loop
      insert into streamer_phase_checklist_items (agency_id, phase_key, stage_key, item_key, label, order_index)
      values (ag.agency_id, 'onboarding_0_15', stage_items[i][1], stage_items[i][2], stage_items[i][3], stage_items[i][4]::int)
      on conflict (agency_id, phase_key, stage_key, item_key) do update set label = excluded.label, order_index = excluded.order_index;
    end loop;
  end loop;
end $$;
