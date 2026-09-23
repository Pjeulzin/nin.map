/**
 * Helpers compartilhados entre a listagem pública de jutsus e a tela
 * de cadastro (admin).
 */

import { t } from "./i18n.js";

export function formatChakraCost(cost) {
  if (cost === null || cost === undefined) return "—";
  return `${cost}`;
}

export function formatCooldown(seconds) {
  if (seconds === null || seconds === undefined) return "—";
  return `${seconds}s`;
}

export function formatLevelRequired(level) {
  if (level === null || level === undefined) return t("level_any");
  return t("level_min", { n: level });
}
