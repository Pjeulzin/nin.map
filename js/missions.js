import { ARCOS } from "./config.js";
import { supabase, isSupabaseConfigured } from "./supabaseClient.js";
import { MISSION_TYPE_LABELS, formatLevelRequirement, formatObjectives } from "./missions-shared.js";

const listEl = document.getElementById("missions-list");
const statusEl = document.getElementById("missions-status");
const filterTypeEl = document.getElementById("filter-type");
const filterArcoEl = document.getElementById("filter-arco");

let allMissions = [];

function populateArcoFilter() {
  ARCOS.forEach((arco) => {
    const option = document.createElement("option");
    option.value = arco.id;
    option.textContent = arco.label;
    filterArcoEl.appendChild(option);
  });
}

function arcoLabel(arcoId) {
  const arco = ARCOS.find((a) => a.id === arcoId);
  return arco ? arco.label : arcoId;
}

function renderMissions() {
  const typeFilter = filterTypeEl.value;
  const arcoFilter = filterArcoEl.value;

  const filtered = allMissions.filter((m) => {
    if (typeFilter && m.mission_type !== typeFilter) return false;
    if (arcoFilter && m.arco_id !== arcoFilter) return false;
    return true;
  });

  listEl.innerHTML = "";

  if (filtered.length === 0) {
    listEl.innerHTML = `<p class="status-message">Nenhuma missão encontrada.</p>`;
    return;
  }

  filtered.forEach((m) => {
    const card = document.createElement("article");
    card.className = "mission-card";

    const typeTag = MISSION_TYPE_LABELS[m.mission_type] || m.mission_type;
    const arcoTag = m.mission_type === "arco" && m.arco_id ? ` · ${arcoLabel(m.arco_id)}` : "";

    card.innerHTML = `
      <header class="mission-card__header">
        <h2 class="mission-card__title">${m.name}</h2>
        <span class="mission-card__tag">${typeTag}${arcoTag}</span>
      </header>
      ${m.description ? `<p class="mission-card__desc">${m.description}</p>` : ""}
      <dl class="mission-card__meta">
        <div><dt>Nível</dt><dd>${formatLevelRequirement(m.level_min, m.level_max)}</dd></div>
        <div><dt>XP</dt><dd>${m.xp ?? 0}</dd></div>
        <div><dt>Ryo</dt><dd>${m.ryo ?? 0}</dd></div>
      </dl>
      <div class="mission-card__objectives">
        <strong>Objetivo:</strong> ${formatObjectives(m.objectives)}
      </div>
    `;

    listEl.appendChild(card);
  });
}

async function loadMissions() {
  if (!isSupabaseConfigured) {
    statusEl.textContent =
      "Supabase ainda não configurado — edite js/supabase-config.js com a URL e a anon key do seu projeto para ver as missões cadastradas.";
    return;
  }

  statusEl.textContent = "Carregando missões...";

  const { data, error } = await supabase
    .from("missions")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) {
    statusEl.textContent = `Erro ao carregar missões: ${error.message}`;
    return;
  }

  allMissions = data || [];
  statusEl.textContent = "";
  renderMissions();
}

populateArcoFilter();
filterTypeEl.addEventListener("change", renderMissions);
filterArcoEl.addEventListener("change", renderMissions);
loadMissions();
