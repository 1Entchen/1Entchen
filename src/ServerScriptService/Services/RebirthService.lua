--[[
	RebirthService  (ModuleScript)  ->  ServerScriptService/Services/RebirthService
	Rebirth: Cash + Figuren zurücksetzen -> dauerhafter Einkommens-Multiplikator,
	+1 Slot (max. +5), längeres Schloss.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Figures = require(Shared:WaitForChild("Figures"))
local Format = require(Shared:WaitForChild("Format"))

local RebirthService = {}
local Services

function RebirthService.HasRequirement(data)
	local required = Config.Rarities[Config.RebirthRequirement(data.Rebirths)].Rank
	for _, slot in pairs(data.Slots) do
		if Figures.RarityRank(slot.Id) >= required then
			return true
		end
	end
	return false
end

function RebirthService.GetInfo(data)
	return {
		Cost = Config.RebirthCost(data.Rebirths),
		Requirement = Config.RebirthRequirement(data.Rebirths),
		HasRequirement = RebirthService.HasRequirement(data),
		CurrentMult = 1 + Config.Multipliers.RebirthPer * data.Rebirths,
		NextMult = 1 + Config.Multipliers.RebirthPer * (data.Rebirths + 1),
	}
end

local function doRebirth(player)
	local data = Services.DataService.Get(player)
	if not data then
		return false, "Daten fehlen"
	end
	local info = RebirthService.GetInfo(data)
	if data.Cash < info.Cost then
		return false, "Dir fehlen " .. Format.Money(info.Cost - data.Cash)
	end
	if not info.HasRequirement then
		return false, "Du brauchst mindestens eine " .. info.Requirement .. "-Figur in deiner Basis"
	end
	if Services.StealService.IsCarrying(player) then
		return false, "Bring erst deine Beute nach Hause"
	end

	Services.StealService.CancelForOwner(player, "Der Besitzer hat einen Rebirth gemacht")
	data.Rebirths += 1
	data.Cash = Config.StartCash
	data.Pending = 0
	data.Slots = {}

	Services.BaseService.RenderAll(player)
	Services.BaseService.UpdateCashPad(player, 0)
	Services.StateService.MarkDirty(player)
	Services.Net.Effect(player, "Rebirth", { Rebirths = data.Rebirths, Mult = info.NextMult })
	Services.Net.Notify(player, ("⭐ REBIRTH %d! Einkommen jetzt x%.1f"):format(data.Rebirths, info.NextMult), "success", "Rebirth")
	Services.Net.Announce(("⭐ %s hat REBIRTH %d erreicht!"):format(player.DisplayName, data.Rebirths), Color3.fromRGB(255, 220, 80))
	task.spawn(Services.DataService.Save, player)
	return true
end

function RebirthService.Init(services)
	Services = services
end

function RebirthService.Start()
	Services.Net.Register("Rebirth", doRebirth, 1)
end

return RebirthService
