--!strict
-- In-server leaderstats plus a global "Top Gardeners" board backed by an
-- OrderedDataStore of lifetime coins earned from selling.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local DataService = require(script.Parent.DataService)
local Plots = require(script.Parent.Plots)

local Leaderboard = {}

local ordered: OrderedDataStore? = nil
local lastPublished: { [Player]: number } = {}
local nameCache: { [number]: string } = {}

local function getOrdered(): OrderedDataStore?
	if ordered then
		return ordered
	end
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.Data.LeaderboardStoreName)
	end)
	if ok then
		ordered = store
	end
	return ordered
end

local function setupLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Value = "0"
	coins.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder
	folder.Parent = player
end

local function updateLeaderstats(player: Player)
	local data = DataService.get(player)
	local folder = player:FindFirstChild("leaderstats")
	if not data or not folder then
		return
	end
	local coins = folder:FindFirstChild("Coins") :: StringValue?
	local rebirths = folder:FindFirstChild("Rebirths") :: IntValue?
	if coins then
		coins.Value = Format.short(data.coins)
	end
	if rebirths then
		rebirths.Value = data.rebirths
	end
end

local function publish(player: Player, force: boolean)
	local data = DataService.get(player)
	local store = getOrdered()
	if not data or not store then
		return
	end
	local last = lastPublished[player] or 0
	if not force and os.clock() - last < Config.Leaderboard.PublishInterval then
		return
	end
	lastPublished[player] = os.clock()
	local value = math.floor(math.min(data.totalEarned, 2 ^ 53))
	if value <= 0 then
		return
	end
	local userId = player.UserId
	task.spawn(function()
		pcall(function()
			(store :: OrderedDataStore):SetAsync(tostring(userId), value)
		end)
	end)
end

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and name then name else "Gardener"
	nameCache[userId] = result
	return result
end

local function render(entries: { { name: string, value: number } }?, message: string?)
	local gui = Plots.world().leaderboard
	gui:ClearAllChildren()

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(1, 1)
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.01, 0)
	layout.Parent = list
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.03, 0)
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.Parent = list

	local function row(text: string, order: number, color: Color3, height: number)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, height)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = color
		label.Text = text
		label.LayoutOrder = order
		label.Parent = list
	end

	row("🏆 TOP GARDENERS", 0, Color3.fromRGB(255, 220, 90), 0.12)
	if message then
		row(message, 1, Color3.new(1, 1, 1), 0.08)
		return
	end
	local rows: { { name: string, value: number } } = entries or {}
	for i, entry in rows do
		local medal = if i == 1 then "🥇" elseif i == 2 then "🥈" elseif i == 3 then "🥉" else `{i}.`
		row(`{medal} {entry.name} — {Format.short(entry.value)}`, i + 1, Color3.new(1, 1, 1), 0.075)
	end
end

local function refreshBoard()
	local store = getOrdered()
	if not store then
		render(nil, "Leaderboard unavailable")
		return
	end
	local ok, pages = pcall(function()
		return (store :: OrderedDataStore):GetSortedAsync(false, Config.Leaderboard.Size)
	end)
	if not ok then
		render(nil, "Leaderboard loading…")
		return
	end
	local entries = {}
	for _, item in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId then
			table.insert(entries, { name = nameFor(userId), value = item.value })
		end
	end
	if #entries == 0 then
		render(nil, "Be the first on the board!")
	else
		render(entries, nil)
	end
end

function Leaderboard.start()
	Players.PlayerAdded:Connect(setupLeaderstats)
	for _, player in Players:GetPlayers() do
		setupLeaderstats(player)
	end
	DataService.addSaveHook(function(player)
		publish(player, false)
	end)
	DataService.ProfileReleased:Connect(function(player)
		publish(player, true)
		lastPublished[player] = nil
	end)

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				updateLeaderstats(player)
			end
			task.wait(1)
		end
	end)
	task.spawn(function()
		render(nil, "Loading…")
		while true do
			refreshBoard()
			task.wait(Config.Leaderboard.RefreshInterval)
		end
	end)
end

return Leaderboard
