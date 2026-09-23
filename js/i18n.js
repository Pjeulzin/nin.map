/**
 * Textos da interface em português e inglês, e os helpers pra usá-los.
 *
 * Isso traduz só a INTERFACE do site (menus, filtros, rótulos). O
 * conteúdo cadastrado no admin (nomes/descrições de missões, mobs e
 * itens) continua no idioma em que foi digitado — isso foi uma
 * escolha consciente pra não duplicar cadastro.
 *
 * Uso em HTML estático: `<span data-i18n="nav_map">Mapa</span>` — o
 * texto dentro da tag é o fallback em português, trocado assim que
 * applyStaticTranslations() roda.
 * Uso em JS: `import { t } from "./i18n.js"; t("missions_loading")`.
 */

const STRINGS = {
  pt: {
    nav_map: "Mapa",
    nav_missions: "Missões",
    nav_mobs: "Mobs",
    nav_items: "Itens",
    nav_npcs: "NPCs",
    nav_masteries: "Maestrias",
    nav_jutsus: "Jutsus",
    nav_builds: "Builds",
    nav_admin: "Admin",
    nav_menu: "Menu",

    village_placeholder: "Sua vila...",
    server_placeholder: "Servidor...",
    btn_center: "Centralizar",
    footer_credit: "Criado por",
    footer_map:
      "Mapas placeholder — troque as imagens em assets/ pelas imagens reais de cada arco (veja js/config.js).",

    filter_all_villages: "Todas as vilas",
    filter_all_types: "Todos os tipos",
    filter_all_arcos: "Todos os arcos",
    filter_all_ranks: "Todos os ranks",
    filter_all_categories: "Todas as categorias",
    filter_all_combat: "Passivo e agressivo",
    filter_all_masteries: "Todas as maestrias",
    search_items_placeholder: "Pesquisar por nome...",

    missions_loading: "Carregando missões...",
    missions_none: "Nenhuma missão encontrada.",
    missions_supabase_off:
      "Supabase ainda não configurado — edite js/supabase-config.js com a URL e a anon key do seu projeto para ver as missões cadastradas.",
    missions_error: "Erro ao carregar missões: {msg}",

    mobs_loading: "Carregando mobs...",
    mobs_none: "Nenhum mob encontrado.",
    mobs_supabase_off:
      "Supabase ainda não configurado — edite js/supabase-config.js com a URL e a anon key do seu projeto para ver os mobs cadastrados.",
    mobs_error: "Erro ao carregar mobs: {msg}",

    items_loading: "Carregando itens...",
    items_none: "Nenhum item encontrado.",
    items_supabase_off:
      "Supabase ainda não configurado — edite js/supabase-config.js com a URL e a anon key do seu projeto para ver os itens cadastrados.",
    items_error: "Erro ao carregar itens: {msg}",

    npcs_loading: "Carregando NPCs...",
    npcs_none: "Nenhum NPC encontrado.",
    npcs_supabase_off:
      "Supabase ainda não configurado — edite js/supabase-config.js com a URL e a anon key do seu projeto para ver os NPCs cadastrados.",
    npcs_error: "Erro ao carregar NPCs: {msg}",

    masteries_loading: "Carregando maestrias...",
    masteries_none: "Nenhuma maestria encontrada.",
    masteries_supabase_off:
      "Supabase ainda não configurado — edite js/supabase-config.js com a URL e a anon key do seu projeto para ver as maestrias cadastradas.",
    masteries_error: "Erro ao carregar maestrias: {msg}",

    jutsus_loading: "Carregando jutsus...",
    jutsus_none: "Nenhum jutsu encontrado.",
    jutsus_supabase_off:
      "Supabase ainda não configurado — edite js/supabase-config.js com a URL e a anon key do seu projeto para ver os jutsus cadastrados.",
    jutsus_error: "Erro ao carregar jutsus: {msg}",

    label_level: "Nível",
    label_damage: "Dano",
    label_objective: "Objetivo",
    label_drops: "Drops",
    label_sells: "Vende",
    label_gives_mission: "Concede",
    label_gives_mission_from: "Concedida por",
    label_price: "Preço",
    label_stock: "Estoque",
    label_mastery: "Maestria",
    label_branch: "Ramificação",
    label_chakra: "Chakra",
    label_cooldown: "Cooldown",
    label_range: "Alcance",
    stock_unlimited: "ilimitado",
    location_unset: "Localização ainda não cadastrada",

    th_name: "Nome",
    th_type: "Tipo",
    th_description: "Descrição",
    th_dropped_by: "Dropado por",
    th_damage: "Dano",
    th_range: "Alcance",

    mission_type_global: "Global",
    mission_type_arco: "Exclusiva de arco",
    mission_type_evento: "Evento",
    mission_type_diaria: "Diária",

    mob_category_boss: "Boss",
    mob_category_enfurecido: "Enfurecido",
    mob_category_regular: "Regular",

    combat_type_passivo: "Passivo",
    combat_type_agressivo: "Agressivo",

    item_type_anel: "Anel",
    item_type_arma: "Arma",
    item_type_roupa: "Roupa",
    item_type_consumivel: "Consumível",
    item_type_item_mob: "Item de mob",

    npc_role_vendedor: "Vendedor",
    npc_role_concede_missao: "Concede missão",
    npc_role_parte_missao: "Parte de missão",
    npc_role_outro: "Outro",
    filter_all_roles: "Todos os papéis",

    weapon_category_espada: "Espada",
    weapon_category_kunai: "Kunai",
    weapon_category_shuriken: "Shuriken",
    weapon_category_bastao: "Bastão",
    weapon_category_outro: "Outro",

    level_any: "Qualquer nível",
    level_exact: "Nível {n}",
    level_range: "Nível {min} até {max}",
    level_min: "Nível +{n}",
    level_max: "Nível até {n}",

    damage_upto: "até {n}",

    detail_back_mobs: "← Voltar para mobs",
    detail_back_npcs: "← Voltar para NPCs",
    detail_back_masteries: "← Voltar para maestrias",
    detail_view: "Ver detalhes",
    detail_not_found: "Não encontrado.",
    detail_loading: "Carregando...",
    detail_section_about: "Sobre",
    detail_section_abilities: "Habilidades especiais",
    detail_section_drops: "Drops",
    detail_section_sells: "Itens à venda",
    detail_section_missions: "Missões",
    detail_section_jutsus: "Jutsus",
    detail_section_branches: "Ramificações",
    detail_section_playstyle: "Como jogar",
    detail_hp: "Vida",
    detail_xp: "XP",
    detail_col_item: "Item",
    detail_col_chance: "Chance",
    detail_col_qty: "Qtd.",
    detail_col_price: "Preço",
    detail_col_stock: "Estoque",
    detail_col_level: "Nível",
    detail_col_rank: "Rank",
    detail_col_chakra: "Chakra",
    detail_col_cooldown: "Cooldown",
    detail_source_note:
      "Estrutura de dados inspirada no ninonline.fandom.com/wiki — o conteúdo (texto, imagem, habilidades) é cadastrado manualmente no admin.",

    builds_title: "Monte seu personagem",
    builds_subtitle:
      "Escolha maestrias, arma, distribua pontos de atributo e veja os jutsus disponíveis — mesma lógica do NinForge.",
    builds_customization: "Personalização",
    builds_character_name: "Nome do personagem",
    builds_village: "Vila",
    builds_village_none: "Nenhuma",
    builds_mastery_1: "1ª Maestria",
    builds_mastery_2: "2ª Maestria",
    builds_mastery_unassigned: "Não escolhida",
    builds_corporation: "Corporação",
    builds_corporation_freelance: "Freelance",
    builds_guild_buff: "Buff de guild",
    builds_reset: "Redefinir personalização",
    builds_weapon: "Arma",
    builds_weapon_group: "Categoria",
    builds_weapon_group_none: "Nenhuma",
    builds_weapon_model: "Modelo",
    builds_weapon_model_none: "Nenhum (desarmado)",
    builds_weapon_requirements: "Requisitos",
    builds_weapon_buffs: "Bônus",
    builds_weapon_rarity: "Raridade",
    builds_status: "Status",
    builds_level: "Nível",
    builds_unallocated: "Pontos livres",
    builds_health: "Vida",
    builds_chakra: "Chakra",
    builds_auto_atk: "Ataque básico",
    builds_kunai: "Kunai",
    builds_shuriken: "Shuriken",
    builds_senbon: "Senbon",
    builds_rings: "Anéis",
    builds_ring_alpha: "Anel Alfa",
    builds_ring_beta: "Anel Beta",
    builds_ring_none: "Nenhum",
    builds_jutsus: "Jutsus",
    builds_jutsus_pick_mastery: "Escolha uma maestria pra ver os jutsus",
    builds_jutsu_locked: "Bloqueado",
    builds_jutsu_dmg: "Dano",
    builds_save_build: "Salvar build",
    builds_share_build: "Compartilhar build",
    builds_share_copied: "Link copiado!",
    builds_saved_builds: "Builds salvos",
    builds_no_saved: "Nenhuma build salva ainda. Monte uma acima e clique em \"Salvar build\".",
    builds_load: "Carregar",
    builds_delete: "Excluir",
    builds_summary: "Meu ninja",
    builds_specifications: "Especificações",
    builds_mastery_path: "Maestrias",
    builds_weapon_none: "Desarmado",
    builds_locked_reqs: "Requisitos não atendidos",
    builds_supabase_off: "Configure o Supabase pra usar o calculador de build.",
    builds_loading: "Carregando dados de build...",
    builds_error: "Erro ao carregar dados de build: {msg}",
  },

  en: {
    nav_map: "Map",
    nav_missions: "Missions",
    nav_mobs: "Mobs",
    nav_items: "Items",
    nav_npcs: "NPCs",
    nav_masteries: "Masteries",
    nav_jutsus: "Jutsu",
    nav_builds: "Builds",
    nav_admin: "Admin",
    nav_menu: "Menu",

    village_placeholder: "Your village...",
    server_placeholder: "Server...",
    btn_center: "Center",
    footer_credit: "Created by",
    footer_map:
      "Placeholder maps — replace the images in assets/ with the real map for each arc (see js/config.js).",

    filter_all_villages: "All villages",
    filter_all_types: "All types",
    filter_all_arcos: "All arcs",
    filter_all_ranks: "All ranks",
    filter_all_categories: "All categories",
    filter_all_combat: "Passive and aggressive",
    filter_all_masteries: "All masteries",
    search_items_placeholder: "Search by name...",

    missions_loading: "Loading missions...",
    missions_none: "No missions found.",
    missions_supabase_off:
      "Supabase isn't configured yet — edit js/supabase-config.js with your project's URL and anon key to see the registered missions.",
    missions_error: "Error loading missions: {msg}",

    mobs_loading: "Loading mobs...",
    mobs_none: "No mobs found.",
    mobs_supabase_off:
      "Supabase isn't configured yet — edit js/supabase-config.js with your project's URL and anon key to see the registered mobs.",
    mobs_error: "Error loading mobs: {msg}",

    items_loading: "Loading items...",
    items_none: "No items found.",
    items_supabase_off:
      "Supabase isn't configured yet — edit js/supabase-config.js with your project's URL and anon key to see the registered items.",
    items_error: "Error loading items: {msg}",

    npcs_loading: "Loading NPCs...",
    npcs_none: "No NPCs found.",
    npcs_supabase_off:
      "Supabase isn't configured yet — edit js/supabase-config.js with your project's URL and anon key to see the registered NPCs.",
    npcs_error: "Error loading NPCs: {msg}",

    masteries_loading: "Loading masteries...",
    masteries_none: "No masteries found.",
    masteries_supabase_off:
      "Supabase isn't configured yet — edit js/supabase-config.js with your project's URL and anon key to see the registered masteries.",
    masteries_error: "Error loading masteries: {msg}",

    jutsus_loading: "Loading jutsu...",
    jutsus_none: "No jutsu found.",
    jutsus_supabase_off:
      "Supabase isn't configured yet — edit js/supabase-config.js with your project's URL and anon key to see the registered jutsu.",
    jutsus_error: "Error loading jutsu: {msg}",

    label_level: "Level",
    label_damage: "Damage",
    label_objective: "Objective",
    label_drops: "Drops",
    label_sells: "Sells",
    label_gives_mission: "Gives",
    label_gives_mission_from: "Given by",
    label_price: "Price",
    label_stock: "Stock",
    label_mastery: "Mastery",
    label_branch: "Branch",
    label_chakra: "Chakra",
    label_cooldown: "Cooldown",
    label_range: "Range",
    stock_unlimited: "unlimited",
    location_unset: "Location not set yet",

    th_name: "Name",
    th_type: "Type",
    th_description: "Description",
    th_dropped_by: "Dropped by",
    th_damage: "Damage",
    th_range: "Range",

    mission_type_global: "Global",
    mission_type_arco: "Arc-exclusive",
    mission_type_evento: "Event",
    mission_type_diaria: "Daily",

    mob_category_boss: "Boss",
    mob_category_enfurecido: "Enraged",
    mob_category_regular: "Regular",

    combat_type_passivo: "Passive",
    combat_type_agressivo: "Aggressive",

    item_type_anel: "Ring",
    item_type_arma: "Weapon",
    item_type_roupa: "Clothing",
    item_type_consumivel: "Consumable",
    item_type_item_mob: "Mob item",

    npc_role_vendedor: "Vendor",
    npc_role_concede_missao: "Gives mission",
    npc_role_parte_missao: "Part of mission",
    npc_role_outro: "Other",
    filter_all_roles: "All roles",

    weapon_category_espada: "Sword",
    weapon_category_kunai: "Kunai",
    weapon_category_shuriken: "Shuriken",
    weapon_category_bastao: "Staff",
    weapon_category_outro: "Other",

    level_any: "Any level",
    level_exact: "Level {n}",
    level_range: "Level {min} to {max}",
    level_min: "Level +{n}",
    level_max: "Level up to {n}",

    damage_upto: "up to {n}",

    detail_back_mobs: "← Back to mobs",
    detail_back_npcs: "← Back to NPCs",
    detail_back_masteries: "← Back to masteries",
    detail_view: "View details",
    detail_not_found: "Not found.",
    detail_loading: "Loading...",
    detail_section_about: "About",
    detail_section_abilities: "Special abilities",
    detail_section_drops: "Drops",
    detail_section_sells: "Items for sale",
    detail_section_missions: "Missions",
    detail_section_jutsus: "Jutsu",
    detail_section_branches: "Branches",
    detail_section_playstyle: "How to play",
    detail_hp: "Health",
    detail_xp: "XP",
    detail_col_item: "Item",
    detail_col_chance: "Chance",
    detail_col_qty: "Qty.",
    detail_col_price: "Price",
    detail_col_stock: "Stock",
    detail_col_level: "Level",
    detail_col_rank: "Rank",
    detail_col_chakra: "Chakra",
    detail_col_cooldown: "Cooldown",
    detail_source_note:
      "Data structure inspired by ninonline.fandom.com/wiki — the content (text, image, abilities) is entered by hand in the admin panel.",

    builds_title: "Build your character",
    builds_subtitle:
      "Pick masteries, a weapon, allocate stat points and see which jutsu are available — same logic as NinForge.",
    builds_customization: "Customization",
    builds_character_name: "Character name",
    builds_village: "Village",
    builds_village_none: "None",
    builds_mastery_1: "1st Mastery",
    builds_mastery_2: "2nd Mastery",
    builds_mastery_unassigned: "Unassigned",
    builds_corporation: "Corporation",
    builds_corporation_freelance: "Freelance",
    builds_guild_buff: "Guild buff",
    builds_reset: "Reset customization",
    builds_weapon: "Weapon",
    builds_weapon_group: "Category",
    builds_weapon_group_none: "None",
    builds_weapon_model: "Model",
    builds_weapon_model_none: "None (unarmed)",
    builds_weapon_requirements: "Requirements",
    builds_weapon_buffs: "Buffs",
    builds_weapon_rarity: "Rarity",
    builds_status: "Status",
    builds_level: "Level",
    builds_unallocated: "Unallocated",
    builds_health: "Health",
    builds_chakra: "Chakra",
    builds_auto_atk: "Auto Atk",
    builds_kunai: "Kunai",
    builds_shuriken: "Shuriken",
    builds_senbon: "Senbon",
    builds_rings: "Rings",
    builds_ring_alpha: "Ring Alpha",
    builds_ring_beta: "Ring Beta",
    builds_ring_none: "None",
    builds_jutsus: "Jutsus",
    builds_jutsus_pick_mastery: "Select a mastery to view jutsus",
    builds_jutsu_locked: "Locked",
    builds_jutsu_dmg: "Dmg",
    builds_save_build: "Save build",
    builds_share_build: "Share build",
    builds_share_copied: "Link copied!",
    builds_saved_builds: "Saved builds",
    builds_no_saved: "No saved builds yet. Build one above and click \"Save build\".",
    builds_load: "Load",
    builds_delete: "Delete",
    builds_summary: "My ninja",
    builds_specifications: "Specifications",
    builds_mastery_path: "Masteries",
    builds_weapon_none: "Bare hands",
    builds_locked_reqs: "Requirements not met",
    builds_supabase_off: "Configure Supabase to use the build calculator.",
    builds_loading: "Loading build data...",
    builds_error: "Error loading build data: {msg}",
  },
};

