import { supabase, isSupabaseConfigured } from "./supabaseClient.js";
import { mountGlobalControls } from "./chrome.js";
import { t, applyStaticTranslations } from "./i18n.js";
import { MISSION_RANKS, MISSION_RANK_COLORS } from "./missions-shared.js";
import { formatChakraCost, formatCooldown, formatLevelRequired } from "./jutsus-shared.js";

const listEl = document.getElementById("jutsus-list");
const statusEl = document.getElementById("jutsus-status");
const filterMasteryEl = document.getElementById("filter-mastery");
const filterRankEl = document.getElementById("filter-rank");

let allJutsus = [];
let statusKind = null;

function populateRankFilter() {
  MISSION_RANKS.forEach((rank) => {
    const option = document.createElement("option");
    option.value = rank;
    option.textContent = `Rank ${rank}`;
    filterRankEl.appendChild(option);
  });
}

async function populateMasteryFilter() {
  const { data, error } = await supabase.from("masteries").select("id, name").order("name");
  if (error) {
    console.error("Erro ao carregar maestrias:", error.message);
    return;
  }
  (data || []).forEach((m) => {
    const option = document.createElement("option");
    option.value = m.id;
    option.textContent = m.name;
    filterMasteryEl.appendChild(option);
  });
}

function renderJutsus() {
  const masteryFilter = filterMasteryEl.value;
  const rankFilter = filterRankEl.value;

  const filtered = allJutsus.filter((j) => {
    if (masteryFilter && j.mastery_id !== masteryFilter) return false;
    if (rankFilter && j.rank !== rankFilter) return false;
    return true;
  });

  listEl.innerHTML = "";

  if (filtered.length === 0) {
    listEl.innerHTML = `<p class="status-message">${t("jutsus_none")}</p>`;
    return;
  }

  filtered.forEach((jutsu) => {
    const card = document.createElement("article");
    card.className = "mission-card";

    const iconHtml = jutsu.image_url
      ? `<img src="${jutsu.image_url}" alt="" />`
      : `<span class="item-icon-frame__empty">—</span>`;

    const rankColor = jutsu.rank ? MISSION_RANK_COLORS[jutsu.rank] : null;
    const rankBadge = jutsu.rank
      ? `<span class="mission-card__rank" style="--rank-color:${rankColor};">${jutsu.rank}</span>`
      : "";

    const masteryTag = jutsu.masteries ? jutsu.masteries.name : null;
    const branchTag = jutsu.mastery_branches ? jutsu.mastery_branches.name : null;
    const tagText = [masteryTag, branchTag].filter(Boolean).join(" · ");

    card.innerHTML = `
      <header class="mission-card__header">
        <div class="mission-card__title-row">
          <div class="item-icon-frame">${iconHtml}</div>
          ${rankBadge}
          <h2 class="mission-card__title">${jutsu.name}</h2>
        </div>
        ${tagText ? `<span class="mission-card__tag">${tagText}</span>` : ""}
      </header>
      ${jutsu.description ? `<p class="mission-card__desc">${jutsu.description}</p>` : ""}
      <dl class="mission-card__meta">
        <div><dt>${t("label_level")}</dt><dd>${formatLevelRequired(jutsu.level_required)}</dd></div>
        <div><dt>${t("label_chakra")}</dt><dd>${formatChakraCost(jutsu.chakra_cost)}</dd></div>
        <div><dt>${t("label_cooldown")}</dt><dd>${formatCooldown(jutsu.cooldown_seconds)}</dd></div>
      </dl>
    `;

    listEl.appendChild(card);
  });
}

function renderStatus() {
  if (statusKind === "loading") statusEl.textContent = t("jutsus_loading");
  else if (statusKind === "supabase-off") statusEl.textContent = t("jutsus_supabase_off");
  else if (statusKind && statusKind.startsWith("error:")) {
    statusEl.textContent = t("jutsus_error", { msg: statusKind.slice(6) });
  } else {
    statusEl.textContent = "";
  }
}

async function loadJutsus() {
  if (!isSupabaseConfigured) {
    statusKind = "supabase-off";
    renderStatus();
    return;
  }

  statusKind = "loading";
  renderStatus();

  const { data, error } = await supabase
    .from("jutsus")
    .select("*, masteries(name), mastery_branches(name)")
    .order("name");

  if (error) {
    statusKind = `error:${error.message}`;
    renderStatus();
    return;
  }

  allJutsus = data || [];
  statusKind = null;
  renderStatus();
  renderJutsus();
}

mountGlobalControls();
applyStaticTranslations();

populateRankFilter();
populateMasteryFilter();

filterMasteryEl.addEventListener("change", renderJutsus);
filterRankEl.addEventListener("change", renderJutsus);

window.addEventListener("ninmap:langchange", () => {
  renderStatus();
  renderJutsus();
});

loadJutsus();
