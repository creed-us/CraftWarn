CraftWarn = CraftWarn or {}
local CW = CraftWarn

CW.ITEM_ANALYSIS_CACHE_SIZE = 8

CW.RUNTIME_CONFIG = {
	fallbackTickerSeconds = 0.5,
	fallbackStaleRefreshSeconds = 0.5,
	fallbackContextCaptureSeconds = 1.0,
	delayedWarningRefreshSeconds = 0.1,
	restoreTryDelaySeconds = 0.15,
	restoreApplyDelaySeconds = 0.05,
}

CW.UI_CONFIG = {
	lastRecipeButtonSize = 32,
	lastRecipeButtonOffsetX = -4,
	warningHolderWidth = 350,
	warningHolderHeight = 24,
	warningHolderOffsetY = -10,
	warningLineSpacing = -2,
	warningColors = {
		mismatch = { 1.0, 0.23, 0.19 },
		match = { 0.26, 0.84, 0.26 },
		info = { 0.5, 0.5, 0.5 },
	},
}

CW.OPTIONS_SCHEMA = {
	{ key = "autoOpenLastRecipe", text = "Auto-open last recipe when browsing orders", tooltip = "Automatically re-open the last recipe when the customer orders window opens." },
	{ key = "enableSpecStatWarning", text = "Warn on spec primary-stat mismatch", tooltip = "Shows a warning if the crafted item primary stat does not match your current specialization primary stat.", refresh = true },
	{ key = "enableArmorTypeWarning", text = "Warn on class armor-type mismatch", tooltip = "Shows a warning if the crafted armor type does not match your class bonus armor type.", refresh = true },
	{ key = "enableSpecStatMatch", text = "Show confirmation when stat matches spec", tooltip = "Shows a green confirmation message when the crafted item primary stat matches your current specialization.", refresh = true },
	{ key = "enableArmorTypeMatch", text = "Show confirmation when armor matches class", tooltip = "Shows a green confirmation message when the crafted armor type matches your class bonus armor type.", refresh = true },
	{ key = "enableNoPrimaryStatInfo", text = "Show info when crafted item has no primary stat", tooltip = "Lower-priority info for items like rings/neck when no primary stat exists.", refresh = true },
	{ key = "forgetOnBack", text = "Don't auto-open last recipe after clicking back", tooltip = "After clicking Back on the order form, the last recipe will not be automatically re-opened next time." },
	{ key = "forgetOnPlace", text = "Don't auto-open last recipe after placing an order", tooltip = "After placing an order, the last recipe will not be automatically re-opened next time." },
}

CW.TEXT = {
	addonPrefix = "|cfc7f03ffCraftWarn|r",
	optionsPanelName = "CraftWarn",
	optionsSubtitle = "Remember last customer-order recipe and show safety warnings.",
	loadedMessage = "%s loaded. Use /craftwarn or /cw for options.",
	lastRecipe = {
		label = "Last Recipe",
		noSavedRecipe = "No saved recipe to restore.",
	},
	chat = {
		toggleUsage = "Usage: /craftwarn %s on|off",
		settingValue = "%s = %s",
		savedSpellId = "saved spellID = %d",
		savedSpellIdNone = "saved spellID = none",
		status = "/craftwarn status",
		reset = "/craftwarn reset",
		toggleHelp = "/craftwarn %s on|off",
		clearedContext = "Cleared saved last order context.",
	},
	warnings = {
		prefixStatMatch = "Stat Match",
		prefixStatMismatch = "Stat Mismatch",
		prefixArmorMatch = "Armor Match",
		prefixArmorMismatch = "Armor Mismatch",
		unknown = "Unknown",
		noPrimaryStat = "Crafted item has no primary stat.",
		statMatch = "Stat Match: Crafted item has %s.",
		statMismatch = "Stat Mismatch: Current spec uses %s, crafted item has %s.",
		armorMatch = "Armor Match: Crafted item is %s.",
		armorMismatch = "Armor Mismatch: Class armor is %s, crafted item is %s.",
	},
}

CW.DEFAULTS = {
	autoOpenLastRecipe		= true,
	enableSpecStatWarning	= true,
	enableArmorTypeWarning	= true,
	enableSpecStatMatch		= false,
	enableArmorTypeMatch	= false,
	enableNoPrimaryStatInfo	= false,
	forgetOnBack			= false,
	forgetOnPlace			= false,
	restoreTTLSeconds		= 24 * 60 * 60,
	lastOrderContext		= nil,
}

CW.PRIMARY_STATS = {
	[1] = "Strength",
	[2] = "Agility",
	[4] = "Intellect",
}

CW.SPEC_TO_STAT_KEY = {
	[1] = "ITEM_MOD_STRENGTH_SHORT",
	[2] = "ITEM_MOD_AGILITY_SHORT",
	[4] = "ITEM_MOD_INTELLECT_SHORT",
}

CW.STAT_KEY_TO_LABEL = {
	ITEM_MOD_STRENGTH_SHORT = "Strength",
	ITEM_MOD_AGILITY_SHORT = "Agility",
	ITEM_MOD_INTELLECT_SHORT = "Intellect",
}

CW.TRACKED_STAT_KEYS = {
	"ITEM_MOD_STRENGTH_SHORT",
	"ITEM_MOD_AGILITY_SHORT",
	"ITEM_MOD_INTELLECT_SHORT",
}

CW.ARMOR_TYPE_BY_CLASS_TOKEN = {
	WARRIOR		= "Plate",
	PALADIN		= "Plate",
	DEATHKNIGHT	= "Plate",

	HUNTER		= "Mail",
	SHAMAN		= "Mail",
	EVOKER		= "Mail",

	ROGUE		= "Leather",
	MONK		= "Leather",
	DRUID		= "Leather",
	DEMONHUNTER	= "Leather",

	PRIEST		= "Cloth",
	MAGE		= "Cloth",
	WARLOCK		= "Cloth",
}
