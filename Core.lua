local ADDON_NAME = ...

CraftWarn = CraftWarn or {}
local CW = CraftWarn

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

CW.db = CW.db or {}
CW.pendingRestoreContext = nil
CW.suppressAutoOpen = false
CW.restoreRequested = false
CW.customerFrameHooked = false

-- Refs from Utilities
local IsContextFresh				= CW.IsContextFresh
local NormalizeCraftingReagentInfos	= CW.NormalizeCraftingReagentInfos
local BuildReagentFromSaved			= CW.BuildReagentFromSaved
local CopyDefaults					= CW.CopyDefaults
local DEFAULTS						= CW.DEFAULTS

---------------------------------------------------------------------------
-- Core helpers
---------------------------------------------------------------------------

function CW:Print(msg)
	local prefix = "|cfc7f03ffCraftWarn|r"
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %s", prefix, tostring(msg)))
	end
end

function CW:EnsureDatabase()
	CraftWarnDB = CopyDefaults(CraftWarnDB, DEFAULTS)
	self.db = CraftWarnDB
end

---------------------------------------------------------------------------
-- Order context capture / restore
---------------------------------------------------------------------------

function CW:CaptureCurrentOrderContext(form)
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
	self.suppressAutoOpen = false
	self:UpdateLastRecipeButton()
end

function CW:ApplySavedAllocations(form, context)
	if not form or not form.transaction or type(context) ~= "table" then
		return
	end

	local savedAllocations = context.allocations
	if type(savedAllocations) ~= "table" or #savedAllocations == 0 then
		form.cwRestoredFromContext = true
		self:RefreshFormWarnings(form)
		return
	end

	if not form.transaction.OverwriteAllocation then
		form.cwRestoredFromContext = true
		self:RefreshFormWarnings(form)
		return
	end

	local recipeSchematic = (form.transaction.GetRecipeSchematic and form.transaction:GetRecipeSchematic()) or form.recipeSchematic
	local slotSchematics = recipeSchematic and recipeSchematic.reagentSlotSchematics
	if type(slotSchematics) ~= "table" then
		form.cwRestoredFromContext = true
		self:RefreshFormWarnings(form)
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
	self:RefreshFormWarnings(form)
end

function CW:SuppressAutoOpen()
	self.suppressAutoOpen = true
end

function CW:ManualRestoreLastContext()
	local context = self.db.lastOrderContext
	if not context or not IsContextFresh(context) then
		self:Print("No saved recipe to restore.")
		return
	end
	self.suppressAutoOpen = false
	self.restoreRequested = false
	self:TryRestoreLastContext()
end

function CW:TryRestoreLastContext()
	if not self.db.autoOpenLastRecipe then
		return
	end

	if self.suppressAutoOpen then
		return
	end

	if self.restoreRequested then
		return
	end

	local context = self.db.lastOrderContext
	if not context or not IsContextFresh(context) then
		return
	end

	if not context.spellID or not context.skillLineAbilityID then
		return
	end

	if not EventRegistry then
		return
	end

	self.pendingRestoreContext = context
	self.restoreRequested = true

	local unusableBOP = false
	EventRegistry:TriggerEvent(
		"ProfessionsCustomerOrders.RecipeSelected",
		context.itemID,
		context.spellID,
		context.skillLineAbilityID,
		unusableBOP
	)
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
	btn:SetSize(32, 32)
	btn:SetPoint("RIGHT", favBtn, "LEFT", -4, 0)
	if btn.Icon then btn.Icon:SetAtlas("common-dropdown-icon-back") end
	btn:SetScript("OnClick", function()
		CW:ManualRestoreLastContext()
	end)
	btn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
		GameTooltip_AddHighlightLine(GameTooltip, "Last Recipe")
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
	form.CraftWarnTicker = C_Timer.NewTicker(1.0, function()
		if not form:IsShown() then
			self:StopFormTicker(form)
			return
		end
		self:CaptureCurrentOrderContext(form)
		self:RefreshFormWarnings(form)
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

	frame:HookScript("OnShow", function()
		self.restoreRequested = false
		C_Timer.After(0.15, function()
			self:TryRestoreLastContext()
		end)
	end)

	frame.Form:HookScript("OnShow", function(form)
		self:StartFormTicker(form)
	end)

	frame.Form:HookScript("OnHide", function(form)
		self:CaptureCurrentOrderContext(form)
		self:StopFormTicker(form)
		self:InvalidateWarningCache()
		self:RenderWarnings(form, nil)
	end)

	hooksecurefunc(frame.Form, "Init", function(form, order)
		self:InvalidateWarningCache()
		self:CaptureCurrentOrderContext(form)

		if self.pendingRestoreContext
			and order
			and order.spellID
			and self.pendingRestoreContext.spellID == order.spellID
		then
			local context = self.pendingRestoreContext
			self.pendingRestoreContext = nil
			C_Timer.After(0.05, function()
				self:ApplySavedAllocations(form, context)
			end)
		else
			form.cwRestoredFromContext = false
			self:RefreshFormWarnings(form)
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
	self:Print(string.format("%s loaded. Use /craftwarn or /cw for options.", version))
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
	eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
	eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
end

local function UnregisterActiveEvents()
	if not activeEventsRegistered then return end
	activeEventsRegistered = false
	eventFrame:UnregisterEvent("BAG_UPDATE_DELAYED")
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

	elseif event == "BAG_UPDATE_DELAYED" then
		CW:MarkReagentsDirty()
		local form = CW:GetVisibleOrderForm()
		if form then
			CW:RefreshFormWarnings(form)
		end

	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		CW:InvalidateWarningCache()
		local form = CW:GetVisibleOrderForm()
		if form then
			CW:RefreshFormWarnings(form)
		end

	elseif event == "PLAYER_UPDATE_RESTING" then
		UpdateRestingState()
	end
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", OnEvent)
