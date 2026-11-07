-- Group frames: party/raid health grid built for healing.
-- Built on Blizzard's SecureGroupHeaderTemplate so clicking, targeting, mouseover
-- macros and click-casting (Clique) keep working in combat.
--
-- Combat values (health, heals, auras, range) may be "secret" in Midnight-era
-- clients: we feed them straight into StatusBars / textures and never do math on
-- them. Incoming heals and shields are drawn as bars anchored to the end of the
-- health fill, so they need no arithmetic either.
local Lumen = select(2, ...).Lumen
local T = Lumen.Theme
local IsSecret, Num, Bool = Lumen.IsSecret, Lumen.Num, Lumen.Bool

local G = Lumen:NewModule("group", {
	name = "Group Frames",
	defaults = {
		enabled = true,
		width = 90,
		height = 46,
		spacing = 3,
		groupBy = "GROUP",
		growth = "DOWN",
		showPlayer = true,
		showSolo = false,
		hideBlizzard = true,
		healthColor = "class",
		healthText = "deficit",
		healPrediction = true,
		absorbs = true,
		rangeAlpha = 0.35,
		showPower = "HEALER",
		powerHeight = 4,
		dispelHighlight = true,
		myBuffs = true,
		debuffs = 3,
		auraSize = 14,
		showRole = true,
		targetHighlight = true,
	},
	options = {
		{ type = "header", name = "Layout" },
		{ key = "width", type = "range", name = "Frame width", min = 50, max = 200, step = 1 },
		{ key = "height", type = "range", name = "Frame height", min = 20, max = 100, step = 1 },
		{ key = "spacing", type = "range", name = "Spacing", min = 0, max = 12, step = 1 },
		{
			key = "groupBy", type = "select", name = "Sort players",
			values = { { "GROUP", "By raid group" }, { "ROLE", "By role (tank, healer, damage)" }, { "CLASS", "By class" } },
		},
		{
			key = "growth", type = "select", name = "Direction",
			values = { { "DOWN", "Players down, groups right" }, { "RIGHT", "Players right, groups down" } },
		},
		{ key = "showPlayer", type = "toggle", name = "Show yourself" },
		{ key = "showSolo", type = "toggle", name = "Show when solo", desc = "Handy while setting up: shows your own frame when you're not in a group." },
		{ key = "hideBlizzard", type = "toggle", name = "Hide Blizzard party & raid frames", reload = true },
		{ type = "header", name = "Health" },
		{
			key = "healthColor", type = "select", name = "Health color",
			desc = "Dark: dark bars with red missing health and class-colored names. Easy to read what needs healing.",
			values = { { "class", "Class color" }, { "dark", "Dark" }, { "green", "Green" } },
		},
		{
			key = "healthText", type = "select", name = "Health text",
			values = { { "deficit", "Missing health (-12.3k)" }, { "percent", "Percent" }, { "none", "None" } },
		},
		{ key = "healPrediction", type = "toggle", name = "Show incoming heals" },
		{ key = "absorbs", type = "toggle", name = "Show shields (absorbs)" },
		{ key = "rangeAlpha", type = "range", name = "Out of range opacity", min = 0.1, max = 1, step = 0.05 },
		{ type = "header", name = "Mana" },
		{
			key = "showPower", type = "select", name = "Show mana bar for",
			values = { { "HEALER", "Healers (assigned role)" }, { "MANA", "Everyone who uses mana" }, { "ALL", "Everyone" }, { "NONE", "Nobody" } },
		},
		{ key = "powerHeight", type = "range", name = "Mana bar height", min = 2, max = 12, step = 1 },
		{ type = "header", name = "Buffs & debuffs" },
		{ key = "dispelHighlight", type = "toggle", name = "Highlight debuffs you can dispel", desc = "Colored border by debuff type (Magic, Disease, ...)." },
		{ key = "myBuffs", type = "toggle", name = "Show your HoTs & shields", desc = "Your own short buffs (Renew, Power Word: Shield, ...) in the top-right corner." },
		{ key = "debuffs", type = "range", name = "Debuffs shown", min = 0, max = 5, step = 1 },
		{ key = "auraSize", type = "range", name = "Icon size", min = 8, max = 30, step = 1 },
		{ type = "header", name = "Indicators" },
		{ key = "showRole", type = "toggle", name = "Tank & healer icons" },
		{ key = "targetHighlight", type = "toggle", name = "Highlight your target" },
	},
})

