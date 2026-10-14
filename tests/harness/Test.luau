--!nocheck
-- Tiny BDD-style test framework for Lune.

local Test = {}

local results = { passed = 0, failed = 0, failures = {} }
local stack = {}

local function fullName(name)
	local parts = table.clone(stack)
	table.insert(parts, name)
	return table.concat(parts, " > ")
end

function Test.describe(name, fn)
	table.insert(stack, name)
	fn()
	table.remove(stack)
end

function Test.it(name, fn)
	local label = fullName(name)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		results.passed += 1
	else
		results.failed += 1
		table.insert(results.failures, { name = label, err = tostring(err) })
	end
end

local function format(value)
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function deepEqual(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

function Test.expect(actual)
	local e = {}
	function e.toBe(expected)
		if actual ~= expected then
			error(`expected {format(expected)}, got {format(actual)}`, 2)
		end
	end
	function e.toEqual(expected)
		if not deepEqual(actual, expected) then
			error(`expected deep equality`, 2)
		end
	end
	function e.toBeNear(expected, epsilon)
		epsilon = epsilon or 1e-6
		if math.abs(actual - expected) > epsilon then
			error(`expected {expected} ± {epsilon}, got {actual}`, 2)
		end
	end
	function e.toBeTruthy()
		if not actual then
			error(`expected truthy, got {format(actual)}`, 2)
		end
	end
	function e.toBeFalsy()
		if actual then
			error(`expected falsy, got {format(actual)}`, 2)
		end
	end
	function e.toBeNil()
		if actual ~= nil then
			error(`expected nil, got {format(actual)}`, 2)
		end
	end
	function e.toBeGreaterThan(n)
		if not (actual > n) then
			error(`expected > {n}, got {format(actual)}`, 2)
		end
	end
	function e.toBeLessThan(n)
		if not (actual < n) then
			error(`expected < {n}, got {format(actual)}`, 2)
		end
	end
	function e.toBeBetween(low, high)
		if not (actual >= low and actual <= high) then
			error(`expected in [{low}, {high}], got {format(actual)}`, 2)
		end
	end
	function e.toThrow()
		local ok = pcall(actual)
		if ok then
			error("expected function to throw", 2)
		end
	end
	return e
end

Test.results = results

return Test
