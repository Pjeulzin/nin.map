-- Migração 019: cadastro dos itens da Cash Shop (loja de Nin Credits/NC),
-- extraídos de https://ninonline.fandom.com/wiki/Cash_Shop e das páginas
-- que ela referencia: Outfits, Premium Hairstyles, Skins & Eyes, Cash
-- Shop Game Items e Furniture.
--
-- Duas colunas novas em `items`, nulas pra item comum:
--   - price_nc: preço em Nin Credits (NC), a moeda paga da Cash Shop.
--     Usada em vez de `clothing_price_ryo`/`clothing_price_text` (que
--     cobrem preço em Ryo ou o USD histórico do Cash Shop antigo,
--     migração 015) porque é um número, pesquisável, e se aplica tanto
--     a roupas quanto a consumíveis desta migração.
--   - price_nc_notes: detalhes do card da Cash Shop que não cabem em
--     `price_nc` -- stack size, se pode ser trocado/destruído, ou (pros
--     hairstyles) a atualização e o artista que a wiki documenta.
--
-- 353 linhas entram/são enriquecidas nesta migração:
--
-- 1) Outfits (215 itens de
--    https://ninonline.fandom.com/wiki/Outfits, incluindo as sub-seções
--    "Pals (Companions)" e "Functional", ver itens 2 e 3 abaixo): 36 já
--    existiam em `items` como `type = 'roupa'` da migração 015
--    (cadastrados com preço em USD do Cash Shop antigo, entre eles o
--    Rat Pal) -- essas só ganham `price_nc` preenchido, sem tocar em
--    descrição/raridade/preço em USD já cadastrados. As outras 179 são
--    novas.
--
--    `clothing_slot` aqui é a seção da própria página da wiki (ex.
--    "Vests, Robes & Body", "Hats & Head", "Masks & Eyewear") em vez de
--    um slot por item -- a página lista só ícone/nome/preço por item,
--    sem detalhar o slot de equipamento individual como as páginas
--    dedicadas faziam na migração 015; usar a seção como veio da wiki é
--    mais honesto que inferir um slot que a fonte não documenta.
--
--    `description` fica null pra todas as novas -- a página lista só
--    ícone, nome e preço, sem texto de descrição por item (diferente
--    das páginas dedicadas de item usadas nas migrações anteriores).
--
-- 2) Pals (8, sub-seção "Pals (Companions)"): cosméticos de companion
--    que seguem o personagem. Uma delas, Rat Pal, já existia (migração
--    015, `clothing_slot = 'Pet'`) -- as outras 7 entram novas com o
--    mesmo `clothing_slot = 'Pet'`, seguindo o precedente já registrado.
--
-- 3) Functional (6, sub-seção "Functional": Merchant Cart, Summoner
--    Scroll, 4 Military Carrier Scrolls de cor, todas novas):
--    cosméticos "de utilidade" que não são nem roupa no sentido usual
--    nem consumível de uso único -- a wiki não documenta o que cada um
--    faz além do nome/preço. Entraram como `type = 'roupa'`,
--    `clothing_slot = 'Functional'`, sem inventar uma descrição de
--    mecânica que a wiki não dá.
--
-- 4) Premium Hairstyles (151, de
--    https://ninonline.fandom.com/wiki/Premium_Hairstyles: 136 a 890 NC
--    + 15 básicas a 260 NC): nenhuma existia antes -- hairstyles nunca
--    tinham sido cadastradas. Entram como `type = 'roupa'`,
--    `clothing_slot = 'Hairstyle'`. Quando a wiki documenta a
--    atualização/artista de uma hairstyle específica, isso vai pro
--    `price_nc_notes` (a maioria não tem essa informação -- a wiki
--    mesma deixa em branco).
--
-- 5) Skins & Eyes (10, de
--    https://ninonline.fandom.com/wiki/Skins_%26_Eyes): mudam skin do
--    corpo, cor/estilo de olho ou cor da montaria -- são "aplicados"
--    uma vez, não equipados num slot permanente, então entraram como
--    `type = 'consumivel'` em vez de `'roupa'`.
--
-- 6) Cash Shop Game Items (10, de
--    https://ninonline.fandom.com/wiki/Cash_Shop_Game_Items): itens de
--    conta/utilidade (Name Changer, Scroll of Stat Reset, Inventory
--    Expansion, World Blessings, etc.) -- `type = 'consumivel'`. O "New
--    Ninja Free Gift" é gratuito (a wiki marca "Free", não um valor em
--    NC) -- `price_nc` ficou null com a nota explicando.
--
-- 7) Furniture (só os 3 itens realmente vendidos na Cash Shop: Grand
--    Piano, Palace Pillar, White Neo Cash Register). A categoria
--    Furniture da wiki tem 9 páginas no total, mas 6 ficaram FORA desta
--    migração por não serem itens de Cash Shop: Battlefield Memorial,
--    War Banner e War Pillar vêm da War Event Shop (moeda/evento
--    diferente); Chateau Bookshelf II e Dark Monkey King Trophy não têm
--    fonte de Cash Shop documentada (o segundo é drop de mob); e
--    Toranin Store é craftável (não comprável). Os 3 itens cadastrados
--    entram como `type = 'roupa'`, `clothing_slot = 'Furniture'`,
--    seguindo o mesmo padrão usado pra Pals/Functional -- mobília não é
--    "vestível" no sentido literal, mas reaproveita a mesma coluna em
--    vez de criar uma tabela nova só pra 3 linhas.
--
-- Fora de escopo desta migração: os itens ligados de Furniture, War
-- Event, mob drop e crafting citados acima (pertencem a outros sistemas
-- e podem virar seu próprio cadastro depois).

