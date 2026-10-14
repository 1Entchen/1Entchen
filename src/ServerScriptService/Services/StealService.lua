--[[
	StealService  (ModuleScript)  ->  ServerScriptService/Services/StealService
	Diebstahl (ProximityPrompt halten -> Figur tragen -> in eigene Basis bringen),
	Verkaufen-Prompt für den Besitzer, Klatsche (Abwehr), Neuling-Schutz.
	Anti-Exploit: Haltezeit, Distanz, Cooldown, Geschwindigkeit beim Tragen.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Figures = require(Shared:WaitForChild("Figures"))
local Format = require(Shared:WaitForChild("Format"))
local FigureBuilder = require(Shared:WaitForChild("FigureBuilder"))

local StealService = {}
local Services

local carrying = {} -- [thief] = carry entry
local beingStolen = {} -- [owner] = { [slot] = thief }
local stealCooldown = {} -- [thief] = os.clock()
local holdStart = {} -- [player] = { Prompt, Time }
local protectedUntil = {} -- [player] = os.clock()
local stunnedUntil = {} -- [player] = os.clock()
local bonkCooldown = {} -- [player] = os.clock()
local ignoreMoveUntil = {} -- [player] = os.clock()

local function getRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function StealService.IsCarrying(player)
	return carrying[player] ~= nil
end

function StealService.IsStunned(player)
	return (stunnedUntil[player] or 0) > os.clock()
end

function StealService.IsBeingStolen(owner, slot)
	local list = beingStolen[owner]
	return list ~= nil and list[slot] ~= nil
end

function StealService.GetProtectionRemaining(player)
	return math.max(0, (protectedUntil[player] or 0) - os.clock())
end

function StealService.NotifyTeleport(player)
	ignoreMoveUntil[player] = os.clock() + 1
	local entry = carrying[player]
	if entry then
		entry.LastPos = nil
	end
end

------------------------------------------------------------------------
-- Prompts an platzierten Figuren
------------------------------------------------------------------------
function StealService.AttachPrompts(model, owner, slot)
	local root = model.PrimaryPart
	local slotData = Services.DataService.Get(owner).Slots[tostring(slot)]
	if not slotData then
		return
	end

	local steal = Instance.new("ProximityPrompt")
	steal.Name = "StealPrompt"
	steal.ActionText = "Stehlen"
	steal.ObjectText = Figures.DisplayName(slotData.Id, slotData.Mut)
	steal.HoldDuration = Config.Steal.HoldTime
	steal.MaxActivationDistance = Config.Steal.PromptDistance
	steal.RequiresLineOfSight = false
	steal.KeyboardKeyCode = Enum.KeyCode.E
	steal:SetAttribute("OwnerId", owner.UserId)
	CollectionService:AddTag(steal, "StealPrompt")
	steal.PromptButtonHoldBegan:Connect(function(player)
		holdStart[player] = { Prompt = steal, Time = os.clock() }
	end)
	steal.Triggered:Connect(function(player)
		StealService.TryStart(player, owner, slot, steal)
	end)
	steal.Parent = root

	local sell = Instance.new("ProximityPrompt")
	sell.Name = "SellPrompt"
	sell.ActionText = "Verkaufen +" .. Format.Money(Figures.SellValue(slotData.Id, slotData.Mut))
	sell.ObjectText = Figures.DisplayName(slotData.Id, slotData.Mut)
	sell.HoldDuration = 0.6
	sell.MaxActivationDistance = 8
	sell.RequiresLineOfSight = false
	sell.KeyboardKeyCode = Enum.KeyCode.F
	sell:SetAttribute("OwnerId", owner.UserId)
	CollectionService:AddTag(sell, "OwnerOnlyPrompt")
	sell.Triggered:Connect(function(player)
		if player == owner then
			Services.BaseService.Sell(owner, slot)
		end
	end)
	sell.Parent = root
end

------------------------------------------------------------------------
-- Diebstahl starten
------------------------------------------------------------------------
local function carrySpeed(player)
	local mult = Services.MonetizationService.HasPass(player, "MasterThief") and Config.Steal.MasterCarrySpeedMult or Config.Steal.CarrySpeedMult
	return Services.BaseService.GetNormalWalkSpeed(player) * mult
end

function StealService.TryStart(thief, owner, slot, prompt)
	if thief == owner or not owner.Parent then
		return
	end
	if not Services.RateLimit.Allow(thief, "Steal", 2, 1) then
		return
	end
	local thiefData = Services.DataService.Get(thief)
	local ownerData = Services.DataService.Get(owner)
	if not thiefData or not ownerData then
		return
	end

	-- Haltezeit serverseitig prüfen (Exploiter könnten das Halten überspringen)
	local hold = holdStart[thief]
	holdStart[thief] = nil
	local required = Services.MonetizationService.HasPass(thief, "MasterThief") and Config.Steal.MasterHoldTime or Config.Steal.HoldTime
	if not hold or hold.Prompt ~= prompt or os.clock() - hold.Time < required - 0.35 then
		return
	end

	if carrying[thief] then
		Services.Net.Notify(thief, "Du trägst schon eine Figur!", "error", "Error")
		return
	end
	local cooldown = (stealCooldown[thief] or 0) - os.clock()
	if cooldown > 0 then
		Services.Net.Notify(thief, ("Warte noch %ds bis zum nächsten Diebstahl"):format(math.ceil(cooldown)), "error", "Error")
		return
	end
	if Services.BaseService.IsLocked(owner) then
		Services.Net.Notify(thief, "Diese Basis ist abgeschlossen!", "error", "Error")
		return
	end
	local protection = StealService.GetProtectionRemaining(owner)
	if protection > 0 then
		Services.Net.Notify(thief, ("🛡 %s hat noch %s Neuling-Schutz"):format(owner.DisplayName, Format.Time(protection)), "error", "Error")
		return
	end
	local slotData = ownerData.Slots[tostring(slot)]
	if not slotData or StealService.IsBeingStolen(owner, slot) then
		return
	end
	local root = getRoot(thief)
	local ownerBase = Services.BaseService.GetBase(owner)
	local figModel = ownerBase and ownerBase.Model and ownerBase.Model.Figures:FindFirstChild("Fig" .. slot)
	if not root or not figModel or not figModel.PrimaryPart or (root.Position - figModel.PrimaryPart.Position).Magnitude > Config.Steal.PromptDistance + 4 then
		return
	end
	if not Services.BaseService.FindFreeSlot(thief) then
		local offer = if Services.MonetizationService.HasPass(thief, "ExtraSlots") then nil else "ExtraSlots"
		Services.Net.Notify(thief, "Deine Basis ist voll! Verkaufe erst eine Figur.", "error", "Error", offer)
		return
	end

	-- Start
	protectedUntil[thief] = 0
	beingStolen[owner] = beingStolen[owner] or {}
	beingStolen[owner][slot] = thief

	local carryModel = FigureBuilder.Build(slotData.Id, slotData.Mut, { Mode = "Carry" })
	local character = thief.Character
	if carryModel then
		carryModel.Name = "CarriedFigure"
		carryModel:PivotTo(root.CFrame * CFrame.new(0, 4.5, 0))
		for _, part in ipairs(carryModel:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.Massless = true
				part.CanCollide = false
			end
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = carryModel.PrimaryPart
		weld.Parent = carryModel.PrimaryPart
		carryModel.Parent = character
	end

	local tag = Instance.new("BillboardGui")
	tag.Name = "ThiefTag"
	tag.Size = UDim2.new(6, 0, 1.5, 0)
	tag.StudsOffset = Vector3.new(0, 7.5, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 200
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "🦹 DIEB!"
	label.TextColor3 = Color3.fromRGB(255, 60, 60)
	label.TextStrokeTransparency = 0
	label.Parent = tag
	tag.Parent = root

	carrying[thief] = {
		Owner = owner,
		Slot = slot,
		Id = slotData.Id,
		Mut = slotData.Mut,
		Model = carryModel,
		Tag = tag,
		Started = os.clock(),
		LastPos = root.Position,
		LastTime = os.clock(),
	}
	thief:SetAttribute("Carrying", true)
	local humanoid = getHumanoid(thief)
	if humanoid then
		humanoid.WalkSpeed = carrySpeed(thief)
	end

	Services.BaseService.RenderSlot(owner, slot)
	local name = Figures.DisplayName(slotData.Id, slotData.Mut)
	Services.Net.Notify(thief, "Bring " .. name .. " schnell in DEINE Basis!", "warning", "Steal")
	Services.Net.Notify(owner, ("⚠ %s klaut deinen %s! Hau ihn mit der Klatsche!"):format(thief.DisplayName, name), "error", "Alarm")
	Services.Net.Effect(owner, "Alarm", { Thief = thief.DisplayName })
	Services.StateService.MarkDirty(thief)
end

------------------------------------------------------------------------
-- Diebstahl beenden
------------------------------------------------------------------------
local function cleanup(thief, entry)
	carrying[thief] = nil
	if entry.Model then
		entry.Model:Destroy()
	end
	if entry.Tag then
		entry.Tag:Destroy()
	end
	local list = beingStolen[entry.Owner]
	if list then
		list[entry.Slot] = nil
	end
	if thief.Parent then
		thief:SetAttribute("Carrying", false)
		Services.BaseService.ApplyWalkSpeed(thief)
		Services.StateService.MarkDirty(thief)
	end
end

function StealService.Fail(thief, reason)
	local entry = carrying[thief]
	if not entry then
		return
	end
	cleanup(thief, entry)
	if entry.Owner.Parent then
		Services.BaseService.RenderSlot(entry.Owner, entry.Slot)
	end
	if reason and thief.Parent then
		Services.Net.Notify(thief, "❌ Diebstahl gescheitert: " .. reason, "error", "Error")
	end
	stealCooldown[thief] = os.clock() + Config.Steal.Cooldown * 0.5
end

local function succeed(thief, entry)
	local owner = entry.Owner
	local ownerData = Services.DataService.Get(owner)
	local thiefData = Services.DataService.Get(thief)
	local current = ownerData and ownerData.Slots[tostring(entry.Slot)]
	if not thiefData or not current or current.Id ~= entry.Id or current.Mut ~= entry.Mut then
		StealService.Fail(thief, "Figur nicht mehr da")
		return
	end
	local newSlot = Services.BaseService.FindFreeSlot(thief)
	if not newSlot then
		StealService.Fail(thief, "Deine Basis ist voll")
		return
	end

	cleanup(thief, entry)
	ownerData.Slots[tostring(entry.Slot)] = nil
	thiefData.Slots[tostring(newSlot)] = { Id = entry.Id, Mut = entry.Mut }
	thiefData.Index[Figures.IndexKey(entry.Id, entry.Mut)] = true
	thiefData.Stats.Steals += 1
	stealCooldown[thief] = os.clock() + Config.Steal.Cooldown

	Services.BaseService.RenderSlot(owner, entry.Slot)
	Services.BaseService.RenderSlot(thief, newSlot)
	Services.RewardService.AddProgress(thief, "Steal", 1)
	Services.StateService.MarkDirty(owner)
	Services.StateService.MarkDirty(thief)

	local name = Figures.DisplayName(entry.Id, entry.Mut)
	Services.Net.Notify(thief, "🦹 Erfolgreich gestohlen: " .. name .. "!", "success", "Reward")
	Services.Net.Effect(thief, "Reveal", { Id = entry.Id, Mut = entry.Mut, Text = "GESTOHLEN!" })
	Services.Net.Notify(owner, ("😭 %s hat deinen %s gestohlen! Schließ deine Basis ab!"):format(thief.DisplayName, name), "error", "Alarm", "LockExtend")
	Services.AnnouncementService.Found(thief, entry.Id, entry.Mut, "von " .. owner.DisplayName .. " gestohlen")
end

function StealService.CancelForOwner(owner, reason)
	for thief, entry in pairs(carrying) do
		if entry.Owner == owner then
			StealService.Fail(thief, reason)
		end
	end
end

local function carryLoop()
	while true do
		task.wait(0.15)
		local nowTime = os.clock()
		for thief, entry in pairs(carrying) do
			local root = getRoot(thief)
			local humanoid = getHumanoid(thief)
			if not thief.Parent or not root or not humanoid or humanoid.Health <= 0 then
				StealService.Fail(thief, "Du bist gestorben")
			elseif not entry.Owner.Parent then
				StealService.Fail(thief, "Besitzer hat das Spiel verlassen")
			elseif nowTime - entry.Started > Config.Steal.MaxCarryTime then
				StealService.Fail(thief, "Zu langsam!")
			else
				-- Geschwindigkeits-Check (Speed-Hacks)
				if entry.LastPos and nowTime > (ignoreMoveUntil[thief] or 0) then
					local dt = nowTime - entry.LastTime
					local delta = root.Position - entry.LastPos
					local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
					if dt > 0 and horizontal / dt > humanoid.WalkSpeed * 1.6 + 10 then
						StealService.Fail(thief, "Unerlaubte Bewegung erkannt")
						continue
					end
				end
				entry.LastPos = root.Position
				entry.LastTime = nowTime
				if Services.BaseService.IsPlayerInOwnBase(thief) then
					succeed(thief, entry)
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- Klatsche
------------------------------------------------------------------------
local function stun(target, seconds)
	stunnedUntil[target] = os.clock() + seconds
	local humanoid = getHumanoid(target)
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
	task.delay(seconds, function()
		if target.Parent and not StealService.IsStunned(target) then
			local h = getHumanoid(target)
			if h then
				h.JumpPower = 50
			end
			Services.BaseService.ApplyWalkSpeed(target)
		end
	end)
end

local function onBonk(player, tool)
	local nowTime = os.clock()
	if (bonkCooldown[player] or 0) > nowTime or StealService.IsStunned(player) then
		return
	end
	bonkCooldown[player] = nowTime + Config.Bonk.Cooldown

	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	game:GetService("Debris"):AddItem(anim, 1)

	local root = getRoot(player)
	if not root then
		return
	end
	local super = Services.MonetizationService.HasPass(player, "SuperBonk")
	local range = super and Config.Bonk.SuperRange or Config.Bonk.Range
	local stunTime = super and Config.Bonk.SuperStun or Config.Bonk.Stun

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local otherRoot = getRoot(other)
			if otherRoot then
				local offset = otherRoot.Position - root.Position
				local distance = offset.Magnitude
				local facing = distance < 4 or root.CFrame.LookVector:Dot(offset.Unit) > 0.2
				if distance <= range and facing then
					Services.RewardService.AddProgress(player, "Bonk", 1)
					Services.Net.Effect(other, "Bonked", { By = player.DisplayName })
					local entry = carrying[other]
					if entry then
						local name = Figures.DisplayName(entry.Id, entry.Mut)
						local ownerName = entry.Owner.DisplayName
						StealService.Fail(other, player.DisplayName .. " hat dich erwischt!")
						stun(other, stunTime)
						local data = Services.DataService.Get(player)
						if data then
							data.Stats.Defends += 1
						end
						Services.RewardService.AddProgress(player, "Defend", 1)
						Services.Net.Notify(player, "🛡 Dieb erwischt! " .. name .. " ist zurück bei " .. ownerName, "success", "Bonk")
						if entry.Owner ~= player and entry.Owner.Parent then
							Services.Net.Notify(entry.Owner, "🛡 " .. player.DisplayName .. " hat den Dieb erwischt!", "success", "Bonk")
						end
					end
				end
			end
		end
	end
end

local function watchCharacter(player, character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Klatsche" and not child:GetAttribute("Hooked") then
			child:SetAttribute("Hooked", true)
			child.Activated:Connect(function()
				if child.Parent == player.Character then
					onBonk(player, child)
				end
			end)
		end
	end)
end

------------------------------------------------------------------------
function StealService.Init(services)
	Services = services
end

function StealService.Start()
	Services.DataService.OnLoaded(function(player)
		protectedUntil[player] = os.clock() + Config.Steal.NewbieProtection
		if player.Character then
			watchCharacter(player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			if carrying[player] then
				StealService.Fail(player, "Du bist gestorben")
			end
			watchCharacter(player, character)
		end)
	end)

	Services.DataService.OnReleasing(function(player)
		if carrying[player] then
			StealService.Fail(player, nil)
		end
		StealService.CancelForOwner(player, "Besitzer hat das Spiel verlassen")
	end)

	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			beingStolen[player] = nil
			stealCooldown[player] = nil
			holdStart[player] = nil
			protectedUntil[player] = nil
			stunnedUntil[player] = nil
			bonkCooldown[player] = nil
			ignoreMoveUntil[player] = nil
		end)
	end)

	task.spawn(carryLoop)
end

return StealService
