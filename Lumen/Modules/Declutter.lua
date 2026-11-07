-- Declutter: hide or fade the bits of the default UI you don't need.
local Lumen = select(2, ...).Lumen

local VISIBILITY = { { "show", "Always show" }, { "mouseover", "Show on mouseover" }, { "hide", "Hide" } }

local D = Lumen:NewModule("declutter", {
	name = "Declutter",
	defaults = {
		enabled = true,
		hideBarArt = true,
		bagBar = "mouseover",
		microMenu = "mouseover",
		talkingHead = true,
		combatErrors = true,
		zoneText = false,
		bossBanner = false,
		collapseTracker = false,
	},
	options = {
		{ type = "header", name = "Action bars & menus" },
		{ key = "hideBarArt", type = "toggle", name = "Hide action bar art", desc = "Removes the gryphons and the frame art around the main action bar." },
		{ key = "bagBar", type = "select", name = "Bag buttons", values = VISIBILITY },
		{ key = "microMenu", type = "select", name = "Menu buttons", desc = "Character, spellbook, talents, ... (key bindings still work).", values = VISIBILITY },
		{ type = "header", name = "Pop-ups & messages" },
		{ key = "talkingHead", type = "toggle", name = "Hide talking heads", desc = "NPC portrait pop-ups with voice lines." },
		{ key = "combatErrors", type = "toggle", name = "Hide red error text in combat", desc = "\"Not enough mana\", \"Spell is not ready yet\", ..." },
		{ key = "zoneText", type = "toggle", name = "Hide big zone names", desc = "The zone name that appears mid-screen when you enter an area." },
		{ key = "bossBanner", type = "toggle", name = "Hide boss kill / loot banner" },
		{ type = "header", name = "Quests" },
		{ key = "collapseTracker", type = "toggle", name = "Collapse quest tracker in dungeons & raids" },
	},
})

local function SetVisibility(frame, mode)
	if not frame then return end
	Lumen:SetHidden(frame, mode == "hide")
	Lumen:SetMouseoverFade(frame, mode == "mouseover")
end

function D:UpdateErrors(inCombat)
	if not UIErrorsFrame then return end
	if self.db.combatErrors and inCombat then
		UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
	else
		UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
	end
end

function D:UpdateTracker()
	local tracker = ObjectiveTrackerFrame
	if not tracker or not tracker.SetCollapsed then return end
	Lumen:AfterCombat(function()
		local _, kind = IsInInstance()
		local inside = kind == "party" or kind == "raid"
		if self.db.collapseTracker and inside then
			tracker:SetCollapsed(true)
			self.collapsedByUs = true
		elseif self.collapsedByUs then
			tracker:SetCollapsed(false)
			self.collapsedByUs = false
		end
	end)
end

function D:HookTalkingHead()
	if self.talkingHeadHooked or not TalkingHeadFrame or not TalkingHeadFrame.PlayCurrent then return end
	self.talkingHeadHooked = true
	hooksecurefunc(TalkingHeadFrame, "PlayCurrent", function(frame)
		if D.db.talkingHead and frame.CloseImmediately then frame:CloseImmediately() end
	end)
end

function D:OnEnable()
	self:RegisterEvent("PLAYER_REGEN_DISABLED", function() D:UpdateErrors(true) end)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function() D:UpdateErrors(false) end)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateTracker")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateTracker")
	self:RegisterEvent("ADDON_LOADED", function(_, _, name)
		if name == "Blizzard_TalkingHeadUI" then D:HookTalkingHead() end
	end)
	self:HookTalkingHead()
	self:Refresh()
end

function D:Refresh()
	local db = self.db
	local bar = MainActionBar or MainMenuBar
	if bar then
		Lumen:SetHidden(bar.EndCaps, db.hideBarArt)
		Lumen:SetHidden(bar.BorderArt, db.hideBarArt)
	end
	SetVisibility(BagsBar, db.bagBar)
	SetVisibility(MicroMenuContainer or MicroMenu, db.microMenu)
	Lumen:SetHidden(ZoneTextFrame, db.zoneText)
	Lumen:SetHidden(SubZoneTextFrame, db.zoneText)
	Lumen:SetHidden(BossBanner, db.bossBanner)
	self:UpdateErrors(InCombatLockdown())
	self:UpdateTracker()
end
