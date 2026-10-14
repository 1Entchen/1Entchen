--!strict
-- Client mirror of the player's server state. UI reads from here and
-- listens to Changed; it never computes authoritative values.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Types"))

local State = {}

-- Sections: main, backpack, boosts, passes, daily, shop (see server Sync).
State.sections = {} :: { [string]: any }
State.stock = nil :: Types.StockState?
State.weather = nil :: Types.WeatherState?

State.Changed = Signal.new() :: Signal.Signal<string>

function State.get(section: string): any
	return State.sections[section]
end

function State.main(): any
	return State.sections.main
end

function State.owns(passKey: string): boolean
	local passes = State.sections.passes
	return passes ~= nil and passes[passKey] == true
end

function State.start()
	Net.event("Sync").OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		for section, value in payload do
			State.sections[section] = value
			State.Changed:Fire(section)
		end
	end)
	Net.event("Stock").OnClientEvent:Connect(function(stock: any)
		State.stock = stock
		State.Changed:Fire("stock")
	end)
	Net.event("Weather").OnClientEvent:Connect(function(weather: any)
		State.weather = weather
		State.Changed:Fire("weather")
	end)
	Net.event("RequestSync"):FireServer()
end

return State
