# Phase 2 – Studio-Setup

Ziel: Am Ende dieser Phase steht die komplette Welt in Studio, und alle Ordner für die Scripts aus Phase 3 sind angelegt. **Fast alles baut ein Setup-Script automatisch**, damit keine Tippfehler bei Namen entstehen. Von Hand baust du nur die 30 Figuren-Modelle, und auch die sind optional, weil das Spiel ohne sie automatisch Platzhalter-Figuren erzeugt.

---

## 1. Projekt anlegen und Grundeinstellungen

1. Roblox Studio → **New** → Vorlage **Baseplate**.
2. **File → Publish to Roblox**, Name „Brainrot Bandits“ (dauerhaft speichern; nötig für DataStores).
3. **Home → Game Settings**
   - **Security:** `Enable Studio Access to API Services` = **ON** (DataStores in Studio testen)
   - **Avatar:** Avatar Type **R15**, Collision **Inner Box**
   - **World:** Jump Power 50, Walk Speed 16 (Standard lassen)
4. **Creator Dashboard → dein Spiel → Places → Start Place → Settings:** **Server Size = 8**.
5. **View** → `Explorer`, `Properties`, `Output` und `Command Bar` einblenden.

---

## 2. Welt automatisch aufbauen

1. Im Explorer: **ServerStorage** → `+` → **ModuleScript**, umbenennen in **`SetupWorld`**.
2. Inhalt komplett ersetzen durch [`src/ServerStorage/SetupWorld.lua`](../src/ServerStorage/SetupWorld.lua).
3. **Nicht** auf Play drücken. Unten in die **Command Bar** eingeben und Enter drücken:
   ```lua
   require(game.ServerStorage.SetupWorld)()
   ```
4. Im Output erscheint `✅ Brainrot-Welt aufgebaut!`.
5. **Strg+S** zum Speichern.

Das Script kann beliebig oft ausgeführt werden, es ersetzt dann die alten Objekte. Achtung: Was du in `BaseTemplate`, `Map` oder `Conveyor` von Hand dekoriert hast, wird dabei überschrieben. Dekoriere also erst, wenn alles läuft.

---

## 3. Layout der Welt (Draufsicht)

```
 Z = +92 ┌──────────┐┌──────────┐┌──────────┐┌──────────┐
         │  Plot 5  ││  Plot 6  ││  Plot 7  ││  Plot 8  │   Basen 80 × 60
         │          ││          ││          ││          │
 Z = +32 └────╥─────┘└────╥─────┘└────╥─────┘└────╥─────┘   ╥ = Tür (20 breit)
                         Laufweg (Walkway)
[Cash-Board]  ║Spawn ══════════ FÖRDERBAND ══════════ Ende║  [Rebirth-Board]
 X = -112     X=-92  -85 ───────────────────────────▶ +85  X=92        X = +112
                         Laufweg (Walkway)        (Spawn-Punkt bei 0, -20)
 Z = -32 ┌────╨─────┐┌────╨─────┐┌────╨─────┐┌────╨─────┐
         │  Plot 1  ││  Plot 2  ││  Plot 3  ││  Plot 4  │
 Z = -92 └──────────┘└──────────┘└──────────┘└──────────┘
          X = -135     X = -45      X = +45     X = +135
```

- Das Förderband ist 180 Studs lang. Figuren laufen in 18 s von `StartPoint` (X = −85) zu `EndPoint` (X = +85). Mit 9,4 Studs/s sind sie langsamer als ein Spieler (16 Studs/s), man kann also neben ihnen herlaufen.
- Jede Tür zeigt zum Band, der Weg zum Band ist nur etwa 25 Studs lang. Das ist kurz und damit mobilfreundlich.
- Wer stiehlt, läuft mit 70 % Tempo etwa 60–200 Studs nach Hause. Das gibt dem Besitzer 4–18 s Zeit, um zu reagieren.

---

## 4. Explorer-Struktur (Endzustand nach Phase 3)

