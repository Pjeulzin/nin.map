/**
 * Painel de navegação flutuante (usado em todas as páginas públicas,
 * no lugar da antiga barra superior/inferior). Dá pra arrastar pelo
 * cabeçalho e minimizar/expandir clicando no botão — a posição e o
 * estado minimizado ficam salvos no navegador (localStorage), então
 * continuam do jeito que você deixou ao trocar de página.
 */

const POS_KEY = "ninmap:panelPos";
const MIN_KEY = "ninmap:panelMinimized";

const panel = document.getElementById("ninmap-panel");
const header = document.getElementById("panel-header");
const toggleBtn = document.getElementById("panel-toggle");

if (panel && header && toggleBtn) {
  function clamp(value, min, max) {
    return Math.min(Math.max(value, min), max);
  }

  function applyPosition(x, y) {
    const rect = panel.getBoundingClientRect();
    const maxX = Math.max(0, window.innerWidth - rect.width);
    const maxY = Math.max(0, window.innerHeight - rect.height);
    panel.style.left = `${clamp(x, 0, maxX)}px`;
    panel.style.top = `${clamp(y, 0, maxY)}px`;
    panel.style.right = "auto";
  }

  function savePosition() {
    try {
      const rect = panel.getBoundingClientRect();
      localStorage.setItem(POS_KEY, JSON.stringify({ x: rect.left, y: rect.top }));
    } catch (e) {
      /* ambiente sem localStorage disponível — ignora */
    }
  }

  function loadPosition() {
    try {
      const raw = localStorage.getItem(POS_KEY);
      if (!raw) return;
      const { x, y } = JSON.parse(raw);
      if (typeof x === "number" && typeof y === "number") applyPosition(x, y);
    } catch (e) {
      /* posição salva inválida ou sem localStorage — ignora */
    }
  }

  function setMinimized(minimized) {
    panel.dataset.minimized = minimized ? "true" : "false";
    toggleBtn.textContent = minimized ? "▢" : "–";
    toggleBtn.setAttribute("aria-expanded", minimized ? "false" : "true");
    try {
      localStorage.setItem(MIN_KEY, minimized ? "1" : "0");
    } catch (e) {
      /* ambiente sem localStorage disponível — ignora */
    }
  }

  function loadMinimized() {
    try {
      return localStorage.getItem(MIN_KEY) === "1";
    } catch (e) {
      return false;
    }
  }

  toggleBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    setMinimized(panel.dataset.minimized !== "true");
  });

  let dragging = false;
  let offsetX = 0;
  let offsetY = 0;

  header.addEventListener("pointerdown", (e) => {
    if (e.target === toggleBtn) return;
    dragging = true;
    const rect = panel.getBoundingClientRect();
    offsetX = e.clientX - rect.left;
    offsetY = e.clientY - rect.top;
    header.setPointerCapture(e.pointerId);
    panel.classList.add("float-panel--dragging");
  });

  header.addEventListener("pointermove", (e) => {
    if (!dragging) return;
    applyPosition(e.clientX - offsetX, e.clientY - offsetY);
  });

  function endDrag(e) {
    if (!dragging) return;
    dragging = false;
    panel.classList.remove("float-panel--dragging");
    try {
      header.releasePointerCapture(e.pointerId);
    } catch (err) {
      /* já liberado — ignora */
    }
    savePosition();
  }

  header.addEventListener("pointerup", endDrag);
  header.addEventListener("pointercancel", endDrag);

  window.addEventListener("resize", () => {
    const rect = panel.getBoundingClientRect();
    applyPosition(rect.left, rect.top);
  });

  setMinimized(loadMinimized());
  loadPosition();
}
