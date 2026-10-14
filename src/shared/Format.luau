--!strict
-- Number and time formatting for UI.

local Format = {}

-- "1.50" -> "1.5", "2.00" -> "2", "120" -> "120"
local function trimZeros(text: string): string
	if not string.find(text, ".", 1, true) then
		return text
	end
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return text
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 999 -> "999", 1234 -> "1.23K", 12345678 -> "12.3M"
function Format.short(n: number): string
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		local text = tostring(math.floor(n))
		return if negative then "-" .. text else text
	end
	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end
	local text
	if n >= 100 then
		text = string.format("%d", math.floor(n))
	elseif n >= 10 then
		text = string.format("%.1f", math.floor(n * 10) / 10)
	else
		text = string.format("%.2f", math.floor(n * 100) / 100)
	end
	text = trimZeros(text)
	return (if negative then "-" else "") .. text .. SUFFIXES[index]
end

-- 1234567 -> "1,234,567"
function Format.commas(n: number): string
	local text = tostring(math.floor(math.abs(n)))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	formatted = string.gsub(formatted, "^,", "")
	return (if n < 0 then "-" else "") .. formatted
end

-- 75 -> "1:15", 3725 -> "1:02:05", 9 -> "0:09"
function Format.clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

-- 45 -> "45s", 125 -> "2m 5s", 7200 -> "2h"
function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds < 60 then
		return `{seconds}s`
	elseif seconds < 3600 then
		local m, s = seconds // 60, seconds % 60
		return if s == 0 then `{m}m` else `{m}m {s}s`
	end
	local h, m = seconds // 3600, (seconds % 3600) // 60
	return if m == 0 then `{h}h` else `{h}h {m}m`
end

function Format.percent(chance: number): string
	local pct = chance * 100
	if pct >= 10 then
		return string.format("%d%%", math.floor(pct + 0.5))
	elseif pct >= 1 then
		return trimZeros(string.format("%.1f", pct)) .. "%"
	end
	return trimZeros(string.format("%.2f", pct)) .. "%"
end

function Format.multiplier(m: number): string
	if m == math.floor(m) then
		return `x{m}`
	end
	return "x" .. trimZeros(string.format("%.2f", m))
end

return Format
