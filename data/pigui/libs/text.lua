-- Copyright © 2008-2022 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
local Engine = require 'Engine'
local Format = require 'Format'
local Lang = require 'Lang'
local Game = require 'Game'
local ui = require 'pigui.baseui'
local pigui = Engine.pigui

local lc = Lang.GetResource("core");

local font_factor = ui.rescaleUI(1, Vector2(1920, 1200))

local textBackgroundMarginPixels = 2

-- apply a subtle bias to prevent fonts from becoming overly tiny at small resolutions
local function fontScale(size)
	return math.round(size * (font_factor * 0.8 + 0.2))
end

ui.fonts = {
	-- dummy font, actually renders icons
	pionicons = {
		small	= { name = "icons", size = fontScale(16), offset = fontScale(14) },
		medium	= { name = "icons", size = fontScale(18), offset = fontScale(20) },
		large	= { name = "icons", size = fontScale(22), offset = fontScale(28) }
	},
	pionillium = {
		xlarge	= { name = "pionillium", size = fontScale(36), offset = fontScale(24) },
		large	= { name = "pionillium", size = fontScale(30), offset = fontScale(24) },
		medlarge = { name = "pionillium", size = fontScale(22), offset = fontScale(18) },
		medium	= { name = "pionillium", size = fontScale(18), offset = fontScale(14) },
		-- 		medsmall = { name = "pionillium", size = 15, offset = 12 },
		small	= { name = "pionillium", size = fontScale(14), offset = fontScale(11) },
		tiny	= { name = "pionillium", size = fontScale(10), offset = fontScale(7) },

		-- alternate font breakpoints
		title    = { name = "pionillium", size = fontScale(30), offset = fontScale(18) },
		heading  = { name = "pionillium", size = fontScale(22), offset = fontScale(18) },
		body     = { name = "pionillium", size = fontScale(19), offset = fontScale(14) },
		details  = { name = "pionillium", size = fontScale(16), offset = fontScale(14) },
	},
	orbiteer = {
		xlarge	= { name = "orbiteer", size = fontScale(36), offset = fontScale(24) },
		large	= { name = "orbiteer", size = fontScale(30), offset = fontScale(24) },
		medlarge = { name = "orbiteer", size = fontScale(24), offset = fontScale(20) },
		medium	= { name = "orbiteer", size = fontScale(20), offset = fontScale(16) },
		small	= { name = "orbiteer", size = fontScale(14), offset = fontScale(11) },
		tiny	= { name = "orbiteer", size = fontScale(10), offset = fontScale(7) },
	},
}


--
-- Function: ui.calcTextSize
--
-- ui.calcTextSize(text, [font, [size]])
--
-- Calculate the size of the given text. If no font is specified, the currently
-- active font is assumed.
--
-- Parameters:
--   text - string, the text to calculate the size of
--   font - table or string, a font definition or the name of a font
--   size - number, the size of the font if a font definition was not passed
--
-- Returns:
--   size - Vector2, the size of the text when rendered
--
function ui.calcTextSize(text, font, size)
	if size == nil and type(font) == "table" then
		size = font.size
		font = font.name
	end

	local pushed = false
	if font then pushed = pigui:PushFont(font, size) end
	local ret = pigui.CalcTextSize(text)
	if pushed then pigui:PopFont() end

	return ret
end

local EARTH_MASS = 5.9742e24
local SOL_MASS = 1.98892e30

local function oldFmt(str, values)
	str = str:gsub("%%(%w+)(%b{})", function(name, fmt)
		if not values[name] then return "" end
		if #fmt <= 2 then return values[name] end
		-- rearrange {f.2} -> %0.2f
		return string.format("%0"..fmt:sub(3, -2)..fmt:sub(2,2), values[name])
	end)
	-- drop extra values from string.gsub
	return str
end

