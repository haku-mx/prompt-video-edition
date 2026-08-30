// app.js — UI mínima de Haku. Sin framework ni build.
// La URL del backend vive en UN solo lugar:
const API_BASE = ""; // mismo origen que sirve esta página

const $ = (sel) => document.querySelector(sel);
let currentIndex = null; // índice del video seleccionado

async function api(path, opts) {
  const res = await fetch(API_BASE + path, opts);
  if (!res.ok) {
    let detail = res.statusText;
    try { detail = (await res.json()).detail || detail; } catch (_) {}
    throw new Error(detail);
  }
  return res.json();
}

// ---- 1. Listar videos ------------------------------------------------------
async function loadVideos() {
  const sel = $("#video-select");
  sel.innerHTML = "";
  try {
    const data = await api("/api/videos");
    $("#videos-dir").textContent = "Carpeta: " + data.videos_dir;
    if (!data.videos.length) {
      const o = document.createElement("option");
      o.textContent = "(coloca un video en esa carpeta y pulsa ↻)";
      o.disabled = true;
      sel.appendChild(o);
      return;
    }
    for (const v of data.videos) {
      const o = document.createElement("option");
      o.value = v.filename;
      o.dataset.videoId = v.video_id;
      o.textContent = v.filename + (v.indexed ? "  ✓ indexado" : "");
      sel.appendChild(o);
    }
  } catch (e) {
    $("#videos-dir").textContent = "Error listando videos: " + e.message;
  }
}

// ---- 2. Indexar ------------------------------------------------------------
async function indexVideo() {
  const opt = $("#video-select").selectedOptions[0];
  if (!opt || !opt.value) return;
  setStatus("#index-status", "Indexando… (detección de shots + transcripción; "
    + "puede tardar en videos largos)");
  disable(true);
  try {
    currentIndex = await api("/api/index", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ filename: opt.value }),
    });
    renderShots(currentIndex);
    setStatus("#index-status", `Listo: ${currentIndex.shots.length} shots · `
      + `fps ${currentIndex.video.fps.toFixed(3)} · `
      + `${currentIndex.video.duration_s.toFixed(1)}s`);
    $("#shots-card").hidden = false;
    $("#prompt-card").hidden = false;
  } catch (e) {
    setStatus("#index-status", "Error: " + e.message);
  } finally {
    disable(false);
  }
}

function renderShots(index) {
  const tbody = $("#shots-table tbody");
  tbody.innerHTML = "";
  for (const s of index.shots) {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${s.shot_id}</td>
      <td>${s.in_tc} → ${s.out_tc}</td>
      <td>${s.duration_s.toFixed(2)}</td>
      <td>${bar(s.brightness)}</td>
      <td>${bar(s.motion)}</td>
      <td class="tx">${escapeHtml(s.transcript).slice(0, 120)}</td>`;
    tbody.appendChild(tr);
  }
}

// ---- 3+4. Cortar y reproducir ---------------------------------------------
async function makeCut() {
  if (!currentIndex) return;
  const prompt = $("#prompt").value.trim();
  if (!prompt) return;
  setStatus("#cut-status", "Pensando el corte con Claude…");
  disable(true);
  try {
    const r = await api("/api/cut", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ video_id: currentIndex.video.id, prompt }),
    });
    $("#rationale").textContent = r.rationale || "";
    const list = $("#clips-list");
    list.innerHTML = "";
    for (const c of r.clips) {
      const li = document.createElement("li");
      li.innerHTML = `<b>${c.shot_id}</b> ${c.in_tc} → ${c.out_tc}`
        + (c.reason ? ` — <span class="reason">${escapeHtml(c.reason)}</span>` : "");
      list.appendChild(li);
    }
    const player = $("#player");
    player.src = r.mp4_url + "?t=" + Date.now(); // evita caché del corte anterior
    player.load();
    $("#otio-link").href = r.otio_url;
    $("#result-card").hidden = false;
    setStatus("#cut-status", `Corte listo: ${r.clips.length} clips`
      + (r.invalid.length ? ` (se ignoraron ${r.invalid.length} inexistentes)` : ""));
  } catch (e) {
    setStatus("#cut-status", "Error: " + e.message);
  } finally {
    disable(false);
  }
}

// ---- helpers ---------------------------------------------------------------
function bar(v) {
  const pct = Math.round((v || 0) * 100);
  return `<span class="meter"><i style="width:${pct}%"></i></span>`;
}
function escapeHtml(s) {
  return (s || "").replace(/[&<>"]/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
}
function setStatus(sel, msg) { $(sel).textContent = msg; }
function disable(v) {
  for (const id of ["#btn-index", "#btn-cut", "#btn-refresh"])
    $(id).disabled = v;
}

$("#btn-refresh").addEventListener("click", loadVideos);
$("#btn-index").addEventListener("click", indexVideo);
$("#btn-cut").addEventListener("click", makeCut);
loadVideos();
