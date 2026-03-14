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
    holder:SetHeight(24)

    local mismatch = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mismatch:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    mismatch:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    mismatch:SetJustifyH("RIGHT")
    mismatch:SetTextColor(1.0, 0.23, 0.19)

    local reagent = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reagent:SetPoint("TOPLEFT", mismatch, "BOTTOMLEFT", 0, -2)
    reagent:SetPoint("TOPRIGHT", mismatch, "BOTTOMRIGHT", 0, -2)
    reagent:SetJustifyH("RIGHT")
    reagent:SetTextColor(1.0, 0.82, 0.0)

    local info = holder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    info:SetPoint("TOPLEFT", reagent, "BOTTOMLEFT", 0, -2)
    info:SetPoint("TOPRIGHT", reagent, "BOTTOMRIGHT", 0, -2)
    info:SetJustifyH("RIGHT")

    form.CraftWarnWarnings = {
        holder = holder,
        mismatch = mismatch,
        reagent = reagent,
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
    local reagentText  = payload and payload.reagentText or nil
    local infoText     = payload and payload.infoText or nil

    warnings.mismatch:SetText(mismatchText or "")
    warnings.mismatch:SetShown(mismatchText and mismatchText ~= "")

    warnings.reagent:SetText(reagentText or "")
    warnings.reagent:SetShown(reagentText and reagentText ~= "")

    warnings.info:SetText(infoText or "")
    warnings.info:SetShown(infoText and infoText ~= "")

    -- Green tint for match confirmation, default gray for other info
    local isMatch = infoText and infoText:find("^Stat Match") and true or false
    if isMatch then
        warnings.info:SetTextColor(0.26, 0.84, 0.26)
    else
        warnings.info:SetTextColor(0.5, 0.5, 0.5)
    end

    local visible = warnings.mismatch:IsShown() or warnings.reagent:IsShown() or warnings.info:IsShown()
    warnings.holder:SetShown(visible)
end

---------------------------------------------------------------------------
-- Warning data builders
---------------------------------------------------------------------------

-- Cache: spec mismatch keyed on spellID + setting toggles, invalidated on spec change.
-- Reagent shortage uses a dirty flag, recomputed only on bag/allocation changes.
local warningCache = {
    spellID = nil,
    enableSpecStatWarning = nil,
    enableSpecStatMatch = nil,
    enableNoPrimaryStatInfo = nil,
    mismatchText = nil,
    infoText = nil,
    reagentText = nil,
    reagentDirty = true,
}

function CW:InvalidateWarningCache()
    warningCache.spellID = nil
    warningCache.enableSpecStatWarning = nil
    warningCache.enableSpecStatMatch = nil
    warningCache.enableNoPrimaryStatInfo = nil
    warningCache.reagentDirty = true
end

function CW:MarkReagentsDirty()
    warningCache.reagentDirty = true
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

function CW:BuildSpecMismatchWarning(form)
    if not self.db.enableSpecStatWarning then
        return nil, nil
    end

    local specInfo = CW.CurrentSpecInfo()
    if not specInfo or not specInfo.primaryStat then
        return nil, nil
    end

    local itemLink = self:GetCurrentOutputItemLink(form)
    if not itemLink then
        return nil, nil
    end

    if not IsEquippableItem(itemLink) then
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

function CW:BuildReagentShortageWarning(form)
    if not form or not form.transaction or not form.cwRestoredFromContext then
        return nil
    end

    if not form.transaction.CreateCraftingReagentInfoTbl then
        return nil
    end

    local infos = form.transaction:CreateCraftingReagentInfoTbl()
    if type(infos) ~= "table" or #infos == 0 then
        return nil
    end

    local deficits = {}
    for _, info in ipairs(infos) do
        local reagent = info.reagent
        if reagent and info.quantity and info.quantity > 0 then
            local possessed = CW.GetReagentPossessionQuantity(reagent)
            if possessed < info.quantity then
                local missing = info.quantity - possessed
                local name = reagent.itemID and CW.SafeItemName(reagent.itemID) or CW.SafeCurrencyName(reagent.currencyID)
                table.insert(deficits, string.format("%dx %s", missing, name))
            end
        end
    end

    if #deficits == 0 then
        return nil
    end

    return string.format("Saved reagents changed: missing %s", table.concat(deficits, ", "))
end

function CW:RefreshFormWarnings(form)
    if not form or not form:IsShown() then
        return
    end

    local spellID = form.order and form.order.spellID
    local warnEnabled = self.db.enableSpecStatWarning
    local matchEnabled = self.db.enableSpecStatMatch
    local noStatEnabled = self.db.enableNoPrimaryStatInfo

    -- Only recompute if the recipe or settings changed since last time
    if spellID ~= warningCache.spellID
        or warnEnabled ~= warningCache.enableSpecStatWarning
        or matchEnabled ~= warningCache.enableSpecStatMatch
        or noStatEnabled ~= warningCache.enableNoPrimaryStatInfo
    then
        warningCache.spellID = spellID
        warningCache.enableSpecStatWarning = warnEnabled
        warningCache.enableSpecStatMatch = matchEnabled
        warningCache.enableNoPrimaryStatInfo = noStatEnabled
        warningCache.mismatchText, warningCache.infoText = self:BuildSpecMismatchWarning(form)
        warningCache.reagentDirty = true -- new recipe, so recheck reagents too
    end

    -- Only recheck reagents when bags changed or recipe switched
    if warningCache.reagentDirty then
        warningCache.reagentDirty = false
        warningCache.reagentText = self:BuildReagentShortageWarning(form)
    end

    self:RenderWarnings(form, {
        mismatchText = warningCache.mismatchText,
        reagentText = warningCache.reagentText,
        infoText = warningCache.infoText,
    })
end
