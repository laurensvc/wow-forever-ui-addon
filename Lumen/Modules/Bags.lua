-- Bags: improves Blizzard's bags instead of replacing them, so item use, sorting,
-- search and the bag settings menu keep working. Adds item levels, dimmed junk,
-- a free-slot counter, scale and a cleaner frame.
local Lumen = select(2, ...).Lumen
local T = Lumen.Theme

local B = Lumen:NewModule("bags", {
	name = "Bags",
	defaults = {
		enabled = true,
		combined = true,
		itemLevel = true,
		dimJunk = true,
		freeSlots = true,
		skin = true,
		scale = 1,
	},
	options = {
		{ key = "combined", type = "toggle", name = "One combined bag", desc = "Show all bags in a single window (Blizzard's combined bags)." },
		{ key = "itemLevel", type = "toggle", name = "Item level on gear" },
		{ key = "dimJunk", type = "toggle", name = "Dim junk (gray items)" },
		{ key = "freeSlots", type = "toggle", name = "Free slot counter" },
		{ key = "skin", type = "toggle", name = "Lumen frame style", reload = true },
		{ key = "scale", type = "range", name = "Scale", min = 0.6, max = 1.5, step = 0.05 },
	},
})

local overlays = setmetatable({}, { __mode = "k" })
local skinned = {}

local function BagFrames()
	local list = {}
	if ContainerFrameCombinedBags then list[#list + 1] = ContainerFrameCombinedBags end
	for i = 1, 13 do
		local f = _G["ContainerFrame" .. i]
		if f then list[#list + 1] = f end
	end
	return list
end

local function IsGear(link)
	local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(link)
	return (classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor)
		and equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
end

function B:DecorateButton(button)
	local o = overlays[button]
	if not o then
		o = {}
		o.ilvl = button:CreateFontString(nil, "OVERLAY", nil, 7)
		o.ilvl:SetPoint("TOPLEFT", 2, -2)
		o.dim = button:CreateTexture(nil, "ARTWORK", nil, 7)
		o.dim:SetAllPoints(button.icon or button)
		o.dim:SetColorTexture(0, 0, 0, 0.55)
		overlays[button] = o
	end
	T:SetFont(o.ilvl, 12)
	o.ilvl:SetText("")
	o.dim:Hide()

	local bag = button.GetBagID and button:GetBagID() or button:GetParent():GetID()
	local info = bag and C_Container.GetContainerItemInfo(bag, button:GetID())
	if not info then return end

	if self.db.dimJunk and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue then
		o.dim:Show()
	end
	if self.db.itemLevel and info.hyperlink and IsGear(info.hyperlink) then
		local level = C_Item.GetDetailedItemLevelInfo(info.hyperlink)
		if level and level > 1 then
			o.ilvl:SetText(level)
			local c = ITEM_QUALITY_COLORS[info.quality]
			if c then
				o.ilvl:SetTextColor(c.r, c.g, c.b)
			else
				o.ilvl:SetTextColor(1, 1, 1)
			end
		end
	end
end

function B:UpdateFreeSlots()
	local f = ContainerFrameCombinedBags
	if not f then return end
	if not self.free then
		self.free = f:CreateFontString(nil, "OVERLAY")
		self.free:SetPoint("TOPRIGHT", f, "TOPRIGHT", -32, -8)
	end
	T:SetFont(self.free, 11)
	self.free:SetShown(self.db.freeSlots)
	local free = 0
	for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
		free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
	end
	self.free:SetFormattedText("%d free", free)
	if free < 5 then
		self.free:SetTextColor(1, 0.3, 0.3)
	else
		self.free:SetTextColor(T:Color("accent"))
	end
end

function B:Skin(frame)
	if skinned[frame] or not self.db.skin then return end
	skinned[frame] = T:CreateBackdrop(frame, 0)
	for _, key in ipairs({ "NineSlice", "Bg", "Background", "TopTileStreaks" }) do
		if frame[key] then frame[key]:SetAlpha(0) end
	end
end

function B:Decorate(frame)
	if not frame:IsShown() or not frame.EnumerateValidItems then return end
	self:Skin(frame)
	for _, button in frame:EnumerateValidItems() do
		self:DecorateButton(button)
	end
	if frame == ContainerFrameCombinedBags then
		self:UpdateFreeSlots()
	end
end

function B:ApplyScale()
	for _, f in ipairs(BagFrames()) do
		f:SetScale(self.db.scale)
	end
end

function B:UpdateOpen()
	for _, f in ipairs(BagFrames()) do
		self:Decorate(f)
	end
end

function B:OnEnable()
	for _, f in ipairs(BagFrames()) do
		if f.UpdateItems then
			hooksecurefunc(f, "UpdateItems", function(frame) B:Decorate(frame) end)
		end
		f:HookScript("OnShow", function(frame) B:Decorate(frame) end)
	end
	if UpdateContainerFrameAnchors then
		hooksecurefunc("UpdateContainerFrameAnchors", function() B:ApplyScale() end)
	end
	self:RegisterEvent("BAG_UPDATE_DELAYED", "UpdateOpen")
	self:Refresh()
end

function B:Refresh()
	if C_CVar and C_CVar.SetCVar then
		C_CVar.SetCVar("combinedBags", self.db.combined and "1" or "0")
	end
	self:ApplyScale()
	self:UpdateOpen()
end
