-- ============================================================================
-- Central de Informacoes da MDuck (app: Configuracoes > Central de Informacoes)
--
-- Reaproveita a estrutura que ja existe: app_settings 'app_config'
-- (faq = lista de {q, a}, help_text, info_version), editavel no painel em
-- Configuracoes do Aplicativo > Ajuda e Suporte.
--   * substitui a lista de perguntas pelas 18 secoes + 2 perguntas rapidas;
--   * atualiza tambem os padroes (app_config_defaults);
--   * app_my_manager(): nome e WhatsApp do gestor responsavel do streamer
--     (profiles.assigned_manager_id), para o botao "Falar com minha gestao".
-- Nao ha estrutura de aceite/versao no sistema: nada disso e criado aqui.
-- Rode manualmente no SQL Editor do Supabase.
-- ============================================================================

create or replace function app_info_center_content()
returns jsonb
language sql immutable
as $central$
  select $json$
{
"help_text": "Aqui você encontra, de forma simples, como funcionam as principais áreas do MDuck Lives e para que cada uma serve. Ficou alguma dúvida? Fale com sua gestão.",
"info_version": "Versão 1.0 — Outubro/2026",
"faq": [
{"q":"1. Sobre o aplicativo","a":"O MDuck Lives foi criado para ajudar você a acompanhar sua evolução nas lives.\n\nEle reúne métricas, jornada, missões, conquistas, ranking, calendário, Academia e outras ferramentas pensadas para incentivar constância, desenvolvimento e crescimento.\n\nAs informações do app servem para acompanhamento e incentivo. O aplicativo está em constante evolução, e algumas funcionalidades, informações ou critérios podem ser atualizados, corrigidos ou modificados pela MDuck."},
{"q":"2. Métricas","a":"As métricas ajudam você a acompanhar sua evolução.\n\nParte dos dados é recebida, organizada e atualizada pela equipe da agência. Por isso, pode haver atraso: a atualização acontece conforme a disponibilidade da equipe e pode não ser diária, principalmente em finais de semana, feriados ou períodos de manutenção.\n\nOs números do app podem ser ajustados ou corrigidos depois.\n\nMetas recomendadas: os dias de live, horas e diamantes mostrados no app são referências de desenvolvimento e incentivo, não uma obrigação mensal. Cada streamer tem sua própria realidade. Você não precisa atingir 80K, 100 horas ou qualquer número específico para continuar sua jornada. O mais importante é seguir evoluindo dentro das suas possibilidades."},
{"q":"3. Conquistas e marcos","a":"As conquistas e os marcos existem para celebrar momentos importantes da sua evolução.\n\nAtingir um número de diamantes pode desbloquear uma conquista visual no app, mas isso não significa, por si só, que exista uma premiação física ou financeira ligada àquele marco.\n\nQuando uma conquista tiver premiação, as condições serão informadas pela MDuck. As conquistas podem ser atualizadas, alteradas ou encerradas conforme os programas da agência."},
{"q":"4. Premiações","a":"As premiações são definidas pela MDuck para cada campanha, programa ou ação, com critérios próprios de elegibilidade, período, condições e regras.\n\nO aparecimento de uma conquista, missão ou marco no app não garante, sozinho, uma premiação.\n\nPremiações podem depender de permanência, atividade, cumprimento das regras e outros critérios informados pela agência. Em casos de inatividade, encerramento do vínculo ou descumprimento das condições, a elegibilidade pode ser revista conforme as regras daquela ação."},
{"q":"5. Calendário","a":"O calendário ajuda a organizar e divulgar eventos, ações, atividades e informações importantes da MDuck.\n\nUm evento no calendário não significa que ele esteja confirmado para todos os participantes.\n\nBatalhas oficiais, ações especiais e compromissos que dependem da agência devem ser alinhados com a gestão pelo WhatsApp oficial. Uma solicitação feita pelo app não substitui a confirmação da equipe: antes de considerar uma batalha ou evento confirmado, aguarde o retorno da gestão."},
{"q":"6. Jornada","a":"A Jornada ajuda você a visualizar sua evolução e acompanhar diferentes etapas dentro da MDuck.\n\nAs atividades, marcos e informações podem ser atualizados pela agência. Os registros servem para acompanhamento e podem ser corrigidos se houver algum erro de cadastro, atualização ou processamento."},
{"q":"7. Missões","a":"As missões incentivam comportamentos, objetivos ou ações dentro da agência.\n\nNem toda missão tem premiação. Quando houver recompensa, ela será informada junto com as condições da missão.\n\nAs missões podem ser alteradas, encerradas ou substituídas pela MDuck conforme as necessidades e estratégias da agência."},
{"q":"8. Ranking","a":"O ranking incentiva participação, evolução e uma competitividade saudável entre os streamers. Ele permite acompanhar resultados e compartilhar momentos de crescimento.\n\nEstar em uma posição do ranking não significa receber premiação. Só rankings ou campanhas com premiação específica terão as condições divulgadas pela agência.\n\nOs dados do ranking podem ter atualizações, atrasos ou correções."},
{"q":"9. Academia MDuck","a":"A Academia oferece conteúdos, perguntas, orientações e materiais para ajudar no seu desenvolvimento.\n\nOs conteúdos são educativos e informativos e podem ser atualizados conforme novas informações, estratégias e necessidades da agência. Alguns usam referências públicas da plataforma e materiais produzidos ou adaptados pela MDuck.\n\nPor isso, a Academia não substitui as diretrizes oficiais da plataforma."},
{"q":"10. Animações e conteúdos do app","a":"Algumas animações, mensagens, personagens e conteúdos do app existem para deixar a experiência mais dinâmica e divertida.\n\nEles podem variar conforme sua atividade, o período, campanhas ou atualizações do app, e a MDuck pode substituir, alterar ou remover esses conteúdos com a evolução do aplicativo."},
{"q":"11. Inatividade","a":"O aplicativo é uma ferramenta para os streamers ativos e participantes da MDuck.\n\nEm períodos prolongados de inatividade, a agência pode revisar a participação em determinados programas, benefícios ou funcionalidades do app, e o acesso ao aplicativo ou a algumas funcionalidades pode ser suspenso ou encerrado, conforme os critérios da agência.\n\nSe precisar se afastar das lives, converse com sua gestão."},
{"q":"12. Nossa relação com você","a":"A MDuck existe para oferecer suporte, acompanhamento, treinamento, desenvolvimento e oportunidades aos seus streamers.\n\nA agência não garante patrocínios, campanhas, presentes, marcas ou oportunidades comerciais para todos. Cada oportunidade depende de disponibilidade, perfil, campanha, estratégia e critérios específicos.\n\nNosso objetivo é construir uma relação de longo prazo, em que streamer e agência cresçam juntos."},
{"q":"13. Comunicação com a gestão","a":"Nossa equipe é formada por pessoas com horários, responsabilidades e funções diferentes dentro da agência.\n\nSempre que precisar de ajuda, procure seu gestor ou o responsável adequado e aguarde o retorno da equipe. Antes de tomar decisões importantes sobre sua carreira ou sobre a participação em uma campanha, converse com sua gestão."},
{"q":"14. MDuck e comunidade","a":"A MDuck é formada por diferentes streamers, gestores e profissionais. Respeito e educação são fundamentais para uma comunidade saudável.\n\nEsperamos uma postura respeitosa com outros streamers, nas batalhas, com gestores, com o seu chat e em qualquer interação ligada à MDuck.\n\nDiscordâncias podem acontecer. Problemas devem ser conversados e resolvidos com respeito."},
{"q":"15. Diretrizes da plataforma","a":"Cada streamer é responsável por conhecer e respeitar as diretrizes da plataforma em que faz suas lives.\n\nComportamentos que violem as regras da plataforma ou as políticas da MDuck podem levar a medidas internas, suspensão de benefícios ou encerramento do vínculo, conforme a situação.\n\nA MDuck orienta e oferece suporte, mas não substitui a responsabilidade de cada streamer sobre a própria conta e o próprio conteúdo."},
{"q":"16. Permanência e diálogo","a":"Uma boa relação entre agência e streamer se constrói com diálogo, respeito e alinhamento de expectativas.\n\nSe você estiver insatisfeito, tiver algum problema, discordar de uma decisão ou achar que algo pode melhorar, fale com sua gestão. Feedbacks e sugestões são sempre bem-vindos e ajudam a agência a evoluir. Nem sempre teremos uma solução imediata para tudo, mas queremos ouvir você.\n\nAntes de decidir sobre sua permanência na agência, converse com seu gestor e tire suas dúvidas. Muitas vezes uma conversa evita uma decisão tomada por impulso.\n\nSe você decidir encerrar o vínculo, algumas conquistas, benefícios, campanhas ou premiações podem ter condições ligadas à permanência e podem ser afetadas.\n\nNosso objetivo é que você cresça junto com a MDuck. Use o botão \"Falar com minha gestão\" no topo desta página."},
{"q":"17. Sobre informações e atualizações","a":"O MDuck Lives está em constante desenvolvimento.\n\nPodem acontecer atrasos de atualização, erros de cadastro, informações incompletas, mudanças de critérios, falhas temporárias ou correções em ranking, métricas, jornada ou conquistas. Quando uma inconsistência for identificada, a MDuck pode corrigir ou atualizar a informação.\n\nO aplicativo é uma ferramenta de acompanhamento e incentivo e não substitui as confirmações oficiais da agência. Se encontrar algo errado, use Configurações > Reportar um problema."},
{"q":"18. Ciência das informações","a":"Ao usar o MDuck Lives, você está ciente de que as informações do aplicativo têm finalidade de acompanhamento e incentivo e podem ser atualizadas, corrigidas ou modificadas pela MDuck.\n\nOs critérios específicos de campanhas, missões e premiações são informados em cada ação."},
{"q":"Pergunta rápida: como desbloqueio a arte de um marco do mês?","a":"Quando você alcança um marco de diamantes no mês, a arte é liberada no app com a sua foto e o seu @, pronta para compartilhar. A arte é uma comemoração visual e não representa, por si só, uma premiação."},
{"q":"Pergunta rápida: encontrei um dado errado. O que faço?","a":"Use Configurações > Reportar um problema e escolha \"Dados incorretos ou desatualizados\". Lembre que alguns dados podem demorar para ser atualizados pela equipe."}
]
}
$json$::jsonb;
$central$;

