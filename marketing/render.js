// Rendert Icon + Thumbnails für Brainrot Bandits (alles eigene Vektorgrafik).
// Ausführen: node marketing/render.js   (braucht das npm-Paket "playwright")
const { chromium } = require("playwright");
const path = require("path");

const OUT = __dirname;
const INK = "#1d1233";

// ---------------------------------------------------------------- Bausteine
const defs = `
<defs>
  <radialGradient id="yolk" cx="40%" cy="35%" r="70%"><stop offset="0" stop-color="#fff176"/><stop offset="1" stop-color="#ff9800"/></radialGradient>
  <linearGradient id="white" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#e8e0ff"/></linearGradient>
  <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff59d"/><stop offset="1" stop-color="#ffb300"/></linearGradient>
  <radialGradient id="pumpkin" cx="40%" cy="35%" r="75%"><stop offset="0" stop-color="#ffb74d"/><stop offset="1" stop-color="#e65100"/></radialGradient>
  <linearGradient id="steel" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="0.5" stop-color="#cfd8dc"/><stop offset="1" stop-color="#78909c"/></linearGradient>
  <radialGradient id="frog" cx="40%" cy="30%" r="80%"><stop offset="0" stop-color="#9ccc65"/><stop offset="1" stop-color="#2e7d32"/></radialGradient>
  <radialGradient id="galaxy" cx="45%" cy="40%" r="75%"><stop offset="0" stop-color="#f48fb1"/><stop offset="0.45" stop-color="#7b1fa2"/><stop offset="1" stop-color="#1a237e"/></radialGradient>
  <linearGradient id="pasta" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff3b0"/><stop offset="1" stop-color="#f2c94c"/></linearGradient>
  <radialGradient id="bandit" cx="40%" cy="35%" r="75%"><stop offset="0" stop-color="#b388ff"/><stop offset="1" stop-color="#5e35b1"/></radialGradient>
  <linearGradient id="title" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff59d"/><stop offset="0.55" stop-color="#ffca28"/><stop offset="1" stop-color="#ff8f00"/></linearGradient>
  <linearGradient id="titlePink" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffb3e6"/><stop offset="1" stop-color="#ff3fa4"/></linearGradient>
  <linearGradient id="rainbow" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#ff5252"/><stop offset="0.2" stop-color="#ffb300"/><stop offset="0.4" stop-color="#ffee58"/>
    <stop offset="0.6" stop-color="#69f0ae"/><stop offset="0.8" stop-color="#40c4ff"/><stop offset="1" stop-color="#e040fb"/></linearGradient>
  <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="10" stdDeviation="8" flood-color="#000" flood-opacity="0.45"/></filter>
  <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="18"/></filter>
</defs>`;

const eye = (x, y, r, look = 0.25) => `
  <circle cx="${x}" cy="${y}" r="${r}" fill="#fff" stroke="${INK}" stroke-width="${r * 0.28}"/>
  <circle cx="${x + r * look}" cy="${y + r * 0.1}" r="${r * 0.52}" fill="${INK}"/>
  <circle cx="${x + r * look - r * 0.18}" cy="${y - r * 0.12}" r="${r * 0.18}" fill="#fff"/>`;

const sparkle = (x, y, s, color = "#fff") => `
  <path transform="translate(${x} ${y}) scale(${s})" d="M0,-40 C6,-8 8,-6 40,0 C8,6 6,8 0,40 C-6,8 -8,6 -40,0 C-8,-6 -6,-8 0,-40Z" fill="${color}" stroke="${INK}" stroke-width="5"/>`;

const g = (x, y, s, body, rot = 0) => `<g transform="translate(${x} ${y}) rotate(${rot}) scale(${s})" filter="url(#shadow)">${body}</g>`;

