# Phase 1 – Game-Design-Dokument

**Arbeitstitel:** Brainrot Bandits (finaler Titel + SEO in Phase 6)
**Genre:** Collect-and-Steal-Tycoon, Brainrot-Stil
**Zielgruppe:** 8–16 Jahre, Mobile zuerst (ca. 70 % der Roblox-Spieler), danach PC und Konsole
**Servergröße:** 8 Spieler, 8 Basen pro Server

---

## 1. Design-Säulen

| Säule | Was das im Spiel heißt |
|---|---|
| **Sofort verständlich** | In 10 Sekunden klar: Figur fährt vorbei → kaufen → sie bringt Geld. |
| **Gier und Angst** | Seltene Figuren will man haben (Gier), und sie können geklaut werden (Angst). Diese Spannung hält Spieler online und bringt sie zurück. |
| **Sichtbarer Erfolg** | Seltene Figuren sind groß, leuchten und haben Partikel. Alle auf dem Server sehen, wer reich ist. |
| **Kurze Glücksmomente** | Alle 2,5 s kommt eine neue Figur. Jede kann die eine Secret-Figur sein. |
| **Fair bezahlen** | Robux beschleunigen den Fortschritt und bringen Komfort, kaufen aber keinen unbesiegbaren Schutz. Das ist gut für Bewertungen und Empfehlungen. |

---

## 2. Core Loop

```
   ┌────────────────────────────────────────────────────────────┐
   │                                                            │
   ▼                                                            │
[Förderband]  Figur mit Seltenheit + Mutation fährt vorbei      │
   │                                                            │
   ▼                                                            │
[Kaufen]  E drücken / antippen, Cash wird abgezogen             │
   │      Figur läuft selbst zur eigenen Basis                  │
   ▼                                                            │
[Platzieren]  automatisch auf den nächsten freien Slot          │
   │                                                            │
   ▼                                                            │
[Einkommen]  Cash/s sammelt sich auf dem Cash-Pad an            │
   │         über das Pad laufen = einsammeln                   │
   ▼                                                            │
[Aufrüsten]  schwache Figuren verkaufen (50 %), bessere kaufen ─┘
   │
   ├──► [Stehlen]   in fremde Basis laufen, Figur nehmen, heimbringen
   ├──► [Verteidigen]  Basis abschließen, Diebe mit der Klatsche treffen
   │
   ▼
[Rebirth]  Cash + Figuren zurücksetzen → dauerhafter Multiplikator, mehr Slots
```

**Meta-Loop (Bindung):** tägliche Belohnung → Quests → Wochenend-Events → neue Figuren mit Updates → globales Leaderboard.

---

## 3. Ablauf einer typischen Sitzung (Zielwerte)

| Zeitpunkt | Ereignis | Zweck |
|---|---|---|
| 0:00 | Spawn in der eigenen Basis, 100 Cash, Pfeil zeigt zum Band | Kein Menü, direkt spielen |
| 0:15 | Erste Common gekauft | Erstes Erfolgserlebnis |
| 2:00 | Erste Rare | „Ich werde besser“ |
| 8–12 min | Erste Epic, erster Diebstahl wird beobachtet | Neugier auf PvP |
| 30–45 min | Erste Legendary, Server-Ankündigung bei anderen | Verlangen geweckt |
| 60–90 min | Rebirth 1 möglich | Langfristiges Ziel erreicht |
| Ab Tag 2 | Mythic/Secret jagen, Quests, Leaderboard | Langzeitbindung |

**KPI-Ziele:** D1-Retention ≥ 25 %, D7 ≥ 8 %, durchschnittliche Sitzung ≥ 18 min, Payer-Conversion ≥ 2 %.

---

## 4. Seltenheiten und Spawn-Chancen

Das Förderband spawnt **alle 2,5 Sekunden** eine Figur (≈ 1.440 pro Stunde und Server). Mit „Lucky Spawn“ (Developer Product) werden die Chancen serverweit verbessert. Das nützt allen Spielern und schafft deshalb gute Stimmung.

