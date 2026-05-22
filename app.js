const STORAGE_KEY = "lut-manager.records.v1";

const defaultTuning = Object.freeze({
  exposure: 0,
  contrast: 0,
  saturation: 0,
  luminance: 0,
  temperature: 0,
  tint: 0,
  hueShift: 0,
  redSat: 0,
  redLum: 0,
  greenSat: 0,
  greenLum: 0,
  blueSat: 0,
  blueLum: 0
});

const tuningDefs = [
  { key: "exposure", label: "曝光", min: -50, max: 50, unit: "" },
  { key: "contrast", label: "对比", min: -60, max: 60, unit: "" },
  { key: "saturation", label: "饱和", min: -70, max: 90, unit: "" },
  { key: "luminance", label: "明度", min: -50, max: 50, unit: "" },
  { key: "temperature", label: "色温", min: -50, max: 50, unit: "" },
  { key: "tint", label: "色调", min: -50, max: 50, unit: "" },
  { key: "hueShift", label: "色相", min: -180, max: 180, unit: "°" },
  { key: "redSat", label: "红饱和", min: -60, max: 80, unit: "" },
  { key: "redLum", label: "红明度", min: -40, max: 40, unit: "" },
  { key: "greenSat", label: "绿饱和", min: -60, max: 80, unit: "" },
  { key: "greenLum", label: "绿明度", min: -40, max: 40, unit: "" },
  { key: "blueSat", label: "蓝饱和", min: -60, max: 80, unit: "" },
  { key: "blueLum", label: "蓝明度", min: -40, max: 40, unit: "" }
];

const sampleLuts = [
  {
    id: "lut_fuji_eterna_soft_001",
    name: "Eterna Soft Contrast",
    fileName: "Eterna_Soft_Contrast.cube",
    category: "Log矫正",
    cameraCompatibility: [
      { brand: "Fujifilm", models: ["X-H2S", "X-T5"], profile: "F-Log2" }
    ],
    author: "LUT Manager Demo",
    colorStyle: "柔和高光、低对比、胶片肤色",
    tags: ["F-Log2", "电影感", "肤色"],
    notes: "适合日间室外和采访素材。原始 LUT 文件保持只读，描述信息保存在 JSON sidecar。",
    cloud: {
      provider: "iCloud Drive",
      relativePath: "LUT Manager/Fujifilm/Eterna_Soft_Contrast.cube",
      lastSyncedAt: "2026-05-22T00:00:00Z"
    },
    previewTuning: {
      exposure: 2,
      contrast: -12,
      saturation: 12,
      luminance: 1,
      temperature: 4,
      tint: 1,
      hueShift: -2,
      redSat: 10,
      redLum: 5,
      greenSat: -8,
      greenLum: 2,
      blueSat: -4,
      blueLum: 5
    },
    createdAt: "2026-05-22T00:00:00Z",
    updatedAt: "2026-05-22T00:00:00Z"
  },
  {
    id: "lut_kodak_warm_retro_002",
    name: "Kodak Patio 2383",
    fileName: "Kodak_Patio_2383.cube",
    category: "复古",
    cameraCompatibility: [
      { brand: "Sony", models: ["FX3", "A7S III"], profile: "S-Log3" },
      { brand: "Canon", models: ["R5 C"], profile: "C-Log3" }
    ],
    author: "LUT Manager Demo",
    colorStyle: "暖阴影、橙红肤色、青绿色暗部",
    tags: ["复古", "胶片", "暖色"],
    notes: "偏强风格化，适合旅行、生活方式和城市夜景。",
    cloud: {
      provider: "OneDrive",
      relativePath: "Color/LUTs/Kodak_Patio_2383.cube",
      lastSyncedAt: "2026-05-22T00:00:00Z"
    },
    previewTuning: {
      exposure: 1,
      contrast: 18,
      saturation: 14,
      luminance: -2,
      temperature: 14,
      tint: 6,
      hueShift: -5,
      redSat: 22,
      redLum: 6,
      greenSat: -18,
      greenLum: -5,
      blueSat: -12,
      blueLum: -3
    },
    createdAt: "2026-05-22T00:00:00Z",
    updatedAt: "2026-05-22T00:00:00Z"
  },
  {
    id: "lut_clean_daylight_003",
    name: "Clean Daylight Skin",
    fileName: "Clean_Daylight_Skin.cube",
    category: "清新",
    cameraCompatibility: [
      { brand: "Panasonic", models: ["S5II", "GH6"], profile: "V-Log" },
      { brand: "Nikon", models: ["Z8", "Z6 III"], profile: "N-Log" }
    ],
    author: "LUT Manager Demo",
    colorStyle: "干净白场、低污染绿色、自然肤色",
    tags: ["清新", "自然", "商业"],
    notes: "适合电商、人物采访和轻量商业片。风格保守，便于后期继续调整。",
    cloud: {
      provider: "Dropbox",
      relativePath: "LUT Manager/Clean_Daylight_Skin.cube",
      lastSyncedAt: "2026-05-22T00:00:00Z"
    },
    previewTuning: {
      exposure: 4,
      contrast: 6,
      saturation: -2,
      luminance: 4,
      temperature: -3,
      tint: 0,
      hueShift: 1,
      redSat: 3,
      redLum: 3,
      greenSat: -20,
      greenLum: 8,
      blueSat: 7,
      blueLum: 7
    },
    createdAt: "2026-05-22T00:00:00Z",
    updatedAt: "2026-05-22T00:00:00Z"
  }
];

