-- =============================================================
-- Migração: adiciona rank (S/A/B/C/D) às missões
-- Rode isso no SQL Editor do Supabase se você já tinha rodado o
-- schema.sql antes desta mudança. Se estiver rodando o schema.sql do
-- zero, pode ignorar este arquivo — ele já está incluído lá.
-- =============================================================

do $$ begin
  create type mission_rank as enum ('S', 'A', 'B', 'C', 'D');
exception
  when duplicate_object then null;
end $$;

alter table missions
  add column if not exists rank mission_rank not null default 'D';