-- padroes (agencias sem configuracao propria)
create or replace function app_config_defaults()
returns jsonb
language sql stable
as $$
  select jsonb_build_object(
    'version_label', '1.0.0 Beta',
    'last_update', to_char(now() at time zone 'America/Sao_Paulo', 'YYYY-MM-DD'),
    'about_title', 'Sobre a MDuck',
    'about_text', 'A MDuck Agency acompanha streamers do TikTok no dia a dia: estratégia, constância, resultados e reconhecimento. Este aplicativo reúne sua jornada, seus marcos do mês e suas conquistas em um só lugar.',
    'support_text', 'Fale com a equipe MDuck Agency pelos canais abaixo.',
    'support_whatsapp', '',
    'support_email', '',
    'settings_title', 'Configurações',
    'report_intro', 'Conte o que aconteceu. Nós já registramos automaticamente sua conta, a data e a versão do app.',
    'report_success', 'Recebemos seu reporte. Obrigado por ajudar a melhorar o app!',
    'app_info_text', 'Aplicativo oficial dos streamers da MDuck Agency.'
  ) || app_info_center_content();
$$;

-- agencias que ja salvaram configuracao: troca a lista antiga pela Central
update app_settings
set value = coalesce(value, '{}'::jsonb) || app_info_center_content()
where key = 'app_config';

-- gestor responsavel do streamer logado (so nome, foto e WhatsApp)
create or replace function app_my_manager()
returns jsonb
language sql stable security definer
set search_path = public
as $$
  select jsonb_build_object('name', coalesce(m.full_name, ''), 'whatsapp', m.whatsapp, 'photo_url', m.photo_url)
  from profiles p
  join managers m on m.id = p.assigned_manager_id
  where p.auth_user_id = auth.uid()
  limit 1;
$$;
grant execute on function app_my_manager() to authenticated;

notify pgrst, 'reload schema';