const els = {
  searchInput: document.querySelector("#searchInput"),
  categoryStrip: document.querySelector("#categoryStrip"),
  lutList: document.querySelector("#lutList"),
  activeTitle: document.querySelector("#activeTitle"),
  previewCamera: document.querySelector("#previewCamera"),
  previewStyle: document.querySelector("#previewStyle"),
  previewCanvas: document.querySelector("#previewCanvas"),
  splitSlider: document.querySelector("#splitSlider"),
  detailCategory: document.querySelector("#detailCategory"),
  detailAuthor: document.querySelector("#detailAuthor"),
  detailCameras: document.querySelector("#detailCameras"),
  detailColorStyle: document.querySelector("#detailColorStyle"),
  detailTags: document.querySelector("#detailTags"),
  detailNotes: document.querySelector("#detailNotes"),
  photoInput: document.querySelector("#photoInput"),
  cubeInput: document.querySelector("#cubeInput"),
  metadataInput: document.querySelector("#metadataInput"),
  resetPhotoButton: document.querySelector("#resetPhotoButton"),
  pickFolderButton: document.querySelector("#pickFolderButton"),
  exportMetadataButton: document.querySelector("#exportMetadataButton"),
  addDemoButton: document.querySelector("#addDemoButton"),
  copyRecordButton: document.querySelector("#copyRecordButton"),
  saveMetadataButton: document.querySelector("#saveMetadataButton"),
  metadataEditor: document.querySelector("#metadataEditor"),
  tuningControls: document.querySelector("#tuningControls"),
  resetTuningButton: document.querySelector("#resetTuningButton"),
  addGeneratedButton: document.querySelector("#addGeneratedButton"),
  downloadCubeButton: document.querySelector("#downloadCubeButton"),
  newLutName: document.querySelector("#newLutName"),
  newLutCamera: document.querySelector("#newLutCamera"),
  syncStatus: document.querySelector("#syncStatus")
};

const ctx = els.previewCanvas.getContext("2d", { willReadFrequently: true });

const state = {
  luts: loadRecords(),
  selectedId: "",
  filter: "全部",
  query: "",
  split: 50,
  activePanel: "preview",
  originalImageData: null,
  tuning: { ...defaultTuning }
};

init();

function init() {
  if (!state.luts.length) {
    state.luts = structuredClone(sampleLuts);
    saveRecords();
  }
  state.selectedId = state.luts[0]?.id || "";
  drawDemoReference();
  renderTuningControls();
  bindEvents();
  renderAll();
}

