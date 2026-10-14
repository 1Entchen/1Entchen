--!strict
-- Remote access for both sides. The server calls Net.setup() once during
-- init to create every remote from Remotes.luau; clients call Net.event(),
-- which waits for the server-created instance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(script.Parent.Remotes)

local FOLDER_NAME = "Remotes"

local Net = {}

local folder: Folder? = nil
local cache: { [string]: RemoteEvent } = {}

function Net.setup()
	assert(RunService:IsServer(), "Net.setup is server-only")
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = FOLDER_NAME
	for _, list in { Remotes.ClientToServer, Remotes.ServerToClient } do
		for _, name in list do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = newFolder
			cache[name] = remote
		end
	end
	newFolder.Parent = ReplicatedStorage
	folder = newFolder
end

local function getFolder(): Folder
	if folder then
		return folder
	end
	assert(RunService:IsClient(), "Net.setup() must run before remotes are used on the server")
	local found = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	folder = found
	return found
end

function Net.event(name: string): RemoteEvent
	local cached = cache[name]
	if cached then
		return cached
	end
	local remote = getFolder():WaitForChild(name, 30)
	assert(remote and remote:IsA("RemoteEvent"), `missing remote {name}`)
	cache[name] = remote
	return remote
end

return Net
