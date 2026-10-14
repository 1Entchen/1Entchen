// Rendert alle 30 Figuren (gleiche 3D-Daten wie im Spiel) als Sammelkarten + Übersichtsposter.
// Ausführen: node marketing/render_figures.js   (braucht "playwright", lädt three.js vom CDN)
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const OUT = path.join(__dirname, "figures");
fs.mkdirSync(OUT, { recursive: true });

const designs = JSON.parse(fs.readFileSync(path.join(__dirname, "figures.json"), "utf8"));
const figSrc = fs.readFileSync(path.join(ROOT, "src/ReplicatedStorage/Shared/Figures.lua"), "utf8");
const figures = [];
const re = /\{ Id = (\d+), Key = "(\w+)", Name = "([^"]+)", Rarity = "(\w+)", Price = (\d+), Income = (\d+), Weight = [\d.]+, Height = ([\d.]+)/g;
let m;
while ((m = re.exec(figSrc))) {
  figures.push({ id: +m[1], key: m[2], name: m[3], rarity: m[4], price: +m[5], income: +m[6], height: +m[7] });
}
if (figures.length !== 30) throw new Error("expected 30 figures, got " + figures.length);

const RARITY = {
  Common: { label: "COMMON", c1: "#9e9e9e", c2: "#5f5f6b" },
  Rare: { label: "RARE", c1: "#3c8cff", c2: "#1a3f8f" },
  Epic: { label: "EPIC", c1: "#a64bff", c2: "#4a1c8c" },
  Legendary: { label: "LEGENDARY", c1: "#ffb400", c2: "#b35a00" },
  Mythic: { label: "MYTHIC", c1: "#ff3c3c", c2: "#7a0f2a" },
  Secret: { label: "SECRET", c1: "#ff5fd2", c2: "#2b1a6b" },
};

function money(n) {
  const s = ["", "K", "M", "B"];
  let i = 0;
  while (n >= 1000 && i < s.length - 1) { n /= 1000; i++; }
  return "$" + (n >= 100 || Number.isInteger(n) ? Math.floor(n) : n.toFixed(1).replace(/\.0$/, "")) + s[i];
}

const html = `<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Luckiest+Guy&family=Fredoka:wght@600;700&display=swap" rel="stylesheet">
<style>
  body{margin:0;background:#120c22;font-family:Fredoka,sans-serif}
  #card{position:relative;width:512px;height:680px;border-radius:36px;overflow:hidden;box-sizing:border-box;border:10px solid #1d1233}
  #bg{position:absolute;inset:0}
  #rays{position:absolute;inset:-50%;background:repeating-conic-gradient(rgba(255,255,255,.13) 0 10deg, transparent 10deg 20deg)}
  canvas{position:absolute;left:0;top:70px}
  .t{position:absolute;left:0;right:0;text-align:center;font-family:'Luckiest Guy';color:#fff;-webkit-text-stroke:0;paint-order:stroke fill;text-shadow:0 5px 0 rgba(0,0,0,.35)}
  #rar{top:22px;font-size:40px;letter-spacing:2px}
  #name{top:auto;bottom:112px;font-size:44px;line-height:1.05;padding:0 18px;white-space:nowrap;-webkit-text-stroke:9px #1d1233}
  #stats{position:absolute;bottom:22px;left:24px;right:24px;display:flex;gap:12px}
  .pill{flex:1;background:rgba(29,18,51,.82);border-radius:20px;padding:10px 0;text-align:center;color:#fff;font-weight:700;font-size:26px}
  .pill small{display:block;font-size:15px;opacity:.75;font-weight:600}
  #num{position:absolute;top:24px;right:28px;font-family:'Luckiest Guy';font-size:28px;color:rgba(255,255,255,.85)}
</style></head><body>
<div id="card"><div id="bg"></div><div id="rays"></div><div class="t" id="rar"></div><div id="num"></div>
<div class="t" id="name"></div>
<div id="stats"><div class="pill"><small>PREIS</small><span id="price"></span></div><div class="pill"><small>EINKOMMEN</small><span id="inc"></span></div></div></div>
<script type="importmap">{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js"}}</script>
<script type="module">
import * as THREE from "three";
const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(1);
renderer.setSize(492, 440);
document.getElementById("card").insertBefore(renderer.domElement, document.getElementById("name"));
const grad = new Uint8Array([90, 160, 255]);
const toonMap = new THREE.DataTexture(grad, 3, 1, THREE.RedFormat);
toonMap.minFilter = toonMap.magFilter = THREE.NearestFilter;
toonMap.needsUpdate = true;

window.renderFigure = (parts) => {
  const scene = new THREE.Scene();
  scene.add(new THREE.AmbientLight(0xffffff, 1.4));
  const sun = new THREE.DirectionalLight(0xffffff, 2.2);
  sun.position.set(-4, 8, -6);
  scene.add(sun);
  const group = new THREE.Group();
  for (const p of parts) {
    let geo;
    if (p.s === "E") geo = new THREE.SphereGeometry(0.5, 28, 20);
    else if (p.s === "C") geo = new THREE.CylinderGeometry(0.5, 0.5, 1, 28);
    else geo = new THREE.BoxGeometry(1, 1, 1);
    const color = new THREE.Color(p.c);
    let mat;
    if (p.m === "Neon") mat = new THREE.MeshBasicMaterial({ color: color.clone().multiplyScalar(1.15) });
    else if (p.m === "Glass") mat = new THREE.MeshToonMaterial({ color, gradientMap: toonMap, transparent: true, opacity: 0.72 });
    else if (p.m === "Metal") mat = new THREE.MeshStandardMaterial({ color, metalness: 0.6, roughness: 0.3 });
    else mat = new THREE.MeshToonMaterial({ color, gradientMap: toonMap });
    if (p.a > 0 && p.m !== "Glass") { mat.transparent = true; mat.opacity = 1 - p.a; }
    const mesh = new THREE.Mesh(geo, mat);
    mesh.scale.set(p.size[0], p.size[1], p.size[2]);
    mesh.position.set(p.pos[0], p.pos[1], p.pos[2]);
    mesh.rotation.set(...p.rot.map((d) => (d * Math.PI) / 180), "XYZ");
    group.add(mesh);
    if (Math.min(...p.size) > 0.25) {
      const outline = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: 0x1d1233, side: THREE.BackSide }));
      outline.scale.set(p.size[0] + 0.12, p.size[1] + 0.12, p.size[2] + 0.12);
      outline.position.copy(mesh.position);
      outline.rotation.copy(mesh.rotation);
      group.add(outline);
    }
  }
  scene.add(group);
  const box = new THREE.Box3().setFromObject(group);
  const size = box.getSize(new THREE.Vector3());
  const center = box.getCenter(new THREE.Vector3());
  const camera = new THREE.PerspectiveCamera(30, 492 / 440, 0.1, 100);
  const dist = Math.max(size.y, size.x * 0.9, size.z * 0.6) * 2.25 + 2;
  camera.position.set(center.x - dist * 0.42, center.y + dist * 0.25, center.z - dist * 0.88);
  camera.lookAt(center);
  renderer.render(scene, camera);
};
window.ready = true;
</script></body></html>`;