function bindEvents() {
  els.searchInput.addEventListener("input", (event) => {
    state.query = event.target.value.trim();
    renderLibrary();
  });

  els.splitSlider.addEventListener("input", (event) => {
    state.split = Number(event.target.value);
    renderPreview();
  });

  document.querySelectorAll(".tab").forEach((tab) => {
    tab.addEventListener("click", () => {
      state.activePanel = tab.dataset.tab;
      document.querySelectorAll(".tab").forEach((node) => node.classList.toggle("active", node === tab));
      document.querySelectorAll("[data-panel]").forEach((panel) => {
        panel.classList.toggle("hidden", panel.dataset.panel !== state.activePanel);
      });
      renderPreview();
    });
  });

  els.photoInput.addEventListener("change", async (event) => {
    const [file] = event.target.files;
    if (file) {
      await loadReferencePhoto(file);
      event.target.value = "";
    }
  });

  els.cubeInput.addEventListener("change", async (event) => {
    const [file] = event.target.files;
    if (file) {
      await importCube(file);
      event.target.value = "";
    }
  });

  els.metadataInput.addEventListener("change", async (event) => {
    const [file] = event.target.files;
    if (file) {
      await importMetadata(file);
      event.target.value = "";
    }
  });

  els.resetPhotoButton.addEventListener("click", () => {
    drawDemoReference();
    renderPreview();
  });

  els.pickFolderButton.addEventListener("click", pickSyncFolder);
  els.exportMetadataButton.addEventListener("click", exportMetadata);
  els.addDemoButton.addEventListener("click", restoreSamples);
  els.copyRecordButton.addEventListener("click", copyCurrentRecord);
  els.saveMetadataButton.addEventListener("click", saveCurrentMetadata);
  els.resetTuningButton.addEventListener("click", resetTuning);
  els.addGeneratedButton.addEventListener("click", addGeneratedLut);
  els.downloadCubeButton.addEventListener("click", downloadGeneratedCube);
}

function loadRecords() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

function saveRecords() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state.luts));
}

function renderAll() {
  renderCategories();
  renderLibrary();
  renderDetails();
  renderPreview();
}

function renderCategories() {
  const categories = ["全部", ...new Set(state.luts.map((lut) => lut.category).filter(Boolean))];
  els.categoryStrip.innerHTML = "";
  categories.forEach((category) => {
    const button = document.createElement("button");
    button.className = `chip${state.filter === category ? " active" : ""}`;
    button.textContent = category;
    button.addEventListener("click", () => {
      state.filter = category;
      renderCategories();
      renderLibrary();
    });
    els.categoryStrip.append(button);
  });
}

function renderLibrary() {
  const query = state.query.toLowerCase();
  const records = state.luts.filter((lut) => {
    const matchesFilter = state.filter === "全部" || lut.category === state.filter;
    const haystack = [
      lut.name,
      lut.category,
      lut.author,
      lut.colorStyle,
      lut.fileName,
      cameraSummary(lut),
      ...(lut.tags || [])
    ].join(" ").toLowerCase();
    return matchesFilter && (!query || haystack.includes(query));
  });

  els.lutList.innerHTML = "";
  if (!records.length) {
    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.textContent = "没有找到匹配的 LUT。可以导入 .cube，或者清空搜索条件。";
    els.lutList.append(empty);
    return;
  }

  records.forEach((lut) => {
    const button = document.createElement("button");
    button.className = `lut-card${lut.id === state.selectedId ? " active" : ""}`;
    button.innerHTML = `
      <strong>${escapeHtml(lut.name)}</strong>
      <span><i class="category-dot"></i>${escapeHtml(lut.category || "未分类")} · ${escapeHtml(lut.author || "未知作者")}</span>
      <span>${escapeHtml(cameraSummary(lut))}</span>
    `;
    button.addEventListener("click", () => {
      state.selectedId = lut.id;
      renderLibrary();
      renderDetails();
      renderPreview();
    });
    els.lutList.append(button);
  });
}

function renderDetails() {
  const lut = selectedLut();
  if (!lut) return;

  els.activeTitle.textContent = lut.name;
  els.previewCamera.textContent = cameraSummary(lut);
  els.previewStyle.textContent = lut.colorStyle || lut.category || "-";
  els.detailCategory.textContent = lut.category || "-";
  els.detailAuthor.textContent = lut.author || "-";
  els.detailCameras.textContent = cameraSummary(lut);
  els.detailColorStyle.textContent = lut.colorStyle || "-";
  els.detailNotes.textContent = lut.notes || "-";
  els.detailTags.innerHTML = "";
  (lut.tags || []).forEach((tag) => {
    const tagNode = document.createElement("span");
    tagNode.className = "tag";
    tagNode.textContent = tag;
    els.detailTags.append(tagNode);
  });
  els.metadataEditor.value = JSON.stringify(sanitizeRecord(lut), null, 2);
}

function selectedLut() {
  return state.luts.find((lut) => lut.id === state.selectedId) || state.luts[0];
}

function cameraSummary(lut) {
  const items = lut.cameraCompatibility || [];
  if (!items.length) return "通用 / 未指定";
  return items
    .map((item) => {
      const models = Array.isArray(item.models) ? item.models.join(", ") : item.models || "";
      return `${item.brand || "Unknown"} ${models}${item.profile ? ` / ${item.profile}` : ""}`.trim();
    })
    .join("；");
}

