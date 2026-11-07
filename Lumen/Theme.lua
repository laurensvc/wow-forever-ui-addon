-- Theme: shared colors, bar textures, fonts and the bordered backdrop every module uses.
local Lumen = select(2, ...).Lumen

local WHITE = "Interface\\Buttons\\WHITE8x8"

local T = Lumen:NewModule("general", {
	name = "General",
	core = true,
	defaults = {
		palette = "holy",
		texture = "smooth",
		font = "default",
		accentBorders = false,
	},
	options = {
		{ type = "header", name = "Theme" },
		{
			key = "palette", type = "select", name = "Color theme",
			desc = "Accent colors for cast bars, borders and highlights.",
			values = {
				{ "holy", "Holy (gold)" },
				{ "shadow", "Shadow (violet)" },
				{ "frost", "Frost (blue)" },
				{ "ember", "Ember (orange)" },
				{ "mono", "Mono (silver)" },
			},
		},
		{
			key = "texture", type = "select", name = "Bar texture",
			values = { { "smooth", "Smooth" }, { "flat", "Flat" }, { "raid", "Raid" } },
		},
		{
			key = "font", type = "select", name = "Font",
			values = {
				{ "default", "Default" },
				{ "frizqt", "Friz Quadrata" },
				{ "arialn", "Arial Narrow" },
				{ "morpheus", "Morpheus" },
				{ "skurri", "Skurri" },
			},
		},
		{ key = "accentBorders", type = "toggle", name = "Accent-colored borders", desc = "Draw Lumen borders in the theme color instead of black." },
	},
})
Lumen.Theme = T
T.WHITE = WHITE

-- cast: normal cast, channel: channeled spell, locked: can't be interrupted,
-- failed: interrupted/failed, health: health bar color in "green" mode.
T.palettes = {
	holy = { accent = { 0.95, 0.78, 0.36 }, cast = { 0.95, 0.78, 0.36 }, channel = { 0.55, 0.80, 1.00 }, locked = { 0.62, 0.62, 0.68 }, failed = { 0.85, 0.25, 0.25 }, health = { 0.30, 0.75, 0.40 } },
	shadow = { accent = { 0.62, 0.42, 0.95 }, cast = { 0.62, 0.42, 0.95 }, channel = { 0.88, 0.55, 1.00 }, locked = { 0.62, 0.62, 0.68 }, failed = { 0.85, 0.25, 0.25 }, health = { 0.35, 0.70, 0.45 } },
	frost = { accent = { 0.40, 0.75, 1.00 }, cast = { 0.40, 0.75, 1.00 }, channel = { 0.55, 0.95, 0.90 }, locked = { 0.62, 0.62, 0.68 }, failed = { 0.85, 0.25, 0.25 }, health = { 0.30, 0.75, 0.55 } },
	ember = { accent = { 1.00, 0.52, 0.20 }, cast = { 1.00, 0.60, 0.25 }, channel = { 1.00, 0.85, 0.40 }, locked = { 0.62, 0.62, 0.68 }, failed = { 0.80, 0.20, 0.20 }, health = { 0.35, 0.75, 0.35 } },
	mono = { accent = { 0.85, 0.85, 0.88 }, cast = { 0.80, 0.80, 0.84 }, channel = { 0.60, 0.75, 0.90 }, locked = { 0.50, 0.50, 0.55 }, failed = { 0.80, 0.30, 0.30 }, health = { 0.40, 0.70, 0.45 } },
}

T.textures = {
	smooth = "Interface\\TargetingFrame\\UI-StatusBar",
	flat = WHITE,
	raid = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
}

T.fonts = {
	default = STANDARD_TEXT_FONT,
	frizqt = "Fonts\\FRIZQT__.TTF",
	arialn = "Fonts\\ARIALN.TTF",
	morpheus = "Fonts\\MORPHEUS.TTF",
	skurri = "Fonts\\SKURRI.TTF",
}

function T:Palette()
	return self.palettes[self.db.palette] or self.palettes.holy
end

function T:Color(name)
	local p = self:Palette()
	local c = p[name] or p.accent
	return c[1], c[2], c[3]
end

function T:Texture()
	return self.textures[self.db.texture] or WHITE
end

function T:Font()
	return self.fonts[self.db.font] or STANDARD_TEXT_FONT
end

function T:SetFont(fontString, size, flags)
	fontString:SetFont(self:Font(), size, flags or "OUTLINE")
end

-- A 1px bordered, dark background sitting just behind `parent`.
local backdrops = {}

function T:StyleBackdrop(bd)
	bd:SetBackdropColor(0.05, 0.05, 0.06, 0.85)
	if self.db.accentBorders then
		local r, g, b = self:Color("accent")
		bd:SetBackdropBorderColor(r, g, b, 1)
	else
		bd:SetBackdropBorderColor(0, 0, 0, 1)
	end
end

function T:CreateBackdrop(parent, pad)
	pad = pad or 1
	local bd = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	bd:SetPoint("TOPLEFT", -pad, pad)
	bd:SetPoint("BOTTOMRIGHT", pad, -pad)
	bd:SetFrameLevel(math.max(parent:GetFrameLevel() - 1, 0))
	bd:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
	backdrops[bd] = true
	self:StyleBackdrop(bd)
	return bd
end

function T:Refresh()
	for bd in pairs(backdrops) do
		self:StyleBackdrop(bd)
	end
end
