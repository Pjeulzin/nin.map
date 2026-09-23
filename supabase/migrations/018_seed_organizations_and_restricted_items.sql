-- Migração 018: cadastro das Organizações (Corps) oficiais do jogo e dos
-- itens restritos por cargo/organização, extraídos de
-- https://ninonline.fandom.com/wiki/Corps,
-- https://ninonline.fandom.com/wiki/Kuronami_Organization,
-- https://ninonline.fandom.com/wiki/Medical_Corps,
-- https://ninonline.fandom.com/wiki/Military_Police e
-- https://ninonline.fandom.com/wiki/Role-gated_equipment.
--
-- Tabela nova `organizations`: 8 organizações --  ANBU, Twelve Guardian
-- Ninja, The Sand Puppet Brigade, Seven Swordsmen of the Mist, The
-- Neo-Akatsuki, Military Police Force, Medical Corps e Kuronami.
--
-- Fora de escopo: a página "Organizations" da wiki também lista 5
-- organizações feitas por JOGADORES (Desert Pirates, Yoru, Taka, Red
-- Lotus, Seigi) -- são história/trivia de servidor (grupos que já não
-- existem mais), não um sistema do jogo ativo hoje, então ficaram de
-- fora. As 8 cadastradas aqui são as oficiais, criadas por admin, que
-- ainda funcionam como mecânica (squads, ranks, itens restritos).
--
-- `village_id`: null quando a organização existe nas 3 vilas (Military
-- Police Force, Medical Corps), é secreta/cross-vila (ANBU, Neo-
-- Akatsuki), ou é baseada numa vila que não está na tabela `villages`
-- (Kuronami, baseada em Takumi Village -- Takumi não é uma das 4 vilas
-- jogáveis cadastradas ali). Preenchido só quando a organização é
-- exclusiva de uma vila específica das 4 (Twelve Guardian Ninja =
-- Folha, The Sand Puppet Brigade = Areia, Seven Swordsmen of the Mist
-- = Névoa).
--
-- `secret`: true pra ANBU e Neo-Akatsuki -- a wiki diz explicitamente
-- que organizações secretas não aparecem no bounty book do jogador.
-- Kuronami não tem essa confirmação explícita na wiki, então ficou
-- `false` mesmo sendo uma organização criminosa.
--
-- `ranks`: lista ordenada (menor pro maior) só quando a wiki documenta
-- uma hierarquia formal (ANBU, Puppet Brigade, Military Police).
-- Twelve Guardian Ninja e Seven Swordsmen explicitamente NÃO têm
-- ranks/esquadrões formais (a wiki diz isso) -- ficou vazio de
-- propósito, não é lacuna de dado. Neo-Akatsuki e Medical Corps não
-- têm uma lista de ranks documentada -- também ficou vazio.
--
-- Itens restritos (10, todos já listados na tabela da página
-- "Role-gated equipment"): 9 já existiam em `items` como `type =
-- 'roupa'` (cadastrados pela migração 015 como placeholders com
-- descrição genérica "This is role-gated...") -- esta migração
-- enriquece essas 9 linhas em vez de recriá-las: preenche descrição
-- completa, `restricted_to` e (só pros que dão bônus) `restricted_
-- stat_bonus`/`restricted_notes`. O décimo (Kuronami Ring) não existia
-- -- a migração 013 (anéis) deixou ele explicitamente fora de escopo
-- por ser restrito a organização -- entra aqui como `type = 'anel'`
-- novo, com as colunas `ring_*` da migração 013.
--
-- Três colunas novas em `items`, nulas pra item comum:
--   - restricted_to: quem pode equipar (organização, rank ou clã),
--     texto livre -- ex. "Mist Special Division", "Chunin", "Clã
--     Tendo".
--   - restricted_stat_bonus: bônus de atributo em JSON, só quando o
--     item dá bônus (a imensa maioria destes é puramente cosmética/de
--     status -- só a Mist Special Division Mask dá stats de verdade
--     entre as 9 roupas; o Kuronami Ring já tem bônus em `ring_
--     variants`, então esta coluna fica nula nele).
--   - restricted_notes: mecânica extra (ex. "não pode ser trocado" nas
--     regalias do Mizukami, "cai ao morrer" no Kuronami Ring -- texto
--     do próprio jogo, não nota da wiki) ou aviso de que o nível
--     exigido no card é baixo o bastante pra ser irrelevante perto do
--     requisito real (rank/organização).
--
-- "Tendo Beserker Pants": grafia "Beserker" (não "Berserker") é a
-- grafia do próprio jogo, mantida como está no nome do item.
--
-- Kuronami Ring -- nota de nomenclatura não resolvida: o nome do item
-- ("Kuronami Ring") e o efeito visual no jogo ("KuronamiGlow") usam o
-- nome da organização Kuronami, mas o texto da própria wiki diz que é
-- "worn only by the Neo-Akatsuki" e dropa na "Neo-Akatsuki cave" --
-- inconsistência da wiki entre o nome do item e a organização que o
-- usa, mantida como está (restricted_to segue o texto: Neo-Akatsuki).
--
-- Lacunas de dados: a forma de conseguir a maioria destes itens não é
-- documentada pela wiki (cargos/organizações concedem o item
-- automaticamente a membros, sem loja/NPC) -- `clothing_source` fica
-- null nesses casos em vez de um chute.

