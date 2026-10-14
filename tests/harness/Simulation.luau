--!nocheck
-- Boots the real server (every system in init.server order, real World
-- builder, real SlimeBuilder) under Lune with:
--   * a virtual clock (VirtualTask) driving every server loop
--   * mock Players / DataStores / Marketplace
--   * polyfills for the few engine methods Lune's Instance lacks
-- Remote handlers are captured so tests can "fire" remotes as a client.

local roblox = require("@lune/roblox")

local Env = require("./Env")
local Mocks = require("./Mocks")
local VirtualTask = require("./VirtualTask")

local Simulation = {}

local currentClock = nil
local polyfilled = false

local function signal()
	-- Like Roblox: a failing handler does not break the firing code.
	local handlers = {}
	local s = { errors = {} }
	function s:Connect(fn)
		table.insert(handlers, fn)
		return {
			Disconnect = function()
				local i = table.find(handlers, fn)
				if i then
					table.remove(handlers, i)
				end
			end,
		}
	end
	function s:Fire(...)
		for _, fn in table.clone(handlers) do
			currentClock.spawn(fn, ...)
		end
	end
	return s
end

local function polyfill()
	if polyfilled then
		return
	end
	polyfilled = true
	roblox.implementProperty("BasePart", "Position", function(self)
		return self.CFrame.Position
	end, function(self, value)
		self.CFrame = self.CFrame.Rotation + value
	end)
	roblox.implementMethod("Model", "GetPivot", function(self)
		return self.WorldPivot
	end)
	roblox.implementMethod("Model", "PivotTo", function(self, target)
		local delta = target * self.WorldPivot:Inverse()
		for _, d in self:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = delta * d.CFrame
			end
		end
		self.WorldPivot = target
	end)
	roblox.implementMethod("Workspace", "GetServerTimeNow", function()
		return 1_000_000 + currentClock.time
	end)
	local promptSignals = {}
	roblox.implementProperty("ProximityPrompt", "Triggered", function(self)
		local key = self:GetFullName()
		promptSignals[key] = promptSignals[key] or signal()
		return promptSignals[key]
	end, function() end)
	Simulation.promptSignals = promptSignals
end

local function makePlayer(players, userId)
	local player = players.join(userId)
	player.MembershipType = roblox.Enum.MembershipType.None
	player.CharacterAdded = signal()
	function player:IsFriendsWith()
		return false
	end
	function player:IsInGroup()
		return false
	end
	local root = {
		Position = roblox.Vector3.new(0, 3, 14),
		IsA = function(_, class)
			return class == "BasePart"
		end,
	}
	local humanoid = { Health = 100 }
	player.Character = {
		FindFirstChildOfClass = function(_, class)
			return if class == "Humanoid" then humanoid else nil
		end,
		FindFirstChild = function(_, name)
			return if name == "HumanoidRootPart" then root else nil
		end,
		PivotTo = function(_, cf)
			root.Position = cf.Position
		end,
	}
	player.root = root
	return player
end

function Simulation.new(options)
	options = options or {}
	polyfill()
	local V = VirtualTask.new()
	currentClock = V

	local players = Mocks.players()
	players.PlayerAdded = signal()
	players.PlayerRemoving = signal()
	players.PlayerMembershipChanged = signal()
	local backend = options.backend or Mocks.dataStoreBackend()
	local workspace = roblox.Instance.new("DataModel"):GetService("Workspace")

	local marketplace = { PromptGamePassPurchaseFinished = signal(), owned = {} }
	function marketplace:UserOwnsGamePassAsync(userId, passId)
		return marketplace.owned[userId .. ":" .. passId] == true
	end

	local env = Env.new({
		jobId = options.jobId or "sim-server",
		isStudio = options.isStudio,
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
			Workspace = workspace,
		},
	})
	env.services.RunService.Heartbeat = signal()
	env.globals.task = V
	env.globals.workspace = workspace
	env.globals.Instance = roblox.Instance
	local seed = 1
	env.globals.Random = {
		new = function()
			local Rng = env.require(env.shared.Rng)
			local rng = Rng.new(seed)
			seed += 1
			return {
				NextNumber = function(_, a, b)
					a, b = a or 0, b or 1
					return a + rng() * (b - a)
				end,
			}
		end,
	}

	-- Capture remote traffic instead of touching the engine.
	local handlers = {}
	local sent = {}
	local function event(name)
		return {
			OnServerEvent = {
				Connect = function(_, fn)
					handlers[name] = handlers[name] or {}
					table.insert(handlers[name], fn)
				end,
			},
			FireClient = function(_, player, ...)
				table.insert(sent, { name = name, player = player, args = table.pack(...) })
			end,
			FireAllClients = function(_, ...)
				table.insert(sent, { name = name, args = table.pack(...) })
			end,
		}
	end
	env.loader.cache[rawget(env.shared.Net, "__path")] = {
		value = {
			setup = function() end,
			event = event,
		},
	}
	-- Leaderstats parent Instances under Player objects, which are mocks here.
	env.loader.cache[rawget(env.server.Systems.Leaderboard, "__path")] = { value = {} }

	local sim =
		{ env = env, clock = V, players = players, backend = backend, sent = sent, workspace = workspace }

	function sim.boot()
		local order = {
			"DataService",
			"Sync",
			"Analytics",
			"Monetization",
			"Weather",
			"Boosts",
			"Tutorial",
			"Retention",
			"Index",
			"Plots",
			"Garden",
			"Shop",
			"Sell",
			"Rebirth",
			"Leaderboard",
		}
		local systems = {}
		for _, name in order do
			systems[name] = env.require(env.server.Systems[name])
		end
		for _, name in order do
			if systems[name].init then
				systems[name].init()
			end
		end
		for _, name in order do
			if systems[name].start then
				V.spawn(systems[name].start)
			end
		end
		systems.DataService.listen()
		sim.systems = systems
		return systems
	end

	function sim.advance(seconds, step)
		step = step or 0.5
		local remaining = seconds
		while remaining > 0 do
			local dt = math.min(step, remaining)
			V.advance(dt)
			env.services.RunService.Heartbeat:Fire(dt)
			V.advance(0)
			remaining -= dt
		end
	end

	function sim.join(userId)
		local player = makePlayer(players, userId)
		players.PlayerAdded:Fire(player)
		sim.advance(1)
		return player
	end

	function sim.leave(player)
		players.leave(player)
		sim.advance(1)
	end

	function sim.fire(name, player, ...)
		for _, fn in handlers[name] or {} do
			V.spawn(fn, player, ...)
		end
		V.advance(0)
	end

	function sim.moveTo(player, position)
		player.root.Position = position
	end

	function sim.notifications(player)
		local list = {}
		for _, message in sent do
			if message.name == "Notify" and message.player == player then
				table.insert(list, message.args[1])
			end
		end
		return list
	end

	function sim.errors()
		return V.errors
	end

	return sim
end

return Simulation
