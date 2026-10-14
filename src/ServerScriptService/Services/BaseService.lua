--[[
	BaseService  (ModuleScript)  ->  ServerScriptService/Services/BaseService
	Basen vergeben, Slots darstellen, Figuren platzieren/verkaufen,
	Cash-Pad, Schloss (serverseitig durchgesetzt), Spawn in der eigenen Basis.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Figures = require(Shared:WaitForChild("Figures"))
local Format = require(Shared:WaitForChild("Format"))
local FigureBuilder = require(Shared:WaitForChild("FigureBuilder"))

local BaseService = {}
local Services

local TOTAL_SLOTS = 21
local FLOOR_COLORS = {
	Color3.fromRGB(255, 170, 200), Color3.fromRGB(170, 210, 255), Color3.fromRGB(190, 255, 190), Color3.fromRGB(255, 230, 150),
	Color3.fromRGB(220, 190, 255), Color3.fromRGB(255, 200, 160), Color3.fromRGB(160, 240, 230), Color3.fromRGB(240, 240, 240),
}

local bases = {} -- [plotIndex] = entry
local playerBase = {} -- [player] = entry
local lastEjectNotify = {}

------------------------------------------------------------------------
-- Hilfsfunktionen
------------------------------------------------------------------------
local function now()
	return os.clock()
end

local function getRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

function BaseService.GetBase(player)
	return playerBase[player]
end

function BaseService.IsInside(entry, position)
	if not entry or not entry.Model then
		return false
	end
	local zone = entry.Model:FindFirstChild("Zone")
	if not zone then
		return false
	end
	local rel = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

function BaseService.IsPlayerInOwnBase(player)
	local root = getRoot(player)
	return root ~= nil and BaseService.IsInside(playerBase[player], root.Position)
end

function BaseService.IsLocked(player)
	local entry = playerBase[player]
	return entry ~= nil and entry.LockedUntil > now()
end

function BaseService.GetLockRemaining(player)
	local entry = playerBase[player]
	if not entry then
		return 0
	end
	return math.max(0, entry.LockedUntil - now())
end

function BaseService.GetLockDuration(player)
	local data = Services.DataService.Get(player)
	local rebirths = data and data.Rebirths or 0
	return math.min(Config.Lock.BaseDuration + Config.Lock.PerRebirth * rebirths, Config.Lock.MaxDuration)
end

------------------------------------------------------------------------
-- Slots
------------------------------------------------------------------------
function BaseService.IsSlotUnlocked(player, index)
	local data = Services.DataService.Get(player)
	if not data then
		return false
	end
	if index <= Config.BaseSlots then
		return true
	elseif index <= Config.BaseSlots + Config.MaxRebirthSlots then
		return index - Config.BaseSlots <= math.min(data.Rebirths, Config.MaxRebirthSlots)
	elseif index <= 20 then
		return Services.MonetizationService.HasPass(player, "ExtraSlots")
	elseif index == Config.PremiumSlot then
		return Services.MonetizationService.IsPremium(player)
	end
	return false
end

function BaseService.GetCapacity(player)
	local count = 0
	for i = 1, TOTAL_SLOTS do
		if BaseService.IsSlotUnlocked(player, i) then
			count += 1
		end
	end
	return count
end

function BaseService.FindFreeSlot(player)
	local data = Services.DataService.Get(player)
	if not data then
		return nil
	end
	for i = 1, TOTAL_SLOTS do
		if BaseService.IsSlotUnlocked(player, i) and data.Slots[tostring(i)] == nil then
			return i
		end
	end
	return nil
end

local function clearSlotExtras(slotPart)
	for _, child in ipairs(slotPart:GetChildren()) do
		if child.Name == "SlotLock" or child.Name == "UpsellPrompt" then
			child:Destroy()
		end
	end
end

local function renderSlotPart(player, entry, index)
	local slotPart = entry.Model.Slots:FindFirstChild("Slot" .. index)
	if not slotPart then
		return
	end
	clearSlotExtras(slotPart)
	local unlocked = BaseService.IsSlotUnlocked(player, index)
	if index == Config.PremiumSlot then
		slotPart.Transparency = unlocked and 0 or 0.4
	else
		slotPart.Color = unlocked and Color3.new(1, 1, 1) or Color3.fromRGB(60, 60, 70)
		slotPart.Transparency = unlocked and 0 or 0.4
	end
	if unlocked then
		return
	end

	local text, upsell
	if index <= Config.BaseSlots + Config.MaxRebirthSlots then
		text = "⭐ Rebirth " .. (index - Config.BaseSlots)
	elseif index <= 20 then
		text = "🏠 Game Pass"
		upsell = { Action = "Slots holen", Object = "+5 Basis-Slots", Kind = "Pass" }
	else
		text = "👑 Premium"
		upsell = { Action = "Premium holen", Object = "Premium-Slot + 10% Cash", Kind = "Premium" }
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "SlotLock"
	gui.Size = UDim2.new(5, 0, 1.5, 0)
	gui.StudsOffset = Vector3.new(0, 1.5, 0)
	gui.MaxDistance = 50
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = slotPart

	if upsell then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "UpsellPrompt"
		prompt.ActionText = upsell.Action
		prompt.ObjectText = upsell.Object
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("OwnerId", player.UserId)
		CollectionService:AddTag(prompt, "OwnerOnlyPrompt")
		prompt.Triggered:Connect(function(who)
			if who ~= player then
				return
			end
			if upsell.Kind == "Pass" then
				Services.MonetizationService.PromptPass(player, "ExtraSlots")
			else
				Services.MonetizationService.PromptPremium(player)
			end
		end)
		prompt.Parent = slotPart
	end
end

function BaseService.RenderSlot(player, index)
	local entry = playerBase[player]
	local data = Services.DataService.Get(player)
	if not entry or not entry.Model or not data then
		return
	end
	local folder = entry.Model:FindFirstChild("Figures")
	local old = folder:FindFirstChild("Fig" .. index)
	if old then
		old:Destroy()
	end
	local slotData = data.Slots[tostring(index)]
	if not slotData then
		return
	end
	local slotPart = entry.Model.Slots:FindFirstChild("Slot" .. index)
	if not slotPart then
		return
	end
	local ghost = Services.StealService.IsBeingStolen(player, index)
	local model = FigureBuilder.Build(slotData.Id, slotData.Mut, { Mode = "Base", Ghost = ghost })
	if not model then
		return
	end
	model.Name = "Fig" .. index
	FigureBuilder.PlaceOn(model, slotPart.CFrame * CFrame.new(0, slotPart.Size.Y / 2, 0))
	model.Parent = folder
	if not ghost then
		Services.StealService.AttachPrompts(model, player, index)
	end
end

function BaseService.UpdateSign(player)
	local entry = playerBase[player]
	local data = Services.DataService.Get(player)
	if not entry or not data then
		return
	end
	local label = entry.Model.Sign.SignGui.Label
	local stars = data.Rebirths > 0 and ("  ⭐" .. data.Rebirths) or ""
	label.Text = "Basis von " .. player.DisplayName .. stars
end

function BaseService.RenderAll(player)
	local entry = playerBase[player]
	if not entry then
		return
	end
	for i = 1, TOTAL_SLOTS do
		renderSlotPart(player, entry, i)
		BaseService.RenderSlot(player, i)
	end
	BaseService.UpdateSign(player)
end

function BaseService.UpdateCashPad(player, pending)
	local entry = playerBase[player]
	if not entry then
		return
	end
	local label = entry.Model.CashPad.CashGui.Label
	if Services.MonetizationService.HasPass(player, "AutoCollect") then
		label.Text = "🧲 Auto-Collect"
	else
		label.Text = Format.Money(pending)
	end
end

------------------------------------------------------------------------
-- Figuren geben / nehmen / verkaufen
------------------------------------------------------------------------
function BaseService.GiveFigure(player, id, mutation)
	local data = Services.DataService.Get(player)
	local slot = BaseService.FindFreeSlot(player)
	if not data or not slot then
		return nil
	end
	data.Slots[tostring(slot)] = { Id = id, Mut = mutation or "Normal" }
	data.Index[Figures.IndexKey(id, mutation)] = true
	BaseService.RenderSlot(player, slot)
	Services.StateService.MarkDirty(player)
	return slot
end

function BaseService.RemoveFigure(player, index)
	local data = Services.DataService.Get(player)
	if not data then
		return
	end
	data.Slots[tostring(index)] = nil
	BaseService.RenderSlot(player, index)
	Services.StateService.MarkDirty(player)
end

function BaseService.Sell(player, index)
	index = tonumber(index)
	if not index or index ~= math.floor(index) or index < 1 or index > TOTAL_SLOTS then
		return false, "Ungültiger Slot"
	end
	local data = Services.DataService.Get(player)
	local slotData = data and data.Slots[tostring(index)]
	if not slotData then
		return false, "Slot ist leer"
	end
	if Services.StealService.IsBeingStolen(player, index) then
		return false, "Wird gerade gestohlen!"
	end
	local value = Figures.SellValue(slotData.Id, slotData.Mut)
	data.Cash += value
	BaseService.RemoveFigure(player, index)
	Services.RewardService.AddProgress(player, "Sell", 1)
	Services.Net.Notify(player, ("Verkauft: %s für %s"):format(Figures.DisplayName(slotData.Id, slotData.Mut), Format.Money(value)), "cash", "Sell")
	return true
end

------------------------------------------------------------------------
-- Schloss
------------------------------------------------------------------------
local function setDoorVisual(entry, locked)
	local door = entry.Model.LaserDoor
	door.Transparency = locked and 0.35 or 1
	door.DoorGui.Enabled = locked
	entry.Model.LockButton.Color = locked and Color3.fromRGB(60, 220, 90) or Color3.fromRGB(255, 60, 60)
end

function BaseService.Lock(player)
	local entry = playerBase[player]
	if not entry then
		return false, "Keine Basis"
	end
	if entry.LockedUntil > now() then
		return false, "Schon abgeschlossen"
	end
	entry.LockedUntil = now() + BaseService.GetLockDuration(player)
	Services.RewardService.AddProgress(player, "Lock", 1)
	Services.Net.Notify(player, "🔒 Basis abgeschlossen!", "success", "Lock")
	Services.StateService.MarkDirty(player)
	return true
end

function BaseService.ExtendLock(player, seconds)
	local entry = playerBase[player]
	if not entry then
		return
	end
	entry.LockedUntil = math.max(now(), entry.LockedUntil) + seconds
	Services.StateService.MarkDirty(player)
end

local function ejectIntruders(entry)
	local outside = entry.Model:GetPivot() * CFrame.new(0, 4, -37)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= entry.Owner then
			local root = getRoot(other)
			if root and BaseService.IsInside(entry, root.Position) then
				Services.StealService.NotifyTeleport(other)
				other.Character:PivotTo(outside)
				if not lastEjectNotify[other] or now() - lastEjectNotify[other] > 3 then
					lastEjectNotify[other] = now()
					Services.Net.Notify(other, "🔒 Diese Basis ist abgeschlossen!", "error", "Error")
				end
			end
		end
	end
end

local function lockLoop()
	while true do
		task.wait(0.2)
		for _, entry in pairs(bases) do
			local owner = entry.Owner
			if owner and entry.Model then
				local remaining = entry.LockedUntil - now()
				local locked = remaining > 0
				if locked ~= entry.WasLocked then
					entry.WasLocked = locked
					setDoorVisual(entry, locked)
					if not locked then
						Services.Net.Notify(owner, "🔓 Dein Schloss ist offen! Diebe können rein!", "warning", "Unlock", "LockExtend")
					end
					Services.StateService.MarkDirty(owner)
				end
				local lockLabel = entry.Model.LockButton.LockGui.Label
				if locked then
					local text = "🔒 " .. Format.Time(remaining)
					entry.Model.LaserDoor.DoorGui.Label.Text = text
					lockLabel.Text = text
					ejectIntruders(entry)
				else
					lockLabel.Text = "🔓 Abschließen"
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- Laufgeschwindigkeit & Spawn
------------------------------------------------------------------------
function BaseService.GetNormalWalkSpeed(player)
	if Services.MonetizationService.HasPass(player, "Speed") then
		return Config.SpeedPassWalkSpeed
	end
	return Config.WalkSpeed
end

function BaseService.ApplyWalkSpeed(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and not Services.StealService.IsCarrying(player) and not Services.StealService.IsStunned(player) then
		humanoid.WalkSpeed = BaseService.GetNormalWalkSpeed(player)
	end
end

local function spawnAtBase(player, character)
	local entry = playerBase[player]
	if not entry then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	task.wait()
	local spawnPart = entry.Model:FindFirstChild("SpawnPoint")
	if spawnPart and character.Parent then
		Services.StealService.NotifyTeleport(player)
		character:PivotTo(spawnPart.CFrame * CFrame.new(0, 3, 0))
	end
	BaseService.ApplyWalkSpeed(player)
end

------------------------------------------------------------------------
-- Zuweisen / Freigeben
------------------------------------------------------------------------
local function assignBase(player)
	local template = ServerStorage:FindFirstChild("BaseTemplate")
	if not template then
		warn("[BaseService] ServerStorage.BaseTemplate fehlt! SetupWorld ausführen.")
		return
	end
	local entry
	for i = 1, #bases do
		if not bases[i].Owner then
			entry = bases[i]
			break
		end
	end
	if not entry then
		player:Kick("Dieser Server ist voll. Bitte tritt erneut bei!")
		return
	end

	local model = template:Clone()
	model.Name = "Base" .. entry.Index
	model:PivotTo(entry.Plot.CFrame)
	local figures = Instance.new("Folder")
	figures.Name = "Figures"
	figures.Parent = model
	model.Floor.Color = FLOOR_COLORS[(entry.Index - 1) % #FLOOR_COLORS + 1]
	model:SetAttribute("OwnerId", player.UserId)
	model.Parent = Workspace:WaitForChild("Bases")

	entry.Model = model
	entry.Owner = player
	entry.LockedUntil = 0
	entry.WasLocked = false
	playerBase[player] = entry

	local connections = {}
	table.insert(connections, model.CashPad.Touched:Connect(function(hit)
		local who = Players:GetPlayerFromCharacter(hit.Parent)
		if who ~= player or not Services.RateLimit.Allow(player, "CashPad", 1, 0.5) then
			return
		end
		local root = getRoot(player)
		if root and (root.Position - model.CashPad.Position).Magnitude < 12 then
			Services.IncomeService.Collect(player)
		end
	end))
	table.insert(connections, model.LockButton.Touched:Connect(function(hit)
		local who = Players:GetPlayerFromCharacter(hit.Parent)
		if who ~= player or not Services.RateLimit.Allow(player, "LockPad", 1, 1) then
			return
		end
		local root = getRoot(player)
		if root and (root.Position - model.LockButton.Position).Magnitude < 10 and not BaseService.IsLocked(player) then
			BaseService.Lock(player)
		end
	end))
	table.insert(connections, player.CharacterAdded:Connect(function(character)
		spawnAtBase(player, character)
	end))
	entry.Connections = connections

	BaseService.RenderAll(player)
	local data = Services.DataService.Get(player)
	BaseService.UpdateCashPad(player, data and data.Pending or 0)
	if player.Character then
		task.spawn(spawnAtBase, player, player.Character)
	end
end

local function releaseBase(player)
	local entry = playerBase[player]
	if not entry then
		return
	end
	for _, connection in ipairs(entry.Connections or {}) do
		connection:Disconnect()
	end
	if entry.Model then
		entry.Model:Destroy()
	end
	entry.Model = nil
	entry.Owner = nil
	entry.LockedUntil = 0
	entry.Connections = nil
	playerBase[player] = nil
	lastEjectNotify[player] = nil
end

function BaseService.Init(services)
	Services = services
	local plots = Workspace:WaitForChild("Plots")
	for i = 1, 8 do
		local plot = plots:FindFirstChild("Plot" .. i)
		if plot then
			table.insert(bases, { Index = i, Plot = plot, LockedUntil = 0 })
		end
	end
	if #bases == 0 then
		warn("[BaseService] Keine Plots gefunden! SetupWorld ausführen.")
	end
end

function BaseService.Start()
	Services.Net.Register("ToggleLock", function(player)
		return BaseService.Lock(player)
	end, 2)
	Services.Net.Register("Sell", function(player, index)
		return BaseService.Sell(player, index)
	end, 5)

	Services.DataService.OnLoaded(assignBase)
	Services.DataService.OnReleasing(releaseBase)
	task.spawn(lockLoop)
end

return BaseService
