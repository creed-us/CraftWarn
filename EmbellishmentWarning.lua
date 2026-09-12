local CW = CraftWarn

local WARNING_TEXT = CW.TEXT.warnings

local embellishCountsCache = { equipped = 0, bag = 0, dirty = true }

function CW:InvalidateEmbellishmentCounts()
	embellishCountsCache.dirty = true
end

-- form.order.reagents is empty while still drafting (it only reflects a placed/server order); the
-- live selections instead live on the form's recipe transaction. Some recipes offer an
-- embellishment as a basic reagent choice rather than an optional/finishing slot, so combine both
-- allocation lists the transaction can build rather than assuming it's always optional.
local function BuildLiveReagentAllocationList(transaction)
	local list = {}

	if transaction.CreateRegularItemReagentInfoTbl then
		for _, entry in ipairs(transaction:CreateRegularItemReagentInfoTbl() or {}) do
			table.insert(list, entry)
		end
	end

	if transaction.CreateOptionalOrFinishingCraftingReagentInfoTbl then
		for _, entry in ipairs(transaction:CreateOptionalOrFinishingCraftingReagentInfoTbl() or {}) do
			table.insert(list, entry)
		end
	end

	return #list > 0 and list or nil
end

-- Checking the reagent items themselves doesn't work: an embellishment reagent's own tooltip just
-- describes its proc narratively and never says "Embellish". The result-preview API (the same one
-- the crafting order UI itself uses) correctly resolves reagent effects, including a recraft's
-- carried-over embellishment via recraftGUID
local function IsOrderCraftingEmbellishment(form)
	local order = form and form.order
	local transaction = form and form.transaction
	if not order or not order.spellID or not transaction then
		return false
	end

	local reagents = BuildLiveReagentAllocationList(transaction)
	return CW.IsRecipeResultEmbellished(order.spellID, reagents, form.recraftGUID)
end

-- A recraft of an item that's already equipped AND already embellished replaces itself in place:
-- the old embellishment is destroyed with the item, so the new one doesn't consume an extra slot.
local function IsRecraftTargetEquippedAndEmbellished(form)
	local order = form and form.order
	local guid = form and form.recraftGUID
	if not order or not order.isRecraft or not guid then
		return false
	end

	local location = C_Item.GetItemLocation(guid)
	if not location or not location:IsValid() or not location:IsEquipmentSlot() then
		return false
	end

	local currentLink = order.recraftItemHyperlink or C_Item.GetItemLinkByGUID(guid)
	return currentLink ~= nil and CW.IsItemLinkEmbellished(currentLink)
end

function CW:BuildEmbellishmentRow(form)
	if not self.db.enableEmbellishmentInfo then
		return nil
	end

	if embellishCountsCache.dirty then
		embellishCountsCache.equipped = CW:CountEquippedEmbellishments()
		embellishCountsCache.bag = CW:CountBagEmbellishments()
		embellishCountsCache.dirty = false
	end

	local equippedCount = embellishCountsCache.equipped
	local bagCount = embellishCountsCache.bag
	local willEmbellish = IsOrderCraftingEmbellishment(form)
	local recraftInPlace = IsRecraftTargetEquippedAndEmbellished(form)

	local netDelta = willEmbellish and 1 or 0
	if recraftInPlace then
		netDelta = netDelta - 1
	end
	local projected = equippedCount + netDelta

	if willEmbellish then
		if projected > 2 then
			local text = WARNING_TEXT.embellishCappedText
			if bagCount > 0 then
				text = text .. string.format(WARNING_TEXT.embellishBagSuffix, bagCount)
			end
			return { state = "warning", text = text, tooltip = WARNING_TEXT.embellishCappedTooltip }
		end

		local text = string.format(WARNING_TEXT.embellishOkText, projected)
		if bagCount > 0 then
			text = text .. string.format(WARNING_TEXT.embellishBagSuffix, bagCount)
		end

		local tooltip = recraftInPlace
			and string.format(WARNING_TEXT.embellishSafeTooltip, projected)
			or string.format(WARNING_TEXT.embellishOkTooltip, projected)

		return { state = "match", text = text, tooltip = tooltip }
	end

	if recraftInPlace then
		return { state = "info", text = WARNING_TEXT.embellishRemovedText, tooltip = string.format(WARNING_TEXT.embellishRemovedTooltip, equippedCount) }
	end

	if bagCount > 0 then
		return {
			state = "info",
			text = string.format(WARNING_TEXT.embellishBagOnlyText, equippedCount, bagCount),
			tooltip = string.format(WARNING_TEXT.embellishBagOnlyTooltip, equippedCount, bagCount),
		}
	end

	return nil
end