| Seltenheit | Farbe | Chance normal | Chance bei Lucky Spawn | ≈ pro Stunde/Server | Preisspanne | Einkommen/s |
|---|---|---|---|---|---|---|
| Common | Grau `#B4B4B4` | 62,0 % | 50,0 % | 893 | 25 – 750 | 1 – 15 |
| Rare | Blau `#3C8CFF` | 25,0 % | 28,0 % | 360 | 1.200 – 9.000 | 20 – 105 |
| Epic | Lila `#A64BFF` | 9,0 % | 13,5 % | 130 | 15K – 90K | 150 – 620 |
| Legendary | Gold `#FFB400` | 3,2 % | 6,0 % | 46 | 160K – 750K | 950 – 3.100 |
| Mythic | Rot `#FF3C3C` | 0,7 % | 2,2 % | 10 | 1,5M – 6,5M | 5.500 – 18.500 |
| Secret | Regenbogen, animiert | 0,1 % | 0,3 % | 1,4 | 20M – 50M | 45K – 100K |

**Ziehung in zwei Stufen:**
1. Erst wird die Seltenheit gewürfelt (Tabelle oben).
2. Dann wird die Figur innerhalb der Seltenheit gewürfelt. Günstigere Figuren haben ein höheres Gewicht (siehe Spalte „Gewicht“ in Abschnitt 6).

**Gesichert gegen Pech (Pity-System, pro Server):** Wenn 400 Spawns lang keine Legendary oder bessere Figur kam, ist die nächste garantiert Legendary. So gibt es keine Server ohne Highlights.

### Mutationen (zusätzlicher Wurf bei jedem Spawn)

Mutationen geben bekannten Figuren einen neuen Reiz. So bleibt auch eine Common spannend.

| Mutation | Chance | Preis-Faktor | Einkommens-Faktor | Optik |
|---|---|---|---|---|
| Normal | 94,8 % | ×1 | ×1 | – |
| Gold | 4,0 % | ×1,5 | ×2 | Gold-Material, Glitzer |
| Diamant | 1,0 % | ×3 | ×5 | Glas/Cyan, Funkeln |
| Regenbogen | 0,2 % | ×6 | ×12 | Farbwechsel, Sterne |

Eine **Regenbogen-Secret** (0,1 % × 0,2 % = 1 zu 500.000) ist die ultimative Jagd und liefert Stoff für Clips und Social Media.

---

## 5. Wirtschaft und Balancing

### Grundwerte

| Parameter | Wert | Begründung |
|---|---|---|
| Startgeld | 100 Cash | Reicht für 2 Commons, also sofort Handeln |
| Basis-Slots | 10 | Früh genug Platz, später wird ausgetauscht |
| Max. Slots | 10 + 5 (Rebirth) + 5 (Game Pass) = **20** | Klare Kaufmotivation für den Pass |
| Verkaufswert | 50 % des Kaufpreises (inkl. Mutation) | Austauschen lohnt sich, ist aber kein Gratis-Geld |
| Cash-Pad | Sammelt Einkommen aller Figuren, kein Limit online | Ein Laufweg, mobilfreundlich |
| Offline-Einkommen | 20 % der Rate, max. 2 h (VIP: 40 %, max. 6 h) | Grund zum Zurückkommen, Mehrwert für VIP |
| Figur auf dem Band | 18 s Laufzeit, danach verschwindet sie | Erzeugt Zeitdruck |
| Kauf-Schutz | Nach einem Kauf ist die Figur reserviert und läuft zur Basis | Kein Kauf-Wettrennen per Exploit |

### Einkommensformel (serverseitig)

```
Einkommen/s = Basis-Einkommen × Mutations-Faktor
              × (1 + 0,5 × Rebirths)
              × 2 (wenn Game Pass „2x Cash“)
              × 1,1 (wenn VIP-Pass)
              × 1,1 (wenn Roblox Premium)
              × (1 + Index-Bonus)        (0 / 0,05 / 0,10 / 0,15)
              × 1,1 (wenn Mitglied der Roblox-Gruppe)
              × Event-Multiplikator (z. B. 2 am Wochenende)
```

### Rebirth

| Rebirth | Kosten (Cash) | Voraussetzung | Einkommens-Multi danach | Bonus-Slot | Schloss-Dauer |
|---|---|---|---|---|---|
| 1 | 2,5M | mind. 1 Legendary besitzen | ×1,5 | +1 | 65 s |
| 2 | 7,5M | mind. 1 Legendary | ×2,0 | +2 | 70 s |
| 3 | 22,5M | mind. 1 Mythic | ×2,5 | +3 | 75 s |
| 4 | 67,5M | mind. 1 Mythic | ×3,0 | +4 | 80 s |
| 5 | 200M | mind. 1 Secret | ×3,5 | +5 | 85 s |
| n | 2,5M × 3^(n−1) | ab 5: Secret | 1 + 0,5n | max. +5 | max. 120 s |