function sanitizeRecord(lut) {
  const { cubeText, parsedCube, ...record } = lut;
  return record;
}

function renderTuningControls() {
  els.tuningControls.innerHTML = "";
  tuningDefs.forEach((def) => {
    const row = document.createElement("label");
    row.className = "control-row";
    row.innerHTML = `
      <span>${def.label}</span>
      <input type="range" min="${def.min}" max="${def.max}" step="1" value="${state.tuning[def.key] || 0}" data-tuning="${def.key}">
      <output>${formatTuningValue(state.tuning[def.key] || 0, def.unit)}</output>
    `;
    const input = row.querySelector("input");
    const output = row.querySelector("output");
    input.addEventListener("input", () => {
      state.tuning[def.key] = Number(input.value);
      output.textContent = formatTuningValue(state.tuning[def.key], def.unit);
      if (state.activePanel === "maker") renderPreview();
    });
    els.tuningControls.append(row);
  });
}

function updateTuningControls() {
  document.querySelectorAll("[data-tuning]").forEach((input) => {
    const key = input.dataset.tuning;
    input.value = state.tuning[key] || 0;
    const def = tuningDefs.find((item) => item.key === key);
    input.parentElement.querySelector("output").textContent = formatTuningValue(state.tuning[key] || 0, def?.unit || "");
  });
}

function formatTuningValue(value, unit) {
  const prefix = value > 0 ? "+" : "";
  return `${prefix}${value}${unit}`;
}

function renderPreview() {
  if (!state.originalImageData) return;
  const source = state.originalImageData;
  const result = new ImageData(new Uint8ClampedArray(source.data), source.width, source.height);

  if (state.activePanel === "maker") {
    applyTuningToImage(result, state.tuning);
  } else {
    const lut = selectedLut();
    const cube = getCube(lut);
    if (cube) {
      applyCubeToImage(result, cube);
    } else {
      applyTuningToImage(result, { ...defaultTuning, ...(lut?.previewTuning || {}) });
    }
  }

  const splitX = Math.round(source.width * (state.split / 100));
  ctx.putImageData(result, 0, 0);
  ctx.save();
  ctx.beginPath();
  ctx.rect(0, 0, splitX, source.height);
  ctx.clip();
  ctx.putImageData(source, 0, 0);
  ctx.restore();

  drawSplitOverlay(splitX);
}

