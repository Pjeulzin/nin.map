/**
 * Helpers compartilhados entre a listagem pública de NPCs e a tela de
 * cadastro (admin). Mesmo padrão de missions-shared.js/mobs-shared.js:
 * o admin usa as versões fixas em português, o site público usa as
 * versões `I18n`.
 */

import { t } from "./i18n.js";

export const NPC_ROLES = ["vendedor", "concede_missao", "parte_missao", "outro"];

export const NPC_ROLE_LABELS = {
  vendedor: "Vendedor",
  concede_missao: "Concede missão",
  parte_missao: "Parte de missão",
  outro: "Outro",
};

export function npcRoleLabelI18n(role) {
  return t(`npc_role_${role}`) || role;
}

export function formatNpcLocationI18n(npc, { arcoLabel, pinName } = {}) {
  const parts = [];
  if (pinName) parts.push(pinName);
  else if (npc.location_note) parts.push(npc.location_note);
  if (arcoLabel) parts.push(arcoLabel);
  return parts.length > 0 ? parts.join(" · ") : t("location_unset");
}

export function formatShopItem(entry) {
  const itemName = entry.items ? entry.items.name : "?";
  const stockText = entry.stock === null || entry.stock === undefined ? t("stock_unlimited") : entry.stock;
  return `${itemName} — ${entry.price} ryo (${t("label_stock")}: ${stockText})`;
}
