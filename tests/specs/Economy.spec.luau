--!nocheck
return function(Test, Env)
	local describe, it, expect = Test.describe, Test.it, Test.expect
	local env = Env.new()
	local Economy = env.require(env.shared.Economy)
	local Species = env.require(env.shared.Species)
	local Mutations = env.require(env.shared.Mutations)
	local Config = env.require(env.shared.Config)
	local Rng = env.require(env.shared.Rng)

	describe("catalog", function()
		it("has ten shop tiers in order with increasing price, time and value", function()
			expect(Species.MaxTier).toBe(10)
			for tier = 2, Species.MaxTier do
				local prev, cur = Species.byTier[tier - 1], Species.byTier[tier]
				expect(cur.price).toBeGreaterThan(prev.price)
				expect(cur.growTime).toBeGreaterThan(prev.growTime)
				expect(cur.value).toBeGreaterThan(prev.value)
			end
		end)

		it("every shop seed is profitable and higher tiers earn more per second", function()
			local lastRate = 0
			for _, species in Species.shopOrder do
				expect(species.value).toBeGreaterThan(species.price * 2)
				local rate = (species.value - species.price) / species.growTime
				expect(rate).toBeGreaterThan(lastRate)
				lastRate = rate
			end
		end)

		it("stock chances are valid probabilities", function()
			for _, species in Species.shopOrder do
				expect(species.stockChance).toBeBetween(0, 1)
				expect(species.stockMax >= species.stockMin).toBeTruthy()
			end
		end)
	end)

	describe("niceRound", function()
		it("keeps two significant digits", function()
			expect(Economy.niceRound(1641)).toBe(1600)
			expect(Economy.niceRound(1650)).toBe(1700)
			expect(Economy.niceRound(99.4)).toBe(99)
			expect(Economy.niceRound(123456)).toBe(120000)
		end)
	end)

	describe("tiles", function()
		it("first purchasable tile costs 100 and cost increases", function()
			local first = Config.Plots.StartingTiles + 1
			expect(Economy.tileCost(first)).toBe(100)
			expect(Economy.tileCost(first - 1)).toBe(0)
			for i = first + 1, Config.Plots.FreeTileLimit do
				expect(Economy.tileCost(i)).toBeGreaterThan(Economy.tileCost(i - 1))
			end
		end)

		it("pass row is only usable with Big Garden", function()
			expect(Economy.isTileUsable(25, 24, false)).toBeFalsy()
			expect(Economy.isTileUsable(25, 24, true)).toBeTruthy()
			expect(Economy.isTileUsable(30, 6, true)).toBeTruthy()
			expect(Economy.isTileUsable(31, 24, true)).toBeFalsy()
			expect(Economy.isTileUsable(7, 6, true)).toBeFalsy()
			expect(Economy.isTileUsable(6, 6, false)).toBeTruthy()
			expect(Economy.isTileUsable(0, 6, false)).toBeFalsy()
			expect(Economy.isTileUsable(2.5, 6, false)).toBeFalsy()
		end)

		it("total tiles counts pass row", function()
			expect(Economy.totalTiles(6, false)).toBe(6)
			expect(Economy.totalTiles(6, true)).toBe(12)
			expect(Economy.totalTiles(99, true)).toBe(30)
		end)

		it("rebirth bonus tiles are capped", function()
			expect(Economy.startingTiles(0)).toBe(6)
			expect(Economy.startingTiles(2)).toBe(8)
			expect(Economy.startingTiles(50)).toBe(12)
		end)
	end)

	describe("values", function()
		it("multiplies base, weight and mutations", function()
			local slime = { s = "goo", w = 2, m = { "golden", "frozen" } }
			expect(Economy.slimeValue(slime, 1)).toBe(24 * 2 * 6 * 3)
			expect(Economy.slimeValue(slime, 1.5)).toBe(math.floor(24 * 2 * 6 * 3 * 1.5))
		end)

		it("uses the base override for exclusive slimes", function()
			expect(Economy.slimeValue({ s = "prism", w = 1, m = {}, b = 5000 }, 1)).toBe(5000)
		end)

		it("ignores unknown mutation ids", function()
			expect(Economy.mutationMultiplier({ "nope" })).toBe(1)
		end)

		it("coin packs and prism scale with best tier", function()
			expect(Economy.coinPackAmount("coins_small", 1)).toBe(240)
			expect(Economy.coinPackAmount("coins_huge", 9)).toBe(3_600_000_000)
			expect(Economy.prismBaseValue(1)).toBe(190)
			expect(Economy.prismBaseValue(5)).toBe(140000)
			expect(function()
				Economy.coinPackAmount("nope", 1)
			end).toThrow()
		end)

		it("coin packs give more coins per Robux at higher tiers", function()
			local Products = env.require(env.shared.Products)
			local last = 0
			for _, key in { "coins_small", "coins_medium", "coins_large", "coins_huge" } do
				local perRobux = Economy.coinPackAmount(key, 3) / Products.byKey[key].price
				expect(perRobux).toBeGreaterThan(last)
				last = perRobux
			end
		end)
	end)

	describe("rolls", function()
		it("weight distribution matches published odds", function()
			local rng = Rng.new(12345)
			local n = 200000
			local titanic, huge, big = 0, 0, 0
			for _ = 1, n do
				local w = Economy.rollWeight(rng)
				expect(w).toBeBetween(0.8, 6)
				local label = Economy.weightLabel(w)
				if label == "Titanic" then
					titanic += 1
				elseif label == "Huge" then
					huge += 1
				elseif label == "Big" then
					big += 1
				end
			end
			expect(titanic / n).toBeNear(0.005, 0.0015)
			expect(huge / n).toBeNear(0.04, 0.004)
			expect(big / n).toBeNear(0.2, 0.01)
		end)

		it("variant odds match catalog and luck doubles them", function()
			for _, luck in { 1, 2 } do
				local rng = Rng.new(99 + luck)
				local n = 400000
				local counts = {}
				for _ = 1, n do
					local id = Economy.rollVariant(rng, luck)
					if id then
						counts[id] = (counts[id] or 0) + 1
					end
				end
				for _, mutation in Mutations.variants do
					local observed = (counts[mutation.id] or 0) / n
					-- Each roll only happens if rarer variants missed, so the
					-- expected rate is slightly below the raw chance.
					expect(observed).toBeNear(mutation.chance * luck, mutation.chance * luck * 0.12 + 0.0005)
				end
			end
		end)

		it("weather tick chance compounds to the per-minute chance", function()
			local tick = Economy.weatherTickChance(0.25, 1, 10)
			local perMinute = 1 - (1 - tick) ^ 6
			expect(perMinute).toBeNear(0.25, 1e-9)
			expect(Economy.weatherTickChance(0.9, 4, 60)).toBeNear(0.95, 1e-9)
		end)
	end)

	describe("multipliers", function()
		local base =
			{ rebirths = 0, doubleCoins = false, vip = false, premium = false, friends = 0, inGroup = false }
		it("is 1 with no bonuses", function()
			expect(Economy.sellMultiplier(base)).toBe(1)
		end)
		it("stacks additive bonuses, then rebirth, then 2x", function()
			local all = table.clone(base)
			all.vip, all.premium, all.inGroup, all.friends = true, true, true, 10
			all.rebirths, all.doubleCoins = 2, true
			-- (1 + .15 + .1 + .1 + .3) * (1 + 1.0) * 2
			expect(Economy.sellMultiplier(all)).toBeNear(1.65 * 2 * 2)
		end)
		it("growth and luck caps", function()
			expect(Economy.growthRate(true, true, 1.5)).toBeNear(1.3 * 2 * 1.5)
			expect(Economy.luck(true, true)).toBe(4)
			expect(Economy.luck(false, false)).toBe(1)
		end)
	end)

	describe("rebirth", function()
		it("costs grow geometrically", function()
			expect(Economy.rebirthCost(0)).toBe(15_000_000)
			expect(Economy.rebirthCost(1)).toBe(60_000_000)
		end)
	end)
end
