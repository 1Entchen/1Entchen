--[[
	EventService  (ModuleScript)  ->  ServerScriptService/Services/EventService
	Zeitlich begrenzte Events (laufen automatisch nach UTC-Zeit):
	  - Wochenende (Sa + So): 2x Cash
	  - Happy Hour täglich 18-19 Uhr UTC: Lucky Spawn gratis für alle
	Zusätzlich kann man live ein Event starten: Attribut "EventCashMult" (Zahl)
	an Workspace setzen, z. B. per Command Bar im Live-Server oder später per Admin-Tool.
]]

local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local EventService = {}
local Services

local function utcNow()
	return os.date("!*t", os.time())
end

function EventService.IsWeekend()
	local t = utcNow()
	return t.wday == 1 or t.wday == 7
end

function EventService.IsHappyHour()
	local t = utcNow()
	return t.hour >= Config.Events.HappyHourStartUTC and t.hour < Config.Events.HappyHourEndUTC
end

function EventService.GetCashMult()
	local mult = 1
	if EventService.IsWeekend() then
		mult *= Config.Events.WeekendCashMult
	end
	local manual = Workspace:GetAttribute("EventCashMult")
	if type(manual) == "number" and manual > 0 then
		mult *= manual
	end
	return mult
end

function EventService.GetInfo()
	local names = {}
	if EventService.IsWeekend() then
		table.insert(names, "🎉 Wochenend-Event: 2x Cash")
	end
	if EventService.IsHappyHour() then
		table.insert(names, "🍀 Happy Hour: Lucky Spawn gratis")
	end
	local manual = Workspace:GetAttribute("EventCashMult")
	if type(manual) == "number" and manual > 1 then
		table.insert(names, ("🔥 Sonder-Event: %sx Cash"):format(manual))
	end
	return { Names = names, CashMult = EventService.GetCashMult(), Luck = EventService.IsHappyHour() }
end

function EventService.Init(services)
	Services = services
end

function EventService.Start()
	task.spawn(function()
		local lastKey = ""
		while true do
			local info = EventService.GetInfo()
			local key = table.concat(info.Names, "|")
			if key ~= lastKey then
				for _, name in ipairs(info.Names) do
					Services.Net.Announce(name .. " ist jetzt aktiv!", Color3.fromRGB(255, 120, 220))
				end
				lastKey = key
				for _, player in ipairs(Services.DataService.GetLoadedPlayers()) do
					Services.StateService.MarkDirty(player)
				end
			end
			task.wait(30)
		end
	end)
end

return EventService
