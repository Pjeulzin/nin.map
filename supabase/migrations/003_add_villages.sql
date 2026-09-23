-- =============================================================
-- Migração: adiciona vilas (Névoa, Folha, Areia, Renegados) e
-- vincula missões a uma vila opcional.
-- Rode isso no SQL Editor do Supabase se você já tinha rodado o
-- schema.sql antes desta mudança. Se estiver rodando o schema.sql do
-- zero, pode ignorar este arquivo — ele já está incluído lá.
-- =============================================================

create table if not exists villages (
  id text primary key,
  label text not null,
  created_at timestamptz not null default now()
);

insert into villages (id, label) values
  ('neblina', 'Névoa'),
  ('folha', 'Folha'),
  ('areia', 'Areia'),
  ('renegados', 'Renegados')
on conflict (id) do nothing;

alter table missions
  add column if not exists village_id text references villages(id) on delete cascade;

create index if not exists missions_village_id_idx on missions (village_id);

alter table villages enable row level security;

drop policy if exists villages_public_read on villages;
create policy villages_public_read on villages for select using (true);
