local CW = CraftWarn
if not CW then
	return
end

local TEXT = CW.TEXT
local CHAT_TEXT = TEXT.chat

local function ToBoolean(value)
	local v = value and string.lower(value)
	if v == "on" or v == "1" or v == "true" then
		return true
	end
	if v == "off" or v == "0" or v == "false" then
		return false
	end
	return nil
end

---------------------------------------------------------------------------
-- Table-driven toggle commands
---------------------------------------------------------------------------

local TOGGLE_COMMANDS = {
	autoopen    = { key = "autoOpenLastRecipe" },
	specwarn    = { key = "enableSpecStatWarning",		refresh = true },
	armorwarn   = { key = "enableArmorTypeWarning",		refresh = true },
	specmatch   = { key = "enableSpecStatMatch",		refresh = true },
	armormatch  = { key = "enableArmorTypeMatch",		refresh = true },
	nostatinfo  = { key = "enableNoPrimaryStatInfo",	refresh = true },
	forgetback  = { key = "forgetOnBack" },
	forgetplace = { key = "forgetOnPlace" },
}

local function HandleToggle(entry, arg)
	local value = ToBoolean(arg)
	if value == nil then
		CW:Print(string.format(CHAT_TEXT.toggleUsage, entry.cmd))
		return
	end
	CraftWarnDB[entry.key] = value
	CW:Print(string.format(CHAT_TEXT.settingValue, entry.key, tostring(value)))

	if entry.refresh then
		local form = CW:GetVisibleOrderForm()
		if form then
			CW:RefreshFormWarnings(form)
		end
	end
end

-- Inject command name into each entry for usage messages
for cmd, entry in pairs(TOGGLE_COMMANDS) do
	entry.cmd = cmd
end

---------------------------------------------------------------------------
-- Status / help
---------------------------------------------------------------------------

local function PrintStatus()
	for _, entry in pairs(TOGGLE_COMMANDS) do
		CW:Print(string.format(CHAT_TEXT.settingValue, entry.key, tostring(CraftWarnDB[entry.key])))
	end

	if CraftWarnDB.lastOrderContext and CraftWarnDB.lastOrderContext.spellID then
		CW:Print(string.format(CHAT_TEXT.savedSpellId, CraftWarnDB.lastOrderContext.spellID))
	else
		CW:Print(CHAT_TEXT.savedSpellIdNone)
	end
end

local function PrintHelp()
	CW:Print(CHAT_TEXT.status)
	for cmd in pairs(TOGGLE_COMMANDS) do
		CW:Print(string.format(CHAT_TEXT.toggleHelp, cmd))
	end
	CW:Print(CHAT_TEXT.reset)
end

---------------------------------------------------------------------------
-- Slash handler
---------------------------------------------------------------------------

SLASH_CRAFTWARN1 = "/craftwarn"
SLASH_CRAFTWARN2 = "/cw"
SlashCmdList.CRAFTWARN = function(msg)
	local command, arg = msg:match("^(%S+)%s*(.-)$")
	command = command and string.lower(command) or ""

	if command == "" or command == "help" then
		PrintHelp()
		return
	end

	if command == "status" then
		PrintStatus()
		return
	end

	if command == "reset" then
		CraftWarnDB.lastOrderContext = nil
		CW.pendingRestoreContext = nil
		CW:Print(CHAT_TEXT.clearedContext)
		return
	end

	local entry = TOGGLE_COMMANDS[command]
	if entry then
		HandleToggle(entry, arg)
		return
	end

	PrintHelp()
end
