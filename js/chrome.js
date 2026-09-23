/**
 * Monta os controles globais de servidor/comunidade e idioma dentro
 * de um elemento `#global-controls`, presente no topbar de toda
 * página pública. Chame mountGlobalControls() uma vez no carregamento
 * de cada página.
 */

import { SERVERS, getServerById, getCurrentServer, storeServer, updateServerInUrl } from "./server.js";
import { getLang, setLang, applyStaticTranslations } from "./i18n.js";

export function mountGlobalControls() {
  const container = document.getElementById("global-controls");
  if (!container) return;

  const serverSelect = document.createElement("select");
  serverSelect.id = "server-select";
  serverSelect.className = "select";
  serverSelect.title = "Servidor";

  const placeholderOption = document.createElement("option");
  placeholderOption.value = "";
  placeholderOption.setAttribute("data-i18n", "server_placeholder");
  placeholderOption.textContent = "Servidor...";
  serverSelect.appendChild(placeholderOption);

  SERVERS.forEach((server) => {
    const option = document.createElement("option");
    option.value = server.id;
    option.textContent = server.label;
    serverSelect.appendChild(option);
  });

  const langToggle = document.createElement("button");
  langToggle.type = "button";
  langToggle.id = "lang-toggle";
  langToggle.className = "btn";
  langToggle.title = "Idioma da interface / Interface language";

  container.appendChild(serverSelect);
  container.appendChild(langToggle);

  function updateLangToggleLabel() {
    langToggle.textContent = getLang() === "en" ? "🇺🇸 EN" : "🇧🇷 PT";
  }

  const currentServerId = getCurrentServer();
  if (currentServerId) serverSelect.value = currentServerId;
  updateLangToggleLabel();

  serverSelect.addEventListener("change", () => {
    const id = serverSelect.value;
    storeServer(id || null);
    updateServerInUrl(id || null);
    const server = getServerById(id);
    if (server) setLang(server.lang);
  });

  langToggle.addEventListener("click", () => {
    setLang(getLang() === "en" ? "pt" : "en");
  });

  window.addEventListener("ninmap:langchange", () => {
    updateLangToggleLabel();
    applyStaticTranslations();
  });
}
