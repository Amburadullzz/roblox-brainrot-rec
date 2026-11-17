--[[
	Format: the game's number and money spelling, shared by the server's announcements and the client's
	HUD so a rate reads the same wherever a player meets it.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

--[[ 1240 -> "1.24K", 980 -> "980", 1500000 -> "1.5M". Two decimals at most, none of them trailing. ]]
function Format.short(value: number): string
	local n = math.max(0, value)
	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end
	if index == 1 then
		return tostring(math.floor(n + 0.5))
	end
	local rounded = math.floor(n * 100 + 0.5) / 100
	local text = string.format("%.2f", rounded)
	text = text:gsub("%.?0+$", "")
	return text .. SUFFIXES[index]
end

--[[ A whole dollar amount with thousands separators: 1234567 -> "1,234,567". ]]
function Format.commas(value: number): string
	local text = tostring(math.floor(math.max(0, value)))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

--[[ The HUD's cash line: "$1,240" under ten thousand, "$1.24M" above it. ]]
function Format.cash(value: number): string
	if value < 10000 then
		return "$" .. Format.commas(value)
	end
	return "$" .. Format.short(value)
end

--[[ A rate: "$18/s", "$1.6K/s". ]]
function Format.rate(value: number): string
	return "$" .. Format.short(value) .. "/s"
end

--[[ Seconds as the wave banner says them: "8.4s", "0.0s". ]]
function Format.seconds(value: number): string
	return string.format("%.1fs", math.max(0, value))
end

--[[ A multiplier: 1.5 -> "x1.50". ]]
function Format.multiplier(value: number): string
	return string.format("x%.2f", value)
end

return Format
