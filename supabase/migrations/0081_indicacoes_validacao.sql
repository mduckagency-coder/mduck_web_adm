-- ============================================================================
-- Indicacoes: "validado" e um marco separado de "entrou na agencia"
-- (converted_at) -- e o coordenador quem confirma manualmente, depois de
-- acompanhar o indicado por um tempo, batendo com a coluna "Validou" da
-- planilha que ja era usada pra controlar isso (dias/horas ate validar).
-- Aditivo/idempotente, rode manualmente no SQL Editor do Supabase.
-- ============================================================================

alter table leads add column if not exists referral_validated_at timestamptz;
comment on column leads.referral_validated_at is 'Quando o coordenador confirmou manualmente que a indicacao foi validada (ex: streamer se manteve ativo por um periodo). Null = ainda nao validado. Independente de converted_at (que so marca a entrada na agencia).';