// Omega Omelettore (Secret)
const omelettore = `
  <g stroke="${INK}" stroke-width="9" stroke-linejoin="round">
    <ellipse cx="0" cy="-165" rx="165" ry="44" fill="#ffd54a" opacity="0.55" filter="url(#glow)" stroke="none"/>
    <rect x="150" y="-178" width="150" height="26" rx="13" fill="#4e4a5e"/>
    <ellipse cx="0" cy="-165" rx="165" ry="46" fill="#4e4a5e"/>
    <ellipse cx="0" cy="-168" rx="138" ry="32" fill="url(#gold)"/>
    <path d="M-160,40 C-185,-70 -95,-140 0,-128 C95,-142 185,-75 168,25 C200,100 125,165 30,150 C-45,180 -160,150 -160,40Z" fill="url(#white)"/>
    <circle cx="0" cy="5" r="88" fill="url(#yolk)"/>
  </g>
  ${eye(-34, -12, 25)}${eye(34, -12, 25)}
  <path d="M-36,30 Q0,85 36,30 Z" fill="#8e1b34" stroke="${INK}" stroke-width="8" stroke-linejoin="round"/>
  <path d="M-16,52 Q0,68 16,52" fill="#ff7aa2"/>
  <ellipse cx="-62" cy="22" rx="16" ry="9" fill="#ff7043" opacity="0.6"/><ellipse cx="62" cy="22" rx="16" ry="9" fill="#ff7043" opacity="0.6"/>`;

// Kaiser Kürbissimo (Legendary)
const kuerbis = `
  <g stroke="${INK}" stroke-width="9" stroke-linejoin="round">
    <rect x="125" y="-70" width="30" height="190" rx="15" fill="#43a047" transform="rotate(12 140 25)"/>
    <circle cx="152" cy="-82" r="22" fill="url(#gold)"/>
    <ellipse cx="-70" cy="10" rx="80" ry="105" fill="url(#pumpkin)"/>
    <ellipse cx="70" cy="10" rx="80" ry="105" fill="url(#pumpkin)"/>
    <ellipse cx="0" cy="8" rx="85" ry="112" fill="url(#pumpkin)"/>
    <rect x="-14" y="-125" width="28" height="36" rx="10" fill="#2e7d32"/>
    <path d="M-78,-105 L-58,-178 L-28,-128 L0,-195 L28,-128 L58,-178 L78,-105 Z" fill="url(#gold)"/>
    <circle cx="0" cy="-140" r="12" fill="#e53935"/><circle cx="-46" cy="-135" r="9" fill="#1e88e5"/><circle cx="46" cy="-135" r="9" fill="#1e88e5"/>
  </g>
  ${eye(-36, -18, 26, -0.1)}${eye(36, -18, 26, 0.1)}
  <path d="M-70,30 C-50,10 -20,22 0,30 C20,22 50,10 70,30 C50,40 25,36 0,44 C-25,36 -50,40 -70,30Z" fill="#4e342e" stroke="${INK}" stroke-width="6"/>
  <path d="M-34,58 Q0,92 34,58" fill="none" stroke="${INK}" stroke-width="9" stroke-linecap="round"/>`;

// Turbo Tortellino (Epic)
const tortellino = `
  <g stroke="${INK}" stroke-width="9" stroke-linejoin="round">
    <path d="M-150,30 C-230,0 -260,40 -300,20 C-260,70 -230,80 -150,70Z" fill="#ff7043"/>
    <path d="M-150,40 C-200,30 -220,50 -245,45 C-215,70 -195,68 -150,62Z" fill="#ffee58" stroke-width="5"/>
    <rect x="-175" y="20" width="50" height="56" rx="10" fill="#90a4ae"/>
    <ellipse cx="-80" cy="95" rx="34" ry="24" fill="url(#frog)"/><ellipse cx="70" cy="95" rx="34" ry="24" fill="url(#frog)"/>
    <circle cx="150" cy="-10" r="62" fill="url(#frog)"/>
    <path d="M-140,70 C-150,-90 120,-110 120,70 Z" fill="url(#pasta)"/>
    <path d="M-110,60 C-110,-40 85,-55 90,60" fill="none" stroke="#d4a72c" stroke-width="10"/>
    <path d="M-80,58 C-80,-5 55,-15 60,58" fill="none" stroke="#d4a72c" stroke-width="8"/>
    <rect x="96" y="-52" width="112" height="22" rx="11" fill="#5d4037"/>
  </g>
  <circle cx="130" cy="-40" r="22" fill="#80deea" stroke="${INK}" stroke-width="7"/><circle cx="182" cy="-40" r="22" fill="#80deea" stroke="${INK}" stroke-width="7"/>
  ${eye(130, -40, 14, 0.3)}${eye(182, -40, 14, 0.3)}
  <path d="M135,10 Q160,34 188,8" fill="none" stroke="${INK}" stroke-width="8" stroke-linecap="round"/>`;