ui.Format = {
	Latitude = function(decimal_degrees)
		local prefix = lc.LATITUDE_NORTH_ABBREV
		if decimal_degrees < 0 then
			prefix = lc.LATITUDE_SOUTH_ABBREV
			decimal_degrees = math.abs(decimal_degrees)
		end
		local deg = math.floor(decimal_degrees)
		local min = (decimal_degrees - deg) * 60
		local sec = (min - math.floor(min)) * 60
		return string.format('%s %03i°%02i\'%02i"', prefix, deg, min, sec)
	end,
	Longitude = function(decimal_degrees)
		local prefix = lc.LONGITUDE_EAST_ABBREV
		if decimal_degrees < 0 then
			prefix = lc.LONGITUDE_WEST_ABBREV
			decimal_degrees = math.abs(decimal_degrees)
		end
		local deg = math.floor(decimal_degrees)
		local min = (decimal_degrees - deg) * 60
		local sec = (min - math.floor(min)) * 60
		return string.format('%s %03i°%02i\'%02i"', prefix, deg, min, sec)
	end,
	Duration = function(duration, elements)
		-- shown elements items (2 -> wd or dh, 3 -> dhm or hms)
		local negative = false
		if duration < 0 then
			duration = math.abs(duration)
			negative = true
		end
		local seconds = math.floor(duration % 60)
		local minutes = math.floor(duration / 60 % 60)
		local hours = math.floor(duration / 60 / 60 % 24)
		local days = math.floor(duration / 60 / 60 / 24 % 7)
		local weeks = math.floor(duration / 60 / 60 / 24 / 7)
		local i = elements or 5
		local count = false
		local result = ""
		if i > 0 then
			if weeks ~= 0 then
				result = result .. weeks .. "w "
				count = true
			end
			if count then
				i = i - 1
			end
		end
		if i > 0 then
			if days ~= 0 then
				result = result .. days .. "d "
				count = true
			end
			if count then
				i = i - 1
			end
		end
		if i > 0 then
			if hours ~= 0 then
				result = result .. hours .. "h "
				count = true
			end
			if count then
				i = i - 1
			end
		end
		if i > 0 then
			if minutes ~= 0 then
				result = result .. minutes .. "m "
				count = true
			end
			if count then
				i = i - 1
			end
		end
		if i > 0 then
			if seconds ~= 0 then
				result = result .. seconds .. "s "
				count = true
			end
			if result == "" then
				result = "0s"
			end
			if count then
				i = i - 1
			end
		end
		if negative then
			result = "-" .. result
		end
		return string.trim(result)
	end,
	DistanceUnit = function(distance, fractional)
		local d = math.abs(distance)
		if d < 1000 then
			return (fractional and string.format("%0.2f", distance) or math.floor(distance)), lc.UNIT_METERS
		end
		if d < 1000*1000 then
			return string.format("%0.2f", distance / 1000), lc.UNIT_KILOMETERS
		end
		if d < 1000*1000*1000 then
			return string.format("%0.2f", distance / 1000 / 1000), lc.UNIT_MILLION_METERS
		end
		return string.format("%0.2f", distance / 1.4960e11), lc.UNIT_AU
	end,
	Distance = function(distance, fractional)
		local d, u = ui.Format.DistanceUnit(distance, fractional)
		return d .. ' ' .. u
	end,
	SpeedUnit = function(distance, fractional)
		local d = math.abs(distance)
		if d < 1000 then
			return (fractional and string.format("%0.2f", distance) or math.floor(distance)), lc.UNIT_METERS_PER_SECOND
		end
		if d < 1000*1000 then
			return string.format("%0.2f", distance / 1000), lc.UNIT_KILOMETERS_PER_SECOND
		end
		return string.format("%0.2f", distance / 1000 / 1000), lc.UNIT_MILLION_METERS_PER_SECOND
		-- no need for au/s
	end,
	Speed = function(distance, fractional)
		local s, u = ui.Format.SpeedUnit(distance, fractional)
		return s .. u
	end,
	MassUnit = function(mass, digits)
		local m = math.abs(mass)
		local fmt = "%0." .. (digits or 2) .. "f"
		if m < 1e3 then
			return string.format(fmt, mass), lc.UNIT_KILOGRAMS
		elseif m < 1e6 then
			return string.format(fmt, mass / 1e3), lc.UNIT_TONNES
		elseif m < 1e9 then
			return string.format(fmt, mass / 1e6), lc.UNIT_KILOTONNES
		elseif m < 1e12 then
			return string.format(fmt, mass / 1e9), lc.UNIT_MEGATONNES
		elseif m < 1e15 then
			return string.format(fmt, mass / 1e12), lc.UNIT_GIGATONNES
		elseif m < 1e18 then
			return string.format(fmt, mass / 1e15), lc.UNIT_TERATONNES
		elseif m < EARTH_MASS / 1e3 then
			return string.format(fmt, mass / 1e18), lc.UNIT_PETATONNES
		elseif m < EARTH_MASS * 1e3 then
			return oldFmt(lc.N_EARTH_MASSES, { mass = mass / EARTH_MASS })
		end
		return oldFmt(lc.N_SOLAR_MASSES, { mass = mass / SOL_MASS })
	end,
	Mass = function(mass, digits)
		local m, u = ui.Format.MassUnit(mass, digits)
		return m .. u
	end,
	Money = Format.Money,
	Date = Format.Date,
	Datetime = function(date)
		local second, minute, hour, day, month, year = Game.GetPartsFromDateTime(date)
		return string.format("%4i-%02i-%02i %02i:%02i:%02i", year, month, day, hour, minute, second)
	end,
	Gravity = function(grav)
		return string.format("%0.2f", grav) .. lc.UNIT_EARTH_GRAVITY
	end,
	Pressure = function(pres)
		return string.format("%0.2f", pres) .. lc.UNIT_PRESSURE_ATMOSPHERES
	end,
	-- produce number..denominator format
	NumberAbbv = function(number, places)
		local s = number < 0.0 and "-" or ""
		number = math.abs(number)
		local fmt = "%." .. (places or '2') .. "f%s"
		if number < 1e3 then return s .. fmt:format(number, "")
		elseif number < 1e6 then return s .. fmt:format(number / 1e3, "k")
		elseif number < 1e9 then return s .. fmt:format(number / 1e6, "mil")
		elseif number < 1e12 then return s .. fmt:format(number / 1e9, "bil")
		else return s .. fmt:format(number / 1e12, "trn") end
	end,
	-- write the entire number using thousands-place grouping
	Number = function(number, places)
		local s = number < 0.0 and "-" or ""
		number = math.abs(number)
		local fmt = "%." .. (places or '2') .. "f"
		if number < 1e3 then return s .. fmt:format(number)
		else
			fmt = "%03." .. (places or '2') .. "f"
			local res = fmt:format(number % 1e3)
			number = number / 1e3
			while number > 1e3 do
				res = string.format("%03d,%s", number % 1e3, res)
				number = number / 1e3
			end
			return string.format("%d,%s", number, res)
		end
	end,
	SystemPath = function(path)
		return path:GetStarSystem().name.." ("..path.sectorX..", "..path.sectorY..", "..path.sectorZ..")"
	end
}

