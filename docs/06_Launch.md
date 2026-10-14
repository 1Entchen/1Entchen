# Phase 6 – Launch-Plan

## 1. Icon und Thumbnails (fertig)

Alle Bilder sind eigene Vektorgrafiken, ohne fremde Marken oder Memes. Sie liegen in [`marketing/`](../marketing):

| Datei | Verwendung | Größe |
|---|---|---|
| `icon_512.png` | Spiel-Icon | 512 × 512 |
| `thumbnail_1_hero.png` | Thumbnail 1 (Titel + Förderband + Seltenheiten) | 1920 × 1080 |
| `thumbnail_2_steal.png` | Thumbnail 2 (Stehlen, „…und renn!“) | 1920 × 1080 |
| `thumbnail_3_collect.png` | Thumbnail 3 (alle Seltenheiten) | 1920 × 1080 |

Außerdem fertig:
| Ordner/Datei | Verwendung |
|---|---|
| `icons/pass_*.png` (7) | Bilder für die Game Passes (beim Anlegen im Creator Hub hochladen) |
| `icons/product_*.png` (10) | Bilder für die Developer Products |
| `figures/01_…png` bis `30_…png` | Sammelkarte jeder Figur (Discord, Social Media, Updates, Gruppen-Posts) |
| `poster_all_figures.png` | Übersicht aller 30 Figuren (Discord, Gruppe, Werbung) |

Hochladen: **Creator Hub → dein Spiel → Configure → Places → Thumbnails / Icon**.
Ändern: Texte und Figuren stehen in `marketing/render.js`. Neu rendern mit `node marketing/render.js` (Node + Playwright nötig).

**Tipp:** Im Creator Hub die **Thumbnail-Tests/Personalisierung** nutzen und alle 3 Thumbnails gegeneinander laufen lassen. Nach etwa einer Woche die Variante mit der besten Klickrate behalten.

Ideen für weitere Varianten:
- Regenbogen-Secret auf schwarzem Grund mit dem Text „1 ZU 500.000!“
- Eine Riesen-Basis voller goldener Figuren, Text „REICHSTER SPIELER?“
- Saisonal: Kürbissimo mit Hexenhut zu Halloween

## 2. Titel

**Empfehlung:** `Brainrot Bandits 🦹💰`

Nach Updates ein Präfix voranstellen (erhöht die Klickrate): `[🆕 SECRETS] Brainrot Bandits 🦹💰`, `[🎃 HALLOWEEN] Brainrot Bandits`, `[2x CASH] Brainrot Bandits`.

## 3. Beschreibung (SEO-optimiert)

**Deutsch:**
```
🦹 BRAINROT BANDITS – Kaufen, Sammeln, KLAUEN! 💰

Kauf verrückte Brainrot-Figuren vom Förderband, stell sie in deine Basis und verdiene jede Sekunde Cash!
Aber Vorsicht: Andere Spieler können deine besten Figuren stehlen! 😱

⭐ 30+ originale Brainrots: Common, Rare, Epic, Legendary, Mythic und SECRET
🌈 Mutationen: Gold, Diamant und das ultra-seltene Regenbogen (1 zu 500.000!)
🦹 Stiehl Figuren aus fremden Basen und renn nach Hause!
🔒 Schließ deine Basis ab und hau Diebe mit der Klatsche weg!
🔁 Rebirth für dauerhafte Multiplikatoren
🎁 Tägliche Belohnungen, Quests und Spielzeit-Geschenke
🎉 Jedes Wochenende 2x CASH! Täglich Happy Hour mit Lucky Spawn!

👍 Like und ⭐ Favorit für neue Figuren!
👥 Tritt unserer Gruppe bei für +10 % Cash!

Tycoon, Simulator, Sammeln, Stehlen, Brainrot, Basis, Rebirth, Secret, Mythic
```

**English** (unter Localization als Übersetzung eintragen; das bringt internationale Spieler):
```
🦹 BRAINROT BANDITS – Buy, Collect, STEAL! 💰

Buy wacky brainrot characters from the conveyor, place them in your base and earn cash every second!
But watch out: other players can steal your best ones! 😱

⭐ 30+ original brainrots: Common, Rare, Epic, Legendary, Mythic and SECRET
🌈 Mutations: Gold, Diamond and ultra-rare Rainbow (1 in 500,000!)
🦹 Steal from other bases and run home!
🔒 Lock your base and bonk thieves!
🔁 Rebirth for permanent multipliers
🎁 Daily rewards, quests and playtime gifts
🎉 2x CASH every weekend! Daily Happy Hour with Lucky Spawn!

👍 Like and ⭐ favorite for new characters!
👥 Join our group for +10% cash!
```

**Mehrsprachigkeit:** Creator Hub → Localization → **Automatic Translation** aktivieren. Die UI-Texte werden automatisch erfasst und übersetzt. Das öffnet das Spiel für Spieler weltweit.

## 4. Einstellungen im Creator Hub

| Einstellung | Wert |
|---|---|
| Genre | **Simulation** (Subgenre: Tycoon), sonst die nächstpassende Kategorie |
| Server-Größe | 8 |
| Geräte | Computer, Phone, Tablet, Console (alle an) |
| Maturity-Fragebogen | Ehrlich ausfüllen. Cartoon-„Klatsche“ ohne Blut gilt als milde Comic-Gewalt, voraussichtlich „Mild“ |
| Social Links | Roblox-Gruppe, Discord, YouTube/TikTok (sobald vorhanden) |
| Private Server | Erlauben, z. B. für 50 R$/Monat (zusätzliche Einnahme) |
| `Config.GroupId` | ID deiner Roblox-Gruppe eintragen (aktiviert +10 % Gruppen-Bonus) |

