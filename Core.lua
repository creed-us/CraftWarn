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
CW.fallbackTickerSeconds = CW.RUNTIME_CONFIG and CW.RUNTIME_CONFIG.fallbackTickerSeconds
CW.fallbackStaleRefreshSeconds = CW.RUNTIME_CONFIG and CW.RUNTIME_CONFIG.fallbackStaleRefreshSeconds
CW.fallbackContextCaptureSeconds = CW.RUNTIME_CONFIG and CW.RUNTIME_CONFIG.fallbackContextCaptureSeconds
CW.restoreRequestTimeoutSeconds = CW.RUNTIME_CONFIG and CW.RUNTIME_CONFIG.restoreRequestTimeoutSeconds

-- Refs from Utilities
local IsContextFresh				= CW.IsContextFresh
local NormalizeCraftingReagentInfos	= CW.NormalizeCraftingReagentInfos
local BuildReagentFromSaved			= CW.BuildReagentFromSaved
local CopyDefaults					= CW.CopyDefaults
local DEFAULTS						= CW.DEFAULTS
local RUNTIME_CONFIG				= CW.RUNTIME_CONFIG
local UI_CONFIG						= CW.UI_CONFIG
local TEXT							= CW.TEXT

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

function CW:ClearRestoreRequest()
	self.restoreRequested = false
	self.pendingRestoreContext = nil
	self.pendingRestoreIsManual = false
	self.restoreRequestToken = (self.restoreRequestToken or 0) + 1
end

function CW:IsAutoOpenSuppressed()
	return self.suppressAutoOpen and true or false
end

function CW:ClearAutoOpenSuppression()
	if not self.suppressAutoOpen then
		return
	end

	self.suppressAutoOpen = false
end

function CW:CanAttemptRestore(isManual)
	if not IsResting() then
		return false, nil
	end

	if not isManual then
		if not self.db.autoOpenLastRecipe then
			return false, nil
		end

		if self:IsAutoOpenSuppressed() then
			return false, nil
		end
	end

	if self.restoreRequested then
		return false, nil
	end

	local context = self.db.lastOrderContext
	if not context or not IsContextFresh(context) then
		return false, nil
	end

	if not context.spellID or not context.skillLineAbilityID then
		return false, nil
	end

	if not EventRegistry then
		return false, nil
	end

	return true, context
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
	return (now - lastRefresh) >= self.fallbackStaleRefreshSeconds
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
	return (now - lastCapture) >= self.fallbackContextCaptureSeconds
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
-- Order context capture / restore
---------------------------------------------------------------------------

function CW:CaptureCurrentOrderContext(form)
	if not self:IsCaptureContext(form) then
		return
	end

	if not form or not form.transaction or not form.order then
		return
	end

	if form.order.orderID then
		return
	end

	local spellID = form.order.spellID
	local skillLineAbilityID = form.order.skillLineAbilityID
	if not spellID or not skillLineAbilityID then
		return
	end

	local craftingInfos = form.transaction.CreateCraftingReagentInfoTbl and form.transaction:CreateCraftingReagentInfoTbl() or nil
	local allocations = NormalizeCraftingReagentInfos(craftingInfos)

	local outputItemID = form.order.itemID
	if not outputItemID and C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
		local schematic = C_TradeSkillUI.GetRecipeSchematic(spellID, form.order.isRecraft or false)
		outputItemID = schematic and schematic.outputItemID or nil
	end

	self.db.lastOrderContext = {
		itemID = outputItemID,
		spellID = spellID,
		skillLineAbilityID = skillLineAbilityID,
		isRecraft = form.order.isRecraft and true or false,
		timestamp = time(),
		allocations = allocations,
	}
	self:UpdateLastRecipeButton()
end