Fett = legt das Setup-Script an. *Kursiv* = entsteht erst zur Laufzeit. `(Phase 3)` = Scripts, die in der nächsten Phase kommen.

```
Workspace
├── **Map** (Folder)
│   ├── Ground, Walkway (Part)
│   └── BoundaryN / BoundaryS / BoundaryE / BoundaryW (unsichtbare Wände)
├── **SpawnLocation**
├── **Conveyor** (Model, PrimaryPart = Belt)
│   ├── Belt, RailLeft, RailRight (Part)
│   ├── Stripes (Folder)
│   ├── StartPoint, EndPoint (unsichtbare Parts)
│   └── SpawnGate, EndGate (Model)
├── **Plots** (Folder): Plot1 … Plot8 (unsichtbare Parts, LookVector → Band)
├── **Bases** (Folder)            ← *hier erscheinen Base1 … Base8 als Klone*
├── **ConveyorFigures** (Folder)  ← *Figuren auf dem Band*
└── **Leaderboards** (Folder)
    ├── CashBoard (Model) → Screen → BoardGui → Title, List
    └── RebirthBoard (Model) → Screen → BoardGui → Title, List

ReplicatedStorage
├── **Shared** (Folder)
│   ├── Config (ModuleScript)          (Phase 3) Balancing, Preise, IDs
│   ├── Figures (ModuleScript)         (Phase 3) die 30 Figuren
│   ├── Format (ModuleScript)          (Phase 3) Zahlen: 1.5K, 2.3M …
│   └── FigureBuilder (ModuleScript)   (Phase 3) Modell + Platzhalter + Mutation
├── **FigureModels** (Folder)          ← deine selbst gebauten Figuren (optional)
└── **Remotes** (Folder)               ← *RemoteEvents/Functions erzeugt der Server*

ServerScriptService
├── ServerMain (Script)                (Phase 3) startet alle Services
└── **Services** (Folder)              (Phase 3) alle ModuleScripts
    ├── DataService         Speichern, Session-Lock
    ├── RateLimit           Anti-Spam / Anti-Exploit
    ├── BaseService         Basen vergeben, Slots, Schloss, Cash-Pad
    ├── ConveyorService     Spawning, Kaufen
    ├── IncomeService       passives Einkommen, Offline-Einkommen
    ├── StealService        Diebstahl, Klatsche
    ├── RebirthService
    ├── LeaderboardService  OrderedDataStore, global
    ├── MonetizationService (Phase 4) Game Passes, Products, ProcessReceipt
    ├── RewardService       (Phase 5) Daily, Quests
    ├── EventService        (Phase 5) Wochenend-Events
    └── AnnouncementService (Phase 5) Server- und globale Ansagen

ServerStorage
├── **BaseTemplate** (Model, PrimaryPart = Floor)
└── SetupWorld (ModuleScript)          ← nach dem Setup löschbar

StarterPack
└── **Klatsche** (Tool) → Handle, Head

StarterGui
└── (leer, die komplette UI erzeugt der Code; so bleibt sie mobil skalierbar)

StarterPlayer → StarterPlayerScripts
├── ClientMain (LocalScript)           (Phase 3)
└── **ClientModules** (Folder)         (Phase 3) UI, Notifications, Effects

SoundService
├── **Sfx** (Folder): Buy, Sell, Cash, Steal, Alarm, Bonk, Lock, Unlock,
│                     Rebirth, Rare, Legendary, Secret, Click, Error, Reward
└── **Music** (Sound, Looped)

Lighting: **Vibe** (ColorCorrection), **Glow** (Bloom), **Air** (Atmosphere)
```

---

## 5. Die Basis-Vorlage im Detail

`ServerStorage.BaseTemplate` wird beim Serverstart 8× geklont und auf die Plots gesetzt. Die **Namen dürfen nicht geändert werden**, weil die Scripts sie suchen.