create table if not exists organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  village_id text references villages(id) on delete set null,
  description text,
  ranks text[] not null default '{}',
  secret boolean not null default false,
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists organizations_village_id_idx on organizations (village_id);
create unique index if not exists organizations_name_unique_idx on organizations (lower(name));

insert into organizations (name, village_id, description, ranks, secret) values
  ('ANBU', null, 'The top-secret squads in each village, including some of the best fighters, acting as the private guards of the Kage. In Mist they are called Hunter-Nin. Joining is very hard: you must be close to the Kage and have proven your loyalty and fighting skill in the village.', array['Squad Member', 'Squad Captain', 'Second in Command (SiC)', 'Leader'], true),
  ('Twelve Guardian Ninja', 'folha', 'The bodyguards appointed to guard the Daimyo of the Land of Fire, based at the summit of the Leaf Village. Unlike most organizations they act as one group rather than being split into squads, led by one skilled leader (the organization leader) on missions and hunts. They have a sub-group called the "Proteges", potential future members in training. Famous for wearing a unique waistcloth marked with the kanji for fire (火).', array[]::text[], false),
  ('The Sand Puppet Brigade', 'areia', 'A unit of Sand shinobi specialized in using giant puppets as weapons to defend the village and fight enemies, summoned via a specialized puppet coffin. Split into squads of 3 with a captain, composed of the most strategic and talented combatants.', array['Squad Member', 'Squad Captain', 'Leader'], false),
  ('Seven Swordsmen of the Mist', 'neblina', 'An organization of the deadliest, most blood-thirsty shinobi of the Hidden Mist Village. More a title than a group -- members do not operate together, usually hunting solo or in groups of up to 3. Famous for wielding the Seven Legendary swords of the Mist, one per member. You join by winning a blood duel against a current member (taking their place and sword) or by being invited to a free spot after proving yourself.', array[]::text[], false),
  ('The Neo-Akatsuki', null, 'The most infamous criminal organization in the Ninja World, consisting of the most dangerous missing-nin, based in Takumi. Organized into two-person teams with a leader per team, formed by compatibility between members. Joined via duel challenge or by being hand-picked for combat skill and high bounty. Each member holds a ring that grants an ominous red aura and a severe strength boost.', array[]::text[], true),
  ('Military Police Force', null, 'The Military Police Forces (LMPF in Leaf, SMPF in Sand, MMPF in Mist) bring justice to the village, punish criminals, investigate crimes and support the Kage. Has a special jutsu that jails a criminal for 30 minutes in the police HQ prison, usable only by ranked ninja such as Chunin and above.', array['Crime Investigator/Analyst', 'Police Captain', 'Deputy Chief', 'Chief General'], false),
  ('Medical Corps', null, 'Village organizations dedicated to healing and supporting fellow ninja, one per major village, operating from a medical base (hospital). Members focus on the Medical mastery and gain access to exclusive daily missions (healing and reviving allied players) for XP and Ryo.', array[]::text[], false),
  ('Kuronami', null, 'A criminal organization formed from the ideology of its predecessor, based in Takumi Village. Members take on paid jobs in exchange for Ryo, including helping with missions, open to members of any village or other organization (12 member slots documented).', array[]::text[], false)
