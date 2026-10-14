--!strict
-- Optional Roblox badge awards (ids configured in Config.Badges).

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Badges = {}

function Badges.award(player: Player, key: string)
	local id = (Config.Badges :: { [string]: number })[key]
	if not id or id == 0 then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			BadgeService:AwardBadge(player.UserId, id)
		end)
		if not ok then
			warn(`[Badges] could not award {key}: {err}`)
		end
	end)
end

return Badges
