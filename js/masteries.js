import { supabase, isSupabaseConfigured } from "./supabaseClient.js";
import { mountGlobalControls } from "./chrome.js";
import { t, applyStaticTranslations } from "./i18n.js";
import { formatBranchNames } from "./masteries-shared.js";

const listEl = document.getElementById("masteries-list");
const statusEl = document.getElementById("masteries-status");

let statusKind = null;

function renderMasteries(masteries) {
  listEl.innerHTML = "";

  if (masteries.length === 0) {
    listEl.innerHTML = `<p class="status-message">${t("masteries_none")}</p>`;
    return;
  }

  masteries.forEach((mastery) => {
    const card = document.createElement("article");
    card.className = "mission-card";

    const iconHtml = mastery.image_url
      ? `<img src="${mastery.image_url}" alt="" />`
      : `<span class="item-icon-frame__empty">—</span>`;

    const branchNames = formatBranchNames(mastery.mastery_branches);

    card.innerHTML = `
      <header class="mission-card__header">
        <a class="mission-card__link" href="mastery-detail.html?id=${mastery.id}">
          <div class="mission-card__title-row">
            <div class="item-icon-frame">${iconHtml}</div>
            <h2 class="mission-card__title">${mastery.name}</h2>
          </div>
        </a>
      </header>
      ${mastery.description ? `<p class="mission-card__desc">${mastery.description}</p>` : ""}
      ${
        branchNames
          ? `<div class="mission-card__objectives"><strong>${t("label_branch")}:</strong> ${branchNames}</div>`
          : ""
      }
    `;

    listEl.appendChild(card);
  });
}

function renderStatus() {
  if (statusKind === "loading") statusEl.textContent = t("masteries_loading");
  else if (statusKind === "supabase-off") statusEl.textContent = t("masteries_supabase_off");
  else if (statusKind && statusKind.startsWith("error:")) {
    statusEl.textContent = t("masteries_error", { msg: statusKind.slice(6) });
  } else {
    statusEl.textContent = "";
  }
}

let allMasteries = [];

async function loadMasteries() {
  if (!isSupabaseConfigured) {
    statusKind = "supabase-off";
    renderStatus();
    return;
  }

  statusKind = "loading";
  renderStatus();

  const { data, error } = await supabase
    .from("masteries")
    .select("*, mastery_branches(id, name, description)")
    .order("name");

  if (error) {
    statusKind = `error:${error.message}`;
    renderStatus();
    return;
  }

  allMasteries = data || [];
  statusKind = null;
  renderStatus();
  renderMasteries(allMasteries);
}

mountGlobalControls();
applyStaticTranslations();

window.addEventListener("ninmap:langchange", () => {
  renderStatus();
  renderMasteries(allMasteries);
});

loadMasteries();
