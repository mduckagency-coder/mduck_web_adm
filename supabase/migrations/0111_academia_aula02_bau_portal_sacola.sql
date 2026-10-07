-- ============================================================================
-- Academia MDuck · AULA — Baú de Tesouros, Portal e Sacola de Prêmios
-- Blocos interativos: live_menu, tiktok_sheet, compare (+ blocos comuns).
-- Nomes, @ e comentários são fictícios; valores são exemplos da interface.
-- Entra "Em revisão" e liberada só para a conta de teste @gidreams_.
-- Para publicar: mude o status no painel (ou rode o update do final).
-- Não mexe em outras aulas. Idempotente (pelo slug).
-- ============================================================================

do $$
declare
  v_menu jsonb := $m$[
    {"icon": "enquete", "label": "Enquete"},
    {"icon": "manual", "label": "Manual"},
    {"icon": "bau", "label": "Baú do tesouro"},
    {"icon": "bau_superfa", "label": "Baú de Superfã"},
    {"icon": "sacola", "label": "Sacola de Prêmios"},
    {"icon": "papel", "label": "Papel de parede"},
    {"icon": "desejos", "label": "Desejos"},
    {"icon": "musicas", "label": "Músicas da LIVE"}
  ]$m$::jsonb;
  v_chat jsonb := $c$[
    {"user": "@ana_live", "text": "boa noite!! 💜"},
    {"user": "@bruno_live", "text": "cheguei 👋"},
    {"user": "Lucas Martins · Host", "text": "bem-vindos! hoje tem novidade na LIVE 🎁"}
  ]$c$::jsonb;
  v_blocks jsonb;
  a record;
begin
  v_blocks := $json$
