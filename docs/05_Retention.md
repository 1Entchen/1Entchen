# Phase 5 – Retention (Spielerbindung)

Alles hier ist bereits im Code eingebaut (`RewardService`, `EventService`, `AnnouncementService`).

## 1. Systeme im Überblick

| System | Funktionsweise | Ziel |
|---|---|---|
| **Tägliche Belohnung** | 7-Tage-Serie. Tag 3 und 6 bringen 2x-Boosts, **Tag 7 eine garantierte Epic-Figur**. Wer einen Tag verpasst, beginnt wieder bei Tag 1. VIP bekommt alles doppelt | D1/D7-Retention, täglicher Login |
| **Tages-Quests** | 3 zufällige Quests pro Tag aus 9 Typen (kaufen, stehlen, verteidigen, abschließen, spielen …). Belohnung skaliert mit dem Einkommen | Sitzungsziele, Abwechslung |
| **Spielzeit-Geschenke** | Geschenke nach 2, 5, 10, 15, 25, 40 und 60 min; das letzte ist ein 2x-Boost | Längere Sitzungen (wichtig für Premium Payouts) |
| **Offline-Einkommen** | 20 % für bis zu 2 h (VIP 40 % für 6 h), Popup beim Zurückkommen | Grund zurückzukommen |
| **Neuling-Schutz** | 5 Minuten unangreifbar | Neue Spieler werden nicht sofort frustriert |
| **Sammel-Index** | 30 Figuren × 4 Mutationen, Bonus bei 10/20/30 entdeckten Figuren (+5/10/15 %) | Langzeit-Ziel |
| **Rebirth** | Dauerhafter Multiplikator, mehr Slots, längeres Schloss | Langzeit-Progression |
| **Pity-System** | Nach 400 Spawns ohne Legendary kommt garantiert eine | Kein Frust durch Pech |

## 2. Zeitlich begrenzte Events

| Event | Wann | Effekt |
|---|---|---|
| Wochenend-Event | Samstag + Sonntag (UTC) | **2x Cash für alle** |
| Happy Hour | täglich 18–19 Uhr UTC (20–21 Uhr deutsche Sommerzeit) | **Lucky Spawn gratis** für alle |
| Sonder-Event (manuell) | jederzeit | Attribut `EventCashMult` an **Workspace** setzen |

**Sonder-Event starten:**
1. In Studio bei **Workspace** das Attribut `EventCashMult` anlegen (Typ Number, z. B. `3`).
2. Veröffentlichen.
3. Im Creator Hub **„Migrate to Latest Update“** ausführen, damit auch laufende Server das Event bekommen.

Zum Beenden das Attribut entfernen und die Schritte wiederholen.

Alle aktiven Events erscheinen oben rechts als Chip und werden beim Start serverweit angesagt.

## 3. Ansagen für seltene Funde

| Was | Wo |
|---|---|
| Legendary oder besser gekauft/gestohlen, oder Diamant-/Regenbogen-Mutation | Banner auf dem ganzen Server |
| Secret oder Regenbogen | Banner in **allen Servern** (MessagingService) |
| Mythic/Secret/Regenbogen erscheint auf dem Band | Banner „SCHNELL!“ auf dem Server |
| Rebirth, Pass-Käufe, Lucky Spawn | Banner auf dem Server |

Andere beim Finden seltener Figuren zu sehen, ist einer der stärksten Gründe weiterzuspielen.

## 4. Update-Plan (sehr wichtig für den Algorithmus)

Roblox empfiehlt Spiele, die regelmäßig aktualisiert werden und Spieler halten. Plan:

| Woche | Update |
|---|---|
| 1 | Launch, Bugfixes, Preise anhand der Analytics prüfen |
| 2 | +3 neue Figuren (1 Mythic, 1 Secret, 1 Legendary) |
| 3 | Neue Mutation (z. B. „Glitch“ ×20) und ein Wochenend-Event |
| 4 | Admin-Event „Secret-Regen“ (Lucky Spawn ×3 für 1 h) mit Ankündigung in der Gruppe |
| danach | Alle 1–2 Wochen 3–5 neue Figuren, saisonale Events (Halloween, Weihnachten) |

Neue Figuren: einfach in `Figures` am Ende der Liste ergänzen (fortlaufende Id). Die Spieler sehen sie sofort im Index als „???“, das macht neugierig.
