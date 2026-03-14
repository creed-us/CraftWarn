local CW = CraftWarn
if not CW then
	return
end

---------------------------------------------------------------------------
-- Table-driven options schema
---------------------------------------------------------------------------

local OPTIONS_SCHEMA = CW.OPTIONS_SCHEMA
local TEXT = CW.TEXT

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
	panel.name = TEXT.optionsPanelName

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
	title:SetText(TEXT.optionsPanelName)

	local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	subtitle:SetText(TEXT.optionsSubtitle)

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