(async () => {
  const browser = await chromium.launch({ args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"] });
  const page = await browser.newPage({ viewport: { width: 512, height: 680 } });
  page.on("pageerror", (e) => console.log("PAGE ERROR", e.message));
  await page.setContent(html, { waitUntil: "networkidle" });
  await page.waitForFunction(() => window.ready === true);
  await page.evaluate(() => document.fonts.ready);
  for (const fig of figures) {
    const r = RARITY[fig.rarity];
    await page.evaluate(({ fig, r, parts, price, inc }) => {
      const bg = fig.rarity === "Secret"
        ? "linear-gradient(160deg,#ff5252,#ffb300,#69f0ae,#40c4ff,#e040fb)"
        : `radial-gradient(circle at 50% 40%, ${r.c1}, ${r.c2})`;
      document.getElementById("bg").style.background = bg;
      document.getElementById("card").style.borderColor = fig.rarity === "Secret" ? "#ffffff" : "#1d1233";
      document.getElementById("rar").textContent = r.label;
      document.getElementById("num").textContent = "#" + fig.id;
      const nameEl = document.getElementById("name");
      nameEl.textContent = fig.name;
      let size = 44;
      nameEl.style.fontSize = size + "px";
      while (nameEl.scrollWidth > 492 && size > 22) { size -= 2; nameEl.style.fontSize = size + "px"; }
      document.getElementById("price").textContent = price;
      document.getElementById("inc").textContent = inc + "/s";
      window.renderFigure(parts);
    }, { fig, r, parts: designs[fig.key], price: money(fig.price), inc: money(fig.income) });
    const file = path.join(OUT, `${String(fig.id).padStart(2, "0")}_${fig.key}.png`);
    await (await page.$("#card")).screenshot({ path: file, omitBackground: true });
    console.log("card", path.basename(file));
  }

  // Übersichtsposter (alle 30 Karten)
  const cards = fs.readdirSync(OUT).filter((f) => f.endsWith(".png")).sort();
  const poster = `<!doctype html><html><head><meta charset="utf-8">
  <link href="https://fonts.googleapis.com/css2?family=Luckiest+Guy&display=swap" rel="stylesheet">
  <style>body{margin:0;width:2400px;background:radial-gradient(circle at 50% 0,#5e35b1,#1a1033);font-family:'Luckiest Guy'}
  h1{margin:0;padding:40px 0 10px;text-align:center;font-size:110px;color:#ffca28;-webkit-text-stroke:14px #1d1233;paint-order:stroke fill}
  h2{margin:0 0 30px;text-align:center;font-size:44px;color:#ff8fd8;-webkit-text-stroke:8px #1d1233;paint-order:stroke fill}
  .grid{display:grid;grid-template-columns:repeat(6,1fr);gap:24px;padding:0 40px 50px}
  img{width:100%}</style></head><body><h1>BRAINROT BANDITS</h1><h2>ALLE 30 FIGUREN · SAMMLE SIE ALLE!</h2>
  <div class="grid">${cards.map((c) => `<img src="data:image/png;base64,${fs.readFileSync(path.join(OUT, c)).toString("base64")}">`).join("")}</div></body></html>`;
  await page.setViewportSize({ width: 2400, height: 1200 });
  await page.setContent(poster, { waitUntil: "networkidle" });
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: path.join(__dirname, "poster_all_figures.png"), fullPage: true });
  console.log("poster done");
  await browser.close();
})();
