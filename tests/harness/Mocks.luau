--!nocheck
-- Mock Roblox services for server-system tests.

local roblox = require("@lune/roblox")
local realTask = require("@lune/task")

local Env = require("./Env")

local Mocks = {}

-- Shared DataStore backend: several "servers" can point at one.
function Mocks.dataStoreBackend()
	local backend = { stores = {}, failUpdates = 0, failAlways = false, updates = 0 }
	local function deepCopy(v)
		if type(v) ~= "table" then
			return v
		end
		local c = {}
		for k, x in v do
			c[k] = deepCopy(x)
		end
		return c
	end
	backend.deepCopy = deepCopy
	function backend.service()
		local service = {}
		function service:GetDataStore(name)
			local data = backend.stores[name]
			if not data then
				data = {}
				backend.stores[name] = data
			end
			local ds = {}
			function ds:UpdateAsync(key, fn)
				backend.updates += 1
				if backend.failAlways then
					error("DataStore request failed (mock outage)")
				end
				if backend.failUpdates > 0 then
					backend.failUpdates -= 1
					error("DataStore request failed (mock)")
				end
				local result = fn(deepCopy(data[key]), nil)
				if result ~= nil then
					data[key] = deepCopy(result)
				end
				return deepCopy(data[key])
			end
			function ds:GetAsync(key)
				return deepCopy(data[key])
			end
			return ds
		end
		function service:GetOrderedDataStore()
			error("ordered stores not mocked")
		end
		return service
	end
	return backend
end

function Mocks.players()
	local players = { list = {} }
	players.PlayerAdded = Env.signal()
	players.PlayerRemoving = Env.signal()
	players.PlayerMembershipChanged = Env.signal()
	function players:GetPlayers()
		return table.clone(players.list)
	end
	function players:GetPlayerByUserId(id)
		for _, p in players.list do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end
	function players.join(userId)
		local player = {
			UserId = userId,
			Name = "Player" .. userId,
			DisplayName = "Player" .. userId,
			Parent = players,
			attributes = {},
		}
		function player:Kick(message)
			player.kicked = message
			player.Parent = nil
			local i = table.find(players.list, player)
			if i then
				table.remove(players.list, i)
			end
		end
		function player:SetAttribute(k, v)
			player.attributes[k] = v
		end
		function player:GetAttribute(k)
			return player.attributes[k]
		end
		table.insert(players.list, player)
		return player
	end
	function players.leave(player)
		local i = table.find(players.list, player)
		if i then
			table.remove(players.list, i)
		end
		player.Parent = nil
		players.PlayerRemoving:Fire(player)
	end
	return players
end

-- task replacement whose wait() returns immediately (advancing a virtual
-- clock) so retry/backoff loops run instantly in tests.
function Mocks.fastTask()
	local t = { clock = 0 }
	function t.wait(seconds)
		seconds = seconds or 0
		t.clock += seconds
		return seconds
	end
	t.spawn = realTask.spawn
	t.defer = realTask.defer
	t.delay = function(_, fn, ...)
		return realTask.defer(fn, ...)
	end
	t.cancel = realTask.cancel
	return t
end

-- Builds an environment for a "server" with the given job id.
function Mocks.server(options)
	local players = options.players or Mocks.players()
	local backend = options.backend or Mocks.dataStoreBackend()
	local marketplace = {
		PromptGamePassPurchaseFinished = Env.signal(),
		owned = {},
	}
	function marketplace:UserOwnsGamePassAsync(userId, passId)
		return marketplace.owned[userId .. ":" .. passId] == true
	end
	local env = Env.new({
		jobId = options.jobId,
		isStudio = options.isStudio,
		verbose = options.verbose,
		services = {
			Players = players,
			DataStoreService = backend.service(),
			MarketplaceService = marketplace,
			AnalyticsService = setmetatable({}, {
				__index = function()
					return function() end
				end,
			}),
			BadgeService = { AwardBadge = function() end },
			Workspace = { GetServerTimeNow = os.clock },
		},
	})
	env.globals.task = Mocks.fastTask()
	env.globals.Instance = roblox.Instance
	env.globals.Random = {
		new = function()
			return {
				NextNumber = function(_, a, b)
					a, b = a or 0, b or 1
					return a + math.random() * (b - a)
				end,
			}
		end,
	}
	env.players = players
	env.backend = backend
	env.marketplace = marketplace

	-- Stub modules that would talk to remotes / the engine.
	local stubs = {}
	function env.stub(instance, value)
		env.loader.cache[rawget(instance, "__path")] = { value = value }
		stubs[instance] = value
	end
	local notifications = {}
	env.notifications = notifications
	env.stub(env.server.Util.Notify, {
		player = function(player, text, kind)
			table.insert(notifications, { player = player, text = text, kind = kind })
		end,
		all = function() end,
		effect = function() end,
		effectAll = function() end,
	})
	env.stub(env.shared.Net, {
		setup = function() end,
		event = function()
			return {
				FireClient = function() end,
				FireAllClients = function() end,
				OnServerEvent = { Connect = function() end },
			}
		end,
	})
	return env
end

return Mocks
