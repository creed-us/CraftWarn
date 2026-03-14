local CW = CraftWarn

local SPEC_TO_STAT_KEY  = CW.SPEC_TO_STAT_KEY
local PRIMARY_STATS     = CW.PRIMARY_STATS
local STAT_KEY_TO_LABEL = CW.STAT_KEY_TO_LABEL

---------------------------------------------------------------------------
-- Warning frame construction
---------------------------------------------------------------------------

function CW:BuildWarningFrames(form)
    if not form or form.CraftWarnWarnings then
        return
    end

    local parent = form.ReagentContainer or form
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -10)
    holder:SetWidth(350)
    holder:SetHeight(36)

    local mismatch = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mismatch:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    mismatch:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    mismatch:SetJustifyH("RIGHT")
    mismatch:SetTextColor(1.0, 0.23, 0.19)

    local armor = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    armor:SetPoint("TOPLEFT", mismatch, "BOTTOMLEFT", 0, -2)
    armor:SetPoint("TOPRIGHT", mismatch, "BOTTOMRIGHT", 0, -2)
    armor:SetJustifyH("RIGHT")
    armor:SetTextColor(1.0, 0.23, 0.19)

    local info = holder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    info:SetPoint("TOPLEFT", armor, "BOTTOMLEFT", 0, -2)
    info:SetPoint("TOPRIGHT", armor, "BOTTOMRIGHT", 0, -2)
    info:SetJustifyH("RIGHT")

    form.CraftWarnWarnings = {
        holder = holder,
        mismatch = mismatch,
        armor = armor,
        info = info,
    }
end

function CW:RenderWarnings(form, payload)
    self:BuildWarningFrames(form)

    local warnings = form and form.CraftWarnWarnings
    if not warnings then
        return
    end

    local mismatchText = payload and payload.mismatchText or nil
    local armorText    = payload and payload.armorText or nil
    local infoText     = payload and payload.infoText or nil
    local infoIsPositive = payload and payload.infoIsPositive or false

    warnings.mismatch:SetText(mismatchText or "")
    warnings.mismatch:SetShown(mismatchText and mismatchText ~= "")

    warnings.armor:SetText(armorText or "")
    warnings.armor:SetShown(armorText and armorText ~= "")

    warnings.info:SetText(infoText or "")
    warnings.info:SetShown(infoText and infoText ~= "")

    if infoIsPositive then
        warnings.info:SetTextColor(0.26, 0.84, 0.26)
    else
        warnings.info:SetTextColor(0.5, 0.5, 0.5)
    end

    local visible = warnings.mismatch:IsShown() or warnings.armor:IsShown() or warnings.info:IsShown()
    warnings.holder:SetShown(visible)
end

---------------------------------------------------------------------------
-- Warning data builders
---------------------------------------------------------------------------

-- Cache: item warnings keyed on spellID + setting toggles, invalidated on spec change.
local warningCache = {
    spellID = nil,
    outputItemLink = nil,
    enableSpecStatWarning = nil,
    enableArmorTypeWarning = nil,
    enableSpecStatMatch = nil,
    enableArmorTypeMatch = nil,
    enableNoPrimaryStatInfo = nil,
    mismatchText = nil,
    armorText = nil,
    infoText = nil,
    infoIsPositive = false,
}

function CW:InvalidateWarningCache()
    warningCache.spellID = nil
    warningCache.outputItemLink = nil
    warningCache.enableSpecStatWarning = nil
    warningCache.enableSpecStatMatch = nil
    warningCache.enableNoPrimaryStatInfo = nil
    warningCache.enableArmorTypeWarning = nil
    warningCache.enableArmorTypeMatch = nil
    warningCache.mismatchText = nil
    warningCache.armorText = nil
    warningCache.infoText = nil
    warningCache.infoIsPositive = false
end

function CW:GetCurrentOutputItemLink(form)
    if not form or not form.order or not form.order.spellID then
        return nil
    end

    local optionalReagents = nil
    if form.transaction and form.transaction.CreateOptionalCraftingReagentInfoTbl then
        optionalReagents = form.transaction:CreateOptionalCraftingReagentInfoTbl()
    end

    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeOutputItemData then
        local data = C_TradeSkillUI.GetRecipeOutputItemData(form.order.spellID, optionalReagents)
        if data and data.hyperlink then
            return data.hyperlink
        end
    end

    if form.order.recraftItemHyperlink then
        return form.order.recraftItemHyperlink
    end

    return nil
end