alter table items add column if not exists price_nc integer;
alter table items add column if not exists price_nc_notes text;
create index if not exists items_price_nc_idx on items (price_nc);

-- ---------------------------------------------------------------
-- Outfits (incl. Pals e Functional): 179 itens novos
-- ---------------------------------------------------------------

insert into items (name, type, description, clothing_slot, clothing_price_text, clothing_source, price_nc) values
  ('Full Metal Arm', 'roupa', null, 'Accessories', '890 NC', 'Cash Shop', 890),
  ('Regal Shoulderguard', 'roupa', null, 'Accessories', '440 NC', 'Cash Shop', 440),
  ('5 O''Clock Shadow', 'roupa', null, 'Beards & Facial Hair', '890 NC', 'Cash Shop', 890),
  ('Large Crescent Beard', 'roupa', null, 'Beards & Facial Hair', '890 NC', 'Cash Shop', 890),
  ('Moustache Beard', 'roupa', null, 'Beards & Facial Hair', '890 NC', 'Cash Shop', 890),
  ('Playboy Beard', 'roupa', null, 'Beards & Facial Hair', '890 NC', 'Cash Shop', 890),
  ('Sensei Beard', 'roupa', null, 'Beards & Facial Hair', '890 NC', 'Cash Shop', 890),
  ('Injustice Cape', 'roupa', null, 'Capes', '890 NC', 'Cash Shop', 890),
  ('Arctic Fox Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Black & Pink Cat Ears', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Black & Pink Cat Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Black & White Cat Ears', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Black & White Cat Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Black Fox Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Bunny Ears', 'roupa', null, 'Ears, Tails & Animal Features', '740 NC', 'Cash Shop', 740),
  ('Mystic Fox Ears', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Orange Fox Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('White & Black Cat Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('White & Blue Cat Ears', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('White & Blue Cat Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('White & Pink Cat Ears', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('White & Pink Cat Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Wolf Ears', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Wolf Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Blue Military Carrier Scroll', 'roupa', null, 'Functional', '890 NC', 'Cash Shop', 890),
  ('Green Military Carrier Scroll', 'roupa', null, 'Functional', '890 NC', 'Cash Shop', 890),
  ('Merchant Cart', 'roupa', null, 'Functional', '890 NC', 'Cash Shop', 890),
  ('Purple Military Carrier Scroll', 'roupa', null, 'Functional', '890 NC', 'Cash Shop', 890),
  ('Red Military Carrier Scroll', 'roupa', null, 'Functional', '890 NC', 'Cash Shop', 890),
  ('Summoner Scroll', 'roupa', null, 'Functional', '890 NC', 'Cash Shop', 890),
  ('Black Cap', 'roupa', null, 'Hats & Head', '440 NC', 'Cash Shop', 440),
  ('Black Cat Ear Bucket Hat', 'roupa', null, 'Hats & Head', '890 NC', 'Cash Shop', 890),
  ('Black Sailor Hat', 'roupa', null, 'Hats & Head', '890 NC', 'Cash Shop', 890),
  ('Dark Blue Cap', 'roupa', null, 'Hats & Head', '440 NC', 'Cash Shop', 440),
  ('Flytrap Hat', 'roupa', null, 'Hats & Head', '890 NC', 'Cash Shop', 890),
  ('Gray Cat Ear Bucket Hat', 'roupa', null, 'Hats & Head', '890 NC', 'Cash Shop', 890),
  ('Green Cap', 'roupa', null, 'Hats & Head', '440 NC', 'Cash Shop', 440),
  ('Pink Cap', 'roupa', null, 'Hats & Head', '440 NC', 'Cash Shop', 440),
  ('Pink Cat Ear Bucket Hat', 'roupa', null, 'Hats & Head', '890 NC', 'Cash Shop', 890),
  ('Purple Cap', 'roupa', null, 'Hats & Head', '440 NC', 'Cash Shop', 440),
  ('Red Cap', 'roupa', null, 'Hats & Head', '440 NC', 'Cash Shop', 440),
  ('Royal Crown', 'roupa', null, 'Hats & Head', '890 NC', 'Cash Shop', 890),
  ('Royal Tiara', 'roupa', null, 'Hats & Head', '890 NC', 'Cash Shop', 890),
  ('White Cap', 'roupa', null, 'Hats & Head', '440 NC', 'Cash Shop', 440),
  ('Yellow Ducky Bucket Hat', 'roupa', null, 'Hats & Head', '710 NC', 'Cash Shop', 710),
  ('Black Stylish Headphones', 'roupa', null, 'Headphones', '890 NC', 'Cash Shop', 890),
  ('Blue Stylish Headphones', 'roupa', null, 'Headphones', '890 NC', 'Cash Shop', 890),
  ('Green Stylish Headphones', 'roupa', null, 'Headphones', '890 NC', 'Cash Shop', 890),
  ('Pink Cute Headphones', 'roupa', null, 'Headphones', '890 NC', 'Cash Shop', 890),
  ('Purple Stylish Headphones', 'roupa', null, 'Headphones', '890 NC', 'Cash Shop', 890),
  ('Red Stylish Headphones', 'roupa', null, 'Headphones', '890 NC', 'Cash Shop', 890),
  ('Yellow Stylish Headphones', 'roupa', null, 'Headphones', '890 NC', 'Cash Shop', 890),
  ('Beige Jacket', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Black Cat Hoodie', 'roupa', null, 'Jackets & Coats', '890 NC', 'Cash Shop', 890),
  ('Black Jacket', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Blue Jacket', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Dark Fox Hoodie', 'roupa', null, 'Jackets & Coats', '890 NC', 'Cash Shop', 890),
  ('Fox Hoodie', 'roupa', null, 'Jackets & Coats', '890 NC', 'Cash Shop', 890),
  ('Fur Collared Beige Jacket', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Fur Collared Beige Jacket B', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Fur Collared Black Jacket', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Fur Collared Black Jacket B', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Fur Collared Black Jacket C', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Fur Collared Blue Jacket', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Fur Collared Blue Jacket B', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Fur Collared Red Jacket', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Fur Collared Red Jacket B', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Orange Cat Hoodie', 'roupa', null, 'Jackets & Coats', '890 NC', 'Cash Shop', 890),
  ('Red Jacket', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Beige Party Dress', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Black Party Dress', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Blue Party Dress', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Brown Katahada Kimono', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Gray Katahada Kimono', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Green Katahada Kimono', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Green Party Dress', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Orange Party Dress', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Peach Party Dress', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Red Katahada Kimono', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('White Party Dress', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Yellow Party Dress', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Black Goggles', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Blue Goggles', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Blue Power Detection Scopes', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Clear Big Round Glasses', 'roupa', null, 'Masks & Eyewear', '710 NC', 'Cash Shop', 710),
  ('Clear Visor', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Eye Scope', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Eye Wrapping Bandage', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Gray Face Mask', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Green Power Detection Scopes', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Inoshishi Mask', 'roupa', null, 'Masks & Eyewear', '890 NC', 'Cash Shop', 890),
  ('Red Power Detection Scopes', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Steel Visors', 'roupa', null, 'Masks & Eyewear', '890 NC', 'Cash Shop', 890),
  ('Tinted Big Round Glasses', 'roupa', null, 'Masks & Eyewear', '710 NC', 'Cash Shop', 710),
  ('White Face Mask', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Wooden Summon Mask', 'roupa', null, 'Masks & Eyewear', '890 NC', 'Cash Shop', 890),
  ('Fish Pal', 'roupa', null, 'Pet', '890 NC', 'Cash Shop', 890),
  ('Kitty Pal', 'roupa', null, 'Pet', '890 NC', 'Cash Shop', 890),
  ('Monkey Pal', 'roupa', null, 'Pet', '890 NC', 'Cash Shop', 890),
  ('Owl Pal', 'roupa', null, 'Pet', '890 NC', 'Cash Shop', 890),
  ('Piggy Pal', 'roupa', null, 'Pet', '890 NC', 'Cash Shop', 890),
  ('Puppy Pal', 'roupa', null, 'Pet', '890 NC', 'Cash Shop', 890),
  ('Sluggy Pal', 'roupa', null, 'Pet', '890 NC', 'Cash Shop', 890),
  ('Blue Sensei Scarf', 'roupa', null, 'Scarves', '890 NC', 'Cash Shop', 890),
  ('Leaf Sensei Scarf', 'roupa', null, 'Scarves', '890 NC', 'Cash Shop', 890),
  ('Mist Sensei Scarf', 'roupa', null, 'Scarves', '890 NC', 'Cash Shop', 890),
  ('Red Wanderers Scarf', 'roupa', null, 'Scarves', '710 NC', 'Cash Shop', 710),
  ('Sand Sensei Scarf', 'roupa', null, 'Scarves', '890 NC', 'Cash Shop', 890),
  ('Beige Cozy Sweater', 'roupa', null, 'Sweaters', '710 NC', 'Cash Shop', 710),
  ('Black Cozy Sweater', 'roupa', null, 'Sweaters', '710 NC', 'Cash Shop', 710),
  ('Blue Cozy Sweater', 'roupa', null, 'Sweaters', '710 NC', 'Cash Shop', 710),
  ('Green Cozy Sweater', 'roupa', null, 'Sweaters', '710 NC', 'Cash Shop', 710),
  ('Pink Cozy Sweater', 'roupa', null, 'Sweaters', '710 NC', 'Cash Shop', 710),
  ('Purple Cozy Sweater', 'roupa', null, 'Sweaters', '710 NC', 'Cash Shop', 710),
  ('Red Cozy Sweater', 'roupa', null, 'Sweaters', '710 NC', 'Cash Shop', 710),
  ('White Cozy Sweater', 'roupa', null, 'Sweaters', '710 NC', 'Cash Shop', 710),
  ('Blue Curse Mark Tattoo', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Kanku Markings Blue', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Kanku Markings Green', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Kanku Markings Pink', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Kanku Markings Red', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Kiba Markings Blue', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Kiba Markings Green', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Kiba Markings Pink', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Kiba Markings Red', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Agent Formal Pants', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Agent Formal Suit', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Black Boxer Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Black Hashi Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Black High-Collar Shirt', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Black Uzushi Pants', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Blue Battle High-Collar Shirt', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Blue Boxer Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Blue Hashi Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Blue Hashi Uniform', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Blue Samurai Vest', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Blue Uzushi Pants', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Blue War Armor', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Boxer Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Dark Ghillie Suit', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Delinquent Uniform', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Flamezu Pants', 'roupa', null, 'Vests, Robes & Body', '440 NC', 'Cash Shop', 440),
  ('Forsaken Exile Robe', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Fox Jacket', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Green Hashi Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Green High-Collar Shirt', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Green Samurai Vest', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Grey Boxer Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Izaku Robe', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Light Ghillie Suit', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Magma War Armor', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Orange Shoes', 'roupa', null, 'Vests, Robes & Body', '440 NC', 'Cash Shop', 440),
  ('Orange Uzushi Pants', 'roupa', null, 'Vests, Robes & Body', '440 NC', 'Cash Shop', 440),
  ('Oto Robe', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Pink Bow Kimono', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Pink Nurse Outfit', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Purple Boxer Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Purple High-Collar Shirt', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Purple Samurai Vest', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Reanimated Robe', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Red Furred Armor', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Red Hashi Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Red High-Collar Shirt', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Red Samurai Vest', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Sand Black Kimono', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Sand Boxer Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Sand Ghillie Suit', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Scorpion Jacket', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Shark Jacket', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Snowy Ghillie Suit', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Teal High-Collar Shirt', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Training Robe', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Two Tone Water Robes', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('White A-Ranker Pants', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('White A-Ranker Shirt', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('White Boxer Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('White Hashi Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('White Izaku Robe', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Yellow Hashi Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710)
on conflict (lower(name)) do update set
  type = 'roupa',
  clothing_slot = coalesce(items.clothing_slot, excluded.clothing_slot),
  clothing_price_text = coalesce(items.clothing_price_text, excluded.clothing_price_text),
  clothing_source = coalesce(items.clothing_source, excluded.clothing_source),
  price_nc = excluded.price_nc
where items.type = 'roupa' or items.type = 'item_mob';

update items set price_nc = v.price_nc
from (values
  ('Sand War Armor', 890),
  ('Red Forsaken Exile Robe', 890),
  ('Green Hashi Uniform', 890),
  ('Red Hashi Uniform', 890),
  ('Black Hashi Uniform', 890),
  ('Red Jira Vest', 890),
  ('Yellow Flash Shirt', 710),
  ('Pink Hyu Shirt', 710),
  ('Green Hyu Shirt', 710),
  ('Blue Hyu Shirt', 710),
  ('Dojo Shirt', 710),
  ('Dojo Pants', 440),
  ('Black Katahada Kimono', 890),
  ('Blue Katahada Kimono', 890),
  ('Sand Ragged Cape', 890),
  ('Justice Cape', 890),
  ('Black Hermit Cape', 890),
  ('White Snake Rope Belt', 890),
  ('Red Cursed Sakkat', 890),
  ('Black Cursed Sakkat', 890),
  ('Floppy Bunny Ears', 740),
  ('Black Oni Half Mask', 890),
  ('White Fox Mask', 890),
  ('Bandage Face Mask', 890),
  ('Black Cowl', 890),
  ('Burnt Bandage Head Wraps', 890),
  ('Summer Sunglasses', 890),
  ('Phantom Mask', 710),
  ('Black Blindfold', 440),
  ('White Blindfold', 440),
  ('Blood Medic Mask', 440),
  ('Blood Visor', 440),
  ('Sakura Visor', 440),
  ('Gray Wanderers Scarf', 710),
  ('Red Curse Mark Tattoo', 440),
  ('Rat Pal', 890)
) as v(name, price_nc)
where lower(items.name) = lower(v.name) and items.type = 'roupa' and items.price_nc is null;

insert into items (name, type, description, clothing_slot, clothing_price_text, clothing_source, price_nc, price_nc_notes) values
  ('Afro Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Ahoge Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.7.9 (2025-07-30). Arte: Bell.'),
  ('Alchemist Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.9.9e (2025-10-12).'),
  ('Archangel Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Ashura Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Assassin Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.11.5 (2026-01-20).'),
  ('Attack Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Azure Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Bald Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Beast Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Big Spikes Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Blizzard Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Bolt Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Bone Marrow Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Bounty Hunter Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.13.4 (2026-07-03). Arte: Azuki.'),
  ('Bowl Cut Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Burn Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Buzz Cut Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Cascade Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Center Parting Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Cherry Blossom Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Cho Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Cloudwalker Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.13.0 (2026-05-22).'),
  ('Clown Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.11.1d (2026-01-12). Arte: Genshin.'),
  ('Cornrows Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Cowboy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Deadlocks Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Dietz Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Double Cornrow Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Dragon Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.11.1d (2026-01-12). Arte: Fuze.'),
  ('Drifter Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Earth Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Erox Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Executioner Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.11.8 (2026-01-26).'),
  ('Faded Locks Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Fairytale Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Fantasy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Fencer Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Flame Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Flash Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Flat Top Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Four-tailed Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Fusion Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Great Puff Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Gun Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Haiku Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Hanoka Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Hanzai Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Hard Spikes Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Healer Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Hermit Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Hero Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Hozuki Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Indara Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Jiang Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.8.4 (2025-08-09).'),
  ('Jugo Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Kaigaku Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Kakuru Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Kalinka Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Kasumi Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Kawa Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('King Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Leafy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Long Bump Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Long Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Long Ponytail Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Long Twin Tail Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Madra Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Maeve Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Mai Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.9.9e (2025-10-12).'),
  ('Mature Rebel Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('May Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Medium Bowl Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Medium Ponytail Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Messy Spiky Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Metro Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Mighty Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Mijikai Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Minerva Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Model Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Mohawk Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Monk Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.9.7 (2025-09-25).'),
  ('Mullet Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Naji Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Naru Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Neat Long Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Nerdy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Neutron Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Nobura Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('One Side Shave Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Ore Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Overlay Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Playboy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Pompadour Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Porcupine Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Prince Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Professor Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Punk Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.12.4 (2026-02-11). Arte: Fuze.'),
  ('Punk Star Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Raging Fire Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Rebel Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Rocker Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Ronin Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Royal Prince Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Saber Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update (2026-01-29).'),
  ('Salamander Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.11.8 (2026-01-26).'),
  ('Samurai Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Sanemi Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Satan Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Sato Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Sharp Bangs Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Shaved Sides Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Shippu Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Short Dreads Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Short Messy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Short Pony Tail Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Short Ponytail Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Short Wavy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Shu Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Slickback Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Slugnir Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.8.6 (2025-08-15).'),
  ('Sly Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Sniper Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Sohei Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Soloist Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.8.6 (2025-08-15).'),
  ('Spellbound Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Spiky Highforehead Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Spiky Messy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Spiky Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Spiky Top Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Split Afro Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Star Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Sui Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Summers Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Swordsman Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Tachi Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Tear Drops Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('The Ghoul''s of Blizzard Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('The Guardian''s Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('The Lonely Vagabond Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('The Queen Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('The Wanderers Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Titan Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Tsunami Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.10.1 (2025-11-22).'),
  ('Twin Buns Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Twin Tails Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Viking Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Volume Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Wavy Curtain Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Wavy Messy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Wolfcut Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.11.1d (2026-01-12). Arte: Kvaset.')
on conflict (lower(name)) do update set
  type = 'roupa',
  clothing_slot = 'Hairstyle',
  clothing_price_text = excluded.clothing_price_text,
  clothing_source = 'Cash Shop',
  price_nc = excluded.price_nc,
  price_nc_notes = excluded.price_nc_notes
where items.type = 'roupa' or items.type = 'item_mob';


-- ---------------------------------------------------------------
-- Skins & Eyes: 10 itens novos (type = 'consumivel')
-- ---------------------------------------------------------------
insert into items (name, type, description, price_nc) values
  ('Bandaged Skin', 'consumivel', 'A body skin wrapped in bandages.', 4400),
  ('Rikudo Skin', 'consumivel', 'A Sage-of-Six-Paths styled body skin.', 4400),
  ('Super Eye Color Changer', 'consumivel', 'Unlocks premium/animated eye color options.', 9400),
  ('Skin Color Dye', 'consumivel', 'Changes your character''s skin color.', 890),
  ('Mount Dye', 'consumivel', 'Changes the color of your mount.', 890),
  ('Eye Color Changer', 'consumivel', 'Changes your eye color.', 890),
  ('Eye Style Changer', 'consumivel', 'Changes your eye style.', 890),
  ('Muscle Skin', 'consumivel', 'A muscular body skin.', 890),
  ('Sexy No Jutsu', 'consumivel', 'A transformation body skin.', 890),
  ('Normal Skin', 'consumivel', 'Resets your character to the default skin.', 260)
on conflict (lower(name)) do update set
  type = 'consumivel',
  description = coalesce(items.description, excluded.description),
  price_nc = excluded.price_nc
where items.type = 'consumivel' or items.type = 'item_mob';

-- ---------------------------------------------------------------
-- Cash Shop Game Items: 10 itens novos (type = 'consumivel')
-- ---------------------------------------------------------------
insert into items (name, type, description, price_nc, price_nc_notes) values
  ('Royalty Collection Pack', 'consumivel', 'Royal Prince Hairstyle, Monkey Pal, Regal Shoulderguard, and 4x Palace Pillars.', 2700, 'Hold 1. Cannot be traded or destroyed.'),
  ('1000 Ninja Credit Chest', 'consumivel', 'Converts into 1000 Nin Credits (NC) when consumed.', 1000, 'Can be traded. Stack to 1000.'),
  ('Name Changer', 'consumivel', 'Renames your account to any available name, or one inactive 2+ years.', 890, 'Stack to 10. Cannot be traded or destroyed.'),
  ('Scroll of Stat Reset', 'consumivel', 'Resets your stats when used.', 890, 'Stack to 29k. Cannot be traded or destroyed.'),
  ('Inventory Expansion', 'consumivel', 'Unlocks 40 additional inventory slots permanently.', 890, 'Hold 1. Cannot be traded. (Premium)'),
  ('Guild Experience Booster Pack', 'consumivel', 'A random amount of tiered Scrolls of Guild Experience.', 620, 'Stack to 29k. Cannot be traded or destroyed.'),
  ('Premium Messenger Hawk 10 Pack', 'consumivel', 'Broadcast a message (up to 240 chars) to your village or the whole world.', 440, 'Hold 5.'),
  ('World Blessing (EXP Rate)', 'consumivel', 'Gives everyone online a 1.5x EXP rate; your name is shown to those benefiting.', 440, 'Stack to 29k.'),
  ('World Blessing (Drop Rate)', 'consumivel', 'Gives everyone online an increased item drop rate; your name is shown to those benefiting.', 440, 'Stack to 29k.'),
  ('New Ninja Free Gift', 'consumivel', 'A starter redemption pack to help new players.', null, '"Free" no card, não um preço em NC. Hold 1. Cannot be traded. (Unique)')
on conflict (lower(name)) do update set
  type = 'consumivel',
  description = coalesce(items.description, excluded.description),
  price_nc = excluded.price_nc,
  price_nc_notes = excluded.price_nc_notes
where items.type = 'consumivel' or items.type = 'item_mob';

-- ---------------------------------------------------------------
-- Furniture (só os 3 itens vendidos na Cash Shop): type = 'roupa',
-- clothing_slot = 'Furniture'
-- ---------------------------------------------------------------
insert into items (name, type, description, clothing_slot, clothing_price_text, clothing_source, price_nc) values
  ('Grand Piano', 'roupa', 'A large black grand piano that can be placed and rotated freely inside a player''s house.', 'Furniture', '440 NC', 'Cash Shop', 440),
  ('Palace Pillar', 'roupa', 'An ornate red-and-gold pillar that can be placed and rotated freely inside a player''s house. Four Palace Pillars are also included in the Royalty Collection Pack.', 'Furniture', '260 NC', 'Cash Shop', 260),
  ('White Neo Cash Register', 'roupa', 'Placed in a player''s house, it opens a personal shop with 20 shop slots that holds stocks of items and sells them to other players while you are offline. Also comes in Red, Purple, Pink and Teal recolors.', 'Furniture', '890 NC', 'Cash Shop', 890)
on conflict (lower(name)) do update set
  type = 'roupa',
  description = coalesce(items.description, excluded.description),
  clothing_slot = coalesce(items.clothing_slot, excluded.clothing_slot),
  clothing_price_text = coalesce(items.clothing_price_text, excluded.clothing_price_text),
  clothing_source = coalesce(items.clothing_source, excluded.clothing_source),
  price_nc = excluded.price_nc
where items.type = 'roupa' or items.type = 'item_mob';
