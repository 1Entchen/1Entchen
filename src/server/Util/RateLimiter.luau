--!strict
-- Per-player, per-key token buckets. Every remote handler passes through
-- one so exploit spam can neither duplicate actions nor load the server.

local Players = game:GetService("Players")

type Bucket = { tokens: number, last: number }

local RateLimiter = {}

local buckets: { [Player]: { [string]: Bucket } } = {}
local strikes: { [Player]: number } = {}

function RateLimiter.allow(player: Player, key: string, ratePerSecond: number, burst: number): boolean
	local now = os.clock()
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local bucket = playerBuckets[key]
	if not bucket then
		bucket = { tokens = burst, last = now }
		playerBuckets[key] = bucket
	end
	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.last) * ratePerSecond)
	bucket.last = now
	if bucket.tokens < 1 then
		local count = (strikes[player] or 0) + 1
		strikes[player] = count
		if count == 200 then
			-- Telemetry only: mobile lag and retries also trip limits, so
			-- never punish on this signal alone.
			warn(`[RateLimiter] {player.Name} ({player.UserId}) is hitting rate limits heavily`)
		end
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimiter.clear(player: Player)
	buckets[player] = nil
	strikes[player] = nil
end

Players.PlayerRemoving:Connect(RateLimiter.clear)

return RateLimiter
