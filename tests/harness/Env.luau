--!nocheck
-- Builds the global environment that game modules see under Lune: Roblox
-- datatypes from @lune/roblox, Lune's task scheduler, and a mock `game`
-- whose services can be overridden per test.

local roblox = require("@lune/roblox")
local task = require("@lune/task")

local VirtualRequire = require("./VirtualRequire")

local Env = {}

local function signal()
	local handlers = {}
	local s = {}
	function s:Connect(fn)
		table.insert(handlers, fn)
		local c = {}
		function c:Disconnect()
			local i = table.find(handlers, fn)
			if i then
				table.remove(handlers, i)
			end
		end
		return c
	end
	function s:Fire(...)
		for _, fn in table.clone(handlers) do
			fn(...)
		end
	end
	function s:Wait()
		local thread = coroutine.running()
		local c
		c = s:Connect(function(...)
			c:Disconnect()
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end
	return s
end

Env.signal = signal

-- options.services: { [name]: table } overrides; options.isStudio: boolean
function Env.new(options)
	options = options or {}
	local services = {}
	local loader

	local runService = {
		IsServer = function()
			return options.isClient ~= true
		end,
		IsClient = function()
			return options.isClient == true
		end,
		IsStudio = function()
			return options.isStudio == true
		end,
		Heartbeat = signal(),
	}

	local game = { JobId = options.jobId or "test-job", PlaceId = 1 }
	function game:GetService(name)
		local service = services[name]
		assert(service, `mock service {name} not provided`)
		return service
	end
	function game:BindToClose(fn)
		game.__closeHandler = fn
	end

	local globals = {
		game = game,
		workspace = {
			GetServerTimeNow = function()
				return os.clock()
			end,
		},
		task = task,
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		ColorSequence = roblox.ColorSequence,
		NumberSequence = roblox.NumberSequence,
		NumberRange = roblox.NumberRange,
		warn = function(...)
			if options.verbose then
				print("[warn]", ...)
			end
		end,
	}

	loader = VirtualRequire.new(globals)
	local shared = loader.root("src/shared")
	local server = loader.root("src/server")

	services.ReplicatedStorage = setmetatable({ Shared = shared }, {
		__index = {
			WaitForChild = function(self, name)
				return assert(rawget(self, name), name)
			end,
			FindFirstChild = function(self, name)
				return rawget(self, name)
			end,
		},
	})
	services.ServerScriptService = setmetatable({ Server = server }, {
		__index = {
			WaitForChild = function(self, name)
				return assert(rawget(self, name), name)
			end,
		},
	})
	services.RunService = runService
	services.HttpService = {
		GenerateGUID = function()
			return tostring(math.random(1, 1e9))
		end,
		JSONEncode = function(_, value)
			return require("@lune/serde").encode("json", value)
		end,
	}
	for name, service in options.services or {} do
		services[name] = service
	end

	return {
		game = game,
		globals = globals,
		services = services,
		loader = loader,
		shared = shared,
		server = server,
		require = loader.require,
	}
end

return Env