const STORAGE_KEY = "ninmap:lang";
const DEFAULT_LANG = "pt";

export function getLang() {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored && STRINGS[stored]) return stored;
  } catch (e) {
    /* ambiente sem localStorage disponível — ignora */
  }
  return DEFAULT_LANG;
}

export function setLang(lang) {
  if (!STRINGS[lang]) return;
  try {
    localStorage.setItem(STORAGE_KEY, lang);
  } catch (e) {
    /* ambiente sem localStorage disponível — ignora */
  }
  document.documentElement.setAttribute("lang", lang === "en" ? "en" : "pt-BR");
  window.dispatchEvent(new CustomEvent("ninmap:langchange", { detail: { lang } }));
}

/** Busca uma string traduzida, com substituição de {variaveis}. */
export function t(key, vars) {
  const lang = getLang();
  let str = (STRINGS[lang] && STRINGS[lang][key]) ?? STRINGS[DEFAULT_LANG][key] ?? key;
  if (vars) {
    Object.entries(vars).forEach(([k, v]) => {
      str = str.replaceAll(`{${k}}`, v);
    });
  }
  return str;
}

/**
 * Escolhe o rótulo certo de um item de config.js (ARCOS/VILLAGES) pro
 * idioma atual — usa `label_en` quando existir e o idioma for inglês,
 * senão cai pro `label` (português).
 */
export function pickLabel(entry) {
  if (!entry) return "";
  return getLang() === "en" && entry.label_en ? entry.label_en : entry.label;
}

/**
 * Aplica as traduções em todo elemento com data-i18n (texto),
 * data-i18n-placeholder (atributo placeholder) ou data-i18n-title
 * (atributo title) dentro de `root`.
 */
export function applyStaticTranslations(root = document) {
  root.querySelectorAll("[data-i18n]").forEach((el) => {
    el.textContent = t(el.getAttribute("data-i18n"));
  });
  root.querySelectorAll("[data-i18n-placeholder]").forEach((el) => {
    el.setAttribute("placeholder", t(el.getAttribute("data-i18n-placeholder")));
  });
  root.querySelectorAll("[data-i18n-title]").forEach((el) => {
    el.setAttribute("title", t(el.getAttribute("data-i18n-title")));
  });
}
