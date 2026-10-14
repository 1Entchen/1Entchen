--[[
	Format  (ModuleScript)  ->  ReplicatedStorage/Shared/Format
	Zahlen und Zeiten hübsch darstellen.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.Short(n)
	n = tonumber(n) or 0
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		local s = tostring(math.floor(n))
		return negative and ("-" .. s) or s
	end
	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end
	local s
	if n >= 100 then
		s = string.format("%d", math.floor(n))
	elseif n >= 10 then
		s = string.format("%.1f", math.floor(n * 10) / 10)
	else
		s = string.format("%.2f", math.floor(n * 100) / 100)
	end
	if s:find("%.") then
		s = s:gsub("0+$", "")
		s = s:gsub("%.$", "")
	end
	return (negative and "-" or "") .. s .. SUFFIXES[index]
end

function Format.Money(n)
	return "$" .. Format.Short(n)
end

function Format.Time(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

function Format.Percent(p)
	if p >= 1 then
		return string.format("%.1f %%", p)
	end
	return string.format("%.2f %%", p)
end

return Format
