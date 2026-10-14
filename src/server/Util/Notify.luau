--!strict
-- Server -> client feedback helpers (toasts, announcements, effects).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

export type Kind = "info" | "success" | "error" | "reward"

local Notify = {}

function Notify.player(player: Player, text: string, kind: Kind?)
	Net.event("Notify"):FireClient(player, text, kind or "info")
end

function Notify.all(text: string, color: Color3?)
	Net.event("Announce"):FireAllClients(text, color)
end

function Notify.effect(player: Player, kind: string, data: { [string]: any })
	Net.event("Effect"):FireClient(player, kind, data)
end

function Notify.effectAll(kind: string, data: { [string]: any })
	for _, player in Players:GetPlayers() do
		Net.event("Effect"):FireClient(player, kind, data)
	end
end

return Notify
