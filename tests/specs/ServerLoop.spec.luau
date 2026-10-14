--!nocheck
-- End-to-end server simulation: the real systems, real world builder and
-- real remote handlers, driven by a virtual clock.
return function(Test, Env)
	local describe, it, expect = Test.describe, Test.it, Test.expect
	local Simulation = require("../harness/Simulation")
	local roblox = require("@lune/roblox")

	local function above(part)
		return part.CFrame.Position + roblox.Vector3.new(0, 3, 0)
	end

	local function setup(options)
		local sim = Simulation.new(options)
		local systems = sim.boot()
		sim.advance(1)
		local player = sim.join(1001)
		local data = systems.DataService.get(player)
		local plot = systems.Plots.get(player)
		return sim, systems, player, data, plot
	end

	local function noErrors(sim)
		local errors = sim.errors()
		if #errors > 0 then
			error("server threads raised errors:\n" .. table.concat(errors, "\n---\n"))
		end
	end

	describe("Server loop", function()
		it("boots, builds the world and assigns a plot", function()
			local sim, systems, player, data, plot = setup()
			expect(data).toBeTruthy()
			expect(plot).toBeTruthy()
			expect(player:GetAttribute("PlotIndex")).toBe(plot.index)
			expect(sim.workspace:FindFirstChild("SlimeGarden")).toBeTruthy()
			expect(#plot.tiles).toBe(30)
			expect(plot.tiles[6]:GetAttribute("Usable")).toBe(true)
			expect(plot.tiles[7]:GetAttribute("Usable")).toBe(false)
			-- teleported home
			expect((player.root.Position - plot.spawn.Position).Magnitude < 1).toBeTruthy()
			expect(systems.Shop.state().restockId).toBe(1)
			noErrors(sim)
		end)

		it("plays the full first session: plant, grow, harvest, sell, buy", function()
			local sim, systems, player, data, plot = setup()
			expect(data.tutorialStep).toBe(0)

			sim.moveTo(player, above(plot.tiles[1]))
			sim.fire("Plant", player, 1, "goo")
			expect(#data.plants).toBe(1)
			expect(data.seeds.goo).toBe(2)
			expect(data.tutorialStep).toBe(1)
			expect(plot.plants:FindFirstChild("Plant1")).toBeTruthy()

			-- Not ripe yet: harvesting does nothing.
			sim.fire("Harvest", player, 1)
			expect(#data.slimes).toBe(0)

			sim.advance(13)
			expect(plot.plants:FindFirstChild("Plant1"):GetAttribute("Ripe")).toBe(true)
			expect(data.tutorialStep).toBe(2)

			sim.fire("Harvest", player, 1)
			expect(#data.slimes).toBe(1)
			expect(#data.plants).toBe(0)
			expect(data.tutorialStep).toBe(3)
			expect(data.index.goo).toBe(true)

			-- Selling away from the stand is refused.
			local coinsBefore = data.coins
			sim.fire("SellAll", player)
			expect(#data.slimes).toBe(1)

			sim.moveTo(player, above(systems.Plots.world().sellCounter))
			sim.fire("SellAll", player)
			expect(#data.slimes).toBe(0)
			expect(data.coins > coinsBefore).toBeTruthy()
			expect(data.totalEarned > 0).toBeTruthy()
			expect(data.tutorialStep).toBe(4)

			sim.moveTo(player, above(systems.Plots.world().shopCounter))
			local coins = data.coins
			sim.fire("BuySeed", player, "goo", 2)
			expect(data.seeds.goo).toBe(4)
			-- 2 seeds at 10 each, then the tutorial completion bonus
			expect(data.coins).toBe(coins - 20 + 50)
			expect(data.tutorialStep).toBe(5)
			expect(data.potions.growth).toBe(1)
			noErrors(sim)
		end)

		it("rejects malformed, far-away and unaffordable requests", function()
			local sim, systems, player, data, plot = setup()
			local snapshot = systems.DataService.get(player)
			sim.moveTo(player, roblox.Vector3.new(400, 3, 400))
			sim.fire("Plant", player, 1, "goo") -- too far
			sim.moveTo(player, above(plot.tiles[1]))
			sim.fire("Plant", player, 999, "goo")
			sim.fire("Plant", player, 0 / 0, "goo")
			sim.fire("Plant", player, 1.5, "goo")
			sim.fire("Plant", player, 1, "cosmic") -- does not own it
			sim.fire("Plant", player, 1, string.rep("x", 5000))
			sim.fire("Plant", player, 7, "goo") -- locked tile
			sim.fire("Plant", player, { 1 }, "goo")
			sim.fire("Plant", player, nil, nil)
			expect(#snapshot.plants).toBe(0)
			expect(snapshot.seeds.goo).toBe(3)

			sim.fire("BuySeed", player, "goo", 1) -- not at the shop
			expect(snapshot.seeds.goo).toBe(3)
			sim.moveTo(player, above(systems.Plots.world().shopCounter))
			sim.fire("BuySeed", player, "king", 1) -- cannot afford / maybe not in stock
			expect(snapshot.seeds.king).toBeNil()
			sim.fire("BuySeed", player, "goo", -5)
			sim.fire("BuySeed", player, "goo", math.huge)
			expect(snapshot.seeds.goo).toBe(3)
			sim.fire("ClaimQuest", player, 1) -- not complete
			sim.fire("Rebirth", player) -- cannot afford
			expect(snapshot.rebirths).toBe(0)
			sim.fire("DevGrant", player, "dev_coins") -- not Studio
			expect(snapshot.coins).toBe(30)
			sim.fire("UsePotion", player, "growth") -- owns none
			expect(snapshot.boostExpiry.growth).toBeNil()
			noErrors(sim)
		end)

		it("unlocks tiles in order and charges the right price", function()
			local sim, _, player, data, plot = setup()
			sim.fire("UnlockTile", player)
			expect(data.unlockedTiles).toBe(6) -- 30 coins is not enough
			data.coins = 1000
			sim.fire("UnlockTile", player)
			sim.advance(1)
			sim.fire("UnlockTile", player)
			expect(data.unlockedTiles).toBe(8)
			expect(data.coins).toBe(1000 - 100 - 180)
			expect(plot.tiles[8]:GetAttribute("Usable")).toBe(true)
			noErrors(sim)
		end)

		it("weather speeds growth and potions stack", function()
			local sim, systems, player, data, plot = setup()
			data.seeds.ember = 1
			sim.moveTo(player, above(plot.tiles[2]))
			systems.Weather._force("goorain")
			sim.advance(0.5)
			expect(systems.Boosts.get(player).growth).toBe(1.5)
			sim.fire("Plant", player, 2, "ember") -- 120s at 1x, 80s at 1.5x
			sim.advance(82)
			systems.Weather._force(nil)
			sim.advance(0.5)
			expect(plot.plants:FindFirstChild("Plant2"):GetAttribute("Ripe")).toBe(true)

			data.potions.growth = 1
			sim.fire("UsePotion", player, "growth")
			expect(data.potions.growth).toBeNil()
			expect(systems.Boosts.get(player).growth).toBe(2)
			noErrors(sim)
		end)

		it("persists the garden across sessions and grows plants offline", function()
			local sim, systems, player, data = setup()
			data.seeds.berry = 1
			local plot = systems.Plots.get(player)
			sim.moveTo(player, above(plot.tiles[3]))
			sim.fire("Plant", player, 3, "berry")
			sim.advance(20)
			sim.leave(player)
			local saved = sim.backend.stores.SlimeGardenPlayers_v1.u_1001
			expect(saved.lock).toBeNil()
			expect(#saved.data.plants).toBe(1)
			expect(saved.data.plants[1].e >= 19).toBeTruthy()
			-- Pretend the player was away for an hour.
			saved.data.lastSeen -= 3600

			local sim2 = Simulation.new({ backend = sim.backend, jobId = "sim-server-2" })
			local systems2 = sim2.boot()
			sim2.advance(1)
			local again = sim2.join(1001)
			local data2 = systems2.DataService.get(again)
			local plot2 = systems2.Plots.get(again)
			expect(#data2.plants).toBe(1)
			local model = plot2.plants:FindFirstChild("Plant3")
			expect(model).toBeTruthy()
			expect(model:GetAttribute("Ripe")).toBe(true)
			noErrors(sim)
			noErrors(sim2)
		end)

		it("rebirth resets progress, keeps favorites and raises the multiplier", function()
			local sim, systems, player, data = setup()
			table.insert(data.slimes, { id = 50, s = "goo", w = 1, m = {}, f = true })
			table.insert(data.slimes, { id = 51, s = "goo", w = 1, m = {} })
			data.nextSlimeId = 52
			data.coins = 15_000_000
			data.unlockedTiles = 20
			sim.fire("Rebirth", player)
			expect(data.rebirths).toBe(1)
			expect(data.coins).toBe(30)
			expect(data.unlockedTiles).toBe(7)
			expect(#data.slimes).toBe(1)
			expect(data.slimes[1].id).toBe(50)
			expect(systems.Boosts.get(player).sell).toBe(1.5)
			noErrors(sim)
		end)

		it("daily reward pays once per day and quests track progress", function()
			local sim, _, player, data, plot = setup()
			sim.fire("ClaimDaily", player)
			local coins = data.coins
			expect(data.daily.streak).toBe(1)
			sim.advance(2)
			sim.fire("ClaimDaily", player)
			expect(data.coins).toBe(coins)
			expect(#data.quests.list).toBe(3)

			sim.moveTo(player, above(plot.tiles[1]))
			sim.fire("Plant", player, 1, "goo")
			for _, quest in data.quests.list do
				if quest.kind == "plant" then
					expect(quest.progress).toBe(1)
				end
			end
			noErrors(sim)
		end)

		it("studio purchase simulation grants passes and products", function()
			local sim, systems, player, data, plot = setup({ isStudio = true })
			sim.fire("DevGrant", player, "auto_harvest")
			expect(systems.Monetization.owns(player, "auto_harvest")).toBe(true)
			sim.fire("DevGrant", player, "big_garden")
			expect(plot.tiles[25]:GetAttribute("Usable")).toBe(true)
			sim.fire("DevGrant", player, "starter_pack")
			expect(data.starterPackClaimed).toBe(true)
			expect(data.seeds.ember).toBe(3)

			sim.moveTo(player, above(plot.tiles[25]))
			sim.fire("Plant", player, 25, "goo")
			expect(#data.plants).toBe(1)
			sim.fire("DevGrant", player, "instant_grow")
			sim.advance(6) -- auto harvest tick
			expect(#data.plants).toBe(0)
			expect(#data.slimes).toBe(1)

			sim.fire("DevGrant", player, "weather_starfall")
			expect(systems.Weather.current()).toBe("starfall")
			noErrors(sim)
		end)

		it("survives a long session of natural weather and restocks", function()
			local sim, systems, player, data, plot = setup()
			data.coins = 50_000
			sim.moveTo(player, above(plot.tiles[1]))
			for tile = 1, 6 do
				data.seeds.bubble = (data.seeds.bubble or 0) + 1
				sim.fire("Plant", player, tile, "bubble")
			end
			sim.advance(60 * 30, 2) -- 30 minutes
			expect(systems.Shop.state().restockId >= 6).toBeTruthy()
			local mutated = 0
			for _, plant in data.plants do
				mutated += #plant.m
			end
			-- Ripe slimes sat through several weather events.
			expect(mutated > 0).toBeTruthy()
			sim.fire("HarvestAll", player)
			expect(#data.slimes).toBe(6)
			noErrors(sim)
		end)
	end)
end
