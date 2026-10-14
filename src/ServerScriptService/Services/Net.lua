--[[
	Net  (ModuleScript)  ->  ServerScriptService/Services/Net
	Erstellt alle Remotes und leitet Client-Anfragen an registrierte Handler weiter.
	Der Client darf nur Wünsche schicken, jede Aktion wird hier gefiltert:
	  - nur registrierte Aktionsnamen
	  - Rate-Limit pro Spieler und Aktion
	  - Fehler im Handler werden abgefangen
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}
local Services
local handlers = {}

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function remote(className, name)
	local existing = remotesFolder:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotesFolder
	return r
end

Net.StateUpdate = remote("RemoteEvent", "StateUpdate")
Net.NotifyEvent = remote("RemoteEvent", "Notify")
Net.AnnounceEvent = remote("RemoteEvent", "Announce")
Net.EffectEvent = remote("RemoteEvent", "Effect")
Net.Request = remote("RemoteFunction", "Request")

-- handler(player, payload) -> ok, message
function Net.Register(action, handler, maxPerSecond)
	handlers[action] = { Fn = handler, Max = maxPerSecond or 5 }
end

function Net.Notify(player, text, kind, sound, offer)
	Net.NotifyEvent:FireClient(player, text, kind or "info", sound, offer)
end

function Net.NotifyAll(text, kind, sound)
	Net.NotifyEvent:FireAllClients(text, kind or "info", sound)
end

function Net.Announce(text, color)
	Net.AnnounceEvent:FireAllClients(text, color or Color3.fromRGB(255, 220, 80))
end

function Net.Effect(player, kind, payload)
	Net.EffectEvent:FireClient(player, kind, payload)
end

function Net.EffectAll(kind, payload)
	Net.EffectEvent:FireAllClients(kind, payload)
end

function Net.Init(services)
	Services = services
end

function Net.Start()
	Net.Request.OnServerInvoke = function(player, action, payload)
		if type(action) ~= "string" then
			return false, "Ungültig"
		end
		local entry = handlers[action]
		if not entry then
			return false, "Unbekannte Aktion"
		end
		if not Services.RateLimit.Allow(player, "Req_" .. action, entry.Max, 1) then
			return false, "Langsamer!"
		end
		if not Services.DataService.Get(player) then
			return false, "Daten laden noch …"
		end
		local ok, result, message = pcall(entry.Fn, player, payload)
		if not ok then
			warn("[Net] Fehler in", action, result)
			return false, "Serverfehler"
		end
		return result, message
	end
end

return Net
