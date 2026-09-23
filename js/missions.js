import { ARCOS, VILLAGES } from "./config.js";
import { supabase, isSupabaseConfigured } from "./supabaseClient.js";
import { getCurrentVillage, storeVillage, updateVillageInUrl } from "./village.js";
import { mountGlobalControls } from "./chrome.js";
import { t, applyStaticTranslations, pickLabel } from "./i18n.js";
import {
  MISSION_RANKS,
  MISSION_RANK_COLORS,
  missionTypeLabelI18n,
  formatLevelRequirementI18n,
  formatObjectives,
} from "./missions-shared.js";

const listEl = document.getElementById("missions-list");
const statusEl = document.getElementById("missions-status");
const filterTypeEl = document.getElementById("filter-type");
const filterArcoEl = document.getElementById("filter-arco");
const filterRankEl = document.getElementById("filter-rank");
const filterVillageEl = document.getElementById("filter-village");

let allMissions = [];
let statusKind = null; // "loading" | "error" | "supabase-off" | null — pra re-traduzir se o idioma mudar

function populateArcoFilter() {
  ARCOS.forEach((arco) => {
    const option = document.createElement("option");
    option.value = arco.id;
    option.textContent = pickLabel(arco);
    filterArcoEl.appendChild(option);
  });
}

function populateRankFilter() {
  MISSION_RANKS.forEach((rank) => {
    const option = document.createElement("option");
    option.value = rank;
    option.textContent = `Rank ${rank}`;
    filterRankEl.appendChild(option);
  });
}

function populateVillageFilter() {
  VILLAGES.forEach((village) => {
    const option = document.createElement("option");
    option.value = village.id;
    option.textContent = pickLabel(village);
    filterVillageEl.appendChild(option);
  });

  const current = getCurrentVillage();
  if (current) filterVillageEl.value = current;
}

function refreshFilterLabels() {
  Array.from(filterArcoEl.options).forEach((opt) => {
    if (!opt.value) return;
    const arco = ARCOS.find((a) => a.id === opt.value);
    if (arco) opt.textContent = pickLabel(arco);
  });
  Array.from(filterVillageEl.options).forEach((opt) => {
    if (!opt.value) return;
    const village = VILLAGES.find((v) => v.id === opt.value);
    if (village) opt.textContent = pickLabel(village);
  });
}

function arcoLabel(arcoId) {
  const arco = ARCOS.find((a) => a.id === arcoId);
  return arco ? pickLabel(arco) : arcoId;
}

function villageLabel(villageId) {
  const village = VILLAGES.find((v) => v.id === villageId);
  return village ? pickLabel(village) : villageId;
}

function renderMissions() {
  const typeFilter = filterTypeEl.value;
  const arcoFilter = filterArcoEl.value;
  const rankFilter = filterRankEl.value;
  const villageFilter = filterVillageEl.value;

  const filtered = allMissions.filter((m) => {
    if (typeFilter && m.mission_type !== typeFilter) return false;
    if (arcoFilter && m.arco_id !== arcoFilter) return false;
    if (rankFilter && m.rank !== rankFilter) return false;
    // Missão sem vila definida (village_id null) vale pra qualquer vila.
    if (villageFilter && m.village_id && m.village_id !== villageFilter) return false;
    return true;
  });

  listEl.innerHTML = "";

  if (filtered.length === 0) {
    listEl.innerHTML = `<p class="status-message">${t("missions_none")}</p>`;
    return;
  }

  filtered.forEach((m) => {
    const card = document.createElement("article");
    card.className = "mission-card";

    const typeTag = missionTypeLabelI18n(m.mission_type);
    const arcoTag = m.mission_type === "arco" && m.arco_id ? ` · ${arcoLabel(m.arco_id)}` : "";
    const villageTag = m.village_id ? ` · ${villageLabel(m.village_id)}` : "";
    const rankColor = MISSION_RANK_COLORS[m.rank] || MISSION_RANK_COLORS.D;

    card.innerHTML = `
      <header class="mission-card__header">
        <div class="mission-card__title-row">
          <span class="mission-card__rank" style="--rank-color:${rankColor};">${m.rank || "D"}</span>
          <h2 class="mission-card__title">${m.name}</h2>
        </div>
        <span class="mission-card__tag">${typeTag}${arcoTag}${villageTag}</span>
      </header>
      ${m.description ? `<p class="mission-card__desc">${m.description}</p>` : ""}
      <dl class="mission-card__meta">
        <div><dt>${t("label_level")}</dt><dd>${formatLevelRequirementI18n(m.level_min, m.level_max)}</dd></div>
        <div><dt>XP</dt><dd>${m.xp ?? 0}</dd></div>
        <div><dt>Ryo</dt><dd>${m.ryo ?? 0}</dd></div>
      </dl>
      <div class="mission-card__objectives">
        <strong>${t("label_objective")}:</strong> ${formatObjectives(m.objectives)}
      </div>
      ${m.npcs && m.npcs.name ? `<div class="mission-card__objectives"><strong>${t("label_gives_mission_from")}:</strong> ${m.npcs.name}</div>` : ""}
    `;

    listEl.appendChild(card);
  });
}

function renderStatus() {
  if (statusKind === "loading") statusEl.textContent = t("missions_loading");
  else if (statusKind === "supabase-off") statusEl.textContent = t("missions_supabase_off");
  else if (statusKind && statusKind.startsWith("error:")) {
    statusEl.textContent = t("missions_error", { msg: statusKind.slice(6) });
  } else {
    statusEl.textContent = "";
  }
}

async function loadMissions() {
  if (!isSupabaseConfigured) {
    statusKind = "supabase-off";
    renderStatus();
    return;
  }

  statusKind = "loading";
  renderStatus();

  const { data, error } = await supabase
    .from("missions")
    .select("*, npcs(name)")
    .order("created_at", { ascending: false });

  if (error) {
    statusKind = `error:${error.message}`;
    renderStatus();
    return;
  }

  allMissions = data || [];
  statusKind = null;
  renderStatus();
  renderMissions();
}

mountGlobalControls();
applyStaticTranslations();

populateArcoFilter();
populateRankFilter();
populateVillageFilter();

filterTypeEl.addEventListener("change", renderMissions);
filterArcoEl.addEventListener("change", renderMissions);
filterRankEl.addEventListener("change", renderMissions);
filterVillageEl.addEventListener("change", (e) => {
  storeVillage(e.target.value || null);
  updateVillageInUrl(e.target.value || null);
  renderMissions();
});

window.addEventListener("ninmap:langchange", () => {
  refreshFilterLabels();
  renderStatus();
  renderMissions();
});

loadMissions();