function drawSplitOverlay(splitX) {
  const { width, height } = els.previewCanvas;
  ctx.save();
  ctx.fillStyle = "rgba(0, 0, 0, 0.34)";
  ctx.fillRect(0, 0, 112, 36);
  ctx.fillRect(width - 112, 0, 112, 36);
  ctx.fillStyle = "#eef3f0";
  ctx.font = "700 16px system-ui, sans-serif";
  ctx.fillText("Before", 22, 24);
  ctx.fillText("After", width - 86, 24);
  ctx.strokeStyle = "rgba(255, 255, 255, 0.92)";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(splitX, 0);
  ctx.lineTo(splitX, height);
  ctx.stroke();
  ctx.fillStyle = "#6ed6a8";
  ctx.beginPath();
  ctx.arc(splitX, height - 48, 13, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function drawDemoReference() {
  const { width, height } = els.previewCanvas;
  const gradient = ctx.createLinearGradient(0, 0, width, height);
  gradient.addColorStop(0, "#cfe3e7");
  gradient.addColorStop(0.42, "#d7b486");
  gradient.addColorStop(1, "#1f3943");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);

  ctx.fillStyle = "#7ea49c";
  ctx.beginPath();
  ctx.moveTo(0, height * 0.48);
  ctx.bezierCurveTo(width * 0.22, height * 0.32, width * 0.36, height * 0.47, width * 0.52, height * 0.35);
  ctx.bezierCurveTo(width * 0.64, height * 0.25, width * 0.76, height * 0.4, width, height * 0.3);
  ctx.lineTo(width, height);
  ctx.lineTo(0, height);
  ctx.closePath();
  ctx.fill();

  ctx.fillStyle = "#2c4f48";
  ctx.beginPath();
  ctx.moveTo(0, height * 0.62);
  ctx.bezierCurveTo(width * 0.28, height * 0.48, width * 0.46, height * 0.67, width * 0.7, height * 0.5);
  ctx.bezierCurveTo(width * 0.84, height * 0.4, width * 0.94, height * 0.57, width, height * 0.52);
  ctx.lineTo(width, height);
  ctx.lineTo(0, height);
  ctx.closePath();
  ctx.fill();

  ctx.fillStyle = "#d49a73";
  roundRect(ctx, width * 0.64, height * 0.2, width * 0.19, height * 0.37, 34);
  ctx.fill();

  ctx.fillStyle = "#50372e";
  ctx.beginPath();
  ctx.ellipse(width * 0.735, height * 0.245, width * 0.08, height * 0.09, -0.2, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = "#f0c7a2";
  ctx.beginPath();
  ctx.ellipse(width * 0.73, height * 0.35, width * 0.055, height * 0.082, 0.05, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = "#f4efe3";
  ctx.fillRect(width * 0.07, height * 0.18, width * 0.32, height * 0.19);
  ctx.fillStyle = "#df563e";
  ctx.fillRect(width * 0.07, height * 0.37, width * 0.1, height * 0.12);
  ctx.fillStyle = "#eaa64f";
  ctx.fillRect(width * 0.17, height * 0.37, width * 0.1, height * 0.12);
  ctx.fillStyle = "#4c9d74";
  ctx.fillRect(width * 0.27, height * 0.37, width * 0.12, height * 0.12);

  ctx.fillStyle = "rgba(255, 255, 255, 0.74)";
  ctx.font = "700 28px system-ui, sans-serif";
  ctx.fillText("Reference Frame", width * 0.075, height * 0.245);
  ctx.font = "500 17px system-ui, sans-serif";
  ctx.fillText("Skin / Sky / Green / Primary Colors", width * 0.075, height * 0.292);

  state.originalImageData = ctx.getImageData(0, 0, width, height);
}

function roundRect(canvasCtx, x, y, width, height, radius) {
  canvasCtx.beginPath();
  canvasCtx.moveTo(x + radius, y);
  canvasCtx.arcTo(x + width, y, x + width, y + height, radius);
  canvasCtx.arcTo(x + width, y + height, x, y + height, radius);
  canvasCtx.arcTo(x, y + height, x, y, radius);
  canvasCtx.arcTo(x, y, x + width, y, radius);
  canvasCtx.closePath();
}

async function loadReferencePhoto(file) {
  const url = URL.createObjectURL(file);
  try {
    const img = await loadImage(url);
    drawImageCover(img);
    state.originalImageData = ctx.getImageData(0, 0, els.previewCanvas.width, els.previewCanvas.height);
    renderPreview();
  } finally {
    URL.revokeObjectURL(url);
  }
}

function loadImage(url) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = url;
  });
}

function drawImageCover(img) {
  const { width, height } = els.previewCanvas;
  const imageRatio = img.width / img.height;
  const canvasRatio = width / height;
  let drawWidth = width;
  let drawHeight = height;
  let x = 0;
  let y = 0;
  if (imageRatio > canvasRatio) {
    drawHeight = height;
    drawWidth = height * imageRatio;
    x = (width - drawWidth) / 2;
  } else {
    drawWidth = width;
    drawHeight = width / imageRatio;
    y = (height - drawHeight) / 2;
  }
  ctx.clearRect(0, 0, width, height);
  ctx.drawImage(img, x, y, drawWidth, drawHeight);
}

function applyTuningToImage(imageData, tuning) {
  const data = imageData.data;
  for (let i = 0; i < data.length; i += 4) {
    const [r, g, b] = applyTuningToColor(data[i], data[i + 1], data[i + 2], tuning);
    data[i] = r;
    data[i + 1] = g;
    data[i + 2] = b;
  }
}