// Kettlo Froggolo (Common)
const kettle = `
  <g stroke="${INK}" stroke-width="9" stroke-linejoin="round">
    <path d="M-120,-20 C-120,-150 120,-150 120,-20" fill="none" stroke-width="16"/>
    <path d="M110,0 C160,-5 175,-45 190,-75 L210,-62 C192,-25 172,25 115,45Z" fill="url(#steel)"/>
    <path d="M-125,105 C-150,0 -110,-60 0,-60 C110,-60 150,0 125,105 Z" fill="url(#steel)"/>
    <ellipse cx="0" cy="-70" rx="92" ry="54" fill="url(#frog)"/>
    <circle cx="-45" cy="-118" r="34" fill="url(#frog)"/><circle cx="45" cy="-118" r="34" fill="url(#frog)"/>
  </g>
  ${eye(-45, -120, 22)}${eye(45, -120, 22)}
  <path d="M-45,-55 Q0,-25 45,-55" fill="none" stroke="${INK}" stroke-width="8" stroke-linecap="round"/>
  <ellipse cx="-70" cy="-60" rx="14" ry="8" fill="#ff8a80"/><ellipse cx="70" cy="-60" rx="14" ry="8" fill="#ff8a80"/>
  <circle cx="225" cy="-110" r="22" fill="#fff" opacity="0.85"/><circle cx="250" cy="-150" r="28" fill="#fff" opacity="0.7"/><circle cx="235" cy="-200" r="20" fill="#fff" opacity="0.5"/>`;

// Galaxio Gelatone (Mythic)
const galaxio = `
  <g stroke="${INK}" stroke-width="9" stroke-linejoin="round">
    <path d="M-110,40 C-120,110 -80,120 -95,175" fill="none" stroke="#f48fb1" stroke-width="20" stroke-linecap="round"/>
    <path d="M-40,45 C-50,120 -10,130 -25,190" fill="none" stroke="#ce93d8" stroke-width="20" stroke-linecap="round"/>
    <path d="M40,45 C30,120 70,130 55,190" fill="none" stroke="#80deea" stroke-width="20" stroke-linecap="round"/>
    <path d="M110,40 C100,110 140,120 125,175" fill="none" stroke="#f48fb1" stroke-width="20" stroke-linecap="round"/>
    <path d="M-150,45 C-150,-150 150,-150 150,45 C100,70 50,30 0,60 C-50,30 -100,70 -150,45Z" fill="url(#galaxy)"/>
    <circle cx="10" cy="-130" r="22" fill="#e53935"/>
  </g>
  <g fill="#fff"><circle cx="-90" cy="-40" r="5"/><circle cx="85" cy="-70" r="4"/><circle cx="-40" cy="-95" r="3"/><circle cx="110" cy="0" r="4"/><circle cx="-115" cy="10" r="3"/></g>
  ${eye(-42, -20, 26)}${eye(42, -20, 26)}
  <path d="M-25,25 Q0,48 25,25" fill="none" stroke="${INK}" stroke-width="8" stroke-linecap="round"/>`;