local GetAura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local buttons = {} -- every unit button the header created
local byUnit = {}  -- unit token -> button
local MAX_BUFFS, MAX_DEBUFFS = 3, 5
local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer" }

local function ClassColor(unit)
	local _, class = UnitClass(unit)
	if not IsSecret(class) and class then
		local c = RAID_CLASS_COLORS[class]
		if c then return c.r, c.g, c.b end
	end
	return 0.6, 0.6, 0.6
end

---------------------------------------------------------------------------
-- Button construction
---------------------------------------------------------------------------
local function CreateIcon(parent)
	local f = CreateFrame("Frame", nil, parent)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetAllPoints()
	f.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	T:CreateBackdrop(f)
	f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
	f.cd:SetAllPoints()
	f.cd:SetDrawEdge(false)
	f.cd:SetReverse(true)
	f.cd:SetHideCountdownNumbers(true)
	f.count = f:CreateFontString(nil, "OVERLAY")
	f.count:SetPoint("BOTTOMRIGHT", 2, -1)
	f:Hide()
	return f
end

local function CreateBorder(parent, size, level)
	local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	f:SetAllPoints()
	f:SetFrameLevel(level)
	f:SetBackdrop({ edgeFile = T.WHITE, edgeSize = size })
	f:Hide()
	return f
end

