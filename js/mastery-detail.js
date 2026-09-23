import { supabase, isSupabaseConfigured } from "./supabaseClient.js";
import { mountGlobalControls } from "./chrome.js";
import { t, applyStaticTranslations } from "./i18n.js";
import { formatLevelRequired, formatChakraCost, formatCooldown } from "./jutsus-shared.js";

const statusEl = document.getElementById("mastery-status");
const detailEl = document.getElementById("mastery-detail");

const masteryId = new URLSearchParams(window.location.search).get("id");

let mastery = null;
let jutsus = [];

function render() {
  if (!mastery) return;

  const iconHtml = mastery.image_url
    ? `<img src="${mastery.image_url}" alt="" />`
    : `<span class="item-icon-frame__empty">—</span>`;

  const branches = mastery.mastery_branches || [];
  const branchesHtml =
    branches.length > 0
      ? `<ul class="detail-ability-list">${branches
          .map((b) => `<li><strong>${b.name}</strong>${b.description ? ` — ${b.description}` : ""}</li>`)
          .join("")}</ul>`
      : `<p class="detail-empty">—</p>`;

  const jutsusHtml =
    jutsus.length > 0
      ? `
        <table class="detail-table">
          <thead>
            <tr>
              <th>${t("th_name")}</th>
              <th>${t("detail_col_rank")}</th>
              <th>${t("detail_col_level")}</th>
              <th>${t("detail_col_chakra")}</th>
              <th>${t("detail_col_cooldown")}</th>
            </tr>
          </thead>
          <tbody>
            ${jutsus
              .map(
                (j) => `
                  <tr>
                    <td>${j.name}</td>
                    <td>${j.rank || "—"}</td>
                    <td>${formatLevelRequired(j.level_required)}</td>
                    <td>${formatChakraCost(j.chakra_cost)}</td>
                    <td>${formatCooldown(j.cooldown_seconds)}</td>
                  </tr>
                `
              )
              .join("")}
          </tbody>
        </table>
      `
      : `<p class="detail-empty">—</p>`;

  document.title = `${mastery.name} — Nin.Map`;

  detailEl.innerHTML = `
    <div class="detail-hero">
      <div class="item-icon-frame detail-hero__icon">${iconHtml}</div>
      <div class="detail-hero__body">
        <div class="detail-hero__title-row">
          <h1 class="detail-hero__title">${mastery.name}</h1>
        </div>
      </div>
    </div>

    ${
      mastery.description
        ? `<div class="detail-section" style="margin-bottom:16px;"><h2>${t("detail_section_about")}</h2><p>${mastery.description}</p></div>`
        : ""
    }

    ${
      mastery.playstyle_notes
        ? `<div class="detail-section" style="margin-bottom:16px;"><h2>${t("detail_section_playstyle")}</h2><p>${mastery.playstyle_notes}</p></div>`
        : ""
    }

    <div class="detail-grid">
      <div class="detail-section">
        <h2>${t("detail_section_branches")}</h2>
        ${branchesHtml}
      </div>
    </div>

    <div class="detail-section">
      <h2>${t("detail_section_jutsus")}</h2>
      ${jutsusHtml}
    </div>
  `;
}

function renderStatus() {
  if (!masteryId) {
    statusEl.textContent = t("detail_not_found");
    return;
  }
  if (!isSupabaseConfigured) {
    statusEl.textContent = t("masteries_supabase_off");
    return;
  }
  if (!mastery) {
    statusEl.textContent = t("detail_loading");
    return;
  }
  statusEl.textContent = "";
}

async function load() {
  renderStatus();
  if (!masteryId || !isSupabaseConfigured) return;

  const [masteryRes, jutsusRes] = await Promise.all([
    supabase
      .from("masteries")
      .select("*, mastery_branches(id, name, description)")
      .eq("id", masteryId)
      .maybeSingle(),
    supabase.from("jutsus").select("*").eq("mastery_id", masteryId).order("level_required"),
  ]);

  if (masteryRes.error || !masteryRes.data) {
    statusEl.textContent = masteryRes.error ? t("masteries_error", { msg: masteryRes.error.message }) : t("detail_not_found");
    return;
  }

  mastery = masteryRes.data;
  jutsus = jutsusRes.data || [];
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
