--!nocheck
-- Test runner: `lune run tests/run.luau` from the repository root.
-- Discovers tests/specs/*.spec.luau and runs each in a fresh environment.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Env = require("./harness/Env")
local Test = require("./harness/Test")

local filter = process.args[1]

local specs = {}
for _, name in fs.readDir("tests/specs") do
	if string.match(name, "%.spec%.luau$") and (filter == nil or string.find(name, filter, 1, true)) then
		table.insert(specs, name)
	end
end
table.sort(specs)

for _, name in specs do
	local spec = require("./specs/" .. string.gsub(name, "%.luau$", ""))
	Test.describe(name, function()
		spec(Test, Env)
	end)
end

local results = Test.results
for _, failure in results.failures do
	print("FAIL " .. failure.name)
	print("     " .. string.gsub(failure.err, "\n", "\n     "))
end
print(string.format("\n%d passed, %d failed (%d spec files)", results.passed, results.failed, #specs))
process.exit(if results.failed > 0 then 1 else 0)