function G:SetupButton(b)
	if not b or buttons[b] then return end
	buttons[b] = true
	buttons[#buttons + 1] = b

	Lumen:AfterCombat(function() b:RegisterForClicks("AnyUp") end)
	-- Clique and similar click-casting addons pick up frames from this table.
	ClickCastFrames = ClickCastFrames or {}
	ClickCastFrames[b] = true

	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	T:CreateBackdrop(b, 1)

	b.health = CreateFrame("StatusBar", nil, b)
	b.health:SetPoint("TOPLEFT")
	b.health:SetPoint("TOPRIGHT")
	b.health:SetClipsChildren(true)
	b.health:SetStatusBarTexture(T:Texture())
	b.incoming = CreateFrame("StatusBar", nil, b.health)
	b.incoming:SetStatusBarTexture(T:Texture())
	b.absorb = CreateFrame("StatusBar", nil, b.health)
	b.absorb:SetStatusBarTexture(T:Texture())

	b.power = CreateFrame("StatusBar", nil, b)
	b.power:SetPoint("BOTTOMLEFT")
	b.power:SetPoint("BOTTOMRIGHT")

	local overlay = CreateFrame("Frame", nil, b)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(b.health:GetFrameLevel() + 5)
	b.overlay = overlay

	b.name = overlay:CreateFontString(nil, "OVERLAY")
	b.name:SetPoint("CENTER", 0, 5)
	b.name:SetWordWrap(false)
	b.status = overlay:CreateFontString(nil, "OVERLAY")
	b.status:SetPoint("CENTER", 0, -8)

	b.role = overlay:CreateTexture(nil, "OVERLAY")
	b.role:SetPoint("TOPLEFT", 2, -2)
	b.raidIcon = overlay:CreateTexture(nil, "OVERLAY")
	b.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	b.raidIcon:SetPoint("LEFT", 2, 0)

	b.dispel = CreateBorder(b, 2, overlay:GetFrameLevel() + 1)
	b.targetBorder = CreateBorder(b, 1, overlay:GetFrameLevel() + 2)
	b.targetBorder:SetBackdropBorderColor(1, 1, 1, 0.9)

	b.buffs, b.debuffs = {}, {}
	for i = 1, MAX_BUFFS do b.buffs[i] = CreateIcon(overlay) end
	for i = 1, MAX_DEBUFFS do b.debuffs[i] = CreateIcon(overlay) end

	b:HookScript("OnAttributeChanged", function(self, name, value)
		if name == "unit" then G:SetUnit(self, value) end
	end)
	b:HookScript("OnShow", function(self) G:UpdateAll(self) end)
	b:HookScript("OnEnter", function(self)
		if self.unit then
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
			GameTooltip:SetUnit(self.unit)
			GameTooltip:Show()
		end
	end)
	b:HookScript("OnLeave", function() GameTooltip:Hide() end)

	self:StyleButton(b)
	self:SetUnit(b, b:GetAttribute("unit"))
end

-- Visual settings that change with options / theme.
function G:StyleButton(b)
	local db, tex = self.db, T:Texture()
	local dark = db.healthColor == "dark"

	if dark then
		b.bg:SetColorTexture(0.55, 0.12, 0.12, 1) -- missing health shows red
	else
		b.bg:SetColorTexture(0.08, 0.08, 0.09, 0.9)
	end

	for _, bar in ipairs({ b.health, b.incoming, b.absorb, b.power }) do
		bar:SetStatusBarTexture(tex)
	end
	-- Prediction bars start where the health fill ends.
	b.incoming:ClearAllPoints()
	b.incoming:SetPoint("TOPLEFT", b.health:GetStatusBarTexture(), "TOPRIGHT")
	b.incoming:SetPoint("BOTTOMLEFT", b.health:GetStatusBarTexture(), "BOTTOMRIGHT")
	b.incoming:SetWidth(db.width)
	b.incoming:SetStatusBarColor(0.35, 1.0, 0.55, 0.55)
	b.absorb:ClearAllPoints()
	b.absorb:SetPoint("TOPLEFT", b.incoming:GetStatusBarTexture(), "TOPRIGHT")
	b.absorb:SetPoint("BOTTOMLEFT", b.incoming:GetStatusBarTexture(), "BOTTOMRIGHT")
	b.absorb:SetWidth(db.width)
	b.absorb:SetStatusBarColor(1, 1, 1, 0.45)

	local nameSize = math.max(9, math.min(14, math.floor(db.height / 4)))
	T:SetFont(b.name, nameSize)
	T:SetFont(b.status, nameSize - 1)
	b.name:SetWidth(db.width - 8)
	b.role:SetSize(12, 12)
	b.raidIcon:SetSize(14, 14)

	local s = db.auraSize
	for i, f in ipairs(b.buffs) do
		f:SetSize(s, s)
		f:ClearAllPoints()
		if i == 1 then
			f:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
		else
			f:SetPoint("RIGHT", b.buffs[i - 1], "LEFT", -2, 0)
		end
		T:SetFont(f.count, math.max(8, s - 4))
	end
	for i, f in ipairs(b.debuffs) do
		f:SetSize(s, s)
		f:ClearAllPoints()
		if i == 1 then
			f:SetPoint("BOTTOMLEFT", b.health, "BOTTOMLEFT", 2, 2)
		else
			f:SetPoint("LEFT", b.debuffs[i - 1], "RIGHT", 2, 0)
		end
		T:SetFont(f.count, math.max(8, s - 4))
	end

	b.powerShown = false
	self:LayoutButton(b)
end

function G:LayoutButton(b)
	b.health:ClearAllPoints()
	b.health:SetPoint("TOPLEFT")
	if b.powerShown then
		b.power:SetHeight(self.db.powerHeight)
		b.power:Show()
		b.health:SetPoint("BOTTOMRIGHT", 0, self.db.powerHeight + 1)
	else
		b.power:Hide()
		b.health:SetPoint("BOTTOMRIGHT")
	end
end

---------------------------------------------------------------------------
-- Unit tracking
---------------------------------------------------------------------------
function G:MapPlayer()
	byUnit.player = nil
	for _, b in ipairs(buttons) do
		if b.unit and Bool(UnitIsUnit(b.unit, "player"), false) then
			byUnit.player = b
			return
		end
	end
end

function G:SetUnit(b, unit)
	if b.unit and byUnit[b.unit] == b then byUnit[b.unit] = nil end
	b.unit = unit
	if unit then byUnit[unit] = b end
	self:MapPlayer()
	self:UpdateAll(b)
end

---------------------------------------------------------------------------
-- Updates
---------------------------------------------------------------------------
function G:UpdateAll(b)
	if not b.unit or not UnitExists(b.unit) then return end
	self:UpdateName(b)
	self:UpdateHealth(b)
	self:UpdatePower(b)
	self:UpdateAuras(b)
	self:UpdateIndicators(b)
	self:UpdateTarget(b)
	self:UpdateRange(b)
end

function G:UpdateName(b)
	b.name:SetText((UnitName(b.unit)))
	if self.db.healthColor == "dark" then
		b.name:SetTextColor(ClassColor(b.unit))
	else
		b.name:SetTextColor(1, 1, 1)
	end
end

function G:SetHealthText(b, unit, cur, max)
	local mode = self.db.healthText
	if mode == "none" then
		b.status:SetText("")
		return
	end
	if IsSecret(cur) or IsSecret(max) then
		-- Restricted in combat: only Blizzard's secret-aware helper can produce a percent.
		local ok = mode == "percent" and UnitHealthPercent and CurveConstants and pcall(function()
			b.status:SetFormattedText("%d%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
		end)
		if not ok then b.status:SetText("") end
		return
	end
	if not cur or not max or max <= 0 or cur >= max then
		b.status:SetText("")
	elseif mode == "percent" then
		b.status:SetFormattedText("%d%%", cur / max * 100)
	else
		b.status:SetText("-" .. (AbbreviateNumbers or tostring)(max - cur))
	end
end

function G:UpdateHealth(b)
	local unit, db = b.unit, self.db
	local cur, max = UnitHealth(unit), UnitHealthMax(unit)
	b.health:SetMinMaxValues(0, Num(max))
	b.health:SetValue(Num(cur))

	b.incoming:SetMinMaxValues(0, Num(max))
	if db.healPrediction then
		b.incoming:SetValue(Num(UnitGetIncomingHeals(unit)))
	else
		b.incoming:SetValue(0)
	end
	b.absorb:SetMinMaxValues(0, Num(max))
	if db.absorbs and UnitGetTotalAbsorbs then
		b.absorb:SetValue(Num(UnitGetTotalAbsorbs(unit)))
	else
		b.absorb:SetValue(0)
	end

	local connected = Bool(UnitIsConnected(unit), true)
	local dead = Bool(UnitIsDeadOrGhost(unit), false)
	if not connected then
		b.status:SetText(PLAYER_OFFLINE or "Offline")
	elseif dead then
		b.status:SetText(DEAD or "Dead")
	else
		self:SetHealthText(b, unit, cur, max)
	end

	local r, g, bl
	if not connected or dead then
		r, g, bl = 0.35, 0.35, 0.35
	elseif db.healthColor == "class" then
		r, g, bl = ClassColor(unit)
	elseif db.healthColor == "dark" then
		r, g, bl = 0.16, 0.16, 0.18
	else
		r, g, bl = T:Color("health")
	end
	b.health:SetStatusBarColor(r, g, bl)
end

function G:ShowsPower(unit)
	local mode = self.db.showPower
	if mode == "ALL" then return true end
	if mode == "NONE" then return false end
	if mode == "MANA" then
		local powerType = UnitPowerType(unit)
		return not IsSecret(powerType) and powerType == (Enum.PowerType and Enum.PowerType.Mana or 0)
	end
	local role = UnitGroupRolesAssigned(unit)
	return not IsSecret(role) and role == "HEALER"
end

function G:UpdatePower(b)
	local unit = b.unit
	local show = self:ShowsPower(unit)
	if show ~= b.powerShown then
		b.powerShown = show
		self:LayoutButton(b)
	end
	if not show then return end
	b.power:SetMinMaxValues(0, Num(UnitPowerMax(unit)))
	b.power:SetValue(Num(UnitPower(unit)))
	local _, token = UnitPowerType(unit)
	local c = not IsSecret(token) and token and PowerBarColor and PowerBarColor[token]
	if c then
		b.power:SetStatusBarColor(c.r, c.g, c.b)
	else
		b.power:SetStatusBarColor(0.25, 0.45, 1)
	end
end

-- Long buffs (Fortitude etc.) aren't worth a slot in the HoT corner.
local function IsLong(aura)
	local d = aura.duration
	if IsSecret(d) then return false end
	return not d or d == 0 or d > 120
end

local function SetIcon(f, unit, aura)
	f.icon:SetTexture(aura.icon)
	local count = aura.applications
	if not IsSecret(count) and count and count > 1 then
		f.count:SetText(count)
	else
		f.count:SetText("")
	end
	local dur, exp = aura.duration, aura.expirationTime
	if not IsSecret(dur) and not IsSecret(exp) then
		if dur and exp and dur > 0 then
			f.cd:SetCooldown(exp - dur, dur)
			f.cd:Show()
		else
			f.cd:Hide()
		end
	else
		-- Secret timings: 12.x duration objects can still drive the swipe.
		local ok = C_UnitAuras.GetAuraDuration and f.cd.SetCooldownFromDurationObject and pcall(function()
			f.cd:SetCooldownFromDurationObject(C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID))
		end)
		f.cd:SetShown(ok and true or false)
	end
	f:Show()
end

local function FillIcons(icons, unit, filter, limit, skipLong)
	local shown = 0
	for i = 1, 40 do
		if shown >= limit then break end
		local aura = GetAura(unit, i, filter)
		if not aura then break end
		if not (skipLong and IsLong(aura)) then
			shown = shown + 1
			SetIcon(icons[shown], unit, aura)
		end
	end
	for j = shown + 1, #icons do
		icons[j]:Hide()
	end
end

function G:UpdateAuras(b)
	if not GetAura then return end
	local unit, db = b.unit, self.db

	-- "RAID" on harmful auras = debuffs the player can dispel.
	local highlight = false
	if db.dispelHighlight then
		local aura = GetAura(unit, 1, "HARMFUL|RAID")
		if aura then
			local r, g, bl = T:Color("accent")
			local kind = aura.dispelName
			local c = not IsSecret(kind) and kind and DebuffTypeColor and DebuffTypeColor[kind]
			if c then r, g, bl = c.r, c.g, c.b end
			b.dispel:SetBackdropBorderColor(r, g, bl, 1)
			highlight = true
		end
	end
	b.dispel:SetShown(highlight)

	FillIcons(b.buffs, unit, "HELPFUL|PLAYER", db.myBuffs and MAX_BUFFS or 0, true)
	FillIcons(b.debuffs, unit, "HARMFUL", math.min(db.debuffs, MAX_DEBUFFS), false)
end

function G:UpdateIndicators(b)
	local unit = b.unit
	local role = UnitGroupRolesAssigned(unit)
	local atlas = self.db.showRole and not IsSecret(role) and ROLE_ATLAS[role]
	if atlas then
		b.role:SetAtlas(atlas)
		b.role:Show()
	else
		b.role:Hide()
	end

	local index = GetRaidTargetIndex(unit)
	if not IsSecret(index) and index then
		SetRaidTargetIconTexture(b.raidIcon, index)
		b.raidIcon:Show()
	else
		b.raidIcon:Hide()
	end
end

function G:UpdateTarget(b)
	b.targetBorder:SetShown(self.db.targetHighlight and Bool(UnitIsUnit(b.unit, "target"), false))
end

function G:UpdateRange(b)
	local unit, oor = b.unit, self.db.rangeAlpha
	if Bool(UnitIsUnit(unit, "player"), false) then
		b:SetAlpha(1)
		return
	end
	local inRange, checked = UnitInRange(unit)
	if IsSecret(inRange) or IsSecret(checked) then
		if b.SetAlphaFromBoolean then
			pcall(b.SetAlphaFromBoolean, b, inRange, 1, oor)
		end
		return
	end
	b:SetAlpha((checked and not inRange) and oor or 1)
end

local function ForEachVisible(method)
	for _, b in ipairs(buttons) do
		if b.unit and b:IsVisible() then G[method](G, b) end
	end
end

---------------------------------------------------------------------------
-- Header
---------------------------------------------------------------------------
function G:CreateHeader()
	local h = CreateFrame("Frame", "LumenGroupHeader", UIParent, "SecureGroupHeaderTemplate")
	h:SetPoint("TOPLEFT", self.anchor, "TOPLEFT")
	h:SetAttribute("template", "SecureUnitButtonTemplate")
	-- Runs in the secure environment, so new members can be added mid-combat.
	h:SetAttribute("initialConfigFunction", [[
		local header = self:GetParent()
		self:SetWidth(header:GetAttribute("lumen-width"))
		self:SetHeight(header:GetAttribute("lumen-height"))
		self:SetAttribute("*type1", "target")
		self:SetAttribute("*type2", "togglemenu")
		header:CallMethod("InitButton", self:GetName())
	]])
	h.InitButton = function(_, name)
		G:SetupButton(_G[name])
	end
	self.header = h
end

function G:ApplyHeader()
	local h, db = self.header, self.db
	if not h then return end
	local down = db.growth == "DOWN"

	h:SetAttribute("lumen-width", db.width)
	h:SetAttribute("lumen-height", db.height)
	for _, b in ipairs(buttons) do
		b:SetSize(db.width, db.height)
	end

	h:SetAttribute("showRaid", true)
	h:SetAttribute("showParty", true)
	h:SetAttribute("showPlayer", db.showPlayer)
	h:SetAttribute("showSolo", db.showSolo)
	h:SetAttribute("point", down and "TOP" or "LEFT")
	h:SetAttribute("xOffset", down and 0 or db.spacing)
	h:SetAttribute("yOffset", down and -db.spacing or 0)
	h:SetAttribute("columnSpacing", db.spacing)
	h:SetAttribute("columnAnchorPoint", down and "LEFT" or "TOP")
	h:SetAttribute("unitsPerColumn", 5)
	h:SetAttribute("maxColumns", 8)
	h:SetAttribute("sortMethod", "INDEX")
	if db.groupBy == "ROLE" then
		h:SetAttribute("groupBy", "ASSIGNEDROLE")
		h:SetAttribute("groupingOrder", "TANK,HEALER,DAMAGER,NONE")
	elseif db.groupBy == "CLASS" then
		h:SetAttribute("groupBy", "CLASS")
		h:SetAttribute("groupingOrder", table.concat(CLASS_SORT_ORDER, ","))
	else
		h:SetAttribute("groupBy", "GROUP")
		h:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
	end

	RegisterAttributeDriver(h, "state-visibility", db.showSolo and "show" or "[group] show; hide")
end

function G:HideBlizzard()
	Lumen:AfterCombat(function()
		for _, name in ipairs({ "CompactPartyFrame", "CompactRaidFrameContainer", "PartyFrame" }) do
			local f = _G[name]
			if f then
				f:UnregisterAllEvents()
				Lumen:SetHidden(f, true)
			end
		end
	end)
end

function G:OnEnable()
	self.anchor = Lumen:CreateAnchor("group", "Group frames", self.db.width, self.db.height, { "TOPLEFT", "TOPLEFT", 30, -320 })

	local unitEvents = {
		UNIT_HEALTH = "UpdateHealth",
		UNIT_MAXHEALTH = "UpdateHealth",
		UNIT_HEAL_PREDICTION = "UpdateHealth",
		UNIT_ABSORB_AMOUNT_CHANGED = "UpdateHealth",
		UNIT_CONNECTION = "UpdateAll",
		UNIT_FLAGS = "UpdateHealth",
		UNIT_NAME_UPDATE = "UpdateName",
		UNIT_AURA = "UpdateAuras",
		UNIT_POWER_UPDATE = "UpdatePower",
		UNIT_MAXPOWER = "UpdatePower",
		UNIT_DISPLAYPOWER = "UpdatePower",
	}
	for event, method in pairs(unitEvents) do
		self:RegisterEvent(event, function(_, _, unit)
			local b = byUnit[unit]
			if b and b:IsVisible() then G[method](G, b) end
		end)
	end
	self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
		G:MapPlayer()
		ForEachVisible("UpdateAll")
	end)
	self:RegisterEvent("PLAYER_ROLES_ASSIGNED", function() ForEachVisible("UpdateAll") end)
	self:RegisterEvent("RAID_TARGET_UPDATE", function() ForEachVisible("UpdateIndicators") end)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", function() ForEachVisible("UpdateTarget") end)

	C_Timer.NewTicker(0.25, function() ForEachVisible("UpdateRange") end)

	if self.db.hideBlizzard then self:HideBlizzard() end

	-- Secure frames can't be created in combat (e.g. after a /reload mid-fight).
	Lumen:AfterCombat(function()
		G:CreateHeader()
		G:Refresh()
	end)
end

function G:Refresh()
	Lumen:AfterCombat(function()
		G.anchor:SetSize(G.db.width, G.db.height)
		G:ApplyHeader()
		for _, b in ipairs(buttons) do
			G:StyleButton(b)
			G:UpdateAll(b)
		end
	end)
end
