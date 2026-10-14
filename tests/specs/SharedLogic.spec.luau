--!nocheck
return function(Test, Env)
	local describe, it, expect = Test.describe, Test.it, Test.expect
	local env = Env.new()
	local Format = env.require(env.shared.Format)
	local Stock = env.require(env.shared.Stock)
	local Quests = env.require(env.shared.Quests)
	local DailyRewards = env.require(env.shared.DailyRewards)
	local Rng = env.require(env.shared.Rng)
	local Species = env.require(env.shared.Species)
	local Weathers = env.require(env.shared.Weathers)
	local Products = env.require(env.shared.Products)

	describe("Format", function()
		it("short", function()
			expect(Format.short(0)).toBe("0")
			expect(Format.short(999)).toBe("999")
			expect(Format.short(1000)).toBe("1K")
			expect(Format.short(1234)).toBe("1.23K")
			expect(Format.short(12345)).toBe("12.3K")
			expect(Format.short(120000)).toBe("120K")
			expect(Format.short(100000)).toBe("100K")
			expect(Format.short(1500000)).toBe("1.5M")
			expect(Format.short(2e9)).toBe("2B")
			expect(Format.short(-1500)).toBe("-1.5K")
			expect(Format.short(0 / 0)).toBe("0")
		end)
		it("commas", function()
			expect(Format.commas(1234567)).toBe("1,234,567")
			expect(Format.commas(100)).toBe("100")
			expect(Format.commas(100000)).toBe("100,000")
		end)
		it("clock and duration", function()
			expect(Format.clock(9)).toBe("0:09")
			expect(Format.clock(75)).toBe("1:15")
			expect(Format.clock(3725)).toBe("1:02:05")
			expect(Format.duration(45)).toBe("45s")
			expect(Format.duration(125)).toBe("2m 5s")
			expect(Format.duration(7200)).toBe("2h")
		end)
		it("percent and multiplier", function()
			expect(Format.percent(0.25)).toBe("25%")
			expect(Format.percent(0.05)).toBe("5%")
			expect(Format.percent(0.012)).toBe("1.2%")
			expect(Format.percent(0.0025)).toBe("0.25%")
			expect(Format.percent(0.015)).toBe("1.5%")
			expect(Format.multiplier(2)).toBe("x2")
			expect(Format.multiplier(2.5)).toBe("x2.5")
			expect(Format.multiplier(1.15)).toBe("x1.15")
		end)
	end)

	describe("Rng", function()
		it("is deterministic and in range", function()
			local a, b = Rng.new(42), Rng.new(42)
			for _ = 1, 1000 do
				local x = a()
				expect(x).toBe(b())
				expect(x >= 0 and x < 1).toBeTruthy()
			end
		end)
		it("is roughly uniform", function()
			local r = Rng.new(7)
			local sum = 0
			for _ = 1, 100000 do
				sum += r()
			end
			expect(sum / 100000).toBeNear(0.5, 0.01)
		end)
	end)

	describe("Stock", function()
		it("always stocks common seeds within range", function()
			local rng = Rng.new(5)
			for _ = 1, 500 do
				local stock = Stock.roll(rng)
				expect(stock.goo).toBeBetween(10, 20)
				expect(stock.bubble).toBeBetween(6, 12)
				expect(stock.prism).toBeNil()
			end
		end)
		it("rare seeds appear at their published rate", function()
			local rng = Rng.new(77)
			local n, crystal = 20000, 0
			for _ = 1, n do
				if Stock.roll(rng).crystal then
					crystal += 1
				end
			end
			expect(crystal / n).toBeNear(Species.byId.crystal.stockChance, 0.01)
		end)
	end)

	describe("Quests", function()
		it("generates three distinct, deterministic quests", function()
			local a = Quests.generate(20000, 123, 3)
			local b = Quests.generate(20000, 123, 3)
			expect(#a).toBe(3)
			expect(a).toEqual(b)
			local seen = {}
			for _, quest in a do
				expect(seen[quest.kind]).toBeNil()
				seen[quest.kind] = true
				expect(quest.target).toBeGreaterThan(0)
				expect(quest.rewardCoins).toBeGreaterThan(0)
				expect(Quests.byKind[quest.kind]).toBeTruthy()
			end
			expect(a[3].rewardItem).toBeTruthy()
		end)
		it("differs between days and never offers rare quests to beginners", function()
			local differs = false
			for day = 1, 60 do
				local quests = Quests.generate(day, 1, 1)
				for _, quest in quests do
					expect(quest.kind ~= "rare").toBeTruthy()
				end
				if not differs and Quests.generate(day + 1, 1, 1)[1].kind ~= quests[1].kind then
					differs = true
				end
			end
			expect(differs).toBeTruthy()
		end)
		it("describes quests", function()
			local text = Quests.describe({ kind = "harvest", target = 15 }, tostring)
			expect(text).toBe("Harvest 15 slimes")
		end)
	end)

	describe("DailyRewards", function()
		it("continues a streak on consecutive days", function()
			local s = DailyRewards.status(99, 3, 100)
			expect(s.canClaim).toBeTruthy()
			expect(s.nextStreak).toBe(4)
			expect(s.cycleDay).toBe(4)
		end)
		it("resets after a missed day and blocks double claims", function()
			expect(DailyRewards.status(97, 3, 100).nextStreak).toBe(1)
			expect(DailyRewards.status(100, 3, 100).canClaim).toBeFalsy()
			expect(DailyRewards.status(-1, 0, 100).cycleDay).toBe(1)
		end)
		it("cycles after day 7", function()
			expect(DailyRewards.status(99, 7, 100).cycleDay).toBe(1)
			expect(DailyRewards.status(99, 13, 100).cycleDay).toBe(7)
		end)
		it("resolves every reward slot", function()
			for day = 1, 7 do
				for _, tier in { 1, 5, 10 } do
					local reward = DailyRewards.resolve(day, tier)
					expect(#reward.label > 0).toBeTruthy()
					for id in reward.seeds do
						expect(Species.byId[id]).toBeTruthy()
						expect(id ~= "cosmic").toBeTruthy()
					end
				end
			end
			expect(DailyRewards.resolve(7, 1).seeds.prism).toBe(1)
		end)
	end)

	describe("Weathers", function()
		it("pick covers the full range", function()
			expect(Weathers.pick(0)).toBe("goorain")
			expect(Weathers.pick(0.999999)).toBe("starfall")
		end)
	end)

	describe("Products", function()
		it("every product has a unique key and positive intended price", function()
			for _, product in Products.list do
				expect(product.price).toBeGreaterThan(0)
				expect(Products.byKey[product.key]).toBe(product)
			end
		end)
		it("every coin pack key has units", function()
			for _, product in Products.list do
				if product.category == "Coins" then
					expect(Products.CoinPackUnits[product.key]).toBeTruthy()
				end
			end
		end)
	end)
end
