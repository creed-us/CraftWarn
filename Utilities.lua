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
	local specIndex = C_SpecializationInfo.GetSpecialization()
	if not specIndex and GetSpecialization then
		specIndex = GetSpecialization()
	end

	if not specIndex then
		return nil
	end

	local specID, name, _, _, _, primaryStat = C_SpecializationInfo.GetSpecializationInfo(specIndex)

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
	local stats = C_Item.GetItemStats(itemLink)
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

	local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemLink)

	local armorClassID = Enum.ItemClass.Armor or 4
	if classID ~= armorClassID then
		return nil
	end

	return ARMOR_SUBCLASS_TO_LABEL[subClassID]
end

---------------------------------------------------------------------------
-- Bag / Item helpers
---------------------------------------------------------------------------

--- Extract itemID from an item hyperlink.
--- @param itemLink string|nil The item hyperlink.
--- @return number|nil The extracted itemID.
local function GetItemIDFromLink(itemLink)
	if not itemLink then
		return nil
	end

	-- Item links format: |cff...|Hitem:itemID:...|h[Name]|h|r
	local itemIDStr = itemLink:match("|Hitem:(%d+):")
	if itemIDStr then
		return tonumber(itemIDStr)
	end

	return nil
end

--- Find an item in player bags that matches the given item link.
--- Returns the ItemLocation if found, nil otherwise.
--- For recraft, we match by itemID and prefer exact hyperlink match when possible.
--- @param targetItemLink string The item hyperlink to match.
--- @return table|nil ItemLocation table with bagID and slotIndex, or nil if not found.
local function FindItemInBagsByLink(targetItemLink)
	if not targetItemLink then
		return nil
	end

	local targetItemID = GetItemIDFromLink(targetItemLink)
	if not targetItemID then
		return nil
	end

	-- Check C_Container API availability
	if not C_Container.GetContainerNumSlots then
		return nil
	end

	local fallbackMatch = nil

	-- Iterate through bags (0 = backpack, 1-4 = regular bags)
	for bagID = 0, 4 do
		local numSlots = C_Container.GetContainerNumSlots(bagID)
		for slotIndex = 1, numSlots do
			local itemInfo = C_Container.GetContainerItemInfo(bagID, slotIndex)
			if itemInfo and itemInfo.itemID == targetItemID then
				-- Found an item with matching itemID
				local itemLink = C_Container.GetContainerItemLink(bagID, slotIndex)
				if itemLink then
					-- Prefer exact hyperlink match (same item with same bonuses/stats)
					if itemLink == targetItemLink then
						return { bagID = bagID, slotIndex = slotIndex }
					end
					-- Keep first itemID match as fallback
					if not fallbackMatch then
						fallbackMatch = { bagID = bagID, slotIndex = slotIndex }
					end
				end
			end
		end
	end

	-- Return fallback match (same itemID but potentially different bonuses) if no exact match
	return fallbackMatch
end

--- Create an ItemLocation from bag and slot.
--- @param bagID number The bag ID.
--- @param slotIndex number The slot index.
--- @return table|nil ItemLocation object or nil if invalid.
local function CreateItemLocation(bagID, slotIndex)
	if ItemLocation and ItemLocation.CreateFromBagAndSlot then
		return ItemLocation:CreateFromBagAndSlot(bagID, slotIndex)
	end
	return nil
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
CW.GetItemIDFromLink           = GetItemIDFromLink
CW.FindItemInBagsByLink        = FindItemInBagsByLink
CW.CreateItemLocation          = CreateItemLocation
