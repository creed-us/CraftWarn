CraftWarn = CraftWarn or {}
local CW = CraftWarn

CW.DEFAULTS = {
    restoreLastRecipe = true,
    autoOpenLastRecipe = true,
    forgetOnBack = false,
    forgetOnPlace = false,
    enableSpecStatWarning = true,
    enableSpecStatMatch = false,
    enableNoPrimaryStatInfo = false,
    restoreTTLSeconds = 24 * 60 * 60,
    lastOrderContext = nil,
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