// Spagetto Gecko (Common)
const gecko = `
  <g stroke="${INK}" stroke-width="9" stroke-linejoin="round" stroke-linecap="round">
    <path d="M60,40 L190,60" stroke="#b0bec5" stroke-width="16"/>
    <path d="M185,40 L215,45 M185,60 L218,64 M185,80 L212,82" stroke="#b0bec5" stroke-width="10"/>
    <ellipse cx="-10" cy="40" rx="110" ry="60" fill="url(#pasta)"/>
    <path d="M-100,30 C-60,0 -20,60 20,20 C50,-5 80,40 100,30" fill="none" stroke="#e2b93b" stroke-width="8"/>
    <path d="M-95,60 C-50,40 -10,80 30,55 C60,40 85,70 100,58" fill="none" stroke="#e2b93b" stroke-width="8"/>
    <ellipse cx="-130" cy="-15" rx="72" ry="55" fill="url(#frog)"/>
  </g>
  ${eye(-155, -35, 22, -0.3)}${eye(-105, -40, 22, -0.3)}
  <path d="M-170,5 Q-140,25 -110,5" fill="none" stroke="${INK}" stroke-width="7" stroke-linecap="round"/>`;

// Sushi Hamsterini (Rare)
const hamster = `
  <g stroke="${INK}" stroke-width="9" stroke-linejoin="round">
    <circle cx="0" cy="0" r="125" fill="#1b3a2b"/>
    <circle cx="0" cy="0" r="100" fill="#fafafa"/>
    <circle cx="-62" cy="-62" r="26" fill="#ffb74d"/><circle cx="62" cy="-62" r="26" fill="#ffb74d"/>
    <circle cx="0" cy="5" r="74" fill="#ffcc80"/>
    <rect x="-40" y="-140" width="80" height="34" rx="14" fill="#ff7043"/>
  </g>
  ${eye(-28, -5, 20)}${eye(28, -5, 20)}
  <ellipse cx="0" cy="28" rx="10" ry="7" fill="#ff8a80" stroke="${INK}" stroke-width="5"/>
  <path d="M-18,42 Q0,58 18,42" fill="none" stroke="${INK}" stroke-width="7" stroke-linecap="round"/>
  <ellipse cx="-50" cy="30" rx="13" ry="8" fill="#ff8a80" opacity="0.7"/><ellipse cx="50" cy="30" rx="13" ry="8" fill="#ff8a80" opacity="0.7"/>`;

// Bandit (Dieb)
const bandit = (carry = "") => `
  <g stroke="${INK}" stroke-width="9" stroke-linejoin="round">
    <ellipse cx="-55" cy="150" rx="38" ry="24" fill="#4527a0" transform="rotate(-20 -55 150)"/>
    <ellipse cx="60" cy="140" rx="38" ry="24" fill="#4527a0" transform="rotate(25 60 140)"/>
    <ellipse cx="0" cy="20" rx="115" ry="130" fill="url(#bandit)"/>
    <path d="M-110,-40 C-60,-70 60,-70 110,-40 L105,5 C55,-15 -55,-15 -105,5Z" fill="${INK}"/>
  </g>
  ${eye(-42, -30, 22, 0.35)}${eye(42, -30, 22, 0.35)}
  <path d="M-30,40 Q5,70 40,35" fill="none" stroke="${INK}" stroke-width="9" stroke-linecap="round"/>
  <path d="M-110,-40 L-160,-70 L-150,-30 Z" fill="${INK}"/>
  ${carry ? `<path d="M-95,-30 C-120,-90 -100,-150 -70,-185 M95,-30 C120,-90 100,-150 70,-185" fill="none" stroke="${INK}" stroke-width="34" stroke-linecap="round"/>
  <path d="M-95,-30 C-120,-90 -100,-150 -70,-185 M95,-30 C120,-90 100,-150 70,-185" fill="none" stroke="#7e57c2" stroke-width="20" stroke-linecap="round"/>` : ""}
  ${carry}`;

