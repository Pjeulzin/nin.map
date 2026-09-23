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

const listEl = document.getElementById("mobs-list");
const statusEl = document.getElementById("mobs-status");
const filterArcoEl = document.getElementById("filter-arco");
const filterCategoryEl = document.getElementById("filter-category");
const filterCombatEl = document.getElementById("filter-combat");

let allMobs = [];
let statusKind = null;

function populateArcoFilter() {
  ARCOS.forEach((arco) => {
    const option = document.createElement("option");
    option.value = arco.id;
    option.textContent = pickLabel(arco);
    filterArcoEl.appendChild(option);
  });
}

function refreshFilterLabels() {
  Array.from(filterArcoEl.options).forEach((opt) => {
    if (!opt.value) return;
    const arco = ARCOS.find((a) => a.id === opt.value);
    if (arco) opt.textContent = pickLabel(arco);
  });
}

function arcoLabel(arcoId) {
  const arco = ARCOS.find((a) => a.id === arcoId);
  return arco ? pickLabel(arco) : arcoId;
}

function locationText(mob) {
  const pinName = mob.pins && mob.pins.name ? mob.pins.name : null;
  return formatMobLocationI18n(mob, {
    arcoLabel: mob.arco_id ? arcoLabel(mob.arco_id) : null,
    pinName,
  });
}

function renderMobs() {
  const arcoFilter = filterArcoEl.value;
  const categoryFilter = filterCategoryEl.value;
  const combatFilter = filterCombatEl.value;

  const filtered = allMobs.filter((m) => {
    if (arcoFilter && m.arco_id !== arcoFilter) return false;
    if (categoryFilter && m.category !== categoryFilter) return false;
    if (combatFilter && m.combat_type !== combatFilter) return false;
    return true;
  });

  listEl.innerHTML = "";

  if (filtered.length === 0) {
    listEl.innerHTML = `<p class="status-message">${t("mobs_none")}</p>`;
    return;
  }

  filtered.forEach((m) => {
    const card = document.createElement("article");
    card.className = "mission-card";

    const categoryLabel = mobCategoryLabelI18n(m.category);
    const categoryColor = MOB_CATEGORY_COLORS[m.category] || MOB_CATEGORY_COLORS.regular;
    const combatLabel = combatTypeLabelI18n(m.combat_type);

    const dropsHtml =
      (m.mob_drops || []).length > 0
        ? (m.mob_drops || [])
            .map((d) => {
              const itemName = d.items ? d.items.name : "?";
              const rate = formatDropRate(d.drop_rate);
              return `${formatDropQuantity(d.quantity_min, d.quantity_max)} ${itemName}${rate ? ` (${rate})` : ""}`;
            })
            .join(", ")
        : "—";

    card.innerHTML = `
      <header class="mission-card__header">
        <a class="mission-card__link" href="mob-detail.html?id=${m.id}">
          <div class="mission-card__title-row">
            <span class="mission-card__rank" style="--rank-color:${categoryColor};">${m.level}</span>
            <h2 class="mission-card__title">${m.name}</h2>
          </div>
        </a>
        <span class="mission-card__tag">${categoryLabel} · ${combatLabel}</span>
      </header>
      <p class="mission-card__desc">${locationText(m)}</p>
      <dl class="mission-card__meta">
        <div><dt>HP</dt><dd>${m.hp}</dd></div>
        <div><dt>${t("label_damage")}</dt><dd>${formatDamageI18n(m.damage_min, m.damage_max)}</dd></div>
        <div><dt>XP</dt><dd>${m.xp_reward ?? 0}</dd></div>
      </dl>
      <div class="mission-card__objectives">
        <strong>${t("label_drops")}:</strong> ${dropsHtml}
      </div>
    `;

    listEl.appendChild(card);
  });
}

function renderStatus() {
  if (statusKind === "loading") statusEl.textContent = t("mobs_loading");
  else if (statusKind === "supabase-off") statusEl.textContent = t("mobs_supabase_off");
  else if (statusKind && statusKind.startsWith("error:")) {
    statusEl.textContent = t("mobs_error", { msg: statusKind.slice(6) });
  } else {
    statusEl.textContent = "";
  }
}

async function loadMobs() {
  if (!isSupabaseConfigured) {
    statusKind = "supabase-off";
    renderStatus();
    return;
  }

  statusKind = "loading";
  renderStatus();

  const { data, error } = await supabase
    .from("mobs")
    .select("*, pins(name), mob_drops(quantity_min, quantity_max, drop_rate, items(name))")
    .order("level");

  if (error) {
    statusKind = `error:${error.message}`;
    renderStatus();
    return;
  }

  allMobs = data || [];
  statusKind = null;
  renderStatus();
  renderMobs();
}

mountGlobalControls();
applyStaticTranslations();

populateArcoFilter();
filterArcoEl.addEventListener("change", renderMobs);
filterCategoryEl.addEventListener("change", renderMobs);
filterCombatEl.addEventListener("change", renderMobs);

window.addEventListener("ninmap:langchange", () => {
  refreshFilterLabels();
  renderStatus();
  renderMobs();
});

loadMobs();
