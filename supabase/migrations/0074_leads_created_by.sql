-- ============================================================================
-- "Cadastro em nome de outro recrutador" (LeadFormDialog, coordenador/admin):
-- depois da 0073 o insert em lead_history parou de falhar, mas o card sumia
-- da aba "Meus leads" de quem cadastrou -- so ficava visivel pra quem foi
-- colocado como recruiter_id (o dono do lead). Precisa aparecer nos dois:
-- pra quem criou e pra quem o lead foi atribuido, sem duplicar a linha.
--
-- leads nao tinha coluna separada pra "quem cadastrou" (so recruiter_id, o
-- dono/responsavel). Adiciona created_by; pra leads ja existentes, dono e
-- quem cadastrou sao a mesma pessoa, entao o backfill copia de recruiter_id.
-- Aditivo/idempotente, rode manualmente no SQL Editor do Supabase.
-- ============================================================================

alter table leads add column if not exists created_by uuid references managers(id);
comment on column leads.created_by is 'Quem de fato cadastrou o lead. Pode ser diferente de recruiter_id quando um coordenador/admin cadastra em nome de outro recrutador -- usado pra o card continuar aparecendo tambem na aba "Meus leads" de quem criou.';

update leads set created_by = recruiter_id where created_by is null;
