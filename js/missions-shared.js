/**
 * Helpers compartilhados entre a listagem pública de missões e a tela
 * de cadastro (admin).
 */

export const MISSION_TYPE_LABELS = {
  global: "Global",
  arco: "Exclusiva de arco",
  evento: "Evento",
  diaria: "Diária",
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

export function formatObjectives(objectives) {
  if (!Array.isArray(objectives) || objectives.length === 0) return "—";
  return objectives
    .map((o) => `${o.quantity}x ${o.item}`)
    .join(", ");
}
