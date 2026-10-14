--[[
	DataService  (ModuleScript)  ->  ServerScriptService/Services/DataService
	Speichert Spielerdaten sicher (ProfileService-Prinzip):
	  - Session-Lock: Daten sind nur in EINEM Server gleichzeitig offen (kein Duplizieren)
	  - UpdateAsync statt SetAsync, Retry mit Backoff
	  - Auto-Save alle 60 s, Speichern beim Verlassen und beim Server-Shutdown
	  - Standardwerte werden automatisch ergänzt (neue Felder in Updates)
	In Studio ohne API-Zugriff wird automatisch ein Test-Speicher im RAM benutzt.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local DataService = {}

local STORE_NAME = "BrainrotBandits_PlayerData_v1"
local LOCK_TIMEOUT = 180 -- Sekunden: älterer Lock gilt als verwaist (Server abgestürzt)
local AUTOSAVE_INTERVAL = 60
local LOAD_ATTEMPTS = 10

local DEFAULT_DATA = {
	Version = 1,
	Cash = Config.StartCash,
	Pending = 0,
	TotalEarned = 0,
	Rebirths = 0,
	Slots = {}, -- ["1"] = { Id = 3, Mut = "Gold" }
	Index = {}, -- ["3_Gold"] = true
	Daily = { Streak = 0, LastDay = 0 },
	Quests = { Day = 0, List = {} },
	Stats = { Steals = 0, Defends = 0, Bought = 0, PlayTime = 0, RobuxSpent = 0 },
	Boost2xUntil = 0,
	LastOnline = 0,
	FirstJoin = 0,
	StarterBought = false,
	OfflineReward = { Amount = 0, Boosted = true },
	Purchases = {},
}

local store
local useMock = false
local mockStore = {}

local profiles = {} -- [player] = { Key, Data }
local loadedCallbacks = {}
local releasingCallbacks = {}
local shuttingDown = false

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function reconcile(data, default)
	for k, v in pairs(default) do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
end

local function updateAsync(key, transform)
	if useMock then
		local result = transform(deepCopy(mockStore[key]))
		if result ~= nil then
			mockStore[key] = deepCopy(result)
		end
		return result
	end
	return store:UpdateAsync(key, transform)
end

local function waitForBudget(requestType)
	if useMock then
		return
	end
	local start = os.clock()
	while DataStoreService:GetRequestBudgetForRequestType(requestType) < 1 and os.clock() - start < 10 do
		task.wait(0.5)
	end
end

local function loadProfile(player)
	local key = "Player_" .. player.UserId
	for attempt = 1, LOAD_ATTEMPTS do
		if not player.Parent then
			return nil
		end
		local lockedByOther = false
		waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
		local ok, result = pcall(updateAsync, key, function(old)
			lockedByOther = false
			local data = old or deepCopy(DEFAULT_DATA)
			local lock = data.SessionLock
			if lock and lock.JobId ~= game.JobId and os.time() - (lock.Time or 0) < LOCK_TIMEOUT then
				lockedByOther = true
				return nil
			end
			data.SessionLock = { JobId = game.JobId, Time = os.time() }
			return data
		end)
		if ok and result and not lockedByOther then
			reconcile(result, DEFAULT_DATA)
			if result.FirstJoin == 0 then
				result.FirstJoin = os.time()
			end
			return { Key = key, Data = result }
		end
		if not ok then
			warn("[DataService] Laden fehlgeschlagen (Versuch " .. attempt .. "):", result)
		end
		task.wait(lockedByOther and 4 or math.min(2 ^ attempt, 10))
	end
	return nil
end

local function saveProfile(player, release)
	local profile = profiles[player]
	if not profile or not profile.Data then
		return false
	end
	profile.Data.LastOnline = os.time()
	local snapshot = deepCopy(profile.Data)

	for attempt = 1, 5 do
		local stolen = false
		waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
		local ok, err = pcall(updateAsync, profile.Key, function(old)
			stolen = false
			if old and old.SessionLock and old.SessionLock.JobId ~= game.JobId then
				stolen = true
				return nil
			end
			if release then
				snapshot.SessionLock = nil
			else
				snapshot.SessionLock = { JobId = game.JobId, Time = os.time() }
			end
			return snapshot
		end)
		if ok then
			if stolen then
				warn("[DataService] Session von anderem Server übernommen, Speichern abgebrochen:", player.Name)
				return false
			end
			return true
		end
		warn("[DataService] Speichern fehlgeschlagen (Versuch " .. attempt .. "):", err)
		task.wait(math.min(2 ^ attempt, 16))
	end
	return false
end

------------------------------------------------------------------------
-- Öffentliche API
------------------------------------------------------------------------
function DataService.Get(player)
	local profile = profiles[player]
	return profile and profile.Data or nil
end

function DataService.IsLoaded(player)
	return profiles[player] ~= nil
end

function DataService.Save(player)
	return saveProfile(player, false)
end

-- fn(player, data) wird aufgerufen, sobald die Daten eines Spielers geladen sind
function DataService.OnLoaded(fn)
	table.insert(loadedCallbacks, fn)
	for player, profile in pairs(profiles) do
		task.spawn(fn, player, profile.Data)
	end
end

-- fn(player, data) wird aufgerufen, kurz bevor die Daten beim Verlassen gespeichert werden
function DataService.OnReleasing(fn)
	table.insert(releasingCallbacks, fn)
end

function DataService.GetLoadedPlayers()
	local list = {}
	for player in pairs(profiles) do
		table.insert(list, player)
	end
	return list
end

------------------------------------------------------------------------
local function onPlayerAdded(player)
	local profile = loadProfile(player)
	if not profile then
		if player.Parent then
			player:Kick("Deine Daten werden noch in einem anderen Server gespeichert. Bitte tritt in 1 Minute erneut bei.")
		end
		return
	end
	if not player.Parent then
		-- Spieler ist während des Ladens gegangen: Lock sofort wieder freigeben
		profiles[player] = profile
		saveProfile(player, true)
		profiles[player] = nil
		return
	end
	profiles[player] = profile
	for _, fn in ipairs(loadedCallbacks) do
		local ok, err = pcall(fn, player, profile.Data)
		if not ok then
			warn("[DataService] OnLoaded-Fehler:", err)
		end
	end
end

local function onPlayerRemoving(player)
	local profile = profiles[player]
	if not profile or profile.Releasing then
		return
	end
	profile.Releasing = true
	for _, fn in ipairs(releasingCallbacks) do
		local ok, err = pcall(fn, player, profile.Data)
		if not ok then
			warn("[DataService] OnReleasing-Fehler:", err)
		end
	end
	saveProfile(player, true)
	profiles[player] = nil
end

function DataService.Init()
	local ok = pcall(function()
		store = DataStoreService:GetDataStore(STORE_NAME)
		store:GetAsync("__ping")
	end)
	if not ok then
		if RunService:IsStudio() then
			useMock = true
			warn("[DataService] Kein DataStore-Zugriff: Test-Speicher (RAM) aktiv. Für echtes Speichern: Spiel veröffentlichen + 'Enable Studio Access to API Services'.")
		else
			store = DataStoreService:GetDataStore(STORE_NAME)
		end
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while not shuttingDown do
			task.wait(AUTOSAVE_INTERVAL)
			for player in pairs(profiles) do
				task.spawn(saveProfile, player, false)
				task.wait(0.5)
			end
		end
	end)

	game:BindToClose(function()
		shuttingDown = true
		for player in pairs(profiles) do
			task.spawn(onPlayerRemoving, player)
		end
		local start = os.clock()
		while next(profiles) ~= nil and os.clock() - start < 25 do
			task.wait(0.2)
		end
	end)
end

DataService.UsingMock = function()
	return useMock
end

return DataService
