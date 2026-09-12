local CW = CraftWarn

local SPEC_TO_STAT_KEY  = CW.SPEC_TO_STAT_KEY
local PRIMARY_STATS     = CW.PRIMARY_STATS
local STAT_KEY_TO_LABEL = CW.STAT_KEY_TO_LABEL
local ITEM_ANALYSIS_CACHE_SIZE = CW.ITEM_ANALYSIS_CACHE_SIZE
local WARNING_TEXT = CW.TEXT.warnings

local itemAnalysisByLink = {}
local itemAnalysisLru = {}

local function TouchItemAnalysisLink(itemLink)
	for i, link in ipairs(itemAnalysisLru) do
		if link == itemLink then
			table.remove(itemAnalysisLru, i)
			break
		end
	end

	table.insert(itemAnalysisLru, 1, itemLink)

	while #itemAnalysisLru > ITEM_ANALYSIS_CACHE_SIZE do
		local evicted = table.remove(itemAnalysisLru)
		itemAnalysisByLink[evicted] = nil
	end
end

function CW:GetItemAnalysis(itemLink)
	if not itemLink then
		return nil
	end

	local cached = itemAnalysisByLink[itemLink]
	if cached then
		TouchItemAnalysisLink(itemLink)
		return cached
	end

	local equippable = C_Item.IsEquippableItem(itemLink) or false
	local _, _, _, itemEquipLoc = C_Item.GetItemInfoInstant(itemLink)

	local primaryStatKeys = equippable and CW.DetectPrimaryStatsOnItem(itemLink) or nil
	local hasHiddenStatIndicator = equippable
		and (not primaryStatKeys or #primaryStatKeys == 0)
		and CW.HasHiddenPrimaryStatIndicator(itemLink)
		or false

	local analysis = {
		equippable = equippable,
		primaryStatKeys = primaryStatKeys,
		hasHiddenStatIndicator = hasHiddenStatIndicator,
		armorType = equippable and CW.GetItemArmorType(itemLink),
		slotLabel = equippable and CW.GetItemSlotLabel(itemEquipLoc) or nil,
		universalSlot = equippable and CW.IsUniversalArmorSlot(itemEquipLoc) or false,
	}

	itemAnalysisByLink[itemLink] = analysis
	TouchItemAnalysisLink(itemLink)
	return analysis
end

function CW:ClearItemAnalysisCache()
	itemAnalysisByLink = {}
	itemAnalysisLru = {}
end

function CW:GetCurrentOutputContext(form)
	if not form or not form.order or not form.order.spellID then
		return nil
	end

	local data = C_TradeSkillUI.GetRecipeOutputItemData(form.order.spellID)
	if data and data.hyperlink then
		return data.hyperlink
	end

	return form.order.recraftItemHyperlink
end

-- Row shape: { state = "match"|"warning"|"info", kind = <internal marker>, text = <short>, tooltip = <full> }.
function CW:BuildSpecMismatchWarning(form, itemLink, itemAnalysis)
	if not self.db.enableSpecStatWarning then
		return nil
	end

	local specInfo = CW.CurrentSpecInfo()
	if not specInfo or not specInfo.primaryStat then
		return nil
	end

	itemLink = itemLink or self:GetCurrentOutputContext(form)
	if not itemLink then
		return nil
	end

	itemAnalysis = itemAnalysis or self:GetItemAnalysis(itemLink)
	if not itemAnalysis or not itemAnalysis.equippable then
		return nil
	end

	local itemPrimaryStatKeys = itemAnalysis.primaryStatKeys
	if #itemPrimaryStatKeys == 0 then
		if not self.db.enableNoPrimaryStatInfo then
			return nil
		end
		if itemAnalysis.hasHiddenStatIndicator then
			return { state = "info", kind = "statProc", text = WARNING_TEXT.statProcText, tooltip = WARNING_TEXT.statProcTooltip }
		end
		return { state = "info", kind = "noStat", text = WARNING_TEXT.noStatText, tooltip = WARNING_TEXT.statNoneTooltip }
	end

	local expectedKey = SPEC_TO_STAT_KEY[specInfo.primaryStat]
	if not expectedKey then
		return nil
	end

	for _, key in ipairs(itemPrimaryStatKeys) do
		if key == expectedKey then
			if not self.db.enableSpecStatMatch then
				return nil
			end
			return { state = "match", kind = "match", text = PRIMARY_STATS[specInfo.primaryStat], tooltip = WARNING_TEXT.statMatchTooltip }
		end
	end

	local expectedLabel = PRIMARY_STATS[specInfo.primaryStat] or WARNING_TEXT.unknown
	local itemLabels = {}
	for _, key in ipairs(itemPrimaryStatKeys) do
		table.insert(itemLabels, STAT_KEY_TO_LABEL[key] or key)
	end

	return {
		state = "warning",
		kind = "mismatch",
		text = table.concat(itemLabels, "/"),
		tooltip = string.format(WARNING_TEXT.statMismatchTooltip, expectedLabel),
	}
end

function CW:BuildArmorTypeWarning(form, itemLink, itemAnalysis)
	if not self.db.enableArmorTypeWarning then
		return nil
	end

	local expectedArmorType = CW.GetExpectedArmorTypeForPlayerClass()
	if not expectedArmorType then
		return nil
	end

	itemLink = itemLink or self:GetCurrentOutputContext(form)
	if not itemLink then
		return nil
	end

	itemAnalysis = itemAnalysis or self:GetItemAnalysis(itemLink)
	if not itemAnalysis or not itemAnalysis.equippable then
		return nil
	end

	if itemAnalysis.universalSlot then
		if not self.db.enableArmorTypeMatch then
			return nil
		end
		local slotLabel = itemAnalysis.slotLabel or WARNING_TEXT.unknown
		return {
			state = "info",
			kind = "universal",
			text = slotLabel,
			tooltip = string.format(WARNING_TEXT.armorUniversalTooltip, slotLabel),
		}
	end

	local itemArmorType = itemAnalysis.armorType
	if not itemArmorType then
		return nil
	end

	if itemArmorType == expectedArmorType then
		if not self.db.enableArmorTypeMatch then
			return nil
		end
		return { state = "match", kind = "match", text = itemArmorType, tooltip = WARNING_TEXT.armorMatchTooltip }
	end

	return {
		state = "warning",
		kind = "mismatch",
		text = itemArmorType,
		tooltip = string.format(WARNING_TEXT.armorMismatchTooltip, expectedArmorType),
	}
end

-- When the item has neither a primary stat nor a class-restricted armor type, fold the two info
-- rows into one "Universal" line instead of stacking statements
function CW.CollapseUniversalRows(statRow, armorRow)
	if statRow and statRow.kind == "noStat" and armorRow and armorRow.kind == "universal" then
		return {
			state = "info",
			kind = "universalCombined",
			text = WARNING_TEXT.universalText,
			tooltip = string.format(WARNING_TEXT.universalTooltip, armorRow.text),
		}, nil
	end
	return statRow, armorRow
end
