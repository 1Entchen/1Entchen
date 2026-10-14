# Slime Garden: Launch Package

## Name and listing

**Title:** `Slime Garden 🌱`. After the first content update, switch to the bracket convention players scan for, e.g. `🎃 Slime Garden [HALLOWEEN]`. Only claim an update in the title when it's real.

**Description** (accurate, front-loaded for the first two lines that show in search):

> 🌱 Plant slime seeds, watch them GROW (even while you're offline!) and harvest giant, golden and RAINBOW slimes!
>
> 🌧️ Weather events mutate your slimes: Drenched, Sunkissed, Frozen and the legendary Starstruck x8!
> 🛒 The Seed Shop restocks every 5 minutes. Catch the rare seeds!
> 📖 Discover all 11 species and 70+ variants in the Slimepedia.
> ⭐ Rebirth for permanent coin bonuses and Cosmic Slimes.
> 🤝 Play with friends for up to +30% coins!
>
> All odds are listed in-game (Slimepedia → Odds).

**Genre / settings:** Simulation. Enable phones, tablets, desktop and console (UI is mobile-first; consoles should be checked first, see STUDIO_TESTING.md). Max players: 6.

**Search terms the description accurately covers:** slime, garden, grow, farming, simulator, idle, collect, mutations, rebirth, weather. Don't add terms the game doesn't deliver, such as pets or trading. Misleading metadata hurts conversion and can violate Roblox rules.

## Thumbnail and icon concepts

Stage these in Studio using the Studio QA panel (+coins and +rare seeds, then plant and ripen) and take screenshots at 1920×1080.

- **Icon (512×512):** one big, glossy green Goo Slime face filling the frame, with sparkles, on a saturated pink-to-purple gradient. No text. Readable at 50 px.
- **Thumbnail 1 (hero):** a Titanic Rainbow King Slime in the foreground, bouncing, with your avatar small beside it for scale. Behind it, a garden full of ripe slimes. Text: "GROW RAINBOW SLIMES!"
- **Thumbnail 2 (weather):** Starfall over a garden of purple Starstruck slimes, with "x8 STARFALL!".
- **Thumbnail 3 (progression):** a row of slimes growing from tiny to huge, with "OFFLINE GROWTH".
- Rotate thumbnails and compare click-through rate in Creator Dashboard analytics. Change one variable at a time.

## Screenshot and trailer plan (30 s, vertical cut for Shorts/TikTok too)

1. 0–3 s: tap the soil and a slime pops up. Text: "Plant a slime…"
2. 3–8 s: time-lapse growth to Titanic size. "…watch it grow…"
3. 8–14 s: Starfall hits and slimes turn Starstruck. "WEATHER MUTATIONS"
4. 14–20 s: harvest a Rainbow, the server announcement fires, coins fly to the counter.
5. 20–26 s: friends' gardens side by side, then a rebirth celebration.
6. 26–30 s: logo and "Play free on Roblox".

## Launch checklist

- [ ] Create all passes/products, paste ids into `src/shared/Products.luau`, rebuild (`scripts/build.sh`) or sync with Rojo
- [ ] Max Players = 6; enable Studio API access; publish
- [ ] Complete the Maturity & Compliance questionnaire
- [ ] Run every item in `STUDIO_TESTING.md` on a real phone (Roblox app) and a PC
- [ ] Test-purchase one pass and one developer product in the live game. Check the reward appears and the receipt isn't granted twice after rejoining.
- [ ] Upload icon and three thumbnails; set description and genre
- [ ] Optional: create a Roblox group (set `Config.GroupId`) and badges (`Config.Badges`)
- [ ] Enable paid **Private Servers** (Game Settings → Monetization). Gardens are personal, so private servers suit friend groups.
- [ ] Soft launch: share with 10–30 friends or community members first and watch the onboarding funnel
- [ ] Only then: small sponsored ad tests (see Acquisition)

## Measuring traction (Creator Dashboard → Analytics)

Events already instrumented: the onboarding funnel (6 steps), economy sources and sinks (coins), progression (tiles, rebirth), purchases, discoveries and daily claims.

| Metric | Where | First target (rule of thumb, not a guarantee) | If below |
|---|---|---|---|
| Tutorial completion | Funnels → Onboarding | ≥ 70% reach "Complete" | Shorten steps, make the arrow and beam more obvious, check mobile tap accuracy |
| Avg session length | Engagement | ≥ 12 min | Faster early tiers, earlier first weather event, more restock excitement |
| D1 retention | Retention | ≥ 15% | Strengthen offline growth hooks (plant something long before leaving), daily rewards |
| D7 retention | Retention | ≥ 4% | More long-term goals: species, events, collection rewards |
| Payer conversion | Monetization | ≥ 1–2% of DAU | Starter pack visibility, value of 49 R$ entry, potion sampling |
| Avg revenue per DAU | Monetization | Compare to the benchmarks shown in your dashboard | Price testing, bundle tuning |

Use the **benchmark percentiles** Roblox shows in the dashboard (compared with similar experiences) instead of fixed numbers. They reflect current platform conditions.

Decision rules:
- **Fix onboarding before anything else.** Every later metric depends on it.
- **Don't buy ads until D1 retention and session length are stable** for a week. Paid traffic into a leaky funnel burns Robux.
- **Change one thing per release** and compare a 3–7 day window before and after.
- If retention is good but conversion is low, adjust monetization (offers, prices, placement). If conversion is good but retention is low, add content and pacing, not more offers.

## Acquisition (organic first)

1. **Shareable moments.** Rare-harvest announcements and Starfall are made to be clipped. Post short vertical clips (TikTok, YouTube Shorts) of Titanic and Rainbow pulls.
2. **Friends bonus** (+10% per friend, up to +30%) gives a reason to invite. Mention it in the description.
3. **Updates are discovery events.** Ship a visible update every 1–2 weeks and update the title tag.
4. **Community.** A Roblox group, plus Discord for update notes and feedback (moderate it; follow Roblox rules for off-platform links).
5. **Paid (later).** Small daily-budget sponsored ad tests in Ads Manager with two or three creatives. Compare cost per play with your measured revenue per play. Scale only when revenue per play is reliably above cost per play.

## First 30 days

| Week | Focus | Deliverables |
|---|---|---|
| 1 | Stability and onboarding | Fix bugs from soft launch, tune the tutorial from funnel data, check mobile layout on several devices |
| 2 | **Halloween update** (timely: launch before Oct 31) | Pumpkin Slime and Ghost Slime species, "Blood Moon" weather with a Haunted mutation, decorated hub. Use transparent event rules and dates, and announce in the title. |
| 3 | Retention | Experience Notifications opt-in ("your slime is ripe"), collection milestone rewards in the Slimepedia, 2 more quest types |
| 4 | Monetization depth | Garden themes (cosmetic plot skins: Candy, Lava, Galaxy) via pass and coins, then review prices against data |

## Next features by impact versus cost

| Feature | Impact | Cost | Notes |
|---|---|---|---|
| Seasonal event (Halloween, then Winter) | High | Low | New species and weather reuse existing systems (catalog entries) |
| Experience Notifications ("slime ready") | High | Low–Med | Strong D1/D7 lever; requires the opt-in prompt |
| Garden themes / cosmetics | Med–High | Med | Non-pay-to-win revenue and status |
| Collection milestone rewards | Med | Low | Long-term goals |
| Gifting slimes to friends | High | Med–High | Needs careful anti-dupe and anti-scam design; build on the existing session locks |
| Server "community goal" (e.g. harvest 10k slimes → free Starfall) | Med | Low | Social cohesion |
| Trading | High | High | Highest exploit and scam risk; do it last, with confirmation screens and logging |
