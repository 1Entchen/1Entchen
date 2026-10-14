# From Robux to Real Money: The Honest Version

Nothing here is a forecast. Revenue depends on traffic, retention and conversion that nobody can know before launch. Most Roblox experiences earn little or nothing. The scenarios below show the **math**, using clearly labelled assumptions.

## The pipeline

1. **Gross Robux spent by players.** This is the sticker price players pay for passes and products.
2. **Earned Robux (your share).** For game passes and developer products, Roblox keeps a marketplace fee and the creator receives about **70%** of the price. Check the current share in the Creator Dashboard.
3. **Minus Robux you spend.** Ads, sponsored experiences, Creator Store assets and group payouts to collaborators come out of your balance. **Earned Robux you spend are gone**, and Robux that were never earned (bought, gifted or transferred) don't count for DevEx at all.
4. **DevEx-eligible Earned Robux.** Per Roblox's [Developer Exchange documentation](https://create.roblox.com/docs/production/monetization/developer-exchange), at the time of writing:
   - Standard rate: **0.0038 USD per Earned Robux** (30,000 Earned Robux = $114).
   - A higher rate (0.0054) applies to certain Earned Robux from purchases by US players verified as 18+.
   - Robux earned before Sept 5, 2025 cash out first, at the legacy 0.0035 rate.
   - Requirements: at least 30,000 Earned Robux, age 13+, a verified email, a DevEx Portal account, a tax form (W-9 or W-8) on file and compliance with Roblox's Terms and Community Standards. Roblox decides what counts as Earned Robux.
5. **Cash received** is the DevEx payout minus anything your bank or payment provider charges, then **income tax** wherever you live. If you're under 18, a parent or guardian will need to be involved with tax forms and payouts.

Always re-check the official page before planning around these numbers. Rates and rules change.

## Example scenarios (assumptions, not predictions)

Formula: `Earned Robux per day ≈ DAU × payer rate × average Robux per paying player per day × 0.70`

| Scenario | DAU | Payer rate | Avg spend per payer per day | Gross R$/day | Earned R$/30 days | USD at 0.0038 (before tax) |
|---|---|---|---|---|---|---|
| A: small, healthy | 300 | 1.5% | 120 R$ | 540 | ~11,340 | ~$43 (below the DevEx minimum; payout after ~80 days) |
| B: modest hit | 3,000 | 2% | 150 R$ | 9,000 | ~189,000 | ~$718 |
| C: breakout | 30,000 | 2.5% | 180 R$ | 135,000 | ~2,835,000 | ~$10,770 |

For each to happen:
- **A** needs a steady trickle of organic players and a working tutorial.
- **B** needs D1 retention and session length good enough that Roblox's recommendation system keeps sending traffic, plus regular updates.
- **C** needs everything in B plus a trend moment (clips going viral, a big seasonal update) *and* strong live operations to keep players. It's rare.

Engagement-based payouts (Roblox's creator rewards and Premium engagement programs) can add revenue on top, based on time Premium or eligible users spend in your experience. Check the current program in the Creator Dashboard. Don't count on it before you see real numbers.

## Protecting the revenue

- Don't spend Earned Robux on ads before your funnel is proven (see LAUNCH.md). Ad Robux don't come back if players don't stay.
- Keep monetization fair. Player trust, transparent odds and no pressure tactics protect long-term revenue and keep you within Roblox policy, which matters for an audience that includes children.
- Track **revenue per play** against **cost per play** before scaling any paid acquisition.
