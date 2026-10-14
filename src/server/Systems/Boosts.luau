--!strict
-- Computes each player's sell / growth / luck multipliers from passes,
-- potions, weather, Premium, group membership and friends in the server.
-- Fires Changed when a player's multipliers change so growth can be
-- re-based without losing progress.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Types"))
local Weathers = require(Shared:WaitForChild("Weathers"))

local Util = script.Parent.Parent:WaitForChild("Util")
local Notify = require(Util:WaitForChild("Notify"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))
local Validate = require(Util:WaitForChild("Validate"))

local DataService = require(script.Parent.DataService)
local Monetization = require(script.Parent.Monetization)
local Sync = require(script.Parent.Sync)
local Weather = require(script.Parent.Weather)

type Multipliers = Types.Multipliers
type Profile = Types.Profile

local Boosts = {}

Boosts.Changed = Signal.new() :: Signal.Signal<Player, Multipliers>

local POTIONS: { [string]: string } = { growth = "Growth Potion", luck = "Luck Potion" }

local cache: { [Player]: Multipliers } = {}
local friendCache: { [Player]: { [number]: boolean } } = {}
local inGroup: { [Player]: boolean } = {}

local function friendsInServer(player: Player): number
	local known = friendCache[player]
	if not known then
		return 0
	end
	local count = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and known[other.UserId] then
			count += 1
		end
	end
	return count
end

local function isPremium(player: Player): boolean
	return player.MembershipType == Enum.MembershipType.Premium
end

local function compute(player: Player, data: Profile): Multipliers
	local t = os.time()
	local growthPotion = (data.boostExpiry.growth or 0) > t
	local luckPotion = (data.boostExpiry.luck or 0) > t
	return {
		sell = Economy.sellMultiplier({
			rebirths = data.rebirths,
			doubleCoins = Monetization.owns(player, "double_coins"),
			vip = Monetization.owns(player, "vip"),
			premium = isPremium(player),
			friends = friendsInServer(player),
			inGroup = inGroup[player] == true,
		}),
		growth = Economy.growthRate(
			Monetization.owns(player, "fast_grow"),
			growthPotion,
			Weather.growthMultiplier()
		),
		luck = Economy.luck(Monetization.owns(player, "lucky"), luckPotion),
	}
end

function Boosts.get(player: Player): Multipliers
	local cached = cache[player]
	if cached then
		return cached
	end
	local data = DataService.get(player)
	if not data then
		return { sell = 1, growth = 1, luck = 1 }
	end
	local fresh = compute(player, data)
	cache[player] = fresh
	return fresh
end

function Boosts.refresh(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local fresh = compute(player, data)
	local old = cache[player]
	cache[player] = fresh
	Sync.mark(player, "boosts")
	if not old or old.sell ~= fresh.sell or old.growth ~= fresh.growth or old.luck ~= fresh.luck then
		Boosts.Changed:Fire(player, fresh)
	end
end

local function refreshAll()
	for _, player in Players:GetPlayers() do
		Boosts.refresh(player)
	end
end

-- Adds `seconds` to a timed boost (stacks duration).
function Boosts.activate(player: Player, data: Profile, kind: string, seconds: number)
	local t = os.time()
	data.boostExpiry[kind] = math.max(data.boostExpiry[kind] or 0, t) + seconds
	Boosts.refresh(player)
end

local function serverTimeFor(unixTime: number): number
	return Workspace:GetServerTimeNow() + (unixTime - os.time())
end

local function buildSection(player: Player, data: Profile): any
	local multipliers = Boosts.get(player)
	local list: { Types.BoostEntry } = {}
	local t = os.time()
	for kind, label in POTIONS do
		local expiry = data.boostExpiry[kind] or 0
		if expiry > t then
			table.insert(list, {
				key = kind,
				label = label,
				icon = if kind == "luck" then "🔮" else "🧪",
				expiresAt = serverTimeFor(expiry),
			})
		end
	end
	local weather = Weathers.get(Weather.current())
	if weather and weather.growthMultiplier > 1 then
		table.insert(list, {
			key = "weather",
			label = `{weather.name} x{weather.growthMultiplier} growth`,
			icon = weather.icon,
			expiresAt = Weather.state().endsAt,
		})
	end
	local friends = friendsInServer(player)
	if friends > 0 then
		table.insert(list, {
			key = "friends",
			label = `{math.min(friends, Config.Bonuses.MaxFriends)} friend(s) +{math.floor(
				Config.Bonuses.FriendBonus * math.min(friends, Config.Bonuses.MaxFriends) * 100
			)}% coins`,
			icon = "🤝",
		})
	end
	if isPremium(player) then
		table.insert(list, { key = "premium", label = "Premium +10% coins", icon = "⭐" })
	end
	if inGroup[player] then
		table.insert(list, { key = "group", label = "Group member +10% coins", icon = "🏠" })
	end
	return {
		multipliers = multipliers,
		list = list,
		premium = isPremium(player),
		groupEnabled = Config.GroupId ~= 0,
		inGroup = inGroup[player] == true,
	}
end

local function loadSocial(player: Player)
	local known: { [number]: boolean } = {}
	friendCache[player] = known
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWith(other.UserId)
			end)
			if ok and isFriend then
				known[other.UserId] = true
				local otherKnown = friendCache[other]
				if otherKnown then
					otherKnown[player.UserId] = true
				end
			end
		end
	end
	if Config.GroupId ~= 0 then
		local ok, member = pcall(function()
			return player:IsInGroup(Config.GroupId)
		end)
		inGroup[player] = ok and member == true
	end
	refreshAll()
