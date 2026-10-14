--!nocheck
-- Receipt processing must grant exactly once and acknowledge only after the
-- grant is persisted.
return function(Test, Env)
	local describe, it, expect = Test.describe, Test.it, Test.expect
	local Mocks = require("../harness/Mocks")
	local roblox = require("@lune/roblox")

	local Granted = roblox.Enum.ProductPurchaseDecision.PurchaseGranted
	local NotYet = roblox.Enum.ProductPurchaseDecision.NotProcessedYet

	local function setup()
		local env = Mocks.server({ jobId = "server-M" })
		local DataService = env.require(env.server.Systems.DataService)
		local Products = env.require(env.shared.Products)
		local Monetization = env.require(env.server.Systems.Monetization)
		local Economy = env.require(env.shared.Economy)
		Monetization.init()
		-- Pretend the coins pack and prism seed are configured on Roblox.
		Products.byProductId[1001] = Products.byKey.coins_small
		Products.byProductId[1002] = Products.byKey.prism_seed
		local player = env.players.join(42)
		DataService.loadPlayer(player)
		return env, DataService, Monetization, Economy, player
	end

	local function receipt(id, productId)
		return { PurchaseId = id, PlayerId = 42, ProductId = productId, CurrencySpent = 25 }
	end

	describe("Monetization.ProcessReceipt", function()
		it("grants a coin pack once and records the receipt", function()
			local env, DataService, Monetization, Economy, player = setup()
			local data = DataService.get(player)
			local before = data.coins
			local amount = Economy.coinPackAmount("coins_small", data.bestTier)

			expect(Monetization._processReceipt(receipt("p-1", 1001))).toBe(Granted)
			expect(data.coins).toBe(before + amount)
			expect(table.find(data.receipts, "p-1")).toBeTruthy()

			-- Roblox re-delivers the same receipt: no double grant.
			expect(Monetization._processReceipt(receipt("p-1", 1001))).toBe(Granted)
			expect(data.coins).toBe(before + amount)
			expect(data.stats.robuxSpent).toBe(25)

			local saved = env.backend.stores.SlimeGardenPlayers_v1.u_42.data
			expect(saved.coins).toBe(before + amount)
		end)

		it("does not acknowledge until the grant is saved, and never double grants", function()
			local env, DataService, Monetization, _, player = setup()
			local data = DataService.get(player)
			env.backend.failAlways = true
			expect(Monetization._processReceipt(receipt("p-2", 1002))).toBe(NotYet)
			expect(data.seeds.prism).toBe(1)

			env.backend.failAlways = false
			expect(Monetization._processReceipt(receipt("p-2", 1002))).toBe(Granted)
			expect(data.seeds.prism).toBe(1)
			expect(env.backend.stores.SlimeGardenPlayers_v1.u_42.data.seeds.prism).toBe(1)
		end)

		it("leaves receipts for unknown products or absent players unprocessed", function()
			local _, _, Monetization = setup()
			expect(Monetization._processReceipt(receipt("p-3", 9999))).toBe(NotYet)
			expect(Monetization._processReceipt({ PurchaseId = "p-4", PlayerId = 7, ProductId = 1001 })).toBe(
				NotYet
			)
		end)

		it("distinct purchases each grant", function()
			local _, DataService, Monetization, _, player = setup()
			local data = DataService.get(player)
			Monetization._processReceipt(receipt("a", 1002))
			Monetization._processReceipt(receipt("b", 1002))
			Monetization._processReceipt(receipt("a", 1002))
			expect(data.seeds.prism).toBe(2)
		end)
	end)
end