function CW:ApplySavedAllocations(form, context)
	if not form or not form.transaction or type(context) ~= "table" then
		return
	end

	local savedAllocations = context.allocations
	if type(savedAllocations) ~= "table" or #savedAllocations == 0 then
		form.cwRestoredFromContext = true
		self:MarkWarningStateDirty(form)
		self:QueueWarningRefresh(form, 0)
		self:QueueWarningRefresh(form, RUNTIME_CONFIG.delayedWarningRefreshSeconds)
		return
	end

	if not form.transaction.OverwriteAllocation then
		form.cwRestoredFromContext = true
		self:MarkWarningStateDirty(form)
		self:QueueWarningRefresh(form, 0)
		self:QueueWarningRefresh(form, RUNTIME_CONFIG.delayedWarningRefreshSeconds)
		return
	end

	local recipeSchematic = (form.transaction.GetRecipeSchematic and form.transaction:GetRecipeSchematic()) or form.recipeSchematic
	local slotSchematics = recipeSchematic and recipeSchematic.reagentSlotSchematics
	if type(slotSchematics) ~= "table" then
		form.cwRestoredFromContext = true
		self:MarkWarningStateDirty(form)
		self:QueueWarningRefresh(form, 0)
		self:QueueWarningRefresh(form, RUNTIME_CONFIG.delayedWarningRefreshSeconds)
		return
	end

	local slotByIndex = {}
	for _, slot in ipairs(slotSchematics) do
		slotByIndex[slot.slotIndex] = slot
	end

	for _, saved in ipairs(savedAllocations) do
		local slotIndex = saved.slotIndex
		local reagent = BuildReagentFromSaved(saved)
		local slotSchematic = slotByIndex[slotIndex]

		if slotIndex and reagent and slotSchematic then
			local quantity = math.max(1, math.floor(saved.quantity or 0))
			if quantity > 0 then
				form.transaction:OverwriteAllocation(slotIndex, reagent, quantity)
			end
		end
	end

	if form.UpdateReagentSlots then
		form:UpdateReagentSlots()
	end
	if form.UpdateListOrderButton then
		form:UpdateListOrderButton()
	end

	form.cwRestoredFromContext = true
	self:MarkWarningStateDirty(form)
	self:QueueWarningRefresh(form, 0)
	self:QueueWarningRefresh(form, RUNTIME_CONFIG.delayedWarningRefreshSeconds)
end

function CW:SuppressAutoOpen()
	self.suppressAutoOpen = true
end

function CW:ManualRestoreLastContext()
	local context = self.db.lastOrderContext
	if not context or not IsContextFresh(context) then
		self:Print(TEXT.lastRecipe.noSavedRecipe)
		return
	end
	self:ClearAutoOpenSuppression()
	self:ClearRestoreRequest()
	self:TryRestoreLastContext(true)
end

function CW:TryRestoreLastContext(isManual)
	local canRestore, context = self:CanAttemptRestore(isManual and true or false)
	if not canRestore then
		return
	end
	if not context then
		return
	end

	self.pendingRestoreContext = context
	self.pendingRestoreIsManual = isManual and true or false
	self.restoreRequested = true
	self.restoreRequestToken = (self.restoreRequestToken or 0) + 1
	local token = self.restoreRequestToken
	local timeoutSeconds = tonumber(self.restoreRequestTimeoutSeconds) or 0
	if timeoutSeconds > 0 then
		C_Timer.After(timeoutSeconds, function()
			if self.restoreRequestToken ~= token then
				return
			end
			self:ClearRestoreRequest()
		end)
	end

	local unusableBOP = false
	self.recipeSelectionOrigin = isManual and "manualRestore" or "autoRestore"
	EventRegistry:TriggerEvent(
		"ProfessionsCustomerOrders.RecipeSelected",
		context.itemID,
		context.spellID,
		context.skillLineAbilityID,
		unusableBOP
	)
	self.recipeSelectionOrigin = nil
end

---------------------------------------------------------------------------
-- Last-recipe button
---------------------------------------------------------------------------

function CW:UpdateLastRecipeButton()
	local btn = self.lastRecipeButton
	if not btn then return end
	local hasContext = (self.db.lastOrderContext ~= nil) and IsContextFresh(self.db.lastOrderContext)
	btn:SetEnabled(hasContext)
	if btn.Icon then btn.Icon:SetDesaturated(not hasContext) end
end

function CW:BuildLastRecipeButton(browsePage)
	if self.lastRecipeButton then return end
	local searchBar = browsePage.SearchBar
	local favBtn = searchBar and searchBar.FavoritesSearchButton
	if not favBtn then return end
	local btn = CreateFrame("Button", nil, searchBar, "SquareIconButtonTemplate")
	local buttonSize = UI_CONFIG.lastRecipeButtonSize
	local buttonOffsetX = UI_CONFIG.lastRecipeButtonOffsetX
	btn:SetSize(buttonSize, buttonSize)
	btn:SetPoint("RIGHT", favBtn, "LEFT", buttonOffsetX, 0)
	if btn.Icon then btn.Icon:SetAtlas("common-dropdown-icon-back") end
	btn:SetScript("OnClick", function()
		CW:ManualRestoreLastContext()
	end)
	btn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
		GameTooltip_AddHighlightLine(GameTooltip, TEXT.lastRecipe.label)
		local ctx = CW.db.lastOrderContext
		if ctx and ctx.spellID then
			local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(ctx.spellID)
			if name then
				GameTooltip_AddNormalLine(GameTooltip, name)
			end
		end
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", GameTooltip_Hide)
	self.lastRecipeButton = btn
	self:UpdateLastRecipeButton()
end

---------------------------------------------------------------------------
-- Ticker
---------------------------------------------------------------------------

