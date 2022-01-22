-- Copyright © 2008-2022 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Game = require 'Game'
local Format = require 'Format'
local Lang = require 'Lang'
local utils = require "libs.utils"

local ui = require 'pigui'
local lui = Lang.GetResource("ui-core");
local getBodyIcon = require 'pigui.modules.flight-ui.body-icons'

local colors = ui.theme.colors
local icons = ui.theme.icons

local iconSize = Vector2(24,24)
local bodyIconSize = Vector2(18,18)
local button_size = Vector2(32,32) * (ui.screenHeight / 1200)
local frame_padding = 1
local bg_color = colors.buttonBlue
local fg_color = colors.white

-- Reusable widget to list the static contents of a system.
-- Intended to be used by flight-ui as a list of nav targets,
-- and the system info view as a list of bodies in-system

local SystemOverviewWidget = utils.inherits(nil, 'ui.SystemOverviewWidget')

function SystemOverviewWidget.New(args)
	local self = {}
	self.shouldSortByPlayerDistance = false
	self.shouldShowStations = false
	self.shouldShowMoons = false
	self.visible = false
	self.filterText = ""

	return setmetatable(self, SystemOverviewWidget.meta)
end

local function sortByPlayerDistance(a,b)
	return (a.body and b.body) and a.body:DistanceTo(Game.player) < b.body:DistanceTo(Game.player)
end

local function sortBySystemDistance(a,b)
	return (a.systemBody.periapsis + a.systemBody.apoapsis) < (b.systemBody.periapsis + b.systemBody.apoapsis)
end

local function make_result(systemBody, label, childrenVisible)
	return {
		systemBody = systemBody,
		body = systemBody.body,
		label = label,
		children = {},
		visible = true,
		children_visible = childrenVisible,
		has_space_stations = false,
		has_ground_stations = false,
		has_moons = false,
	}
end

-- Returns a table of entries.
-- Each entry will have { children_visible = true } if they are a parent of, or a selected object
-- Entries that are excluded by the current filter will have { visible = false }
---@return table @ SystemBody entry
---@return boolean @ whether this entry is part of the chain of selected objects
local function calculateEntry(systemBody, parent, selected, filter)
	local result = nil
	local is_target = selected[systemBody] or (systemBody.body and selected[systemBody.body]) or false

	result = make_result(systemBody, systemBody.name, is_target)
	result.visible = is_target or filter(systemBody)
	if systemBody.isSpaceStation then
		parent.has_space_stations = true
	elseif systemBody.isGroundStation then
		parent.has_ground_stations = true
	elseif systemBody.isMoon then
		parent.has_moons = true
	end

	for _, child in pairs(systemBody.children or {}) do
		table.insert(result.children, calculateEntry(child, result, selected, filter))
	end

	-- propagate children_visible and visible upwards
	if parent then
		if result.visible then parent.visible = true end
		if result.children_visible then parent.children_visible = true end
	end

	return result
end

-- Render a row for an entry in the system overview
function SystemOverviewWidget:renderEntry(entry, indent, selected)
	local sbody = entry.systemBody
	local label = entry.label or "UNKNOWN"
	local isSelected = selected[sbody] or selected[entry.body]

	ui.dummy(Vector2(iconSize.x * indent / 2.0, iconSize.y))
	ui.sameLine()
	ui.icon(getBodyIcon(sbody), iconSize, colors.font)
	ui.sameLine()

	local pos = ui.getCursorPos()
	if ui.selectable("##" .. label, isSelected, {"SpanAllColumns"}, Vector2(0, iconSize.y)) then
		self:onBodySelected(sbody, entry.body)
	end
	if ui.isItemHovered() and ui.isMouseClicked(1) then
		self:onBodyContextMenu(sbody, entry.body)
	end

	ui.setCursorPos(pos)
	ui.alignTextToLineHeight(iconSize.y)
	ui.text(label)
	ui.sameLine()

	if entry.has_moons then
		ui.icon(icons.moon, bodyIconSize, colors.font)
		ui.sameLine(0,0.01)
	end
	if entry.has_ground_stations then
		ui.icon(icons.starport, bodyIconSize, colors.font)
		ui.sameLine(0,0.01)
	end
	if entry.has_space_stations then
		ui.icon(icons.spacestation, bodyIconSize, colors.font)
		ui.sameLine(0,0.01)
	end

	ui.nextColumn()
	ui.dummy(Vector2(0, iconSize.y))
	ui.sameLine()
	ui.alignTextToLineHeight(iconSize.y)

	local distance
	if entry.body and self.showingActiveSystem then
		distance = entry.body:DistanceTo(Game.player)
	else
		distance = (sbody.apoapsis + sbody.periapsis) / 2.0
	end
	ui.text(Format.Distance(distance))
	ui.nextColumn()
end

function SystemOverviewWidget:showEntry(entry, indent, selected, sortFunction)
	self:renderEntry(entry, indent, selected)

	table.sort(entry.children, sortFunction)
	for _, v in pairs(entry.children) do
		if v.visible or entry.children_visible then
			self:showEntry(v, indent + 1, selected, sortFunction)
		end
	end
end

function SystemOverviewWidget:drawControlButtons()
	if ui.coloredSelectedIconButton(icons.moon, button_size, self.shouldShowMoons, frame_padding, bg_color, fg_color, lui.TOGGLE_OVERVIEW_SHOW_MOONS) then
		self.shouldShowMoons = not self.shouldShowMoons
	end
	ui.sameLine()
	if ui.coloredSelectedIconButton(icons.filter_stations, button_size, self.shouldShowStations, frame_padding, bg_color, fg_color, lui.TOGGLE_OVERVIEW_SHOW_STATIONS) then
		self.shouldShowStations = not self.shouldShowStations
	end
end

function SystemOverviewWidget:overrideDrawButtons()
	self:drawControlButtons()
end

function SystemOverviewWidget:display(system, root, selected)
	self.showingActiveSystem = Game.system.path:IsSameSystem(system.path)
	self:overrideDrawButtons()

	root = root or system.rootSystemBody

	local filterText = ui.inputText("", self.filterText, {})
	self.filterText = filterText

	ui.sameLine()
	ui.icon(icons.filter_bodies, button_size, colors.frame, lui.OVERVIEW_NAME_FILTER)

	local sortFunction = self.shouldSortByPlayerDistance and sortByPlayerDistance or sortBySystemDistance

	local filterFunction = function(systemBody)
		-- only plain text matches, no regexes
		if filterText ~= "" and filterText ~= nil and not string.find(systemBody.name:lower(), filterText:lower(), 1, true) then
			return false
		end
		if (not self.shouldShowMoons) and systemBody.isMoon then
			return false
		elseif (not self.shouldShowStations) and systemBody.isStation then
			return false
		end
		return true
	end

	ui.child("spaceTargets", function()
		local tree = calculateEntry(root, nil, selected, filterFunction)

		if tree then
			ui.columns(2, "spaceTargetColumnsOn", false) -- no border
			ui.setColumnOffset(1, ui.getWindowSize().x * 0.66)
			self:showEntry(tree, 0, selected, sortFunction)
			ui.columns(1, "spaceTargetColumnsOff", false) -- no border
			ui.radialMenu("systemoverviewspacetargets")
		else
			ui.text(lui.NO_FILTER_MATCHES)
		end
	end)
end

return SystemOverviewWidget
