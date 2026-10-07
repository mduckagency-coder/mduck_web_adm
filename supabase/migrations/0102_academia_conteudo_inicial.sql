-- ============================================================================
-- ACADEMIA MDUCK: conteudo inicial + aulas do antigo MAX Aulas
--
-- * academy_seed(agencia, dados) cria categorias, series e aulas que AINDA
--   NAO existem (pelo slug). Nunca sobrescreve o que a equipe ja editou.
-- * Conteudo inicial foi escrito com apoio de IA: entra PUBLICADO porem
--   BLOQUEADO e com info_status 'revisar'. Os streamers veem a estrutura da
--   Academia (com cadeado e "Solicitar acesso"); a equipe revisa no painel e
--   libera aula por aula.
-- * Aulas do MAX Aulas viram aulas da categoria "Conteudo exclusivo MDuck",
--   ja disponiveis (como estavam no app).
-- Rode depois da 0101. Idempotente.
-- ============================================================================

create or replace function academy_seed(p_agency uuid, p_data jsonb)
returns int
language plpgsql volatile security definer
set search_path = public
as $$
declare
  c jsonb;
  s jsonb;
  l jsonb;
  v_count int := 0;
begin
  for c in select * from jsonb_array_elements(p_data->'categories') loop
    insert into academy_categories (agency_id, slug, title, subtitle, emoji, theme, audience, sort_order)
    values (p_agency, c->>'slug', c->>'title', c->>'subtitle', c->>'emoji', c->>'theme', c->>'audience', (c->>'order')::int)
    on conflict (agency_id, slug) do nothing;
  end loop;

  for s in select * from jsonb_array_elements(p_data->'series') loop
    insert into academy_series (agency_id, slug, title, subtitle, emoji, category_id, sort_order)
    values (p_agency, s->>'slug', s->>'title', s->>'subtitle', s->>'emoji',
            (select id from academy_categories where agency_id = p_agency and slug = s->>'cat'), (s->>'order')::int)
    on conflict (agency_id, slug) do nothing;
  end loop;

  for l in select * from jsonb_array_elements(p_data->'lessons') loop
    if not exists (select 1 from academy_lessons where agency_id = p_agency and slug = l->>'slug') then
      insert into academy_lessons (agency_id, slug, category_id, subcategory, title, subtitle, summary, audience, level,
        blocks, availability, status, featured, recommended, start_here, series_id, series_order, sort_order,
        duration_min, tags, sources, reviewed_at, info_status)
      values (p_agency, l->>'slug',
        (select id from academy_categories where agency_id = p_agency and slug = l->>'cat'),
        l->>'sub', l->>'title', l->>'subtitle', l->>'summary',
        coalesce((select array_agg(x) from jsonb_array_elements_text(l->'audience') x), array['todos']),
        coalesce(l->>'level', 'iniciante'),
        coalesce(l->'blocks', '[]'::jsonb),
        'bloqueado', 'publicado',
        coalesce((l->>'featured')::boolean, false), coalesce((l->>'recommended')::boolean, false),
        coalesce((l->>'start_here')::boolean, false),
        (select id from academy_series where agency_id = p_agency and slug = l->>'series'),
        (l->>'series_order')::int, coalesce((l->>'order')::int, 0), (l->>'dur')::int,
        coalesce((select array_agg(x) from jsonb_array_elements_text(l->'tags') x), '{}'),
        coalesce(l->'sources', '[]'::jsonb), null, 'revisar');
      v_count := v_count + 1;
    end if;
  end loop;
  return v_count;
end;
$$;

