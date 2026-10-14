--[[
	AnnouncementService  (ModuleScript)  ->  ServerScriptService/Services/AnnouncementService
	Ansagen bei seltenen Funden:
	  - ab Legendary (oder Mutation): Banner im ganzen Server
	  - Secret oder Regenbogen: Banner in ALLEN Servern (MessagingService)
	Seltene Funde bei anderen sehen ist der stärkste Grund, selbst weiterzuspielen.
]]

local MessagingService = game:GetService("MessagingService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Figures = require(Shared:WaitForChild("Figures"))

local AnnouncementService = {}
local Services

local TOPIC = "BrainrotBandits_Global"
local lastGlobal = 0

function AnnouncementService.Found(player, id, mutation, verb)
	local fig = Figures.Get(id)
	if not fig then
		return
	end
	local rarity = Config.Rarities[fig.Rarity]
	local serverMin = Config.Rarities[Config.Announce.ServerMinRarity].Rank
	local globalMin = Config.Rarities[Config.Announce.GlobalMinRarity].Rank
	local special = mutation == "Diamond" or mutation == "Rainbow"
	if rarity.Rank < serverMin and not special then
		return
	end

	local text = ("✨ %s hat %s %s %s!"):format(player.DisplayName, rarity.Display, Figures.DisplayName(id, mutation), verb)
	Services.Net.Announce(text, rarity.Color)

	if (rarity.Rank >= globalMin or mutation == "Rainbow") and os.clock() - lastGlobal > 10 then
		lastGlobal = os.clock()
		task.spawn(function()
			pcall(MessagingService.PublishAsync, MessagingService, TOPIC, {
				Text = "🌍 " .. text,
				Color = rarity.Color:ToHex(),
				JobId = game.JobId,
			})
		end)
	end
end

function AnnouncementService.Init(services)
	Services = services
end

function AnnouncementService.Start()
	task.spawn(function()
		pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC, function(message)
			local data = message.Data
			if type(data) ~= "table" or data.JobId == game.JobId or type(data.Text) ~= "string" then
				return
			end
			local ok, color = pcall(Color3.fromHex, data.Color)
			Services.Net.Announce(data.Text, ok and color or nil)
		end)
	end)
end

return AnnouncementService
