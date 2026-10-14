--!nocheck
-- Loads Roblox-style ModuleScripts (`require(script.Parent.X)`) under Lune by
-- mapping a virtual instance tree onto the source folders described in
-- default.project.json. Each module gets its own `script` global plus any
-- injected globals (mock `game`, `workspace`, `Color3`, `Enum`, ...).

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local VirtualRequire = {}

-- Lune's fs calls yield, which is not allowed inside metamethods, so the
-- source tree is indexed up front.
local files: { [string]: string } = {}
local dirs: { [string]: boolean } = {}

local function scan(path)
	dirs[path] = true
	for _, name in fs.readDir(path) do
		local child = path .. "/" .. name
		if fs.isDir(child) then
			scan(child)
		elseif string.match(name, "%.luau$") then
			files[child] = fs.readFile(child)
		end
	end
end

for _, root in { "src" } do
	scan(root)
end

local function isDir(path)
	return dirs[path] == true
end

local function isFile(path)
	return files[path] ~= nil
end

-- A virtual instance is a table with a filesystem path. Indexing a child name
-- resolves "<path>/<Name>.luau", "<path>/<Name>/init.luau" or a folder.
local VInstance = {}

function VirtualRequire.new(globals)
	local loader = { cache = {}, globals = globals or {} }

	local function makeInstance(path, name, parent)
		local inst = { __path = path, Name = name, Parent = parent }
		return setmetatable(inst, VInstance)
	end

	VInstance.__index = function(self, key)
		local raw = rawget(VInstance, key)
		if raw then
			return raw
		end
		local base = rawget(self, "__path")
		local dirBase = base
		if isFile(base) then
			-- a module file's children live next to it only when it is init.luau
			if string.match(base, "init%.luau$") then
				dirBase = string.gsub(base, "/init%.luau$", "")
			else
				error(`module {base} has no child {key}`)
			end
		end
		local candidates = {
			dirBase .. "/" .. key .. ".luau",
			dirBase .. "/" .. key .. ".server.luau",
			dirBase .. "/" .. key .. ".client.luau",
		}
		for _, candidate in candidates do
			if isFile(candidate) then
				local child = makeInstance(candidate, key, self)
				rawset(self, key, child)
				return child
			end
		end
		local folder = dirBase .. "/" .. key
		if isDir(folder) then
			local init = folder .. "/init.luau"
			local child = makeInstance(if isFile(init) then init else folder, key, self)
			rawset(self, key, child)
			return child
		end
		return nil
	end

	function VInstance.WaitForChild(self, name)
		local child = self[name]
		assert(child, `WaitForChild: {name} not found under {rawget(self, "__path")}`)
		return child
	end

	function VInstance.FindFirstChild(self, name)
		return self[name]
	end

	function VInstance.IsA(_, className)
		return className == "ModuleScript" or className == "Instance"
	end

	function loader.require(target)
		if type(target) == "string" then
			error("string requires are not supported in game modules: " .. target)
		end
		local path = rawget(target, "__path")
		assert(path, "require target is not a virtual module")
		local cached = loader.cache[path]
		if cached ~= nil then
			return cached.value
		end
		assert(isFile(path), `cannot require folder {path}`)
		local source = files[path]
		-- Lune copies the environment's own keys, so it must be a plain table.
		local env = {}
		for key, value in loader.globals do
			env[key] = value
		end
		env.script = target
		env.require = loader.require
		local chunk = luau.load(source, { debugName = path, environment = env })
		local value = chunk()
		loader.cache[path] = { value = value }
		return value
	end

	function loader.root(path)
		return makeInstance(path, path, nil)
	end

	return loader
end

return VirtualRequire
