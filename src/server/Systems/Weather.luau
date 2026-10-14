--!strict
-- Server-wide weather events on a randomized timer, plus purchasable
-- "summon" events that benefit everyone in the server (social, non-random,
-- clearly described in the store).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Types"))
local Weathers = require(Shared:WaitForChild("Weathers"))

local Util = script.Parent.Parent:WaitForChild("Util")
local Notify = require(Util:WaitForChild("Notify"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

local Monetization = require(script.Parent.Monetization)

type WeatherState = Types.WeatherState

local Weather = {}

Weather.Changed = Signal.new() :: Signal.Signal<string?>

type QueuedEvent = { id: string, summonedBy: string }

local random = Random.new()
local state: WeatherState = {
	id = nil,
	endsAt = 0,
	summonedBy = nil,
	nextAt = 0,
}
local queue: { QueuedEvent } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

function Weather.current(): string?
	return state.id
end

function Weather.state(): WeatherState
	return state
end

function Weather.growthMultiplier(): number
	local weather = Weathers.get(state.id)
	return if weather then weather.growthMultiplier else 1
end

local function broadcast()
	Net.event("Weather"):FireAllClients(state)
end

local function startEvent(id: string, summonedBy: string?)
	local weather = Weathers.get(id)
	if not weather then
		return
	end
	state.id = id
	state.endsAt = now() + Config.Weather.Duration
	state.summonedBy = summonedBy
	broadcast()
	if summonedBy then
		Notify.all(
			`{weather.icon} {summonedBy} summoned {weather.name} for everyone! {weather.description}`,
			weather.tint
		)
	else
		Notify.all(`{weather.icon} {weather.name} has started! {weather.description}`, weather.tint)
	end
	Weather.Changed:Fire(id)
end

local function endEvent()
	state.id = nil
	state.summonedBy = nil
	state.nextAt = now() + random:NextNumber(Config.Weather.MinInterval, Config.Weather.MaxInterval)
	broadcast()
	Weather.Changed:Fire(nil)
end

-- Summoned events start immediately if the sky is clear, otherwise right
-- after the current event; the buyer is told which.
function Weather.queue(id: string, summonedBy: string): boolean
	if not Weathers.get(id) then
		return false
	end
	if state.id == nil then
		startEvent(id, summonedBy)
	else
		table.insert(queue, { id = id, summonedBy = summonedBy })
	end
	return true
end

local function loop()
	while true do
		task.wait(1)
		local t = now()
		if state.id then
			if t >= state.endsAt then
				endEvent()
			end
		elseif #queue > 0 then
			local nextEvent = table.remove(queue, 1) :: QueuedEvent
			startEvent(nextEvent.id, nextEvent.summonedBy)
		elseif t >= state.nextAt then
			startEvent(Weathers.pick(random:NextNumber()), nil)
		end
	end
end

local function summonHandler(id: string): Monetization.ProductHandler
	return function(player: Player)
		local weather = Weathers.get(id)
		if not weather then
			return false
		end
		local startsNow = state.id == nil
		Weather.queue(id, player.DisplayName)
		if not startsNow then
			Notify.player(
				player,
				`{weather.icon} {weather.name} will start right after the current weather. Thank you!`,
				"reward"
			)
		end
		return true
	end
end

function Weather.init()
	state.nextAt = now() + random:NextNumber(90, 180) -- first event early in a server's life
	Monetization.registerProduct("weather_goorain", summonHandler("goorain"))
	Monetization.registerProduct("weather_starfall", summonHandler("starfall"))
end

function Weather.start()
	Net.event("RequestSync").OnServerEvent:Connect(function(player)
		if RateLimiter.allow(player, "RequestSyncWeather", 0.2, 2) then
			Net.event("Weather"):FireClient(player, state)
		end
	end)
	task.spawn(loop)
end

-- Test / QA hook.
function Weather._force(id: string?)
	if id then
		startEvent(id, nil)
	else
		endEvent()
	end
end

return Weather