**Rebirth setzt zurück:** Cash (auf 100) und alle platzierten Figuren.
**Rebirth behält:** Rebirth-Zähler, Game Passes, Tagesbelohnungs-Serie, Statistik, Index (Sammelbuch).
Nach jedem Rebirth kommt eine Konfetti- und Sound-Animation, und der Rebirth-Rang erscheint als Titel über dem Kopf (z. B. „⭐3“).

### Sammel-Index

Jede Figur, die jemals besessen wurde, wird im Index freigeschaltet. Mutationen zählen getrennt (30 × 4 = 120 Einträge). Belohnungen:
- 10 / 20 / 30 Figuren entdeckt: +5 % / +10 % / +15 % Einkommen (dauerhaft)
- Alle Gold-Varianten: Titel „Goldjäger“

Der Index ist ein starkes Langzeit-Ziel und übersteht jeden Rebirth.

---

## 6. Die 30 originalen Figuren

Alle Namen und Konzepte sind eigene Erfindungen: Alltagsgegenstand + Tier + Fantasie-Italienisch/Deutsch. Es gibt keine Anlehnung an bestehende Meme-Charaktere. Die Modelle werden in Studio aus Parts/Unions gebaut (Low-Poly-Stil, siehe Phase 2). Die Sounds sind selbst eingesprochene Fantasie-Rufe oder stammen aus der Roblox-eigenen Audio-Bibliothek.

„Gewicht“ = relative Ziehchance innerhalb der Seltenheit. „Amortisation“ = Preis ÷ Einkommen, also nach wie vielen Sekunden sich die Figur bezahlt hat.

### Common (grau)

| # | Name | Beschreibung | Preis | Cash/s | Amortisation | Gewicht |
|---|---|---|---|---|---|---|
| 1 | **Spagetto Gecko** | Gecko aus Spaghetti, Gabel als Schwanz | 25 | 1 | 25 s | 30 |
| 2 | **Sockolino Mausolino** | Maus, die in einer Ringelsocke wohnt | 60 | 2 | 30 s | 22 |
| 3 | **Kettlo Froggolo** | Frosch mit Teekessel-Bauch, pfeift beim Quaken | 120 | 3 | 40 s | 16 |
| 4 | **Brezelwurm Brezelini** | Wurm, der sich zur Brezel verknotet hat | 200 | 5 | 40 s | 12 |
| 5 | **Radiero Schneckolo** | Schnecke mit Radiergummi-Haus | 350 | 8 | 44 s | 9 |
| 6 | **Mopetto Pinguzzo** | Pinguin mit Wischmopp-Frisur | 500 | 11 | 45 s | 7 |
| 7 | **Wackel Wobblino** | Wackelpudding-Blob mit Kirschhut | 750 | 15 | 50 s | 4 |

### Rare (blau)

| # | Name | Beschreibung | Preis | Cash/s | Amortisation | Gewicht |
|---|---|---|---|---|---|---|
| 8 | **Lampadino Falenino** | Motte mit Glühbirnen-Kopf, flackert | 1.200 | 20 | 60 s | 28 |
| 9 | **Ciabatto Canguro** | Känguru mit Hausschuh als Beutel | 1.800 | 28 | 64 s | 22 |
| 10 | **Sushi Hamsterini** | Hamster als Sushi-Rolle eingewickelt | 2.700 | 40 | 68 s | 18 |
| 11 | **Bürsto Igelino** | Igel mit Zahnbürsten-Stacheln | 4.000 | 55 | 73 s | 14 |
| 12 | **Kaktoffel Krabbo** | Krabbe mit Kaktus-Kartoffel-Panzer | 6.000 | 75 | 80 s | 10 |
| 13 | **Trommelo Dackelini** | Dackel mit Trommel-Körper, trommelt beim Laufen | 9.000 | 105 | 86 s | 8 |

### Epic (lila)

| # | Name | Beschreibung | Preis | Cash/s | Amortisation | Gewicht |
|---|---|---|---|---|---|---|
| 14 | **Turbo Tortellino** | Schildkröte mit Tortellini-Panzer und Raketendüse | 15.000 | 150 | 100 s | 26 |
| 15 | **Discomuffo Mantarini** | Mantarochen-Muffin mit Discokugel-Kirsche | 22.000 | 200 | 110 s | 21 |
| 16 | **Waschmaschino Walrossi** | Walross im Waschmaschinen-Körper, schleudert | 32.000 | 270 | 119 s | 18 |
| 17 | **Fönix Föhnini** | Feuervogel aus einem Haarföhn | 45.000 | 360 | 125 s | 15 |
| 18 | **Zitrono Okapini** | Okapi mit Zitronenscheiben-Ohren | 65.000 | 480 | 135 s | 12 |
| 19 | **Ventilatore Pelicanzo** | Pelikan mit Ventilator-Schnabel | 90.000 | 620 | 145 s | 8 |

