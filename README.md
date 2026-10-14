- 👋 Hi, I’m @1Entchen
- 👀 I’m interested in Mountainbiking
- 🌱 I’m currently learning HTML, JavaScript, PHP
- 📫 How to reach me Discord = 1Entchen#0815


---

## Brainrot Bandits – Roblox-Tycoon

Collect-and-Steal-Tycoon im Brainrot-Stil: Figuren vom Förderband kaufen, passiv Cash verdienen, bei anderen stehlen, Basis abschließen, Rebirth.

### Schnellstart (5 Minuten)
1. **[`BrainrotBandits.rbxlx`](BrainrotBandits.rbxlx) herunterladen** und per Doppelklick in Roblox Studio öffnen
2. **Play** drücken: Welt, Basen, Förderband, Schilder und alle 30 Figuren werden automatisch gebaut
3. **File → Publish to Roblox**, dann bei Game Settings → Security „Enable Studio Access to API Services“ einschalten
4. Game Passes und Developer Products anlegen (Bilder in [`marketing/icons/`](marketing/icons)), IDs in `ReplicatedStorage/Shared/Config` eintragen → [Phase 4](docs/04_Monetarisierung.md)
5. Icon und Thumbnails aus [`marketing/`](marketing) hochladen, Beschreibung einfügen → [Phase 6](docs/06_Launch.md)

### Was drin ist
- 30 originale Figuren als 3D-Modelle + Sammelkarten ([`marketing/figures/`](marketing/figures), [Poster](marketing/poster_all_figures.png))
- Förderband, 8 Basen, Schloss, Stehlen + Klatsche, Rebirth, globale Leaderboards
- Komplette UI (Shop, Basis/Index, Rebirth, Belohnungen, Quests), Tutorial mit Pfeil, Schilder in der Welt
- 7 Game Passes + 10 Developer Products inkl. Icons, Premium-Vorteile
- Speichern mit Session-Lock, Anti-Exploit auf dem Server
- Spiel-Icon, 3 Thumbnails, Beschreibung, Launch-Plan

| Phase | Inhalt | Datei |
|---|---|---|
| 1 | Game-Design-Dokument | [docs/01_Game-Design-Dokument.md](docs/01_Game-Design-Dokument.md) |
| 2 | Studio-Setup + Welt-Setup-Script | [docs/02_Studio-Setup.md](docs/02_Studio-Setup.md) |
| 3 | Alle Scripts + Installation + Anti-Exploit | [docs/03_Scripts-Installation.md](docs/03_Scripts-Installation.md), [src/](src) |
| 4 | Monetarisierung (Pässe, Products, Premium) | [docs/04_Monetarisierung.md](docs/04_Monetarisierung.md) |
| 5 | Retention (Daily, Quests, Events, Ansagen) | [docs/05_Retention.md](docs/05_Retention.md) |
| 6 | Launch (Icon, Thumbnails, Text, Tests, Marketing) | [docs/06_Launch.md](docs/06_Launch.md), [marketing/](marketing) |

**Für Entwickler:** `rojo build default.project.json -o BrainrotBandits.rbxlx` baut die Datei neu. Figuren-Designs ändern: `tools/figure_designs.py` bearbeiten und ausführen. Bilder neu rendern: `node marketing/render.js`, `render_figures.js`, `render_icons.js`.
