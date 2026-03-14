local CW = CraftWarn

local SPEC_TO_STAT_KEY  = CW.SPEC_TO_STAT_KEY
local PRIMARY_STATS     = CW.PRIMARY_STATS
local STAT_KEY_TO_LABEL = CW.STAT_KEY_TO_LABEL
local ITEM_ANALYSIS_CACHE_SIZE = CW.ITEM_ANALYSIS_CACHE_SIZE
local UI_CONFIG = CW.UI_CONFIG
local WARNING_COLORS = UI_CONFIG.warningColors
local WARNING_ICONS = UI_CONFIG.warningIcons
local WARNING_ICON_SIZE = UI_CONFIG.warningIconSize
local WARNING_ICON_TEXT_GAP = UI_CONFIG.warningIconTextGap
local WARNING_ICON_OFFSET_Y = UI_CONFIG.warningIconOffsetY
local WARNING_ICON_LINE_SPACING = UI_CONFIG.warningIconLineSpacing
local WARNING_INFO_ICON_TINT = UI_CONFIG.warningInfoIconTint
local TEXT = CW.TEXT
local WARNING_TEXT = TEXT.warnings

---------------------------------------------------------------------------
-- Warning frame construction
---------------------------------------------------------------------------

function CW:BuildWarningFrames(form)
    if not form or form.CraftWarnWarnings then
        return
    end

    local parent = form.ReagentContainer or form
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, UI_CONFIG.warningHolderOffsetY)
    holder:SetWidth(UI_CONFIG.warningHolderWidth)
    holder:SetHeight(UI_CONFIG.warningHolderHeight)

    local mismatch = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mismatch:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    mismatch:SetJustifyH("RIGHT")
    local mismatchColor = WARNING_COLORS.mismatch
    mismatch:SetTextColor(mismatchColor[1], mismatchColor[2], mismatchColor[3])

    local mismatchIcon = holder:CreateTexture(nil, "OVERLAY")
    mismatchIcon:SetSize(WARNING_ICON_SIZE, WARNING_ICON_SIZE)
    mismatchIcon:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, WARNING_ICON_OFFSET_Y)
    mismatch:SetPoint("TOPRIGHT", mismatchIcon, "TOPLEFT", -WARNING_ICON_TEXT_GAP, 0)

    local armor = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local warningLineSpacing = UI_CONFIG.warningLineSpacing
    armor:SetPoint("TOPLEFT", mismatch, "BOTTOMLEFT", 0, warningLineSpacing)
    armor:SetJustifyH("RIGHT")
    armor:SetTextColor(mismatchColor[1], mismatchColor[2], mismatchColor[3])

    local armorIcon = holder:CreateTexture(nil, "OVERLAY")
    armorIcon:SetSize(WARNING_ICON_SIZE, WARNING_ICON_SIZE)
    armorIcon:SetPoint("TOPRIGHT", mismatchIcon, "BOTTOMRIGHT", 0, WARNING_ICON_LINE_SPACING)
    armor:SetPoint("TOPRIGHT", armorIcon, "TOPLEFT", -WARNING_ICON_TEXT_GAP, 0)

    form.CraftWarnWarnings = {
        holder = holder,
        mismatch = mismatch,
        mismatchIcon = mismatchIcon,
        armor = armor,
        armorIcon = armorIcon,
    }
end

local function SetLineState(line, text, matchPrefix, mismatchPrefix)
    line:SetText(text or "")
    line:SetShown(text and text ~= "")

    if not (text and text ~= "") then
        return "none"
    end

    if matchPrefix and text:find("^" .. matchPrefix) then
        local matchColor = WARNING_COLORS.match
        line:SetTextColor(matchColor[1], matchColor[2], matchColor[3])
        return "match"
    elseif mismatchPrefix and text:find("^" .. mismatchPrefix) then
        local mismatchColor = WARNING_COLORS.mismatch
        line:SetTextColor(mismatchColor[1], mismatchColor[2], mismatchColor[3])
        return "warning"
    else
        local infoColor = WARNING_COLORS.info
        line:SetTextColor(infoColor[1], infoColor[2], infoColor[3])
        return "info"
    end
