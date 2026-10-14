# Manual Test Plan (Roblox Studio and Devices)

Automated checks (`scripts/check.sh`) cover formatting, lint, strict type-checking against the Roblox API, economy and odds math, data safety (session locking, failed loads and saves, lost locks), receipt idempotency, and end-to-end **server** simulations of the gameplay loop. The following can **only** be verified in Roblox itself, because they involve rendering, physics, input devices or Roblox services.

Use **Test → Start** with 2 players for social checks, and **Test → Device** emulation for phone and tablet layouts. Then test on a real phone through the Roblox app after publishing.

## First session (most important)
- [ ] Spawn: you appear on your own plot, facing the tiles. The sign shows your name and avatar.
- [ ] Hint bubble, green beam and bouncing arrow point at the glowing first tile.
- [ ] **Tap or click a tile to plant**: the slime appears small and grows smoothly. The timer label counts down.
- [ ] On a phone, check that taps hit the tile you touched. If taps land too high or low, the screen-to-ray conversion in `GardenView.onWorldTap` needs `ViewportPointToRay` instead of `ScreenPointToRay`.
- [ ] Ripe slime bounces; the "✋ value" label and the **Harvest** proximity prompt appear; tapping the slime harvests it.
- [ ] Beam leads to the Sell Stand; "Sell All" prompt sells; coins fly to the counter.
- [ ] Beam leads to the Seed Shop; the prompt opens the shop; buying completes the tutorial (toast plus Growth Potion).

## World and visuals
- [ ] You can walk onto plots and the hub without jumping (step heights are ≤ 0.4 studs).
- [ ] Shopkeeper slimes peek over the counters and face customers.
- [ ] Locked-tile labels ("🔒 cost", "⭐ Big Garden") are readable from the plot entrance. If they're upside down, remove `label.Rotation = 180` in `Plots.setTileLabel`.
- [ ] Weather: Goo Rain, Golden Hour, Snowfall and Starfall show particles and a tint, and lighting returns to normal afterwards. Use the QA panel's "Starfall" to trigger one.
- [ ] Mutated slimes look right (Golden foil, Rainbow cycling colours, Frozen ice, sparkles). Cosmic and Prism stars orbit smoothly.
- [ ] Performance: 6 full gardens (use two or more test players with the QA panel). Check the frame rate on a low-end phone.

## UI (phone landscape, tablet, 1080p PC)
- [ ] Coins, restock timer, weather pill and boost chips don't overlap the Roblox top bar.
- [ ] Left menu (2×3) and right action buttons don't overlap the thumbstick or jump button.
- [ ] Seed bar scrolls; selecting a seed highlights it; "Plant All" fills empty tiles.
- [ ] Every window (Shop, Backpack, Store, Slimepedia with Odds tab, Daily, Quests, Rebirth) fits on screen and closes with X or by tapping outside.
- [ ] Toasts, the announcement banner and the tutorial bubble don't hide each other badly.

## Purchases (after creating products)
- [ ] Store shows live prices from Roblox.
- [ ] Buy a pass: the benefit applies immediately (e.g. Big Garden tiles turn into soil) and the card shows "Owned".
- [ ] Buy a developer product: the reward arrives once. Rejoin and confirm it isn't granted again.
- [ ] Starter Pack grants once, even after rejoining.
- [ ] Summon Starfall while another weather is active: you're told it's queued, and it starts afterwards for everyone.

## Data
- [ ] With API access on: plant something, leave, rejoin. The plant is still there and has grown during the time away.
- [ ] Join a second server quickly after leaving the first. Your data loads; if the previous server is still saving, you're asked to rejoin rather than losing progress.
- [ ] Shut down a server (Creator Dashboard → shut down) while playing, then rejoin. Progress is saved.

## Social
- [ ] Two friends in one server: both see "🤝 +10% coins".
- [ ] Rare harvest announcements appear for everyone, in the banner and in chat.
- [ ] VIP owners show a gold [VIP] chat tag.
- [ ] The global leaderboard fills in after a few minutes (needs published DataStores).
