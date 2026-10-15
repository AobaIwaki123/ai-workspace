const SVG_NS = "http://www.w3.org/2000/svg";

const art = document.querySelector("#generated-art");
const stateName = document.querySelector("#state-name");
const stateValue = document.querySelector("#state-value");
const cuteRange = document.querySelector("#cute-range");
const strongRange = document.querySelector("#strong-range");
const cuteOutput = document.querySelector("#cute-output");
const strongOutput = document.querySelector("#strong-output");

const states = {
  idle: { label: "IDLE / ふわっと始まる", value: "SOFT START", fillA: "#ff9dce", fillB: "#9b8cff", accent: "#77e4e8", motion: "idle" },
  charge: { label: "CHARGE / 力をためる", value: "GATHER POWER", fillA: "#ffb6d9", fillB: "#7ddde8", accent: "#ffe18b", motion: "charge" },
  power: { label: "POWER / つよく変わる", value: "BREAK THROUGH", fillA: "#ff88bd", fillB: "#755fff", accent: "#ffe18b", motion: "power" },
  recover: { label: "RECOVER / 立て直す", value: "BACK ON FEET", fillA: "#8ce1dd", fillB: "#9282ff", accent: "#ff9dce", motion: "recover" },
};

let currentState = "idle";

function svgElement(name, attrs = {}) {
  const node = document.createElementNS(SVG_NS, name);
  Object.entries(attrs).forEach(([key, value]) => node.setAttribute(key, value));
  return node;
}

function append(parent, name, attrs = {}) {
  const node = svgElement(name, attrs);
  parent.appendChild(node);
  return node;
}

function makeBurst(parent, state, strength) {
  const count = 8 + Math.round(strength * 8);
  const radius = 100 + strength * 32;
  for (let i = 0; i < count; i += 1) {
    const angle = (Math.PI * 2 * i) / count;
    const inner = radius - 14 - strength * 8;
    const outer = radius + 10 + strength * 20;
    const x1 = 180 + Math.cos(angle) * inner;
    const y1 = 184 + Math.sin(angle) * inner;
    const x2 = 180 + Math.cos(angle) * outer;
    const y2 = 184 + Math.sin(angle) * outer;
    append(parent, "line", {
      x1, y1, x2, y2,
      stroke: i % 2 ? state.accent : "#ffffff",
      "stroke-width": 3 + strength * 4,
      "stroke-linecap": "round",
      opacity: 0.45 + strength * 0.5,
    });
  }
}

function makeStars(parent, state, cuteness) {
  const positions = [
    [86, 100, 7], [278, 91, 5], [305, 242, 8], [62, 254, 5], [265, 48, 4],
  ];
  positions.forEach(([x, y, size], index) => {
    const points = [];
    for (let i = 0; i < 8; i += 1) {
      const radius = i % 2 ? size * 0.4 : size;
      const angle = -Math.PI / 2 + (Math.PI * 2 * i) / 8;
      points.push(`${x + Math.cos(angle) * radius},${y + Math.sin(angle) * radius}`);
    }
    append(parent, "polygon", {
      points: points.join(" "),
      fill: index % 2 ? state.accent : "#ffffff",
      opacity: 0.48 + cuteness * 0.45,
    });
  });
}

function render() {
  const state = states[currentState];
  const cuteness = Number(cuteRange.value) / 100;
  const strength = Number(strongRange.value) / 100;
  const softness = 20 + cuteness * 34;
  const stroke = 4 + strength * 5;
  const bodyWidth = 124 + cuteness * 18;
  const bodyHeight = 112 + cuteness * 24;

  art.replaceChildren();
  art.setAttribute("class", state.motion);
  stateName.textContent = state.label;
  stateValue.textContent = state.value;
  cuteOutput.value = Math.round(cuteness * 100);
  strongOutput.value = Math.round(strength * 100);

  const halo = append(art, "circle", { cx: 180, cy: 184, r: 145 + cuteness * 18, fill: "url(#halo-gradient)" });
  halo.setAttribute("opacity", 0.7 + strength * 0.3);
  makeStars(art, state, cuteness);
  if (strength > 0.25 || currentState === "power") makeBurst(art, state, strength);

  const body = append(art, "rect", {
    x: 180 - bodyWidth / 2,
    y: 136 - bodyHeight / 2,
    width: bodyWidth,
    height: bodyHeight,
    rx: softness,
    fill: "url(#body-gradient)",
    stroke: state.accent,
    "stroke-width": stroke,
    transform: `rotate(${strength * -3} 180 180)`,
  });
  body.setAttribute("filter", "drop-shadow(0 14px 16px rgba(0,0,0,0.2))");

  const ribbonY = 182 + cuteness * 8;
  append(art, "path", {
    d: `M 180 ${ribbonY - 6} C 154 ${ribbonY - 18}, 137 ${ribbonY - 10}, 123 ${ribbonY + 2} C 144 ${ribbonY + 9}, 162 ${ribbonY + 9}, 180 ${ribbonY + 1} C 198 ${ribbonY + 9}, 216 ${ribbonY + 9}, 237 ${ribbonY + 2} C 223 ${ribbonY - 10}, 206 ${ribbonY - 18}, 180 ${ribbonY - 6} Z`,
    fill: state.accent,
    opacity: 0.88,
  });

  const eyeY = 132;
  const eyeR = 5 + cuteness * 1.8;
  append(art, "circle", { cx: 158, cy: eyeY, r: eyeR, fill: "#24152f" });
  append(art, "circle", { cx: 202, cy: eyeY, r: eyeR, fill: "#24152f" });
  append(art, "circle", { cx: 156, cy: eyeY - 2, r: 1.5, fill: "#ffffff" });
  append(art, "circle", { cx: 200, cy: eyeY - 2, r: 1.5, fill: "#ffffff" });

  const mouth = currentState === "recover" ? "M 169 155 Q 180 148 191 155" : "M 169 151 Q 180 162 191 151";
  append(art, "path", { d: mouth, fill: "none", stroke: "#24152f", "stroke-width": 4, "stroke-linecap": "round" });

  if (currentState === "power") {
    append(art, "path", { d: "M 151 86 L 161 65 L 180 80 L 199 65 L 209 86 Z", fill: state.accent, stroke: "#24152f", "stroke-width": 4, "stroke-linejoin": "round" });
  } else {
    append(art, "circle", { cx: 180, cy: 76, r: 13 + cuteness * 4, fill: state.accent, opacity: 0.9 });
  }

  const ringRadius = 122 + (1 - strength) * 12;
  append(art, "circle", { cx: 180, cy: 184, r: ringRadius, fill: "none", stroke: state.accent, "stroke-width": 2 + cuteness * 2, "stroke-dasharray": currentState === "power" ? "5 7" : "2 12", opacity: 0.62 });
}

document.querySelectorAll(".state-button").forEach((button) => {
  button.addEventListener("click", () => {
    currentState = button.dataset.state;
    document.querySelectorAll(".state-button").forEach((item) => item.classList.toggle("active", item === button));
    render();
  });
});

[cuteRange, strongRange].forEach((range) => range.addEventListener("input", render));

document.querySelector("#random-button").addEventListener("click", () => {
  const names = Object.keys(states);
  currentState = names[Math.floor(Math.random() * names.length)];
  cuteRange.value = String(35 + Math.floor(Math.random() * 66));
  strongRange.value = String(25 + Math.floor(Math.random() * 76));
  document.querySelectorAll(".state-button").forEach((item) => item.classList.toggle("active", item.dataset.state === currentState));
  render();
});

render();
