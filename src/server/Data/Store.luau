--!strict
-- Thin adapter over DataStoreService. In Studio without API access it falls
-- back to an in-memory store (with a loud warning) so the game is playable
-- before publishing. Live servers never fall back.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

export type Transform = (any, any) -> any

export type Store = {
	name: string,
	isMemory: boolean,
	update: (self: Store, key: string, transform: Transform) -> any,
	get: (self: Store, key: string) -> any,
}

local Store = {}

local memoryData: { [string]: { [string]: any } } = {}

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

function Store.memory(name: string): Store
	local bucket = memoryData[name]
	if not bucket then
		bucket = {}
		memoryData[name] = bucket
	end
	local store = { name = name, isMemory = true }
	function store.update(_: any, key: string, transform: Transform): any
		-- Copy in and out to mimic serialization: callers never share tables
		-- with the "stored" value.
		local result = transform(deepCopy(bucket[key]), nil)
		if result == nil then
			return deepCopy(bucket[key])
		end
		bucket[key] = deepCopy(result)
		return deepCopy(result)
	end
	function store.get(_: any, key: string): any
		return deepCopy(bucket[key])
	end
	return (store :: any) :: Store
end

local function isStudioAccessError(message: string): boolean
	local lower = string.lower(message)
	return string.find(lower, "studio", 1, true) ~= nil
		or string.find(lower, "publish", 1, true) ~= nil
		or string.find(lower, "403", 1, true) ~= nil
		or string.find(lower, "api services", 1, true) ~= nil
end

function Store.open(name: string): Store
	local ok, dataStore = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)

	if ok and RunService:IsStudio() then
		local probeOk, probeError = pcall(function()
			return dataStore:GetAsync("__studio_probe")
		end)
		if not probeOk and isStudioAccessError(tostring(probeError)) then
			ok = false
		end
	end

	if not ok then
		if RunService:IsStudio() then
			warn(
				`[Store] DataStores unavailable in Studio ({name}). Using TEMPORARY in-memory saves. `
					.. "Publish the place and enable 'Studio Access to API Services' to test real saving."
			)
			return Store.memory(name)
		end
		error(`[Store] could not open DataStore {name}: {dataStore}`)
	end

	local store = { name = name, isMemory = false }
	function store.update(_: any, key: string, transform: Transform): any
		return (dataStore :: DataStore):UpdateAsync(key, transform)
	end
	function store.get(_: any, key: string): any
		return (dataStore :: DataStore):GetAsync(key)
	end
	return (store :: any) :: Store
end

return Store
