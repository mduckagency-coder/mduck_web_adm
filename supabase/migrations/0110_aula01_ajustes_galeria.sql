-- Aula 01: "Como funciona a Galeria", disputa com Presentes reais,
-- ate 3 presenteadores por Presente, sem quiz e sem resumo final.
update academy_lessons l
set blocks = (
  select jsonb_agg(
    case
      when b->>'type' = 'flow' and b->>'title' = 'A Galeria funciona em ciclos' then $j$
        {"type": "flow", "title": "Como funciona a Galeria",
         "items": [
           {"emoji": "🔄", "label": "Toda semana, uma nova Galeria", "body": "A Galeria é reiniciada semanalmente, e os Presentes dela variam de acordo com a Liga do criador."},
           {"emoji": "✨", "label": "Os espectadores iluminam", "body": "Quando um espectador envia um Presente que faz parte da Galeria, aquele Presente fica iluminado."},
           {"emoji": "🏷️", "label": "Nome na Galeria a semana toda", "body": "Quem iluminou um Presente fica com o nome na Galeria do criador durante toda a semana."},
           {"emoji": "👑", "label": "O maior presenteador em destaque", "body": "Ao tocar em um Presente, aparecem até 3 presenteadores. Quem mais enviou aquele Presente aparece como o principal."}
         ]}$j$::jsonb
      when b->>'type' = 'feed' then b || $j$
        {"title": "Uma disputa amigável",
         "items": [
           {"user": "@ana_live", "text": "enviou Leão e iluminou o Presente", "image_url": "asset:academy/gifts/leao.png", "emoji": "🦁"},
           {"user": "@bruno_live", "text": "enviou Mergulho com baleia", "image_url": "asset:academy/gifts/mergulho_com_baleia.png", "emoji": "🐋"},
           {"user": "@bruno_live", "text": "enviou mais Leões e virou o principal 👑", "image_url": "asset:academy/gifts/leao.png", "emoji": "🦁"},
           {"user": "@ana_live", "text": "voltou a enviar e retomou o destaque", "image_url": "asset:academy/gifts/leao.png", "emoji": "🦁"}
         ],
         "body": "Um mesmo Presente pode ter vários presenteadores na semana, e quem mais enviou aparece como principal. Isso cria uma disputa amigável — e cada participação merece reconhecimento."}$j$::jsonb
      when b->>'type' = 'gift_gallery' then b || jsonb_build_object(
        'sender_title', '👤 Quem iluminou',
        'sender_body', 'Aparecem até 3 presenteadores por Presente. Quem mais enviou fica em destaque como principal, com o nome na Galeria durante toda a semana.',
        'unlit_body', 'Este Presente ainda não foi iluminado nesta semana.',
        'gifts', (
          select jsonb_agg(g || jsonb_build_object('others', case g->>'name'
              when 'TikTok Universe' then '@ana_live, @theo.games'
              when 'Leon e Lion' then '@bruno_live'
              when 'Leão' then '@camila_s, @joaopedro'
              when 'Festa sem parar' then '@gabriel_live'
              when 'Planeta maravilhoso' then '@mari.oficial, @bruno_live'
              when 'Cidade do futuro' then '@theo.games'
              when 'Jatos Voadores' then '@ana_live, @camila_s'
              else '' end) order by gi)
          from jsonb_array_elements(b->'gifts') with ordinality as y(g, gi)))
      else b end
    order by i)
  from jsonb_array_elements(l.blocks) with ordinality as x(b, i)
  where b->>'type' not in ('quiz', 'recap')),
  updated_at = now()
where l.slug = 'aula-01-perfil-liga-galeria';

select string_agg(coalesce(b->>'title', b->>'label', b->>'type'), ' · ' order by i) as blocos
from academy_lessons l, jsonb_array_elements(l.blocks) with ordinality as x(b, i)
where l.slug = 'aula-01-perfil-liga-galeria';
