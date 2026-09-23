/**
 * Helpers compartilhados entre a listagem pública de missões e a tela
 * de cadastro (admin).
 *
 * O admin (área de cadastro) é uma ferramenta só sua e continua
 * sempre em português — por isso usa as versões fixas (MISSION_TYPE_LABELS,
 * formatLevelRequirement). O site público troca de idioma, então usa
 * as versões que terminam em `I18n`, que buscam o texto certo em
 * js/i18n.js na hora de renderizar.
 */

import { t } from "./i18n.js";

export const MISSION_TYPE_LABELS = {
  global: "Global",
  arco: "Exclusiva de arco",
  evento: "Evento",
  diaria: "Diária",
};

export function missionTypeLabelI18n(type) {
  return t(`mission_type_${type}`) || type;
}

// Ordem do rank, do mais difícil (S) ao mais fácil (D) — usada pra
// preencher selects e pra ordenar/comparar ranks quando precisar.
export const MISSION_RANKS = ["S", "A", "B", "C", "D"];

// Cor de destaque de cada rank, usada nos badges (site público e admin).
export const MISSION_RANK_COLORS = {
  S: "#e0b84c",
  A: "#e5735e",
  B: "#6fbf73",
  C: "#5ba3d0",
  D: "#9aa0a6",
};

export function formatLevelRequirement(levelMin, levelMax) {
  const min = levelMin === null || levelMin === undefined ? null : Number(levelMin);
  const max = levelMax === null || levelMax === undefined ? null : Number(levelMax);

  if (min === null && max === null) return "Qualquer nível";
  if (min !== null && max !== null && min === max) return `Nível ${min}`;
  if (min !== null && max !== null) return `Nível ${min} até ${max}`;
  if (min !== null) return `Nível +${min}`;
  return `Nível até ${max}`;
}

export function formatLevelRequirementI18n(levelMin, levelMax) {
  const min = levelMin === null || levelMin === undefined ? null : Number(levelMin);
  const max = levelMax === null || levelMax === undefined ? null : Number(levelMax);

  if (min === null && max === null) return t("level_any");
  if (min !== null && max !== null && min === max) return t("level_exact", { n: min });
  if (min !== null && max !== null) return t("level_range", { min, max });
  if (min !== null) return t("level_min", { n: min });
  return t("level_max", { n: max });
}

export function formatObjectives(objectives) {
  if (!Array.isArray(objectives) || objectives.length === 0) return "—";
  return objectives.map((o) => `${o.quantity}x ${o.item}`).join(", ");
}