ui.addFancyText = function(position, anchor_horizontal, anchor_vertical, data, bg_color)
	-- always align texts at baseline
	local spacing = 2
	local size = Vector2(0, 0)
	local max_offset = 0

	for i=1,#data do
		local item = data[i]
		assert(item.text, "missing text for item in addFancyText")
		assert(item.font, "missing font for item in addFancyText")
		assert(item.color, "missing font for item in addFancyText")

		local is_icon = item.font.name == "icons"
		local s
		local popfont
		if is_icon then
			s = Vector2(item.font.size, item.font.size)
		else
			popfont = pigui:PushFont(item.font.name, item.font.size)
			s = pigui.CalcTextSize(item.text)
		end

		size.x = size.x + s.x
		size.x = size.x + spacing -- spacing
		size.y = math.max(size.y, s.y)
		max_offset = math.max(max_offset, item.font.offset)

		if popfont then pigui.PopFont() end
	end

	size.x = size.x - spacing -- remove last spacing
	position = ui.calcTextAlignment(position, size, anchor_horizontal, nil)

	if anchor_vertical == ui.anchor.top then
		position.y = position.y + size.y -- was max_offset, seems wrong
	elseif anchor_vertical == ui.anchor.bottom then
		position.y = position.y - size.y + max_offset
	end

	if bg_color then
		pigui.AddRectFilled(position - Vector2(textBackgroundMarginPixels, size.y + textBackgroundMarginPixels),
			position + Vector2(size.x + textBackgroundMarginPixels, textBackgroundMarginPixels),
			bg_color, 0, 0)
	end

	for i=1,#data do
		local item = data[i]
		local is_icon = item.font.name == "icons"
		if is_icon then
			local s = ui.addIcon(position, item.text, item.color, Vector2(item.font.size, item.font.size), ui.anchor.left, ui.anchor.bottom, item.tooltip)
			position.x = position.x + s.x + spacing
		else
			local s = ui.addStyledText(position, ui.anchor.left, ui.anchor.baseline, item.text, item.color, item.font, item.tooltip)
				position.x = position.x + s.x + spacing
		end
	end
	return size
end

ui.addStyledText = function(position, anchor_horizontal, anchor_vertical, text, color, font, tooltip, bg_color)
	-- addStyledText aligns to upper left
	local size = Vector2(0, 0)
	ui.withFont(font.name, font.size, function()
		size = pigui.CalcTextSize(text)
		-- align bottom to baseline
		if anchor_vertical == ui.anchor.baseline then anchor_vertical = ui.anchor.bottom end
		position = ui.calcTextAlignment(position, size, anchor_horizontal, anchor_vertical) -- ignore vertical if baseline
		if bg_color then
			pigui.AddRectFilled(Vector2(position.x - textBackgroundMarginPixels, position.y - textBackgroundMarginPixels),
				Vector2(position.x + size.x + textBackgroundMarginPixels, position.y + size.y + textBackgroundMarginPixels),
				bg_color, 0, 0)
		end
		pigui.AddText(position, color, text)
		-- pigui.AddQuad(position, position + Vector2(size.x, 0), position + Vector2(size.x, size.y), position + vector.new(0, size.y), colors.red, 1.0)
	end)

	if tooltip and (ui.isMouseHoveringWindow() or not ui.isAnyWindowHovered()) and tooltip ~= "" then
		if pigui.IsMouseHoveringRect(position, position + size, true) then
			ui.maybeSetTooltip(tooltip)
		end
	end

	return size
end
