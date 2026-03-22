local ADDON_NAME = ...

CraftWarn = CraftWarn or {}
local CW = CraftWarn

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

CW.db = CW.db or {}
CW.pendingRestoreContext = nil
CW.pendingRestoreIsManual = false
CW.suppressAutoOpen = false
CW.restoreRequested = false
CW.restoreRequestToken = 0
CW.customerFrameHooked = false
CW.recipeSelectedHooked = false
CW.recipeSelectionOrigin = nil
CW.isShuttingDown = false

-- Refs from Utilities
local CopyDefaults		= CW.CopyDefaults
local DEFAULTS			= CW.DEFAULTS
local RUNTIME_CONFIG	= CW.RUNTIME_CONFIG
local TEXT				= CW.TEXT

---------------------------------------------------------------------------
-- Core helpers
---------------------------------------------------------------------------

function CW:Print(msg)
	local prefix = TEXT.addonPrefix
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %s", prefix, tostring(msg)))
	end
end

function CW:EnsureDatabase()
	CraftWarnDB = CopyDefaults(CraftWarnDB, DEFAULTS)
	self.db = CraftWarnDB
end

function CW:IsOperationalContext(form)
	if not IsResting() then
		return false
	end

	local targetForm = form
	if not targetForm then
		local frame = _G["ProfessionsCustomerOrdersFrame"]
		targetForm = frame and frame.Form or nil
	end

	if not targetForm or not targetForm:IsShown() then
		return false
	end

	local order = targetForm.order
	if not order then
		return false
	end

	return order.orderID == nil
end

-- Capture can run during teardown even when the form is no longer visible.
function CW:IsCaptureContext(form)
	if not IsResting() then
		return false
	end

	if not form or not form.order then
		return false
	end

	return form.order.orderID == nil
end

function CW:MarkWarningStateDirty(form)
	if not form then
		return
	end

	form.cwWarningDirty = true
end

function CW:ShouldRunFallbackRefresh(form)
	if not form then
		return false
	end

	if form.cwWarningDirty then
		return true
	end

	local now = GetTime and GetTime() or time()
	local lastRefresh = form.cwLastWarningRefreshTime or 0
	return (now - lastRefresh) >= RUNTIME_CONFIG.fallbackStaleRefreshSeconds
end

function CW:ShouldCaptureContext(form)
	if not form then
		return false
	end

	if form.cwWarningDirty then
		return true
	end

	local now = GetTime and GetTime() or time()
	local lastCapture = form.cwLastContextCaptureTime or 0
	return (now - lastCapture) >= RUNTIME_CONFIG.fallbackContextCaptureSeconds
end

function CW:QueueWarningRefresh(form, delaySeconds)
	if not form then
		return
	end

	if not self:IsOperationalContext(form) then
		form.cwWarningDirty = false
		self:RenderWarnings(form, nil)
		return
	end

	local delay = tonumber(delaySeconds) or 0
	form.cwRefreshToken = (form.cwRefreshToken or 0) + 1
	local token = form.cwRefreshToken

	if delay <= 0 then
		self:RefreshFormWarnings(form)
		return
	end

	C_Timer.After(delay, function()
		if not form or not form:IsShown() then
			return
		end
		if form.cwRefreshToken ~= token then
			return
		end
		self:RefreshFormWarnings(form)
	end)
end

---------------------------------------------------------------------------
-- Ticker
---------------------------------------------------------------------------

function CW:StartFormTicker(form)
	if not form then return end
	self:StopFormTicker(form)
	form.CraftWarnTicker = C_Timer.NewTicker(RUNTIME_CONFIG.fallbackTickerSeconds, function()
		if not self:IsOperationalContext(form) then
			self:RenderWarnings(form, nil)
			self:StopFormTicker(form)
			return
		end

		if not form:IsShown() then
			self:StopFormTicker(form)
			return
		end

		if self:ShouldCaptureContext(form) then
			self:CaptureCurrentOrderContext(form)
			form.cwLastContextCaptureTime = GetTime and GetTime() or time()
		end

		if self:ShouldRunFallbackRefresh(form) then
			self:MarkWarningStateDirty(form)
			self:QueueWarningRefresh(form, 0)
		end
	end)
end

function CW:StopFormTicker(form)
	if form and form.CraftWarnTicker then
		form.CraftWarnTicker:Cancel()
		form.CraftWarnTicker = nil
	end
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------

function CW:Initialize()
	self:EnsureDatabase()
	self:HookCustomerOrdersFrame()
	local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"
	self:Print(string.format(TEXT.loadedMessage, version))
end

---------------------------------------------------------------------------
-- Events (only active while resting in cities/inns)
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

-- Blizzard loads these on demand, so watch ADDON_LOADED until they show up
local pendingAddons = {
	["Blizzard_ProfessionsCustomerOrders"] = true,
	["Blizzard_Professions"] = true,
}

local activeEventsRegistered = false

local function RegisterActiveEvents()
	if activeEventsRegistered then return end
	activeEventsRegistered = true
	eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
end

local function UnregisterActiveEvents()
	if not activeEventsRegistered then return end
	activeEventsRegistered = false
	eventFrame:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")

	-- Kill the ticker, no point in running it outside of rest areas
	local frame = _G["ProfessionsCustomerOrdersFrame"]
	if frame and frame.Form then
		CW:StopFormTicker(frame.Form)
	end
end

local function UpdateRestingState()
	if IsResting() then
		RegisterActiveEvents()
	else
		UnregisterActiveEvents()
	end
end

local function TryUnregisterAddonLoaded(addonName)
	pendingAddons[addonName] = nil
	if not next(pendingAddons) then
		eventFrame:UnregisterEvent("ADDON_LOADED")
	end
end

-- If both addons loaded before us (unlikely but possible), skip ADDON_LOADED entirely
local function CleanupAlreadyLoadedAddons()
	for addon in pairs(pendingAddons) do
		if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addon) then
			pendingAddons[addon] = nil
		elseif IsAddOnLoaded and IsAddOnLoaded(addon) then
			pendingAddons[addon] = nil
		end
	end
	if not next(pendingAddons) then
		return true -- already loaded, don't bother with ADDON_LOADED
	end
	return false
end

local function OnEvent(_, event, arg1)
	if event == "PLAYER_LOGIN" then
		CW.isShuttingDown = false
		CW:Initialize()

		if not CleanupAlreadyLoadedAddons() then
			eventFrame:RegisterEvent("ADDON_LOADED")
		end

		eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
		UpdateRestingState()

	elseif event == "ADDON_LOADED" then
		if pendingAddons[arg1] then
			CW:HookCustomerOrdersFrame()
			TryUnregisterAddonLoaded(arg1)
		end

	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		CW:InvalidateWarningCache()
		local form = CW:GetVisibleOrderForm()
		if form then
			CW:MarkWarningStateDirty(form)
			CW:QueueWarningRefresh(form, 0)
		end

	elseif event == "PLAYER_UPDATE_RESTING" then
		UpdateRestingState()

	elseif event == "PLAYER_LOGOUT" then
		CW.isShuttingDown = true
		CW:ClearCachedRecipeContext()
	end
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", OnEvent)
