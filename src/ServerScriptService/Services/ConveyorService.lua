--[[
	ConveyorService  (ModuleScript)  ->  ServerScriptService/Services/ConveyorService
	Spawnt Figuren auf dem Förderband (Seltenheit, Mutation, Pity, Lucky Spawn)
	und wickelt den Kauf ab. Alle Prüfungen passieren auf dem Server.
]]

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Figures = require(Shared:WaitForChild("Figures"))
local Format = require(Shared:WaitForChild("Format"))
local FigureBuilder = require(Shared:WaitForChild("FigureBuilder"))

local ConveyorService = {}
local Services

local rng = Random.new()
local active = {} -- [model] = entry
local activeCount = 0
local luckUntil = 0
local pityCounter = 0

local conveyor, folder, startCFrame, endCFrame

------------------------------------------------------------------------
-- Zufall
------------------------------------------------------------------------
local function weightedPick(items, weightOf)
	local total = 0
	for _, item in ipairs(items) do
		total += weightOf(item)
	end
	local roll = rng:NextNumber() * total
	for _, item in ipairs(items) do
		roll -= weightOf(item)
		if roll <= 0 then
			return item
		end
	end
	return items[#items]
end

function ConveyorService.IsLucky()
	return os.time() < luckUntil or Services.EventService.IsHappyHour()
end

function ConveyorService.GetLuckRemaining()
	return math.max(0, luckUntil - os.time())
end

function ConveyorService.AddLuck(seconds)
	luckUntil = math.max(os.time(), luckUntil) + seconds
	for _, player in ipairs(Services.DataService.GetLoadedPlayers()) do
		Services.StateService.MarkDirty(player)
	end
end

local function rollRarity()
	local lucky = ConveyorService.IsLucky()
	return weightedPick(Config.RarityOrder, function(name)
		local r = Config.Rarities[name]
		return lucky and r.LuckyWeight or r.Weight
	end)
end

local function rollMutation()
	local mult = ConveyorService.IsLucky() and Config.LuckyMutationMult or 1
	local roll = rng:NextNumber() * 100
	for i = #Config.MutationOrder, 2, -1 do
		local name = Config.MutationOrder[i]
		local chance = Config.Mutations[name].Chance * mult
		if roll < chance then
			return name
		end
		roll -= chance
	end
	return "Normal"
end

local function rollFigure(rarity)
	local fig = weightedPick(Figures.ByRarity[rarity], function(f)
		return f.Weight
	end)
	return fig.Id
end

------------------------------------------------------------------------
-- Spawnen
------------------------------------------------------------------------
local function removeEntry(model)
	if active[model] then
		active[model] = nil
		activeCount -= 1
	end
	if model.Parent then
		model:Destroy()
	end
end

local function spawnFigure(id, mutation, reservedFor)
	local fig = Figures.Get(id)
	local model = FigureBuilder.Build(id, mutation, { Mode = "Conveyor" })
	if not model then
		return
	end
	local price = Figures.Price(id, mutation)
	local entry = {
		Id = id,
		Mut = mutation,
		Price = price,
		Sold = false,
		ReservedFor = reservedFor and reservedFor.UserId or nil,
		ReservedName = reservedFor and reservedFor.DisplayName or nil,
		ReservedUntil = reservedFor and (os.clock() + Config.Conveyor.ReserveSeconds) or 0,
	}

	FigureBuilder.PlaceOn(model, startCFrame)
	local root = model.PrimaryPart

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Kaufen " .. Format.Money(price)
	prompt.ObjectText = Figures.DisplayName(id, mutation)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		ConveyorService.TryBuy(player, model)
	end)

	if entry.ReservedFor then
		local info = root:FindFirstChild("Info")
		if info then
			info.RarityLabel.Text = "🔒 für " .. entry.ReservedName
		end
	end

	active[model] = entry
	activeCount += 1
	model.Parent = folder

	local travelTarget = endCFrame * startCFrame:Inverse() * root.CFrame
	local tween = TweenService:Create(root, TweenInfo.new(Config.Conveyor.TravelTime, Enum.EasingStyle.Linear), { CFrame = travelTarget })
	entry.Tween = tween
	tween.Completed:Connect(function()
		if not entry.Sold then
			removeEntry(model)
		end
	end)
	tween:Play()

	-- Hype für seltene Spawns
	local rank = Config.Rarities[fig.Rarity].Rank
	if rank >= Config.Rarities.Mythic.Rank or mutation == "Rainbow" then
		Services.Net.Announce(("🚨 %s %s ist auf dem Förderband erschienen! SCHNELL!"):format(Config.Rarities[fig.Rarity].Display, Figures.DisplayName(id, mutation)), Config.Rarities[fig.Rarity].Color)
	end
	if rank >= Config.Rarities.Legendary.Rank then
		Services.Net.EffectAll("RareSpawn", { Id = id, Mut = mutation })
	end
end

function ConveyorService.ForceSpawn(rarity, forPlayer)
	spawnFigure(rollFigure(rarity), rollMutation(), forPlayer)
end

local function spawnTick()
	if activeCount >= Config.Conveyor.MaxFigures then
		return
	end
	local rarity = rollRarity()
	pityCounter += 1
	if Config.Rarities[rarity].Rank >= Config.Rarities.Legendary.Rank then
		pityCounter = 0
	elseif pityCounter >= Config.Conveyor.PityThreshold then
		rarity = "Legendary"
		pityCounter = 0
	end
	spawnFigure(rollFigure(rarity), rollMutation(), nil)
