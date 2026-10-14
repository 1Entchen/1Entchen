--[[
	RateLimit  (ModuleScript)  ->  ServerScriptService/Services/RateLimit
	Begrenzt, wie oft ein Spieler eine Aktion pro Zeitfenster auslösen darf.
]]

local Players = game:GetService("Players")

local RateLimit = {}

local buckets = {} -- [player] = { [key] = { count, windowStart } }

function RateLimit.Allow(player, key, maxCount, window)
	local now = os.clock()
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local bucket = playerBuckets[key]
	if not bucket or now - bucket.Start >= window then
		playerBuckets[key] = { Count = 1, Start = now }
		return true
	end
	if bucket.Count >= maxCount then
		return false
	end
	bucket.Count += 1
	return true
end

function RateLimit.Start()
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return RateLimit