Koordinaten lokal (Mitte des Bodens = 0,0,0; Tür = −Z):

| Name | Typ | Größe | Position | Zweck |
|---|---|---|---|---|
| `Floor` | Part (PrimaryPart) | 80 × 1 × 60 | 0, 0.5, 0 | Boden, wird in der Spielerfarbe eingefärbt |
| `Walls/BackWall`, `LeftWall`, `RightWall` | Part | Höhe 10 | Rand | nicht überspringbar (Sprunghöhe ≈ 7) |
| `Walls/FrontLeftWall`, `FrontRightWall` | Part | 30 × 10 × 1 | ±25, 6, −29.5 | Front mit 20 Studs Türlücke |
| `Walls/DoorBeam` | Part | 20 × 2 × 1 | 0, 12, −29.5 | Türsturz |
| `LaserDoor` | Part (Neon, unsichtbar) | 20 × 10 × 0.4 | 0, 6, −29.5 | Wird beim Abschließen rot sichtbar |
| `LaserDoor/DoorGui/Label` | BillboardGui | – | – | Countdown „🔒 45“ |
| `Sign/SignGui/Label` | SurfaceGui | 24 × 5 | 0, 15.5, −29.5 | „Basis von Name ⭐3“ |
| `Slots/Slot1 … Slot10` | Part 5 × 0.4 × 5 | vordere Reihe | z = 6 | Start-Slots |
| `Slots/Slot11 … Slot15` | | hintere Reihe | z = 19 | durch Rebirth freigeschaltet |
| `Slots/Slot16 … Slot20` | | hintere Reihe | z = 19 | Game Pass „+5 Slots“ |
| `Slots/Slot21` | Part (Gold, Neon) | | 0, 1.2, −4 | Premium-Slot |
| `CashPad/CashGui/Label` | Part + Billboard | 8 × 0.4 × 8 | −28, 1.2, −18 | drüberlaufen = einsammeln |
| `LockButton/LockGui/Label` | Part + Billboard | 5 × 0.6 × 5 | 28, 1.3, −18 | Schloss aktivieren |
| `SpawnPoint` | unsichtbar | 4 × 1 × 4 | 0, 1.5, −12 | Besitzer spawnt hier |
| `Zone` | unsichtbar | 78 × 16 × 58 | 0, 9, 0 | Server prüft: Wer ist in der Basis? |

**Schloss-Technik:** Die Laser-Tür ist nie solide. Stattdessen prüft der Server 5× pro Sekunde, ob ein Fremder in der `Zone` steht, während das Schloss aktiv ist, und schiebt ihn vor die Tür. Das ist exploit-sicher, weil der Client die Kollision nicht manipulieren kann, und der Besitzer kommt immer durch.

**Dekorieren (später):** `BaseTemplate` nach Workspace ziehen, Deko-Parts in einen neuen Ordner `Decor` legen (Anchored, CanCollide nach Wunsch), Modell wieder zurück nach ServerStorage ziehen. Die Position spielt keine Rolle, weil der Server die Vorlage per `PivotTo` auf den Plot setzt.

---

## 6. Figuren-Modelle bauen (optional, aber wichtig für den Erfolg)

**Update:** Alle 30 Figuren sind jetzt fertig als 3D-Modelle in `FigureDesigns` enthalten (Vorschau: `marketing/poster_all_figures.png`). Eigene Modelle in `FigureModels` ersetzen sie automatisch.

Ohne `FigureDesigns` und ohne eigene Modelle erzeugt `FigureBuilder` (Phase 3) automatisch einen **Platzhalter**: einen Körper in den Figurfarben mit Kopf, Augen und Namensschild. Damit ist das Spiel sofort testbar. Echte Modelle machen später den großen Unterschied bei Thumbnails und Clips.

### Regeln für jedes Modell

