import { ARCOS } from "./config.js";
import { supabase, isSupabaseConfigured } from "./supabaseClient.js";
import { mountGlobalControls } from "./chrome.js";
import { t, applyStaticTranslations, pickLabel } from "./i18n.js";
import {
  MOB_CATEGORY_COLORS,
  mobCategoryLabelI18n,
  combatTypeLabelI18n,
  formatDamageI18n,
  formatDropQuantity,
  formatDropRate,
  formatMobLocationI18n,
} from "./mobs-shared.js";

const statusEl = document.getElementById("mob-status");
const detailEl = document.getElementById("mob-detail");

const mobId = new URLSearchParams(window.location.search).get("id");

let mob = null;

function arcoLabel(arcoId) {
  const arco = ARCOS.find((a) => a.id === arcoId);
  return arco ? pickLabel(arco) : arcoId;
}

function locationText(m) {
  const pinName = m.pins && m.pins.name ? m.pins.name : null;
  return formatMobLocationI18n(m, {
    arcoLabel: m.arco_id ? arcoLabel(m.arco_id) : null,
    pinName,
  });
}

function render() {
  if (!mob) return;

  const categoryLabel = mobCategoryLabelI18n(mob.category);
  const categoryColor = MOB_CATEGORY_COLORS[mob.category] || MOB_CATEGORY_COLORS.regular;
  const combatLabel = combatTypeLabelI18n(mob.combat_type);

  const iconHtml = mob.image_url
    ? `<img src="${mob.image_url}" alt="" />`
    : `<span class="item-icon-frame__empty">—</span>`;

  const abilities = mob.special_abilities || [];
  const abilitiesHtml =
    abilities.length > 0
      ? `<ul class="detail-ability-list">${abilities.map((a) => `<li>${a}</li>`).join("")}</ul>`
      : `<p class="detail-empty">—</p>`;

  const drops = mob.mob_drops || [];
  const dropsHtml =
    drops.length > 0
      ? `
        <table class="detail-table">
          <thead>
            <tr>
              <th>${t("detail_col_item")}</th>
              <th>${t("detail_col_qty")}</th>
              <th>${t("detail_col_chance")}</th>
            </tr>
          </thead>
          <tbody>
            ${drops
              .map((d) => {
                const itemName = d.items ? d.items.name : "?";
                const rate = formatDropRate(d.drop_rate);
                return `<tr><td>${itemName}</td><td>${formatDropQuantity(d.quantity_min, d.quantity_max)}</td><td>${rate || "—"}</td></tr>`;
              })
              .join("")}
          </tbody>
        </table>
      `
      : `<p class="detail-empty">—</p>`;

  document.title = `${mob.name} — Nin.Map`;

  detailEl.innerHTML = `
    <div class="detail-hero">
      <div class="item-icon-frame detail-hero__icon">${iconHtml}</div>
      <div class="detail-hero__body">
        <div class="detail-hero__title-row">
          <h1 class="detail-hero__title">${mob.name}</h1>
          <div class="detail-hero__tags">
            <span class="mission-card__tag" style="color:${categoryColor}; border-color:${categoryColor}66; background:${categoryColor}22;">${categoryLabel}</span>
            <span class="mission-card__tag">${combatLabel}</span>
          </div>
        </div>
        <p class="detail-hero__location">${locationText(mob)}</p>
      </div>
    </div>

    <div class="detail-grid">
      <div class="detail-section">
        <h2>${t("label_level")} / ${t("detail_hp")} / ${t("label_damage")} / ${t("detail_xp")}</h2>
        <dl class="detail-stats">
          <div><dt>${t("label_level")}</dt><dd>${mob.level}</dd></div>
          <div><dt>${t("detail_hp")}</dt><dd>${mob.hp}</dd></div>
          <div><dt>${t("label_damage")}</dt><dd>${formatDamageI18n(mob.damage_min, mob.damage_max)}</dd></div>
          <div><dt>${t("detail_xp")}</dt><dd>${mob.xp_reward ?? 0}</dd></div>
        </dl>
      </div>

      <div class="detail-section">
        <h2>${t("detail_section_abilities")}</h2>
        ${abilitiesHtml}
      </div>
    </div>

    ${
      mob.description
        ? `<div class="detail-section" style="margin-bottom:16px;"><h2>${t("detail_section_about")}</h2><p>${mob.description}</p></div>`
        : ""
    }

    <div class="detail-section">
      <h2>${t("detail_section_drops")}</h2>
      ${dropsHtml}
    </div>
  `;
}

function renderStatus() {
  if (!mobId) {
    statusEl.textContent = t("detail_not_found");
    return;
  }
  if (!isSupabaseConfigured) {
    statusEl.textContent = t("mobs_supabase_off");
    return;
  }
  if (!mob) {
    statusEl.textContent = t("detail_loading");
    return;
  }
  statusEl.textContent = "";
}

async function load() {
  renderStatus();
  if (!mobId || !isSupabaseConfigured) return;

  const { data, error } = await supabase
    .from("mobs")
    .select("*, pins(name), mob_drops(quantity_min, quantity_max, drop_rate, items(name))")
    .eq("id", mobId)
    .maybeSingle();

  if (error || !data) {
    statusEl.textContent = error ? t("mobs_error", { msg: error.message }) : t("detail_not_found");
    return;
  }

  mob = data;
  renderStatus();
  render();
}

mountGlobalControls();
applyStaticTranslations();

window.addEventListener("ninmap:langchange", () => {
  renderStatus();
  render();
});

load();
