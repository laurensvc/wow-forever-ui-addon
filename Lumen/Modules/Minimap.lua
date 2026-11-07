-- Minimap: square or round, resizable, mouse-wheel zoom, zone / coordinates / clock overlay.
local Lumen = select(2, ...).Lumen
local T = Lumen.Theme
local IsSecret = Lumen.IsSecret

local M = Lumen:NewModule("minimap", {
	name = "Minimap",
	defaults = {
		enabled = true,
		size = 200,
		square = true,
		wheelZoom = true,
		showZone = true,
		showCoords = true,
		showClock = true,
		hideZoomButtons = true,
		hideCalendar = false,
		hideTracking = false,
	},
	options = {
		{ type = "header", name = "Shape & size" },
		{ key = "size", type = "range", name = "Size", min = 120, max = 320, step = 5, desc = "Width and height in pixels. Move the minimap with Edit Mode." },
		{ key = "square", type = "toggle", name = "Square minimap" },
		{ key = "wheelZoom", type = "toggle", name = "Zoom with mouse wheel" },
		{ type = "header", name = "Info" },
		{ key = "showZone", type = "toggle", name = "Zone name on the map" },
		{ key = "showCoords", type = "toggle", name = "Coordinates" },
		{ key = "showClock", type = "toggle", name = "Clock", desc = "Click the clock to open the stopwatch and alarm." },
		{ type = "header", name = "Buttons" },
		{ key = "hideZoomButtons", type = "toggle", name = "Hide zoom buttons" },
		{ key = "hideCalendar", type = "toggle", name = "Hide calendar button" },
		{ key = "hideTracking", type = "toggle", name = "Hide tracking button" },
	},
})

local SQUARE_MASK = "Interface\\ChatFrame\\ChatFrameBackground"
local ROUND_MASK = "Textures\\MinimapMask"

local PVP_COLORS = {
	sanctuary = { 0.41, 0.80, 0.94 },
	friendly = { 0.10, 1.00, 0.10 },
	hostile = { 1.00, 0.10, 0.10 },
	contested = { 1.00, 0.70, 0.00 },
	arena = { 1.00, 0.10, 0.10 },
	combat = { 1.00, 0.10, 0.10 },
}

function M:OnEnable()
	-- Addon minimap buttons (LibDBIcon) read this to position themselves.
	_G.GetMinimapShape = function()
		return M.db.square and "SQUARE" or "ROUND"
	end

	self.border = T:CreateBackdrop(Minimap)

	local overlay = CreateFrame("Frame", nil, Minimap)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(Minimap:GetFrameLevel() + 5)

	self.zone = overlay:CreateFontString(nil, "OVERLAY")
	self.zone:SetPoint("TOPLEFT", 4, -5)
	self.zone:SetPoint("TOPRIGHT", -4, -5)
	self.zone:SetJustifyH("CENTER")
	self.zone:SetWordWrap(false)

	self.coords = overlay:CreateFontString(nil, "OVERLAY")
	self.coords:SetPoint("BOTTOMLEFT", 5, 5)

	local clock = CreateFrame("Button", nil, overlay)
	clock:SetSize(50, 16)
	clock:SetPoint("BOTTOMRIGHT", -4, 3)
	clock.text = clock:CreateFontString(nil, "OVERLAY")
	clock.text:SetPoint("RIGHT")
	clock:SetScript("OnClick", function()
		if TimeManager_Toggle then TimeManager_Toggle() end
	end)
	self.clock = clock

	Minimap:SetScript("OnMouseWheel", function(_, delta)
		local zoom = Minimap:GetZoom() + (delta > 0 and 1 or -1)
		if zoom >= 0 and zoom < Minimap:GetZoomLevels() then
			Minimap:SetZoom(zoom)
		end
	end)

	for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
		self:RegisterEvent(event, "UpdateZone")
	end
	-- The clock button lives in a load-on-demand Blizzard addon.
	self:RegisterEvent("ADDON_LOADED", function(_, _, name)
		if name == "Blizzard_TimeManager" then M:Refresh() end
	end)
	-- Edit Mode can re-layout the minimap; re-apply our size afterwards.
	if EventRegistry then
		EventRegistry:RegisterCallback("EditMode.Exit", function() M:Refresh() end, self)
	end

	C_Timer.NewTicker(0.5, function() M:UpdateInfo() end)
	self:Refresh()
end

function M:Refresh()
	local db = self.db

	Minimap:SetMaskTexture(db.square and SQUARE_MASK or ROUND_MASK)
	self.border:SetShown(db.square)
	Minimap:SetSize(db.size, db.size)
	-- Nudge the zoom so the map texture redraws at its new size.
	local zoom = Minimap:GetZoom()
	Minimap:SetZoom(zoom > 0 and zoom - 1 or zoom + 1)
	Minimap:SetZoom(zoom)
	Minimap:EnableMouseWheel(db.wheelZoom)

	Lumen:SetHidden(MinimapCompassTexture, db.square)
	if MinimapCluster then
		Lumen:SetHidden(MinimapCluster.BorderTop, db.showZone)
		Lumen:SetHidden(MinimapCluster.ZoneTextButton, db.showZone)
		Lumen:SetHidden(MinimapCluster.Tracking, db.hideTracking)
	end
	Lumen:SetHidden(Minimap.ZoomIn, db.hideZoomButtons)
	Lumen:SetHidden(Minimap.ZoomOut, db.hideZoomButtons)
	Lumen:SetHidden(GameTimeFrame, db.hideCalendar)
	Lumen:SetHidden(TimeManagerClockButton, db.showClock)

	local size = db.size >= 180 and 13 or 11
	T:SetFont(self.zone, size)
	T:SetFont(self.coords, size - 1)
	T:SetFont(self.clock.text, size - 1)
	self.clock.text:SetTextColor(T:Color("accent"))
	self.zone:SetShown(db.showZone)
	self.coords:SetShown(db.showCoords)
	self.clock:SetShown(db.showClock)

	self:UpdateZone()
	self:UpdateInfo()
end

function M:UpdateZone()
	if not self.db.showZone then return end
	local getPvp = (C_PvP and C_PvP.GetZonePVPInfo) or GetZonePVPInfo
	local c = PVP_COLORS[getPvp and getPvp() or ""]
	self.zone:SetText(GetMinimapZoneText())
	if c then
		self.zone:SetTextColor(c[1], c[2], c[3])
	else
		self.zone:SetTextColor(1, 0.95, 0.85)
	end
end

function M:UpdateInfo()
	local db = self.db
	if db.showCoords then
		local text = ""
		local map = C_Map.GetBestMapForUnit("player")
		local pos = map and C_Map.GetPlayerMapPosition(map, "player")
		if pos then
			local x, y = pos:GetXY()
			if not IsSecret(x) and not IsSecret(y) and x and x > 0 then
				text = ("%.1f  %.1f"):format(x * 100, y * 100)
			end
		end
		self.coords:SetText(text)
	end
	if db.showClock then
		self.clock.text:SetText(date(GetCVarBool("timeMgrUseMilitaryTime") and "%H:%M" or "%I:%M %p"))
	end
end