-- ----------------------------------------------------------------------------
-- Conteudo
-- ----------------------------------------------------------------------------
select academy_seed(a.agency_id, $json$
{
"categories": [
  {"slug":"fundamentos","title":"Fundamentos do LIVE","subtitle":"O essencial que todo streamer precisa conhecer.","emoji":"🦆","theme":"fundamentos","audience":null,"order":10},
  {"slug":"batalhas","title":"Batalhas","subtitle":"Aprenda a aproveitar melhor batalhas, interação, ritmo e estratégia.","emoji":"⚔️","theme":"batalhas","audience":"batalhas","order":20},
  {"slug":"games","title":"Games","subtitle":"Transforme gameplay numa LIVE mais interessante, interativa e envolvente.","emoji":"🎮","theme":"games","audience":"games","order":30},
  {"slug":"musica","title":"Música","subtitle":"Estruture sua LIVE musical, crie conexão e transforme espectadores em comunidade.","emoji":"🎤","theme":"musica","audience":"musica","order":40},
  {"slug":"engajamento","title":"Engajamento e evolução","subtitle":"Frequência, interação, comunidade e qualidade da LIVE.","emoji":"🚀","theme":"engajamento","audience":"conversa","order":50},
  {"slug":"todo_streamer","title":"Para todo streamer","subtitle":"Conteúdos que valem para qualquer nicho.","emoji":"⭐","theme":"todos","audience":null,"order":60},
  {"slug":"recursos","title":"Recursos do LIVE","subtitle":"Presentes, metas, convidados, moderação e mais.","emoji":"🧰","theme":"recursos","audience":null,"order":70},
  {"slug":"seguranca","title":"Segurança e diretrizes","subtitle":"Boas práticas para uma LIVE segura e tranquila.","emoji":"🛡️","theme":"seguranca","audience":null,"order":80},
  {"slug":"exclusivo","title":"Conteúdo exclusivo MDuck","subtitle":"Treinamentos, entrevistas e análises da equipe MDuck.","emoji":"💜","theme":"exclusivo","audience":null,"order":90}
],
"series": [
  {"slug":"comece_aqui","title":"Comece por aqui","subtitle":"Os primeiros passos na sua LIVE.","emoji":"👋","cat":"fundamentos","order":10},
  {"slug":"serie_games","title":"Série Games","subtitle":"Do começo à comunidade gamer.","emoji":"🎮","cat":"games","order":20},
  {"slug":"serie_batalhas","title":"Série Batalhas","subtitle":"Da primeira batalha à rotina de batalhas.","emoji":"⚔️","cat":"batalhas","order":30},
  {"slug":"serie_musica","title":"Série Música","subtitle":"Da preparação à comunidade de fãs.","emoji":"🎤","cat":"musica","order":40}
],
"lessons": [

{"slug":"f_o_que_e_live","cat":"fundamentos","sub":"Primeiros passos","title":"O que é uma LIVE","subtitle":"Entenda o que torna a LIVE diferente de um vídeo.","summary":"A LIVE é conversa em tempo real: quem assiste participa, comenta e ajuda a construir o momento.","audience":["todos"],"level":"iniciante","dur":4,"start_here":true,"featured":true,"series":"comece_aqui","series_order":1,"order":1,"tags":["live","começo","fundamentos"],
"sources":[{"title":"TikTok — LIVE Safety Guide","url":"https://www.tiktok.com/safety/en/tools-and-guides/live-safety-guide","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"text","label":"O que é?","body":"Uma LIVE é uma transmissão ao vivo: você e a sua audiência estão no mesmo momento. Diferente de um vídeo gravado, o que acontece na LIVE é construído junto com quem está assistindo — pelos comentários, pelas reações e pela participação."},
{"type":"platform","title":"Como o TikTok funciona","body":"Para fazer LIVE no TikTok é preciso ter pelo menos 18 anos e cumprir um número mínimo de seguidores, que pode variar conforme o país. A conta também precisa seguir as Diretrizes da Comunidade.","varies":true},
{"type":"discover","title":"Toque para descobrir: o que existe numa LIVE","items":[
 {"emoji":"🎥","title":"Você","body":"Seu rosto, sua voz e sua energia são o centro da LIVE."},
 {"emoji":"💬","title":"Comentários","body":"É por aqui que a audiência conversa com você em tempo real."},
 {"emoji":"❤️","title":"Curtidas","body":"Toques na tela mostram que as pessoas estão gostando."},
 {"emoji":"🎁","title":"Presentes","body":"Forma de apoio da audiência, quando o recurso está disponível para você."}]},
{"type":"tip","body":"Não pense apenas em quem está entrando na sua LIVE. Pense em quem pode voltar amanhã."},
{"type":"quiz","question":"Qual é a maior diferença entre uma LIVE e um vídeo gravado?","options":["A LIVE tem filtros melhores","Na LIVE a audiência participa em tempo real","A LIVE sempre dura mais"],"correct":1,"explanation":"Na LIVE, a conversa acontece agora. A participação de quem assiste faz parte do conteúdo."},
{"type":"challenge","body":"Na sua próxima LIVE, cumprimente pelo nome as três primeiras pessoas que comentarem."}]},

{"slug":"f_preparar_live","cat":"fundamentos","sub":"Primeiros passos","title":"Como preparar sua LIVE","subtitle":"Os 10 minutos antes de entrar ao vivo fazem diferença.","summary":"Um checklist rápido de ambiente, assunto e energia antes de começar.","audience":["todos"],"level":"iniciante","dur":5,"start_here":true,"series":"comece_aqui","series_order":2,"order":2,"tags":["preparação","rotina","checklist"],
"blocks":[
{"type":"text","label":"Por que preparar?","body":"Quem entra na sua LIVE decide em poucos segundos se fica. Uma LIVE preparada começa com energia, imagem clara e um assunto definido — e isso segura mais gente."},
{"type":"steps","title":"Como fazer","items":["Defina o objetivo da LIVE de hoje (ex.: bater um papo, jogar, cantar, fazer batalhas).","Confira internet, bateria e espaço no celular.","Arrume luz de frente para o rosto e um fundo organizado.","Teste o áudio: fale normalmente e veja se está claro.","Separe 2 ou 3 assuntos ou perguntas para puxar conversa.","Avise seus seguidores (vídeo curto ou story) antes de começar."]},
{"type":"checklist","title":"Checklist antes de entrar","items":["Internet estável","Bateria carregada ou carregador por perto","Luz de frente","Áudio testado","Objetivo da LIVE definido","2 ou 3 assuntos separados","Água por perto"]},
{"type":"tip","body":"Comece a LIVE já falando, como se a conversa estivesse acontecendo. O silêncio dos primeiros segundos afasta quem acabou de chegar."},
{"type":"challenge","body":"Use o checklist completo antes das suas próximas 3 LIVEs."}]},

{"slug":"f_escolher_formato","cat":"fundamentos","sub":"Primeiros passos","title":"Como escolher um formato","subtitle":"Conversa, games, música, batalhas: qual combina com você?","summary":"Um formato claro ajuda a audiência a saber o que esperar — e a voltar.","audience":["todos"],"level":"iniciante","dur":5,"series":"comece_aqui","series_order":3,"order":3,"tags":["formato","identidade","nicho"],
"blocks":[
{"type":"text","label":"O que é um formato?","body":"Formato é o jeito que sua LIVE costuma acontecer: o que você faz, em que ordem e com qual clima. Ele pode ser conversa, gameplay, música, batalhas ou uma mistura — o importante é a audiência reconhecer."},
{"type":"discover","title":"Toque para conhecer os formatos","items":[
 {"emoji":"💬","title":"Conversa / variedades","body":"Bate-papo, perguntas, histórias, reações. A conexão é o produto principal."},
 {"emoji":"🎮","title":"Games","body":"Você joga e a audiência acompanha, comenta e participa das decisões."},
 {"emoji":"🎤","title":"Música","body":"Repertório, pedidos e conversa entre as músicas."},
 {"emoji":"⚔️","title":"Batalhas","body":"Competições com outros criadores, com energia e participação do público."}]},
{"type":"steps","title":"Como escolher","items":["Liste o que você gosta de fazer por horas sem cansar.","Veja o que sua audiência mais comenta e pede.","Teste um formato por pelo menos 2 semanas antes de trocar.","Anote o que funcionou em cada LIVE."]},
{"type":"tip","body":"Formato não é prisão. Você pode ter um formato principal e momentos especiais — desde que a audiência saiba o que esperar."},
{"type":"quiz","question":"Qual é o melhor jeito de descobrir seu formato?","options":["Trocar de formato a cada LIVE","Testar por algumas semanas e observar a audiência","Copiar exatamente outro criador"],"correct":1,"explanation":"Testar com consistência e observar a reação da audiência mostra o que realmente funciona para você."}]},

{"slug":"f_rotina","cat":"fundamentos","sub":"Rotina","title":"Como criar uma rotina de LIVE","subtitle":"Horário e frequência transformam LIVE em hábito — seu e da audiência.","summary":"Uma rotina previsível ajuda as pessoas a saberem quando te encontrar.","audience":["todos"],"level":"iniciante","dur":5,"series":"comece_aqui","series_order":4,"order":4,"recommended":true,"tags":["rotina","frequência","horário","hábito"],
"blocks":[
{"type":"text","label":"Por que rotina?","body":"Quando você faz LIVE em dias e horários parecidos, sua audiência aprende quando te encontrar. A rotina também facilita para você: menos decisão, mais constância."},
{"type":"steps","title":"Como montar a sua","items":["Escolha os dias da semana que você consegue manter.","Defina um horário principal (e tente repetir).","Comece com uma duração possível — é melhor manter do que exagerar e parar.","Avise a agenda no seu perfil ou em vídeos.","Revise a rotina no fim do mês."]},
{"type":"example","title":"Exemplo","body":"Segunda a sexta às 20h, por 2 horas. Sábado uma LIVE especial com batalhas. Domingo descanso."},
{"type":"tip","body":"A MDuck usa como referência 22 dias e 100 horas no mês — mas evolua no seu ritmo. Constância vale mais que um dia gigante isolado."},
{"type":"challenge","body":"Escreva sua agenda da próxima semana (dias e horários) e cumpra pelo menos 80% dela."}]},

{"slug":"f_conversar","cat":"fundamentos","sub":"Audiência","title":"Como conversar com espectadores","subtitle":"Falar com a audiência, não para a audiência.","summary":"Nome, pergunta e resposta: o básico que faz a pessoa se sentir parte da LIVE.","audience":["todos"],"level":"iniciante","dur":5,"start_here":true,"series":"comece_aqui","series_order":5,"order":5,"recommended":true,"tags":["conexão","comentários","interação","audiência"],
"blocks":[
{"type":"text","label":"O que é?","body":"Conversar na LIVE é transformar comentários em diálogo. A pessoa comenta, você responde, ela se sente vista — e tende a ficar e voltar."},
{"type":"simulation","scene":"conversa","title":"Toque nos elementos da LIVE","intro":"Veja onde cada parte da conversa acontece."},
{"type":"steps","title":"Como fazer","items":["Leia o comentário em voz alta antes de responder.","Chame a pessoa pelo nome (ou @).","Responda e devolva com uma pergunta.","Dê boas-vindas a quem chega, sem interromper o assunto.","Lembre de quem volta: \"Fulano, você de novo! Que bom!\""]},
{"type":"tip","body":"Pergunta aberta puxa conversa (\"o que vocês fizeram hoje?\"). Pergunta de sim/não costuma morrer rápido."},
{"type":"quiz","question":"Alguém comenta \"oi\". O que gera mais conversa?","options":["Responder só \"oi\"","\"Oi, Ana! Tudo bem? De onde você está assistindo?\"","Ignorar e continuar"],"correct":1,"explanation":"Nome + pergunta aberta convidam a pessoa a continuar participando."},
{"type":"challenge","body":"Na sua próxima LIVE, faça uma pergunta para a audiência a cada 15 minutos."}]},

{"slug":"f_pouca_audiencia","cat":"fundamentos","sub":"Audiência","title":"Como lidar com pouca audiência","subtitle":"Dias vazios fazem parte — e podem ser bons treinos.","summary":"O que fazer quando a LIVE está parada, sem desanimar.","audience":["todos"],"level":"iniciante","dur":4,"order":6,"tags":["pouca audiência","silêncio","motivação"],
"blocks":[
{"type":"text","label":"Isso é normal","body":"Toda LIVE tem momentos com pouca gente. Quem está assistindo agora merece a mesma energia de uma LIVE cheia — e quem chegar depois encontra uma LIVE viva."},
{"type":"steps","title":"Como fazer","items":["Continue falando como se estivesse conversando com uma pessoa.","Comente o que está fazendo e por quê.","Faça perguntas mesmo sem resposta imediata.","Use o momento para testar algo novo (assunto, enquadramento, jogo, música).","Agradeça quem está ali pelo nome."]},
{"type":"tip","body":"LIVE com pouca gente é treino com plateia. Use para melhorar sua fala e seu ritmo."},
{"type":"checklist","title":"Quando a LIVE estiver parada","items":["Falei algo nos últimos 30 segundos?","Fiz uma pergunta recentemente?","Dei boas-vindas a quem chegou?","Mudei algo para renovar a energia?"]}]},

{"slug":"f_terminar_live","cat":"fundamentos","sub":"Rotina","title":"Como terminar uma LIVE","subtitle":"O final também é um convite para a próxima.","summary":"Feche com agradecimento, resumo e o horário da próxima LIVE.","audience":["todos"],"level":"iniciante","dur":3,"order":7,"tags":["encerramento","rotina"],
"blocks":[
{"type":"text","label":"Por que importa?","body":"O fim da LIVE é a última lembrança de quem assistiu. Um bom encerramento deixa a sensação de \"quero voltar\"."},
{"type":"steps","title":"Como fazer","items":["Avise uns minutos antes: \"daqui a pouco a gente encerra\".","Agradeça quem participou e apoiou.","Relembre um momento marcante da LIVE.","Diga quando será a próxima LIVE.","Encerre com energia, não no meio de uma frase."]},
{"type":"tip","body":"Sempre termine dizendo quando você volta. Quem sabe o próximo horário tem um motivo para voltar."},
{"type":"challenge","body":"Nas próximas 3 LIVEs, encerre anunciando dia e horário da próxima."}]},

{"slug":"f_pos_live","cat":"fundamentos","sub":"Rotina","title":"Como analisar a LIVE depois","subtitle":"5 minutos de pós-LIVE valem mais que muitas horas no escuro.","summary":"Anote o que funcionou e o que mudar na próxima.","audience":["todos"],"level":"intermediario","dur":5,"order":8,"tags":["análise","pós-live","evolução","métricas"],
"blocks":[
{"type":"text","label":"O que é?","body":"Analisar a LIVE é olhar para o que aconteceu e tirar uma lição prática. Não é se cobrar: é ajustar o próximo passo."},
{"type":"steps","title":"Como fazer","items":["Anote o horário em que mais gente estava assistindo.","Lembre o momento com mais comentários.","Lembre o momento em que a LIVE esvaziou.","Escolha UMA coisa para manter e UMA para mudar."]},
{"type":"platform","title":"Como o TikTok funciona","body":"O TikTok oferece dados sobre suas LIVEs (como espectadores e tempo assistido) nas ferramentas do criador. Os nomes e o local das métricas podem mudar com atualizações do app.","varies":true},
{"type":"tip","body":"Uma mudança por vez. Se você mudar tudo de uma vez, não descobre o que funcionou."},
{"type":"checklist","title":"Pós-LIVE","items":["Melhor momento da LIVE","Momento em que caiu","1 coisa para manter","1 coisa para mudar","Horário da próxima LIVE"]}]},

{"slug":"f_comunidade","cat":"fundamentos","sub":"Audiência","title":"Como construir comunidade","subtitle":"Espectadores assistem. Comunidade volta.","summary":"Rituais, nomes e momentos recorrentes transformam audiência em comunidade.","audience":["todos"],"level":"intermediario","dur":5,"order":9,"recommended":true,"tags":["comunidade","fãs","rituais","conexão"],
"blocks":[
{"type":"text","label":"O que é comunidade?","body":"Comunidade é quando as pessoas se reconhecem entre si, conhecem as \"piadas internas\" da LIVE e voltam porque se sentem parte de algo."},
{"type":"discover","title":"Toque para descobrir ideias","items":[
 {"emoji":"👋","title":"Ritual de abertura","body":"Um jeito fixo de começar a LIVE que todos reconhecem."},
 {"emoji":"🏷️","title":"Nome da comunidade","body":"Um apelido para quem acompanha você."},
 {"emoji":"⭐","title":"Reconhecimento","body":"Destaque quem está sempre presente."},
 {"emoji":"📅","title":"Momento fixo","body":"Ex.: toda sexta tem desafio, toda segunda tem pedidos."}]},
{"type":"tip","body":"Comunidade não nasce de um dia para o outro. Ela nasce da repetição: mesmo horário, mesmos rituais, você presente."},
{"type":"challenge","body":"Crie um ritual de abertura e repita em todas as LIVEs da próxima semana."}]},

{"slug":"b_o_que_e","cat":"batalhas","sub":"Entendendo a Batalha","title":"O que é uma Batalha","subtitle":"O LIVE Match explicado do jeito simples.","summary":"Dois (ou mais) criadores, um placar e cinco minutos de energia.","audience":["todos","batalhas"],"level":"iniciante","dur":5,"featured":true,"series":"serie_batalhas","series_order":1,"order":1,"tags":["batalha","match","placar","pk"],
"sources":[{"title":"LIVE Studio Help — Start a LIVE match to call on your supporters","url":"https://www.tiktok.com/live/studio/help/article/Monetize-your-creativity/Start-a-LIVE-match-to-call-on-your-supporters?lang=en","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"text","label":"O que é?","body":"A Batalha (no TikTok, o recurso se chama LIVE Match) é uma competição entre criadores que estão fazendo LIVE juntos. A audiência de cada lado apoia o seu criador e o placar mostra quem está na frente."},
{"type":"platform","title":"Como o TikTok funciona","body":"Segundo a central de ajuda do LIVE Studio: a partida começa quando você está fazendo co-host com outro criador e toca em \"Start match\"; quando o oponente aceita, ela começa e dura cinco minutos. Cada moeda (coin) dos presentes vale um ponto e cada curtida vale três pontos. Existem partidas em que só presentes específicos contam e partidas em equipe com até quatro criadores.","varies":true,"source_url":"https://www.tiktok.com/live/studio/help/article/Monetize-your-creativity/Start-a-LIVE-match-to-call-on-your-supporters?lang=en"},
{"type":"simulation","scene":"batalha","title":"Toque nos elementos da Batalha","intro":"Explore a tela de uma Batalha simulada."},
{"type":"tip","body":"Batalha não é só placar. É um momento de show: quem assiste quer energia, torcida e diversão — ganhando ou perdendo."},
{"type":"quiz","question":"Para iniciar uma Batalha, o que precisa acontecer primeiro?","options":["Estar em co-host com outro criador","Ter 1 milhão de seguidores","Encerrar a LIVE"],"correct":0,"explanation":"Pela ajuda oficial do LIVE Studio, a partida é iniciada durante um co-host com outro criador."}]},

{"slug":"b_como_iniciar","cat":"batalhas","sub":"Entendendo a Batalha","title":"Como puxar uma Batalha","subtitle":"Do convite ao início da partida.","summary":"Convide, combine e comece no momento certo.","audience":["todos","batalhas"],"level":"iniciante","dur":5,"series":"serie_batalhas","series_order":2,"order":2,"recommended":true,"tags":["batalha","convite","co-host","parceiros"],
"sources":[{"title":"LIVE Studio Help — Go LIVE with other creators","url":"https://www.tiktok.com/live/studio/help/article/Boost-viewer-engagement/Go-LIVE-with-other-creators?lang=en","consulted_at":"2026-10-03"},{"title":"LIVE Studio Help — Start a LIVE match","url":"https://www.tiktok.com/live/studio/help/article/Monetize-your-creativity/Start-a-LIVE-match-to-call-on-your-supporters?lang=en","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"platform","title":"Como o TikTok funciona","body":"O co-host permite convidar outros criadores para a sua LIVE em tela dividida (a ajuda do LIVE Studio fala em até três outros criadores). Em co-host, aparece a opção de iniciar a partida; ela começa quando o outro criador aceita.","varies":true},
{"type":"steps","title":"Como fazer","items":["Combine antes com o outro criador (horário e clima da batalha).","Avise sua audiência: \"daqui a 10 minutos tem batalha!\".","Entre em co-host com o criador.","Converse um pouco antes de começar — apresente o parceiro.","Inicie a partida quando a audiência estiver aquecida."]},
{"type":"simulation","scene":"batalha","title":"Explore a Batalha","intro":"Toque no placar, no tempo e nos presentes."},
{"type":"tip","body":"Não espere a Batalha começar para criar energia. Prepare sua audiência antes."},
{"type":"challenge","body":"Antes da sua próxima batalha, avise a audiência com pelo menos 10 minutos de antecedência."}]},

{"slug":"b_placar_pontos","cat":"batalhas","sub":"Entendendo a Batalha","title":"Como funcionam o placar e os pontos","subtitle":"Moedas, curtidas e presentes específicos.","summary":"Entenda o placar para orientar sua audiência sem confusão.","audience":["todos","batalhas"],"level":"iniciante","dur":4,"series":"serie_batalhas","series_order":3,"order":3,"tags":["placar","pontos","curtidas","presentes"],
"sources":[{"title":"LIVE Studio Help — Start a LIVE match","url":"https://www.tiktok.com/live/studio/help/article/Monetize-your-creativity/Start-a-LIVE-match-to-call-on-your-supporters?lang=en","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"platform","title":"Como o TikTok funciona","body":"Pela ajuda do LIVE Studio: cada moeda de presente vale um ponto e cada curtida vale três pontos. Em partidas de presente específico, só o presente escolhido soma pontos (os outros presentes continuam podendo ser enviados). Em partidas em equipe, os pontos dos parceiros somam. Ao final, quem tiver mais pontos vence; se houver vencedor, há um tempo extra em que o vencedor pode propor tarefas para quem perdeu. Encerrar a partida antes conta como derrota.","varies":true},
{"type":"flow","title":"Do apoio ao placar","items":[{"emoji":"❤️","label":"Curtidas","body":"Toques na tela também contam pontos."},{"emoji":"🎁","label":"Presentes","body":"O valor em moedas vira pontos."},{"emoji":"📊","label":"Placar","body":"A barra mostra quem está na frente."},{"emoji":"🏆","label":"Resultado","body":"Quem tiver mais pontos ao final vence."}]},
{"type":"tip","body":"Curtidas também contam! Lembre quem não pode mandar presentes que tocar na tela já ajuda."},
{"type":"quiz","question":"Numa partida de presente específico, o que acontece com outros presentes?","options":["São bloqueados","Podem ser enviados, mas não somam pontos","Valem o dobro"],"correct":1,"explanation":"Segundo a ajuda oficial, só o presente escolhido soma pontos nessa modalidade."}]},

{"slug":"b_expectativa","cat":"batalhas","sub":"Estratégia","title":"Como criar expectativa antes da Batalha","subtitle":"A batalha começa antes do placar aparecer.","summary":"Aquecimento, contagem e combinados com a audiência.","audience":["batalhas","todos"],"level":"intermediario","dur":4,"series":"serie_batalhas","series_order":4,"order":4,"recommended":true,"tags":["batalha","energia","aquecimento","estratégia"],
"blocks":[
{"type":"text","label":"Por que?","body":"Quem chega no meio de uma batalha sem entender o contexto tende a sair. Quem acompanhou o aquecimento já está torcendo."},
{"type":"steps","title":"Como fazer","items":["Anuncie a batalha com antecedência.","Apresente o adversário de forma positiva.","Explique o \"porquê\" da batalha (desafio, brincadeira, combinado).","Faça uma contagem regressiva com a audiência.","Combine uma comemoração para a vitória e um castigo divertido para a derrota."]},
{"type":"tip","body":"Uma meta clara (\"se a gente ganhar, eu canto aquela música\") dá motivo para torcer."},
{"type":"challenge","body":"Na próxima batalha, combine com a audiência uma comemoração antes de começar."}]},

{"slug":"b_energia","cat":"batalhas","sub":"Estratégia","title":"Como manter a energia durante a Batalha","subtitle":"Cinco minutos passam rápido — use bem cada um.","summary":"Ritmo, narração e reconhecimento de quem apoia.","audience":["batalhas","todos"],"level":"intermediario","dur":4,"series":"serie_batalhas","series_order":5,"order":5,"tags":["energia","ritmo","narração"],
"blocks":[
{"type":"steps","title":"Como fazer","items":["Narre o placar: \"faltam 2 minutos, estamos quase empatando!\".","Agradeça na hora quem apoia, pelo nome.","Interaja com o adversário com respeito e bom humor.","Guarde energia para o último minuto.","Comemore sem humilhar o outro lado."]},
{"type":"simulation","scene":"batalha","title":"Onde olhar durante a Batalha","intro":"Toque no tempo e no placar para ver como usar."},
{"type":"tip","body":"O último minuto é o momento mais emocionante. Avise antes que ele está chegando."},
{"type":"quiz","question":"Faltam 30 segundos e você está perdendo. O que funciona melhor?","options":["Encerrar a partida","Narrar o momento e chamar a torcida com energia","Ficar em silêncio"],"correct":1,"explanation":"Narrar o momento cria emoção. E encerrar antes conta como derrota."}]},

{"slug":"b_derrota","cat":"batalhas","sub":"Estratégia","title":"Como lidar com derrota","subtitle":"Perder bem também conquista audiência.","summary":"Humor, agradecimento e próxima chance.","audience":["batalhas","todos"],"level":"iniciante","dur":3,"order":6,"tags":["derrota","emocional","respeito"],
"blocks":[
{"type":"text","label":"Perder faz parte","body":"A audiência lembra mais de como você reagiu do que do placar. Uma derrota com bom humor e gratidão pode ser um dos melhores momentos da LIVE."},
{"type":"steps","title":"Como fazer","items":["Parabenize o adversário.","Agradeça quem apoiou você.","Cumpra o castigo combinado com bom humor.","Anuncie a revanche ou a próxima batalha."]},
{"type":"tip","body":"Nunca culpe a audiência pela derrota. Ela continua com você."},
{"type":"challenge","body":"Na próxima derrota, agradeça três apoiadores pelo nome antes de seguir."}]},

{"slug":"b_parceiros","cat":"batalhas","sub":"Rotina","title":"Como escolher parceiros de Batalha","subtitle":"O parceiro certo deixa as duas LIVEs melhores.","summary":"Afinidade, horário e respeito valem mais que tamanho.","audience":["batalhas","todos"],"level":"intermediario","dur":4,"series":"serie_batalhas","series_order":6,"order":7,"tags":["parceiros","colaboração","rede"],
"blocks":[
{"type":"steps","title":"Como escolher","items":["Procure criadores com clima parecido com o seu.","Veja se os horários de LIVE combinam.","Prefira quem trata bem a audiência e os adversários.","Comece com batalhas amistosas e vá construindo a parceria."]},
{"type":"tip","body":"Na MDuck você tem colegas de agência: combine batalhas com quem você já conhece para treinar."},
{"type":"checklist","title":"Antes de convidar","items":["Combinei horário","Combinei o clima (amistosa, desafio...)","Combinei castigos/comemorações","Avisei minha audiência"]}]},

{"slug":"b_erros_comuns","cat":"batalhas","sub":"Estratégia","title":"Erros comuns em Batalhas","subtitle":"O que afasta a audiência durante uma partida.","summary":"Evite os deslizes que tiram a graça da batalha.","audience":["batalhas","todos"],"level":"intermediario","dur":3,"order":8,"tags":["erros","batalha","boas práticas"],
"blocks":[
{"type":"discover","title":"Toque em cada erro","items":[
 {"emoji":"🙊","title":"Silêncio","body":"Ficar calado olhando o placar. Narre e interaja."},
 {"emoji":"😤","title":"Pressão","body":"Cobrar presentes de forma insistente cansa a audiência."},
 {"emoji":"🥊","title":"Desrespeito","body":"Provocar o adversário além da brincadeira afasta todo mundo."},
 {"emoji":"⏹️","title":"Sair antes","body":"Encerrar a partida antes do fim conta como derrota."}]},
{"type":"tip","body":"Apoio vem de quem está se divertindo. Foque na diversão e o apoio aparece naturalmente."},
{"type":"quiz","question":"Qual atitude afasta mais a audiência?","options":["Narrar o placar","Cobrar presentes de forma insistente","Agradecer quem apoia"],"correct":1,"explanation":"Pressão cansa. Narração e agradecimento aproximam."}]},

{"slug":"b_rotina_batalhas","cat":"batalhas","sub":"Rotina","title":"Como criar uma rotina de Batalhas","subtitle":"Batalhas com hora marcada viram evento.","summary":"Dia fixo, parceiros fixos e momentos especiais.","audience":["batalhas"],"level":"avancado","dur":4,"series":"serie_batalhas","series_order":7,"order":9,"tags":["rotina","evento","batalha"],
"blocks":[
{"type":"steps","title":"Como fazer","items":["Escolha dias fixos para batalhas (ex.: sexta à noite).","Monte um grupo de parceiros de confiança.","Crie batalhas temáticas (ex.: rodada de músicas, perguntas).","Divulgue a agenda de batalhas.","Revise no fim do mês o que funcionou."]},
{"type":"tip","body":"Quando a batalha tem dia certo, a audiência se organiza para estar lá."},
{"type":"challenge","body":"Defina um dia fixo de batalhas e mantenha por 4 semanas."}]},

{"slug":"g_estruturar_live","cat":"games","sub":"Gameplay","title":"Como estruturar uma LIVE de gameplay","subtitle":"Começo, meio e fim — mesmo jogando.","summary":"Uma estrutura simples para a LIVE de games não virar só tela de jogo.","audience":["games","todos"],"level":"iniciante","dur":5,"featured":true,"series":"serie_games","series_order":1,"order":1,"recommended":true,"tags":["games","gameplay","estrutura"],
"blocks":[
{"type":"text","label":"Por que estruturar?","body":"Uma LIVE de games não precisa ser apenas gameplay. Quando ela tem começo, objetivo e momentos marcantes, quem chega entende rápido o que está acontecendo — e fica."},
{"type":"steps","title":"Estrutura sugerida","items":["Abertura (5 min): cumprimente, conte qual é o jogo e o objetivo de hoje.","Aquecimento: uma partida tranquila conversando com o chat.","Momento principal: o desafio da LIVE.","Pausas curtas: responda perguntas e recapitule para quem chegou.","Encerramento: resultado do objetivo e horário da próxima LIVE."]},
{"type":"simulation","scene":"games","title":"Toque nos elementos da LIVE de games","intro":"Veja como cada parte da tela pode trabalhar a seu favor."},
{"type":"tip","body":"Recapitule a cada 15–20 minutos: \"pra quem chegou agora, o desafio de hoje é...\". Muita gente entra no meio."},
{"type":"challenge","body":"Na próxima LIVE de Games, crie um objetivo claro para a sessão e anuncie no início."}]},

{"slug":"g_conversar_jogando","cat":"games","sub":"Comunidade","title":"Como conversar enquanto joga","subtitle":"Jogar e interagir ao mesmo tempo, sem perder o ritmo.","summary":"Pausas naturais, narração e leitura do chat.","audience":["games"],"level":"iniciante","dur":4,"series":"serie_games","series_order":2,"order":2,"tags":["games","chat","conversa","narração"],
"blocks":[
{"type":"steps","title":"Como fazer","items":["Narre o que você está pensando (\"vou por aqui porque...\").","Leia o chat nos momentos calmos do jogo (loading, menus, mortes).","Responda curto durante a ação e completo nas pausas.","Peça opiniões: \"vou pela esquerda ou direita?\"."]},
{"type":"tip","body":"Narrar seu pensamento já é conversar. Quem assiste se sente jogando junto."},
{"type":"quiz","question":"Você está numa parte difícil do jogo e o chat pergunta algo. O que fazer?","options":["Ignorar para sempre","Responder rápido e voltar com calma na próxima pausa","Parar o jogo toda hora"],"correct":1,"explanation":"Reconhecer na hora e completar na pausa mantém o ritmo e a conexão."}]},

{"slug":"g_audiencia_participa","cat":"games","sub":"Comunidade","title":"Como fazer o espectador participar","subtitle":"Decisões, desafios e votações com o chat.","summary":"Dê ao chat um papel dentro da sua gameplay.","audience":["games","todos"],"level":"intermediario","dur":5,"series":"serie_games","series_order":3,"order":3,"recommended":true,"tags":["games","interação","votação","desafios"],
"sources":[{"title":"TikTok Newsroom — Gaming goes LIVE on TikTok","url":"https://newsroom.tiktok.com/gaming-goes-live-on-tiktok","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"text","label":"O que é?","body":"Fazer o espectador participar é dar a ele uma decisão real: escolher personagem, rota, desafio ou regra. Quem decide algo quer ver o resultado — e fica."},
{"type":"discover","title":"Toque para ver ideias","items":[
 {"emoji":"🗳️","title":"Votação no chat","body":"\"Digite 1 para o mapa A e 2 para o mapa B.\""},
 {"emoji":"🎯","title":"Desafio do chat","body":"O chat escolhe uma regra extra para a próxima partida."},
 {"emoji":"🏷️","title":"Nome do chat","body":"Use nomes sugeridos pelo chat para personagens ou times."},
 {"emoji":"🔮","title":"Palpites","body":"\"Quantos abates eu faço nessa partida?\" — confira no final."}]},
{"type":"platform","title":"Como o TikTok funciona","body":"O próprio TikTok já mostrou formatos de LIVE de games em que o público ajuda a escolher nomes e participa de \"votações de sabotagem\" (série The Game Room).","source_url":"https://newsroom.tiktok.com/gaming-goes-live-on-tiktok"},
{"type":"tip","body":"Quando o chat decide, mostre a consequência na tela e comemore junto (ou sofra junto!)."},
{"type":"challenge","body":"Na sua próxima LIVE, deixe o chat decidir 3 coisas durante a gameplay."}]},

{"slug":"g_live_interativa","cat":"games","sub":"LIVE Interativa","title":"LIVE Interativa: o espectador controla parte da experiência","subtitle":"Presente → evento → algo acontece no jogo.","summary":"Entenda o conceito de interatividade em LIVE de games.","audience":["games","todos"],"level":"intermediario","dur":6,"featured":true,"order":4,"tags":["interativo","jogos interativos","eventos","presentes"],
"sources":[{"title":"LIVE Studio Help — How to get cash rewards from your LIVE content","url":"https://www.tiktok.com/live/studio/help/article/Monetize-your-creativity/How-to-get-cash-rewards-from-your-LIVE-content","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"text","label":"O que é?","body":"Numa LIVE interativa, as ações da audiência mudam algo na experiência: um comando no chat, uma curtida ou um presente pode ativar um evento, um item ou uma mudança no ambiente."},
{"type":"strategy","title":"Experiência / estratégia MDuck","body":"Os exemplos desta aula são educativos: mostram o conceito de interatividade. Ferramentas, jogos e integrações disponíveis variam conforme o jogo, a conta, a região e as regras da plataforma. Sempre confira o que está disponível para você antes de prometer algo à audiência."},
{"type":"flow","title":"Toque para seguir o caminho","items":[{"emoji":"🎁","label":"Presente recebido","body":"Alguém da audiência envia um presente."},{"emoji":"⚡","label":"Evento ativado","body":"O presente dispara um evento combinado."},{"emoji":"🎮","label":"Algo acontece","body":"Ex.: um obstáculo aparece, um item é liberado, o personagem muda."}]},
{"type":"simulation","scene":"games","title":"Explore uma LIVE interativa simulada","intro":"Toque no evento, no presente e no chat."},
{"type":"platform","title":"Como o TikTok funciona","body":"Entre os recursos de LIVE citados pelo TikTok estão as \"Gift Votes\", em que a audiência vota enviando presentes. A disponibilidade de recursos pode variar.","varies":true,"source_url":"https://www.tiktok.com/live/studio/help/article/Monetize-your-creativity/How-to-get-cash-rewards-from-your-LIVE-content"},
{"type":"tip","body":"Interatividade funciona quando a regra é clara e a consequência aparece rápido. Explique as regras no começo e repita para quem chega."}]},

{"slug":"g_identificar_interativa","cat":"games","sub":"LIVE Interativa","title":"Você consegue identificar uma LIVE interativa?","subtitle":"Treine o olhar: gameplay, interação, objetivo e evento.","summary":"Um exercício rápido de tocar na tela.","audience":["games","todos"],"level":"iniciante","dur":3,"order":5,"tags":["interativo","exercício","quiz"],
"blocks":[
{"type":"identify","scene":"games","title":"Toque na parte certa da tela","prompts":[
 {"ask":"Onde está a gameplay?","key":"gameplay","ok":"Isso! A gameplay é o jogo em si."},
 {"ask":"Onde está a participação da audiência?","key":"chat","ok":"Boa! O chat é onde a audiência participa."},
 {"ask":"Qual é o objetivo da sessão?","key":"objetivo","ok":"Isso! Objetivo claro ajuda quem chega a entender a LIVE."},
 {"ask":"Onde está o evento ativado pela audiência?","key":"evento","ok":"Perfeito! O evento é a consequência da interação."}]},
{"type":"tip","body":"Se alguém que acabou de chegar não consegue apontar o objetivo da sua LIVE em poucos segundos, deixe-o mais visível."}]},

{"slug":"g_setup","cat":"games","sub":"Setup","title":"Organização do setup gamer","subtitle":"Tela, câmera, áudio e captura.","summary":"O básico de setup para LIVE de games no celular ou no PC.","audience":["games"],"level":"iniciante","dur":6,"series":"serie_games","series_order":4,"order":6,"tags":["setup","áudio","câmera","captura","live studio"],
"sources":[{"title":"LIVE Studio Help — Add a capture source to share your computer screen","url":"https://www.tiktok.com/live/studio/help/article/Get-started-with-your-first-LIVE/Add-a-capture-source-to-share-your-computer-screen?lang=en","consulted_at":"2026-10-03"},{"title":"LIVE Studio Help — Add a cast source to share your phone screen","url":"https://www.tiktok.com/live/studio/help/article/Get-started-with-your-first-LIVE/Add-a-cast-source-to-share-your-phone-screen","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"platform","title":"Como o TikTok funciona","body":"No TikTok LIVE Studio (programa para computador) existem fontes de captura: captura de jogo, de janela e de tela inteira. Também é possível transmitir a tela do celular pelo recurso de \"cast\". Os requisitos de computador e a disponibilidade podem variar.","varies":true},
{"type":"discover","title":"Toque em cada parte do setup","items":[
 {"emoji":"🖥️","title":"Tela","body":"Deixe o jogo como foco e evite elementos que cubram informações importantes."},
 {"emoji":"📷","title":"Câmera","body":"Uma janelinha com seu rosto aumenta muito a conexão."},
 {"emoji":"🎙️","title":"Microfone","body":"Áudio claro importa mais que imagem perfeita."},
 {"emoji":"🔊","title":"Volume do jogo","body":"O som do jogo não pode cobrir sua voz."},
 {"emoji":"💡","title":"Iluminação","body":"Luz de frente no rosto, nunca atrás."}]},
{"type":"checklist","title":"Teste antes de entrar","items":["Jogo aparecendo corretamente","Câmera no lugar","Voz mais alta que o jogo","Internet estável","Notificações silenciadas"]},
{"type":"tip","body":"Faça uma LIVE de teste curta para conferir áudio e imagem antes de um dia importante."}]},

{"slug":"g_desafios_metas","cat":"games","sub":"Estratégia","title":"Como criar desafios e objetivos","subtitle":"Dê um motivo para a audiência acompanhar até o fim.","summary":"Metas de sessão, desafios do chat e momentos de tensão.","audience":["games","todos"],"level":"intermediario","dur":5,"series":"serie_games","series_order":5,"order":7,"tags":["desafios","metas","objetivos","tensão"],
"blocks":[
{"type":"text","label":"Por que?","body":"Objetivo cria história. \"Hoje eu só saio quando ganhar 3 partidas\" faz a audiência torcer e voltar para ver o final."},
{"type":"discover","title":"Toque para ver exemplos","items":[
 {"emoji":"🏁","title":"Meta da sessão","body":"Ex.: chegar a um nível, vencer X partidas, terminar uma fase."},
 {"emoji":"🎲","title":"Desafio com regra","body":"Ex.: jogar só com uma arma, sem curar, com um personagem escolhido pelo chat."},
 {"emoji":"⏱️","title":"Tempo","body":"Ex.: terminar algo em 20 minutos."},
 {"emoji":"🏆","title":"Recompensa","body":"Uma comemoração combinada quando a meta for batida — dentro das regras da plataforma."}]},
{"type":"tip","body":"Mostre o progresso da meta na tela ou repita em voz alta. Meta que ninguém lembra não cria tensão."},
{"type":"challenge","body":"Crie uma meta para sua próxima sessão e anuncie o progresso a cada 20 minutos."}]},

{"slug":"g_ranking","cat":"games","sub":"Competição","title":"Ranking e competição em games","subtitle":"Use a progressão como narrativa da sua LIVE.","summary":"Ranking do jogo, ranking da comunidade e competições oficiais não são a mesma coisa.","audience":["games"],"level":"intermediario","dur":5,"order":8,"tags":["ranking","competição","progressão","torneio"],
"blocks":[
{"type":"text","label":"O que é ranking?","body":"Ranking é uma classificação. Em games, ele pode mostrar seu nível, sua divisão ou sua posição em relação a outros jogadores."},
{"type":"discover","title":"Toque para entender as diferenças","items":[
 {"emoji":"🎮","title":"Ranking dentro do jogo","body":"Sistema do próprio jogo (elos, divisões, temporadas). Cada jogo tem as suas regras."},
 {"emoji":"👥","title":"Ranking da comunidade","body":"Criado por você ou por eventos da sua comunidade (ex.: placar de desafios do chat)."},
 {"emoji":"🏟️","title":"Competição oficial","body":"Eventos ou campeonatos promovidos pela plataforma ou organizadores. Confirme sempre as regras e se estão disponíveis para você."}]},
{"type":"strategy","title":"Experiência / estratégia MDuck","body":"Não existe um ranking único do TikTok para todos os jogos. Antes de falar de um ranking ou competição oficial, confirme se ela existe, quais são as regras e se você pode participar."},
{"type":"steps","title":"Como usar na LIVE","items":["Mostre de onde você está partindo (ex.: divisão atual).","Defina uma meta pessoal para a temporada.","Comemore cada subida com a audiência.","Transforme derrotas em história: \"amanhã a gente recupera\"."]},
{"type":"tip","body":"Progressão é narrativa: a audiência que acompanha a subida volta para ver o próximo capítulo."}]},

{"slug":"g_identidade","cat":"games","sub":"Crescimento","title":"Como criar uma identidade gamer","subtitle":"Jogo principal, estilo e marca pessoal.","summary":"Por que as pessoas voltam para te ver jogar — e não só pelo jogo.","audience":["games"],"level":"avancado","dur":5,"series":"serie_games","series_order":6,"order":9,"tags":["identidade","crescimento","jogo principal","tendências"],
"blocks":[
{"type":"steps","title":"Como fazer","items":["Escolha um jogo principal e aprofunde nele.","Teste jogos novos como momentos especiais, não como rotina.","Crie bordões e reações que viram sua marca.","Acompanhe tendências e lançamentos do seu jogo.","Transforme os melhores momentos da LIVE em vídeos curtos."]},
{"type":"tip","body":"As pessoas podem encontrar o jogo em muitos lugares. Elas voltam por você."},
{"type":"challenge","body":"Separe 3 momentos da sua próxima LIVE e transforme em vídeos curtos."}]},

{"slug":"g_comunidade_jogo","cat":"games","sub":"Crescimento","title":"Como construir comunidade em torno de um jogo","subtitle":"Do espectador ao parceiro de jogatina.","summary":"Eventos, jogar com a audiência e reconhecer os frequentes.","audience":["games"],"level":"avancado","dur":4,"series":"serie_games","series_order":7,"order":10,"tags":["comunidade","games","eventos"],
"blocks":[
{"type":"discover","title":"Toque para ver ideias","items":[
 {"emoji":"🤝","title":"Jogue com a audiência","body":"Partidas com seguidores em dias específicos."},
 {"emoji":"🏆","title":"Torneio da comunidade","body":"Uma competição amistosa entre quem acompanha você."},
 {"emoji":"⭐","title":"Reconhecimento","body":"Destaque os frequentes da semana."}]},
{"type":"tip","body":"Quando a audiência joga com você, ela deixa de ser espectadora e vira parte da história."}]},

{"slug":"m_repertorio","cat":"musica","sub":"Preparando a LIVE","title":"Escolha do repertório","subtitle":"Montar a setlist pensando em quem assiste.","summary":"Abertura forte, variação de energia e espaço para pedidos.","audience":["musica","todos"],"level":"iniciante","dur":5,"featured":true,"series":"serie_musica","series_order":1,"order":1,"recommended":true,"tags":["repertório","setlist","música"],
"blocks":[
{"type":"text","label":"Por que planejar?","body":"Repertório planejado evita pausas longas procurando música e deixa a LIVE com ritmo. Também ajuda a equilibrar músicas que você ama com músicas que a audiência pede."},
{"type":"steps","title":"Como montar","items":["Abra com uma música conhecida e animada.","Alterne momentos de energia alta e baixa.","Reserve blocos para pedidos da audiência.","Tenha músicas \"de segurança\" que você domina.","Feche com uma música marcante (a sua \"assinatura\")."]},
{"type":"tip","body":"Tenha uma lista à vista (papel ou tela). Procurar música em silêncio esfria a LIVE."},
{"type":"challenge","body":"Monte sua setlist da próxima LIVE com abertura, bloco de pedidos e música de encerramento."}]},

{"slug":"m_entre_musicas","cat":"musica","sub":"Preparando a LIVE","title":"Como conversar entre músicas","subtitle":"O intervalo também é um momento de conexão.","summary":"Histórias, pedidos e agradecimentos entre uma música e outra.","audience":["musica"],"level":"iniciante","dur":4,"series":"serie_musica","series_order":2,"order":2,"recommended":true,"tags":["conexão","intervalo","conversa"],
"blocks":[
{"type":"text","label":"Por que?","body":"Na música, o intervalo entre duas músicas também pode ser um momento de conexão. É ali que a audiência conhece você além da voz."},
{"type":"steps","title":"Como fazer","items":["Conte por que escolheu a próxima música.","Leia e responda pedidos e comentários.","Agradeça quem apoiou durante a música.","Anuncie o que vem a seguir para segurar quem chegou."]},
{"type":"simulation","scene":"musica","title":"Toque nos elementos da LIVE musical","intro":"Veja onde estão os pedidos, a música atual e a audiência."},
{"type":"tip","body":"Intervalos curtos e cheios de conversa valem mais que intervalos longos em silêncio."},
{"type":"challenge","body":"Na próxima LIVE musical, converse com a audiência antes de iniciar cada música."}]},

{"slug":"m_pedidos","cat":"musica","sub":"Comunidade","title":"Como trabalhar com pedidos de música","subtitle":"Fila, prioridade e transparência.","summary":"Organize pedidos sem perder o controle da LIVE.","audience":["musica"],"level":"intermediario","dur":4,"series":"serie_musica","series_order":3,"order":3,"tags":["pedidos","fila","comunidade"],
"sources":[{"title":"LIVE Studio Help — Set a LIVE goal to welcome more Gifts","url":"https://www.tiktok.com/live/studio/help/article/Monetize-your-creativity/Set-a-LIVE-goal-to-welcome-more-Gifts","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"steps","title":"Como fazer","items":["Explique as regras dos pedidos no começo.","Anote a fila e diga em voz alta a ordem.","Seja honesto quando não souber uma música.","Ofereça alternativas parecidas."]},
{"type":"platform","title":"Como o TikTok funciona","body":"A Meta de LIVE (LIVE goal) mostra para a audiência um objetivo durante a transmissão, com o tipo e a quantidade de presentes. Ela pode ser usada, por exemplo, para marcar momentos especiais da LIVE.","varies":true},
{"type":"tip","body":"Transparência na fila evita frustração: todo mundo sabe quando é a vez da sua música."}]},

{"slug":"m_presenca","cat":"musica","sub":"Performance","title":"Presença de câmera para músicos","subtitle":"Enquadramento, olhar e expressão.","summary":"Pequenos ajustes que fazem a audiência se sentir na primeira fila.","audience":["musica"],"level":"iniciante","dur":4,"series":"serie_musica","series_order":4,"order":4,"tags":["performance","câmera","enquadramento","iluminação"],
"blocks":[
{"type":"discover","title":"Toque em cada ponto","items":[
 {"emoji":"📐","title":"Enquadramento","body":"Mostre rosto e instrumento sem cortar as mãos."},
 {"emoji":"👀","title":"Olhar","body":"Olhe para a câmera em trechos importantes da música."},
 {"emoji":"💡","title":"Luz","body":"Luz de frente e suave. Evite janela atrás."},
 {"emoji":"🎚️","title":"Áudio","body":"Equilibre voz e instrumento. Teste antes."},
 {"emoji":"🖼️","title":"Cenário","body":"Simples e organizado, com algo que tenha a sua cara."}]},
{"type":"tip","body":"Áudio bom segura mais gente do que imagem perfeita. Priorize o som."},
{"type":"checklist","title":"Antes de cantar","items":["Instrumento afinado","Voz e instrumento equilibrados","Rosto iluminado","Enquadramento testado"]}]},

{"slug":"m_comunidade_fas","cat":"musica","sub":"Comunidade de fãs","title":"Como criar uma comunidade de fãs","subtitle":"Rituais, momentos recorrentes e expectativa.","summary":"Faça o espectador voltar para a próxima LIVE.","audience":["musica"],"level":"intermediario","dur":5,"series":"serie_musica","series_order":5,"order":5,"tags":["fãs","rituais","comunidade","identidade"],
"sources":[{"title":"TikTok Newsroom — Exploring new ways for creators to build their community with LIVE Subscription","url":"https://newsroom.tiktok.com/en-us/live-subscription-invite-only","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"discover","title":"Toque para ver ideias","items":[
 {"emoji":"🎶","title":"Música de abertura","body":"Sempre a mesma: vira o \"chegou a hora\"."},
 {"emoji":"🙌","title":"Momento dos fãs","body":"Um bloco fixo dedicado a quem acompanha sempre."},
 {"emoji":"📣","title":"Expectativa","body":"Anuncie uma surpresa para a próxima LIVE."},
 {"emoji":"🏷️","title":"Nome do fã-clube","body":"Um apelido para a sua comunidade."}]},
{"type":"platform","title":"Como o TikTok funciona","body":"A LIVE Subscription é uma assinatura mensal com benefícios definidos pelo criador (como selos e emotes personalizados). O acesso ao recurso depende de elegibilidade e pode variar.","varies":true},
{"type":"tip","body":"Fã gosta de se sentir lembrado. Reconheça quem está sempre presente."},
{"type":"challenge","body":"Crie um momento fixo dos fãs e repita nas próximas 4 LIVEs."}]},

{"slug":"m_energia","cat":"musica","sub":"Preparando a LIVE","title":"Como manter a energia na LIVE musical","subtitle":"Ritmo, variação e pausas inteligentes.","summary":"Evite que a LIVE fique monótona depois da primeira hora.","audience":["musica"],"level":"intermediario","dur":4,"order":6,"tags":["energia","ritmo","variação"],
"blocks":[
{"type":"steps","title":"Como fazer","items":["Varie estilos e andamentos.","Faça um bloco temático (ex.: anos 2000, acústico).","Use pausas curtas para hidratar e conversar.","Crie um momento especial na metade da LIVE."]},
{"type":"tip","body":"Avise o que vem a seguir: \"daqui a pouco tem o bloco de pedidos!\" segura quem está assistindo."}]},

{"slug":"m_evolucao","cat":"musica","sub":"Evolução","title":"Como evoluir sua LIVE musical","subtitle":"Testar formatos e analisar o que funciona.","summary":"Pequenas experiências semanais com repertório e formato.","audience":["musica"],"level":"avancado","dur":4,"series":"serie_musica","series_order":6,"order":7,"tags":["evolução","análise","formatos"],
"blocks":[
{"type":"steps","title":"Como fazer","items":["Teste um formato novo por semana (ex.: só pedidos, tema, convidado).","Anote quais músicas mais engajam.","Transforme os melhores momentos em vídeos curtos.","Revise o repertório todo mês."]},
{"type":"tip","body":"A música que mais engaja nem sempre é a que você mais gosta de cantar. Observe a audiência."}]},

{"slug":"m_carreira","cat":"musica","sub":"Carreira","title":"O LIVE na carreira de artista","subtitle":"De espectadores a uma base de fãs.","summary":"Como a LIVE pode fazer parte do desenvolvimento de um artista.","audience":["musica"],"level":"avancado","dur":5,"series":"serie_musica","series_order":7,"order":8,"tags":["carreira","artista","programas"],
"sources":[{"title":"TikTok Newsroom — TikTok LIVE's Music on Stage returns for 2026","url":"https://newsroom.tiktok.com/tiktok-lives-music-on-stage-returns-for-2026-to-discover-the-next-generation-of-global-music-stars?lang=en-GB","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"platform","title":"Como o TikTok funciona","body":"O TikTok tem destacado o LIVE como espaço para artistas emergentes. Um exemplo é o programa global Music on Stage, que voltou em 2026 para descobrir novos artistas e apoiá-los no caminho entre a LIVE e a carreira musical. Programas e regras variam por região e edição.","varies":true},
{"type":"steps","title":"Como usar a LIVE na carreira","items":["Apresente suas músicas autorais com contexto e história.","Teste músicas novas com a audiência antes de lançar.","Crie uma base de fãs que acompanha seus lançamentos.","Use a LIVE para anunciar shows, lançamentos e novidades."]},
{"type":"tip","body":"Sua comunidade da LIVE pode ser o primeiro público dos seus lançamentos. Cuide dela."}]},

{"slug":"e_frequencia","cat":"engajamento","sub":"Evolução","title":"Como melhorar sua frequência","subtitle":"Constância é o que transforma LIVE em hábito.","summary":"Pequenos aumentos de frequência, sem se sobrecarregar.","audience":["todos","conversa"],"level":"iniciante","dur":4,"order":1,"recommended":true,"tags":["frequência","constância","rotina","evolução"],
"blocks":[
{"type":"text","label":"Por que?","body":"Quanto mais previsível a sua presença, mais fácil é a audiência criar o hábito de te encontrar."},
{"type":"steps","title":"Como fazer","items":["Veja quantos dias você fez LIVE no último mês.","Some um dia por semana, sem aumentar tudo de uma vez.","Mantenha horários parecidos.","Prefira LIVEs mais curtas e frequentes a uma LIVE gigante isolada."]},
{"type":"tip","body":"Evolua no seu ritmo. Constância vale mais do que intensidade."},
{"type":"challenge","body":"Faça uma LIVE a mais por semana do que no mês passado, durante 4 semanas."}]},

{"slug":"e_silencio","cat":"engajamento","sub":"Engajamento","title":"Como lidar com silêncio no chat","subtitle":"Chat parado não é LIVE parada.","summary":"Técnicas para reacender a conversa.","audience":["todos","conversa"],"level":"iniciante","dur":4,"order":2,"tags":["silêncio","chat","engajamento"],
"blocks":[
{"type":"discover","title":"Toque para ver técnicas","items":[
 {"emoji":"❓","title":"Pergunta fácil","body":"\"De onde vocês estão assistindo?\""},
 {"emoji":"🗳️","title":"Escolha","body":"\"Digite 1 ou 2\" — responder é fácil."},
 {"emoji":"📖","title":"História","body":"Conte algo que aconteceu com você hoje."},
 {"emoji":"🎯","title":"Mini desafio","body":"Proponha um desafio rápido para quem estiver assistindo."}]},
{"type":"quiz","question":"Você está numa LIVE de Games e o chat está parado. O que pode fazer?","options":["Ignorar o chat","Criar uma pergunta ou desafio para a audiência","Encerrar imediatamente"],"correct":1,"explanation":"Perguntas e desafios dão um motivo fácil para a pessoa participar."},
{"type":"tip","body":"Muita gente assiste sem comentar. Falar com elas também conta: \"se você está aí quietinho, manda um 💜\"."}]},

{"slug":"e_entender_audiencia","cat":"engajamento","sub":"Engajamento","title":"Como entender sua audiência","subtitle":"Quem são, de onde vêm e o que gostam.","summary":"Observe padrões para criar LIVEs que fazem sentido para quem assiste.","audience":["todos"],"level":"intermediario","dur":4,"order":3,"tags":["audiência","análise","público"],
"blocks":[
{"type":"steps","title":"Como fazer","items":["Pergunte de onde as pessoas estão assistindo.","Observe quais assuntos geram mais comentários.","Anote quem são os frequentes.","Veja em quais horários a LIVE enche mais."]},
{"type":"tip","body":"Sua audiência te diz o que quer o tempo todo. Basta prestar atenção nos comentários."}]},

{"slug":"e_metas","cat":"engajamento","sub":"Evolução","title":"Como criar metas para sua LIVE","subtitle":"Metas pequenas, claras e possíveis.","summary":"Metas que motivam sem pressionar.","audience":["todos"],"level":"iniciante","dur":4,"order":4,"tags":["metas","objetivos","evolução"],
"sources":[{"title":"LIVE Studio Help — Set a LIVE goal to welcome more Gifts","url":"https://www.tiktok.com/live/studio/help/article/Monetize-your-creativity/Set-a-LIVE-goal-to-welcome-more-Gifts","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"text","label":"O que é uma boa meta?","body":"Uma boa meta é clara, possível e fácil de acompanhar. Ex.: \"fazer 4 LIVEs esta semana\" ou \"responder todo mundo que chegar\"."},
{"type":"platform","title":"Como o TikTok funciona","body":"A Meta de LIVE (LIVE goal, antes chamada de Wishlist) exibe para a audiência um objetivo de presentes durante a transmissão. A própria ajuda do LIVE Studio recomenda metas realistas: metas exageradas podem desanimar a participação.","varies":true,"source_url":"https://www.tiktok.com/live/studio/help/article/Monetize-your-creativity/Set-a-LIVE-goal-to-welcome-more-Gifts"},
{"type":"tip","body":"Meta boa é a que você consegue repetir. Comemore cada meta batida com a audiência."},
{"type":"challenge","body":"Defina uma meta para a próxima semana e conte para a audiência na primeira LIVE."}]},

{"slug":"e_dias_ruins","cat":"engajamento","sub":"Evolução","title":"Como lidar com dias ruins","subtitle":"Nem toda LIVE vai ser a melhor — e tudo bem.","summary":"Cuide de você e mantenha a constância de forma leve.","audience":["todos"],"level":"iniciante","dur":3,"order":5,"tags":["emocional","bem-estar","constância"],
"blocks":[
{"type":"steps","title":"Como fazer","items":["Faça uma LIVE mais curta em vez de não fazer.","Seja honesto com a audiência, sem dramatizar.","Escolha um formato leve (conversa, música tranquila).","Descanse quando precisar — descanso também é estratégia."]},
{"type":"tip","body":"Sua audiência gosta de você, não só dos seus melhores dias."}]},

{"slug":"e_conteudo_curto","cat":"engajamento","sub":"Evolução","title":"Como transformar LIVE em conteúdo curto","subtitle":"Os melhores momentos podem trazer gente nova.","summary":"Recortes, bastidores e chamadas para a próxima LIVE.","audience":["todos"],"level":"intermediario","dur":4,"order":6,"tags":["vídeos curtos","recortes","divulgação"],
"blocks":[
{"type":"steps","title":"Como fazer","items":["Anote os momentos marcantes durante a LIVE.","Transforme em vídeos curtos com contexto.","Use os vídeos para anunciar a próxima LIVE.","Teste formatos: reação, melhores momentos, bastidores."]},
{"type":"tip","body":"Quem te conhece por um vídeo curto precisa saber quando te encontrar ao vivo. Coloque o horário da LIVE."}]},

{"slug":"t_conexao","cat":"todo_streamer","sub":"Conexão","title":"Como criar conexão com a audiência","subtitle":"O que faz alguém sentir que conhece você.","summary":"Autenticidade, memória e reciprocidade.","audience":["todos"],"level":"iniciante","dur":5,"start_here":true,"featured":true,"order":1,"recommended":true,"tags":["conexão","audiência","comunidade","autenticidade"],
"blocks":[
{"type":"text","label":"O que é conexão?","body":"Conexão é quando a pessoa sente que existe uma relação: você lembra dela, conversa com ela e compartilha um pouco de quem você é."},
{"type":"discover","title":"Toque para descobrir","items":[
 {"emoji":"🧠","title":"Memória","body":"Lembre detalhes: \"e aquela prova, deu certo?\""},
 {"emoji":"🤗","title":"Autenticidade","body":"Seja você. As pessoas se conectam com gente, não com personagens perfeitos."},
 {"emoji":"🔁","title":"Reciprocidade","body":"Pergunte sobre a vida de quem assiste também."}]},
{"type":"tip","body":"Não pense apenas em quem está entrando na sua LIVE. Pense em quem pode voltar amanhã."},
{"type":"challenge","body":"Na próxima LIVE, lembre de algo que um espectador frequente contou numa LIVE anterior."}]},

{"slug":"t_energia","cat":"todo_streamer","sub":"Conexão","title":"Como manter a energia","subtitle":"Energia não é gritar: é presença.","summary":"Postura, voz e ritmo para LIVEs longas.","audience":["todos"],"level":"iniciante","dur":4,"order":2,"tags":["energia","voz","postura","ritmo"],
"blocks":[
{"type":"steps","title":"Como fazer","items":["Fale um pouco mais animado do que numa conversa normal.","Varie o tom de voz.","Faça pausas curtas para se hidratar.","Mude de assunto ou atividade a cada tempo."]},
{"type":"tip","body":"Energia constante cansa você e a audiência. Varie entre momentos agitados e calmos."}]},

{"slug":"t_identidade","cat":"todo_streamer","sub":"Identidade","title":"Como criar sua identidade","subtitle":"O que faz a sua LIVE ser reconhecida.","summary":"Bordões, cenário, horário e estilo.","audience":["todos"],"level":"intermediario","dur":4,"order":3,"tags":["identidade","marca pessoal","estilo"],
"blocks":[
{"type":"discover","title":"Toque nos elementos de identidade","items":[
 {"emoji":"🗣️","title":"Bordão","body":"Uma frase que todo mundo associa a você."},
 {"emoji":"🎨","title":"Visual","body":"Cenário, cores e iluminação reconhecíveis."},
 {"emoji":"⏰","title":"Horário","body":"Ser encontrado sempre no mesmo horário também é identidade."},
 {"emoji":"💜","title":"Valores","body":"Como você trata as pessoas na LIVE."}]},
{"type":"tip","body":"Identidade se constrói repetindo. Escolha poucas coisas e mantenha."}]},

{"slug":"t_melhorar_aos_poucos","cat":"todo_streamer","sub":"Evolução","title":"Como melhorar aos poucos","subtitle":"1% melhor a cada LIVE.","summary":"Uma melhoria por vez, com consistência.","audience":["todos"],"level":"iniciante","dur":3,"order":4,"tags":["evolução","melhoria contínua"],
"blocks":[
{"type":"steps","title":"Como fazer","items":["Escolha uma coisa para melhorar nesta semana.","Pratique em todas as LIVEs da semana.","Avalie no fim da semana.","Escolha a próxima melhoria."]},
{"type":"tip","body":"Ninguém fica bom em LIVE de uma vez. Quem melhora um pouco toda semana vai longe."},
{"type":"challenge","body":"Escolha hoje a sua melhoria da semana e escreva onde você possa ver."}]},

{"slug":"r_presentes_diamantes","cat":"recursos","sub":"Monetização","title":"Presentes e diamantes","subtitle":"Como funciona o apoio da audiência na LIVE.","summary":"Moedas, presentes, diamantes e elegibilidade.","audience":["todos"],"level":"iniciante","dur":5,"order":1,"tags":["presentes","diamantes","moedas","monetização"],
"sources":[{"title":"TikTok Support — LIVE Gifts on TikTok","url":"https://support.tiktok.com/en/live-gifts-wallet/tiktok-live/live-gifts-on-tiktok","consulted_at":"2026-10-03"},{"title":"TikTok — LIVE Safety Guide","url":"https://www.tiktok.com/safety/en/tools-and-guides/live-safety-guide","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"platform","title":"Como o TikTok funciona","body":"Durante a LIVE, a audiência pode enviar presentes usando moedas (coins) compradas no app. Os presentes recebidos geram diamantes para o criador, de acordo com as regras e a elegibilidade do programa. Para enviar e receber presentes é preciso ter pelo menos 18 anos (19 na Coreia do Sul), e a disponibilidade depende da região e das regras da conta.","varies":true},
{"type":"flow","title":"O caminho do apoio","items":[{"emoji":"🪙","label":"Moedas","body":"A audiência compra moedas no app."},{"emoji":"🎁","label":"Presente","body":"Envia um presente na sua LIVE."},{"emoji":"💎","label":"Diamantes","body":"O presente gera diamantes para você, conforme as regras do TikTok."}]},
{"type":"tip","body":"Agradeça cada presente pelo nome — o agradecimento é o que faz a pessoa se sentir parte."},
{"type":"strategy","title":"Atenção","body":"Valores, taxas de conversão e regras de pagamento mudam e dependem do país e do programa. Confirme sempre nas páginas oficiais do TikTok e com a equipe MDuck."}]},

{"slug":"r_metas_live","cat":"recursos","sub":"Monetização","title":"Meta de LIVE (LIVE goal)","subtitle":"Mostre um objetivo para a audiência acompanhar.","summary":"Como configurar e usar metas visíveis na LIVE.","audience":["todos"],"level":"intermediario","dur":4,"order":2,"tags":["meta","live goal","wishlist"],
"sources":[{"title":"LIVE Studio Help — Set a LIVE goal to welcome more Gifts","url":"https://www.tiktok.com/live/studio/help/article/Monetize-your-creativity/Set-a-LIVE-goal-to-welcome-more-Gifts","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"platform","title":"Como o TikTok funciona","body":"A Meta de LIVE mostra seus objetivos para a audiência durante a transmissão (o recurso já se chamou Wishlist). Na configuração você escolhe a descrição, o tipo e a quantidade de presentes e pode definir uma recompensa para quem mais contribuir.","varies":true},
{"type":"steps","title":"Como usar bem","items":["Escolha metas possíveis.","Explique o que acontece quando a meta for batida.","Atualize a audiência sobre o progresso.","Cumpra o que foi combinado e comemore."]},
{"type":"tip","body":"Se prometer algo para quem mais apoiar, cumpra. Confiança é o que mantém a comunidade."}]},

{"slug":"r_convidados","cat":"recursos","sub":"Colaboração","title":"Co-host e convidados","subtitle":"LIVE com outros criadores e com a audiência.","summary":"Diferença entre co-host e convidados, e como aproveitar.","audience":["todos"],"level":"intermediario","dur":5,"order":3,"tags":["co-host","convidados","multi-guest","colaboração"],
"sources":[{"title":"LIVE Studio Help — Go LIVE with other creators","url":"https://www.tiktok.com/live/studio/help/article/Boost-viewer-engagement/Go-LIVE-with-other-creators?lang=en","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"platform","title":"Como o TikTok funciona","body":"Co-host: você convida outros criadores que estão ao vivo para dividir a tela (a ajuda do LIVE Studio cita até três outros criadores) — e é a partir do co-host que se inicia uma partida (Batalha). Convidados (multi-guest): você traz pessoas para participar da sua LIVE. Formatos e limites podem mudar com atualizações.","varies":true},
{"type":"steps","title":"Como aproveitar","items":["Combine o assunto antes com o convidado.","Apresente o convidado para sua audiência.","Divida o tempo de fala.","Agradeça e indique o perfil do convidado no final."]},
{"type":"tip","body":"Um bom convidado apresenta você para uma audiência nova. Escolha com cuidado e seja um bom anfitrião."}]},

{"slug":"r_moderacao","cat":"recursos","sub":"Moderação","title":"Moderação na LIVE","subtitle":"Moderadores e filtros de comentários.","summary":"Mantenha o chat saudável sem tirar sua atenção da LIVE.","audience":["todos"],"level":"iniciante","dur":4,"order":4,"tags":["moderação","moderadores","comentários","segurança"],
"sources":[{"title":"TikTok Support — Moderating on TikTok LIVE","url":"https://support.tiktok.com/en/live-gifts-wallet/tiktok-live/moderating-on-tiktok-live","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"platform","title":"Como o TikTok funciona","body":"Você pode adicionar moderadores para ajudar na LIVE. Criadores e moderadores têm ferramentas para gerenciar comentários, como filtrar palavras-chave. O caminho exato nas configurações pode mudar com atualizações do app.","varies":true},
{"type":"steps","title":"Como organizar","items":["Escolha moderadores de confiança.","Combine com eles as regras do chat.","Configure palavras bloqueadas antes de começar.","Deixe as regras claras para a audiência."]},
{"type":"tip","body":"Moderador bom deixa você livre para focar em quem está assistindo."}]},

{"slug":"s_boas_praticas","cat":"seguranca","sub":"Segurança","title":"Boas práticas de segurança na LIVE","subtitle":"Proteja você e sua comunidade.","summary":"Dados pessoais, localização e limites.","audience":["todos"],"level":"iniciante","dur":4,"order":1,"tags":["segurança","privacidade","diretrizes"],
"sources":[{"title":"TikTok — LIVE Safety Guide","url":"https://www.tiktok.com/safety/en/tools-and-guides/live-safety-guide","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"checklist","title":"Antes de entrar ao vivo","items":["Nada no cenário mostra endereço ou documentos","Localização não aparece na tela","Moderadores definidos","Palavras bloqueadas configuradas","Sei como encerrar ou silenciar alguém rápido"]},
{"type":"platform","title":"Como o TikTok funciona","body":"O TikTok mantém um Guia de Segurança para LIVE com regras e ferramentas, incluindo os requisitos de idade (18+ para fazer LIVE e para enviar e receber presentes).","source_url":"https://www.tiktok.com/safety/en/tools-and-guides/live-safety-guide"},
{"type":"tip","body":"Na dúvida, não mostre. Sua segurança vem antes de qualquer número."}]},

{"slug":"s_diretrizes","cat":"seguranca","sub":"Diretrizes","title":"Diretrizes e cuidados","subtitle":"Regras da comunidade também valem ao vivo.","summary":"Conheça as diretrizes e evite restrições na conta.","audience":["todos"],"level":"iniciante","dur":4,"order":2,"tags":["diretrizes","regras","restrições"],
"sources":[{"title":"TikTok — Community Guidelines: Accounts and Features","url":"https://www.tiktok.com/community-guidelines/en/accounts-features","consulted_at":"2026-10-03"}],
"blocks":[
{"type":"platform","title":"Como o TikTok funciona","body":"As Diretrizes da Comunidade do TikTok também valem para a LIVE. Violações podem levar a restrições de recursos ou da conta. As regras são atualizadas periodicamente.","varies":true,"source_url":"https://www.tiktok.com/community-guidelines/en/accounts-features"},
{"type":"tip","body":"Antes de testar um formato novo, pergunte para a equipe MDuck se ele está dentro das regras."},
{"type":"quiz","question":"As Diretrizes da Comunidade valem durante a LIVE?","options":["Não, só para vídeos","Sim, também valem ao vivo"],"correct":1,"explanation":"As regras da comunidade valem para todo o conteúdo, inclusive LIVE."}]},

{"slug":"x_em_breve_games_avancado","cat":"games","sub":"Crescimento","title":"Games avançado","subtitle":"Estamos preparando novos conteúdos para você.","summary":"Conteúdos avançados para streamers de games.","audience":["games"],"level":"avancado","dur":null,"order":99,"tags":["em breve"],"blocks":[]}

]}
$json$::jsonb)
from (select distinct agency_id from managers where agency_id is not null) a;

-- aula "em breve" ja nasce como em breve
update academy_lessons set availability = 'em_breve' where slug = 'x_em_breve_games_avancado' and availability = 'bloqueado';

-- ----------------------------------------------------------------------------
-- MAX Aulas -> Academia (categoria "Conteudo exclusivo MDuck"), ja disponiveis
-- ----------------------------------------------------------------------------
insert into academy_lessons (agency_id, slug, category_id, subcategory, title, summary, audience, level, thumbnail_url,
                             blocks, availability, status, is_active, sort_order, tags, info_status)
select m.agency_id, 'max_' || m.id,
       (select id from academy_categories c where c.agency_id = m.agency_id and c.slug = 'exclusivo'),
       case m.category when 'batalha' then 'Batalhas' when 'musico' then 'Música' when 'games' then 'Games' else 'Geral' end,
       m.title, m.description,
       case m.category when 'batalha' then array['batalhas'] when 'musico' then array['musica'] when 'games' then array['games'] else array['todos'] end,
       case m.level when 'veterano' then 'intermediario' when 'pro' then 'avancado' else 'iniciante' end,
       m.cover_image_url,
       jsonb_build_array(
         case when m.video_source = 'youtube'
           then jsonb_build_object('type', 'youtube', 'url', m.video_url, 'title', m.title)
           else jsonb_build_object('type', 'video', 'url', m.video_url, 'title', m.title) end)
       || case when coalesce(m.description, '') <> '' then jsonb_build_array(jsonb_build_object('type', 'text', 'body', m.description)) else '[]'::jsonb end,
       'disponivel', 'publicado', m.is_active, 0, array['mduck'], 'atual'
from max_lessons m
where not exists (select 1 from academy_lessons l where l.agency_id = m.agency_id and l.slug = 'max_' || m.id);

notify pgrst, 'reload schema';
