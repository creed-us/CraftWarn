local CW = CraftWarn

local UI_CONFIG = CW.UI_CONFIG
local WARNING_COLORS = UI_CONFIG.warningColors
local WARNING_ICONS = UI_CONFIG.warningIcons
local WARNING_ROW_COUNT = UI_CONFIG.warningRowCount
local WARNING_ICON_SIZE = UI_CONFIG.warningIconSize
local WARNING_ICON_TEXT_GAP = UI_CONFIG.warningIconTextGap
local WARNING_ICON_LINE_SPACING = UI_CONFIG.warningIconLineSpacing
local WARNING_INFO_ICON_TINT = UI_CONFIG.warningInfoIconTint

local function OnRowEnter(row)
	if not row.tooltipText then
		return
	end
	GameTooltip:SetOwner(row, "ANCHOR_LEFT")
	GameTooltip:SetText(row.tooltipText, 1, 1, 1, 1, true)
	GameTooltip:Show()
end

-- Each row is an independently positioned, hoverable frame: a short status icon plus minimal
-- text, with the full explanation available on hover.
function CW:BuildWarningFrames(form)
	if not form or form.CraftWarnWarnings then
		return
	end

	local holder = CreateFrame("Frame", nil, form)
	if form.FavoriteButton then
		holder:SetPoint("TOPRIGHT", form.FavoriteButton, "BOTTOMRIGHT", 0, UI_CONFIG.warningHolderOffsetY)
	else
		local anchorTarget = form.RecipeHeader or form.ReagentContainer or form
		holder:SetPoint("TOPRIGHT", anchorTarget, "TOPRIGHT", 0, UI_CONFIG.warningHolderOffsetY)
	end
	holder:SetWidth(UI_CONFIG.warningHolderWidth)
	holder:SetHeight(UI_CONFIG.warningHolderHeight)

	local rows = {}
	for i = 1, WARNING_ROW_COUNT do
		local row = CreateFrame("Frame", nil, holder)
		row:SetHeight(WARNING_ICON_SIZE)
		row:EnableMouse(true)
		row:Hide()
		row:SetScript("OnEnter", OnRowEnter)
		row:SetScript("OnLeave", GameTooltip_Hide)

		local icon = row:CreateTexture(nil, "OVERLAY")
		icon:SetSize(WARNING_ICON_SIZE, WARNING_ICON_SIZE)
		icon:SetPoint("RIGHT", row, "RIGHT", 0, 0)

		local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		text:SetJustifyH("RIGHT")
		text:SetWordWrap(false)
		text:SetPoint("LEFT", row, "LEFT", 0, 0)
		text:SetPoint("RIGHT", icon, "LEFT", -WARNING_ICON_TEXT_GAP, 0)

		rows[i] = { frame = row, icon = icon, text = text }
	end

	form.CraftWarnWarnings = { holder = holder, rows = rows }
end

local function SetRowIcon(icon, state)
	if state == "match" then
		icon:SetTexture(WARNING_ICONS.match)
		icon:SetVertexColor(1, 1, 1)
	elseif state == "warning" then
		icon:SetTexture(WARNING_ICONS.warning)
		icon:SetVertexColor(1, 1, 1)
	else
		icon:SetTexture(WARNING_ICONS.info)
		icon:SetVertexColor(WARNING_INFO_ICON_TINT[1], WARNING_INFO_ICON_TINT[2], WARNING_INFO_ICON_TINT[3])
	end
end

-- payload is an array of up to WARNING_ROW_COUNT entries: { state, text, tooltip } or nil to hide that row.
function CW:RenderWarnings(form, payload)
	self:BuildWarningFrames(form)

	local warnings = form and form.CraftWarnWarnings
	if not warnings then
		return
	end

	local previousRow = nil
	local anyShown = false

	for i, row in ipairs(warnings.rows) do
		local data = payload and payload[i]
		local text = data and data.text

		if text and text ~= "" then
			row.frame:ClearAllPoints()
			if previousRow then
				row.frame:SetPoint("TOPLEFT", previousRow.frame, "BOTTOMLEFT", 0, -WARNING_ICON_LINE_SPACING)
				row.frame:SetPoint("TOPRIGHT", previousRow.frame, "BOTTOMRIGHT", 0, -WARNING_ICON_LINE_SPACING)
			else
				row.frame:SetPoint("TOPLEFT", warnings.holder, "TOPLEFT", 0, 0)
				row.frame:SetPoint("TOPRIGHT", warnings.holder, "TOPRIGHT", 0, 0)
			end

			row.text:SetText(text)
			local color = WARNING_COLORS[data.state] or WARNING_COLORS.info
			row.text:SetTextColor(color[1], color[2], color[3])
			SetRowIcon(row.icon, data.state)

			row.frame.tooltipText = data.tooltip
			row.frame:Show()

			previousRow = row
			anyShown = true
		else
			row.frame:Hide()
			row.frame.tooltipText = nil
		end
	end

	warnings.holder:SetShown(anyShown)
end
