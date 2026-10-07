-- ============================================================================
-- Desafio (Operacoes APP > Desafio): microinteracao da Home do app. O
-- streamer toca no dado, joga um jogo rapido e, no fim (ganhando, perdendo
-- ou empatando), recebe uma "Dica do Max" sobre live/streaming.
--
-- Estrutura generica pra crescer com outros jogos no futuro:
--   challenge_games  catalogo de jogos (game_key identifica o componente do
--                    app; o primeiro e 'tic_tac_toe' = Jogo da Velha)
--   challenge_tips   banco de dicas (texto, categoria opcional, ativa/inativa)
--   challenge_plays  registro de cada partida (so pra Visao geral do painel;
--                    nao existe ranking, pontuacao nem recompensa)
--
-- Sem jogo ativo: o app esconde o dado. Sem dica ativa: o jogo termina
-- normalmente, so sem a dica.
--
-- Aditivo/idempotente, rode manualmente no SQL Editor do Supabase. Ja
-- cadastra o Jogo da Velha e as 30 dicas iniciais pra cada agencia (so se a
-- agencia ainda nao tiver nenhuma).
-- ============================================================================

create table if not exists challenge_games (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  game_key text not null,
  name text not null,
  description text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (agency_id, game_key)
);

comment on table challenge_games is 'Jogos do Desafio (dado da Home). game_key liga ao componente do app (tic_tac_toe = Jogo da Velha). settings guarda opcoes futuras por jogo.';