end

local function onUsePotion(player: Player, kind: unknown)
	if not RateLimiter.allow(player, "UsePotion", 2, 4) then
		return
	end
	local data = DataService.get(player)
	local potion = Validate.shortString(kind, 16)
	if not data or not potion or not POTIONS[potion] then
		return
	end
	local count = data.potions[potion] or 0
	if count < 1 then
		return
	end
	if count > 1 then
		data.potions[potion] = count - 1
	else
		data.potions[potion] = nil
	end
	Boosts.activate(player, data, potion, Config.Boosts.PotionDuration)
	Notify.player(player, `{POTIONS[potion]} active for 15 minutes!`, "success")
	Sync.mark(player, "main")
end

local function potionProduct(kind: string): Monetization.ProductHandler
	return function(player: Player, data: Profile): boolean
		Boosts.activate(player, data, kind, Config.Boosts.PotionDuration)
		Notify.player(player, `{POTIONS[kind]} active! +15 minutes. Thank you 💚`, "reward")
		return true
	end
end

function Boosts.init()
	Sync.register("boosts", buildSection)
	Monetization.registerProduct("growth_potion", potionProduct("growth"))
	Monetization.registerProduct("luck_potion", potionProduct("luck"))
end

function Boosts.start()
	Monetization.PlayerReady:Connect(function(player, data)
		-- Potions that ran out while offline expire silently.
		local t = os.time()
		for kind, expiry in data.boostExpiry do
			if expiry <= t then
				data.boostExpiry[kind] = nil
			end
		end
		Boosts.refresh(player)
		task.spawn(loadSocial, player)
	end)
	Monetization.PassesChanged:Connect(function(player)
		Boosts.refresh(player)
	end)
	Weather.Changed:Connect(refreshAll)
	Players.PlayerMembershipChanged:Connect(function(player)
		Boosts.refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
		friendCache[player] = nil
		inGroup[player] = nil
		-- Defer so the leaving player is no longer counted as a friend in server.
		task.defer(refreshAll)
	end)
	Net.event("UsePotion").OnServerEvent:Connect(onUsePotion)

	-- Expire timed boosts.
	task.spawn(function()
		while true do
			task.wait(1)
			local t = os.time()
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				local cached = cache[player]
				if data and cached then
					for kind, label in POTIONS do
						local expiry = data.boostExpiry[kind]
						if expiry and expiry <= t then
							data.boostExpiry[kind] = nil
							Notify.player(player, `{label} has worn off.`, "info")
							Boosts.refresh(player)
						end
					end
				end
			end
		end
	end)
end

return Boosts
