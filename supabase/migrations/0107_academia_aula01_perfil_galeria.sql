-- ============================================================================
-- Academia MDuck · AULA 01 — Perfil, Liga e Galeria de Presentes
-- Primeira aula no novo modelo interativo (blocos tiktok_profile,
-- league_ladder, gift_gallery, feed, recap). Nomes, @ e fotos sao ficticios.
-- Entra como "Em revisao": so a equipe ve (no app e no "Visualizar como").
-- Depois de aprovar, mude o status para Publicado no painel.
-- Nao mexe em nenhuma outra aula. Idempotente (pelo slug).
-- Rode manualmente no SQL Editor do Supabase.
-- ============================================================================

do $$
declare
  v_blocks jsonb := $json$
[
  {"type": "text", "label": "Aula interativa",
   "body": "Aqui você aprende explorando a tela. Toque nos elementos destacados para entender cada parte e siga em frente quando quiser."},

  {"type": "tiktok_profile",
   "title": "Você está em uma Batalha",
   "intro": "Dois criadores estão em Batalha. Toque no perfil de um dos participantes para abrir.",
   "tap_hint_text": "Toque no perfil (no alto, à esquerda) para abrir.",
   "name": "Lucas Martins", "handle": "lucasmartins.live", "avatar_url": "",
   "bio": "🎤 Live streamer | Música & Batalhas\n🎙️ Lives de segunda a sábado\n🦆 MDuck Agency",
   "followers": "128 mil", "following": "312",
   "league": "A1", "league_rank": "Nº 7", "community": "1.240", "gifter_level": "45",
   "opponent": "Rafa Souza", "score_left": "4.542", "score_right": "5.027", "timer": "04:28", "viewers": "3.5K",
   "spots": {
     "perfil": {"title": "Nome e @",
       "body": "O nome identifica o perfil. O @ é o identificador da conta.",
       "tip": "Uma bio clara ajuda quem chega na sua LIVE a entender rapidamente quem você é e o que você faz."},
     "livepro": {"title": "✨ LIVE Pro",
       "body": "LIVE Pro é uma forma de reconhecimento/certificação relacionada a criadores do TikTok LIVE que atendem aos critérios do programa.\n\nNem toda pessoa que faz LIVE é LIVE Pro, e nenhum número de seguidores garante esse reconhecimento. Os critérios são definidos pelo TikTok.",
       "tip": "Independentemente de selos ou reconhecimentos, o objetivo é construir uma LIVE consistente, criativa e com uma comunidade que queira voltar."},
     "bio": {"title": "Uma bio que explica quem você é",
       "body": "Use sua bio para deixar claro seu conteúdo, sua rotina ou outras informações que façam sentido para sua comunidade.\n\nNo exemplo: o que faz (música e batalhas), quando faz LIVE (segunda a sábado) e de onde faz parte. Citar a MDuck não é obrigatório — é só uma forma de organizar.",
       "tip": ""},
     "liga": {"title": "🏆 O que é a Liga?",
       "body": "A Liga faz parte do sistema competitivo do TikTok LIVE e organiza os criadores em diferentes classes. Neste exemplo, o perfil está na classe A1.\n\nLogo abaixo você explora a sequência completa, do D5 ao A1.",
       "tip": ""},
     "comunidade": {"title": "👥 Comunidade",
       "body": "Este indicador apresenta uma informação relacionada à comunidade do criador e ajuda a visualizar a dimensão da audiência construída ao redor da LIVE.",
       "tip": "Mais importante do que o número é construir pessoas que tenham vontade de voltar para a sua próxima LIVE."},
     "nivel": {"title": "🎁 Nível de presenteador",
       "body": "Esse nível está relacionado ao histórico de participação da conta como presenteadora, incluindo o envio de Presentes durante as experiências do TikTok.\n\nÀ medida que uma pessoa participa enviando Presentes, ela pode avançar no sistema de níveis de presenteador.",
       "tip": ""},
     "galeria": {"title": "🎁 Galeria de Presentes",
       "body": "A Galeria de Presentes mostra uma coleção de Presentes do criador e quem participou enviando cada um. Vamos abrir e explorar?",
       "action": "Abrir a Galeria 🎁", "tip": ""}
   }},

  {"type": "league_ladder", "label": "A Liga",
   "title": "Do D5 ao A1",
   "intro": "Toque em cada faixa para entender. Toque no 🏆 A1 para ver o topo.",
   "groups": [
     {"letter": "D", "tiers": "D5, D4, D3, D2, D1", "body": "Classes iniciais da estrutura."},
     {"letter": "C", "tiers": "C5, C4, C3, C2, C1", "body": "Faixa seguinte da progressão."},
     {"letter": "B", "tiers": "B5, B4, B3, B2, B1", "body": "Faixa avançada."},
     {"letter": "A", "tiers": "A3, A2, A1", "body": "Faixa superior."}
   ],
   "top": "A1", "top_title": "🏆 A1",
   "top_body": "É a classe mais alta dessa estrutura: A1 é o topo dessa sequência de classes.",
   "note": "As regras e critérios do sistema podem ser atualizados pelo TikTok."},

  {"type": "gift_gallery", "label": "Galeria de Presentes",
   "title": "Explore a Galeria A1",
   "intro": "Esta é uma recriação da Galeria de Presentes de um perfil em A1. Os Presentes iluminados já foram registrados neste ciclo.",
   "owner": "Lucas Martins", "league": "A1", "total": "20",
   "hint": "👆 Toque em um Presente para entender.",
   "gifts": [
     {"emoji": "🌌", "name": "TikTok Universe", "user": "@gabriel_live", "lit": "sim", "image_url": "asset:academy/gifts/tiktok_universe.png", "body": ""},
     {"emoji": "🦁", "name": "Leon e Lion", "user": "@ana_live", "lit": "sim", "image_url": "asset:academy/gifts/leon_e_lion.png", "body": ""},
     {"emoji": "🦁", "name": "Leão", "user": "@bruno_live", "lit": "sim", "image_url": "asset:academy/gifts/leao.png", "body": ""},
     {"emoji": "🪩", "name": "Festa sem parar", "user": "@mari.oficial", "lit": "sim", "image_url": "", "body": ""},
     {"emoji": "🪐", "name": "Planeta maravilhoso", "user": "@joaopedro", "lit": "sim", "image_url": "asset:academy/gifts/planeta_maravilhoso.png", "body": ""},
     {"emoji": "🌆", "name": "Cidade do futuro", "user": "@camila_s", "lit": "sim", "image_url": "asset:academy/gifts/cidade_do_futuro.png", "body": ""},
     {"emoji": "✈️", "name": "Jatos Voadores", "user": "@theo.games", "lit": "sim", "image_url": "asset:academy/gifts/jatos_voadores.png", "body": ""},
     {"emoji": "🐱", "name": "Leon, o gatinho", "user": "@gabriel_live", "lit": "não", "image_url": "asset:academy/gifts/leon_o_gatinho.png", "body": ""},
     {"emoji": "🐋", "name": "Mergulho com baleia", "user": "@ana_live", "lit": "não", "image_url": "asset:academy/gifts/mergulho_com_baleia.png", "body": ""}
   ],
   "gift_body": "Este é um exemplo de Presente que pode aparecer em uma Galeria de uma Liga alta.",
   "unlit_body": "Este Presente ainda não foi registrado neste ciclo da Galeria.",
   "sender_title": "👤 Quem enviou?",
   "sender_body": "A Galeria pode mostrar a pessoa associada à contribuição daquele Presente. A participação da audiência fica visível e reconhecível.",
   "sender_tip": "Reconheça quem participa da sua Galeria. Um simples agradecimento pode transformar uma contribuição em um momento de conexão.",
   "demo_button": "Ver a Galeria sendo iluminada",
   "lit_title": "✨ Galeria iluminada",
   "lit_body": "A iluminação representa o progresso da Galeria conforme os Presentes são registrados, de acordo com as regras da experiência."},

  {"type": "discover", "title": "A Galeria muda conforme a Liga",
   "items": [
     {"emoji": "🩶", "title": "D", "body": "Galeria de nível inicial."},
     {"emoji": "💚", "title": "C", "body": "Galeria intermediária."},
     {"emoji": "💙", "title": "B", "body": "Galeria avançada."},
     {"emoji": "💛", "title": "A", "body": "Galeria superior."}
   ]},
  {"type": "text", "label": "Importante",
   "body": "A composição da Galeria pode variar de acordo com a Liga. Isso não quer dizer que todos os Presentes de uma Liga sejam necessariamente os maiores da plataforma."},

  {"type": "discover", "title": "🎯 Por que completar a Galeria?",
   "items": [
     {"emoji": "🎯", "title": "Meta", "body": "Cria um objetivo para a semana."},
     {"emoji": "👥", "title": "Participação", "body": "A audiência pode participar."},
     {"emoji": "🏆", "title": "Competição", "body": "Pode existir uma disputa entre participantes."},
     {"emoji": "👤", "title": "Reconhecimento", "body": "A contribuição fica associada ao participante na interface."}
   ]},

  {"type": "flow", "title": "A Galeria funciona em ciclos",
   "items": [
     {"emoji": "🌅", "label": "Início do ciclo", "body": "A Galeria começa novamente. O período exato é definido pelo TikTok e pode mudar."},
     {"emoji": "👥", "label": "Durante o ciclo", "body": "A comunidade participa."},
     {"emoji": "✨", "label": "Galeria sendo iluminada", "body": "Os Presentes vão sendo registrados."},
     {"emoji": "🏁", "label": "Final do ciclo", "body": "Resultado do período."},
     {"emoji": "🔄", "label": "Novo ciclo", "body": "Uma nova Galeria começa."}
   ]},

  {"type": "feed", "label": "Disputa pela Galeria", "title": "Uma disputa amigável",
   "button": "Ver a disputa",
   "items": [
     {"user": "@ana_live", "text": "enviou um Presente", "emoji": "🎁"},
     {"user": "@bruno_live", "text": "participou também", "emoji": "✨"},
     {"user": "@ana_live", "text": "voltou a participar", "emoji": "💜"}
   ],
   "body": "Mais de uma pessoa pode participar da Galeria, criando uma dinâmica de competição e reconhecimento durante o ciclo."},

  {"type": "flow", "title": "🦆 Como aproveitar a Galeria na sua LIVE",
   "items": [
     {"emoji": "📣", "label": "Antes", "body": "Mostre que a Galeria existe."},
     {"emoji": "💬", "label": "Durante", "body": "Comente o progresso."},
     {"emoji": "🙌", "label": "Quando alguém participar", "body": "Reconheça a pessoa."},
     {"emoji": "⏳", "label": "Quando a Galeria estiver quase completa", "body": "Crie expectativa."},
     {"emoji": "🏁", "label": "No final do ciclo", "body": "Mostre o resultado."},
     {"emoji": "🔄", "label": "Novo ciclo", "body": "Comece novamente."}
   ]},

  {"type": "example", "title": "Exemplo de fala",
   "body": "“Olha só, falta esse presente para completar essa parte da nossa Galeria. Quem participar vai aparecer aqui junto com o Presente.”"},

  {"type": "tip",
   "body": "Não trate a Galeria apenas como uma lista de Presentes. Transforme ela em uma atividade da comunidade: mostre o progresso, reconheça quem participa e crie momentos divertidos durante a LIVE."},

  {"type": "quiz",
   "question": "Para que serve entender a Galeria de Presentes?",
   "options": [
     "Para saber quais Presentes aparecem e entender a participação da audiência.",
     "Para garantir automaticamente mais seguidores.",
     "Para subir automaticamente de Liga."
   ],
   "correct": 0,
   "explanation": "A Galeria é uma experiência de participação e reconhecimento dentro da LIVE. Ela não garante automaticamente seguidores ou promoção de Liga."},

  {"type": "recap", "title": "🎉 Agora você já sabe:",
   "items": [
     "Como abrir o perfil de um participante",
     "O que significam os principais elementos do perfil",
     "O que é a Liga",
     "Como visualizar a progressão D → C → B → A",
     "O que representa a Comunidade",
     "O que é o nível de presenteador",
     "Onde encontrar a Galeria de Presentes",
     "Como os Presentes aparecem na Galeria",
     "Como identificar quem participou",
     "Por que a Galeria pode ser uma dinâmica de comunidade",
     "Como aproveitar a Galeria durante a LIVE"
   ]}
]
$json$::jsonb;
  v_sources jsonb := jsonb_build_array(jsonb_build_object(
    'title', 'Observação da interface do TikTok LIVE (perfil na Batalha e Galeria de Presentes). Não localizamos página oficial do TikTok detalhando Liga, LIVE Pro ou Galeria — revisar quando houver.',
    'url', null,
    'consulted_at', '2026-10-07'));
  a record;
begin
  for a in select distinct agency_id from academy_categories where slug = 'recursos' loop
    if not exists (select 1 from academy_lessons where agency_id = a.agency_id and slug = 'aula-01-perfil-liga-galeria') then
      insert into academy_lessons (agency_id, slug, category_id, subcategory, title, subtitle, audience, level,
        blocks, availability, status, sort_order, duration_min, tags, sources, info_status)
      values (a.agency_id, 'aula-01-perfil-liga-galeria',
        (select id from academy_categories where agency_id = a.agency_id and slug = 'recursos'),
        'Aula interativa',
        '🎁 Perfil e Galeria de Presentes',
        'Entenda o que aparece no perfil de um criador durante uma LIVE e descubra como funciona a Galeria de Presentes.',
        array['todos'], 'iniciante',
        v_blocks, 'disponivel', 'revisao', -10, 6,
        array['perfil', 'liga', 'galeria', 'presentes', 'interativa'],
        v_sources, 'revisar');
    end if;
  end loop;
end $$;

select title, status, availability, jsonb_array_length(blocks) as blocos
from academy_lessons where slug = 'aula-01-perfil-liga-galeria';
