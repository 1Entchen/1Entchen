--[[
	LeaderboardService  (ModuleScript)  ->  ServerScriptService/Services/LeaderboardService
	Globale Bestenlisten (alle Server) über OrderedDataStore:
	  - CashBoard:    insgesamt verdientes Cash
	  - RebirthBoard: meiste Rebirths
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))

local LeaderboardService = {}
local Services

local BOARDS = {
	{ Board = "CashBoard", Store = "LB_TotalEarned_v1", Field = "TotalEarned", Format = Format.Money },
	{ Board = "RebirthBoard", Store = "LB_Rebirths_v1", Field = "Rebirths", Format = function(v)
		return "⭐ " .. tostring(v)
	end },
}
local MAX_VALUE = 9e15
local nameCache = {}

local function getName(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = ok and name or "???"
	return nameCache[userId]
end

local function pushPlayer(player)
	local data = Services.DataService.Get(player)
	if not data then
		return
	end
	for _, board in ipairs(BOARDS) do
		if board.DataStore then
			local value = math.floor(math.clamp(data[board.Field] or 0, 0, MAX_VALUE))
			pcall(board.DataStore.SetAsync, board.DataStore, tostring(player.UserId), value)
		end
	end
end

local function renderBoard(board, entries)
	local model = Workspace:FindFirstChild("Leaderboards") and Workspace.Leaderboards:FindFirstChild(board.Board)
	local list = model and model.Screen.BoardGui.List
	if not list then
		return
	end
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local medals = { "🥇", "🥈", "🥉" }
	for rank, entry in ipairs(entries) do
		local row = Instance.new("TextLabel")
		row.LayoutOrder = rank
		row.Size = UDim2.fromScale(1, 0.095)
		row.BackgroundTransparency = rank % 2 == 0 and 1 or 0.85
		row.BackgroundColor3 = Color3.new(1, 1, 1)
		row.Font = Enum.Font.FredokaOne
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = rank <= 3 and Color3.fromRGB(255, 220, 80) or Color3.new(1, 1, 1)
		row.Text = ("  %s %s   %s"):format(medals[rank] or ("#" .. rank), getName(tonumber(entry.key)), board.Format(entry.value))
		row.Parent = list
	end
end

local function refreshBoards()
	for _, board in ipairs(BOARDS) do
		if board.DataStore then
			local ok, pages = pcall(board.DataStore.GetSortedAsync, board.DataStore, false, 10)
			if ok and pages then
				renderBoard(board, pages:GetCurrentPage())
			end
		end
	end
end

function LeaderboardService.Init(services)
	Services = services
	for _, board in ipairs(BOARDS) do
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, board.Store)
		if ok then
			board.DataStore = store
		end
	end
end

function LeaderboardService.Start()
	Services.DataService.OnReleasing(function(player)
		task.spawn(pushPlayer, player)
	end)

	task.spawn(function()
		task.wait(10)
		while true do
			for _, player in ipairs(Services.DataService.GetLoadedPlayers()) do
				pushPlayer(player)
				task.wait(1)
			end
			refreshBoards()
			task.wait(90)
		end
	end)
end

return LeaderboardService