1. **Model** in `ReplicatedStorage/FigureModels`, Name **exakt** wie in der Spalte `Key` (ohne Umlaute und Leerzeichen).
2. **PrimaryPart = `Root`**: unsichtbarer Part (Transparency 1), 3 × 0.2 × 3, **unten mittig** unter der Figur. Die Unterseite von Root ist der Boden.
3. **Blickrichtung:** Das Gesicht schaut in die **Vorderseite** (Front, −Z) von `Root`. In Studio mit „Show Orientation Indicator“ prüfen.
4. Höhe nach Seltenheit: Common ≈ 4, Rare ≈ 5, Epic ≈ 6, Legendary ≈ 7,5, Mythic ≈ 9, Secret ≈ 11 Studs. Breite maximal 6 Studs.
5. **Höchstens 30 Parts**, keine Scripts, keine Sounds im Modell. Unions und MeshParts nur aus **eigener** Erstellung (Blender-Export unter deinem Account). Keine Toolbox-Modelle fremder Ersteller.
6. Anchored, CanCollide und Material setzt der Code automatisch, du musst nichts einstellen.
7. Stil: rundliche Formen (Ball, Cylinder, Wedge), kräftige Farben, **große Augen** (weiße Kugel + schwarze Pupille). Für Glanz Material `SmoothPlastic` verwenden, `Neon` nur sparsam für Details.

### Beispiel: Kettlo Froggolo (Common, Höhe 4)

| Teil | Form | Größe | Farbe |
|---|---|---|---|
| Root | Block, unsichtbar | 3 × 0.2 × 3 | – |
| Bauch (Kessel) | Ball | 3 × 2.6 × 3 | Silber `#C0C0C0`, Material Metal |
| Deckel | Cylinder | 0.4 × 1.6 × 1.6 | Silber |
| Kopf | Ball | 2.4 × 1.8 × 2 | Grün `#4CAF50` |
| Augen 2× | Ball | 0.8 | Weiß + Pupille 0.4 Schwarz |
| Tülle (Nase) | Cylinder | 1.2 × 0.4 × 0.4 schräg | Silber |
| Beine 2× | Wedge | 0.8 × 0.6 × 1.4 | Grün |

So geht es Schritt für Schritt: Root setzen → Bauch darauf → Kopf vorne oben → Augen → Details → alles markieren → **Strg+G** (Model) → PrimaryPart = Root → umbenennen in `KettloFroggolo` → nach `FigureModels` ziehen.

### Alle Keys (für Modelle und Platzhalter-Farben)