### Legendary (gold)

| # | Name | Beschreibung | Preis | Cash/s | Amortisation | Gewicht |
|---|---|---|---|---|---|---|
| 20 | **Kaiser Kürbissimo** | Kürbis-Kaiser mit Gurken-Zepter | 160.000 | 950 | 168 s | 30 |
| 21 | **Raketto Raclettini** | Käse-Raclette-Pfännchen auf einer Rakete | 240.000 | 1.300 | 185 s | 25 |
| 22 | **Gondolo Goriglione** | Gorilla, der in einer Gondel rudert | 350.000 | 1.750 | 200 s | 20 |
| 23 | **Tictaco Polpettone** | Krake mit Kuckucksuhr-Kopf | 500.000 | 2.300 | 217 s | 15 |
| 24 | **Donnerdöner Greifino** | Greif mit Gewitterwolken-Flügeln aus Fladenbrot | 750.000 | 3.100 | 242 s | 10 |

### Mythic (rot)

| # | Name | Beschreibung | Preis | Cash/s | Amortisation | Gewicht |
|---|---|---|---|---|---|---|
| 25 | **Galaxio Gelatone** | Qualle aus Galaxie-Eiscreme, schwebt | 1.500.000 | 5.500 | 273 s | 40 |
| 26 | **Vulcano Waffelotto** | Vulkan aus Waffeln, spuckt Sirup | 2.500.000 | 8.500 | 294 s | 30 |
| 27 | **Kristallo Kapibarone** | Riesen-Wasserschwein aus Kristall | 4.000.000 | 12.500 | 320 s | 20 |
| 28 | **Astronudel Nautilino** | Nautilus-Muschel als Raumschiff aus Nudeln | 6.500.000 | 18.500 | 351 s | 10 |

### Secret (Regenbogen, animiert)

| # | Name | Beschreibung | Preis | Cash/s | Amortisation | Gewicht |
|---|---|---|---|---|---|---|
| 29 | **Il Grande Glitchonzo** | Figur, die ständig „glitcht“ (Teile springen, Farben flackern) | 20.000.000 | 45.000 | 444 s | 70 |
| 30 | **Omega Omelettore** | Kosmischer Spiegelei-Gott mit Pfannen-Heiligenschein | 50.000.000 | 100.000 | 500 s | 30 |

**Content-Plan:** Mit jedem Update (alle 1–2 Wochen) kommen 3–5 neue Figuren dazu, vor allem in Mythic, Secret und Event-Varianten. Neue Figuren sind der wichtigste Grund, warum Spieler zurückkommen.

---

## 7. Diebstahl-System (PvP)

| Regel | Wert |
|---|---|
| Stehlen | ProximityPrompt an einer fremden Figur, **2,0 s halten** |
| Tragen | Figur schwebt über dem Kopf des Diebs, der Dieb läuft mit 70 % Tempo und ist für alle rot markiert |
| Erfolg | Dieb berührt die Zone seiner **eigenen** Basis → Figur landet auf seinem freien Slot |
| Kein freier Slot | Stehlen ist nicht möglich (Prompt wird ausgegraut) |
| Abwehr | Jeder Spieler hat eine **Klatsche** (Tool). Ein Treffer auf den Dieb → Figur fliegt zurück zum Besitzer, Dieb wird 1,5 s betäubt |
| Fehlschlag | Dieb stirbt, verlässt das Spiel oder trägt länger als 40 s → Figur geht zurück |
| Cooldown | 20 s zwischen zwei Diebstählen pro Dieb |
| Benachrichtigung | Besitzer bekommt sofort ein rotes Banner + Sound: „⚠ Spieler XY klaut deinen Kaiser Kürbissimo!“ |
| Neuling-Schutz | Basen sind in den ersten 5 Minuten nach dem Beitritt geschützt (Schild-Effekt) |
| Schutz verlieren | Wer selbst stiehlt, verliert seinen Neuling-Schutz sofort |

### Basis-Schloss

