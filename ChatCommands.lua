local CW = CraftWarn
if not CW then
	return
end

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
	restore     = { key = "restoreLastRecipe" },
	autoopen    = { key = "autoOpenLastRecipe" },
	forgetback  = { key = "forgetOnBack" },
	forgetplace = { key = "forgetOnPlace" },
	specwarn    = { key = "enableSpecStatWarning",    refresh = true },
	specmatch   = { key = "enableSpecStatMatch",      refresh = true },
	nostatinfo  = { key = "enableNoPrimaryStatInfo",  refresh = true },
}

local function HandleToggle(entry, arg)
	local value = ToBoolean(arg)
	if value == nil then
		CW:Print(string.format("Usage: /craftwarn %s on|off", entry.cmd))
		return
	end
	CraftWarnDB[entry.key] = value
	CW:Print(string.format("%s = %s", entry.key, tostring(value)))

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
		CW:Print(string.format("%s = %s", entry.key, tostring(CraftWarnDB[entry.key])))
	end

	if CraftWarnDB.lastOrderContext and CraftWarnDB.lastOrderContext.spellID then
		CW:Print(string.format("saved spellID = %d", CraftWarnDB.lastOrderContext.spellID))
	else
		CW:Print("saved spellID = none")
	end
end

local function PrintHelp()
	CW:Print("/craftwarn status")
	for cmd in pairs(TOGGLE_COMMANDS) do
		CW:Print(string.format("/craftwarn %s on|off", cmd))
	end
	CW:Print("/craftwarn reset")
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
		CW:Print("Cleared saved last order context.")
		return
	end

	local entry = TOGGLE_COMMANDS[command]
	if entry then
		HandleToggle(entry, arg)
		return
	end

	PrintHelp()
end
