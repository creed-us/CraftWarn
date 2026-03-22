local CW = CraftWarn

local DEFAULTS = CW.DEFAULTS
local PRIMARY_STATS = CW.PRIMARY_STATS
local TRACKED_STAT_KEYS = CW.TRACKED_STAT_KEYS
local ARMOR_TYPE_BY_CLASS_TOKEN = CW.ARMOR_TYPE_BY_CLASS_TOKEN

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

local ARMOR_SUBCLASS_TO_LABEL = {
	[1] = "Cloth",
	[2] = "Leather",
	[3] = "Mail",
	[4] = "Plate",
}

local function GetExpectedArmorTypeForPlayerClass()
	local _, classToken = UnitClass("player")
	if not classToken then
		return nil
	end

	return ARMOR_TYPE_BY_CLASS_TOKEN[classToken]
end

local function GetItemArmorType(itemLink)
	if not itemLink then
		return nil
	end

	local classID, subClassID
	if C_Item and C_Item.GetItemInfoInstant then
		_, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemLink)
	else
		return nil
	end

	local armorClassID = Enum and Enum.ItemClass and Enum.ItemClass.Armor or 4
	if classID ~= armorClassID then
		return nil
	end

	return ARMOR_SUBCLASS_TO_LABEL[subClassID]
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
CW.IsContextFresh              = IsContextFresh
CW.CurrentSpecInfo             = CurrentSpecInfo
CW.DetectPrimaryStatsOnItem    = DetectPrimaryStatsOnItem
CW.GetExpectedArmorTypeForPlayerClass = GetExpectedArmorTypeForPlayerClass
CW.GetItemArmorType            = GetItemArmorType
