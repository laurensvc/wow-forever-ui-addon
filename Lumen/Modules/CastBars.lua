-- Cast bars: restyles Blizzard's player / target / focus cast bars.
-- Blizzard keeps running the bars (so they stay correct under combat restrictions);
-- we only change how they look. Three switchable styles: Flat, Accent, Minimal.
local Lumen = select(2, ...).Lumen
local T = Lumen.Theme
local IsSecret = Lumen.IsSecret

local C = Lumen:NewModule("castbars", {
	name = "Cast Bars",
	defaults = {
		enabled = true,
		style = "accent",
		colorMode = "theme",
		showIcon = true,
		showTime = true,
		player = true,
		playerWidth = 240,
		playerHeight = 20,
		target = true,
		focus = true,
		otherWidth = 170,
		otherHeight = 14,
	},
	options = {
		{ type = "header", name = "Look" },
		{
			key = "style", type = "select", name = "Style",
			desc = "Flat: clean bar, thin black border. Accent: border in your theme color. Minimal: slim bar with the text above it.",
			values = { { "flat", "Flat" }, { "accent", "Accent" }, { "minimal", "Minimal" } },
		},
		{
			key = "colorMode", type = "select", name = "Bar color",
			desc = "Theme: casts and channels use the theme colors. Class: your own cast bar uses your class color.",
			values = { { "theme", "Theme colors" }, { "class", "Class color" } },
		},
		{ key = "showIcon", type = "toggle", name = "Show spell icon" },
		{ key = "showTime", type = "toggle", name = "Show remaining time" },
		{ type = "header", name = "Player cast bar" },
		{ key = "player", type = "toggle", name = "Style player cast bar", reload = true },
		{ key = "playerWidth", type = "range", name = "Width", min = 120, max = 400, step = 5 },
		{ key = "playerHeight", type = "range", name = "Height", min = 8, max = 40, step = 1 },
		{ type = "header", name = "Target & focus cast bars" },
		{ key = "target", type = "toggle", name = "Style target cast bar", reload = true },
		{ key = "focus", type = "toggle", name = "Style focus cast bar", reload = true },
		{ key = "otherWidth", type = "range", name = "Width", min = 80, max = 300, step = 5 },
		{ key = "otherHeight", type = "range", name = "Height", min = 6, max = 30, step = 1 },
	},
})

local BARS = {
	{ key = "player", size = "player", get = function() return PlayerCastingBarFrame or CastingBarFrame end },
	{ key = "target", size = "other", get = function() return TargetFrameSpellBar end },
	{ key = "focus", size = "other", get = function() return FocusFrameSpellBar end },
}

-- Blizzard art we remove from the bars.
local ART = {
	"Border", "BorderShield", "TextBorder", "Background", "Flash", "Spark",
	"StandardGlow", "CraftGlow", "ChannelShadow", "BaseGlow", "WispGlow", "WispMask",
	"Sparkles01", "Sparkles02", "Flakes01", "Flakes02", "Flakes03", "Shine",
	"EnergyGlow", "EnergyMask", "ChargeGlow", "ChargeFlash", "InterruptGlow", "Shield",
}

local skins = {}    -- bar -> our widgets
local applying = {} -- re-entrancy guard for texture hooks

local function Strip(region)
	if not region or not region.SetTexture then return end
	region:SetTexture(nil)
	if region.SetAtlas then
		hooksecurefunc(region, "SetAtlas", function(r) r:SetTexture(nil) end)
	end
end

-- Which theme color fits the bar's current state.
local function StateColor(bar, asset)
	local kind = bar.barType
	if type(kind) ~= "string" then
		kind = type(asset) == "string" and asset:lower() or ""
	end
	if kind:find("uninterrupt") then return "locked" end
	if kind:find("interrupt") then return "failed" end
	if kind:find("channel") then return "channel" end
	return "cast"
end

local function ApplyLook(bar, asset)
	local s = skins[bar]
	if not s or applying[bar] then return end
	applying[bar] = true

	bar:SetStatusBarTexture(T:Texture())
	local state = StateColor(bar, asset)
	local r, g, b = T:Color(state)
	if C.db.colorMode == "class" and s.info.key == "player" and (state == "cast" or state == "channel") then
		local _, class = UnitClass("player")
		local c = class and RAID_CLASS_COLORS[class]
		if c then r, g, b = c.r, c.g, c.b end
	end
	bar:SetStatusBarColor(r, g, b)

	s.spark:ClearAllPoints()
	s.spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT")

	applying[bar] = nil
