local CW = CraftWarn
if not CW then
	return
end

---------------------------------------------------------------------------
-- Table-driven options schema
---------------------------------------------------------------------------

local OPTIONS_SCHEMA = {
	{ key = "restoreLastRecipe",      text = "Restore last customer-order recipe and reagents",      tooltip = "When reopening customer orders, re-open last selected recipe and re-apply saved reagent selections." },
	{ key = "enableSpecStatWarning",  text = "Warn on spec primary-stat mismatch",                   tooltip = "Shows a warning if the crafted item primary stat does not match your current specialization primary stat.", refresh = true },
	{ key = "enableSpecStatMatch",     text = "Show confirmation when stat matches spec",             tooltip = "Shows a green confirmation message when the crafted item primary stat matches your current specialization.", refresh = true },
	{ key = "enableNoPrimaryStatInfo", text = "Show info when crafted item has no primary stat",      tooltip = "Lower-priority info for items like rings/neck when no primary stat exists.", refresh = true },
	{ key = "autoOpenLastRecipe",     text = "Auto-open last recipe when browsing orders",            tooltip = "Automatically re-open the last recipe when the customer orders window opens." },
	{ key = "forgetOnBack",           text = "Don't auto-open last recipe after clicking Back",       tooltip = "After clicking Back on the order form, the last recipe will not be automatically re-opened next time." },
	{ key = "forgetOnPlace",          text = "Don't auto-open last recipe after placing an order",    tooltip = "After placing an order, the last recipe will not be automatically re-opened next time." },
}

local function CreateCheckbox(parent, schema, yOffset)
	local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
	checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
	checkbox.Text:SetText(schema.text)
	checkbox.tooltipText = schema.tooltip

	checkbox:SetScript("OnClick", function(button)
		CraftWarnDB[schema.key] = button:GetChecked() and true or false
		if schema.refresh then
			local form = CW:GetVisibleOrderForm()
			if form then
				CW:RefreshFormWarnings(form)
			end
		end
	end)

	return checkbox
end

---------------------------------------------------------------------------
-- Panel creation
---------------------------------------------------------------------------

function CW:CreateOptionsPanel()
	if self.optionsPanel then
		return self.optionsPanel
	end

	local panel = CreateFrame("Frame")
	panel.name = "CraftWarn"

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
	title:SetText("CraftWarn")

	local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	subtitle:SetText("Remember last customer-order recipe and show safety warnings.")

	local checkboxes = {}
	for i, schema in ipairs(OPTIONS_SCHEMA) do
		local yOffset = -24 - (i * 30)
		checkboxes[i] = CreateCheckbox(panel, schema, yOffset)
	end

	panel:SetScript("OnShow", function()
		if not CraftWarnDB then return end
		for i, schema in ipairs(OPTIONS_SCHEMA) do
			checkboxes[i]:SetChecked(CraftWarnDB[schema.key])
		end
	end)

	if Settings and Settings.RegisterCanvasLayoutCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
		Settings.RegisterAddOnCategory(category)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end

	self.optionsPanel = panel
	return panel
end

CW:CreateOptionsPanel()
