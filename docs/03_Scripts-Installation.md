# Phase 3 – Alle Scripts einbauen

## Weg A (empfohlen): fertige Datei öffnen
[`BrainrotBandits.rbxlx`](../BrainrotBandits.rbxlx) enthält **alle Scripts bereits am richtigen Ort**. Doppelklick → Studio öffnet das Spiel → **Play**. Beim ersten Start baut der Server die komplette Welt automatisch (Förderband, Basen, Schilder, Leaderboards, Klatsche, Licht).

Willst du die Welt auch im Editor sehen und dekorieren: einmal in der Command Bar `require(game.ServerStorage.SetupWorld)()` ausführen und speichern.

## Weg B: Scripts einzeln einfügen

Alle Scripts liegen fertig im Ordner [`src/`](../src). Jede Datei wird in Studio als eigenes Script-Objekt angelegt: **Name = Dateiname ohne Endung** (ohne `.server` / `.client`), Inhalt komplett hineinkopieren.

Voraussetzung: Phase 2 ist erledigt (`SetupWorld` wurde ausgeführt, die Ordner existieren).

## 1. Welche Datei wohin?

| Datei | Typ in Studio | Ort in Studio | Name |
|---|---|---|---|
| `ReplicatedStorage/Shared/Config.lua` | **ModuleScript** | ReplicatedStorage › Shared | `Config` |
| `ReplicatedStorage/Shared/Figures.lua` | **ModuleScript** | ReplicatedStorage › Shared | `Figures` |
| `ReplicatedStorage/Shared/Format.lua` | **ModuleScript** | ReplicatedStorage › Shared | `Format` |
| `ReplicatedStorage/Shared/FigureDesigns.lua` | **ModuleScript** | ReplicatedStorage › Shared | `FigureDesigns` |
| `ReplicatedStorage/Shared/FigureBuilder.lua` | **ModuleScript** | ReplicatedStorage › Shared | `FigureBuilder` |
| `ServerScriptService/ServerMain.server.lua` | **Script** | ServerScriptService | `ServerMain` |
| `ServerScriptService/Services/RateLimit.lua` | **ModuleScript** | ServerScriptService › Services | `RateLimit` |
| `ServerScriptService/Services/Net.lua` | **ModuleScript** | ServerScriptService › Services | `Net` |
| `ServerScriptService/Services/DataService.lua` | **ModuleScript** | ServerScriptService › Services | `DataService` |
| `ServerScriptService/Services/MonetizationService.lua` | **ModuleScript** | ServerScriptService › Services | `MonetizationService` |
| `ServerScriptService/Services/EventService.lua` | **ModuleScript** | ServerScriptService › Services | `EventService` |
| `ServerScriptService/Services/IncomeService.lua` | **ModuleScript** | ServerScriptService › Services | `IncomeService` |
| `ServerScriptService/Services/BaseService.lua` | **ModuleScript** | ServerScriptService › Services | `BaseService` |
| `ServerScriptService/Services/ConveyorService.lua` | **ModuleScript** | ServerScriptService › Services | `ConveyorService` |
| `ServerScriptService/Services/StealService.lua` | **ModuleScript** | ServerScriptService › Services | `StealService` |
| `ServerScriptService/Services/RebirthService.lua` | **ModuleScript** | ServerScriptService › Services | `RebirthService` |
| `ServerScriptService/Services/RewardService.lua` | **ModuleScript** | ServerScriptService › Services | `RewardService` |
| `ServerScriptService/Services/LeaderboardService.lua` | **ModuleScript** | ServerScriptService › Services | `LeaderboardService` |
| `ServerScriptService/Services/AnnouncementService.lua` | **ModuleScript** | ServerScriptService › Services | `AnnouncementService` |
| `ServerScriptService/Services/StateService.lua` | **ModuleScript** | ServerScriptService › Services | `StateService` |
| `StarterPlayerScripts/ClientMain.client.lua` | **LocalScript** | StarterPlayer › StarterPlayerScripts | `ClientMain` |
| `StarterPlayerScripts/ClientModules/UIKit.lua` | **ModuleScript** | StarterPlayer › StarterPlayerScripts › ClientModules | `UIKit` |
| `StarterPlayerScripts/ClientModules/Notify.lua` | **ModuleScript** | … › ClientModules | `Notify` |
| `StarterPlayerScripts/ClientModules/HUD.lua` | **ModuleScript** | … › ClientModules | `HUD` |
| `StarterPlayerScripts/ClientModules/Menus.lua` | **ModuleScript** | … › ClientModules | `Menus` |
| `StarterPlayerScripts/ClientModules/World.lua` | **ModuleScript** | … › ClientModules | `World` |
| `StarterPlayerScripts/ClientModules/Tutorial.lua` | **ModuleScript** | … › ClientModules | `Tutorial` |
| `ServerStorage/SetupWorld.lua` | **ModuleScript** | ServerStorage | `SetupWorld` |

So legst du ein Script an: Rechtsklick auf den Ordner → **Insert Object** → Typ wählen → umbenennen → Doppelklick → alles markieren (Strg+A) → einfügen.

> Schneller (optional): Mit dem Plugin **Rojo** lässt sich der ganze `src`-Ordner auf einmal synchronisieren. Die Ordnerstruktur ist bereits darauf ausgelegt.

