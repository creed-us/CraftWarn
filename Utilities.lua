local CW = CraftWarn

local DEFAULTS = CW.DEFAULTS
local PRIMARY_STATS = CW.PRIMARY_STATS
local TRACKED_STAT_KEYS = CW.TRACKED_STAT_KEYS
local ARMOR_TYPE_BY_CLASS_TOKEN = CW.ARMOR_TYPE_BY_CLASS_TOKEN
local UNIVERSAL_ARMOR_EQUIP_LOCS = CW.UNIVERSAL_ARMOR_EQUIP_LOCS

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

-- Some trinkets grant a primary stat only through an on-use/proc effect rather than a flat item
-- stat, so GetItemStats reports nothing even though the tooltip names the stat. Catch those by
-- scanning the tooltip text itself, skipping flavor text to avoid narrative mentions of the words.
local function HasHiddenPrimaryStatIndicator(itemLink)
	if not itemLink then
		return false
	end

	local tooltipData = C_TooltipInfo.GetHyperlink(itemLink)
	if not tooltipData or not tooltipData.lines then
		return false
	end

	for _, line in ipairs(tooltipData.lines) do
		if line.leftText and line.type ~= Enum.TooltipDataLineType.FlavorText then
			for _, label in pairs(PRIMARY_STATS) do
				if line.leftText:find(label, 1, true) then
					return true
				end
			end
		end
	end

	return false
end

local ARMOR_SUBCLASS_TO_LABEL = { [1] = "Cloth", [2] = "Leather", [3] = "Mail", [4] = "Plate" }

local function GetExpectedArmorTypeForPlayerClass()
	local _, classToken = UnitClass("player")
	return classToken and ARMOR_TYPE_BY_CLASS_TOKEN[classToken] or nil
end

local function GetItemArmorType(itemLink)
	if not itemLink then
		return nil
	end

	local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemLink)
	if classID ~= Enum.ItemClass.Armor then
		return nil
	end

	return ARMOR_SUBCLASS_TO_LABEL[subClassID]
end

-- Whether an equip slot carries no class-restricted armor type (rings, necks, trinkets, cloaks, off-hands)
local function IsUniversalArmorSlot(itemEquipLoc)
	return itemEquipLoc ~= nil and UNIVERSAL_ARMOR_EQUIP_LOCS[itemEquipLoc] == true
end

-- Blizzard's own localized label for an equip slot (e.g. "Finger", "Trinket")
local function GetItemSlotLabel(itemEquipLoc)
	return itemEquipLoc and _G[itemEquipLoc] or nil
end

local function GetItemIDFromLink(itemLink)
	if not itemLink then
		return nil
	end

	local itemIDStr = itemLink:match("|Hitem:(%d+):")
	return itemIDStr and tonumber(itemIDStr) or nil
end

-- Finds an item in the player's bags matching the given link, preferring an exact hyperlink
-- match (same bonuses) over any item sharing just the itemID.
local function FindItemInBagsByLink(targetItemLink)
	local targetItemID = GetItemIDFromLink(targetItemLink)
	if not targetItemID then
		return nil
	end

	local fallbackMatch = nil

	for bagID = 0, 4 do
		local numSlots = C_Container.GetContainerNumSlots(bagID)
		for slotIndex = 1, numSlots do
			local itemInfo = C_Container.GetContainerItemInfo(bagID, slotIndex)
			if itemInfo and itemInfo.itemID == targetItemID then
				local itemLink = C_Container.GetContainerItemLink(bagID, slotIndex)
				if itemLink == targetItemLink then
					return { bagID = bagID, slotIndex = slotIndex }
				elseif itemLink and not fallbackMatch then
					fallbackMatch = { bagID = bagID, slotIndex = slotIndex }
				end
			end
		end
	end

	return fallbackMatch
end

local function CreateItemLocation(bagID, slotIndex)
	if ItemLocation and ItemLocation.CreateFromBagAndSlot then
		return ItemLocation:CreateFromBagAndSlot(bagID, slotIndex)
	end
	return nil
end

function CW:GetVisibleOrderForm()
	local frame = _G["ProfessionsCustomerOrdersFrame"]
	if frame and frame.Form and frame.Form:IsShown() then
		return frame.Form
	end
	return nil
end

CW.CopyDefaults              = CopyDefaults
CW.IsContextFresh              = IsContextFresh
CW.CurrentSpecInfo             = CurrentSpecInfo
CW.DetectPrimaryStatsOnItem    = DetectPrimaryStatsOnItem
CW.HasHiddenPrimaryStatIndicator = HasHiddenPrimaryStatIndicator
CW.GetExpectedArmorTypeForPlayerClass = GetExpectedArmorTypeForPlayerClass
CW.GetItemArmorType            = GetItemArmorType
CW.IsUniversalArmorSlot        = IsUniversalArmorSlot
CW.GetItemSlotLabel            = GetItemSlotLabel
CW.GetItemIDFromLink           = GetItemIDFromLink
CW.FindItemInBagsByLink        = FindItemInBagsByLink
CW.CreateItemLocation          = CreateItemLocation
