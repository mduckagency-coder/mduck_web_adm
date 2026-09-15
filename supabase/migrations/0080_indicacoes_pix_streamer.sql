-- ============================================================================
-- Indicacoes: streamer da agencia que indicou alguem ganha uma chave PIX
-- cadastravel pelo gestor direto no CRM. O lead de indicacao passa a poder
-- referenciar esse streamer diretamente (referrer_streamer_id), pra puxar a
-- chave PIX automaticamente na hora do coordenador confirmar o pagamento do
-- bonus em Financeiro/Financeiro & RH -- em vez de digitar a chave na mao
-- toda vez.
--
-- referrer_streamer_id fica null quando quem indicou nao e streamer da
-- agencia (so o texto livre em origin_detail, como ja era).
-- Aditivo/idempotente, rode manualmente no SQL Editor do Supabase.
-- ============================================================================

alter table profiles add column if not exists pix_key text;
comment on column profiles.pix_key is 'Chave PIX do streamer, cadastrada pelo gestor no CRM -- usada para pagar bonus de indicacao quando esse streamer foi quem indicou.';

alter table leads add column if not exists referrer_streamer_id uuid references profiles(id);
comment on column leads.referrer_streamer_id is 'Streamer da agencia (CRM) que fez a indicacao, quando aplicavel. Preenchido pelo coordenador ao confirmar o pagamento em Indicacoes, pra puxar a chave PIX automaticamente.';