end

------------------------------------------------------------------------
-- Kaufen
------------------------------------------------------------------------
local function suggestCashPack(player, missing)
	for _, key in ipairs({ "CashSmall", "CashMedium", "CashLarge", "CashMega" }) do
		if Services.MonetizationService.CashPackAmount(player, Config.Products[key]) >= missing then
			return key
		end
	end
	return "CashMega"
end

function ConveyorService.TryBuy(player, model)
	local entry = active[model]
	if not entry or entry.Sold then
		return
	end
	if not Services.RateLimit.Allow(player, "Buy", 4, 1) then
		return
	end
	local data = Services.DataService.Get(player)
	if not data then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not model.PrimaryPart or (root.Position - model.PrimaryPart.Position).Magnitude > Config.Conveyor.BuyDistance then
		return
	end
	if Services.StealService.IsCarrying(player) then
		Services.Net.Notify(player, "Bring erst deine Beute nach Hause!", "error", "Error")
		return
	end
	if entry.ReservedFor and entry.ReservedFor ~= player.UserId and os.clock() < entry.ReservedUntil then
		Services.Net.Notify(player, ("Reserviert für %s (noch %ds)"):format(entry.ReservedName, math.ceil(entry.ReservedUntil - os.clock())), "error", "Error")
		return
	end
	if data.Cash < entry.Price then
		local missing = entry.Price - data.Cash
		Services.Net.Notify(player, ("Dir fehlen %s!"):format(Format.Money(missing)), "error", "Error", suggestCashPack(player, missing))
		return
	end
	local slot = Services.BaseService.FindFreeSlot(player)
	if not slot then
		local offer = if Services.MonetizationService.HasPass(player, "ExtraSlots") then nil else "ExtraSlots"
		Services.Net.Notify(player, "Deine Basis ist voll! Verkaufe eine Figur (Inventar) oder hol dir mehr Slots.", "error", "Error", offer)
		return
	end

	-- Kauf gültig
	entry.Sold = true
	data.Cash -= entry.Price
	data.Slots[tostring(slot)] = { Id = entry.Id, Mut = entry.Mut }
	data.Index[Figures.IndexKey(entry.Id, entry.Mut)] = true
	data.Stats.Bought += 1
	Services.RewardService.AddProgress(player, "Buy", 1)
	if Figures.RarityRank(entry.Id) >= Config.Rarities.Rare.Rank then
		Services.RewardService.AddProgress(player, "BuyRare", 1)
	end
	Services.StateService.MarkDirty(player)

	local fig = Figures.Get(entry.Id)
	local rank = Config.Rarities[fig.Rarity].Rank
	Services.Net.Notify(player, "Gekauft: " .. Figures.DisplayName(entry.Id, entry.Mut) .. "!", "success", rank >= 4 and "Legendary" or (rank >= 2 and "Rare" or "Buy"))
	if rank >= Config.Rarities.Legendary.Rank or entry.Mut ~= "Normal" then
		Services.Net.Effect(player, "Reveal", { Id = entry.Id, Mut = entry.Mut, Text = "NEUE FIGUR!" })
	end
	Services.AnnouncementService.Found(player, entry.Id, entry.Mut, "gekauft")

	-- Figur "läuft" zur Basis
	local prompt = model.PrimaryPart:FindFirstChild("BuyPrompt")
	if prompt then
		prompt:Destroy()
	end
	if entry.Tween then
		entry.Tween:Cancel()
	end
	local base = Services.BaseService.GetBase(player)
	local slotPart = base and base.Model and base.Model.Slots:FindFirstChild("Slot" .. slot)
	if slotPart then
		local target = slotPart.CFrame * CFrame.new(0, slotPart.Size.Y / 2 + model.PrimaryPart.Size.Y / 2, 0)
		local distance = (target.Position - model.PrimaryPart.Position).Magnitude
		local walk = TweenService:Create(model.PrimaryPart, TweenInfo.new(math.clamp(distance / 40, 0.6, 2.5), Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = target })
		walk.Completed:Connect(function()
			removeEntry(model)
			Services.BaseService.RenderSlot(player, slot)
		end)
		walk:Play()
	else
		removeEntry(model)
		Services.BaseService.RenderSlot(player, slot)
	end
end

------------------------------------------------------------------------
function ConveyorService.Init(services)
	Services = services
	conveyor = Workspace:WaitForChild("Conveyor")
	folder = Workspace:FindFirstChild("ConveyorFigures")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ConveyorFigures"
		folder.Parent = Workspace
	end
	local belt = conveyor:WaitForChild("Belt")
	local beltTop = belt.Position.Y + belt.Size.Y / 2
	local startPos = conveyor:WaitForChild("StartPoint").Position
	local endPos = conveyor:WaitForChild("EndPoint").Position
	startPos = Vector3.new(startPos.X, beltTop, startPos.Z)
	endPos = Vector3.new(endPos.X, beltTop, endPos.Z)
	startCFrame = CFrame.lookAt(startPos, endPos)
	endCFrame = CFrame.lookAt(endPos, endPos + (endPos - startPos).Unit)
end

function ConveyorService.Start()
	task.spawn(function()
		while true do
			task.wait(Config.Conveyor.SpawnInterval)
			local ok, err = pcall(spawnTick)
			if not ok then
				warn("[Conveyor] Spawn-Fehler:", err)
			end
		end
	end)
end

return ConveyorService
