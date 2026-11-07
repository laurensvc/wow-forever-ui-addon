-- Builds the Esc > Options > AddOns > Lumen panel from each module's `options` list.
--
-- Option shapes:
--   { type = "header", name = "..." }
--   { key = "x", type = "toggle", name = "...", desc = "...", reload = true? }
--   { key = "x", type = "range",  name = "...", min = 0, max = 10, step = 1, format = "%.2f"? }
--   { key = "x", type = "select", name = "...", values = { { "value", "Label" }, ... } }
local Lumen = select(2, ...).Lumen

StaticPopupDialogs.LUMEN_RELOAD = {
	text = "Lumen: this change needs a UI reload.",
	button1 = RELOADUI or "Reload UI",
	button2 = CANCEL,
	OnAccept = function() ReloadUI() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local CreateCheckbox = Settings.CreateCheckbox or Settings.CreateCheckBox
local CreateDropdown = Settings.CreateDropdown or Settings.CreateDropDown

local function AddOption(category, layout, m, opt)
	if opt.type == "header" then
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(opt.name))
		return
	end

	local variable = "Lumen_" .. m.key .. "_" .. opt.key
	local default = m.defaults[opt.key]
	local setting = Settings.RegisterAddOnSetting(category, variable, opt.key, m.db, type(default), opt.name, default)
	Settings.SetOnValueChangedCallback(variable, function()
		Lumen:OnOptionChanged(m, opt)
	end)

	if opt.type == "toggle" then
		CreateCheckbox(category, setting, opt.desc)
	elseif opt.type == "range" then
		local o = Settings.CreateSliderOptions(opt.min, opt.max, opt.step)
		local fmt = opt.format or (opt.step < 1 and "%.2f" or "%d")
		o:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
			return fmt:format(v)
		end)
		Settings.CreateSlider(category, setting, o, opt.desc)
	elseif opt.type == "select" then
		CreateDropdown(category, setting, function()
			local c = Settings.CreateControlTextContainer()
			for _, v in ipairs(opt.values) do
				c:Add(v[1], v[2])
			end
			return c:GetData()
		end, opt.desc)
	end
end

local function AddButton(layout, name, buttonText, onClick, tooltip)
	if CreateSettingsButtonInitializer then
		layout:AddInitializer(CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, true))
	end
end

function Lumen:BuildSettings()
	local root, rootLayout = Settings.RegisterVerticalLayoutCategory("Lumen")
	self.settingsCategory = root

	for _, m in ipairs(self.modules) do
		if m.core then
			for _, opt in ipairs(m.options) do
				AddOption(root, rootLayout, m, opt)
			end
		end
	end

	rootLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Tools"))
	AddButton(rootLayout, "Move frames", "Unlock / lock", function() Lumen:ToggleMovers() end,
		"Show drag handles for Lumen frames (group frames). Same as /lumen move.")
	AddButton(rootLayout, "Reload UI", RELOADUI or "Reload", function() ReloadUI() end,
		"Some changes, like turning a module on or off, need a reload.")

	for _, m in ipairs(self.modules) do
		if not m.core then
			local cat, layout = Settings.RegisterVerticalLayoutSubcategory(root, m.name)
			AddOption(cat, layout, m, {
				key = "enabled", type = "toggle", name = "Enable " .. m.name,
				desc = "Turn this module on or off. Needs a UI reload.", reload = true,
			})
			for _, opt in ipairs(m.options) do
				AddOption(cat, layout, m, opt)
			end
		end
	end

	Settings.RegisterAddOnCategory(root)
end

function Lumen:OpenSettings()
	Settings.OpenToCategory(self.settingsCategory:GetID())
end