## 5. Test-Checkliste vor dem Launch

### Funktion (Studio: Test → 2–3 Players)
- [ ] Spawn in der eigenen Basis, Schild zeigt den Namen
- [ ] Figuren spawnen, Kaufen per E/Antippen klappt, Figur läuft in den Slot
- [ ] Einkommen steigt, Cash-Pad sammelt ein
- [ ] Verkaufen über Prompt (F) und über das Basis-Menü
- [ ] Stehlen: Halten → Tragen → in eigener Basis ankommen = Erfolg
- [ ] Klatsche stoppt den Dieb, Figur geht zurück
- [ ] Schloss: Fremde werden rausgesetzt, Countdown läuft, Ablauf-Toast erscheint
- [ ] Neuling-Schutz verhindert Diebstahl in den ersten 5 Minuten
- [ ] Rebirth mit und ohne erfüllte Bedingung
- [ ] Tägliche Belohnung, Geschenke und Quests abholen
- [ ] Alle Game Passes und Developer Products kaufen (in Studio kostenlos testbar), die Wirkung prüfen
- [ ] Spiel verlassen und neu beitreten: Cash, Figuren und Rebirths sind gespeichert, Offline-Popup erscheint
- [ ] Leaderboards füllen sich (nur im veröffentlichten Spiel, ca. 2 Minuten warten)

### Mobile (Device Emulator + echtes Handy)
- [ ] Alle Buttons gut antippbar, nichts überlappt den Joystick (links unten) oder den Sprung-Button (rechts unten)
- [ ] Shop-Fenster passt auf den Bildschirm und lässt sich scrollen
- [ ] ProximityPrompts sind antippbar (Kaufen, Stehlen, Verkaufen)
- [ ] Klatsche: Tool-Leiste antippen, dann auf den Bildschirm tippen
- [ ] Performance flüssig (≥ 30 FPS auf einem Mittelklasse-Handy)

### PC und Konsole
- [ ] Tasten E (Kaufen/Stehlen), F (Verkaufen), 1 (Klatsche)
- [ ] Gamepad: Prompts mit X/A, Menüs mit dem virtuellen Cursor bedienbar

### Live-Test
- [ ] Spiel veröffentlichen, mit 3–5 Freunden im echten Server spielen
- [ ] Output/Developer Console (F9) auf rote Fehler prüfen

## 6. Die ersten Spieler bekommen

### Woche 0 (vor dem Launch)
1. **Roblox-Gruppe** anlegen („Brainrot Bandits Fans“), Gruppen-ID in `Config.GroupId` eintragen. Mitglieder bekommen +10 % Cash und bilden die Basis für Ankündigungen.
2. **Discord-Server** mit Kanälen #updates, #secret-funde, #handel. In der Spielbeschreibung verlinken (Social Links).
3. **10–15 Kurzvideos** vorproduzieren (TikTok, YouTube Shorts, Instagram Reels):
   - „Ich habe ein REGENBOGEN-SECRET gezogen 😱“
   - „Er hat meinen Mythic geklaut… Rache!“ (Diebstahl + Klatsche)
   - „0 → Rebirth 1 in 10 Minuten“ (mit einem Testaccount)
   - Hook in den ersten 1–2 Sekunden, Hochformat, Spielname als Text im Video

### Launch-Tag (am besten Freitagnachmittag)
1. Veröffentlichen, sodass das 2x-Cash-Wochenende direkt danach beginnt.
2. Täglich 1–2 Shorts posten, Hashtags `#roblox #brainrot #robloxtycoon`.
3. Freunde und die Gruppe einladen. Freunde im selben Server geben +10 % Cash pro Freund (der Button „👥 +10%“ im Spiel öffnet die Einladung).

### Roblox-Werbung (Ads Manager)
- **Sponsored Experiences** im Roblox Ads Manager.
- **Testphase:** 7 Tage mit kleinem Tagesbudget (z. B. 15–30 € pro Tag, insgesamt ca. 100–200 €).
- Alle 3 Thumbnails als eigene Anzeigen laufen lassen. Nach 2–3 Tagen die schlechtesten abschalten.
- Kennzahlen: **Klickrate**, **D1-Retention ≥ 20 %**, **durchschnittliche Spielzeit ≥ 12 min**, **Robux-Einnahmen pro Besuch**.
- Hochskalieren, sobald die Einnahmen pro Besuch die Werbekosten pro Besuch übersteigen. Sonst zuerst das Spiel verbessern (Tutorial, Balancing) und dann erneut testen.

### Danach
- Wöchentliche Updates (Phase 5) und den Titel-Präfix anpassen.
- Kleine YouTuber (1.000–50.000 Abonnenten) anschreiben und ihnen einen frühen Blick auf neue Secrets anbieten.
- Community-Events im Discord ankündigen („Samstag 18 Uhr: Secret-Regen“).

## 7. Kennzahlen (Creator Hub → Analytics)

| Kennzahl | Ziel | Wenn darunter |
|---|---|---|
| D1-Retention | ≥ 25 % | Ersten Spielminuten verbessern (Start-Cash, Tutorial-Pfeil, frühe Rares) |
| D7-Retention | ≥ 8 % | Mehr Content und Events, Tag-7-Belohnung attraktiver machen |
| Sitzungsdauer | ≥ 18 min | Spielzeit-Geschenke, Quests, Hype um seltene Spawns |
| Payer-Conversion | ≥ 2 % | Starter-Paket prüfen, Platzierung der Angebote anpassen |
| ARPPU | ≥ 150 R$ | Bessere Pässe, Bundles, saisonale Angebote |
