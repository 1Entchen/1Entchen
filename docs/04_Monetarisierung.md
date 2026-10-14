# Phase 4 – Monetarisierung

Ziel: möglichst viele Robux pro Spieler, **ohne gegen Roblox-Regeln zu verstoßen**. Ein gesperrtes Spiel verdient nichts. Deshalb gilt:
- Die Chancen bei bezahlten Zufalls-Items werden **vor dem Kauf** angezeigt (passiert automatisch im Shop beim Mythic-Drop).
- Keine Glücksspiel-Mechanik mit Robux.
- Keine irreführenden Angebote.
- Kein Druck auf Kinder („Kauf jetzt oder du verlierst alles“).

Der Code ist komplett fertig: `MonetizationService` (Server) und Shop, Popups und Toasts (Client). Du musst nur die Produkte anlegen und ihre IDs eintragen.

## 1. Produkte anlegen und IDs eintragen

**Creator Hub → Creations → dein Spiel → Monetization**

1. **Passes → Create a Pass:** Name, Bild (Icon aus `marketing/` oder ein eigenes), Beschreibung, dann **Sale aktivieren** und Preis setzen.
2. **Developer Products → Create:** Name, Preis.
3. Die **ID** jedes Produkts kopieren und in `ReplicatedStorage/Shared/Config` beim passenden Eintrag eintragen (`Id = 0` → `Id = 123456789`).

Die echten Preise werden im Spiel automatisch über `GetProductInfo` geladen. Änderst du einen Preis im Creator Hub, stimmt der Shop also trotzdem.

## 2. Game Passes (einmalig, für immer)

| Key in Config | Name | Preis | Nutzen | Warum dieser Preis |
|---|---|---|---|---|
| `DoubleCash` | 2x Cash | **249 R$** | Einkommen ×2 dauerhaft | Der Standard-Bestseller in Tycoons. 199–299 ist der bewährte Bereich, 249 bleibt unter der 250er-Schwelle |
| `VIP` | VIP | **349 R$** | +10 % Cash, Chat-Tag, 2× Tagesbelohnung, Offline 40 % für 6 h | Status-Pass: Sichtbarkeit (Chat-Tag) verkauft sich, darum der höchste Preis |
| `ExtraSlots` | +5 Basis-Slots | **299 R$** | 5 Slots mehr | Wird an gesperrten Slots in der Basis und beim Toast „Basis voll“ direkt angeboten |
| `AutoCollect` | Auto-Collect | **179 R$** | Cash landet automatisch auf dem Konto | Komfort für Vielspieler, günstiger Einstiegs-Pass |
| `MasterThief` | Meisterdieb | **199 R$** | Halten 1 s statt 2 s, Tempo beim Tragen 85 % statt 70 % | PvP-Vorteil, starke Motivation, aber kein Sieg-Garant (die Klatsche stoppt auch Meisterdiebe) |
| `Speed` | Turbo-Schuhe | **129 R$** | +30 % Laufgeschwindigkeit | Impulskauf, nützlich beim Band und beim Stehlen |
| `SuperBonk` | Mega-Klatsche | **149 R$** | Reichweite 14 statt 9, Betäubung 2,5 s | Verteidigungs-Gegenstück zum Meisterdieb |

Gesamtwert aller Pässe: 1.453 R$. Später ist ein **Bundle-Pass** (z. B. „Alle Pässe“ für 999 R$) möglich.

## 3. Developer Products (beliebig oft kaufbar)

