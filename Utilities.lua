
local CW = CraftWarn

local DEFAULTS = CW.DEFAULTS
local PRIMARY_STATS = CW.PRIMARY_STATS
local TRACKED_STAT_KEYS = CW.TRACKED_STAT_KEYS

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function CopyDefaults(db, defaults)
	if type(db) ~= "table" then
		db = {}
	end

	for key, value in pairs(defaults) do
		if db[key] == nil then
			if type(value) == "table" then
				db[key] = CopyDefaults({}, value)
			else
				db[key] = value
			end
		elseif type(value) == "table" and type(db[key]) == "table" then
			CopyDefaults(db[key], value)
		end
	end

	return db
end

local function SafeItemName(itemID)
	if not itemID then
		return "Unknown item"
	end

	local itemName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
	if itemName then
		return itemName
	end

	---@diagnostic disable: deprecated
	itemName = C_Item.GetItemInfo(itemID) or GetItemInfo(itemID)
	---@diagnostic enable: deprecated
	if itemName then
		return itemName
	end

	return string.format("item:%d", itemID)
end

local function SafeCurrencyName(currencyID)
	if not currencyID or not C_CurrencyInfo then
		return "Unknown currency"
	end

	local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
	return (info and info.name) or string.format("currency:%d", currencyID)
end

local function BuildReagentIdentity(reagent)
	if not reagent then
		return nil
	end

	if reagent.itemID then
		return string.format("item:%d", reagent.itemID)
	end

	if reagent.currencyID then
		return string.format("currency:%d", reagent.currencyID)
	end

	return nil
end

local function GetReagentPossessionQuantity(reagent)
	if not reagent then
		return 0
	end

	if ProfessionsUtil and ProfessionsUtil.GetReagentQuantityInPossession then
		return ProfessionsUtil.GetReagentQuantityInPossession(reagent, false) or 0
	end

	if reagent.itemID then
		---@diagnostic disable: deprecated
		return C_Item and C_Item.GetItemCount and C_Item.GetItemCount(reagent.itemID, false) or GetItemCount(reagent.itemID, false)
		---@diagnostic enable: deprecated
	end

	if reagent.currencyID and C_CurrencyInfo then
		local info = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
		return (info and info.quantity) or 0
	end

	return 0
end

local function NormalizeCraftingReagentInfo(info)
	if not info or not info.reagent then
		return nil
	end

	local reagent = info.reagent
	if not reagent.itemID and not reagent.currencyID then
		return nil
	end

	return {
		slotIndex = info.slotIndex,
		dataSlotIndex = info.dataSlotIndex,
		quantity = info.quantity or 0,
		itemID = reagent.itemID,
		currencyID = reagent.currencyID,
		key = BuildReagentIdentity(reagent),
	}
end

local function NormalizeCraftingReagentInfos(infos)
	local normalized = {}

	if type(infos) ~= "table" then
		return normalized
	end

	for _, info in ipairs(infos) do
		local entry = NormalizeCraftingReagentInfo(info)
		if entry and entry.slotIndex and entry.quantity and entry.quantity > 0 then
			table.insert(normalized, entry)
		end
	end

	return normalized
end

local function BuildReagentFromSaved(saved)
	if not saved then
		return nil
	end

	if saved.itemID then
		return { itemID = saved.itemID }
	end

	if saved.currencyID then
		return { currencyID = saved.currencyID }
	end

	return nil
end

local function IsContextFresh(context)
	if type(context) ~= "table" then
		return false
	end

	if not context.timestamp then
		return true
	end

	local ttl = tonumber(CraftWarnDB and CraftWarnDB.restoreTTLSeconds) or DEFAULTS.restoreTTLSeconds
	return (time() - context.timestamp) <= ttl
end

local function CurrentSpecInfo()
	local specIndex = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
	if not specIndex and GetSpecialization then
		specIndex = GetSpecialization()
	end

	if not specIndex then
		return nil
	end

	local specID, name, _, _, _, primaryStat
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
		specID, name, _, _, _, primaryStat = C_SpecializationInfo.GetSpecializationInfo(specIndex)
	elseif GetSpecializationInfo then
		specID, name, _, _, _, primaryStat = GetSpecializationInfo(specIndex)
	end

	if not primaryStat then
		return nil
	end

	return {
		specID = specID,
		name = name,
		primaryStat = primaryStat,
		primaryStatLabel = PRIMARY_STATS[primaryStat],
	}
end

local function DetectPrimaryStatsOnItem(itemLink)
	local stats = C_Item and C_Item.GetItemStats and C_Item.GetItemStats(itemLink)
	if not stats and GetItemStats then
		stats = GetItemStats(itemLink)
	end

	if type(stats) ~= "table" then
		return {}
	end

	local found = {}
	for _, statKey in ipairs(TRACKED_STAT_KEYS) do
		if (stats[statKey] or 0) > 0 then
			table.insert(found, statKey)
		end
	end

	return found
end

---------------------------------------------------------------------------
-- Shared accessor
---------------------------------------------------------------------------

function CW:GetVisibleOrderForm()
	local frame = _G["ProfessionsCustomerOrdersFrame"]
	if frame and frame.Form and frame.Form:IsShown() then
		return frame.Form
	end
	return nil
end

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------

CW.CopyDefaults              = CopyDefaults
CW.SafeItemName               = SafeItemName
CW.SafeCurrencyName            = SafeCurrencyName
CW.GetReagentPossessionQuantity = GetReagentPossessionQuantity
CW.NormalizeCraftingReagentInfos = NormalizeCraftingReagentInfos
CW.BuildReagentFromSaved       = BuildReagentFromSaved
CW.IsContextFresh              = IsContextFresh
CW.CurrentSpecInfo             = CurrentSpecInfo
CW.DetectPrimaryStatsOnItem    = DetectPrimaryStatsOnItem