| # | Key | Seltenheit | Höhe | Farbe 1 | Farbe 2 |
|---|---|---|---|---|---|
| 1 | SpagettoGecko | Common | 4 | `#F2D16B` | `#6BBF59` |
| 2 | SockolinoMausolino | Common | 4 | `#E94F4F` | `#BDBDBD` |
| 3 | KettloFroggolo | Common | 4 | `#4CAF50` | `#C0C0C0` |
| 4 | BrezelwurmBrezelini | Common | 4 | `#A0612B` | `#F5E6C8` |
| 5 | RadieroSchneckolo | Common | 4 | `#FF8FB1` | `#7CB342` |
| 6 | MopettoPinguzzo | Common | 4 | `#263238` | `#ECEFF1` |
| 7 | WackelWobblino | Common | 4 | `#66E07A` | `#D32F2F` |
| 8 | LampadinoFalenino | Rare | 5 | `#FFF59D` | `#8D6E63` |
| 9 | CiabattoCanguro | Rare | 5 | `#C68642` | `#5C6BC0` |
| 10 | SushiHamsterini | Rare | 5 | `#FFCC80` | `#212121` |
| 11 | BurstoIgelino | Rare | 5 | `#8D6E63` | `#29B6F6` |
| 12 | KaktoffelKrabbo | Rare | 5 | `#E64A19` | `#388E3C` |
| 13 | TrommeloDackelini | Rare | 5 | `#795548` | `#FFD54F` |
| 14 | TurboTortellino | Epic | 6 | `#FFE082` | `#43A047` |
| 15 | DiscomuffoMantarini | Epic | 6 | `#7E57C2` | `#E0E0E0` |
| 16 | WaschmaschinoWalrossi | Epic | 6 | `#ECEFF1` | `#8D6E63` |
| 17 | FonixFohnini | Epic | 6 | `#FF7043` | `#EC407A` |
| 18 | ZitronoOkapini | Epic | 6 | `#FFEB3B` | `#5D4037` |
| 19 | VentilatorePelicanzo | Epic | 6 | `#90CAF9` | `#FFFFFF` |
| 20 | KaiserKurbissimo | Legendary | 7.5 | `#FB8C00` | `#2E7D32` |
| 21 | RakettoRaclettini | Legendary | 7.5 | `#FFD54F` | `#B0BEC5` |
| 22 | GondoloGoriglione | Legendary | 7.5 | `#424242` | `#1565C0` |
| 23 | TictacoPolpettone | Legendary | 7.5 | `#AB47BC` | `#8D6E63` |
| 24 | DonnerdonerGreifino | Legendary | 7.5 | `#FFCA28` | `#455A64` |
| 25 | GalaxioGelatone | Mythic | 9 | `#3949AB` | `#F48FB1` |
| 26 | VulcanoWaffelotto | Mythic | 9 | `#D84315` | `#FFB74D` |
| 27 | KristalloKapibarone | Mythic | 9 | `#80DEEA` | `#B39DDB` |
| 28 | AstronudelNautilino | Mythic | 9 | `#FFE0B2` | `#26C6DA` |
| 29 | IlGrandeGlitchonzo | Secret | 11 | `#00E676` | `#D500F9` |
| 30 | OmegaOmelettore | Secret | 11 | `#FFFFFF` | `#FFC107` |

**Empfohlene Reihenfolge:** zuerst die 7 Commons (die sieht man am häufigsten), dann Secret und Mythic (Thumbnail-Stars), danach den Rest.

---

## 7. Sounds (nur Roblox-eigene oder eigene Audios)

In `SoundService/Sfx` liegen 15 leere Sound-Objekte. So füllst du sie:

1. **Toolbox → Audio**, Filter **Creator: Roblox** (die offiziellen, lizenzfreien Roblox-Sounds) **oder** eigene Aufnahmen über **Asset Manager → Bulk Import** hochladen (z. B. selbst eingesprochene Fantasie-Rufe wie „Ploppo!“ für die Figuren).
2. Sound anklicken → `SoundId` kopieren → beim jeweiligen Sound-Objekt in `SoundId` einfügen.
3. Vorschläge für die Suche: Buy = „pop“, Cash = „coins“, Steal = „whoosh“, Alarm = „alarm“, Bonk = „boing“, Lock = „lock click“, Rebirth = „level up“, Legendary/Secret = „fanfare“ oder „magic“, Music = „upbeat“ (Creator Roblox).

Fehlt eine SoundId, spielt der Code einfach nichts ab. Es gibt also keine Fehler.

---

## 8. Checkliste vor Phase 3

- [ ] Spiel veröffentlicht, API Services an
- [ ] `SetupWorld` ausgeführt, Output zeigt ✅
- [ ] Im Workspace sind sichtbar: Förderband mit lila und rotem Tor, 2 Leaderboards, Wiese, Laufweg
- [ ] `ServerStorage/BaseTemplate` vorhanden (zum Anschauen kurz nach Workspace ziehen und wieder zurück)
- [ ] `StarterPack/Klatsche` vorhanden
- [ ] Ordner `ReplicatedStorage/Shared`, `FigureModels`, `Remotes`, `ServerScriptService/Services`, `StarterPlayerScripts/ClientModules` vorhanden
- [ ] Gespeichert (Strg+S bzw. File → Publish)

Die Plots sind absichtlich unsichtbar. Die Basen erscheinen erst, wenn du in Phase 3 auf Play drückst.
