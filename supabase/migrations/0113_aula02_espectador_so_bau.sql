-- "Onde o espectador encontra": só o Baú, com o baú desenhado no app.
update academy_lessons l
set blocks = (
  select jsonb_agg(
    case when b->>'type' = 'viewer_view' then b || $v$
      {"intro": "Para quem assiste, o Baú aparece como um ícone no canto de cima, logo abaixo da foto do streamer. Toque nele.",
       "icons": [
         {"emoji": "🎁", "art": "bau", "badge": "01:46", "title": "🎁 Baú de Tesouros",
          "body": "O espectador toca nesse ícone, logo abaixo da foto do streamer, para participar do Baú. O contador mostra quanto tempo falta."}
       ]}$v$::jsonb
    else b end order by i)
  from jsonb_array_elements(l.blocks) with ordinality as x(b, i)),
  updated_at = now()
where l.slug = 'aula-02-bau-portal-sacola';

select b->'icons' as icones
from academy_lessons l, jsonb_array_elements(l.blocks) b
where l.slug = 'aula-02-bau-portal-sacola' and b->>'type' = 'viewer_view';