const bg = (w, h, c1, c2) => {
  const rays = [];
  const n = 24;
  const cx = w / 2, cy = h / 2, R = Math.max(w, h);
  for (let i = 0; i < n; i += 2) {
    const a1 = (i / n) * Math.PI * 2, a2 = ((i + 1) / n) * Math.PI * 2;
    rays.push(`<path d="M${cx},${cy} L${cx + R * Math.cos(a1)},${cy + R * Math.sin(a1)} L${cx + R * Math.cos(a2)},${cy + R * Math.sin(a2)}Z" fill="${c2}" opacity="0.55"/>`);
  }
  return `<rect width="${w}" height="${h}" fill="${c1}"/>${rays.join("")}
  <radialGradient id="vign" cx="50%" cy="50%" r="70%"><stop offset="0.55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.45"/></radialGradient>
  <rect width="${w}" height="${h}" fill="url(#vign)"/>`;
};

const title = (x, y, size, text, fill = "url(#title)", anchor = "middle", rot = 0) => `
  <text x="${x}" y="${y}" font-family="Luckiest Guy" font-size="${size}" text-anchor="${anchor}" transform="rotate(${rot} ${x} ${y})"
    fill="${fill}" stroke="${INK}" stroke-width="${size * 0.16}" stroke-linejoin="round" paint-order="stroke" filter="url(#shadow)">${text}</text>`;

const pill = (x, y, w, h, color, text, size = 34) => `
  <g filter="url(#shadow)"><rect x="${x - w / 2}" y="${y - h / 2}" width="${w}" height="${h}" rx="${h / 2}" fill="${color}" stroke="${INK}" stroke-width="7"/>
  <text x="${x}" y="${y + size * 0.36}" font-family="Luckiest Guy" font-size="${size}" text-anchor="middle" fill="#fff" stroke="${INK}" stroke-width="6" paint-order="stroke">${text}</text></g>`;

const conveyor = (y, w) => {
  let chevrons = "";
  for (let x = 20; x < w; x += 90) chevrons += `<path d="M${x},${y + 30} l30,25 l-30,25" fill="none" stroke="#ffca28" stroke-width="10" stroke-linecap="round" opacity="0.8"/>`;
  return `<rect x="-20" y="${y}" width="${w + 40}" height="110" fill="#2b2838" stroke="${INK}" stroke-width="10"/>
  <rect x="-20" y="${y - 18}" width="${w + 40}" height="22" fill="#ffca28" stroke="${INK}" stroke-width="8"/>
  <rect x="-20" y="${y + 106}" width="${w + 40}" height="22" fill="#ffca28" stroke="${INK}" stroke-width="8"/>${chevrons}`;
};

const svgPage = (w, h, body) => `<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Luckiest+Guy&display=swap" rel="stylesheet">
<style>html,body{margin:0;padding:0;background:#000}svg{display:block}</style></head>
<body><svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${defs}${body}</svg></body></html>`;

// ---------------------------------------------------------------- Motive
const icon = svgPage(512, 512, `
  ${bg(512, 512, "#7c4dff", "#b388ff")}
  ${sparkle(70, 90, 0.7, "#fff59d")}${sparkle(450, 140, 0.55, "#fff")}${sparkle(440, 400, 0.6, "#fff59d")}
  ${g(256, 250, 0.95, omelettore)}
  ${g(415, 330, 0.36, bandit(), -10)}
  ${title(256, 84, 64, "BRAINROT")}
  ${title(256, 478, 66, "BANDITS", "url(#titlePink)")}
`);

