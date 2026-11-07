-- Lumen core: module registry, saved variables, combat-safe helpers, movers, slash command.
local ADDON, ns = ...

local Lumen = CreateFrame("Frame")
ns.Lumen = Lumen
_G.Lumen = Lumen

Lumen.modules = {}
Lumen.anchors = {}

function Lumen:Print(...)
	print("|cfff2c14eLumen|r:", ...)
end

---------------------------------------------------------------------------
-- Secret values (Midnight / 12.x API)
-- In combat many APIs return "secret" values. Addon code may hand them to
-- widgets (StatusBar:SetValue, FontString:SetText, ...) but may not compare,
-- test or do math on them. These helpers keep that rule in one place.
---------------------------------------------------------------------------
function Lumen.IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

-- A number that is safe to pass to a widget: secret values pass through, nil becomes 0.
function Lumen.Num(v)
	if Lumen.IsSecret(v) then return v end
	return v or 0
end

-- A boolean we can branch on: secret values fall back to `fallback`.
function Lumen.Bool(v, fallback)
	if Lumen.IsSecret(v) then return fallback end
	return v
end

---------------------------------------------------------------------------
-- Combat lockdown: protected frames can only be changed out of combat.
---------------------------------------------------------------------------
local pending = {}

function Lumen:AfterCombat(fn)
	if InCombatLockdown() then
		pending[#pending + 1] = fn
	else
		fn()
	end
end

---------------------------------------------------------------------------
-- Hiding Blizzard frames: reparent to a hidden frame so Blizzard's own
-- Show() calls stay invisible. Reversible.
---------------------------------------------------------------------------
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
local savedParents = setmetatable({}, { __mode = "k" })

function Lumen:SetHidden(frame, hide)
	if not frame then return end
	self:AfterCombat(function()
		if hide and not savedParents[frame] then
			savedParents[frame] = frame:GetParent() or UIParent
			frame:SetParent(hiddenParent)
		elseif not hide and savedParents[frame] then
			frame:SetParent(savedParents[frame])
			savedParents[frame] = nil
		end
	end)
end

---------------------------------------------------------------------------
-- Mouseover fading: frame is invisible until the cursor is over it.
---------------------------------------------------------------------------
local faded = {}
local fadeTicker

function Lumen:SetMouseoverFade(frame, enable)
	if not frame then return end
	if enable then
		faded[frame] = true
	elseif faded[frame] then
		faded[frame] = nil
		frame:SetAlpha(1)
	end
	if next(faded) and not fadeTicker then
		fadeTicker = C_Timer.NewTicker(0.15, function()
			for f in pairs(faded) do
				f:SetAlpha(f:IsMouseOver() and 1 or 0)
			end
		end)
	elseif not next(faded) and fadeTicker then
		fadeTicker:Cancel()
		fadeTicker = nil
	end
end

---------------------------------------------------------------------------
-- Movers: plain anchor frames our own frames attach to. /lumen move
---------------------------------------------------------------------------
function Lumen:CreateAnchor(key, label, width, height, default)
	local a = CreateFrame("Frame", "LumenAnchor_" .. key, UIParent)
	a:SetSize(width, height)
	a:SetMovable(true)
	a:SetClampedToScreen(true)
	local pos = self.db.positions[key] or default
	a:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])

	local h = CreateFrame("Frame", nil, a, "BackdropTemplate")
	h:SetAllPoints()
	h:SetFrameStrata("DIALOG")
	h:EnableMouse(true)
	h:RegisterForDrag("LeftButton")
	h:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	h:SetBackdropColor(0.95, 0.78, 0.36, 0.25)
	h:SetBackdropBorderColor(0.95, 0.78, 0.36, 1)
	local text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("CENTER")
	text:SetText(label)
	h:SetScript("OnDragStart", function() a:StartMoving() end)
	h:SetScript("OnDragStop", function()
		a:StopMovingOrSizing()
		local point, _, relPoint, x, y = a:GetPoint()
		self.db.positions[key] = { point, relPoint, x, y }
	end)
	h:Hide()

	a.mover = h
	self.anchors[key] = a
	return a
