-- Baú e Portal com o desenho de baú (estilo TikTok) nos cartões e animações.
update academy_lessons l
set blocks = (
  select jsonb_agg(
    case
      when b->>'type' = 'compare' then jsonb_set(b, '{items}', (
        select jsonb_agg(
          case it->>'title'
            when 'Baú' then it || '{"art": "bau"}'
            when 'Portal' then it || '{"art": "portal"}'
            else it end order by k)
        from jsonb_array_elements(b->'items') with ordinality as y(it, k)))
      when b->>'type' = 'tiktok_sheet' and b ? 'send_steps' then jsonb_set(b, '{send_steps}', (
        select coalesce(jsonb_agg(
          case st->>'label'
            when 'O Baú aparece na LIVE' then st || '{"art": "bau"}'
            when 'Pessoas em outras LIVEs veem o Portal' then st || '{"art": "portal"}'
            else st end order by k), '[]'::jsonb)
        from jsonb_array_elements(b->'send_steps') with ordinality as y(st, k)))
      else b end
    order by i)
  from jsonb_array_elements(l.blocks) with ordinality as x(b, i)),
  updated_at = now()
where l.slug = 'aula-02-bau-portal-sacola';

select count(*) filter (where t like '%"art": "bau"%') as com_bau, count(*) filter (where t like '%"art": "portal"%') as com_portal
from academy_lessons l, jsonb_array_elements(l.blocks) b, lateral (select b::text as t) z
where l.slug = 'aula-02-bau-portal-sacola';
