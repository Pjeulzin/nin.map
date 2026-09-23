-- Campos extras pra página de detalhes de mobs, NPCs e maestrias
-- (estrutura inspirada em ninonline.fandom.com/wiki: cada mob/boss lá
-- tem imagem, descrição/lore, habilidades especiais nomeadas — e cada
-- maestria tem um texto de "como jogar" além da lista de técnicas).

alter table mobs add column if not exists description text;
alter table mobs add column if not exists image_url text;
alter table mobs add column if not exists special_abilities text[] not null default '{}';

alter table npcs add column if not exists image_url text;

alter table masteries add column if not exists playstyle_notes text;