function CW:StartFormTicker(form)
	if not form then return end
	self:StopFormTicker(form)
	form.CraftWarnTicker = C_Timer.NewTicker(self.fallbackTickerSeconds, function()
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
-- UI hooking
---------------------------------------------------------------------------

function CW:HookCustomerOrdersFrame()
	if self.customerFrameHooked then
		return
	end

	local frame = _G["ProfessionsCustomerOrdersFrame"]
	if not frame or not frame.Form then
		return
	end

	self.customerFrameHooked = true
	if EventRegistry and not self.recipeSelectedHooked then
		self.recipeSelectedHooked = true
		hooksecurefunc(EventRegistry, "TriggerEvent", function(_, eventName)
			if eventName ~= "ProfessionsCustomerOrders.RecipeSelected" then
				return
			end

			if self.recipeSelectionOrigin == nil then
				self:ClearAutoOpenSuppression()
			end
		end)
	end

	frame:HookScript("OnShow", function()
		if not IsResting() then
			return
		end

		self:ClearRestoreRequest()
		C_Timer.After(RUNTIME_CONFIG.restoreTryDelaySeconds, function()
			if not frame or not frame:IsShown() then
				return
			end
			self:TryRestoreLastContext(false)
		end)
	end)

	frame.Form:HookScript("OnShow", function(form)
		if not self:IsOperationalContext(form) then
			self:RenderWarnings(form, nil)
			return
		end
		self:MarkWarningStateDirty(form)
		self:QueueWarningRefresh(form, 0)
		self:StartFormTicker(form)
	end)

	frame.Form:HookScript("OnHide", function(form)
		self:CaptureCurrentOrderContext(form)
		self:StopFormTicker(form)
		self:InvalidateWarningCache()
		form.cwWarningDirty = false
		form.cwLastWarningRefreshTime = nil
		form.cwLastContextCaptureTime = nil
		form.cwRefreshToken = nil
		self:RenderWarnings(form, nil)
	end)

	hooksecurefunc(frame.Form, "UpdateReagentSlots", function(form)
		if not self:IsOperationalContext(form) then
			return
		end

		self:MarkWarningStateDirty(form)
		self:QueueWarningRefresh(form, 0)
	end)

	hooksecurefunc(frame.Form, "Init", function(form, order)
		self:InvalidateWarningCache()

		if not self:IsOperationalContext(form) then
			self:RenderWarnings(form, nil)
			return
		end

		self:CaptureCurrentOrderContext(form)
		self:MarkWarningStateDirty(form)

		local didScheduleRestore = false
		if self.pendingRestoreContext
			and order
			and order.spellID
			and self.pendingRestoreContext.spellID == order.spellID
		then
			local context = self.pendingRestoreContext
			local wasManualRestore = self.pendingRestoreIsManual
			self:ClearRestoreRequest()
			if wasManualRestore then
				self:ClearAutoOpenSuppression()
			end
			didScheduleRestore = true
			C_Timer.After(RUNTIME_CONFIG.restoreApplyDelaySeconds, function()
				if not self:IsOperationalContext(form) then
					return
				end
				self:ApplySavedAllocations(form, context)
			end)
		elseif self.restoreRequested then
			-- A different recipe won the race; clear stale pending restore state.
			self:ClearRestoreRequest()
		end

		if not didScheduleRestore then
			form.cwRestoredFromContext = false
			self:MarkWarningStateDirty(form)
			self:QueueWarningRefresh(form, 0)
			self:QueueWarningRefresh(form, RUNTIME_CONFIG.delayedWarningRefreshSeconds)
		end
	end)

	local backButton = frame.Form.BackButton
	if backButton then
		backButton:HookScript("OnClick", function()
			if self.db.forgetOnBack then
				self:SuppressAutoOpen()
			end
		end)
	end

	hooksecurefunc(frame.Form, "ListOrder", function()
		if self.db.forgetOnPlace then
			self:SuppressAutoOpen()
		end

		self:InvalidateWarningCache()
		if self.ClearItemAnalysisCache then
			self:ClearItemAnalysisCache()
		end

		if frame.Form then
			frame.Form.cwWarningDirty = false
			self:RenderWarnings(frame.Form, nil)
		end
	end)

	if frame.BrowseOrders then
		self:BuildLastRecipeButton(frame.BrowseOrders)
	end
end

function CW:TryHookProfessionUI()
	self:HookCustomerOrdersFrame()
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------

function CW:Initialize()
	self:EnsureDatabase()
	self:TryHookProfessionUI()
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
		CW:Initialize()

		if not CleanupAlreadyLoadedAddons() then
			eventFrame:RegisterEvent("ADDON_LOADED")
		end

		eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
		UpdateRestingState()

	elseif event == "ADDON_LOADED" then
		if pendingAddons[arg1] then
			CW:TryHookProfessionUI()
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
	end
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", OnEvent)
