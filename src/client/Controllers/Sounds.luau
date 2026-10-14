--!strict
-- Local sound effects with slight pitch variation to avoid fatigue.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sounds = {}

local cache: { [string]: Sound } = {}

local VOLUMES: { [string]: number } = {
	Click = 0.35,
	Plant = 0.5,
	Harvest = 0.45,
	Sell = 0.6,
	Rare = 0.6,
	Error = 0.25,
}

function Sounds.play(name: string, pitch: number?)
	local id = (Config.Sounds :: { [string]: string })[name]
	if not id or id == "" then
		return
	end
	local sound = cache[name]
	if not sound then
		local newSound = Instance.new("Sound")
		newSound.Name = "Sfx_" .. name
		newSound.SoundId = id
		newSound.Volume = VOLUMES[name] or 0.5
		newSound.Parent = SoundService
		cache[name] = newSound
		sound = newSound
	end
	sound.PlaybackSpeed = (pitch or 1) * (0.94 + math.random() * 0.12)
	SoundService:PlayLocalSound(sound)
end

return Sounds