| Key | Name | Preis | Wirkung | Wo er angeboten wird |
|---|---|---|---|---|
| `StarterPack` | Starter-Paket | **49 R$** | Gold-Turbo-Tortellino (Epic, 300 $/s) + 25K Cash + 30 Min 2x | Popup nach 2,5 min für Spieler, die es noch nicht haben; ganz oben im Shop |
| `Boost2x` | 2x Cash (30 Min) | **49 R$** | Einkommen ×2 für 30 min, stapelbar, auch zusätzlich zum Pass | HUD-Button rechts, Shop |
| `CashSmall` | Cash-Beutel | **25 R$** | 5 Minuten Einkommen (min. 1K) | Toast „Dir fehlen $X“ beim Kaufversuch |
| `CashMedium` | Cash-Koffer | **79 R$** | 20 Minuten Einkommen (min. 5K) | dto. (passendes Paket wird automatisch gewählt) |
| `CashLarge` | Cash-Tresor | **199 R$** | 60 Minuten Einkommen (min. 25K) | Shop, Rebirth-Menü |
| `CashMega` | Cash-Berg | **499 R$** | 3 Stunden Einkommen (min. 100K) | Shop („BESTER WERT“) |
| `LuckySpawn` | Lucky Spawn | **99 R$** | 10 min bessere Chancen für den ganzen Server | Shop; jeder Kauf wird serverweit angesagt |
| `MythicDrop` | Mythic-Drop | **249 R$** | Sofort ein Mythic auf dem Band, 12 s reserviert | Shop (mit Chancen-Anzeige) |
| `LockExtend` | Schloss +5 Min | **29 R$** | Basis 5 Minuten extra gesichert | HUD, Toast „Schloss offen!“, Toast „Dir wurde etwas gestohlen“ |
| `OfflineTriple` | Offline-Cash x3 | **25 R$** | Verdreifacht das letzte Offline-Einkommen | Popup „Willkommen zurück“ |

**Warum diese Preisstruktur funktioniert:**
- **Einstieg für 25–49 R$:** Der erste Kauf ist die größte Hürde. Danach kaufen Spieler deutlich häufiger erneut.
- **Cash-Pakete skalieren mit dem Einkommen:** In jeder Spielphase bleiben sie gleich wertvoll (5 Minuten Einkommen kurz vor einem Rebirth sind viel Geld).
- **Ankerpreis 499 R$:** Neben dem „Cash-Berg“ wirken 79 und 199 günstig.
- **Lucky Spawn nützt allen:** Andere sehen die Ansage „X hat Lucky Spawn aktiviert!“. Das ist Social Proof, und der Käufer wird gefeiert.
- **Emotionale Momente:** Angebote erscheinen genau dann, wenn sie gebraucht werden: Geld fehlt, die Basis ist voll, das Schloss ist offen, man wurde bestohlen, man kommt zurück.

## 4. Wann und wo Angebote erscheinen

| Moment | Was der Spieler sieht |
|---|---|
| Will eine Figur kaufen, hat zu wenig Cash | Toast „Dir fehlen $X“ + Button mit dem kleinsten Cash-Paket, das reicht |
| Basis voll | Toast + Button „+5 Basis-Slots“ |
| Schloss läuft ab | Toast „Dein Schloss ist offen!“ + „Schloss +5 Min“ |
| Wurde bestohlen | Toast + „Schloss +5 Min“ |
| Kommt nach Pause zurück | Popup „Willkommen zurück“ + „3x für 25 R$“ |
| 2,5 Minuten im Spiel | Popup Starter-Paket (einmal pro Sitzung, bis es gekauft ist) |
| Gesperrte Slots 16–20 in der Basis | ProximityPrompt „Slots holen“ (nur für den Besitzer) |
| Goldener Premium-Slot | ProximityPrompt „Premium holen“ (Roblox-Premium-Kauf) |
| Rebirth-Menü | Button „Schneller mit Cash-Paketen“ |
| HUD | grünes **+** neben dem Cash, Buttons Boost und Schloss |
| Jeder Kauf eines Passes | Ansage an den ganzen Server + Konfetti |

## 5. Roblox Premium (Premium Payouts)

Roblox zahlt Entwicklern Robux dafür, wie viel Zeit Premium-Mitglieder im Spiel verbringen. Deshalb:
- **Premium-Vorteile:** +10 % Cash und ein exklusiver **goldener Premium-Slot (Slot 21)**.
- Nicht-Premium-Spieler sehen den goldenen Slot mit dem Schild „👑 Premium“. Ein Prompt öffnet den offiziellen Roblox-Premium-Kauf.
- Je länger Spieler bleiben (Retention, Phase 5), desto mehr Premium Payouts gibt es.

## 6. Feinschliff nach dem Launch

- Im Creator Hub die **Analytics → Monetization** beobachten: Conversion (Zahler / aktive Spieler), ARPPU, Top-Produkte.
- Funktioniert ein Produkt schlecht: zuerst die Platzierung ändern, dann den Preis.
- Wenn im Creator Hub verfügbar, die **Preis-Optimierung für Developer Products** testen, die automatisch den besten Preis ermittelt.
- Saisonale Angebote (Halloween-Figur, Weihnachts-Paket) als neue Developer Products mit begrenzter Zeit (Phase 5, Events).
