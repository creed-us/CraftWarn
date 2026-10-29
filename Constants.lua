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
	restoreRecraftDelaySeconds = 0.2,
	restoreRequestTimeoutSeconds = 1.0,
}

CW.UI_CONFIG = {
	lastRecipeButtonSize = 32,
	lastRecipeButtonOffsetX = -4,
	warningHolderWidth = 400,
	warningHolderHeight = 24,
	warningHolderOffsetY = -10,
	warningRowCount = 3,
	warningIconSize = 15,
	warningIconTextGap = 2,
	warningIconLineSpacing = 3,
	warningIcons = {
		match = "Interface\\RaidFrame\\ReadyCheck-Ready",
		info = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew",
		warning = "Interface\\RaidFrame\\ReadyCheck-NotReady",
	},
	warningInfoIconTint = { 0.86, 0.84, 0.72 },
	warningColors = {
		warning = { 1.0, 0.23, 0.19 },
		match = { 0.26, 0.84, 0.26 },
		info = { 1.0, 0.95, 0.8 },
	},
}

CW.OPTIONS_SCHEMA = {
	{ key = "autoOpenLastRecipe", text = "Auto-open last recipe when browsing orders", tooltip = "Automatically re-open the last recipe when the customer orders window opens." },
	{ key = "enableSpecStatWarning", text = "Warn on spec primary-stat mismatch", tooltip = "Shows a warning if the crafted item primary stat does not match your current specialization primary stat.", refresh = true },
	{ key = "enableArmorTypeWarning", text = "Warn on class armor-type mismatch", tooltip = "Shows a warning if the crafted armor type does not match your class bonus armor type.", refresh = true },
	{ key = "enableSpecStatMatch", text = "Show confirmation when stat matches spec", tooltip = "Shows a green confirmation message when the crafted item primary stat matches your current specialization.", refresh = true },
	{ key = "enableArmorTypeMatch", text = "Show confirmation when armor matches class (and info for universal-slot items)", tooltip = "Shows a green confirmation when the crafted armor type matches your class, and a note for slots with no armor-type restriction (rings, necklaces, trinkets, cloaks, off-hand items).", refresh = true },
	{ key = "enableNoPrimaryStatInfo", text = "Show info when crafted item has no primary stat", tooltip = "Lower-priority info for items like rings/neck when no primary stat exists.", refresh = true },
	{ key = "enableEmbellishmentInfo", text = "Show Embellished gear info (equipped + bags)", tooltip = "Shows how many Embellished items you have equipped (max 2) and whether you're carrying any in your bags.", refresh = true },
	{ key = "forgetOnBack", text = "Don't auto-open last recipe after clicking back", tooltip = "After clicking Back on the order form, the last recipe will not be automatically re-opened next time." },
	{ key = "forgetOnPlace", text = "Don't auto-open last recipe after placing an order", tooltip = "After placing an order, the last recipe will not be automatically re-opened next time." },
	{ key = "showLoadedMessage", text = "Show startup message in chat", tooltip = "Prints a short message to chat when CraftWarn loads at login." },
}

CW.SLASH_TOGGLE_COMMANDS = {
	autoopen = "autoOpenLastRecipe",
	specwarn = "enableSpecStatWarning",
	armorwarn = "enableArmorTypeWarning",
	specmatch = "enableSpecStatMatch",
	armormatch = "enableArmorTypeMatch",
	nostatinfo = "enableNoPrimaryStatInfo",
	embellishinfo = "enableEmbellishmentInfo",
	forgetback = "forgetOnBack",
	forgetplace = "forgetOnPlace",
	loadmsg = "showLoadedMessage",
}

CW.TEXT = {
	addonPrefix = "|cfc7f03ffCraftWarn|r",
	optionsPanelName = "CraftWarn",
	optionsSubtitle = "Remember last customer-order recipe and show safety warnings.",
	loadedMessage = "%s loaded. Use /craftwarn or /cwarn for options.",
	lastRecipe = {
		label = "Last Recipe",
		labelRecraft = "Last Recipe (Recraft)",
		noSavedRecipe = "No saved recipe to restore.",
		recraftItemNotFound = "Recraft item not found in bags.",
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
		unknown = "Unknown",
		noStatText = "No Stat",
		statNoneTooltip = "This item has no primary stat.",
		statProcText = "Stat Proc",
		statProcTooltip = "No flat primary stat, but the tooltip mentions one (likely a conditional or on-use effect) - check manually whether it benefits your spec.",
		statMatchTooltip = "Matches your spec's primary stat.",
		statMismatchTooltip = "Your spec's primary stat is %s.",
		armorMatchTooltip = "Matches your class armor.",
		armorMismatchTooltip = "Your class wears %s.",
		armorUniversalTooltip = "%s items have no armor-type restriction - any class can use this.",
		universalText = "Universal",
		universalTooltip = "%s items have no primary stat or armor-type restriction - any class can use this.",
		embellishOkText = "Embellished %d/2",
		embellishOkTooltip = "This craft results in an Embellished item - you'll have %d/2 equipped.",
		embellishSafeTooltip = "This is a recraft of an item you currently have equipped and embellished (%d/2). It'll remain embellished afterward.",
		embellishRemovedText = "Embellishment Removed",
		embellishRemovedTooltip = "This recraft removes the Embellishment from an item you currently have equipped (%d/2 currently) - you'll free up a slot.",
		embellishCappedText = "Embellished 2/2",
		embellishCappedTooltip = "This craft uses an Embellishment, but you already have 2 equipped (the max) - you'll need to unequip one to wear it.",
		embellishBagSuffix = " (+%d in bag)",
		embellishBagOnlyText = "Embellished %d/2 (+%d bag)",
		embellishBagOnlyTooltip = "You have %d/2 Embellished items equipped, and %d unequipped in your bags.",
	},
}

CW.DEFAULTS = {
	autoOpenLastRecipe		= true,
	enableSpecStatWarning	= true,
	enableArmorTypeWarning	= true,
	enableSpecStatMatch		= false,
	enableArmorTypeMatch	= false,
	enableNoPrimaryStatInfo	= false,
	enableEmbellishmentInfo	= true,
	forgetOnBack			= false,
	forgetOnPlace			= false,
	showLoadedMessage		= true,
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

-- Equip slots that carry no class-restricted armor type: any class can use these.
CW.UNIVERSAL_ARMOR_EQUIP_LOCS = {
	INVTYPE_NECK		= true,
	INVTYPE_FINGER		= true,
	INVTYPE_TRINKET		= true,
	INVTYPE_CLOAK		= true,
	INVTYPE_HOLDABLE	= true,
}

-- Real equipment slots to scan for Embellished gear (excludes shirt/tabard, which can't be embellished).
CW.EQUIPPED_SLOT_IDS = {
	INVSLOT_HEAD,
	INVSLOT_NECK,
	INVSLOT_SHOULDER,
	INVSLOT_CHEST,
	INVSLOT_WAIST,
	INVSLOT_LEGS,
	INVSLOT_FEET,
	INVSLOT_WRIST,
	INVSLOT_HAND,
	INVSLOT_FINGER1,
	INVSLOT_FINGER2,
	INVSLOT_TRINKET1,
	INVSLOT_TRINKET2,
	INVSLOT_BACK,
	INVSLOT_MAINHAND,
	INVSLOT_OFFHAND,
}
