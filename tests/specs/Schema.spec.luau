--!nocheck
return function(Test, Env)
	local describe, it, expect = Test.describe, Test.it, Test.expect
	local env = Env.new()
	local Schema = env.require(env.server.Data.Schema)
	local serde = require("@lune/serde")

	describe("Schema", function()
		it("defaults are JSON round-trippable", function()
			local defaults = Schema.defaults(1000)
			local decoded = serde.decode("json", serde.encode("json", defaults))
			local reconciled = Schema.reconcile(decoded, 1000)
			expect(reconciled.coins).toBe(defaults.coins)
			expect(reconciled.seeds.goo).toBe(3)
			expect(reconciled.unlockedTiles).toBe(6)
		end)

		it("reconciles nil and garbage into defaults", function()
			expect(Schema.reconcile(nil, 5).coins).toBe(30)
			expect(Schema.reconcile("bad", 5).coins).toBe(30)
			local fixed = Schema.reconcile(
				{ coins = 0 / 0, rebirths = -4, seeds = { goo = -1, berry = 2.7, [1] = 4 } },
				5
			)
			expect(fixed.coins).toBe(30)
			expect(fixed.rebirths).toBe(0)
			expect(fixed.seeds.goo).toBeNil()
			expect(fixed.seeds.berry).toBe(2)
		end)

		it("drops invalid slimes and plants and fixes next id", function()
			local data = Schema.reconcile({
				slimes = {
					{ id = 7, s = "goo", w = 1, m = { "golden", 5 } },
					{ id = 8, s = "notaspecies", w = 1, m = {} },
					{ id = 9, s = "goo", w = 0 / 0, m = {} },
				},
				nextSlimeId = 2,
				plants = {
					{ tile = 1, s = "goo", w = 1, e = 4 },
					{ tile = 1, s = "berry", w = 1, e = 4 },
					{ tile = 2, s = "nope", w = 1, e = 4 },
				},
			}, 5)
			expect(#data.slimes).toBe(1)
			expect(#data.slimes[1].m).toBe(1)
			expect(data.nextSlimeId).toBe(8)
			expect(#data.plants).toBe(1)
			expect(data.plants[1].r).toBe(false)
		end)

		it("keeps unknown keys for forward compatibility", function()
			expect(Schema.reconcile({ futureField = "x" }, 5).futureField).toBe("x")
		end)

		it("caps stored receipts", function()
			local receipts = {}
			for i = 1, 150 do
				receipts[i] = "r" .. i
			end
			local data = Schema.reconcile({ receipts = receipts }, 5)
			expect(#data.receipts).toBe(100)
			expect(data.receipts[1]).toBe("r51")
		end)

		it("deepCopy is independent", function()
			local a = { x = { y = 1 } }
			local b = Schema.deepCopy(a)
			b.x.y = 2
			expect(a.x.y).toBe(1)
		end)
	end)
end