on conflict (lower(name)) do update set
  village_id = excluded.village_id,
  description = excluded.description,
  ranks = excluded.ranks,
  secret = excluded.secret;

drop trigger if exists organizations_set_updated_at on organizations;
create trigger organizations_set_updated_at before update on organizations for each row execute function set_updated_at();
alter table organizations enable row level security;
drop policy if exists organizations_public_read on organizations;
create policy organizations_public_read on organizations for select using (true);
drop policy if exists organizations_auth_write on organizations;
create policy organizations_auth_write on organizations for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

alter table items add column if not exists restricted_to text;
alter table items add column if not exists restricted_stat_bonus jsonb;
alter table items add column if not exists restricted_notes text;
create index if not exists items_restricted_to_idx on items (restricted_to);

-- Enriquecimento das 9 roupas role-gated já cadastradas pela migração
-- 015 (placeholders com descrição genérica) -- atualiza só linhas que
-- já são 'roupa', nunca cria linha nova aqui.
insert into items (name, type, description, clothing_slot, clothing_rarity, clothing_level_required, clothing_source, clothing_notes, restricted_to, restricted_stat_bonus, restricted_notes) values
  ('Mist Special Division Mask', 'roupa', 'A mask worn by Mist Special Division to hide their identities and offer some protection.', 'Hat', 'Enchanted', 5, null, 'Forma de ingresso na Mist Special Division não documentada pela wiki.', 'Mist Special Division (Névoa)', '{"Strength": 7, "Fortitude": 7, "Intellect": 7, "Agility": 7, "Chakra": 7}'::jsonb, 'O nível 5 no card não é o requisito real -- o item só pode ser equipado por quem tem o cargo de Mist Special Division (o card também lista a vila Mist). Maior bônus de atributo entre os itens catalogados nesta migração (+7 em todos os 5 atributos, +35 no total).'),
  ('Mist Special Division Robe', 'roupa', 'Robe worn by the Mist Special Division Corps of the Mist village.', 'Vest', 'Common', null, null, 'Forma de ingresso na Mist Special Division não documentada pela wiki.', 'Mist Special Division (Névoa)', null, 'Não dá bônus de atributo -- o bônus do uniforme está inteiro na Mist Special Division Mask.'),
  ('Mizukami Hat', 'roupa', 'A hat worn by the leader of the Mist Village during ceremonies and meetings to show his authority.', 'Hat', 'Legendary', null, null, null, 'Mizukage (líder da vila Névoa)', null, 'Regalia do cargo, não item de combate -- marcado "Cannot be traded" no card: só quem ocupa o cargo pode usar, e não pode ser repassado a outro jogador.'),
  ('Mizukami Cloak', 'roupa', 'A cloak worn by the leader of the Mist Village during ceremonies and meetings to show his authority.', 'Vest', 'Legendary', null, null, null, 'Mizukage (líder da vila Névoa)', null, 'Regalia do cargo, não item de combate -- marcado "Cannot be traded" no card: só quem ocupa o cargo pode usar, e não pode ser repassado a outro jogador.'),
  ('Sand Police Vest', 'roupa', 'A police uniform (Only equippable by Sand Police Force members)', 'Vest', 'Common', null, null, 'Forma de ingresso no Sand Police Force não documentada pela wiki.', 'Sand Police Force (Areia)', null, 'O card carrega a tag "Authority".'),
  ('Yamato Protector', 'roupa', 'This forehead protector comes with a metal piece around the face for added protection. Wearing one is a sign of mutual respect as ninjas in combat.', 'Hat', 'Uncommon', null, null, null, 'Chunin (Folha)', null, 'Restrito por rank (Chunin) e vila (Folha), não por nível.'),
  ('Black Flak Jacket', 'roupa', 'A flak jacket, designed to give added protection to the upper body and the vital areas residing there.', 'Vest', 'Uncommon', 5, null, null, 'Jonin', null, 'O nível 5 no card é irrelevante -- o requisito real é o rank Jonin.'),
  ('White Chunin Battle Suit', 'roupa', 'A white robe fitted with straps of charred leather for added protection.', 'Shirt', 'Uncommon', 30, null, null, 'Chunin (Areia)', null, 'Restrito por rank (Chunin), nível (30) e vila (Areia) ao mesmo tempo -- diferente da maioria dos itens role-gated cadastrados aqui, que restringem só por um critério.'),
  ('Tendo Beserker Pants', 'roupa', 'A pair of pants that is worn by the Tendo Clan elites.', 'Pants', 'Unique', 30, null, null, 'Clã Tendo (elite)', null, 'Grafia "Beserker" (não "Berserker") é a grafia do próprio jogo, mantida como está no nome do item.')
