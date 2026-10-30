-- Aula Baú, Portal e Sacola: ícones desenhados no lugar dos emojis
-- ([bau], [portal], [sacola], [superfa]), visão do espectador com os três,
-- novos textos do Portal, Baú de Superfã e "Use com estratégia".
update academy_lessons l
set blocks = replace(replace(replace(replace(l.blocks::text,
      '⭐ Baú de Superfã', '[superfa] Baú de Superfã'),
      '🚪', '[portal]'),
      '🛍️', '[sacola]'),
      '🎁', '[bau]')::jsonb
where l.slug = 'aula-02-bau-portal-sacola';

update academy_lessons l
set blocks = (
  select jsonb_agg(
    case
      when b->>'type' = 'live_menu' then b || $c$
        {"chat": [
          {"user": "@ana_live", "text": "boa noite!! 💜"},
          {"user": "@bruno_live", "text": "cheguei 👋"},
          {"user": "Lucas Martins · Host", "text": "bem-vindos! hoje tem novidade na LIVE 🎉"}
        ]}$c$::jsonb
      when b->>'type' = 'viewer_view' then b || $v$
        {"intro": "Para quem assiste, o Baú, o Portal e a Sacola aparecem como ícones pequenos no canto esquerdo, logo abaixo da foto do host. Toque em cada um.",
         "icons": [
           {"art": "bau", "badge": "01:46", "title": "[bau] Baú de Tesouros",
            "body": "O espectador toca nesse ícone, logo abaixo da foto do host, para participar do Baú. O contador mostra quanto tempo falta."},
           {"art": "portal", "badge": "", "title": "[portal] Portal",
            "body": "Quando há um Portal, ele aparece nesse mesmo canto, com o baú brilhando."},
           {"art": "sacola", "badge": "02:00", "title": "[sacola] Sacola de Prêmios",
            "body": "A Sacola também aparece ali: o espectador toca no ícone para ver as regras e participar."}
         ]}$v$::jsonb
      when b->>'type' = 'compare' then jsonb_set(b, '{items}', (
        select jsonb_agg(case it->>'title' when 'Sacola' then it || '{"art": "sacola"}' else it end order by k)
        from jsonb_array_elements(b->'items') with ordinality as y(it, k)))
      when b->>'type' = 'tiktok_sheet' and b ? 'send_steps' then jsonb_set(b, '{send_steps}', (
        select coalesce(jsonb_agg(case st->>'label' when 'A Sacola aparece na LIVE' then st || '{"art": "sacola"}' else st end order by k), '[]'::jsonb)
        from jsonb_array_elements(b->'send_steps') with ordinality as y(st, k)))
      when b->>'type' = 'flow' and b->>'title' like '%O Portal pode trazer a pessoa%' then b || $f$
        {"items": [
          {"art": "portal", "label": "Entrada", "body": "Avise na LIVE: “Enviei um Portal, fiquem atentos e peguem as moedas!”"},
          {"emoji": "👀", "label": "A pessoa entrou", "body": "Chame pelo nome quem estiver chegando, pergunte de onde é e dê boas-vindas. Quem se sente notado tem mais vontade de ficar."},
          {"emoji": "🎤", "label": "Algo interessante acontecendo", "body": "Você tem poucos minutos para prender a atenção de quem chegou. Faça algo que chame a atenção: uma brincadeira, uma música, um desafio."},
          {"emoji": "❤️", "label": "Interação", "body": "Puxe conversa, responda o chat e convide quem chegou a participar."},
          {"emoji": "👥", "label": "Possibilidade de permanecer", "body": "É normal muitas pessoas entrarem só pela recompensa e saírem. Se uma ficar, já valeu: tente transformá-la em uma espectadora fiel."}
        ]}$f$::jsonb
      when b->>'type' = 'strategy' and b->>'title' like '%Baú de Superfã%' then b || $s$
        {"title": "[superfa] Baú de Superfã",
         "body": "O Superfã é um nível de membro dos espectadores na LIVE. Com o Baú de Superfã, é possível enviar um baú para que algum espectador se torne Superfã gratuitamente — o valor é pago pelo host ou por quem enviou. A disponibilidade pode variar conforme a conta e a região."}$s$::jsonb
      when b->>'type' = 'text' and b->>'label' = 'Cuidado com Moedas' then
        jsonb_build_object('type', 'text', 'label', 'Use com estratégia',
          'body', 'As Moedas são um valor gasto por você ou por quem enviou. Usadas com estratégia, podem ser muito úteis para a sua comunidade crescer mais rápido.')
      else b end
    order by i)
  from jsonb_array_elements(l.blocks) with ordinality as x(b, i)),
  updated_at = now()
where l.slug = 'aula-02-bau-portal-sacola';

select (blocks::text like '%🎁%' or blocks::text like '%🚪%' or blocks::text like '%🛍️%') as ainda_tem_emoji,
       (select count(*) from jsonb_array_elements(blocks) b where b::text like '%[sacola]%' or b::text like '%"sacola"%') as blocos_com_sacola
from academy_lessons where slug = 'aula-02-bau-portal-sacola';
