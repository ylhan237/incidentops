const API_URL = window.INCIDENTOPS_API_URL || "";

const form = document.querySelector("#incident-form");
const incidentsContainer = document.querySelector("#incidents");
const refreshButton = document.querySelector("#refresh");
const feedback = document.querySelector("#feedback");
const searchInput = document.querySelector("#search-input");
const severityFilter = document.querySelector("#severity-filter");
const apiStatus = document.querySelector("#api-status");

const stats = {
  total: document.querySelector("#stat-total"),
  open: document.querySelector("#stat-open"),
  high: document.querySelector("#stat-high"),
  resolved: document.querySelector("#stat-resolved"),
};

let incidentState = [];
const LOCAL_STORAGE_KEY = "incidentops-local-incidents";
function loadLocalIncidents() {
  const storedIncidents = localStorage.getItem(LOCAL_STORAGE_KEY);

  if (!storedIncidents) {
    return [];
  }

  try {
    const parsedIncidents = JSON.parse(storedIncidents);

    return Array.isArray(parsedIncidents)
      ? parsedIncidents
      : [];
  } catch {
    return [];
  }
}

function saveLocalIncidents(items) {
  localStorage.setItem(
    LOCAL_STORAGE_KEY,
    JSON.stringify(items)
  );
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function normalize(value) {
  return String(value ?? "").trim().toLowerCase();
}

function setFeedback(message = "", type = "") {
  feedback.textContent = message;
  feedback.className = `feedback${type ? ` ${type}` : ""}`;
}

function setApiStatus(mode, message) {
  apiStatus.classList.remove("offline", "demo");

  if (mode === "offline") {
    apiStatus.classList.add("offline");
  }

  if (mode === "demo") {
    apiStatus.classList.add("demo");
  }

  apiStatus.querySelector(".api-status-value").textContent = message;
}

function renderLoading() {
  incidentsContainer.innerHTML = `
    <div class="loading-skeleton"></div>
    <div class="loading-skeleton"></div>
    <div class="loading-skeleton"></div>
  `;
}

function updateStats(items) {
  stats.total.textContent = items.length;

  stats.open.textContent = items.filter(
    (item) => normalize(item.status) === "open"
  ).length;

  stats.high.textContent = items.filter(
    (item) => normalize(item.severity) === "high"
  ).length;

  stats.resolved.textContent = items.filter(
    (item) => normalize(item.status) === "resolved"
  ).length;
}

function getFilteredIncidents() {
  const query = normalize(searchInput.value);
  const selectedSeverity = normalize(severityFilter.value);

  return incidentState.filter((item) => {
    const matchesQuery =
      !query ||
      normalize(item.title).includes(query) ||
      normalize(item.status).includes(query) ||
      normalize(item.id).includes(query);

    const matchesSeverity =
      selectedSeverity === "all" ||
      normalize(item.severity) === selectedSeverity;

    return matchesQuery && matchesSeverity;
  });
}

function renderIncidents(items) {
  updateStats(incidentState);

  if (!items.length) {
    incidentsContainer.innerHTML = `
      <div class="empty-state">
        <div>
          <span class="empty-state-icon" aria-hidden="true">◇</span>
          <p>Aucun incident ne correspond à votre recherche.</p>
        </div>
      </div>
    `;
    return;
  }

  incidentsContainer.innerHTML = items
    .map((item) => {
      const severity = normalize(item.severity) || "low";
      const status = normalize(item.status) || "unknown";

      return `
        <article class="incident-card">
          <div>
            <p class="incident-title">${escapeHtml(item.title)}</p>

            <p class="incident-meta">
              ID : ${escapeHtml(item.id)} · Statut : ${escapeHtml(status)}
            </p>
          </div>

          <div class="incident-badges">
            <span class="badge badge-${escapeHtml(severity)}">
              ${escapeHtml(severity)}
            </span>

            <span class="badge badge-status">
              ${escapeHtml(status)}
            </span>
          </div>
        </article>
      `;
    })
    .join("");
}

function refreshFilteredView() {
  renderIncidents(getFilteredIncidents());
}

async function loadIncidents() {
  setFeedback("");
  renderLoading();

  if (!API_URL) {
  incidentState = loadLocalIncidents();

  setApiStatus("demo", "Mode démonstration");

  setFeedback(
    "Mode local : les incidents sont conservés dans le navigateur."
  );

  refreshFilteredView();
  return;
}

  try {
    const response = await fetch(`${API_URL}/incidents`);

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const data = await response.json();

    incidentState = Array.isArray(data.items)
      ? data.items
      : [];

    setApiStatus("online", "API opérationnelle");

    setFeedback(
      `${incidentState.length} incident${
        incidentState.length > 1 ? "s" : ""
      } chargé${
        incidentState.length > 1 ? "s" : ""
      }.`,
      "success"
    );

    refreshFilteredView();
  } catch (error) {
    incidentState = [];

    updateStats(incidentState);

    incidentsContainer.innerHTML = `
      <div class="empty-state">
        <div>
          <span class="empty-state-icon" aria-hidden="true">!</span>
          <p>Impossible de charger les incidents.</p>
        </div>
      </div>
    `;

    setApiStatus("offline", "API indisponible");

    setFeedback(
      `Erreur de chargement : ${error.message}`,
      "error"
    );
  }
}

async function createIncident(event) {
  event.preventDefault();

  const submitButton = form.querySelector(
    'button[type="submit"]'
  );

  const payload = {
    title: form.title.value.trim(),
    severity: form.severity.value,
  };

  if (!payload.title) {
    setFeedback(
      "Le titre de l’incident est obligatoire.",
      "error"
    );

    form.title.focus();
    return;
  }

  submitButton.disabled = true;
  submitButton.textContent = "Création en cours…";

  setFeedback("");

  try {
    if (!API_URL) {
      const newIncident = {
        id: crypto.randomUUID(),
        title: payload.title,
        severity: payload.severity,
        status: "open",
      };

      incidentState = [
        newIncident,
        ...incidentState,
      ];

      saveLocalIncidents(incidentState);

      setApiStatus("demo", "Mode démonstration");

      setFeedback(
        "Incident créé et sauvegardé localement.",
        "success"
      );

      form.reset();
      refreshFilteredView();
      return;
    }

    const response = await fetch(
      `${API_URL}/incidents`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify(payload),
      }
    );

    if (!response.ok) {
      const errorBody = await response.text();

      throw new Error(
        errorBody || `HTTP ${response.status}`
      );
    }

    form.reset();

    setFeedback(
      "Incident créé avec succès.",
      "success"
    );

    await loadIncidents();
  } catch (error) {
    setFeedback(
      `Création impossible : ${error.message}`,
      "error"
    );
  } finally {
    submitButton.disabled = false;

    submitButton.innerHTML =
      '<span aria-hidden="true">＋</span> Créer l’incident';
  }
}

form.addEventListener(
  "submit",
  createIncident
);

refreshButton.addEventListener(
  "click",
  loadIncidents
);

searchInput.addEventListener(
  "input",
  refreshFilteredView
);

severityFilter.addEventListener(
  "change",
  refreshFilteredView
);

loadIncidents();