function CW:BuildSpecMismatchWarning(form, itemLink)
    if not self.db.enableSpecStatWarning then
        return nil, nil
    end

    local specInfo = CW.CurrentSpecInfo()
    if not specInfo or not specInfo.primaryStat then
        return nil, nil
    end

	itemLink = itemLink or self:GetCurrentOutputItemLink(form)
    if not itemLink then
        return nil, nil
    end

    if not C_Item.IsEquippableItem(itemLink) then
        return nil, nil
    end

    local itemPrimaryStatKeys = CW.DetectPrimaryStatsOnItem(itemLink)
    if #itemPrimaryStatKeys == 0 then
        if self.db.enableNoPrimaryStatInfo then
            return nil, "Crafted item has no primary stat."
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
                local label = PRIMARY_STATS[specInfo.primaryStat] or "Unknown"
                return nil, string.format("Stat Match: Crafted item has %s.", label)
            end
            return nil, nil
        end
    end

    local expectedLabel = PRIMARY_STATS[specInfo.primaryStat] or "Unknown"
    local itemLabels = {}
    for _, key in ipairs(itemPrimaryStatKeys) do
        table.insert(itemLabels, STAT_KEY_TO_LABEL[key] or key)
    end

    local itemLabelText = table.concat(itemLabels, "/")
    return string.format("Stat Mismatch: Current spec uses %s, crafted item has %s.", expectedLabel, itemLabelText), nil
end

function CW:BuildArmorTypeWarning(form, itemLink)
    if not self.db.enableArmorTypeWarning then
        return nil, nil
    end

    local expectedArmorType = CW.GetExpectedArmorTypeForPlayerClass()
    if not expectedArmorType then
        return nil, nil
    end

	itemLink = itemLink or self:GetCurrentOutputItemLink(form)
    if not itemLink then
        return nil, nil
    end

    if not C_Item.IsEquippableItem(itemLink) then
        return nil, nil
    end

    local itemArmorType = CW.GetItemArmorType(itemLink)
    if not itemArmorType then
        return nil, nil
    end

    if itemArmorType == expectedArmorType then
        if self.db.enableArmorTypeMatch then
            return nil, string.format("Armor Match: Crafted item is %s.", itemArmorType)
        end
        return nil, nil
    end

    return string.format("Armor Mismatch: Class armor is %s, crafted item is %s.", expectedArmorType, itemArmorType), nil
end

local function BuildInfoTextAndColor(statInfoText, armorInfoText)
    local messages = {}
    local allPositive = true

    if statInfoText and statInfoText ~= "" then
        table.insert(messages, statInfoText)
        if not statInfoText:find("^Stat Match") then
            allPositive = false
        end
    end

    if armorInfoText and armorInfoText ~= "" then
        table.insert(messages, armorInfoText)
        if not armorInfoText:find("^Armor Match") then
            allPositive = false
        end
    end

    if #messages == 0 then
        return nil, false
    end

    return table.concat(messages, "  "), allPositive
end

function CW:RefreshFormWarnings(form)
    if not form or not form:IsShown() then
        return
    end

    local spellID = form.order and form.order.spellID
    local itemLink = self:GetCurrentOutputItemLink(form)
    local warnEnabled = self.db.enableSpecStatWarning
    local matchEnabled = self.db.enableSpecStatMatch
    local noStatEnabled = self.db.enableNoPrimaryStatInfo
    local armorWarnEnabled = self.db.enableArmorTypeWarning
    local armorMatchEnabled = self.db.enableArmorTypeMatch

    -- Only recompute if the recipe or settings changed since last time
    if spellID ~= warningCache.spellID
        or itemLink ~= warningCache.outputItemLink
        or warnEnabled ~= warningCache.enableSpecStatWarning
        or matchEnabled ~= warningCache.enableSpecStatMatch
        or noStatEnabled ~= warningCache.enableNoPrimaryStatInfo
        or armorWarnEnabled ~= warningCache.enableArmorTypeWarning
        or armorMatchEnabled ~= warningCache.enableArmorTypeMatch
    then
        warningCache.spellID = spellID
        warningCache.outputItemLink = itemLink
        warningCache.enableSpecStatWarning = warnEnabled
        warningCache.enableSpecStatMatch = matchEnabled
        warningCache.enableNoPrimaryStatInfo = noStatEnabled
        warningCache.enableArmorTypeWarning = armorWarnEnabled
        warningCache.enableArmorTypeMatch = armorMatchEnabled

        local statMismatchText, statInfoText = self:BuildSpecMismatchWarning(form, itemLink)
        local armorMismatchText, armorInfoText = self:BuildArmorTypeWarning(form, itemLink)

        warningCache.mismatchText = statMismatchText
        warningCache.armorText = armorMismatchText
        warningCache.infoText, warningCache.infoIsPositive = BuildInfoTextAndColor(statInfoText, armorInfoText)
    end

    self:RenderWarnings(form, {
        mismatchText = warningCache.mismatchText,
        armorText = warningCache.armorText,
        infoText = warningCache.infoText,
        infoIsPositive = warningCache.infoIsPositive,
    })
end