const thumbHero = svgPage(1920, 1080, `
  ${bg(1920, 1080, "#5e35b1", "#9575cd")}
  ${conveyor(760, 1920)}
  ${g(330, 720, 0.75, kettle)}${g(760, 700, 0.8, tortellino)}${g(1230, 690, 0.95, kuerbis)}${g(1650, 650, 1.1, omelettore)}
  ${pill(330, 940, 230, 64, "#9e9e9e", "COMMON")}${pill(760, 940, 200, 64, "#a64bff", "EPIC")}
  ${pill(1230, 940, 300, 64, "#ffa000", "LEGENDARY")}${pill(1650, 940, 260, 64, "url(#rainbow)", "SECRET!")}
  ${sparkle(1500, 330, 1.1, "#fff59d")}${sparkle(1820, 420, 0.8, "#fff")}${sparkle(120, 300, 0.9, "#fff59d")}
  ${title(960, 210, 190, "BRAINROT BANDITS")}
  ${title(960, 360, 92, "KAUFEN · SAMMELN · KLAUEN!", "url(#titlePink)")}
`);

const thumbSteal = svgPage(1920, 1080, `
  ${bg(1920, 1080, "#c62828", "#ef5350")}
  <g filter="url(#shadow)">
    <rect x="1180" y="330" width="760" height="700" fill="#ffe0f0" stroke="${INK}" stroke-width="12"/>
    <rect x="1180" y="330" width="60" height="700" fill="#f8bbd0" stroke="${INK}" stroke-width="10"/>
    <rect x="1240" y="480" width="34" height="550" fill="#ff1744" opacity="0.85"/>
    <rect x="1240" y="480" width="34" height="550" fill="#ff8a80" filter="url(#glow)"/>
  </g>
  ${g(1560, 760, 0.85, kuerbis)}
  ${g(700, 700, 1.25, bandit(`<g transform="translate(-10 -230) scale(0.55)">${omelettore}</g>`), -6)}
  <path d="M260,650 l-160,-30 M280,740 l-200,0 M260,830 l-160,30" stroke="#fff" stroke-width="18" stroke-linecap="round" opacity="0.8"/>
  ${pill(1560, 980, 360, 70, "#00c853", "🔒 ABSCHLIESSEN", 36)}
  ${title(960, 200, 170, "KLAU DIR DIE BESTEN!")}
  ${title(330, 1010, 84, "...und renn!", "url(#titlePink)", "middle", -4)}
`);

const thumbCollect = svgPage(1920, 1080, `
  ${bg(1920, 1080, "#00897b", "#4db6ac")}
  ${g(250, 650, 0.68, gecko)}${g(555, 640, 0.72, hamster)}${g(840, 650, 0.5, tortellino)}
  ${g(1150, 610, 0.72, kuerbis)}${g(1460, 610, 0.8, galaxio)}${g(1760, 590, 0.82, omelettore)}
  ${pill(210, 880, 230, 60, "#9e9e9e", "COMMON", 30)}${pill(555, 880, 190, 60, "#3c8cff", "RARE", 30)}
  ${pill(840, 880, 180, 60, "#a64bff", "EPIC", 30)}${pill(1150, 880, 280, 60, "#ffa000", "LEGENDARY", 30)}
  ${pill(1460, 880, 220, 60, "#ff3c3c", "MYTHIC", 30)}${pill(1760, 880, 220, 60, "url(#rainbow)", "SECRET", 30)}
  ${title(960, 210, 160, "30+ BRAINROTS!")}
  ${title(960, 340, 80, "GOLD · DIAMANT · REGENBOGEN", "url(#titlePink)")}
  ${sparkle(1700, 330, 0.9, "#fff59d")}${sparkle(250, 340, 0.8, "#fff")}
`);

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
  const page = await browser.newPage();
  const jobs = [
    ["icon_512.png", icon, 512, 512],
    ["thumbnail_1_hero.png", thumbHero, 1920, 1080],
    ["thumbnail_2_steal.png", thumbSteal, 1920, 1080],
    ["thumbnail_3_collect.png", thumbCollect, 1920, 1080],
  ];
  for (const [file, html, w, h] of jobs) {
    await page.setViewportSize({ width: w, height: h });
    await page.setContent(html, { waitUntil: "networkidle" });
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: path.join(OUT, file), clip: { x: 0, y: 0, width: w, height: h } });
    console.log("rendered", file);
  }
  await browser.close();
})();
