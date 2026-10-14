--!nocheck
-- Session locking and persistence safety, simulated with two servers that
-- share one mock DataStore.
return function(Test, Env)
	local describe, it, expect = Test.describe, Test.it, Test.expect
	local Mocks = require("../harness/Mocks")

	local function twoServers()
		local backend = Mocks.dataStoreBackend()
		local a = Mocks.server({ jobId = "server-A", backend = backend, players = Mocks.players() })
		local b = Mocks.server({ jobId = "server-B", backend = backend, players = Mocks.players() })
		local dsA = a.require(a.server.Systems.DataService)
		local dsB = b.require(b.server.Systems.DataService)
		return backend, a, b, dsA, dsB
	end

	local function stored(backend, userId)
		local store = backend.stores.SlimeGardenPlayers_v1
		return store and store["u_" .. userId]
	end

	describe("DataService", function()
		it("creates a default profile for a new player and takes the lock", function()
			local backend, a, _, dsA = twoServers()
			local player = a.players.join(1)
			dsA.loadPlayer(player)
			local data = dsA.get(player)
			expect(data).toBeTruthy()
			expect(data.coins).toBe(30)
			expect(data.seeds.goo).toBe(3)
			expect(stored(backend, 1).lock.jobId).toBe("server-A")
			expect(player.kicked).toBeNil()
		end)

		it("refuses to load while another live server holds the lock", function()
			local backend, a, b, dsA, dsB = twoServers()
			local pA = a.players.join(2)
			dsA.loadPlayer(pA)
			dsA.get(pA).coins = 999

			local pB = b.players.join(2)
			dsB.loadPlayer(pB)
			expect(dsB.get(pB)).toBeNil()
			expect(pB.kicked).toBeTruthy()
			expect(string.find(pB.kicked, "still saving", 1, true)).toBeTruthy()
			expect(stored(backend, 2).lock.jobId).toBe("server-A")
		end)

		it("persists on release and hands data to the next server", function()
			local backend, a, b, dsA, dsB = twoServers()
			local pA = a.players.join(3)
			dsA.loadPlayer(pA)
			dsA.get(pA).coins = 1234
			dsA.get(pA).seeds.berry = 2
			a.players.leave(pA)
			dsA.releasePlayer(pA)
			expect(stored(backend, 3).lock).toBeNil()
			expect(stored(backend, 3).data.coins).toBe(1234)

			local pB = b.players.join(3)
			dsB.loadPlayer(pB)
			expect(pB.kicked).toBeNil()
			expect(dsB.get(pB).coins).toBe(1234)
			expect(dsB.get(pB).seeds.berry).toBe(2)
			expect(dsB.get(pB).stats.sessions).toBe(2)
		end)

		it("takes over a stale lock left by a crashed server", function()
			local backend, _, b, _, dsB = twoServers()
			backend.stores.SlimeGardenPlayers_v1 = {
				u_4 = { data = { coins = 77 }, lock = { jobId = "dead-server", time = os.time() - 10000 } },
			}
			local p = b.players.join(4)
			dsB.loadPlayer(p)
			expect(p.kicked).toBeNil()
			expect(dsB.get(p).coins).toBe(77)
			expect(stored(backend, 4).lock.jobId).toBe("server-B")
		end)

		it("kicks instead of handing out a blank profile when loading fails", function()
			local backend, a, _, dsA = twoServers()
			backend.stores.SlimeGardenPlayers_v1 = { u_5 = { data = { coins = 5000 } } }
			backend.failAlways = true
			local p = a.players.join(5)
			dsA.loadPlayer(p)
			expect(dsA.get(p)).toBeNil()
			expect(p.kicked).toBeTruthy()
			backend.failAlways = false
			expect(stored(backend, 5).data.coins).toBe(5000)
		end)

		it("retries transient save failures", function()
			local backend, a, _, dsA = twoServers()
			local p = a.players.join(6)
			dsA.loadPlayer(p)
			dsA.get(p).coins = 42
			backend.failUpdates = 2
			expect(dsA.saveNow(p)).toBeTruthy()
			expect(stored(backend, 6).data.coins).toBe(42)
		end)

		it("never overwrites data after losing the lock, and kicks the player", function()
			local backend, a, _, dsA = twoServers()
			local p = a.players.join(7)
			dsA.loadPlayer(p)
			dsA.get(p).coins = 1
			-- Another server legitimately took over (e.g. after an outage).
			backend.stores.SlimeGardenPlayers_v1.u_7 = {
				data = { coins = 9000 },
				lock = { jobId = "server-C", time = os.time() },
			}
			expect(dsA.saveNow(p)).toBeFalsy()
			expect(stored(backend, 7).data.coins).toBe(9000)
			expect(p.kicked).toBeTruthy()
			expect(dsA.get(p)).toBeNil()
		end)

		it("releases the lock if the player left during loading", function()
			local backend, a, _, dsA = twoServers()
			local p = a.players.join(8)
			p.Parent = nil -- left before load completed
			dsA.loadPlayer(p)
			expect(dsA.get(p)).toBeNil()
			local record = stored(backend, 8)
			expect(record == nil or record.lock == nil).toBeTruthy()
		end)

		it("runs save hooks before writing", function()
			local backend, a, _, dsA = twoServers()
			local p = a.players.join(9)
			dsA.loadPlayer(p)
			dsA.addSaveHook(function(_, data)
				data.coins = 31337
			end)
			dsA.saveNow(p)
			expect(stored(backend, 9).data.coins).toBe(31337)
		end)
	end)
end
