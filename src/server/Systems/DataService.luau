--!strict
-- Owns every player profile. One server holds a player's data at a time
-- (session lock); gameplay mutates the in-memory profile only and this
-- module persists it on autosave, on leave and on shutdown.
--
-- Safety rules implemented here:
--  * all writes use UpdateAsync and re-check that this server owns the lock
--  * a failed load kicks the player instead of handing out a blank profile
--  * a fresh lock held by another server blocks loading (no dupes)
--  * a lost lock kicks the player instead of overwriting newer data

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Signal = require(Shared:WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Types"))

local DataFolder = script.Parent.Parent:WaitForChild("Data")
local Schema = require(DataFolder:WaitForChild("Schema"))
local StoreModule = require(DataFolder:WaitForChild("Store"))

type Profile = Types.Profile
type Store = StoreModule.Store

export type Session = {
	player: Player,
	userId: number,
	key: string,
	data: Profile,
	lastSave: number,
	isNew: boolean,
	lockLost: boolean,
}

local DataService = {}

DataService.ProfileLoaded = Signal.new() :: Signal.Signal<Player, Profile>
-- Fired after a player's profile is no longer active (before the final save
-- completes). Systems clean up runtime state here, never mutating data.
DataService.ProfileReleased = Signal.new() :: Signal.Signal<Player>

local JOB_ID = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
local LOAD_ATTEMPTS = 5
local LOCK_WAIT_ATTEMPTS = 6
local LOCK_WAIT_SECONDS = 5
local SAVE_ATTEMPTS = 3

local store: Store? = nil
local sessions: { [Player]: Session } = {}
local loading: { [Player]: boolean } = {}
local releasing: { [number]: boolean } = {}
local saveHooks: { (Player, Profile) -> () } = {}
local shuttingDown = false

DataService.jobId = JOB_ID

local function getStore(): Store
	if not store then
		store = StoreModule.open(Config.Data.StoreName)
	end
	return store :: Store
end

local function keyFor(userId: number): string
	return `u_{userId}`
end

-- Registers a synchronous callback that runs right before every save so
-- systems can flush runtime state (e.g. growth progress) into the profile.
function DataService.addSaveHook(hook: (Player, Profile) -> ())
	table.insert(saveHooks, hook)
end

local function runSaveHooks(player: Player, data: Profile)
	for _, hook in saveHooks do
		local ok, err = pcall(hook :: any, player, data)
		if not ok then
			warn(`[DataService] save hook failed: {err}`)
		end
	end
end

type ClaimResult = { status: "ok", data: Profile, isNew: boolean } | { status: "locked" } | { status: "error" }

local function tryClaim(key: string): ClaimResult
	local now = os.time()
	local lockedByOther = false
	local loaded: Profile? = nil
	local isNew = false

	local ok, err = pcall(function()
		getStore():update(key, function(old: any)
			lockedByOther = false
			loaded = nil
			if typeof(old) ~= "table" then
				old = nil
			end
			local lock = old and old.lock
			if
				typeof(lock) == "table"
				and lock.jobId ~= JOB_ID
				and now - (tonumber(lock.time) or 0) < Config.Data.LockStaleAfter
			then
				lockedByOther = true
				return nil -- abort the write; another live server owns this profile
			end
			isNew = old == nil or old.data == nil
			local raw = if old and old.data then Schema.migrate(old.data) else Schema.defaults(now)
			local data = Schema.reconcile(raw, now)
			loaded = data
			return { data = data, lock = { jobId = JOB_ID, time = now } }
		end)
	end)

	if not ok then
		warn(`[DataService] load failed for {key}: {err}`)
		return { status = "error" }
	end
	if lockedByOther then
		return { status = "locked" }
	end
	if not loaded then
		return { status = "error" }
	end
	return { status = "ok", data = loaded :: Profile, isNew = isNew }
end

-- Writes the profile. Returns false if every attempt failed or the lock was
-- lost (in which case session.lockLost is set).
local function writeSession(session: Session, release: boolean): boolean
	local snapshot = Schema.deepCopy(session.data)
	snapshot.lastSeen = os.time()

	for attempt = 1, SAVE_ATTEMPTS do
		local lost = false
		local ok, err = pcall(function()
			getStore():update(session.key, function(old: any)
				lost = false
				local lock = typeof(old) == "table" and old.lock
				if typeof(lock) ~= "table" or lock.jobId ~= JOB_ID then
					lost = true
					return nil
				end
				return {
					data = snapshot,
					lock = if release then nil else { jobId = JOB_ID, time = os.time() },
				}
			end)
		end)
		if ok and lost then
			session.lockLost = true
			warn(`[DataService] lost session lock for {session.key}; refusing to overwrite`)
			return false
		elseif ok then
			session.lastSave = os.clock()
			return true
		end
		warn(`[DataService] save attempt {attempt}/{SAVE_ATTEMPTS} failed for {session.key}: {err}`)
		if attempt < SAVE_ATTEMPTS and not shuttingDown then
			task.wait(2 ^ attempt)
		end
	end
	return false