on conflict (lower(name)) do update set
  description = excluded.description,
  clothing_slot = excluded.clothing_slot,
  clothing_rarity = excluded.clothing_rarity,
  clothing_level_required = excluded.clothing_level_required,
  clothing_source = coalesce(items.clothing_source, excluded.clothing_source),
  clothing_notes = excluded.clothing_notes,
  restricted_to = excluded.restricted_to,
  restricted_stat_bonus = excluded.restricted_stat_bonus,
  restricted_notes = excluded.restricted_notes
where items.type = 'roupa';

-- Kuronami Ring: décimo item restrito, fora de escopo da migração 013
-- (anéis) por ser restrito a organização -- entra aqui como novo `type
-- = 'anel'`.
insert into items (name, type, description, ring_family, ring_level_required, ring_variants, ring_notes, restricted_to, restricted_notes) values
  ('Kuronami Ring', 'anel', 'A ring worn only by the Neo-Akatsuki, the strongest and most evil ninja. It creates an ominous aura around the wielder and grants them immense power, increasing all their stats greatly. It can only be obtained from the Neo-Akatsuki cave, accessible only to the organization''s members.', 'Kuronami Ring', 35, '[{"rarity": "Legendary", "stats": {"Strength": 20, "Fortitude": 30, "Intellect": 20, "Agility": 20, "Chakra": 20}}]'::jsonb, 'Anéis são cosmeticamente invisíveis -- não mudam a aparência do personagem, só dão bônus de atributo (este, além disso, dá uma aura visual ao redor do personagem).', 'Neo-Akatsuki (membro)', 'Cai ao morrer ("Drops on death", texto do próprio jogo). Obtido só na Neo-Akatsuki cave, acessível apenas a membros. Nota de nomenclatura: o nome do item ("Kuronami Ring") e o efeito visual ("KuronamiGlow") usam o nome da organização Kuronami, mas o texto da própria wiki diz que é usado pelo Neo-Akatsuki -- inconsistência da wiki não resolvida aqui.')
on conflict (lower(name)) do update set
  description = excluded.description,
  ring_family = excluded.ring_family,
  ring_level_required = excluded.ring_level_required,
  ring_variants = excluded.ring_variants,
  ring_notes = excluded.ring_notes,
  restricted_to = excluded.restricted_to,
  restricted_notes = excluded.restricted_notes
where items.type = 'anel' or items.type = 'item_mob';
