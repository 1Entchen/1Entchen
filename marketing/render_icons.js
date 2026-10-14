// Rendert Icons (512x512) für alle Game Passes und Developer Products.
// Ausführen: node marketing/render_icons.js
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const OUT = path.join(__dirname, "icons");
fs.mkdirSync(OUT, { recursive: true });

// [Datei, Emoji, Zeile 1, Zeile 2, Farbe oben, Farbe unten]
const ICONS = [
  ["pass_DoubleCash", "💰", "2X", "CASH", "#43e97b", "#0b8a4b"],
  ["pass_VIP", "👑", "VIP", "", "#ffe259", "#ff8c00"],
  ["pass_ExtraSlots", "🏠", "+5", "SLOTS", "#4facfe", "#1a3f8f"],
  ["pass_AutoCollect", "🧲", "AUTO", "COLLECT", "#f093fb", "#8e2de2"],
  ["pass_MasterThief", "🦹", "MEISTER", "DIEB", "#b388ff", "#311b92"],
  ["pass_Speed", "👟", "TURBO", "SPEED", "#00f2fe", "#0072ff"],
  ["pass_SuperBonk", "🔨", "MEGA", "KLATSCHE", "#ff9a9e", "#d6246e"],
  ["product_StarterPack", "🎁", "STARTER", "PAKET", "#ffd200", "#f7971e"],
  ["product_Boost2x", "⚡", "2X", "30 MIN", "#fff200", "#ff9500"],
  ["product_CashSmall", "💵", "CASH", "BEUTEL", "#a8e063", "#56ab2f"],
  ["product_CashMedium", "💰", "CASH", "KOFFER", "#56ab2f", "#1e6b30"],
  ["product_CashLarge", "🏦", "CASH", "TRESOR", "#11998e", "#0b5345"],
  ["product_CashMega", "💎", "CASH", "BERG", "#00c6ff", "#5b2cff"],
  ["product_LuckySpawn", "🍀", "LUCKY", "SPAWN", "#76ff03", "#1b5e20"],
  ["product_MythicDrop", "🔥", "MYTHIC", "DROP", "#ff512f", "#9b0b3a"],
  ["product_LockExtend", "🔐", "+5 MIN", "SCHLOSS", "#f7797d", "#8e0e00"],
  ["product_OfflineTriple", "😴", "OFFLINE", "X3", "#8e9eff", "#3f2b96"],
];

const page = (emoji, l1, l2, c1, c2) => `<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Luckiest+Guy&display=swap" rel="stylesheet">
<style>
body{margin:0;width:512px;height:512px;background:transparent}
.b{position:absolute;inset:0;border-radius:96px;background:radial-gradient(circle at 50% 30%, ${c1}, ${c2});border:14px solid #1d1233;box-sizing:border-box;overflow:hidden}
.r{position:absolute;inset:-60%;background:repeating-conic-gradient(rgba(255,255,255,.16) 0 9deg, transparent 9deg 18deg)}
.e{position:absolute;left:0;right:0;top:${l2 ? 46 : 70}px;text-align:center;font-size:${l2 ? 210 : 240}px;line-height:1;font-family:'Noto Color Emoji';filter:drop-shadow(0 12px 0 rgba(0,0,0,.3))}
.t{position:absolute;left:0;right:0;text-align:center;font-family:'Luckiest Guy';color:#fff;-webkit-text-stroke:16px #1d1233;paint-order:stroke fill;line-height:1}
.t1{bottom:${l2 ? 104 : 46}px;font-size:${l1.length > 6 ? 70 : 92}px}
.t2{bottom:34px;font-size:${l2.length > 7 ? 54 : 66}px;color:#fff59d}
</style></head><body><div class="b"><div class="r"></div><div class="e">${emoji}</div>
<div class="t t1">${l1}</div>${l2 ? `<div class="t t2">${l2}</div>` : ""}</div></body></html>`;

(async () => {
  const browser = await chromium.launch();
  const p = await browser.newPage({ viewport: { width: 512, height: 512 } });
  for (const [file, emoji, l1, l2, c1, c2] of ICONS) {
    await p.setContent(page(emoji, l1, l2, c1, c2), { waitUntil: "networkidle" });
    await p.evaluate(() => document.fonts.ready);
    await p.screenshot({ path: path.join(OUT, file + ".png"), omitBackground: true });
    console.log("icon", file);
  }
  await browser.close();
})();
