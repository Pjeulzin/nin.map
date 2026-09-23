-- Migração 012: cadastro das Proficiências (Proficiencies) do jogo,
-- a partir de https://ninonline.fandom.com/wiki/Proficiencies,
-- https://ninonline.fandom.com/wiki/Weaving e https://ninonline.fandom.com/wiki/Cooking.
--
-- "Proficiencies" na wiki não são as maestrias de combate (fogo, vento,
-- taijutsu etc., já cadastradas na migração 007/tabela `masteries`) — são
-- 10 skills de coleta e crafting, cada uma com nível 1-500 e um bônus de
-- sucesso de 1% a cada 10 níveis (50% no cap). 4 são de coleta (Mining,
-- Woodcutting, Fishing, Foraging) e 6 são de crafting (Forging, Weaving,
-- Carpentry, Cooking, Transmutation, Fuinjutsu).
--
-- Escopo desta migração, conforme pedido: as 10 proficiências + as
-- receitas documentadas na wiki. Só Tecelagem (Weaving) e Culinária
-- (Cooking) têm página própria com lista de receitas — as outras 8
-- (incluindo Forjaria/Forging, que a wiki lista no hub mas cujo link
-- hoje só redireciona pra um resumo genérico sem dados) ainda não têm
-- receitas publicadas, só a descrição geral do que fazem.
--
-- Tecelagem: 24 receitas (17 com nível de desbloqueio conhecido + 7 que
-- só vêm de drop de mob, sem nível publicado). A wiki não documenta os
-- materiais/ingredientes dessas receitas, só o item final — por isso
-- essas entram sem linhas em `proficiency_recipe_materials`.
--
-- Culinária: 21 receitas, essas sim com ingredientes completos (a
-- página foi inteiramente re-documentada em 16/08/2026). Inclui a taxa
-- de sucesso base só pra Rice Ball (90%, confirmada em skill 0) e Fried
-- Egg (~50%, aproximada); as outras 19 não têm taxa/tempo de craft
-- registrados ainda.
--
-- Itens novos (materiais e produtos de receita que não existiam no
-- catálogo) foram criados com type = 'consumivel', já que o enum
-- item_type atual (anel/arma/roupa/consumivel/item_mob) não tem uma
-- categoria própria pra "ingrediente de crafting" — ajuste o tipo
-- manualmente no Admin pra roupas/acessórios craftados por Tecelagem
-- (chapéus, botas, calças, cachecóis, máscaras, capas) se quiser mais
-- precisão. Igual nas migrações anteriores, o "on conflict do nothing"
-- garante que reexecutar essa migração nunca sobrescreve um item que
-- você já editou manualmente.

do $$ begin
  create type proficiency_category as enum ('coleta', 'crafting');
exception
  when duplicate_object then null;
end $$;

