-- Aula Baú, Portal e Sacola: sem quiz e sem resumo; troca o exemplo no chat
-- pela visão do espectador (ícone abaixo da foto do streamer); sem "chegou
-- alguém"; nova fala da Sacola; dica de Heart Me nível 1.
update academy_lessons l
set blocks = (
  select jsonb_agg(blk order by pos)
  from (
    select case
             when b->>'type' = 'feed' and b->>'title' = 'Um Baú na LIVE' then $v$
               {"type": "viewer_view", "label": "Como o espectador vê", "title": "Onde o espectador encontra",
                "intro": "Para quem assiste, o Baú, o Portal e a Sacola aparecem como um ícone no canto de cima, logo abaixo da foto do streamer. Toque em cada um.",
                "host": "Lucas Martins",
                "icons": [
                  {"emoji": "🎁", "badge": "01:46", "title": "🎁 Baú de Tesouros", "body": "O espectador toca nesse ícone, logo abaixo da foto do streamer, para participar do Baú."},
                  {"emoji": "🚪", "badge": "", "title": "🚪 Portal", "body": "Quando há um Portal, ele também aparece nesse mesmo canto da tela."},
                  {"emoji": "🛍️", "badge": "02:00", "title": "🛍️ Sacola de Prêmios", "body": "A Sacola também aparece ali: o espectador toca no ícone para ver as regras e participar."}
                ]}$v$::jsonb
             when b->>'type' = 'example' and b->>'title' = 'Exemplo de fala' then
               b || jsonb_build_object('body', '“Coloquei uma Sacola de Prêmios! Vamos ver quem serão os ganhadores 🎉”')
             else b end as blk,
           i::numeric as pos
    from jsonb_array_elements(l.blocks) with ordinality as x(b, i)
    where b->>'type' not in ('quiz', 'recap')
      and not (b->>'type' = 'feed' and b->>'label' = 'Chegou alguém')
    union all
    select jsonb_build_object('type', 'tip', 'body',
             'De preferência, coloque como requisito o nível 1 de Heart Me (fãs). Assim, para participar, a pessoa entra para a sua comunidade — e isso ajuda a aumentar o seu clube de fãs.'),
           i + 0.5
    from jsonb_array_elements(l.blocks) with ordinality as x(b, i)
    where b->>'type' = 'tiktok_sheet' and b->>'title' = 'Quem pode participar?'
      and not exists (select 1 from jsonb_array_elements(l.blocks) t where t->>'body' like 'De preferência, coloque como requisito o nível 1 de Heart Me%')
  ) s),
  updated_at = now()
where l.slug = 'aula-02-bau-portal-sacola';

select string_agg(coalesce(b->>'title', b->>'label', b->>'type'), ' · ' order by i) as blocos
from academy_lessons l, jsonb_array_elements(l.blocks) with ordinality as x(b, i)
where l.slug = 'aula-02-bau-portal-sacola';
