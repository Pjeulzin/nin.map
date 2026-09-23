-- Migração 013: cadastro dos Anéis (Rings) do jogo, a partir de
-- https://ninonline.fandom.com/wiki/Rings e das 11 páginas individuais de
-- anel que tinham números exatos por raridade não repetidos no hub
-- (famílias Qi Ring, Chakra Vein Band e Spirit Rend Band).
--
-- Anéis são um tipo de equipamento cosmeticamente invisível — só dão
-- bônus de atributo, sem mudar a aparência do personagem. Cada anel
-- nomeado pode dropar em mais de uma raridade, cada raridade com um
-- bônus de atributo diferente (às vezes até duas variantes "Uncommon"
-- diferentes com o mesmo nome) — por isso os bônus ficam num array
-- jsonb `ring_variants` em vez de uma coluna fixa, um item por raridade
-- documentada.
--
-- 41 anéis cadastrados: 5 da família Qi Ring, 3 Chakra Vein Band, 3
-- Spirit Rend Band, 5 Bedrock Band, 4 Agate Ring, 5 Stargazer Ring, 12
-- Zodiac (incluindo Ring of the Jade Dragon, que não tem página própria
-- mas tem os dados completos no quadro-resumo da página Rings) e 4
-- avulsos sem família (Deathmarch Band, Eclipsed Crystal Ring, Shark
-- Tooth Ring, Moontide Pearl Ring).
--
-- Fora do escopo: o Kuronami Ring, que a própria wiki arquiva fora da
-- Category:Rings por ser restrito a membros da organização Neo-Akatsuki
-- (drop ao morrer, não faz parte do sistema normal de drop de anéis).
--
-- Lacunas de dados (documentadas por anel em `ring_notes`): variantes
-- Rare não capturadas de Granite/Basalt/Slate Bedrock Band nem Common de
-- Azurite Bedrock Band; Common/Uncommon do Iron Spirit Rend Band; uma
-- quinta cor (Fortitude) da família Agate Ring; a variante +7 do
-- Sapphire Stargazer Ring; e as variantes "4%"/"6%" mais fortes dos 3
-- anéis de crit/steal (Shark Tooth, Eclipsed Crystal, Deathmarch), das
-- quais só a mais fraca documentada (2% ou 4%) está aqui.
--
-- A família Qi Ring tem uma inconsistência da própria wiki entre
-- editores: a página da Sapphire Qi Ring descreve uma tabela de família
-- diferente da tabela genérica usada nas páginas de Amber/Amethyst/
-- Ruby/Topaz. Mantida como está — ver a nota da Sapphire Qi Ring.

alter table items add column if not exists ring_family text;
alter table items add column if not exists ring_level_required integer;
alter table items add column if not exists ring_variants jsonb;
alter table items add column if not exists ring_notes text;

create index if not exists items_ring_family_idx on items (ring_family);