create table if not exists proficiencies (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  category proficiency_category not null,
  description text,
  level_cap integer not null default 500,
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists proficiencies_category_idx on proficiencies (category);

-- Uma receita pertence a uma proficiência, e opcionalmente aponta pro
-- item que ela produz (`output_item_id`) — null quando o item final
-- ainda não tiver sido cadastrado por algum motivo.
create table if not exists proficiency_recipes (
  id uuid primary key default gen_random_uuid(),
  proficiency_id uuid not null references proficiencies(id) on delete cascade,
  name text not null,
  output_item_id uuid references items(id) on delete set null,
  level_required integer,
  success_rate_base numeric(5, 2),
  craft_time_seconds integer,
  requires_workbench boolean not null default false,
  effect_description text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (proficiency_id, name)
);

create index if not exists proficiency_recipes_proficiency_id_idx on proficiency_recipes (proficiency_id);
create index if not exists proficiency_recipes_output_item_id_idx on proficiency_recipes (output_item_id);

-- Ingredientes de cada receita (n:n receita <-> item), só preenchido
-- quando a wiki documenta os materiais (hoje, só Culinária).
create table if not exists proficiency_recipe_materials (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references proficiency_recipes(id) on delete cascade,
  item_id uuid not null references items(id) on delete cascade,
  quantity integer not null default 1,
  created_at timestamptz not null default now(),
  unique (recipe_id, item_id)
);

create index if not exists proficiency_recipe_materials_recipe_id_idx on proficiency_recipe_materials (recipe_id);
create index if not exists proficiency_recipe_materials_item_id_idx on proficiency_recipe_materials (item_id);

-- ---------------------------------------------------------------
-- updated_at automático + RLS
-- ---------------------------------------------------------------
drop trigger if exists proficiencies_set_updated_at on proficiencies;
create trigger proficiencies_set_updated_at
  before update on proficiencies
  for each row execute function set_updated_at();

drop trigger if exists proficiency_recipes_set_updated_at on proficiency_recipes;
create trigger proficiency_recipes_set_updated_at
  before update on proficiency_recipes
  for each row execute function set_updated_at();

alter table proficiencies enable row level security;
alter table proficiency_recipes enable row level security;
alter table proficiency_recipe_materials enable row level security;

drop policy if exists proficiencies_public_read on proficiencies;
create policy proficiencies_public_read on proficiencies for select using (true);

drop policy if exists proficiencies_auth_write on proficiencies;
create policy proficiencies_auth_write on proficiencies for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists proficiency_recipes_public_read on proficiency_recipes;
create policy proficiency_recipes_public_read on proficiency_recipes for select using (true);

drop policy if exists proficiency_recipes_auth_write on proficiency_recipes;
create policy proficiency_recipes_auth_write on proficiency_recipes for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists proficiency_recipe_materials_public_read on proficiency_recipe_materials;
create policy proficiency_recipe_materials_public_read on proficiency_recipe_materials for select using (true);

drop policy if exists proficiency_recipe_materials_auth_write on proficiency_recipe_materials;
create policy proficiency_recipe_materials_auth_write on proficiency_recipe_materials for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- ---------------------------------------------------------------
-- Seed: as 10 proficiências
-- ---------------------------------------------------------------
insert into proficiencies (slug, name, category, description, level_cap) values
  ('mineracao', 'Mineração', 'coleta', 'Extração de minério de nós de minério espalhados pelo mundo, usando uma picareta comprada no Ferreiro da vila. Cada nó minerado dá 2 XP. Minérios são refinados em lingotes através da Forjaria. A página "Mining" da wiki hoje só redireciona pra um resumo genérico (Gathering Proficiencies) — sem dados de nós/rotas específicos documentados ainda.', 500),
  ('corte_madeira', 'Corte de Madeira', 'coleta', 'Corte de árvores (variantes Basic, Thin e Huge) pra coletar toras e subir o nível da profissão. O tipo de tora depende do território: Vibrant na Folha, Dull perto da Areia e fronteiras Rogue, Dark na Névoa. A wiki documenta uma tabela de nível 1 a 30 com dano por golpe, XP e rendimento de toras por árvore.', 500),
  ('pesca', 'Pesca', 'coleta', 'Pesca de peixes e outros achados em qualquer tile de água de uns 2x2 ou maior, usando uma vara. Varas vão de uma Cheap Rod de 2.000 Ryo até uma Aerongel Gold Rod de 500.000 Ryo. Boa parte das receitas de Culinária depende de peixes raros pescados com tiers avançados de isca (Baiting Basics).', 500),
  ('forrageamento', 'Forrageamento', 'coleta', 'Coleta de frutinhas (berries), ervas, fibra e arroz de nós espalhados pelo mundo. Ainda sem página própria na wiki, mas é a que mais alimenta a Culinária — só o Arroz entra 5 unidades por Rice Ball.', 500),
  ('forjaria', 'Forjaria', 'crafting', 'Transforma minérios em lingotes, e lingotes em itens de metal. Ainda sem página própria detalhada na wiki — o link "Forging" hoje só redireciona pra um resumo genérico (Crafting Proficiencies), sem lista de receitas.', 500),
  ('tecelagem', 'Tecelagem', 'crafting', 'Transforma fibra, linha e couro em roupas, usando uma Bancada de Trabalho (Workbench). Foca em itens vestíveis e materiais de crafting como tiras de couro e folhas de tecido. Algumas receitas só aparecem depois de obtidas como drop de mob específico.', 500),
  ('carpintaria', 'Carpintaria', 'crafting', 'Transforma toras em tábuas e móveis, até uma Barraca de Mercado do Jogador (Player Market Stall) — o item craftado de maior valor já registrado na wiki (22.500 Ryo). Ainda sem página própria detalhada.', 500),
  ('culinaria', 'Culinária', 'crafting', 'Transforma frutinhas, arroz, ovos e peixe em comida que cura, descansa ou dá bônus de atributo por 30 minutos. As receitas mais fortes são vendidas pelo Chef em Takumi Village e exigem Culinária 18+. Substituiu o antigo sistema de Charms (Horóscopos e Amuletos), desativado na v5.13.2.', 500),
  ('transmutacao', 'Transmutação', 'crafting', 'Transforma ervas e óleos em suprimentos médicos, como Bandagens e Óleo de Sapo (Toad Oil). Ainda sem página própria detalhada na wiki.', 500),
  ('fuinjutsu', 'Fuinjutsu', 'crafting', 'Transforma Pergaminhos em Branco (Blank Scroll) em pergaminhos de jutsu selados e, no topo da progressão, Contratos de Invocação. Ainda sem página própria detalhada na wiki.', 500)
on conflict (slug) do update set
  name = excluded.name,
  category = excluded.category,
  description = excluded.description,
  level_cap = excluded.level_cap;

-- ---------------------------------------------------------------
-- Seed: itens novos (produtos e ingredientes de receita)
-- ---------------------------------------------------------------
insert into items (name, type) values
  ('Arapaima', 'consumivel'),
  ('Black High Heel Boots', 'consumivel'),
  ('Black Tenegui Towel Hat', 'consumivel'),
  ('Blight Leechskin Scarf', 'consumivel'),
  ('Blobfish', 'consumivel'),
  ('Blue Berries', 'consumivel'),
  ('Blue Berry Cake', 'consumivel'),
  ('Blue Catfish', 'consumivel'),
  ('Blue Shark', 'consumivel'),
  ('Blue Tenegui Towel Hat', 'consumivel'),
  ('Bottled Honey', 'consumivel'),
  ('Bread', 'consumivel'),
  ('Brown Catfish', 'consumivel'),
  ('Carrot', 'consumivel'),
  ('Crimson Leechskin Scarf', 'consumivel'),
  ('Crispy Fish', 'consumivel'),
  ('Dark Barbarian Cloak', 'consumivel'),
  ('Deep Sea Hotdog', 'consumivel'),
  ('Dwarf Gourami', 'consumivel'),
  ('Egg', 'consumivel'),
  ('Egg Sushi', 'consumivel'),
  ('Electric Fish', 'consumivel'),
  ('Fabric Sheets', 'consumivel'),
  ('Firefish', 'consumivel'),
  ('Fish Soup', 'consumivel'),
  ('Fish Sushi', 'consumivel'),
  ('Flour', 'consumivel'),
  ('Fried Egg', 'consumivel'),
  ('Green Tenegui Towel Hat', 'consumivel'),
  ('Grey Barbarian Cloak', 'consumivel'),
  ('Grey Shark', 'consumivel'),
  ('Grilled Arapaima', 'consumivel'),
  ('Honey & Herb Fish', 'consumivel'),
  ('Jellyfish', 'consumivel'),
  ('Jellyfish Takoyaki', 'consumivel'),
  ('Leaf Style Omelette', 'consumivel'),
  ('Leather Strips', 'consumivel'),
  ('Maki Sushi', 'consumivel'),
  ('Maki Sushi Hat', 'consumivel'),
  ('Milk', 'consumivel'),
  ('Mist Style Omelette', 'consumivel'),
  ('Penguin Wings', 'consumivel'),
  ('Pink Tenegui Towel Hat', 'consumivel'),
  ('Puppet Mask', 'consumivel'),
  ('Purple Tenegui Towel Hat', 'consumivel'),
  ('Reaper Death Sauce', 'consumivel'),
  ('Red Anchovy', 'consumivel'),
  ('Red Berries', 'consumivel'),
  ('Red Berry Cake', 'consumivel'),
  ('Red High Heel Boots', 'consumivel'),
  ('Red Tenegui Towel Hat', 'consumivel'),
  ('Rice', 'consumivel'),
  ('Rice Ball', 'consumivel'),
  ('Sand Style Omelette', 'consumivel'),
  ('Seaweed', 'consumivel'),
  ('Shark Curry', 'consumivel'),
  ('Sharks Fin', 'consumivel'),
  ('Slug Venom', 'consumivel'),
  ('Slugskin Scarf', 'consumivel'),
  ('Spicy Fried Shark', 'consumivel'),
  ('Spicy Fried Wings', 'consumivel'),
  ('Spider Eggs', 'consumivel'),
  ('Stylish Kunai Pants', 'consumivel'),
  ('Tadpole Egg', 'consumivel'),
  ('Takoyaki Hat', 'consumivel'),
  ('Tan Barbarian Cloak', 'consumivel'),
  ('Temaki', 'consumivel'),
  ('Tentacle', 'consumivel'),
  ('Tunneler Tongue', 'consumivel'),
  ('Vegetarian Instant Ramen', 'consumivel'),
  ('Vigilante Bandana Mask', 'consumivel'),
  ('Wanderer Shirt', 'consumivel'),
  ('Wool String', 'consumivel'),
  ('Yellow Tenegui Towel Hat', 'consumivel')
on conflict (lower(name)) do nothing;

-- ---------------------------------------------------------------
-- Seed: receitas (Tecelagem + Culinária)
-- ---------------------------------------------------------------
insert into proficiency_recipes (proficiency_id, name, output_item_id, level_required, success_rate_base, craft_time_seconds, requires_workbench, effect_description, notes) values
  ((select id from proficiencies where slug = 'tecelagem'), 'Leather Strips', (select id from items where lower(name) = lower('Leather Strips')), 5, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Wool String', (select id from items where lower(name) = lower('Wool String')), 8, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Takoyaki Hat', (select id from items where lower(name) = lower('Takoyaki Hat')), 8, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Blue Tenegui Towel Hat', (select id from items where lower(name) = lower('Blue Tenegui Towel Hat')), 9, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Fabric Sheets', (select id from items where lower(name) = lower('Fabric Sheets')), 10, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Green Tenegui Towel Hat', (select id from items where lower(name) = lower('Green Tenegui Towel Hat')), 10, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Blight Leechskin Scarf', (select id from items where lower(name) = lower('Blight Leechskin Scarf')), 11, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Pink Tenegui Towel Hat', (select id from items where lower(name) = lower('Pink Tenegui Towel Hat')), 11, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Crimson Leechskin Scarf', (select id from items where lower(name) = lower('Crimson Leechskin Scarf')), 12, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Purple Tenegui Towel Hat', (select id from items where lower(name) = lower('Purple Tenegui Towel Hat')), 12, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Slugskin Scarf', (select id from items where lower(name) = lower('Slugskin Scarf')), 13, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Red Tenegui Towel Hat', (select id from items where lower(name) = lower('Red Tenegui Towel Hat')), 13, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Yellow Tenegui Towel Hat', (select id from items where lower(name) = lower('Yellow Tenegui Towel Hat')), 14, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Black Tenegui Towel Hat', (select id from items where lower(name) = lower('Black Tenegui Towel Hat')), 15, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Red High Heel Boots', (select id from items where lower(name) = lower('Red High Heel Boots')), 18, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Black High Heel Boots', (select id from items where lower(name) = lower('Black High Heel Boots')), 19, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Stylish Kunai Pants', (select id from items where lower(name) = lower('Stylish Kunai Pants')), 25, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Vigilante Bandana Mask', (select id from items where lower(name) = lower('Vigilante Bandana Mask')), null, null, null, false, null, 'Receita obtida via drop de mob (fonte não registrada na wiki).'),
  ((select id from proficiencies where slug = 'tecelagem'), 'Puppet Mask', (select id from items where lower(name) = lower('Puppet Mask')), null, null, null, false, null, 'Receita obtida via drop de mob (fonte não registrada na wiki).'),
  ((select id from proficiencies where slug = 'tecelagem'), 'Wanderer Shirt', (select id from items where lower(name) = lower('Wanderer Shirt')), null, null, null, false, null, 'Receita obtida via drop de mob (fonte não registrada na wiki).'),
  ((select id from proficiencies where slug = 'tecelagem'), 'Maki Sushi Hat', (select id from items where lower(name) = lower('Maki Sushi Hat')), null, null, null, false, null, 'Receita obtida via drop de mob (fonte não registrada na wiki).'),
  ((select id from proficiencies where slug = 'tecelagem'), 'Dark Barbarian Cloak', (select id from items where lower(name) = lower('Dark Barbarian Cloak')), null, null, null, false, null, 'Receita obtida via drop do mob Black Bear.'),
  ((select id from proficiencies where slug = 'tecelagem'), 'Grey Barbarian Cloak', (select id from items where lower(name) = lower('Grey Barbarian Cloak')), null, null, null, false, null, 'Receita obtida via drop do mob Alpha Leopard.'),
  ((select id from proficiencies where slug = 'tecelagem'), 'Tan Barbarian Cloak', (select id from items where lower(name) = lower('Tan Barbarian Cloak')), null, null, null, false, null, 'Receita obtida via drop do mob Spirit Fox.'),
  ((select id from proficiencies where slug = 'culinaria'), 'Rice Ball', (select id from items where lower(name) = lower('Rice Ball')), null, 90.0, 2, false, 'Cura 100 HP e deixa o personagem descansado (leva 4s pra comer).', 'Base de sucesso confirmada em 90% (a única confirmada na wiki, no skill 0).'),
  ((select id from proficiencies where slug = 'culinaria'), 'Fried Egg', (select id from items where lower(name) = lower('Fried Egg')), null, 50.0, 2, false, 'Cura 100 HP e deixa o personagem descansado (leva 4s pra comer).', 'Base aproximada (~50%), lida a 1% de skill (91% e 50,5% respectivamente), não confirmada no skill 0.'),
  ((select id from proficiencies where slug = 'culinaria'), 'Maki Sushi', (select id from items where lower(name) = lower('Maki Sushi')), null, null, null, false, 'Cura 100 HP e deixa o personagem descansado (leva 4s pra comer).', 'Taxa de sucesso e tempo de craft não registrados.'),
  ((select id from proficiencies where slug = 'culinaria'), 'Egg Sushi', (select id from items where lower(name) = lower('Egg Sushi')), null, null, null, false, 'Cura 100 HP e deixa o personagem descansado (leva 4s pra comer).', 'Taxa de sucesso e tempo de craft não registrados.'),
  ((select id from proficiencies where slug = 'culinaria'), 'Fish Sushi', (select id from items where lower(name) = lower('Fish Sushi')), null, null, null, false, 'Cura 100 HP e deixa o personagem descansado (leva 4s pra comer).', 'Taxa de sucesso e tempo de craft não registrados.'),
  ((select id from proficiencies where slug = 'culinaria'), 'Leaf Style Omelette', (select id from items where lower(name) = lower('Leaf Style Omelette')), null, null, null, false, '+1 em todos os atributos por 30 minutos.', null),
  ((select id from proficiencies where slug = 'culinaria'), 'Mist Style Omelette', (select id from items where lower(name) = lower('Mist Style Omelette')), null, null, null, false, '+1 em todos os atributos por 30 minutos.', null),
  ((select id from proficiencies where slug = 'culinaria'), 'Sand Style Omelette', (select id from items where lower(name) = lower('Sand Style Omelette')), null, null, null, false, '+1 em todos os atributos por 30 minutos.', null),
  ((select id from proficiencies where slug = 'culinaria'), 'Blue Berry Cake', (select id from items where lower(name) = lower('Blue Berry Cake')), null, null, null, true, '+5 Intellect por 30 minutos.', null),
  ((select id from proficiencies where slug = 'culinaria'), 'Red Berry Cake', (select id from items where lower(name) = lower('Red Berry Cake')), null, null, null, true, '+5 Strength por 30 minutos.', null),
  ((select id from proficiencies where slug = 'culinaria'), 'Grilled Arapaima', (select id from items where lower(name) = lower('Grilled Arapaima')), null, null, null, false, '+5 Fortitude por 30 minutos.', 'Arapaima é uma pesca Rare (isca tier III).'),
  ((select id from proficiencies where slug = 'culinaria'), 'Crispy Fish', (select id from items where lower(name) = lower('Crispy Fish')), null, null, null, false, '+5 Agility por 30 minutos.', 'Brown Catfish é uma pesca Rare (isca tier II).'),
  ((select id from proficiencies where slug = 'culinaria'), 'Temaki', (select id from items where lower(name) = lower('Temaki')), null, null, null, false, '+5 Chakra por 30 minutos.', 'Blue Catfish é uma pesca Rare (isca tier II).'),
  ((select id from proficiencies where slug = 'culinaria'), 'Honey & Herb Fish', (select id from items where lower(name) = lower('Honey & Herb Fish')), null, null, null, false, '+3 em todos os atributos por 30 minutos.', 'Único prato que dá +3 em todos os atributos. Electric Fish é uma pesca Unique (isca tier III).'),
  ((select id from proficiencies where slug = 'culinaria'), 'Spicy Fried Wings', (select id from items where lower(name) = lower('Spicy Fried Wings')), 18, null, null, false, '+10 Agility, +4 Fortitude por 30 minutos.', 'Vendida pelo Chef em Takumi Village, exige Culinária 18+.'),
  ((select id from proficiencies where slug = 'culinaria'), 'Fish Soup', (select id from items where lower(name) = lower('Fish Soup')), 18, null, null, false, '+10 Intellect, +4 Fortitude por 30 minutos.', 'Vendida pelo Chef em Takumi Village, exige Culinária 18+.'),
  ((select id from proficiencies where slug = 'culinaria'), 'Spicy Fried Shark', (select id from items where lower(name) = lower('Spicy Fried Shark')), 18, null, null, false, '+10 Strength, +4 Chakra por 30 minutos.', 'Vendida pelo Chef em Takumi Village, exige Culinária 18+ (nome do jogo tem erro de grafia: "Strenght").'),
  ((select id from proficiencies where slug = 'culinaria'), 'Shark Curry', (select id from items where lower(name) = lower('Shark Curry')), 18, null, null, false, '+10 Strength, +4 Fortitude por 30 minutos.', 'Vendida pelo Chef em Takumi Village, exige Culinária 18+ (nome do jogo tem erro de grafia: "Strenght").'),
  ((select id from proficiencies where slug = 'culinaria'), 'Deep Sea Hotdog', (select id from items where lower(name) = lower('Deep Sea Hotdog')), 18, null, null, false, '+10 Agility, +4 Chakra por 30 minutos.', 'Vendida pelo Chef em Takumi Village, exige Culinária 18+.'),
  ((select id from proficiencies where slug = 'culinaria'), 'Jellyfish Takoyaki', (select id from items where lower(name) = lower('Jellyfish Takoyaki')), 18, null, null, false, '+10 Intellect, +4 Chakra por 30 minutos.', 'Vendida pelo Chef em Takumi Village, exige Culinária 18+. Jellyfish é a pesca de tier mais alto registrada (Baiting Basics IV).'),
  ((select id from proficiencies where slug = 'culinaria'), 'Reaper Death Sauce', (select id from items where lower(name) = lower('Reaper Death Sauce')), null, null, null, false, null, 'Único ingrediente usado noutras receitas (Spicy Fried Wings, Spicy Fried Shark) cuja própria receita não é vendida pelo Chef — ela dropa do mob Kiemon. Firefish é uma pesca Rare (isca tier III).')
on conflict (proficiency_id, name) do update set
  output_item_id = excluded.output_item_id,
  level_required = excluded.level_required,
  success_rate_base = excluded.success_rate_base,
  craft_time_seconds = excluded.craft_time_seconds,
  requires_workbench = excluded.requires_workbench,
  effect_description = excluded.effect_description,
  notes = excluded.notes;

-- ---------------------------------------------------------------
-- Seed: ingredientes das receitas de Culinária
-- ---------------------------------------------------------------
insert into proficiency_recipe_materials (recipe_id, item_id, quantity) values
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Rice Ball'), (select id from items where lower(name) = lower('Rice')), 5),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Fried Egg'), (select id from items where lower(name) = lower('Egg')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Maki Sushi'), (select id from items where lower(name) = lower('Rice Ball')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Maki Sushi'), (select id from items where lower(name) = lower('Seaweed')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Egg Sushi'), (select id from items where lower(name) = lower('Rice Ball')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Egg Sushi'), (select id from items where lower(name) = lower('Seaweed')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Egg Sushi'), (select id from items where lower(name) = lower('Tadpole Egg')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Fish Sushi'), (select id from items where lower(name) = lower('Rice Ball')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Fish Sushi'), (select id from items where lower(name) = lower('Seaweed')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Fish Sushi'), (select id from items where lower(name) = lower('Dwarf Gourami')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Leaf Style Omelette'), (select id from items where lower(name) = lower('Egg')), 2),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Leaf Style Omelette'), (select id from items where lower(name) = lower('Milk')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Leaf Style Omelette'), (select id from items where lower(name) = lower('Spider Eggs')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Mist Style Omelette'), (select id from items where lower(name) = lower('Egg')), 2),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Mist Style Omelette'), (select id from items where lower(name) = lower('Milk')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Mist Style Omelette'), (select id from items where lower(name) = lower('Sharks Fin')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Sand Style Omelette'), (select id from items where lower(name) = lower('Egg')), 2),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Sand Style Omelette'), (select id from items where lower(name) = lower('Milk')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Sand Style Omelette'), (select id from items where lower(name) = lower('Tunneler Tongue')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Blue Berry Cake'), (select id from items where lower(name) = lower('Flour')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Blue Berry Cake'), (select id from items where lower(name) = lower('Milk')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Blue Berry Cake'), (select id from items where lower(name) = lower('Blue Berries')), 5),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Blue Berry Cake'), (select id from items where lower(name) = lower('Egg')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Red Berry Cake'), (select id from items where lower(name) = lower('Flour')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Red Berry Cake'), (select id from items where lower(name) = lower('Milk')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Red Berry Cake'), (select id from items where lower(name) = lower('Egg')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Red Berry Cake'), (select id from items where lower(name) = lower('Red Berries')), 5),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Grilled Arapaima'), (select id from items where lower(name) = lower('Arapaima')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Grilled Arapaima'), (select id from items where lower(name) = lower('Bottled Honey')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Crispy Fish'), (select id from items where lower(name) = lower('Flour')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Crispy Fish'), (select id from items where lower(name) = lower('Egg')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Crispy Fish'), (select id from items where lower(name) = lower('Brown Catfish')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Temaki'), (select id from items where lower(name) = lower('Rice Ball')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Temaki'), (select id from items where lower(name) = lower('Seaweed')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Temaki'), (select id from items where lower(name) = lower('Blue Catfish')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Honey & Herb Fish'), (select id from items where lower(name) = lower('Flour')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Honey & Herb Fish'), (select id from items where lower(name) = lower('Bottled Honey')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Honey & Herb Fish'), (select id from items where lower(name) = lower('Electric Fish')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Spicy Fried Wings'), (select id from items where lower(name) = lower('Reaper Death Sauce')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Spicy Fried Wings'), (select id from items where lower(name) = lower('Flour')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Spicy Fried Wings'), (select id from items where lower(name) = lower('Penguin Wings')), 2),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Fish Soup'), (select id from items where lower(name) = lower('Vegetarian Instant Ramen')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Fish Soup'), (select id from items where lower(name) = lower('Carrot')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Fish Soup'), (select id from items where lower(name) = lower('Blobfish')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Fish Soup'), (select id from items where lower(name) = lower('Red Anchovy')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Spicy Fried Shark'), (select id from items where lower(name) = lower('Grey Shark')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Spicy Fried Shark'), (select id from items where lower(name) = lower('Reaper Death Sauce')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Spicy Fried Shark'), (select id from items where lower(name) = lower('Flour')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Shark Curry'), (select id from items where lower(name) = lower('Rice Ball')), 2),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Shark Curry'), (select id from items where lower(name) = lower('Carrot')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Shark Curry'), (select id from items where lower(name) = lower('Blue Shark')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Deep Sea Hotdog'), (select id from items where lower(name) = lower('Bread')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Deep Sea Hotdog'), (select id from items where lower(name) = lower('Tentacle')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Deep Sea Hotdog'), (select id from items where lower(name) = lower('Red Anchovy')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Jellyfish Takoyaki'), (select id from items where lower(name) = lower('Flour')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Jellyfish Takoyaki'), (select id from items where lower(name) = lower('Egg')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Jellyfish Takoyaki'), (select id from items where lower(name) = lower('Jellyfish')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Reaper Death Sauce'), (select id from items where lower(name) = lower('Firefish')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Reaper Death Sauce'), (select id from items where lower(name) = lower('Red Berries')), 2),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Reaper Death Sauce'), (select id from items where lower(name) = lower('Slug Venom')), 1)
on conflict (recipe_id, item_id) do update set
  quantity = excluded.quantity;
