const API_URL = window.INCIDENTOPS_API_URL || "";

const form = document.querySelector("#incident-form");
const incidents = document.querySelector("#incidents");
const refresh = document.querySelector("#refresh");

function renderIncidents(items) {
  if (!items.length) {
    incidents.innerHTML = "<p class=\"item-meta\">Aucun incident pour le moment.</p>";
    return;
  }

  incidents.innerHTML = items
    .map(
      (item) => `
        <article class="item">
          <div>
            <p class="item-title">${escapeHtml(item.title)}</p>
            <p class="item-meta">Status: ${escapeHtml(item.status)} · ID: ${escapeHtml(item.id)}</p>
          </div>
          <span class="badge">${escapeHtml(item.severity)}</span>
        </article>
      `
    )
    .join("");
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

async function loadIncidents() {
  if (!API_URL) {
    renderIncidents([
      {
        id: "local-demo",
        title: "Configure window.INCIDENTOPS_API_URL after deployment",
        severity: "medium",
        status: "open",
      },
    ]);
    return;
  }

  const response = await fetch(`${API_URL}/incidents`);
  const data = await response.json();
  renderIncidents(data.items || []);
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();

  const payload = {
    title: form.title.value,
    severity: form.severity.value,
  };

  if (!API_URL) {
    renderIncidents([{ id: "preview", title: payload.title, severity: payload.severity, status: "open" }]);
    form.reset();
    return;
  }

  await fetch(`${API_URL}/incidents`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });

  form.reset();
  await loadIncidents();
});

refresh.addEventListener("click", loadIncidents);
loadIncidents();