end

local function SetLineIcon(icon, state)
    if not icon then
        return
    end

    if state == "match" then
        icon:SetTexture(WARNING_ICONS.match)
        icon:SetVertexColor(1, 1, 1)
        icon:Show()
    elseif state == "warning" then
        icon:SetTexture(WARNING_ICONS.warning)
        icon:SetVertexColor(1, 1, 1)
        icon:Show()
    elseif state == "info" then
        icon:SetTexture(WARNING_ICONS.info)
        icon:SetVertexColor(WARNING_INFO_ICON_TINT[1], WARNING_INFO_ICON_TINT[2], WARNING_INFO_ICON_TINT[3])
        icon:Show()
    else
        icon:Hide()
    end
end

function CW:RenderWarnings(form, payload)
    self:BuildWarningFrames(form)

    local warnings = form and form.CraftWarnWarnings
    if not warnings then
        return
    end

    local statText = payload and payload.statText
    local armorText = payload and payload.armorText
    local warningLineSpacing = UI_CONFIG.warningLineSpacing

    local statState = SetLineState(
        warnings.mismatch,
        statText,
        WARNING_TEXT.prefixStatMatch,
        WARNING_TEXT.prefixStatMismatch
    )
    local armorState = SetLineState(
        warnings.armor,
        armorText,
        WARNING_TEXT.prefixArmorMatch,
        WARNING_TEXT.prefixArmorMismatch
    )

    SetLineIcon(warnings.mismatchIcon, statState)
    SetLineIcon(warnings.armorIcon, armorState)

    warnings.armor:ClearAllPoints()
    warnings.armorIcon:ClearAllPoints()

    if warnings.mismatch:IsShown() then
        warnings.armor:SetPoint("TOPLEFT", warnings.mismatch, "BOTTOMLEFT", 0, warningLineSpacing)
        warnings.armorIcon:SetPoint("TOPRIGHT", warnings.mismatchIcon, "BOTTOMRIGHT", 0, WARNING_ICON_LINE_SPACING)
    else
        warnings.armor:SetPoint("TOPLEFT", warnings.holder, "TOPLEFT", 0, 0)
        warnings.armorIcon:SetPoint("TOPRIGHT", warnings.holder, "TOPRIGHT", 0, WARNING_ICON_OFFSET_Y)
    end

    warnings.armor:SetPoint("TOPRIGHT", warnings.armorIcon, "TOPLEFT", -WARNING_ICON_TEXT_GAP, 0)

    local visible = warnings.mismatch:IsShown() or warnings.armor:IsShown()
    warnings.holder:SetShown(visible)
end

---------------------------------------------------------------------------
-- Warning data builders
---------------------------------------------------------------------------

-- Cache layers:
-- 1) Per-form warning payload keyed by spell, reagent signature, and toggles.
-- 2) Bounded item-analysis LRU keyed by output item link.
local warningCache = {
    spellID = nil,
    outputItemLink = nil,
    reagentSignature = nil,
    enableSpecStatWarning = nil,
    enableArmorTypeWarning = nil,
    enableSpecStatMatch = nil,
    enableArmorTypeMatch = nil,
    enableNoPrimaryStatInfo = nil,
    statText = nil,
    armorText = nil,
}

local itemAnalysisByLink = {}
-- Tracks item-link recency so we can evict old analysis entries.
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

