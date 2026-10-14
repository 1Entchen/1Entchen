--!nocheck
-- Validates a Rojo-built place file: expected script hierarchy, exactly one
-- server Script and one client LocalScript, and every script compiles.
-- Usage: lune run tests/validate_place.luau build/SlimeGarden.rbxlx

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local path = process.args[1] or "build/SlimeGarden.rbxlx"
local game = roblox.deserializePlace(fs.readFile(path))

local problems = {}
local function check(condition, message)
	if not condition then
		table.insert(problems, message)
	end
end

local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
local server = game:GetService("ServerScriptService"):FindFirstChild("Server")
local starterPlayer = game:GetService("StarterPlayer")
local client = starterPlayer:FindFirstChild("StarterPlayerScripts")
	and starterPlayer.StarterPlayerScripts:FindFirstChild("Client")

check(shared and shared:IsA("Folder"), "ReplicatedStorage.Shared folder missing")
check(server and server.ClassName == "Script", "ServerScriptService.Server must be a Script")
check(client and client.ClassName == "LocalScript", "StarterPlayerScripts.Client must be a LocalScript")

local counts = { Script = 0, LocalScript = 0, ModuleScript = 0 }
for _, inst in game:GetDescendants() do
	if inst:IsA("LuaSourceContainer") then
		counts[inst.ClassName] = (counts[inst.ClassName] or 0) + 1
		local ok, err = pcall(luau.compile, inst.Source)
		check(ok, `{inst:GetFullName()} does not compile: {err}`)
		check(string.sub(inst.Source, 1, 9) == "--!strict", `{inst:GetFullName()} is not --!strict`)
	end
end
check(counts.Script == 1, `expected exactly 1 Script, found {counts.Script}`)
check(counts.LocalScript == 1, `expected exactly 1 LocalScript, found {counts.LocalScript}`)

-- Every system / controller listed in the bootstraps exists.
local function listedNames(source)
	local block = string.match(source, "local ORDER = (%b{})")
	local names = {}
	for name in string.gmatch(block or "", '"(%w+)"') do
		table.insert(names, name)
	end
	return names
end
if server then
	for _, name in listedNames(server.Source) do
		check(server.Systems:FindFirstChild(name), `server system {name} missing`)
	end
end
if client then
	for _, name in listedNames(client.Source) do
		check(client.Controllers:FindFirstChild(name), `client controller {name} missing`)
	end
end

local lighting = game:GetService("Lighting")
check(lighting:FindFirstChildOfClass("Atmosphere"), "Lighting.Atmosphere missing")

if #problems > 0 then
	for _, problem in problems do
		print("PROBLEM: " .. problem)
	end
	process.exit(1)
end
print(
	`Place OK: {counts.ModuleScript} ModuleScripts, {counts.Script} Script, {counts.LocalScript} LocalScript, all compile`
)