function applyTuningToColor(r, g, b, tuning) {
  const t = { ...defaultTuning, ...tuning };
  let rn = clamp01(r / 255);
  let gn = clamp01(g / 255);
  let bn = clamp01(b / 255);

  const temp = t.temperature / 220;
  const tint = t.tint / 260;
  rn = clamp01(rn + temp + tint * 0.5);
  gn = clamp01(gn - tint);
  bn = clamp01(bn - temp + tint * 0.5);

  let [h, s, l] = rgbToHsl(rn, gn, bn);
  h = (h + t.hueShift / 360 + 1) % 1;

  const redWeight = hueWeight(h, 0);
  const greenWeight = hueWeight(h, 1 / 3);
  const blueWeight = hueWeight(h, 2 / 3);
  const satLift = (t.redSat * redWeight + t.greenSat * greenWeight + t.blueSat * blueWeight) / 100;
  const lumLift = (t.redLum * redWeight + t.greenLum * greenWeight + t.blueLum * blueWeight) / 100;

  s = clamp01(s * (1 + t.saturation / 100 + satLift));
  l = clamp01(l + t.luminance / 100 + lumLift * 0.45);

  [rn, gn, bn] = hslToRgb(h, s, l);

  const exposure = Math.pow(2, t.exposure / 50);
  const contrast = 1 + t.contrast / 100;
  rn = clamp01((rn * exposure - 0.5) * contrast + 0.5);
  gn = clamp01((gn * exposure - 0.5) * contrast + 0.5);
  bn = clamp01((bn * exposure - 0.5) * contrast + 0.5);

  return [rn * 255, gn * 255, bn * 255];
}

function hueWeight(hue, center) {
  const distance = Math.min(Math.abs(hue - center), 1 - Math.abs(hue - center));
  return clamp01(1 - distance / 0.19);
}

function rgbToHsl(r, g, b) {
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  let h = 0;
  let s = 0;
  const l = (max + min) / 2;
  const d = max - min;
  if (d !== 0) {
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    if (max === r) h = (g - b) / d + (g < b ? 6 : 0);
    if (max === g) h = (b - r) / d + 2;
    if (max === b) h = (r - g) / d + 4;
    h /= 6;
  }
  return [h, s, l];
}

function hslToRgb(h, s, l) {
  if (s === 0) return [l, l, l];
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p = 2 * l - q;
  return [
    hueToRgb(p, q, h + 1 / 3),
    hueToRgb(p, q, h),
    hueToRgb(p, q, h - 1 / 3)
  ];
}

function hueToRgb(p, q, t) {
  let value = t;
  if (value < 0) value += 1;
  if (value > 1) value -= 1;
  if (value < 1 / 6) return p + (q - p) * 6 * value;
  if (value < 1 / 2) return q;
  if (value < 2 / 3) return p + (q - p) * (2 / 3 - value) * 6;
  return p;
}

function clamp01(value) {
  return Math.max(0, Math.min(1, value));
}

function getCube(lut) {
  if (!lut?.cubeText) return null;
  if (!lut.parsedCube) {
    try {
      lut.parsedCube = parseCube(lut.cubeText);
    } catch {
      lut.parsedCube = null;
    }
  }
  return lut.parsedCube;
}

function parseCube(text) {
  const lines = text.split(/\r?\n/);
  let size = 0;
  const values = [];

  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const parts = line.split(/\s+/);
    if (parts[0] === "LUT_3D_SIZE") {
      size = Number(parts[1]);
      continue;
    }
    if (/^[A-Z_]+$/i.test(parts[0])) continue;
    if (parts.length >= 3) {
      const rgb = parts.slice(0, 3).map(Number);
      if (rgb.every(Number.isFinite)) values.push(...rgb.map(clamp01));
    }
  }

  if (!size || values.length !== size * size * size * 3) {
    throw new Error("Unsupported or invalid .cube file.");
  }
  return { size, data: new Float32Array(values) };
}

function applyCubeToImage(imageData, cube) {
  const data = imageData.data;
  for (let i = 0; i < data.length; i += 4) {
    const [r, g, b] = sampleCube(cube, data[i] / 255, data[i + 1] / 255, data[i + 2] / 255);
    data[i] = r * 255;
    data[i + 1] = g * 255;
    data[i + 2] = b * 255;
  }
}

function sampleCube(cube, r, g, b) {
  const max = cube.size - 1;
  const rf = clamp01(r) * max;
  const gf = clamp01(g) * max;
  const bf = clamp01(b) * max;
  const r0 = Math.floor(rf);
  const g0 = Math.floor(gf);
  const b0 = Math.floor(bf);
  const r1 = Math.min(r0 + 1, max);
  const g1 = Math.min(g0 + 1, max);
  const b1 = Math.min(b0 + 1, max);
  const tr = rf - r0;
  const tg = gf - g0;
  const tb = bf - b0;

  const c000 = cubeAt(cube, r0, g0, b0);
  const c100 = cubeAt(cube, r1, g0, b0);
  const c010 = cubeAt(cube, r0, g1, b0);
  const c110 = cubeAt(cube, r1, g1, b0);
  const c001 = cubeAt(cube, r0, g0, b1);
  const c101 = cubeAt(cube, r1, g0, b1);
  const c011 = cubeAt(cube, r0, g1, b1);
  const c111 = cubeAt(cube, r1, g1, b1);

  return [0, 1, 2].map((channel) => {
    const x00 = lerp(c000[channel], c100[channel], tr);
    const x10 = lerp(c010[channel], c110[channel], tr);
    const x01 = lerp(c001[channel], c101[channel], tr);
    const x11 = lerp(c011[channel], c111[channel], tr);
    const y0 = lerp(x00, x10, tg);
    const y1 = lerp(x01, x11, tg);
    return lerp(y0, y1, tb);
  });
}