local function BuildOptionalReagentSignature(optionalReagents)
    if type(optionalReagents) ~= "table" or #optionalReagents == 0 then
        return ""
    end

    local tokens = {}
    for _, info in ipairs(optionalReagents) do
        local slotIndex = info.slotIndex or 0
        local quantity = info.quantity or 0
        local reagent = info.reagent or {}
        local itemID = reagent.itemID or 0
        local currencyID = reagent.currencyID or 0
        tokens[#tokens + 1] = string.format("%d:%d:%d:%d", slotIndex, itemID, currencyID, quantity)
    end

    table.sort(tokens)
    return table.concat(tokens, "|")
end

local function AreSettingKeysUnchanged(self)
    return self.db.enableSpecStatWarning == warningCache.enableSpecStatWarning
        and self.db.enableSpecStatMatch == warningCache.enableSpecStatMatch
        and self.db.enableNoPrimaryStatInfo == warningCache.enableNoPrimaryStatInfo
        and self.db.enableArmorTypeWarning == warningCache.enableArmorTypeWarning
        and self.db.enableArmorTypeMatch == warningCache.enableArmorTypeMatch
end

local function GetItemAnalysis(itemLink)
    if not itemLink then
        return nil
    end

    local cached = itemAnalysisByLink[itemLink]
    if cached then
        TouchItemAnalysisLink(itemLink)
        return cached
    end

    local equippable = C_Item and C_Item.IsEquippableItem and C_Item.IsEquippableItem(itemLink) or false
    local analysis = {
        equippable = equippable,
        primaryStatKeys = equippable and CW.DetectPrimaryStatsOnItem(itemLink),
        armorType = equippable and CW.GetItemArmorType(itemLink),
    }

    itemAnalysisByLink[itemLink] = analysis
    TouchItemAnalysisLink(itemLink)
    return analysis
end

function CW:InvalidateWarningCache()
    warningCache.spellID = nil
    warningCache.outputItemLink = nil
    warningCache.reagentSignature = nil
    warningCache.enableSpecStatWarning = nil
    warningCache.enableSpecStatMatch = nil
    warningCache.enableNoPrimaryStatInfo = nil
    warningCache.enableArmorTypeWarning = nil
    warningCache.enableArmorTypeMatch = nil
    warningCache.statText = nil
    warningCache.armorText = nil
end

function CW:ClearItemAnalysisCache()
    itemAnalysisByLink = {}
    itemAnalysisLru = {}
end

function CW:GetCurrentOutputContext(form)
    if not form or not form.order or not form.order.spellID then
        return nil, ""
    end

    local optionalReagents = nil
    if form.transaction and form.transaction.CreateOptionalCraftingReagentInfoTbl then
        optionalReagents = form.transaction:CreateOptionalCraftingReagentInfoTbl()
    end

    local reagentSignature = BuildOptionalReagentSignature(optionalReagents)

    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeOutputItemData then
        local data = C_TradeSkillUI.GetRecipeOutputItemData(form.order.spellID, optionalReagents)
        if data and data.hyperlink then
            return data.hyperlink, reagentSignature
        end
    end

    if form.order.recraftItemHyperlink then
        return form.order.recraftItemHyperlink, reagentSignature
    end

    return nil, reagentSignature
end

function CW:BuildSpecMismatchWarning(form, itemLink, itemAnalysis)
    if not self.db.enableSpecStatWarning then
        return nil, nil
    end

    local specInfo = CW.CurrentSpecInfo()
    if not specInfo or not specInfo.primaryStat then
        return nil, nil
    end

	itemLink = itemLink or select(1, self:GetCurrentOutputContext(form))
    if not itemLink then
        return nil, nil
    end

    itemAnalysis = itemAnalysis or GetItemAnalysis(itemLink)
    if not itemAnalysis or not itemAnalysis.equippable then
        return nil, nil
    end

    local itemPrimaryStatKeys = itemAnalysis.primaryStatKeys
    if #itemPrimaryStatKeys == 0 then
        if self.db.enableNoPrimaryStatInfo then
            return nil, WARNING_TEXT.noPrimaryStat
        end
        return nil, nil
    end

    local expectedKey = SPEC_TO_STAT_KEY[specInfo.primaryStat]
    if not expectedKey then
        return nil, nil
    end

    for _, key in ipairs(itemPrimaryStatKeys) do
        if key == expectedKey then
            if self.db.enableSpecStatMatch then
                local label = PRIMARY_STATS[specInfo.primaryStat]
                return nil, string.format(WARNING_TEXT.statMatch, label)
            end
            return nil, nil
        end
    end

    local expectedLabel = PRIMARY_STATS[specInfo.primaryStat] or (WARNING_TEXT.unknown)
    local itemLabels = {}
    for _, key in ipairs(itemPrimaryStatKeys) do
        table.insert(itemLabels, STAT_KEY_TO_LABEL[key] or key)
    end

    local itemLabelText = table.concat(itemLabels, "/")
    return string.format(WARNING_TEXT.statMismatch, expectedLabel, itemLabelText), nil
end

function CW:BuildArmorTypeWarning(form, itemLink, itemAnalysis)
    if not self.db.enableArmorTypeWarning then
        return nil, nil
    end

    local expectedArmorType = CW.GetExpectedArmorTypeForPlayerClass()
    if not expectedArmorType then
        return nil, nil
    end

	itemLink = itemLink or select(1, self:GetCurrentOutputContext(form))
    if not itemLink then
        return nil, nil
    end

    itemAnalysis = itemAnalysis or GetItemAnalysis(itemLink)
    if not itemAnalysis or not itemAnalysis.equippable then
        return nil, nil
    end

    local itemArmorType = itemAnalysis.armorType
    if not itemArmorType then
        return nil, nil
    end

    if itemArmorType == expectedArmorType then
        if self.db.enableArmorTypeMatch then
            return nil, string.format(WARNING_TEXT.armorMatch, itemArmorType)
        end
        return nil, nil
    end

    return string.format(WARNING_TEXT.armorMismatch, expectedArmorType, itemArmorType), nil
end

function CW:RefreshFormWarnings(form)
    if not form or not form:IsShown() then
        return
    end

    if self.IsOperationalContext and not self:IsOperationalContext(form) then
        self:RenderWarnings(form, nil)
        return
    end

    local spellID = form.order and form.order.spellID
    local forceRecompute = form.cwWarningDirty and true or false
    local warnEnabled = self.db.enableSpecStatWarning
    local matchEnabled = self.db.enableSpecStatMatch
    local noStatEnabled = self.db.enableNoPrimaryStatInfo
    local armorWarnEnabled = self.db.enableArmorTypeWarning
    local armorMatchEnabled = self.db.enableArmorTypeMatch

    local now = GetTime and GetTime() or time()

    if not forceRecompute
        and spellID == warningCache.spellID
        and AreSettingKeysUnchanged(self)
    then
        self:RenderWarnings(form, {
            statText = warningCache.statText,
            armorText = warningCache.armorText,
        })
        form.cwLastWarningRefreshTime = now
        return
    end

    local itemLink, reagentSignature = self:GetCurrentOutputContext(form)

    -- Only recompute if the recipe or settings changed since last time
    if forceRecompute
        or spellID ~= warningCache.spellID
        or itemLink ~= warningCache.outputItemLink
        or reagentSignature ~= warningCache.reagentSignature
        or warnEnabled ~= warningCache.enableSpecStatWarning
        or matchEnabled ~= warningCache.enableSpecStatMatch
        or noStatEnabled ~= warningCache.enableNoPrimaryStatInfo
        or armorWarnEnabled ~= warningCache.enableArmorTypeWarning
        or armorMatchEnabled ~= warningCache.enableArmorTypeMatch
    then
        warningCache.spellID = spellID
        warningCache.outputItemLink = itemLink
        warningCache.reagentSignature = reagentSignature
        warningCache.enableSpecStatWarning = warnEnabled
        warningCache.enableSpecStatMatch = matchEnabled
        warningCache.enableNoPrimaryStatInfo = noStatEnabled
        warningCache.enableArmorTypeWarning = armorWarnEnabled
        warningCache.enableArmorTypeMatch = armorMatchEnabled

        local itemAnalysis = GetItemAnalysis(itemLink)

        local statMismatchText, statInfoText = self:BuildSpecMismatchWarning(form, itemLink, itemAnalysis)
        local armorMismatchText, armorInfoText = self:BuildArmorTypeWarning(form, itemLink, itemAnalysis)

        warningCache.statText = statMismatchText or statInfoText
        warningCache.armorText = armorMismatchText or armorInfoText
    end

    self:RenderWarnings(form, {
        statText = warningCache.statText,
        armorText = warningCache.armorText,
    })

    form.cwWarningDirty = false
    form.cwLastWarningRefreshTime = now
end