-- ---------------------------------------------------------------
-- Seed: os 41 anéis
-- ---------------------------------------------------------------
insert into items (name, type, description, ring_family, ring_level_required, ring_variants, ring_notes) values
  ('Amber Qi Ring', 'anel', 'Originally developed by wandering ascetics, these rings harmonize with the user''s inner qi. They encourage a smoother circulation of chakra through the tenketsu points, slightly improving jutsu consistency and reducing wasted energy.', 'Qi Ring', 19, '[{"rarity": "Common", "stats": {"Strength": 1, "Agility": 1}}, {"rarity": "Uncommon", "stats": {"Strength": 2, "Agility": 1}}, {"rarity": "Uncommon", "stats": {"Strength": 1, "Agility": 2}}, {"rarity": "Rare", "stats": {"Strength": 2, "Agility": 2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Amethyst Qi Ring', 'anel', 'Originally developed by wandering ascetics, these rings harmonize with the user''s inner qi. They encourage a smoother circulation of chakra through the tenketsu points, slightly improving jutsu consistency and reducing wasted energy.', 'Qi Ring', 19, '[{"rarity": "Common", "stats": {"Intellect": 1, "Agility": 1}}, {"rarity": "Uncommon", "stats": {"Intellect": 2, "Agility": 1}}, {"rarity": "Uncommon", "stats": {"Intellect": 1, "Agility": 2}}, {"rarity": "Rare", "stats": {"Intellect": 2, "Agility": 2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Ruby Qi Ring', 'anel', 'Originally developed by wandering ascetics, these rings harmonize with the user''s inner qi. They encourage a smoother circulation of chakra through the tenketsu points, slightly improving jutsu consistency and reducing wasted energy.', 'Qi Ring', 19, '[{"rarity": "Common", "stats": {"Strength": 1, "Intellect": 1}}, {"rarity": "Uncommon", "stats": {"Strength": 2, "Intellect": 1}}, {"rarity": "Uncommon", "stats": {"Strength": 1, "Intellect": 2}}, {"rarity": "Rare", "stats": {"Strength": 2, "Intellect": 2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Topaz Qi Ring', 'anel', 'Originally developed by wandering ascetics, these rings harmonize with the user''s inner qi. They encourage a smoother circulation of chakra through the tenketsu points, slightly improving jutsu consistency and reducing wasted energy.', 'Qi Ring', 19, '[{"rarity": "Common", "stats": {"Intellect": 1, "Agility": 1}}, {"rarity": "Uncommon", "stats": {"Intellect": 2, "Agility": 1}}, {"rarity": "Uncommon", "stats": {"Intellect": 1, "Agility": 2}}, {"rarity": "Rare", "stats": {"Intellect": 2, "Agility": 2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Sapphire Qi Ring', 'anel', 'Originally developed by wandering ascetics, these rings harmonize with the user''s inner qi. They encourage a smoother circulation of chakra through the tenketsu points, slightly improving jutsu consistency and reducing wasted energy.', 'Qi Ring', 19, '[{"rarity": "Rare", "stats": {"Strength": 2, "Intellect": 2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Só a variante Rare está documentada nesta página; a tabela de família na própria página da Sapphire diverge da tabela genérica usada nas páginas de Amber/Amethyst/Ruby/Topaz (ali, Ruby aparece como Uncommon +1 Str/+2 Int e Topaz como Rare +2 Int/+2 Agi) — inconsistência da própria wiki entre editores, mantida como está, sem tentar reconciliar.'),
  ('Silver Chakra Vein Band', 'anel', 'An enhanced shinobi tool embedded with micro-channels designed to resonate with the body''s chakra network. The band boosts internal stability, improving chakra regulation during jutsu execution.', 'Chakra Vein Band', 7, '[{"rarity": "Common", "stats": {"Chakra": 1}}, {"rarity": "Uncommon", "stats": {"Chakra": 2}}, {"rarity": "Rare", "stats": {"Chakra": 3}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Steel Chakra Vein Band', 'anel', 'An enhanced shinobi tool embedded with micro-channels designed to resonate with the body''s chakra network. The band boosts internal stability, improving chakra regulation during jutsu execution.', 'Chakra Vein Band', 10, '[{"rarity": "Common", "stats": {"Chakra": 2}}, {"rarity": "Uncommon", "stats": {"Chakra": 3}}, {"rarity": "Rare", "stats": {"Chakra": 4}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Uncommon e Rare confirmados contra o card do jogo em 25/08/2026.'),
  ('Mithril Chakra Vein Band', 'anel', 'An enhanced shinobi tool embedded with micro-channels designed to resonate with the body''s chakra network. The band boosts internal stability, improving chakra regulation during jutsu execution.', 'Chakra Vein Band', 12, '[{"rarity": "Common", "stats": {"Fortitude": 2, "Chakra": 1}}, {"rarity": "Uncommon", "stats": {"Fortitude": 1, "Chakra": 2}}, {"rarity": "Rare", "stats": {"Fortitude": 2, "Chakra": 2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Rare confirmado contra o card do jogo em 14/08/2026.'),
  ('Copper Spirit Rend Band', 'anel', 'Crafted by monks who studied the boundary between body and soul, it slightly sharpens the wearer''s fortitude.', 'Spirit Rend Band', 6, '[{"rarity": "Common", "stats": {"Fortitude": 1}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Nível mais baixo entre os anéis documentados na wiki. Captado do card do jogo em 11/08/2026.'),
  ('Iron Spirit Rend Band', 'anel', 'Crafted by monks who studied the boundary between body and soul, it slightly sharpens the wearer''s fortitude.', 'Spirit Rend Band', 9, '[{"rarity": "Rare", "stats": {"Fortitude": 4}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Só a variante Rare foi confirmada; Common/Uncommon ainda não documentadas na wiki.'),
  ('Gold Spirit Rend Band', 'anel', 'Crafted by monks who studied the boundary between body and soul, it slightly sharpens the wearer''s fortitude.', 'Spirit Rend Band', 11, '[{"rarity": "Common", "stats": {"Fortitude": 1, "Chakra": 2}}, {"rarity": "Uncommon", "stats": {"Fortitude": 2, "Chakra": 1}}, {"rarity": "Rare", "stats": {"Fortitude": 2, "Chakra": 2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Granite Bedrock Band', 'anel', null, 'Bedrock Band', 42, '[{"rarity": "Common", "stats": {"Strength": 4, "Fortitude": 1}}, {"rarity": "Uncommon", "stats": {"Strength": 5}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Sem variante Rare documentada na wiki.'),
  ('Basalt Bedrock Band', 'anel', null, 'Bedrock Band', 42, '[{"rarity": "Common", "stats": {"Fortitude": 5}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Só a variante Common está documentada.'),
  ('Slate Bedrock Band', 'anel', null, 'Bedrock Band', 42, '[{"rarity": "Common", "stats": {"Fortitude": 1, "Intellect": 4}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Só a variante Common está documentada.'),
  ('Limestone Bedrock Band', 'anel', null, 'Bedrock Band', 42, '[{"rarity": "Common", "stats": {"Fortitude": 1, "Agility": 4}}, {"rarity": "Uncommon", "stats": {"Fortitude": 1, "Agility": 5}}, {"rarity": "Rare", "stats": {"Agility": 6}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Azurite Bedrock Band', 'anel', null, 'Bedrock Band', 42, '[{"rarity": "Uncommon", "stats": {"Fortitude": 1, "Chakra": 5}}, {"rarity": "Rare", "stats": {"Chakra": 6}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Sem variante Common documentada.'),
  ('Red Agate Ring', 'anel', null, 'Agate Ring', 30, '[{"rarity": "Common", "stats": {"Strength": 3}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Purple Agate Ring', 'anel', null, 'Agate Ring', 30, '[{"rarity": "Common", "stats": {"Intellect": 3}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Blue Agate Ring', 'anel', null, 'Agate Ring', 30, '[{"rarity": "Common", "stats": {"Chakra": 3}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Green Agate Ring', 'anel', null, 'Agate Ring', 30, '[{"rarity": "Uncommon", "stats": {"Agility": 4}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Nenhuma cor de Fortitude foi documentada — se a família seguir o padrão de 5 cores (como Bedrock e Stargazer), falta uma.'),
  ('Ruby Stargazer Ring', 'anel', null, 'Stargazer Ring', 55, '[{"rarity": "Common", "stats": {"Strength": 5}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Amethyst Stargazer Ring', 'anel', null, 'Stargazer Ring', 55, '[{"rarity": "Common", "stats": {"Fortitude": 5}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Garnet Stargazer Ring', 'anel', null, 'Stargazer Ring', 55, '[{"rarity": "Common", "stats": {"Intellect": 5}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Topaz Stargazer Ring', 'anel', null, 'Stargazer Ring', 55, '[{"rarity": "Common", "stats": {"Agility": 5}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Sapphire Stargazer Ring', 'anel', null, 'Stargazer Ring', 55, '[{"rarity": "Common", "stats": {"Chakra": 5}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Existe uma variante +7 citada nas notas de patch (retaggeada de Rare pra Unique na v5.13.5), ainda não capturada em detalhe.'),
  ('Ring of the Sacred Ox', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Strength": 6}, "costs": {"Agility": -2, "Chakra": -2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Boi. Um dos 12 Anéis do Zodíaco, adicionados em 17/02/2026 pro evento de Ano Novo Lunar, obtidos via Sealed Zodiac Ring dropado de mobs enfurecidos.'),
  ('Ring of the Brave Tiger', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Strength": 6}, "costs": {"Agility": -4}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Tigre.'),
  ('Ring of the Wild Horse', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Fortitude": 6}, "costs": {"Strength": -1, "Intellect": -1, "Agility": -1, "Chakra": -1}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Cavalo.'),
  ('Ring of the Wild Boar', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Fortitude": 6}, "costs": {"Strength": -1, "Intellect": -1, "Agility": -2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Javali.'),
  ('Ring of the Trickster Monkey', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Agility": 6}, "costs": {"Intellect": -2, "Chakra": -2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Macaco.'),
  ('Ring of the Charging Ram', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Chakra": 6}, "costs": {"Strength": -1, "Intellect": -2, "Agility": -1}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Carneiro.'),
  ('Ring of the Celestial Rat', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Chakra": 6}, "costs": {"Fortitude": -4}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Rato.'),
  ('Ring of the Moon Hare', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Agility": 7}, "costs": {"Strength": -1, "Fortitude": -2, "Chakra": -1}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Coelho.'),
  ('Ring of the Vigilant Bird', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Intellect": 7}, "costs": {"Fortitude": -2, "Chakra": -2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Galo.'),
  ('Ring of the Faithful Dog', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Intellect": 7}, "costs": {"Chakra": -4}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Cachorro.'),
  ('Ring of the Coiled Serpent', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Strength": 3, "Agility": 4}, "costs": {"Fortitude": -2, "Chakra": -2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Serpente.'),
  ('Ring of the Jade Dragon', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Fortitude": 4, "Chakra": 3}, "costs": {"Strength": -1, "Intellect": -1, "Agility": -2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Dragão. Sem página própria na wiki — dados só do quadro-resumo da página Rings.'),
  ('Deathmarch Band', 'anel', null, null, 65, '[{"rarity": "Unique", "stats": {"Fortitude": 2}, "percent": {"Life Steal": "2%"}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Retaggeado de Rare pra Unique na v5.13.5 (drop agora anunciado no chat global). A wiki documenta a variante 2%; uma variante 4% é citada mas não descrita em detalhe.'),
  ('Eclipsed Crystal Ring', 'anel', null, null, 65, '[{"rarity": "Unique", "stats": {"Chakra": 2}, "percent": {"Chakra Steal": "2%"}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Retaggeado de Rare pra Unique na v5.13.5 (drop agora anunciado no chat global). A wiki documenta a variante 2%; uma variante 4% é citada mas não descrita em detalhe.'),
  ('Shark Tooth Ring', 'anel', null, null, 49, '[{"rarity": "Unique", "stats": {"Strength": 1, "Agility": 1}, "percent": {"Critical Rate": "4%"}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Retaggeado de Rare pra Unique na v5.13.5. Uma variante 6% é citada mas não descrita em detalhe. Sem página própria — dados só do quadro-resumo da página Rings.'),
  ('Moontide Pearl Ring', 'anel', null, null, 50, '[{"rarity": "Legendary", "stats": {"Chakra": 8}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Único anel Legendary visto até agora. Dropa do mob Shinkai Crab (abaixo de 1%). Adicionado em 15/09/2026.')
on conflict (lower(name)) do update set
  ring_family = excluded.ring_family,
  ring_level_required = excluded.ring_level_required,
  ring_variants = excluded.ring_variants,
  ring_notes = excluded.ring_notes
where items.type = 'anel';
