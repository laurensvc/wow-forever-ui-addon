-- Chat: short channel names, clickable links you can copy, fewer buttons, faster scrolling.
local Lumen = select(2, ...).Lumen
local IsSecret = Lumen.IsSecret

local C = Lumen:NewModule("chat", {
	name = "Chat",
	defaults = {
		enabled = true,
		shortChannels = true,
		urls = true,
		hideButtons = true,
		hideSocial = false,
		fastScroll = true,
	},
	options = {
		{ key = "shortChannels", type = "toggle", name = "Short channel names", desc = "[2. Trade - City] becomes [2], [Guild] becomes [G], [Raid Leader] becomes [RL]." },
		{ key = "urls", type = "toggle", name = "Clickable web links", desc = "Click a link in chat to get a box you can copy it from." },
		{ key = "hideButtons", type = "toggle", name = "Hide chat side buttons", desc = "Hides the menu, channel and voice buttons next to chat. Slash commands still work." },
		{ key = "hideSocial", type = "toggle", name = "Hide social (friends) button" },
		{ key = "fastScroll", type = "toggle", name = "Fast scrolling", desc = "Shift + mouse wheel jumps to top/bottom, Ctrl + wheel scrolls faster." },
	},
})

local SHORT = {}
local function BuildShortNames()
	local map = {
		{ CHAT_MSG_GUILD, "G" }, { CHAT_MSG_OFFICER, "O" },
		{ CHAT_MSG_PARTY, "P" }, { CHAT_MSG_PARTY_LEADER, "PL" },
		{ CHAT_MSG_RAID, "R" }, { CHAT_MSG_RAID_LEADER, "RL" }, { CHAT_MSG_RAID_WARNING, "RW" },
		{ INSTANCE_CHAT, "I" }, { INSTANCE_CHAT_LEADER, "IL" },
	}
	for _, pair in ipairs(map) do
		if pair[1] then SHORT[pair[1]] = pair[2] end
	end
end

local function ShortenChannel(link, name)
	local short = name:match("^(%d+)%.") or SHORT[name]
	if short then
		return "|Hchannel:" .. link .. "|h[" .. short .. "]|h"
	end
end

local function LinkifyWord(word)
	if not (word:find("^https?://") or word:find("^www%.")) then return end
	local url, trail = word:match("^(.-)([%.,!%?%)]*)$")
	return "|cff7fb8ff|Haddon:Lumen:url:" .. url .. "|h[" .. url .. "]|h|r" .. trail
end

local function Filter(msg)
	-- Messages can be secret during restricted encounters; leave those alone.
	if IsSecret(msg) or type(msg) ~= "string" then return msg end
	if C.db.shortChannels then
		msg = msg:gsub("|Hchannel:(.-)|h%[(.-)%]|h", ShortenChannel)
	end
	if C.db.urls then
		msg = msg:gsub("%S+", LinkifyWord)
	end
	return msg
end

---------------------------------------------------------------------------
-- Copy box for clicked links
---------------------------------------------------------------------------
StaticPopupDialogs.LUMEN_URL = {
	text = "Press Ctrl+C to copy the link:",
	button1 = CLOSE,
	hasEditBox = true,
	editBoxWidth = 320,
	OnShow = function(self, url)
		local box = self.GetEditBox and self:GetEditBox() or self.editBox
		box:SetText(url or "")
		box:HighlightText()
		box:SetFocus()
	end,
	EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
	EditBoxOnEnterPressed = function(box) box:GetParent():Hide() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local lastUrl, lastTime = nil, 0
local function OnLink(link)
	local url = type(link) == "string" and link:match("^addon:Lumen:url:(.+)$")
	if not url then return end
	-- Both hooks below may fire for one click.
	if url == lastUrl and GetTime() - lastTime < 0.3 then return end
	lastUrl, lastTime = url, GetTime()
	StaticPopup_Show("LUMEN_URL", nil, nil, url)
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
local original = {}

function C:HookChatFrame(cf)
	if original[cf] then return end
	original[cf] = cf.AddMessage
	cf.AddMessage = function(frame, msg, ...)
		return original[frame](frame, Filter(msg), ...)
	end
	cf:HookScript("OnMouseWheel", function(frame, delta)
		if not C.db.fastScroll then return end
		if IsShiftKeyDown() then
			if delta > 0 then frame:ScrollToTop() else frame:ScrollToBottom() end
		elseif IsControlKeyDown() then
			for _ = 1, 4 do
				if delta > 0 then frame:ScrollUp() else frame:ScrollDown() end
			end
		end
	end)
end

function C:OnEnable()
	BuildShortNames()
	for i = 1, NUM_CHAT_WINDOWS or 10 do
		local cf = _G["ChatFrame" .. i]
		if cf and cf ~= ChatFrame2 then -- ChatFrame2 is the combat log
			self:HookChatFrame(cf)
		end
	end
	if EventRegistry then
		EventRegistry:RegisterCallback("SetItemRef", function(_, link) OnLink(link) end, self)
	end
	hooksecurefunc("SetItemRef", OnLink)
	self:Refresh()
end

function C:Refresh()
	local db = self.db
	for _, name in ipairs({ "ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }) do
		Lumen:SetHidden(_G[name], db.hideButtons)
	end
	for i = 1, NUM_CHAT_WINDOWS or 10 do
		Lumen:SetHidden(_G["ChatFrame" .. i .. "ButtonFrame"], db.hideButtons)
	end
	Lumen:SetHidden(QuickJoinToastButton, db.hideSocial)
end