## 2. Testen in Studio

1. **Play** drücken (F5).
2. Im **Output** müssen erscheinen: `✅ Brainrot Bandits Server gestartet` und `✅ Client bereit`.
3. Erwartet:
   - Du spawnst in deiner Basis. Das Schild zeigt „Basis von <Name>“ und „⬇ DEINE BASIS ⬇“.
   - Auf dem Band laufen alle 2,5 s Figuren mit Name, Seltenheit und Preis.
   - Zum Band laufen und **E** drücken (Mobile: antippen) kauft die Figur, sie läuft dann zu deinem Slot.
   - Oben steigt das Cash. Über das grüne **Cash-Pad** laufen sammelt es ein.
   - Buttons links: Shop, Basis, Rebirth, Täglich, Quests. Rechts: Schloss, Schloss-Verlängerung, Geschenk, Boost.
4. **Stehlen testen:** Test → Clients and Servers → **2 Players** → Start. Mit Spieler 2 in die Basis von Spieler 1 gehen (erst nach 5 Minuten Neuling-Schutz), **E halten**, dann mit der Figur in die eigene Basis laufen. Mit Spieler 1 die **Klatsche** ausrüsten (Taste 1) und klicken, um den Dieb zu stoppen.
5. **Mobile testen:** Test → Device Emulator → z. B. iPhone 14 / Galaxy S22 im Querformat.

Hinweis: In Studio ohne „API Services“ speichert das Spiel nur im Arbeitsspeicher (Meldung im Output). Für echtes Speichern muss das Spiel veröffentlicht und der Schalter aktiviert sein (siehe Phase 2).

## 3. Wie die Scripts zusammenarbeiten

```
ServerMain ─┬─ RateLimit       Anti-Spam pro Spieler/Aktion
            ├─ Net             Remotes + Aktions-Router (nur erlaubte Aktionen)
            ├─ DataService     Session-Lock, UpdateAsync, Auto-Save, BindToClose
            ├─ Monetization    Game Passes, ProcessReceipt (idempotent), Premium
            ├─ EventService    Wochenende 2x Cash, Happy Hour
            ├─ IncomeService   Cash/s, Cash-Pad, Offline-Einkommen, Multiplikatoren
            ├─ BaseService     Basen, Slots, Verkauf, Schloss (Server schiebt Fremde raus)
            ├─ Conveyor        Spawning (Seltenheit, Mutation, Pity, Luck), Kauf
            ├─ StealService    Stehlen, Klatsche, Neuling-Schutz, Speed-Hack-Erkennung
            ├─ Rebirth         Kosten, Bedingungen, Reset
            ├─ RewardService   Tägliche Belohnung, Quests, Spielzeit-Geschenke
            ├─ Leaderboard     globale Bestenlisten (OrderedDataStore)
            ├─ Announcement    Server- und serverübergreifende Ansagen
            └─ StateService    schickt UI-Zustand an den Client
Client: ClientMain → UIKit, Notify, HUD, Menus, World
```

## 4. Anti-Exploit: Was der Server prüft

| Aktion | Prüfungen auf dem Server |
|---|---|
| Kaufen | Figur existiert und ist unverkauft, Reservierung, Distanz ≤ 16, genug Cash, freier Slot, Rate-Limit |
| Verkaufen | Slot-Nummer ganzzahlig 1–21, Slot belegt, Figur wird nicht gerade gestohlen |
| Stehlen | Haltezeit wirklich abgewartet (Server misst selbst), Distanz, Cooldown, Schloss, Neuling-Schutz, freier Slot, nur eine Figur gleichzeitig |
| Tragen | Geschwindigkeitsprüfung alle 0,15 s: Teleport oder Speed-Hack → Diebstahl scheitert |
| Schloss | Nur der Besitzer. Fremde in der Zone werden 5× pro Sekunde rausgesetzt |
| Cash-Pad | Nur der Besitzer, Distanz-Check, Rate-Limit |
| Klatsche | Cooldown, Reichweite, Blickrichtung |
| Remotes | Nur registrierte Aktionen, Rate-Limit, Fehler werden abgefangen |
| Käufe | Doppelte PurchaseIds werden ignoriert, „granted“ erst nach erfolgreichem Speichern |

Der Client schickt nie Beträge, Preise oder Figuren-IDs, die der Server übernimmt. Er schickt nur Wünsche.

## 5. Häufige Fehlermeldungen

| Meldung im Output | Lösung |
|---|---|
| `ModuleScript fehlt: ServerScriptService/Services/X` | Modul `X` fehlt oder ist falsch benannt |
| `ServerStorage.BaseTemplate fehlt` | `SetupWorld` (Phase 2) ausführen |
| `Infinite yield possible on ... WaitForChild("Shared")` | Ordner `ReplicatedStorage/Shared` fehlt |
| `Kein DataStore-Zugriff: Test-Speicher (RAM) aktiv` | Nur ein Hinweis in Studio. Für echtes Speichern: veröffentlichen + API Services an |
| `Dieses Angebot ist noch nicht eingerichtet` (im Spiel) | ID in `Config` eintragen (Phase 4) |
| Figuren sind einfache bunte Platzhalter | `FigureDesigns` fehlt in ReplicatedStorage › Shared |

Hilft das nicht, schick mir den kompletten roten Text aus dem Output.