[
  {"type": "text", "label": "Aula interativa",
   "body": "Você vai encontrar, abrir e configurar três recursos da LIVE tocando na tela. Os números que aparecem são exemplos: na sua conta podem ser diferentes."},

  {"type": "compare", "label": "Três recursos, três objetivos", "title": "Qual é a diferença?",
   "intro": "Toque em cada um para ver o caminho.",
   "items": [
     {"emoji": "🎁", "title": "Baú", "goal": "Recompense quem já está na sua LIVE.", "steps": "Sua LIVE | 👥 espectadores da sua LIVE"},
     {"emoji": "🚪", "title": "Portal", "goal": "Traga pessoas de outras LIVEs para a sua.", "steps": "Outras LIVEs | 🚪 Portal | Sua LIVE"},
     {"emoji": "🛍️", "title": "Sacola", "goal": "Crie uma ação de participação com regras definidas por você.", "steps": "Sua LIVE | 📋 condições | 👥 participantes elegíveis"}
   ]},

  {"type": "text", "label": "Parte 1", "title": "🎁 Baú de Tesouros", "body": "Primeiro: onde ele fica durante a LIVE."},

  {"type": "live_menu", "title": "Onde fica o Baú?", "intro": "Você está fazendo LIVE. Os recursos ficam no botão ⋯ (Mais opções).",
   "host": "Lucas Martins", "chat": "__CHAT__", "items": "__MENU__",
   "target": "Baú do tesouro",
   "target_title": "🎁 Baú de Tesouros",
   "target_body": "Achou! O Baú fica no menu ⋯ (Mais opções). No mesmo menu também aparecem o Baú de Superfã e a Sacola de Prêmios.",
   "done_text": "✨ Achou o Baú! Continue ↓"},

  {"type": "tiktok_sheet", "title": "A tela do Baú", "intro": "Toque nos cards para entender e depois em Enviar para ver o que acontece.",
   "host": "Lucas Martins", "tabs": "Baú de Tesouros|Portal", "tab_active": "0", "corner": "icons",
   "tab_explain": "O Portal fica aqui, ao lado do Baú. Vamos ver na Parte 2.",
   "section": "Itens", "section_action": "Personalizar ✎",
   "elements": [
     {"kind": "option", "coins": "20", "right": "16 ganhadores", "selected": "sim",
      "explain_title": "🪙 Moedas",
      "explain": "Cada card junta uma quantidade de Moedas com um número de ganhadores. As Moedas saem do saldo da conta que cria o Baú.\n\nOs valores são exemplos da interface e podem variar conforme a conta, a região e a versão do TikTok."},
     {"kind": "option", "coins": "100", "right": "25 ganhadores",
      "explain_title": "👥 Ganhadores",
      "explain": "Quando a opção estiver disponível, você define quantas pessoas poderão receber a recompensa. Ex.: 20 Moedas → 16 ganhadores. Os números são só exemplos da interface."},
     {"kind": "option", "coins": "1000", "right": "100 ganhadores"}
   ],
   "terms": "Ao tocar em \"Enviar\", você aceita os Termos do Baú de Tesouros.", "button": "Enviar",
   "send_title": "DEPOIS DE ENVIAR",
   "send_steps": [
     {"emoji": "🎁", "label": "O Baú aparece na LIVE"},
     {"emoji": "👥", "label": "Os espectadores participam"},
     {"emoji": "🪙", "label": "As Moedas são distribuídas conforme a mecânica do recurso"}
   ],
   "rewards": "6",
   "send_body": "Quem pode participar depende das regras que o próprio recurso mostrar no momento da criação."},

  {"type": "steps", "title": "Como o Baú funciona",
   "items": [
     "Você define a quantidade de Moedas.",
     "Define a quantidade de ganhadores, quando essa opção estiver disponível.",
     "O Baú aparece para a audiência.",
     "As pessoas participam.",
     "As Moedas são distribuídas conforme a mecânica do recurso."
   ]},

  {"type": "tiktok_sheet", "title": "Personalizar o Baú", "intro": "Em Personalizar você digita os seus valores. Toque em cada campo.",
   "host": "Lucas Martins", "sheet_title": "Personalizar", "back": "sim", "corner": "help",
   "elements": [
     {"kind": "field", "label": "Moedas", "hint": "Total (1-10000)",
      "explain_title": "🪙 Moedas", "explain": "A quantidade total de Moedas do Baú, dentro do limite que o TikTok mostrar na sua tela. O limite do exemplo é o que aparecia na interface de referência."},
     {"kind": "field", "label": "Ganhadores", "hint": "Quantidade (1-500)",
      "explain_title": "👥 Ganhadores", "explain": "Quantas pessoas poderão receber a recompensa, dentro do limite mostrado pelo TikTok."},
     {"kind": "field", "label": "Contagem regressiva", "hint": "Período da contagem regressiva (1-5)",
      "explain_title": "⏱️ Contagem regressiva", "explain": "Define o período de contagem regressiva disponível para essa ação, conforme as opções apresentadas pelo TikTok."}
   ],
   "terms": "Ao tocar em \"Enviar\", você aceita os Termos do Baú de Tesouros.", "button": "Enviar"},

  {"type": "feed", "label": "Exemplo prático", "title": "Um Baú na LIVE", "button": "Ver o exemplo",
   "items": [
     {"user": "@lucasmartins.live", "text": "Vou abrir um Baú para quem está aqui comigo!", "emoji": "🎁"},
     {"user": "@ana_live", "text": "entrou no Baú", "emoji": "👥"},
     {"user": "@bruno_live", "text": "recebeu Moedas do Baú", "emoji": "🪙"},
     {"user": "@camila_s", "text": "obrigada!! 💜", "emoji": "💬"}
   ],
   "body": "O que aconteceu? O Baú criou uma pequena dinâmica dentro da LIVE e deu um motivo a mais para a audiência participar daquele momento."},

  {"type": "tip", "body": "O Baú pode movimentar a audiência que já está na sua LIVE. Use em momentos estratégicos: crie uma pequena expectativa, puxe a interação no chat e reconheça quem participa. Não precisa ser sempre — e nunca acima do que cabe no seu bolso."},

  {"type": "text", "label": "Parte 2", "title": "🚪 Portal", "body": "O Portal fica junto do Baú. Vamos voltar ao menu."},

  {"type": "live_menu", "title": "Onde fica o Portal?", "intro": "Abra o menu ⋯ de novo.",
   "host": "Lucas Martins", "chat": "__CHAT__", "items": "__MENU__",
   "target": "Baú do tesouro",
   "target_title": "🚪 O Portal fica junto do Baú",
   "target_body": "Toque em Baú do tesouro: na tela que abre, a aba Portal fica ao lado da aba Baú de Tesouros.",
   "done_text": "✨ Isso! O Portal é a aba ao lado ↓"},

  {"type": "compare", "label": "O que é o Portal?", "title": "Baú x Portal",
   "intro": "O Portal ajuda a levar sua ação para espectadores que estão em outras LIVEs.",
   "items": [
     {"emoji": "🎁", "title": "Baú", "goal": "Quem já está aqui.", "steps": "Sua LIVE | 👥👥👥"},
     {"emoji": "🚪", "title": "Portal", "goal": "Pessoas que estão em outras LIVEs.", "steps": "LIVE A 👥👥👥 | 🚪 Portal | Sua LIVE 👥👥👥👥"}
   ]},

  {"type": "tiktok_sheet", "title": "A aba Portal", "intro": "Cada card mostra uma estimativa. Toque para entender e envie para ver o caminho de quem chega.",
   "host": "Lucas Martins", "tabs": "Baú de Tesouros|Portal", "tab_active": "1", "corner": "icons",
   "tab_explain": "Esta é a aba do Baú de Tesouros, que vimos na Parte 1.",
   "section": "Espectadores", "section_action": "Personalizar ✎",
   "elements": [
     {"kind": "option", "icon": "people", "left": "533 espectadores", "sub": "Baú de Tesouros: 120 Moedas\nPara alcançar os espectadores: 80 Moedas", "coins": "200", "selected": "sim",
      "explain_title": "👥 Espectadores (estimativa)",
      "explain": "Cada opção mostra quantos espectadores o Portal pode alcançar e como as Moedas se dividem entre o Baú e o alcance.\n\nSão exemplos da interface de referência — não existe uma fórmula fixa, e estimativa não é garantia de resultado."},
     {"kind": "option", "icon": "people", "left": "2.667 espectadores", "sub": "Baú de Tesouros: 600 Moedas\nPara alcançar os espectadores: 400 Moedas", "coins": "1000"}
   ],
   "terms": "Ao tocar em \"Enviar\", você aceita os Termos do Portal e os Termos do Baú de Tesouros.", "button": "Enviar",
   "send_title": "PORTAL ATIVADO",
   "send_steps": [
     {"emoji": "📺", "label": "Pessoas em outras LIVEs veem o Portal"},
     {"emoji": "👆", "label": "Alguém toca e entra"},
     {"emoji": "👋", "label": "A pessoa chega na sua LIVE"},
     {"emoji": "🎁", "label": "E participa da ação"}
   ],
   "send_body": "O Portal cria uma oportunidade para novas pessoas descobrirem sua LIVE. Ele não garante seguidores, permanência nem aumento de alcance."},

  {"type": "tiktok_sheet", "title": "Personalizar o Portal", "intro": "Arraste a barra de Moedas e veja a estimativa mudar.",
   "host": "Lucas Martins", "sheet_title": "Personalizar Portal", "back": "sim", "corner": "help",
   "elements": [
     {"kind": "stat", "big_min": "500", "big_max": "2667", "label": "Espectadores alcançados (estimativa)",
      "explain_title": "📊 Estimativa de alcance",
      "explain": "O TikTok pode mostrar uma estimativa de quantas pessoas o Portal alcança e de quantas entram na sua LIVE. Estimativas não representam garantia de resultado."},
     {"kind": "pair", "label": "Espectadores entraram (estimativa)", "value": "10 - 40"},
     {"kind": "slider", "label": "Todas de Moedas", "min": "200", "max": "1000",
      "note": "Simulação ilustrativa: os números reais aparecem na tela do TikTok.",
      "explain_title": "🪙 Moedas do Portal",
      "explain": "Você escolhe quantas Moedas usar e a tela do TikTok atualiza a estimativa. Aqui é só uma simulação para entender a ideia."}
   ],
   "terms": "Ao tocar em \"Enviar\", você aceita os Termos do Portal e os Termos do Baú de Tesouros.", "button": "Enviar"},

  {"type": "feed", "label": "Chegou alguém", "title": "👀 Uma nova pessoa acabou de chegar", "button": "Ver a chegada",
   "items": [
     {"user": "@novo_espectador", "text": "entrou na LIVE pelo Portal", "emoji": "🚪"},
     {"user": "@lucasmartins.live", "text": "seja bem-vindo! bora participar? 🎉", "emoji": "💬"}
   ],
   "body": "O objetivo é criar uma oportunidade para novas pessoas descobrirem sua LIVE."},

  {"type": "flow", "title": "⚠️ O Portal pode trazer a pessoa. Você precisa dar um motivo para ela ficar.",
   "items": [
     {"emoji": "🚪", "label": "Entrada", "body": ""},
     {"emoji": "👀", "label": "A pessoa chegou", "body": ""},
     {"emoji": "🎤", "label": "Algo interessante acontecendo", "body": ""},
     {"emoji": "❤️", "label": "Interação", "body": ""},
     {"emoji": "👥", "label": "Possibilidade de permanecer", "body": "Se a pessoa entra só pela recompensa e não encontra nada interessante acontecendo, ela pode sair rapidamente."}
   ]},

  {"type": "tip", "body": "Se usar o Portal, prepare um momento especial para quem chegar: começar uma música, um desafio, uma conversa, uma Batalha ou uma dinâmica que já esteja acontecendo."},

  {"type": "text", "label": "Parte 3", "title": "🛍️ Sacola de Prêmios", "body": "De volta ao menu ⋯."},

  {"type": "live_menu", "title": "Onde fica a Sacola?", "intro": "Abra o menu e encontre a Sacola de Prêmios.",
   "host": "Lucas Martins", "chat": "__CHAT__", "items": "__MENU__",
   "target": "Sacola de Prêmios",
   "target_title": "🛍️ Sacola de Prêmios",
   "target_body": "A Sacola de Prêmios fica no menu ⋯. Ao tocar, abre a tela de configuração.",
   "done_text": "✨ Achou a Sacola! Continue ↓"},

  {"type": "platform", "title": "🛍️ O que é a Sacola de Prêmios?", "varies": true,
   "body": "A Sacola permite criar uma ação de participação com recompensas e critérios definidos dentro das opções disponíveis no TikTok.\n\n🎁 Baú: distribuição simples de recompensa.\n🚪 Portal: alcançar pessoas de outras LIVEs.\n🛍️ Sacola: ação configurável para a participação da comunidade."},

  {"type": "tiktok_sheet", "title": "A tela da Sacola", "intro": "Toque em cada linha para entender. Depois envie.",
   "host": "Lucas Martins", "sheet_title": "Sacola de Prêmios", "corner": "help",
   "elements": [
     {"kind": "row", "label": "Todas de Moedas", "value": "10",
      "explain_title": "🪙 Moedas", "explain": "Define a quantidade total de Moedas usada nessa ação, conforme as opções disponíveis. O 10 é só o exemplo da tela — não é um mínimo universal."},
     {"kind": "row", "label": "Ganhadores", "value": "5",
      "explain_title": "👥 Ganhadores", "explain": "Define quantas pessoas poderão receber a recompensa, conforme as opções disponíveis."},
     {"kind": "row", "label": "Quem pode participar", "value": "Nível mínimo de membro 1",
      "explain_title": "🎟️ Quem pode participar", "explain": "Aqui você escolhe entre todos os espectadores ou um nível mínimo de fãs/membros. Veja a tela logo abaixo ↓"},
     {"kind": "row", "label": "Como participar", "value": "Enviar este comentário",
      "explain_title": "✅ Como participar", "explain": "Define o que o espectador precisa fazer para participar. Veja as opções logo abaixo ↓"},
     {"kind": "comment", "label": "lucas 🐸",
      "explain_title": "💬 Comentário configurado", "explain": "É o comentário que o espectador envia para participar. O texto é só um exemplo — você escolhe o seu."}
   ],
   "terms": "Ao continuar, você aceita os Termos da Sacola de Prêmios.", "button": "Enviar",
   "send_title": "DEPOIS DE ENVIAR",
   "send_steps": [
     {"emoji": "🛍️", "label": "A Sacola aparece na LIVE"},
     {"emoji": "👥", "label": "Os espectadores elegíveis participam"},
     {"emoji": "🎲", "label": "Distribuição"},
     {"emoji": "🏆", "label": "Os ganhadores recebem a recompensa"}
   ],
   "rewards": "5",
   "send_body": "A distribuição acontece conforme as regras e condições configuradas no recurso."},

  {"type": "tiktok_sheet", "title": "Quem pode participar?", "intro": "Escolha uma opção e um nível.",
   "host": "Lucas Martins", "sheet_title": "Quem pode participar", "corner": "close",
   "elements": [
     {"kind": "radio", "label": "Todos os espectadores",
      "explain_title": "👥 Todos os espectadores", "explain": "Qualquer espectador pode participar, sem requisito de nível."},
     {"kind": "radio", "label": "Nível mínimo de fãs", "selected": "sim",
      "explain_title": "⭐ Nível mínimo de fãs",
      "explain": "Quando essa opção estiver disponível, você define um nível mínimo de fãs/membros: só participa quem atende ao requisito. Nem toda conta tem essa configuração."},
     {"kind": "chips", "options": "Nv.1, Nv.3, Nv.5, Nv.10", "selected": "0",
      "explain_title": "🎚️ Nível", "explain": "Escolha o nível mínimo exigido. Nenhum nível é obrigatório: você decide dentro das opções disponíveis."},
     {"kind": "note", "label": "No momento, 0 membros podem participar desta Sacola de Prêmios."}
   ],
   "button": "Confirmar"},

  {"type": "tiktok_sheet", "title": "Como participar?", "intro": "Toque em cada forma de participação.",
   "host": "Lucas Martins", "sheet_title": "Como participar", "corner": "close",
   "elements": [
     {"kind": "radio", "label": "Enviar este comentário", "selected": "sim",
      "explain_title": "💬 Enviar este comentário", "explain": "O criador configura um comentário específico que o espectador precisa enviar, quando essa opção estiver disponível."},
     {"kind": "radio", "label": "Compartilhar esta LIVE",
      "explain_title": "↗️ Compartilhar esta LIVE", "explain": "A participação fica vinculada ao compartilhamento da LIVE, quando essa opção estiver disponível."},
     {"kind": "radio", "label": "Sem requisitos",
      "explain_title": "○ Sem requisitos", "explain": "Permite participar sem uma condição adicional, quando essa opção estiver disponível."}
   ],
   "button": "Confirmar"},

  {"type": "discover", "title": "🦆 Como usar a Sacola estrategicamente",
   "items": [
     {"emoji": "🎲", "title": "Dinâmica", "body": "Uma atividade com começo, meio e fim durante a LIVE."},
     {"emoji": "🎉", "title": "Brincadeira", "body": "Algo leve para a audiência participar junto."},
     {"emoji": "👥", "title": "Comunidade", "body": "Um momento para quem acompanha você sempre."},
     {"emoji": "🎯", "title": "Meta", "body": "Uma recompensa ligada a um objetivo da LIVE."}
   ]},

  {"type": "example", "title": "Exemplo de fala",
   "body": "“Hoje vamos fazer uma dinâmica: quem participar da atividade poderá concorrer à Sacola.”"},

  {"type": "platform", "title": "💜 E o Heart Me / clube de fãs?", "varies": true,
   "body": "Se o Heart Me ou o clube de fãs estiver disponível na sua conta, recursos de comunidade podem ajudar a incentivar a participação.\n\nA Sacola não exige Heart Me automaticamente: se a tela pedir um nível mínimo de fãs/membros, vale exatamente o que estiver configurado ali."},

  {"type": "strategy", "title": "⭐ Baú de Superfã",
   "body": "O TikTok também pode apresentar recursos de recompensa direcionados a fãs/superfãs, dependendo da disponibilidade da conta e da região. Saiba mais futuramente →"},

  {"type": "compare", "label": "Comparação final", "title": "Qual usar?",
   "intro": "Toque em cada recurso.",
   "items": [
     {"emoji": "🎁", "title": "Baú", "goal": "Movimentar quem já está na sua LIVE.", "steps": "🎁 Baú | 👥 quem já está aqui", "question": "Como posso criar uma ação para quem já está aqui?"},
     {"emoji": "🚪", "title": "Portal", "goal": "Alcançar pessoas que estão em outras LIVEs.", "steps": "🚪 Portal | 👥 pessoas de outras LIVEs", "question": "Como posso criar uma oportunidade para novas pessoas chegarem?"},
     {"emoji": "🛍️", "title": "Sacola", "goal": "Criar uma ação com condições de participação.", "steps": "🛍️ Sacola | 👥 comunidade + regras", "question": "Como posso criar uma dinâmica para minha comunidade?"}
   ],
   "footer": "Três ferramentas. Três objetivos diferentes."},

  {"type": "quiz", "question": "Você quer criar uma ação para quem já está na sua LIVE. Qual recurso faz mais sentido?",
   "options": ["Portal", "Baú", "Sacola"], "correct": 1,
   "explanation": "O Baú é pensado para movimentar quem já está na sua LIVE."},
  {"type": "quiz", "question": "Você quer criar uma ação que alcance pessoas que estão em outras LIVEs.",
   "options": ["Portal", "Baú", "Galeria"], "correct": 0,
   "explanation": "O Portal leva a sua ação para espectadores de outras LIVEs."},
  {"type": "quiz", "question": "Você quer configurar condições como quem pode participar e como participar.",
   "options": ["Portal", "Baú", "Sacola"], "correct": 2,
   "explanation": "Na Sacola você define quem pode participar e como participar, dentro das opções disponíveis."},

  {"type": "tip", "body": "A ferramenta é só o começo. O que importa é o que você faz com ela.\n🎁 Baú: crie um momento.\n🚪 Portal: prepare algo interessante para quem chegar.\n🛍️ Sacola: crie uma dinâmica para sua comunidade."},

  {"type": "text", "label": "Cuidado com Moedas",
   "body": "Moedas são itens virtuais do TikTok, e o valor usado é descontado do saldo da conta. Use recursos que envolvem Moedas com responsabilidade e dentro do seu orçamento."},

  {"type": "recap", "title": "🎉 Agora você entende:",
   "items": [
     "Onde encontrar o Baú",
     "Como configurar o Baú",
     "Como funciona a distribuição",
     "Para que serve o Portal",
     "Como o Portal pode trazer novas pessoas",
     "Por que é importante ter algo acontecendo quando elas chegam",
     "Onde encontrar a Sacola",
     "Como configurar Moedas e ganhadores",
     "Como definir quem pode participar",
     "Como definir a forma de participação",
     "Como usar cada recurso de maneira estratégica"
   ]}
]
$json$::jsonb;

  -- menu e chat repetidos nas 3 partes
  v_blocks := (
    select jsonb_agg(
      case when b->>'type' = 'live_menu' then b || jsonb_build_object('items', v_menu, 'chat', v_chat) else b end
      order by i)
    from jsonb_array_elements(v_blocks) with ordinality as x(b, i));

  for a in select distinct agency_id from academy_categories where slug = 'recursos' loop
    if not exists (select 1 from academy_lessons where agency_id = a.agency_id and slug = 'aula-02-bau-portal-sacola') then
      insert into academy_lessons (agency_id, slug, category_id, subcategory, title, subtitle, audience, level,
        blocks, availability, status, sort_order, duration_min, tags, sources, info_status)
      values (a.agency_id, 'aula-02-bau-portal-sacola',
        (select id from academy_categories where agency_id = a.agency_id and slug = 'recursos'),
        'Aula interativa',
        '🎁 Baú, Portal e Sacola de Prêmios',
        'Onde encontrar, como configurar e quando usar cada recurso da LIVE.',
        array['todos'], 'iniciante',
        v_blocks, 'disponivel', 'revisao', -9, 8,
        array['baú', 'portal', 'sacola', 'moedas', 'recursos', 'interativa'],
        jsonb_build_array(jsonb_build_object(
          'title', 'Interface do TikTok LIVE observada em 07/10/2026 (menu ⋯, Baú de Tesouros, Portal, Sacola de Prêmios). Valores ilustrativos; podem variar por conta, região e versão. Sem página oficial detalhada localizada — revisar quando houver.',
          'url', null, 'consulted_at', '2026-10-07')),
        'revisar');
    end if;
  end loop;
end $$;

-- conta de teste vê a aula em revisão
insert into academy_access_grants (lesson_id, profile_id)
select l.id, p.id from academy_lessons l
join profiles p on p.agency_id = l.agency_id and lower(ltrim(p.tiktok_username, '@')) = 'gidreams_'
where l.slug = 'aula-02-bau-portal-sacola'
on conflict do nothing;

select title, status, jsonb_array_length(blocks) as blocos
from academy_lessons where slug = 'aula-02-bau-portal-sacola';

-- Para liberar para todos depois de aprovar:
-- update academy_lessons set status = 'publicado' where slug = 'aula-02-bau-portal-sacola';