end

local function kick(player: Player, message: string)
	if player.Parent then
		player:Kick(message)
	end
end

local function handleLostLock(session: Session)
	if sessions[session.player] == session then
		sessions[session.player] = nil
		DataService.ProfileReleased:Fire(session.player)
	end
	kick(session.player, "Your progress was opened on another server. Please rejoin.")
end

function DataService.loadPlayer(player: Player)
	if sessions[player] or loading[player] then
		return
	end
	loading[player] = true
	local userId = player.UserId
	local key = keyFor(userId)

	-- A quick rejoin to this same server: wait for our own release to finish.
	local waited = 0
	while releasing[userId] and waited < 30 do
		task.wait(0.25)
		waited += 0.25
	end

	local result: ClaimResult = { status = "error" }
	local errors, lockedTries = 0, 0
	while player.Parent do
		result = tryClaim(key)
		if result.status == "ok" then
			break
		elseif result.status == "locked" then
			lockedTries += 1
			if lockedTries >= LOCK_WAIT_ATTEMPTS then
				break
			end
			task.wait(LOCK_WAIT_SECONDS)
		else
			errors += 1
			if errors >= LOAD_ATTEMPTS then
				break
			end
			task.wait(math.min(2 ^ errors, 16))
		end
	end
	loading[player] = nil

	if result.status ~= "ok" then
		if result.status == "locked" then
			kick(player, "Your garden is still saving on another server. Please rejoin in a minute!")
		else
			kick(player, "We couldn't load your garden (Roblox data services may be down). Please rejoin.")
		end
		return
	end

	local session: Session = {
		player = player,
		userId = userId,
		key = key,
		data = result.data,
		lastSave = os.clock() - math.random() * Config.Data.AutosaveInterval, -- stagger autosaves
		isNew = result.isNew,
		lockLost = false,
	}

	if not player.Parent then
		-- Left while loading: give the lock straight back.
		releasing[userId] = true
		writeSession(session, true)
		releasing[userId] = nil
		return
	end

	session.data.stats.sessions += 1
	sessions[player] = session
	DataService.ProfileLoaded:Fire(player, session.data)
end

function DataService.releasePlayer(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	releasing[session.userId] = true
	runSaveHooks(player, session.data)
	DataService.ProfileReleased:Fire(player)
	writeSession(session, true)
	releasing[session.userId] = nil
end

function DataService.get(player: Player): Profile?
	local session = sessions[player]
	return if session then session.data else nil
end

function DataService.getSession(player: Player): Session?
	return sessions[player]
end

function DataService.waitFor(player: Player, timeout: number): Profile?
	local start = os.clock()
	while player.Parent and not sessions[player] and os.clock() - start < timeout do
		task.wait(0.1)
	end
	local session = sessions[player]
	return if session then session.data else nil
end

-- Immediate save used after purchases. Returns true only when the write
-- landed, so receipts are acknowledged strictly after persistence.
function DataService.saveNow(player: Player): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	runSaveHooks(player, session.data)
	local ok = writeSession(session, false)
	if session.lockLost then
		handleLostLock(session)
		return false
	end
	return ok
end

local function autosaveLoop()
	while true do
		task.wait(5)
		for player, session in sessions do
			if os.clock() - session.lastSave >= Config.Data.AutosaveInterval then
				session.lastSave = os.clock() -- prevent overlapping attempts
				task.spawn(function()
					runSaveHooks(player, session.data)
					writeSession(session, false)
					if session.lockLost then
						handleLostLock(session)
					end
				end)
			end
		end
	end
end

local function onShutdown()
	shuttingDown = true
	local pending = 0
	for player in sessions do
		pending += 1
		task.spawn(function()
			DataService.releasePlayer(player)
			pending -= 1
		end)
	end
	local start = os.clock()
	local limit = if RunService:IsStudio() and getStore().isMemory then 1 else 25
	-- Also wait for releases started by PlayerRemoving during shutdown.
	while (pending > 0 or next(releasing) ~= nil) and os.clock() - start < limit do
		task.wait(0.1)
	end
end

function DataService.init()
	getStore()
end

function DataService.start()
	Players.PlayerRemoving:Connect(DataService.releasePlayer)
	game:BindToClose(onShutdown)
	task.spawn(autosaveLoop)
end

-- Called by the bootstrap after every system has started, so no listener
-- can miss a ProfileLoaded event.
function DataService.listen()
	Players.PlayerAdded:Connect(DataService.loadPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(DataService.loadPlayer, player)
	end
end

-- Test hook: swap the backing store.
function DataService._setStore(newStore: Store)
	store = newStore
end

return DataService
