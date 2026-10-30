-- ============================================================================
-- Academia MDuck · AULA — Missões de Batalha
-- Blocos: battle_sim (batalha animada), multiplier, tap_tap + comuns.
-- Streamers, @ e chat fictícios; números ilustrativos (editáveis no painel).
-- Entra "Em revisão", liberada só para a conta de teste @gidreams_.
-- Não mexe em outras aulas. Idempotente (pelo slug).
-- ============================================================================

do $$
declare
  v_blocks jsonb := $json$
[
  {"type": "text", "label": "Aula interativa",
   "body": "Aqui você aprende vendo a batalha acontecer. Toque em Próximo › para avançar ou em ▶ Assistir para ver tudo seguido."},

  {"type": "battle_sim", "title": "Você está em uma batalha",
   "left_name": "@LucasLive", "right_name": "@RafaBattle", "left_wins": "3", "right_wins": "0",
   "steps": [
     {"timer": "05:00", "left": "0", "right": "0",
      "caption": "Dois streamers em batalha: @LucasLive (rosa) e @RafaBattle (azul). O placar no topo mostra os pontos de cada lado."},
     {"timer": "04:41", "left": "1240", "right": "980", "chat": "@ana_live: bora Lucas!! | @bruno_live: 🌹🌹",
      "caption": "Presentes e Tap Tap do público viram pontos. Quem tiver mais pontos quando o cronômetro zerar vence."},
     {"timer": "04:30", "left": "1240", "right": "980",
      "caption": "No alto de cada lado aparecem as vitórias seguidas (WIN). Quem perde uma batalha volta para WIN x0."}
   ]},

  {"type": "platform", "title": "🎯 Missões de Batalha", "varies": true,
   "body": "Durante algumas batalhas, podem aparecer missões temporárias que alteram a pontuação de determinados presentes ou ações por um período.\n\nAs missões são dinâmicas e não necessariamente aparecem em todas as batalhas da mesma forma. O streamer não escolhe quando uma missão vai aparecer."},

  {"type": "battle_sim", "label": "Missão 1", "title": "Primeiro presente x2 ou x3",
   "left_name": "@LucasLive", "right_name": "@RafaBattle", "left_wins": "3", "right_wins": "0",
   "steps": [
     {"timer": "04:58", "left": "0", "right": "0", "banner": "first", "banner_sub": "x3 pontos de presente", "seconds": "26",
      "caption": "No começo de algumas batalhas aparece: PRIMEIRO PRESENTE — x3 pontos de presente, com o tempo correndo."},
     {"timer": "04:58", "left": "0", "right": "0", "banner": "first", "banner_sub": "x2 pontos de presente", "seconds": "26",
      "caption": "O multiplicador pode ser x2 ou x3."},
     {"timer": "04:52", "left": "3", "right": "0", "banner": "first", "banner_sub": "x3 pontos de presente", "seconds": "20",
      "gift": "🌹", "calc": "1 × 3 = 3 pontos",
      "caption": "O primeiro presente enviado por aquela pessoa durante a missão vale o multiplicador indicado na pontuação da batalha."}
   ]},

  {"type": "multiplier", "label": "Exemplo", "title": "Com a Rosa fica fácil",
   "intro": "Toque em x2 ou x3.",
   "multipliers": "2,3",
   "gifts": [
     {"emoji": "🌹", "name": "Rosa", "points": "1"},
     {"emoji": "🎁", "name": "Presente de 100 pontos", "points": "100"}
   ],
   "note": "O multiplicador vale para a pontuação da batalha."},

  {"type": "battle_sim", "title": "Do presente ao placar",
   "left_name": "@LucasLive", "right_name": "@RafaBattle", "left_wins": "3", "right_wins": "0",
   "steps": [
     {"timer": "04:20", "left": "500", "right": "900", "banner": "first", "banner_sub": "x2 pontos de presente", "seconds": "14",
      "gift": "🎁", "caption": "1. PRESENTE ENVIADO — um presente de 100 pontos."},
     {"timer": "04:19", "left": "500", "right": "900", "banner": "first", "banner_sub": "x2 pontos de presente", "seconds": "13",
      "calc": "100 × 2 = 200 pontos", "caption": "2. MULTIPLICADOR APLICADO — a missão está em x2."},
     {"timer": "04:18", "left": "700", "right": "900", "banner": "first", "banner_sub": "x2 pontos de presente", "seconds": "12",
      "caption": "3. PONTUAÇÃO SUBINDO — +200 no placar da batalha."}
   ]},

  {"type": "tap_tap", "title": "👆 Tap Tap", "points": "3",
   "intro": "Cada pessoa que curte (Tap Tap) soma 3 pontos na batalha — só uma vez por batalha, não acumula.",
   "hint": "Toque várias vezes aqui!",
   "warning": "Mesmo assim, incentive todo mundo a curtir desde o começo da batalha e continuar curtindo: as curtidas aumentam o total de likes da LIVE e ajudam no engajamento. Tap Tap não é presente nem monetização."},

  {"type": "flow", "title": "Como os presentes viram pontos?",
   "items": [
     {"emoji": "🎁", "label": "Presente", "body": "Alguém do público envia um presente."},
     {"emoji": "💎", "label": "Valor do presente", "body": "Rosa = 1 ponto · presente de 100 = 100 pontos."},
     {"emoji": "✖️", "label": "Multiplicador da missão", "body": "x2: 100 × 2 = 200 · x3: 100 × 3 = 300."},
     {"emoji": "📈", "label": "Pontos na batalha", "body": "O resultado entra no placar."}
   ]},

  {"type": "strategy", "icon": "⚠️", "title": "Pontuação não é o mesmo que ganho 💵",
   "body": "O x2 ou x3 da missão aumenta a pontuação da batalha. Isso não significa que o streamer recebe o dobro ou o triplo em ganhos.\n\nEx.: um presente de 100 pontos numa missão x3 pode valer 300 pontos na batalha — mas o ganho continua relacionado ao presente efetivamente enviado. Tap Tap também é só pontuação.\n\n“O multiplicador aumenta a pontuação da batalha — não multiplica o ganho do presente.”"},

  {"type": "battle_sim", "label": "Missão 2", "title": "Missões bônus",
   "left_name": "@LucasLive", "right_name": "@RafaBattle", "left_wins": "3", "right_wins": "0",
   "steps": [
     {"timer": "03:10", "left": "2100", "right": "2400", "banner": "progress", "progress": "0/200", "progress_icon": "🎁", "seconds": "58",
      "caption": "Durante a batalha pode aparecer uma missão bônus com uma condição para desbloquear. Neste exemplo: chegar a 200 em presentes."},
     {"timer": "03:02", "left": "2200", "right": "2400", "banner": "progress", "progress": "100/200", "progress_icon": "🎁", "seconds": "50", "gift": "🌹", "gift_from": "@camila_s",
      "caption": "Os presentes enviados vão enchendo a barra."},
     {"timer": "02:55", "left": "2300", "right": "2450", "banner": "progress", "progress": "200/200", "progress_icon": "🎁",
      "caption": "Condição alcançada ✓"},
     {"timer": "02:54", "left": "2300", "right": "2450", "banner": "unlocked", "banner_sub": "x2 pontos de presentes",
      "caption": "✨ Missão desbloqueada!"},
     {"timer": "02:53", "left": "2300", "right": "2450", "banner": "bonus", "banner_sub": "x2 pontos de presentes", "seconds": "45",
      "caption": "🔥 Bônus ativo: durante o tempo indicado, os presentes contribuem com o multiplicador para a pontuação da batalha."},
     {"timer": "01:45", "left": "3000", "right": "3100", "banner": "goal", "banner_sub": "5",
      "caption": "Outra missão: Meta de presenteador — quantas pessoas precisam enviar presentes."},
     {"timer": "01:40", "left": "3000", "right": "3100", "banner": "progress", "progress": "3/5", "progress_icon": "👥", "seconds": "58",
      "caption": "Outras missões dependem de quantas pessoas participam enviando presentes. Os números podem variar conforme a missão."},
     {"timer": "01:31", "left": "3200", "right": "3100", "banner": "progress", "progress": "5/5", "progress_icon": "👥", "seconds": "58",
      "caption": "5 pessoas ✓ — missão desbloqueada."}
   ]},

  {"type": "battle_sim", "title": "Aproveitando o bônus",
   "left_name": "@LucasLive", "right_name": "@RafaBattle", "left_wins": "3", "right_wins": "0",
   "steps": [
     {"timer": "02:30", "left": "2600", "right": "2700", "banner": "bonus", "banner_sub": "x2 pontos de presentes", "seconds": "45",
      "chat": "@LucasLive: MISSÃO ATIVA! | @ana_live: MANDA AGORA! | @camila_s: APROVEITA O DOBRO!",
      "caption": "O streamer percebe o bônus e avisa o chat na hora, mostrando o tempo restante."},
     {"timer": "02:18", "left": "3000", "right": "2700", "banner": "bonus", "banner_sub": "x2 pontos de presentes", "seconds": "33",
      "gift": "🎁", "calc": "100 × 2 = 200 pontos", "gift_from": "@bruno_live", "chat": "@bruno_live: foi! 🔥",
      "caption": "O chat participa e o placar sobe mais rápido."}
   ]},

  {"type": "tip", "body": "Quando aparecer um bônus x2 ou x3, aproveite o momento: avise o chat, mostre o tempo restante, incentive a participação e crie um momento de interação."},

  {"type": "battle_sim", "label": "Power-Ups", "title": "🥊 E a luva?",
   "left_name": "@LucasLive", "right_name": "@RafaBattle", "left_wins": "3", "right_wins": "0",
   "steps": [
     {"timer": "01:10", "left": "3400", "right": "3500", "glove": "sim", "glove_label": "x5",
      "caption": "Alguns Power-Ups podem alterar a pontuação de presentes. A luva aparece no canto superior esquerdo, embaixo da foto do streamer."},
     {"timer": "01:05", "left": "3400", "right": "3500", "glove": "sim", "glove_label": "x5", "gift": "🎁", "calc": "🎁 → 🥊 → x5",
      "caption": "Se o presente pegar na luva, ele pode virar x5 — pode pegar ou não. A aula completa de Power-Ups vem em breve."}
   ]},

  {"type": "strategy", "icon": "⚠️", "title": "Não é x2 × x5 = x10",
   "body": "A luva não acumula com a missão: se o presente pegar na luva, ele fica x5 no total — não x10.\n\nMesmo assim, vale incentivar a luva durante o x2 ou x3: o presente já tem a multiplicação garantida da missão e, com a luva, ainda tem a chance de virar x5."},

  {"type": "strategy", "icon": "❌", "title": "MITO: Rosa ou presente baixo “fura” a luva",
   "body": "Muitos streamers dizem que enviar Rosa ou presentes de valor baixo pode furar a luva. Isso é MITO.\n\nIncentive e agradeça todos os presentes que a sua comunidade enviar."},

  {"type": "battle_sim", "label": "Simulação completa", "title": "A batalha inteira", "auto_ms": "3600",
   "left_name": "@LucasLive", "right_name": "@RafaBattle", "left_wins": "3", "right_wins": "0",
   "steps": [
     {"timer": "05:00", "left": "0", "right": "0", "caption": "⚔️ Dois streamers entram em batalha."},
     {"timer": "04:59", "left": "0", "right": "0", "caption": "⏱️ O cronômetro começa."},
     {"timer": "04:58", "left": "0", "right": "0", "banner": "first", "banner_sub": "x3 pontos de presente", "seconds": "26",
      "caption": "🎁 Surge a missão: PRIMEIRO PRESENTE x3."},
     {"timer": "04:52", "left": "3", "right": "0", "banner": "first", "banner_sub": "x3 pontos de presente", "seconds": "20", "gift": "🌹", "calc": "1 × 3 = 3 pontos",
      "caption": "👤 Um espectador envia uma Rosa: 1 × 3 = 3 pontos."},
     {"timer": "04:20", "left": "3", "right": "40", "taps": "sim", "tap_points": "3", "chat": "@ana_live: tap tap tap!!",
      "caption": "👆 O chat começa a curtir (Tap Tap): cada pessoa soma 3 pontos uma vez na batalha, e as curtidas continuam aumentando os likes da LIVE."},
     {"timer": "03:30", "left": "900", "right": "1100", "gift": "🌹", "gift_from": "@bruno_live", "caption": "🌹 Outros presentes são enviados."},
     {"timer": "02:40", "left": "1200", "right": "1400", "banner": "progress", "progress": "2/5", "progress_icon": "👥", "seconds": "58",
      "caption": "🔥 Uma missão bônus aparece."},
     {"timer": "02:31", "left": "1350", "right": "1450", "banner": "progress", "progress": "5/5", "progress_icon": "👥", "seconds": "58",
      "caption": "👥 O chat atinge a condição."},
     {"timer": "02:30", "left": "1350", "right": "1450", "banner": "unlocked", "banner_sub": "x2 pontos de presentes", "caption": "✨ Missão desbloqueada."},
     {"timer": "02:29", "left": "1350", "right": "1450", "banner": "bonus", "banner_sub": "x2 pontos de presentes", "seconds": "45",
      "caption": "⏱️ Começa o bônus: x2 por 45 segundos."},
     {"timer": "02:14", "left": "1750", "right": "1600", "banner": "bonus", "banner_sub": "x2 pontos de presentes", "seconds": "30", "gift": "🎁", "calc": "100 × 2 = 200 pontos",
      "chat": "@bruno_live: APROVEITA!", "caption": "🎁 O chat aproveita o momento e envia presentes."},
     {"timer": "01:48", "left": "2600", "right": "1900", "banner": "bonus", "banner_sub": "x2 pontos de presentes", "seconds": "4", "glove": "sim", "glove_label": "x5",
      "caption": "📈 O placar sobe mais rápido. Luva e Power-Ups no fim do bônus, e um snipe no final da missão, podem dar vantagem."},
     {"timer": "00:30", "left": "2600", "right": "3100", "banner": "text", "banner_title": "⏳ ÚLTIMOS 30 SEGUNDOS", "banner_sub": "Hora de virar o placar", "glove": "sim", "glove_label": "x5",
      "chat": "@LucasLive: manda a luva agora, segura comigo!",
      "caption": "Nos últimos 30 segundos, incentive a luva e converse com o chat: é a hora de tentar virar o placar ou garantir a vitória."},
     {"timer": "00:03", "left": "3600", "right": "3100", "gift": "🎁", "calc": "Snipe! +1.000",
      "caption": "🎯 Snipe: presentes nos últimos segundos podem mudar o resultado."},
     {"timer": "00:00", "left": "3600", "right": "3100", "result": "win",
      "caption": "🏆 WIN! @LucasLive vence e vai para WIN x4. Quem perde fica com LOSE e volta para WIN x0."}
   ]},

  {"type": "compare", "label": "Resumo", "title": "Em poucas palavras",
   "items": [
     {"emoji": "👆", "title": "Tap Tap", "goal": "Cada pessoa soma 3 pontos uma vez por batalha; as curtidas aumentam os likes da LIVE.", "steps": "👆 Curtiu | +3 pontos (1x por batalha)"},
     {"emoji": "🎁", "title": "Presentes", "goal": "Contribuem para a pontuação e representam os presentes enviados pelo público.", "steps": "🎁 Presente | 💎 Valor | 📈 Pontos"},
     {"emoji": "🔥", "title": "Missão x2/x3", "goal": "Pode aumentar a pontuação dos presentes durante o período indicado.", "steps": "🎁 100 | ✖️ x2 | 📈 200"},
     {"emoji": "🥊", "title": "Power-Up", "goal": "Luva: se o presente pegar na luva, pode virar x5.", "steps": "🎁 Presente | 🥊 Luva | x5"},
     {"emoji": "⚠️", "title": "Lembrete", "goal": "Multiplicadores de batalha não multiplicam os ganhos financeiros do streamer.", "steps": "Pontos ≠ ganhos"}
   ]},

  {"type": "tip", "body": "Missão boa é missão aproveitada.\nVEJA → AVISE O CHAT → CRIE O MOMENTO → APROVEITE O TEMPO."}
]
$json$::jsonb;
  a record;
