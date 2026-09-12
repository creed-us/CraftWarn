local CW = CraftWarn

local EQUIPPED_SLOT_IDS = CW.EQUIPPED_SLOT_IDS

-- No typed API exposes embellishment status, we guessin'
local EMBELLISHED_MARKER = "Embellish"
local embellishedLinkCache = {}

-- true/false once tooltip data has lines, nil if there's nothing to scan
local function TooltipDataHasEmbellishment(tooltipData)
	if not tooltipData or not tooltipData.lines then
		return nil
	end

	for _, line in ipairs(tooltipData.lines) do
		if line.leftText and line.leftText:find(EMBELLISHED_MARKER, 1, true) then
			return true
		end
	end

	return false
end

local function ScanLinkForEmbellishment(itemLink)
	return TooltipDataHasEmbellishment(C_TooltipInfo.GetHyperlink(itemLink))
end

-- permanent item instances (equipped gear, bag items)
local function IsItemLinkEmbellished(itemLink)
	if not itemLink then
		return false
	end

	local cached = embellishedLinkCache[itemLink]
	if cached ~= nil then
		return cached
	end

	local result = ScanLinkForEmbellishment(itemLink)
	if result == nil then
		return false
	end

	embellishedLinkCache[itemLink] = result
	return result
end

-- Speculative recipe-output preview links can describe a different item each time reagent
-- selections change, so these are never cached.
local function IsPreviewLinkEmbellished(itemLink)
	return itemLink ~= nil and ScanLinkForEmbellishment(itemLink) == true
end

-- The same purpose-built preview API the crafting order UI itself uses; correctly resolves
-- reagent effects, including a recraft's carried-over embellishment via recraftItemGUID
local function IsRecipeResultEmbellished(recipeID, craftingReagents, recraftItemGUID)
	if not recipeID then
		return false
	end

	local tooltipData = C_TooltipInfo.GetRecipeResultItem(recipeID, craftingReagents, recraftItemGUID)
	return TooltipDataHasEmbellishment(tooltipData) == true
end

local function CountEquippedEmbellishments()
	local count = 0
	for _, slotID in ipairs(EQUIPPED_SLOT_IDS) do
		local itemLink = GetInventoryItemLink("player", slotID)
		if itemLink and IsItemLinkEmbellished(itemLink) then
			count = count + 1
		end
	end
	return count
end

local function CountBagEmbellishments()
	local count = 0
	for bagID = 0, 4 do
		local numSlots = C_Container.GetContainerNumSlots(bagID)
		for slotIndex = 1, numSlots do
			local itemLink = C_Container.GetContainerItemLink(bagID, slotIndex)
			if itemLink and IsItemLinkEmbellished(itemLink) then
				count = count + 1
			end
		end
	end
	return count
end

CW.IsItemLinkEmbellished       = IsItemLinkEmbellished
CW.IsPreviewLinkEmbellished    = IsPreviewLinkEmbellished
CW.IsRecipeResultEmbellished   = IsRecipeResultEmbellished
CW.CountEquippedEmbellishments = CountEquippedEmbellishments
CW.CountBagEmbellishments      = CountBagEmbellishments