create table if not exists challenge_tips (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  text text not null,
  category text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_challenge_tips_agency on challenge_tips(agency_id, is_active);

comment on table challenge_tips is 'Dicas do Max mostradas ao fim de cada partida do Desafio. category e opcional (Interacao, Inicio de live, Retencao, Conteudo, Chat, Presentes, Comunidade, Engajamento, Estrategia).';

create table if not exists challenge_plays (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  streamer_id uuid not null references profiles(id) on delete cascade,
  game_key text not null,
  result text not null check (result in ('win', 'loss', 'draw')),
  tip_id uuid references challenge_tips(id) on delete set null,
  played_at timestamptz not null default now()
);
create index if not exists idx_challenge_plays_agency on challenge_plays(agency_id, played_at desc);
create index if not exists idx_challenge_plays_streamer on challenge_plays(streamer_id, played_at desc);

-- ============================================================================
-- RLS
-- ============================================================================
alter table challenge_games enable row level security;
alter table challenge_tips enable row level security;
alter table challenge_plays enable row level security;

drop policy if exists "challenge_games_agency" on challenge_games;
create policy "challenge_games_agency" on challenge_games
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "challenge_games_streamer_select" on challenge_games;
create policy "challenge_games_streamer_select" on challenge_games
  for select using (
    is_active and agency_id = (select agency_id from profiles where auth_user_id = auth.uid())
  );

drop policy if exists "challenge_tips_agency" on challenge_tips;
create policy "challenge_tips_agency" on challenge_tips
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "challenge_plays_agency_select" on challenge_plays;
create policy "challenge_plays_agency_select" on challenge_plays
  for select using (agency_id = (select agency_id from managers where id = auth.uid()));

-- ============================================================================
-- Funcao usada pelo app ao terminar a partida: registra o resultado e sorteia
-- uma dica ativa, evitando repetir a ultima que o streamer recebeu
-- (p_last_tip_id) quando houver outra opcao. Devolve null se nao houver dica.
-- ============================================================================
create or replace function app_challenge_finish(p_game_key text, p_result text, p_last_tip_id uuid default null)
returns table (tip_id uuid, tip_text text)
language plpgsql volatile security definer
set search_path = public
as $$
declare
  v_me record;
  v_tip record;
begin
  select id, agency_id into v_me from profiles where auth_user_id = auth.uid() limit 1;
  if v_me.id is null then
    return;
  end if;

  select t.id, t.text into v_tip
  from challenge_tips t
  where t.agency_id = v_me.agency_id and t.is_active
  order by (t.id = p_last_tip_id), random()
  limit 1;

  insert into challenge_plays (agency_id, streamer_id, game_key, result, tip_id)
  values (
    v_me.agency_id,
    v_me.id,
    p_game_key,
    case when p_result in ('win', 'loss', 'draw') then p_result else 'draw' end,
    v_tip.id
  );

  if v_tip.id is not null then
    tip_id := v_tip.id;
    tip_text := v_tip.text;
    return next;
  end if;
end;
$$;

grant execute on function app_challenge_finish(text, text, uuid) to authenticated;

-- ============================================================================
-- Conteudo inicial (so pra agencias que ainda nao tem nada)
-- ============================================================================
insert into challenge_games (agency_id, game_key, name, description, sort_order)
select distinct m.agency_id, 'tic_tac_toe', 'Jogo da Velha', 'O streamer joga contra o sistema; no fim recebe uma Dica do Max.', 0
from managers m
where m.agency_id is not null
on conflict (agency_id, game_key) do nothing;

insert into challenge_tips (agency_id, text, category)
select a.agency_id, t.text, t.category
from (select distinct agency_id from managers where agency_id is not null) a
cross join (values
  ('Quando começar sua live, deixe claro o que vai acontecer. Isso cria expectativa em quem acabou de chegar.', 'Início de live'),
  ('Quando alguém novo entrar na sua live, tente cumprimentar pelo nome. Pequenos detalhes fazem a pessoa se sentir parte da live.', 'Interação'),
  ('Crie um objetivo para cada live. Ter algo para buscar deixa a transmissão mais interessante.', 'Estratégia'),
  ('Faça perguntas para quem está assistindo. Uma conversa é mais fácil de manter quando você também abre espaço para a audiência participar.', 'Interação'),
  ('Evite ficar muito tempo sem falar. Mesmo quando o chat estiver mais quieto, continue conduzindo a live.', 'Chat'),
  ('Conte para a audiência o que você está fazendo e por quê. Isso ajuda quem acabou de chegar a entender o contexto.', 'Conteúdo'),
  ('Quando acontecer algo inesperado na live, aproveite o momento. Situações espontâneas podem virar os melhores momentos da transmissão.', 'Conteúdo'),
  ('Crie pequenas metas durante a live. Elas ajudam a manter você e sua audiência envolvidos.', 'Engajamento'),
  ('Reconheça quem está presente. Um simples ‘obrigado por estar aqui’ pode fazer diferença.', 'Comunidade'),
  ('Se o chat estiver movimentado, aproveite os assuntos que estão gerando mais conversa.', 'Chat'),
  ('Comece a live com energia. Os primeiros minutos ajudam a definir o ritmo da transmissão.', 'Início de live'),
  ('Tenha sempre um assunto ou atividade para puxar quando o chat ficar mais quieto.', 'Chat'),
  ('Não espere apenas perguntas. Conte histórias, faça comentários e crie assuntos por conta própria.', 'Conteúdo'),
  ('Quando uma pessoa voltar para sua live, reconheça isso. Mostrar que você lembra dela ajuda a criar conexão.', 'Comunidade'),
  ('Experimente diferentes horários e observe em quais momentos sua audiência participa mais.', 'Estratégia'),
  ('Uma live não precisa ser perfeita. O mais importante é criar momentos reais com quem está assistindo.', 'Conteúdo'),
  ('Se algo deu errado durante a live, não tenha medo de transformar isso em parte da diversão.', 'Conteúdo'),
  ('Crie momentos que façam a audiência querer voltar para a próxima live.', 'Retenção'),
  ('Quando perceber que um assunto está funcionando bem, explore um pouco mais antes de mudar de tema.', 'Retenção'),
  ('Termine a live deixando uma expectativa para a próxima. Dê um motivo para sua audiência voltar.', 'Retenção'),
  ('Se alguém estiver participando bastante do chat, envolva essa pessoa na conversa.', 'Interação'),
  ('Use o nome das pessoas naturalmente durante a conversa. Isso torna a interação mais pessoal.', 'Interação'),
  ('Quando receber um presente, agradeça de forma verdadeira e específica, em vez de apenas repetir um agradecimento automático.', 'Presentes'),
  ('Observe quais momentos da sua live geram mais interação. Eles podem ajudar você a entender o que sua audiência gosta.', 'Estratégia'),
  ('Não tenha medo de testar formatos diferentes. Uma pequena mudança pode revelar uma nova forma de prender a atenção.', 'Estratégia'),
  ('Se a audiência estiver quieta, não interprete isso automaticamente como algo ruim. Continue conduzindo a live e dê tempo para a conversa acontecer.', 'Chat'),
  ('Crie uma rotina de começo de live que sua audiência reconheça. Pequenos rituais ajudam a criar identidade.', 'Comunidade'),
  ('Se você estiver fazendo uma atividade, explique o que está acontecendo para quem acabou de entrar.', 'Retenção'),
  ('Uma boa interação nem sempre precisa ser longa. Às vezes, alguns segundos de atenção genuína já fazem diferença.', 'Interação'),
  ('Pense na sua live como uma história. O que você quer que aconteça antes de terminar?', 'Estratégia')
) as t(text, category)
where not exists (select 1 from challenge_tips ct where ct.agency_id = a.agency_id);
