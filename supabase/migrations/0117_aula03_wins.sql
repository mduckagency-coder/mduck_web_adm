-- Missões de Batalha: quem perde fica com WIN x0 (o adversário começa em 0).
update academy_lessons
set blocks = replace(replace(replace(blocks::text,
      '"right_wins": "2"', '"right_wins": "0"'),
      '🏆 WIN! @LucasLive vence e soma mais uma vitória. Quem perde fica com LOSE.', '🏆 WIN! @LucasLive vence e vai para WIN x4. Quem perde fica com LOSE e volta para WIN x0.'),
      'No alto aparecem as vitórias (WIN) de cada um.', 'No alto de cada lado aparecem as vitórias seguidas (WIN). Quem perde uma batalha volta para WIN x0.')::jsonb,
    updated_at = now()
where slug = 'aula-03-missoes-de-batalha';

select (blocks::text like '%"right_wins": "0"%') as ok from academy_lessons where slug = 'aula-03-missoes-de-batalha';