end

function Lumen:ToggleMovers(state)
	if InCombatLockdown() then
		self:Print("You can't move frames in combat.")
		return
	end
	if state == nil then state = not self.moving end
	self.moving = state
	for _, a in pairs(self.anchors) do
		a.mover:SetShown(state)
	end
	if state then
		self:Print("Drag the gold boxes to move frames. Type /lumen move again to lock.")
	end
end

---------------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------------
local Module = {}
Module.__index = Module

-- handler: a function(self, event, ...) or the name of a method; defaults to the event name.
function Module:RegisterEvent(event, handler)
	if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then
		return false
	end
	self.handlers[event] = handler or event
	self.eventFrame:RegisterEvent(event)
	return true
end

function Module:UnregisterEvent(event)
	self.handlers[event] = nil
	self.eventFrame:UnregisterEvent(event)
end

-- info: { name, defaults, options, core }
function Lumen:NewModule(key, info)
	local m = setmetatable({
		key = key,
		name = info.name,
		defaults = info.defaults or {},
		options = info.options or {},
		core = info.core,
		handlers = {},
	}, Module)
	m.eventFrame = CreateFrame("Frame")
	m.eventFrame:SetScript("OnEvent", function(_, event, ...)
		local h = m.handlers[event]
		if type(h) == "string" then h = m[h] end
		if h then h(m, event, ...) end
	end)
	self.modules[#self.modules + 1] = m
	return m
end

function Lumen:GetModule(key)
	for _, m in ipairs(self.modules) do
		if m.key == key then return m end
	end
end

-- Called by Settings.lua whenever an option changes.
function Lumen:OnOptionChanged(m, opt)
	if opt.reload then
		StaticPopup_Show("LUMEN_RELOAD")
		return
	end
	if m.core then
		-- Theme changed: everything restyles.
		for _, mod in ipairs(self.modules) do
			if mod.enabled and mod.Refresh then mod:Refresh() end
		end
	elseif m.enabled and m.Refresh then
		m:Refresh(opt.key)
	end
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
local function ApplyDefaults(db, defaults)
	for k, v in pairs(defaults) do
		if type(v) == "table" then
			if type(db[k]) ~= "table" then db[k] = {} end
			ApplyDefaults(db[k], v)
		elseif db[k] == nil then
			db[k] = v
		end
	end
end

Lumen:RegisterEvent("ADDON_LOADED")
Lumen:RegisterEvent("PLAYER_LOGIN")
Lumen:RegisterEvent("PLAYER_REGEN_ENABLED")
Lumen:RegisterEvent("PLAYER_REGEN_DISABLED")

Lumen:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON then
		LumenDB = LumenDB or {}
		LumenDB.positions = LumenDB.positions or {}
		for _, m in ipairs(self.modules) do
			LumenDB[m.key] = LumenDB[m.key] or {}
			ApplyDefaults(LumenDB[m.key], m.defaults)
			m.db = LumenDB[m.key]
		end
		self.db = LumenDB
		self:BuildSettings()
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		for _, m in ipairs(self.modules) do
			if m.core then
				m.enabled = true
			elseif m.db.enabled and m.OnEnable then
				m.enabled = true
				local ok = xpcall(m.OnEnable, geterrorhandler(), m)
				if not ok then m.enabled = false end
			end
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		if self.moving then self:ToggleMovers(false) end
	elseif event == "PLAYER_REGEN_ENABLED" then
		local queue = pending
		pending = {}
		for _, fn in ipairs(queue) do
			xpcall(fn, geterrorhandler())
		end
	end
end)

SLASH_LUMEN1 = "/lumen"
SlashCmdList.LUMEN = function(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "move" then
		Lumen:ToggleMovers()
	elseif msg == "reset" then
		wipe(Lumen.db.positions)
		Lumen:Print("Frame positions reset. Type /reload to apply.")
	else
		Lumen:OpenSettings()
	end
end