begin
  for a in select distinct agency_id from academy_categories where slug = 'batalhas' loop
    if exists (select 1 from academy_lessons where agency_id = a.agency_id and slug = 'aula-03-missoes-de-batalha') then
      update academy_lessons set blocks = v_blocks, updated_at = now()
      where agency_id = a.agency_id and slug = 'aula-03-missoes-de-batalha';
    else
      insert into academy_lessons (agency_id, slug, category_id, subcategory, title, subtitle, audience, level,
        blocks, availability, status, sort_order, duration_min, tags, sources, info_status)
      values (a.agency_id, 'aula-03-missoes-de-batalha',
        (select id from academy_categories where agency_id = a.agency_id and slug = 'batalhas'),
        'Aula interativa',
        '⚔️ Missões de Batalha',
        'Primeiro presente x2/x3, missões bônus, Tap Tap, luva e os últimos segundos da batalha.',
        array['todos', 'batalhas'], 'iniciante',
        v_blocks, 'disponivel', 'revisao', -10, 7,
        array['batalha', 'missão', 'x2', 'x3', 'tap tap', 'luva', 'snipe', 'interativa'],
        jsonb_build_array(jsonb_build_object(
          'title', 'Interface de Batalha do TikTok LIVE observada em 2026. Mecânicas e números são ilustrativos e podem variar por conta, região e versão — revisar quando houver documentação oficial.',
          'url', null, 'consulted_at', '2026-10-07')),
        'revisar');
    end if;
  end loop;
end $$;

insert into academy_access_grants (lesson_id, profile_id)
select l.id, p.id from academy_lessons l
join profiles p on p.agency_id = l.agency_id and lower(ltrim(p.tiktok_username, '@')) = 'gidreams_'
where l.slug = 'aula-03-missoes-de-batalha'
on conflict do nothing;

select title, status, jsonb_array_length(blocks) as blocos
from academy_lessons where slug = 'aula-03-missoes-de-batalha';
