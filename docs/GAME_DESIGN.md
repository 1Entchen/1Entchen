# Slime Garden: Game Design

## Why this concept

These are the concepts I evaluated, scored on discovery, retention, monetization, solo feasibility and differentiation:

| Concept | Verdict |
|---|---|
| "Steal a ___" base-raid collector | The genre is hot but saturated. PvP theft frustrates younger players, and the genre leader actively sues imitators. Rejected. |
| Survival/horror (99 Nights-like) | Strong breakout genre, but it needs monster AI, animation and authored assets to feel good. Too risky to polish solo. |
| Classic tycoon | Proven, but it needs lots of modelled content and is crowded. |
| Anime battler | Needs combat feel, VFX and balance work far beyond a solo first release. |
| **Real-time growing + collection (Slime Garden)** | Grow a Garden showed that "plant, wait, harvest, mutate, come back tomorrow" scales enormously and is understood instantly on mobile. Slimes give it a distinct, cute, thumbnail-friendly identity that can be built **entirely from code** (no asset pipeline), and mutations and sizes create shareable moments. **Selected.** |

The differentiation, while keeping the proven loop:
- **Slimes are the crop.** They visibly grow from tiny to huge, bounce when ripe, and carry visible mutations (gold, rainbow, frozen, starstruck sparkles). The garden doubles as a display case others walk past.
- **Size rolls happen at planting**, so a Titanic slime is visibly huge while it grows. Anticipation builds before the payoff.
- **Weather mutations reward timing.** Ripe slimes left in the garden during weather can gain stacking multipliers. The decision is "harvest now or wait for Starfall?"
- **Summoned weather is a social purchase.** One player buys Starfall and *everyone in the server* benefits, with a public thank-you. It's monetization that makes other players happy.
- **Fully transparent odds.** The Slimepedia has an Odds tab listing every random roll and the player's personal luck-adjusted chances.

Commercial potential in one sentence: it's a proven retention loop (real-time growth, offline progress, restock timers, daily streaks) with a unique visual hook and fair monetization, delivered as a complete, polished, assetless codebase that is cheap to extend with new species, weathers and events.

## Core loop (the first 10 seconds and the first session)

1. Spawn **in your own garden** holding 3 Goo Seeds, with a glowing tile, an arrow and a hint: "Tap the glowing soil".
2. Tap: the slime appears and grows over **12 seconds**.
3. Tap the ripe, bouncing slime to harvest it. A floating "+1 Goo Slime" appears, along with a sound and the "📖 New species!" bonus.
4. A beam guides you to the **Sell Stand**: coins burst into the counter.
5. The beam guides you to the **Seed Shop**: buy better seeds. Tutorial complete, with a free Growth Potion.

Pacing from the simulator (`scripts/balance.luau`, continuous free play, no mutations, median of 11 seeds): Berry ~2 min, Ember ~4 min, Frost (Rare) ~10 min, Toxic ~25 min, Crystal (Epic) ~50 min, Shadow ~2 h, King (Legendary) ~4–5 h. Cosmic requires Rebirth 1 (15M coins). Offline growth, weather mutations, daily rewards and quests all speed this up.

## Systems

| System | Purpose |
|---|---|
| Garden (30 tiles: 6 start, 18 coin unlocks, 6 via pass) | Core loop and visible progress |
| Real-time + offline growth | Reason to come back ("your King Slime is ready") |
| Size rolls (Normal → Titanic) | Excitement on every plant |
| Variants (Shiny ×2, Golden ×6, Rainbow ×15) | Rare moments rolled once at ripening |
| Weather (Goo Rain, Golden Hour, Snowfall, Starfall) every 9–13 min | Session reasons, server-wide moments, stacking mutations |
| Seed Shop restock every 5 min (per-player stock, published odds) | Short-term check-back loop |
| Slimepedia (11 species × 7 mutations) | Long-term collection goals and discovery bonuses |
| Daily streak (7 days) + 3 daily quests | Daily habit, scaled rewards, free potion samples |
| Rebirth (+50% coins each, +1 starting tile, unlocks Cosmic) | Long-term replay |
| Friends (+10% each, max 3), Premium (+10%), group (+10%) | Social and platform-aligned bonuses that never punish solo play |
| Global "Top Gardeners" board + leaderstats | Competition and status |
| Server announcements for rare harvests (in chat + banner) | Shareable moments and social proof |
| Auto-harvest, potions, instant grow | Convenience; all also reachable free (potions from daily rewards and quests) |

## Economy

Each species sells for about 2.4× its seed price, and profit per tile-second grows about 2.5× per tier. Rewards and coin packs scale with the player's best tier (`Economy.unit`), so they stay meaningful at every stage. Coin sinks: seeds, tile unlocks (100 → ~1.4M, ×1.75 each) and rebirth (15M × 4ⁿ).

## Monetization design

Principles: every purchase has a clear benefit, nothing random is sold for Robux, the game is fully enjoyable free, and there's no fake scarcity or countdown pressure.

| Tier | Item | Price | Why it converts |
|---|---|---|---|
| Entry | Starter Pack (pass, one-time) | 49 | Huge early value (Ember and Frost seeds, coins, potions); the first purchase is the hardest |
| Entry | Instant Grow | 29 | Impulse skip; saved for later if nothing is growing |
| Entry | Growth / Luck Potion (15 min) | 39 | Players already got free potions from daily rewards, so they know the value |
| Entry | Coin pouch | 25 | Smallest pack |
| Mid | Prism Seed | 99 | Exclusive species worth 8× your best slime (scales with progress) |
| Mid | Big Garden (+6 tiles) | 149 | Permanent, visible capacity |
| Mid | Sell Anywhere | 149 | Convenience |
| Mid | VIP | 199 | +15% coins, +50 backpack, chat tag (status) |
| Mid | Summon Goo Rain | 79 | Social purchase that helps the whole server |
| Premium | Lucky Gardener (×2 mutation odds) | 249 | Odds are disclosed |
| Premium | Fast Grow (+30%, also offline) | 299 | Permanent speed |
| Premium | Auto Harvest | 349 | Convenience for long sessions |
| Premium | 2x Coins | 399 | The genre's classic best-seller |
| Premium | Summon Starfall | 199 | Big social moment |
| Whale | Coin packs 75 / 199 / 449 | | Better rate per Robux at higher tiers (shown in the store) |

Price rationale: these are intended starting points in the band commonly seen in simulator-style games: low-hundreds Robux for permanent passes and double-digit Robux for consumables. They are not proven optimal. Once you have traffic, use **Creator Dashboard → Monetization** (including price optimization for developer products where available) and A/B test.

Policy-sensitive choices:
- No paid random items. Robux buys deterministic things: a specific seed, a timed boost, a permanent pass or coins. Growth outcomes are gameplay rolls with odds published in-game.
- Weather purchases are described honestly. If weather is already active, the summoned event is queued and the buyer is told so.
- Premium perks follow Roblox's model: a small bonus for subscribers. The game never sells or promises Robux.
- Server-side receipts only. No reward is granted on the client's word.
