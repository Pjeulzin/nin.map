/**
 * Helpers compartilhados entre a listagem pública de mobs/itens e as
 * telas de cadastro (admin).
 *
 * O admin continua sempre em português (versões fixas: MOB_CATEGORY_LABELS,
 * MOB_COMBAT_TYPE_LABELS, ITEM_TYPE_LABELS). O site público troca de
 * idioma, então usa as versões `I18n`, que buscam o texto em js/i18n.js.
 */

import { t } from "./i18n.js";

export const MOB_CATEGORY_LABELS = {
  boss: "Boss",
  enfurecido: "Enfurecido",
  regular: "Regular",
};

export function mobCategoryLabelI18n(category) {
  return t(`mob_category_${category}`) || category;
}

export const MOB_CATEGORY_COLORS = {
  boss: "#e5735e",
  enfurecido: "#e0b84c",
  regular: "#6fbf73",
};

export const MOB_COMBAT_TYPE_LABELS = {
  passivo: "Passivo",
  agressivo: "Agressivo",
};

export function combatTypeLabelI18n(combatType) {
  return t(`combat_type_${combatType}`) || combatType;
}

export const ITEM_TYPE_LABELS = {
  anel: "Anel",
  arma: "Arma",
  roupa: "Roupa",
  consumivel: "Consumível",
  item_mob: "Item de mob",
};

export function itemTypeLabelI18n(itemType) {
  return t(`item_type_${itemType}`) || itemType;
}

// Categoria da arma (só preenchido quando item.type === "arma").
export const WEAPON_CATEGORY_LABELS = {
  espada: "Espada",
  kunai: "Kunai",
  shuriken: "Shuriken",
  bastao: "Bastão",
  outro: "Outro",
};

export function weaponCategoryLabelI18n(category) {
  if (!category) return "";
  return t(`weapon_category_${category}`) || category;
}

export function formatDamage(min, max) {
  if (min === null || min === undefined) {
    if (max === null || max === undefined) return "—";
    return `até ${max}`;
  }
  if (max === null || max === undefined || max === min) return `${min}`;
  return `${min}–${max}`;
}

export function formatDamageI18n(min, max) {
  if (min === null || min === undefined) {
    if (max === null || max === undefined) return "—";
    return t("damage_upto", { n: max });
  }
  if (max === null || max === undefined || max === min) return `${min}`;
  return `${min}–${max}`;
}

export function formatDropRate(rate) {
  if (rate === null || rate === undefined) return "";
  const n = Number(rate);
  return Number.isInteger(n) ? `${n}%` : `${n.toFixed(2)}%`;
}

export function formatDropQuantity(min, max) {
  if (min === max) return `${min}x`;
  return `${min}–${max}x`;
}

export function formatMobLocation(mob, { arcoLabel, pinName } = {}) {
  const parts = [];
  if (pinName) parts.push(pinName);
  else if (mob.location_note) parts.push(mob.location_note);
  if (arcoLabel) parts.push(arcoLabel);
  return parts.length > 0 ? parts.join(" · ") : "Localização não cadastrada";
}

export function formatMobLocationI18n(mob, { arcoLabel, pinName } = {}) {
  const parts = [];
  if (pinName) parts.push(pinName);
  else if (mob.location_note) parts.push(mob.location_note);
  if (arcoLabel) parts.push(arcoLabel);
  return parts.length > 0 ? parts.join(" · ") : t("location_unset");
}
