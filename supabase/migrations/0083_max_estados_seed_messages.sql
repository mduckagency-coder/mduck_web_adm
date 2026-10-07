-- ============================================================================
-- Max - Mensagens iniciais dos estados (Home > 🦆 Max > Entrada)
-- Semeia as frases fornecidas pelo administrador para cada agencia existente.
-- Retorno / Inicio do mes / Meio do mes / Final do mes ficam vinculadas ao
-- estado "regular" (estado padrao), distinguidas pelo campo "category".
-- Rode manualmente no SQL Editor do Supabase. Idempotente (nao duplica se
-- rodar mais de uma vez).
-- ============================================================================

insert into max_state_messages (agency_id, state_key, category, message)
select m.agency_id, v.state_key, v.category, v.message
from (select distinct agency_id from managers) m
cross join (values
  ('regular', 'geral', 'Fala, Ducker.'),
  ('regular', 'geral', 'Bora ver como tá seu ritmo?'),
  ('regular', 'geral', 'Mais um dia por aqui.'),
  ('regular', 'geral', 'Como tá o ritmo hoje?'),

  ('constante', 'geral', 'Tá mantendo o ritmo, Ducker.'),
  ('constante', 'geral', 'Essa sequência tá bonita.'),
  ('constante', 'geral', 'Tá firme nas lives, hein?'),
  ('constante', 'geral', 'Gostei dessa constância.'),
  ('constante', 'geral', 'Tá fazendo acontecer.'),

  ('regular', 'retorno', 'Boa, você voltou.'),
  ('regular', 'retorno', 'Olha quem apareceu.'),
  ('regular', 'retorno', 'De volta ao ritmo?'),
  ('regular', 'retorno', 'Bora retomar?'),

  ('inativo', 'geral', 'Você deu uma sumida.'),
  ('inativo', 'geral', 'Faz uns dias, hein?'),
  ('inativo', 'geral', 'Tá tudo bem por aí?'),
  ('inativo', 'geral', 'Eu tava esperando você voltar.'),

  ('caveira', 'geral', 'Olha o que aconteceu comigo esperando você.'),
  ('caveira', 'geral', 'Ducker... você sumiu mesmo.'),
  ('caveira', 'geral', 'Eu já tava virando decoração.'),
  ('caveira', 'geral', 'Até que enfim você apareceu.'),

  ('regular', 'inicio_mes', 'Mês novo. Bora começar bem.'),
  ('regular', 'inicio_mes', 'Novo mês, novo ritmo.'),
  ('regular', 'inicio_mes', 'Bora construir esse mês.'),

  ('regular', 'meio_mes', 'Metade do mês já foi. Como tá o ritmo?'),
  ('regular', 'meio_mes', 'Ainda tem muito mês pela frente.'),
  ('regular', 'meio_mes', 'Tá mantendo a pegada?'),

  ('regular', 'final_mes', 'Reta final, Ducker.'),
  ('regular', 'final_mes', 'Últimos dias. Bora fechar bem.'),
  ('regular', 'final_mes', 'O mês tá acabando. Como tá o ritmo?'),
  ('regular', 'final_mes', 'Tá chegando a hora de fechar o mês.')
) as v(state_key, category, message)
where not exists (
  select 1 from max_state_messages x
  where x.agency_id = m.agency_id
    and x.state_key = v.state_key
    and x.category = v.category
    and x.message = v.message
);
