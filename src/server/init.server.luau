--!strict
-- The single server entry point. Systems load in dependency order; every
-- system's init() runs before any start(), so cross-system registration
-- (remotes, sync sections, product handlers) is complete before gameplay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Systems = script:WaitForChild("Systems")

local ORDER = {
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

type System = { init: (() -> ())?, start: (() -> ())? }

Net.setup()

local loaded: { { name: string, system: System } } = {}
for _, name in ORDER do
	local module = Systems:WaitForChild(name) :: ModuleScript
	local system = (require :: any)(module) :: System
	table.insert(loaded, { name = name, system = system })
end

for _, entry in loaded do
	local init = entry.system.init
	if init then
		local ok, err = pcall(init :: any)
		if not ok then
			warn(`[Server] {entry.name}.init failed: {err}`)
		end
	end
end

for _, entry in loaded do
	local start = entry.system.start
	if start then
		task.spawn(function()
			local ok, err = pcall(start :: any)
			if not ok then
				warn(`[Server] {entry.name}.start failed: {err}`)
			end
		end)
	end
end

-- Begin loading players only once every system is listening.
task.defer(function()
	local DataService = require(Systems:WaitForChild("DataService")) :: any
	DataService.listen()
	print("[Slime Garden] server started")
end)