| Regel | Wert |
|---|---|
| Aktivieren | Lock-Knopf in der eigenen Basis berühren |
| Dauer | 60 s (+5 s pro Rebirth, max. 120 s) |
| Wirkung | Laser-Tür am Eingang wird solide. Nur der Besitzer kommt durch, Fremde werden zurückgestoßen |
| Erneut abschließen | Erst wenn das Schloss abgelaufen ist (Sichtbarer Countdown über der Tür). So entstehen kurze Zeitfenster für Diebe |
| Developer Product „Schloss-Verlängerung“ | +5 Minuten sofort, auch während das Schloss läuft |

Warum das funktioniert: Aktive Spieler können sich gut schützen, aber nie zu 100 %. Abwesende Spieler sind verwundbar. Daraus entsteht Spannung, ohne dass sich jemand ständig unfair behandelt fühlt.

---

## 8. Monetarisierung (Kurzübersicht, Details und Code in Phase 4)

| Typ | Produkt | Preis (Robux) | Kern-Nutzen |
|---|---|---|---|
| Game Pass | 2x Cash | 249 | Verdoppelt jedes Einkommen dauerhaft |
| Game Pass | VIP | 349 | Chat-Tag, VIP-Lounge, +10 % Cash, besseres Offline-Einkommen, goldener Name |
| Game Pass | Auto-Collect | 179 | Kein Laufen zum Cash-Pad mehr |
| Game Pass | +5 Basis-Slots | 299 | 20 statt 15 Slots |
| Dev Product | Cash-Pakete (4 Stufen, skalieren mit dem Fortschritt) | 25 / 79 / 199 / 499 | Sofortiger Fortschritt |
| Dev Product | Lucky Spawn (10 min, ganzer Server) | 99 | Bessere Chancen für alle + Ankündigung des Käufers |
| Dev Product | Schloss-Verlängerung | 29 | Basis 5 min zusätzlich sicher |
| Premium | Premium-Payouts | – | +10 % Cash, exklusiver Premium-Slot, tägliche Bonus-Truhe |

Cash-Pakete skalieren mit dem **aktuellen Einkommen** (z. B. „10 Minuten Einkommen“). So bleiben sie in jeder Spielphase gleich attraktiv.

---

## 9. Retention (Kurzübersicht, Details in Phase 5)

- **Tägliche Belohnung:** 7-Tage-Kalender, Tag 7 = garantierte Epic, Serie bleibt beim Rebirth erhalten
- **Quests:** 3 Tages- und 3 Wochenquests („Kaufe 20 Figuren“, „Stiehl 3 Figuren“, „Verteidige 2 Mal“)
- **Events:** Wochenende = 2x Cash; monatliche Themen-Events mit limitierten Figuren
- **Server-Ankündigungen:** Bei Legendary oder besser erscheint ein Banner im ganzen Server, bei Secret serverübergreifend (MessagingService)
- **Gruppen-Belohnung:** +10 % Cash für Mitglieder der Roblox-Gruppe, so wächst die Community

---

## 10. Technische Leitlinien

- **Der Server entscheidet alles.** Der Client schickt nur Wünsche („ich will Figur #ID kaufen“). Der Server prüft Geld, Distanz, Slots, Cooldowns und den Besitz.
- **Daten:** Session-Locking im ProfileService-Stil, Auto-Save alle 60 s, Speichern bei Verlassen und bei `BindToClose`, Retry mit Backoff, Schema-Versionierung
- **Performance:** Max. 12 Figuren gleichzeitig auf dem Band. Figuren sind einfache Modelle (≤ 30 Parts), Animation per Client-TweenService
- **Mobil:** Alle Buttons ≥ 44 px, nur ProximityPrompts statt Tastenkürzeln, UI mit `UIScale` und `UIAspectRatioConstraint`

### Gespeicherte Spielerdaten (Entwurf)

```lua
{
    Version = 1,
    Cash = 100,
    TotalEarned = 0,          -- für das Leaderboard
    Rebirths = 0,
    Slots = {                 -- [SlotIndex] = Figur
        [1] = { Id = 1, Mutation = "Normal" },
    },
    Index = { ["1_Normal"] = true },
    Daily = { Streak = 0, LastClaim = 0 },
    Quests = { Day = 0, Progress = {}, Claimed = {} },
    Stats = { Steals = 0, Defends = 0, Bought = 0, PlayTime = 0 },
    LastOnline = 0,
    Settings = { Music = true, Sfx = true },
}
```

---

## Nächste Phase

**Phase 2 – Studio-Setup:** komplette Explorer-Struktur, alle Parts und Modelle mit exakten Namen, Basis-Layout, Förderband-Aufbau und Figuren-Bauanleitung im Low-Poly-Stil.
