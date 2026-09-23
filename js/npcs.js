import { ARCOS } from "./config.js";
import { supabase, isSupabaseConfigured } from "./supabaseClient.js";
import { mountGlobalControls } from "./chrome.js";
import { t, applyStaticTranslations, pickLabel } from "./i18n.js";
import { npcRoleLabelI18n, formatNpcLocationI18n, formatShopItem } from "./npcs-shared.js";

const listEl = document.getElementById("npcs-list");
const statusEl = document.getElementById("npcs-status");
const filterArcoEl = document.getElementById("filter-arco");
const filterRoleEl = document.getElementById("filter-role");

let allNpcs = [];
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

function locationText(npc) {
  const pinName = npc.pins && npc.pins.name ? npc.pins.name : null;
  return formatNpcLocationI18n(npc, {
    arcoLabel: npc.arco_id ? arcoLabel(npc.arco_id) : null,
    pinName,
  });
}

function renderNpcs() {
  const arcoFilter = filterArcoEl.value;
  const roleFilter = filterRoleEl.value;

  const filtered = allNpcs.filter((n) => {
    if (arcoFilter && n.arco_id !== arcoFilter) return false;
    if (roleFilter && !(n.roles || []).includes(roleFilter)) return false;
    return true;
  });

  listEl.innerHTML = "";

  if (filtered.length === 0) {
    listEl.innerHTML = `<p class="status-message">${t("npcs_none")}</p>`;
    return;
  }

  filtered.forEach((npc) => {
    const card = document.createElement("article");
    card.className = "mission-card";

    const rolesTag = (npc.roles || []).map((r) => npcRoleLabelI18n(r)).join(" · ") || "—";

    const shopItems = npc.npc_shop_items || [];
    const shopHtml =
      shopItems.length > 0
        ? `<div class="mission-card__objectives"><strong>${t("label_sells")}:</strong> ${shopItems
            .map((s) => formatShopItem(s))
            .join(", ")}</div>`
        : "";

    const givenMissions = npc.missions || [];
    const missionsHtml =
      givenMissions.length > 0
        ? `<div class="mission-card__objectives"><strong>${t("label_gives_mission")}:</strong> ${givenMissions
            .map((m) => m.name)
            .join(", ")}</div>`
        : "";

    card.innerHTML = `
      <header class="mission-card__header">
        <a class="mission-card__link" href="npc-detail.html?id=${npc.id}">
          <div class="mission-card__title-row">
            <h2 class="mission-card__title">${npc.name}</h2>
          </div>
        </a>
        <span class="mission-card__tag">${rolesTag}</span>
      </header>
      <p class="mission-card__desc">${locationText(npc)}</p>
      ${npc.description ? `<p class="mission-card__desc">${npc.description}</p>` : ""}
      ${shopHtml}
      ${missionsHtml}
    `;

    listEl.appendChild(card);
  });
}

function renderStatus() {
  if (statusKind === "loading") statusEl.textContent = t("npcs_loading");
  else if (statusKind === "supabase-off") statusEl.textContent = t("npcs_supabase_off");
  else if (statusKind && statusKind.startsWith("error:")) {
    statusEl.textContent = t("npcs_error", { msg: statusKind.slice(6) });
  } else {
    statusEl.textContent = "";
  }
}

async function loadNpcs() {
  if (!isSupabaseConfigured) {
    statusKind = "supabase-off";
    renderStatus();
    return;
  }

  statusKind = "loading";
  renderStatus();

  const { data, error } = await supabase
    .from("npcs")
    .select("*, pins(name), npc_shop_items(price, stock, items(name)), missions(name)")
    .order("name");

  if (error) {
    statusKind = `error:${error.message}`;
    renderStatus();
    return;
  }

  allNpcs = data || [];
  statusKind = null;
  renderStatus();
  renderNpcs();
}

mountGlobalControls();
applyStaticTranslations();

populateArcoFilter();
filterArcoEl.addEventListener("change", renderNpcs);
filterRoleEl.addEventListener("change", renderNpcs);

window.addEventListener("ninmap:langchange", () => {
  refreshFilterLabels();
  renderStatus();
  renderNpcs();
});

loadNpcs();
