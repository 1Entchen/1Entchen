--!strict
-- The single client entry point.

local Controllers = script:WaitForChild("Controllers")
local UI = script:WaitForChild("UI")

local Kit = require(UI:WaitForChild("Kit"))
local State = require(script:WaitForChild("State"))

local ORDER = {
	"Sounds",
	"Notifications",
	"GardenView",
	"HUD",
	"ShopWindow",
	"BackpackWindow",
	"StoreWindow",
	"IndexWindow",
	"RewardsWindow",
	"RebirthWindow",
	"Tutorial",
	"WeatherFX",
	"ChatTags",
	"DevPanel",
}

type Controller = { start: (() -> ())? }

local Sounds = require(Controllers:WaitForChild("Sounds")) :: any
Kit.setClickSound(function()
	Sounds.play("Click")
end)

for _, name in ORDER do
	local module = Controllers:WaitForChild(name) :: ModuleScript
	local controller = (require :: any)(module) :: Controller
	if controller.start then
		task.spawn(function()
			local ok, err = pcall(controller.start :: any)
			if not ok then
				warn(`[Client] {name}.start failed: {err}`)
			end
		end)
	end
end

-- Ask for a full state push once every controller is listening.
task.defer(State.start)