end

local function UpdateTime(bar, s)
	local value = bar:GetValue()
	local _, max = bar:GetMinMaxValues()
	if IsSecret(value) or IsSecret(max) or not value or not max then
		s.time:SetText("")
		return
	end
	local remaining = bar.channeling and value or (max - value)
	if remaining > 0 then
		s.time:SetFormattedText("%.1f", remaining)
	else
		s.time:SetText("")
	end
end

function C:Skin(bar, info)
	local s = { info = info }
	skins[bar] = s

	for _, key in ipairs(ART) do
		Strip(bar[key])
	end

	s.bd = T:CreateBackdrop(bar)

	s.spark = bar:CreateTexture(nil, "OVERLAY")
	s.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	s.spark:SetBlendMode("ADD")

	s.iconFrame = CreateFrame("Frame", nil, bar)
	s.icon = s.iconFrame:CreateTexture(nil, "ARTWORK")
	s.icon:SetAllPoints()
	s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	T:CreateBackdrop(s.iconFrame)
	if bar.Icon then
		bar.Icon:SetAlpha(0)
		hooksecurefunc(bar.Icon, "SetTexture", function(_, tex) s.icon:SetTexture(tex) end)
	end

	s.time = bar:CreateFontString(nil, "OVERLAY")
	s.time:SetJustifyH("RIGHT")

	hooksecurefunc(bar, "SetStatusBarTexture", ApplyLook)
	hooksecurefunc(bar, "SetStatusBarColor", function(b) ApplyLook(b) end)
	if bar.SetLook then
		-- Edit Mode switches the player bar between "attached to player frame" and free looks.
		hooksecurefunc(bar, "SetLook", function(b) C:Layout(b) end)
	end
	bar:HookScript("OnUpdate", function(b)
		if C.db.showTime then UpdateTime(b, s) end
	end)
end

function C:Layout(bar)
	local s = skins[bar]
	if not s then return end
	local db = self.db
	local isPlayer = s.info.size == "player"
	local width = isPlayer and db.playerWidth or db.otherWidth
	local height = isPlayer and db.playerHeight or db.otherHeight
	local minimal = db.style == "minimal"
	if minimal then height = math.max(4, math.floor(height / 2)) end

	bar:SetSize(width, height)

	T:StyleBackdrop(s.bd)
	if db.style == "accent" then
		s.bd:SetBackdropBorderColor(T:Color("accent"))
	end

	local iconSize = minimal and height + 14 or height
	s.iconFrame:SetSize(iconSize, iconSize)
	s.iconFrame:ClearAllPoints()
	s.iconFrame:SetPoint(minimal and "BOTTOMRIGHT" or "RIGHT", bar, minimal and "BOTTOMLEFT" or "LEFT", -4, 0)
	s.iconFrame:SetShown(db.showIcon)

	s.spark:SetSize(12, height * 2.2)

	local text = bar.Text
	local fontSize = minimal and 11 or math.max(9, math.min(14, math.floor(height * 0.6)))
	T:SetFont(s.time, fontSize)
	s.time:ClearAllPoints()
	s.time:SetShown(db.showTime)
	if text then
		T:SetFont(text, fontSize)
		text:SetJustifyH("LEFT")
		text:SetWordWrap(false)
		text:ClearAllPoints()
	end
	if minimal then
		s.time:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 3)
		if text then
			text:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 3)
			text:SetPoint("RIGHT", s.time, "LEFT", -4, 0)
		end
	else
		s.time:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
		if text then
			text:SetPoint("LEFT", bar, "LEFT", 4, 0)
			text:SetPoint("RIGHT", s.time, "LEFT", -4, 0)
		end
	end
	-- Blizzard's own cast-time text (Edit Mode option) duplicates ours.
	if bar.CastTimeText then
		bar.CastTimeText:SetAlpha(db.showTime and 0 or 1)
	end

	ApplyLook(bar)
end

function C:OnEnable()
	for _, info in ipairs(BARS) do
		local bar = info.get()
		if bar and self.db[info.key] then
			self:Skin(bar, info)
		end
	end
	if EventRegistry then
		EventRegistry:RegisterCallback("EditMode.Exit", function() C:Refresh() end, self)
	end
	self:Refresh()
end

function C:Refresh()
	for bar in pairs(skins) do
		self:Layout(bar)
	end
end
