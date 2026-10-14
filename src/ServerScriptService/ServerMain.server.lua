--[[
	ServerMain  (Script)  ->  ServerScriptService/ServerMain
	Startet alle Services in der richtigen Reihenfolge.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local folder = ServerScriptService:WaitForChild("Services")

-- Reihenfolge = Reihenfolge der OnLoaded-Callbacks (Pässe vor Einkommen vor Basis …)
local ORDER = {
	"RateLimit",
	"Net",
	"EventService",
	"MonetizationService",
	"IncomeService",
	"BaseService",
	"ConveyorService",
	"StealService",
	"RebirthService",
	"RewardService",
	"LeaderboardService",
	"AnnouncementService",
	"StateService",
	"DataService", -- startet zuletzt: erst danach werden Spieler geladen
}

local Services = {}

for _, name in ipairs(ORDER) do
	local module = folder:WaitForChild(name, 10)
	if not module then
		error("[ServerMain] ModuleScript fehlt: ServerScriptService/Services/" .. name)
	end
	Services[name] = require(module)
end

for _, name in ipairs(ORDER) do
	local service = Services[name]
	if service.Init then
		service.Init(Services)
	end
end

for _, name in ipairs(ORDER) do
	local service = Services[name]
	if service.Start then
		service.Start()
	end
end

print("✅ Brainrot Bandits Server gestartet")
