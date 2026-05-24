import { writeFile } from "node:fs/promises";

const size = 2000;
const spacing = 44;
const dotRadius = 14;
const vertexRadius = 16;

const vertices = {
  A: [1000, 240],
  B: [1760, 1000],
  C: [1000, 1760],
  D: [240, 1000],
  E: [1000, 640],
  F: [1360, 1000],
  G: [1000, 1360],
  H: [640, 1000],
};

const edges = [
  ["A", "B"],
  ["B", "C"],
  ["C", "D"],
  ["D", "A"],
  ["E", "F"],
  ["F", "G"],
  ["G", "H"],
  ["H", "E"],
  ["A", "E"],
  ["B", "F"],
  ["C", "G"],
  ["D", "H"],
];

const stops = [
  [0, "#ff2d2d"],
  [0.14, "#ff8a00"],
  [0.29, "#ffe600"],
  [0.45, "#34d84d"],
  [0.62, "#00c8ff"],
  [0.79, "#315bff"],
  [1, "#d52dff"],
];

function hexToRgb(hex) {
  const value = hex.replace("#", "");
  return [
    Number.parseInt(value.slice(0, 2), 16),
    Number.parseInt(value.slice(2, 4), 16),
    Number.parseInt(value.slice(4, 6), 16),
  ];
}

function rgbToHex([r, g, b]) {
  const toHex = (value) => Math.round(value).toString(16).padStart(2, "0");
  return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}

function mix(a, b, t) {
  return a.map((channel, index) => channel + (b[index] - channel) * t);
}

function rainbowColor(x, y) {
  const t = Math.max(0, Math.min(1, (x - 240 + (y - 240) * 0.55) / (1520 + 1520 * 0.55)));
  for (let i = 0; i < stops.length - 1; i += 1) {
    const [leftT, leftColor] = stops[i];
    const [rightT, rightColor] = stops[i + 1];
    if (t >= leftT && t <= rightT) {
      const localT = (t - leftT) / (rightT - leftT);
      return rgbToHex(mix(hexToRgb(leftColor), hexToRgb(rightColor), localT));
    }
  }
  return stops.at(-1)[1];
}

function circle([x, y], radius) {
  return `<circle cx="${x.toFixed(2)}" cy="${y.toFixed(2)}" r="${radius}" fill="${rainbowColor(x, y)}"/>`;
}

const dots = [];

for (const [startKey, endKey] of edges) {
  const start = vertices[startKey];
  const end = vertices[endKey];
  const dx = end[0] - start[0];
  const dy = end[1] - start[1];
  const distance = Math.hypot(dx, dy);
  const count = Math.max(1, Math.floor(distance / spacing) - 1);

  for (let index = 1; index <= count; index += 1) {
    const t = index / (count + 1);
    dots.push(circle([start[0] + dx * t, start[1] + dy * t], dotRadius));
  }
}

for (const point of Object.values(vertices)) {
  dots.push(circle(point, vertexRadius));
}

const svg = `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" xmlns="http://www.w3.org/2000/svg">
  <rect width="${size}" height="${size}" fill="#ffffff"/>
  <g>
    ${dots.join("\n    ")}
  </g>
</svg>
`;

await writeFile("canva_icon_candidates/lut_cube_dotted_icon_refined.svg", svg);