function cubeAt(cube, r, g, b) {
  const index = ((b * cube.size * cube.size) + (g * cube.size) + r) * 3;
  return [cube.data[index], cube.data[index + 1], cube.data[index + 2]];
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

async function importCube(file) {
  const text = await file.text();
  try {
    parseCube(text);
  } catch (error) {
    notify("这个 .cube 文件暂时无法解析。请确认它是 3D LUT。");
    return;
  }

  const now = new Date().toISOString();
  const record = {
    id: `lut_imported_${Date.now()}`,
    name: file.name.replace(/\.cube$/i, "").replace(/[_-]+/g, " "),
    fileName: file.name,
    category: "未分类",
    cameraCompatibility: [{ brand: "通用", models: ["未指定"], profile: "" }],
    author: "导入",
    colorStyle: "来自 .cube 文件",
    tags: ["Imported", ".cube"],
    notes: "该记录由导入的 .cube 文件创建。原文件不会被修改，描述信息可在元数据面板中编辑。",
    cloud: {
      provider: "Local Folder",
      relativePath: file.name,
      lastSyncedAt: now
    },
    previewTuning: { ...defaultTuning },
    cubeText: text,
    createdAt: now,
    updatedAt: now
  };
  state.luts.unshift(record);
  state.selectedId = record.id;
  saveRecords();
  renderAll();
  notify("已导入 .cube 并生成一条元数据记录。");
}

async function importMetadata(file) {
  try {
    const text = await file.text();
    const payload = JSON.parse(text);
    const records = Array.isArray(payload) ? payload : payload.luts;
    if (!Array.isArray(records)) throw new Error("Invalid metadata file.");
    const now = new Date().toISOString();
    records.forEach((record) => {
      if (!record.id) record.id = `lut_metadata_${Date.now()}_${Math.random().toString(16).slice(2)}`;
      record.updatedAt = now;
      const index = state.luts.findIndex((lut) => lut.id === record.id);
      if (index >= 0) {
        state.luts[index] = { ...state.luts[index], ...record };
      } else {
        state.luts.unshift(record);
      }
    });
    state.selectedId = records[0]?.id || state.selectedId;
    saveRecords();
    renderAll();
    notify("元数据已导入。");
  } catch {
    notify("JSON 元数据无法导入，请检查文件格式。");
  }
}

async function pickSyncFolder() {
  if (!("showDirectoryPicker" in window)) {
    els.syncStatus.textContent = "当前浏览器不支持直接选择文件夹。桌面版会使用系统文件夹权限；现在可先用 JSON 导入/导出同步。";
    return;
  }

  try {
    const handle = await window.showDirectoryPicker({ mode: "readwrite" });
    els.syncStatus.textContent = `已选择同步文件夹：${handle.name}。未来会在这里放 .cube 和 .lutmanager.json。`;
  } catch {
    els.syncStatus.textContent = "未选择同步文件夹。";
  }
}

function exportMetadata() {
  const payload = {
    app: "LUT Manager",
    schemaVersion: 1,
    exportedAt: new Date().toISOString(),
    luts: state.luts.map(sanitizeRecord)
  };
  downloadText("lut-manager-metadata.json", JSON.stringify(payload, null, 2), "application/json");
}

function restoreSamples() {
  const existing = new Set(state.luts.map((lut) => lut.id));
  sampleLuts.forEach((sample) => {
    if (!existing.has(sample.id)) state.luts.push(structuredClone(sample));
  });
  state.selectedId = sampleLuts[0].id;
  saveRecords();
  renderAll();
  notify("示例 LUT 已恢复。");
}

async function copyCurrentRecord() {
  try {
    await navigator.clipboard.writeText(els.metadataEditor.value);
    notify("当前元数据已复制。");
  } catch {
    els.metadataEditor.select();
    document.execCommand("copy");
    notify("当前元数据已复制。");
  }
}

function saveCurrentMetadata() {
  const lut = selectedLut();
  if (!lut) return;
  try {
    const updated = JSON.parse(els.metadataEditor.value);
    const index = state.luts.findIndex((record) => record.id === lut.id);
    state.luts[index] = {
      ...lut,
      ...updated,
      id: updated.id || lut.id,
      cubeText: lut.cubeText,
      parsedCube: lut.parsedCube,
      updatedAt: new Date().toISOString()
    };
    state.selectedId = state.luts[index].id;
    saveRecords();
    renderAll();
    notify("元数据已保存到本地库。");
  } catch {
    notify("JSON 格式有误，保存失败。");
  }
}

function resetTuning() {
  state.tuning = { ...defaultTuning };
  updateTuningControls();
  if (state.activePanel === "maker") renderPreview();
}

function addGeneratedLut() {
  const now = new Date().toISOString();
  const name = els.newLutName.value.trim() || "My HSL Look";
  const fileName = `${slugify(name)}.cube`;
  const camera = els.newLutCamera.value.trim() || "通用 / 未指定";
  const record = {
    id: `lut_custom_${Date.now()}`,
    name,
    fileName,
    category: "自定义",
    cameraCompatibility: [cameraToRecord(camera)],
    author: "用户自定义",
    colorStyle: tuningSummary(state.tuning),
    tags: ["自定义", "HSL", "Generated"],
    notes: "由参考照片和 HSL 调整生成。原始参考照片不会写入元数据。",
    cloud: {
      provider: "Local Folder",
      relativePath: fileName,
      lastSyncedAt: now
    },
    previewTuning: { ...state.tuning },
    cubeText: generateCubeText(name, state.tuning),
    createdAt: now,
    updatedAt: now
  };
  state.luts.unshift(record);
  state.selectedId = record.id;
  saveRecords();
  renderAll();
  notify("自定义 LUT 已加入库。");
}

function downloadGeneratedCube() {
  const name = els.newLutName.value.trim() || "My HSL Look";
  downloadText(`${slugify(name)}.cube`, generateCubeText(name, state.tuning), "text/plain");
}

function generateCubeText(title, tuning) {
  const size = 17;
  const lines = [
    `TITLE "${title.replace(/"/g, "'")}"`,
    `# Generated by LUT Manager prototype`,
    `LUT_3D_SIZE ${size}`,
    "DOMAIN_MIN 0.0 0.0 0.0",
    "DOMAIN_MAX 1.0 1.0 1.0"
  ];

  for (let b = 0; b < size; b += 1) {
    for (let g = 0; g < size; g += 1) {
      for (let r = 0; r < size; r += 1) {
        const [rr, gg, bb] = applyTuningToColor(
          (r / (size - 1)) * 255,
          (g / (size - 1)) * 255,
          (b / (size - 1)) * 255,
          tuning
        ).map((value) => clamp01(value / 255));
        lines.push(`${rr.toFixed(6)} ${gg.toFixed(6)} ${bb.toFixed(6)}`);
      }
    }
  }

  return `${lines.join("\n")}\n`;
}

function downloadText(filename, text, type) {
  const blob = new Blob([text], { type });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.append(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

function cameraToRecord(input) {
  const [brandModel, profile = ""] = input.split("/").map((part) => part.trim());
  const [brand = "通用", ...modelParts] = brandModel.split(/\s+/);
  return {
    brand,
    models: [modelParts.join(" ") || "未指定"],
    profile
  };
}

function tuningSummary(tuning) {
  const parts = [];
  if (tuning.hueShift) parts.push(`色相 ${formatTuningValue(tuning.hueShift, "°")}`);
  if (tuning.saturation) parts.push(`饱和 ${formatTuningValue(tuning.saturation, "")}`);
  if (tuning.contrast) parts.push(`对比 ${formatTuningValue(tuning.contrast, "")}`);
  if (tuning.temperature) parts.push(`色温 ${formatTuningValue(tuning.temperature, "")}`);
  return parts.length ? parts.join("、") : "自然 HSL 调整";
}

function slugify(value) {
  const slug = value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/gi, "_")
    .replace(/^_+|_+$/g, "");
  return slug || "custom_lut";
}

function notify(message) {
  els.syncStatus.textContent = message;
}

function escapeHtml(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
