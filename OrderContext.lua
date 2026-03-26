local CW = CraftWarn
if not CW then return end

local IsContextFresh = CW.IsContextFresh
local FindItemInBagsByLink = CW.FindItemInBagsByLink
local CreateItemLocation = CW.CreateItemLocation
local RUNTIME_CONFIG = CW.RUNTIME_CONFIG
local UI_CONFIG = CW.UI_CONFIG
local TEXT = CW.TEXT

---------------------------------------------------------------------------
-- Order context capture / restore
---------------------------------------------------------------------------

function CW:ClearCachedRecipeContext()
	if self.db then self.db.lastOrderContext = nil end
	if CraftWarnDB then CraftWarnDB.lastOrderContext = nil end
	self.pendingRestoreContext = nil
	self.pendingRestoreIsManual = false
	self.restoreRequested = false
	self.suppressAutoOpen = false
end

function CW:ClearRestoreRequest()
	self.restoreRequested = false
	self.pendingRestoreContext = nil
	self.pendingRestoreIsManual = false
	self.restoreRequestToken = (self.restoreRequestToken or 0) + 1
end

function CW:ClearAutoOpenSuppression()
	self.suppressAutoOpen = false
end

function CW:SuppressAutoOpen()
	self.suppressAutoOpen = true
end

function CW:CanAttemptRestore(isManual)
	if not IsResting() or not EventRegistry then return false, nil end
	if not isManual and (not self.db.autoOpenLastRecipe or self.suppressAutoOpen) then return false, nil end
	if self.restoreRequested then return false, nil end

	local context = self.db.lastOrderContext
	if not context or not IsContextFresh(context) then return false, nil end

	if context.isRecraft then
		if not context.recraftGUID and not context.recraftItemHyperlink then return false, nil end
	else
		if not context.spellID or not context.skillLineAbilityID then return false, nil end
	end

	return true, context
end

function CW:CaptureCurrentOrderContext(form)
	if self.isShuttingDown or not self:IsCaptureContext(form) then return end
	if not form.transaction then return end

	local spellID, skillLineAbilityID = form.order.spellID, form.order.skillLineAbilityID
	if not spellID or not skillLineAbilityID then return end

	local outputItemID = form.order.itemID
	if not outputItemID and C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
		local schematic = C_TradeSkillUI.GetRecipeSchematic(spellID, form.order.isRecraft or false)
		outputItemID = schematic and schematic.outputItemID
	end

	local recraftItemHyperlink = form.order.recraftItemHyperlink
	if form.order.isRecraft and form.recraftGUID and not recraftItemHyperlink and C_Item and C_Item.GetItemLinkByGUID then
		recraftItemHyperlink = C_Item.GetItemLinkByGUID(form.recraftGUID)
	end

	self.db.lastOrderContext = {
		itemID = outputItemID,
		spellID = spellID,
		skillLineAbilityID = skillLineAbilityID,
		isRecraft = form.order.isRecraft and true or false,
		recraftItemHyperlink = recraftItemHyperlink,
		recraftGUID = form.recraftGUID,
		timestamp = time(),
	}
	self:UpdateLastRecipeButton()
end

function CW:ApplySavedContext(form, context)
	if not form or type(context) ~= "table" then return end
	form.cwRestoredFromContext = true
	self:MarkWarningStateDirty(form)
	self:QueueWarningRefresh(form, 0)
	self:QueueWarningRefresh(form, RUNTIME_CONFIG.delayedWarningRefreshSeconds)
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
	if not canRestore then return end

	self.pendingRestoreContext = context
	self.pendingRestoreIsManual = isManual and true or false
	self.restoreRequested = true

	local token = (self.restoreRequestToken or 0) + 1
	self.restoreRequestToken = token

	local timeoutSeconds = RUNTIME_CONFIG.restoreRequestTimeoutSeconds or 0
	if timeoutSeconds > 0 then
		C_Timer.After(timeoutSeconds, function()
			if self.restoreRequestToken == token then self:ClearRestoreRequest() end
		end)
	end

	self.recipeSelectionOrigin = isManual and "manualRestore" or "autoRestore"

	---@diagnostic disable: need-check-nil
	if context.isRecraft then
		EventRegistry:TriggerEvent("ProfessionsCustomerOrders.RecraftCategorySelected")
		self:TrySelectRecraftItem(context.recraftGUID, context.recraftItemHyperlink)
	else
		EventRegistry:TriggerEvent("ProfessionsCustomerOrders.RecipeSelected",
			context.itemID, context.spellID, context.skillLineAbilityID, false)
	end
	---@diagnostic enable: need-check-nil

	self.recipeSelectionOrigin = nil
end

--- Select recraft item by GUID (preferred) or by searching bags for hyperlink match.
function CW:TrySelectRecraftItem(recraftGUID, recraftItemHyperlink)
	if not recraftGUID and not recraftItemHyperlink then return end

	C_Timer.After(RUNTIME_CONFIG.restoreRecraftDelaySeconds, function()
		local itemGUID = recraftGUID

		-- If GUID invalid or missing, try to find item in bags by hyperlink
		if itemGUID then
			local loc = C_Item and C_Item.GetItemLocation and C_Item.GetItemLocation(itemGUID)
			if not loc or not loc:IsValid() then itemGUID = nil end
		end

		if not itemGUID and recraftItemHyperlink then
			local bagLoc = FindItemInBagsByLink(recraftItemHyperlink)
			if bagLoc then
				local loc = CreateItemLocation(bagLoc.bagID, bagLoc.slotIndex)
				if loc and loc:IsValid() and C_Item and C_Item.GetItemGUID then
					itemGUID = C_Item.GetItemGUID(loc)
				end
			end
		end

		if not itemGUID then return end

		local frame = _G["ProfessionsCustomerOrdersFrame"]
		if frame and frame.Form and frame.Form:IsShown() and frame.Form.SetRecraftItemGUID then
			frame.Form:SetRecraftItemGUID(itemGUID)
		end
	end)
end

---------------------------------------------------------------------------
-- Last-recipe button
---------------------------------------------------------------------------

function CW:UpdateLastRecipeButton()
	local btn = self.lastRecipeButton
	if not btn then return end

	local hasContext = self.db.lastOrderContext and IsContextFresh(self.db.lastOrderContext)
	btn:SetEnabled(hasContext)
	if btn.Icon then btn.Icon:SetDesaturated(not hasContext) end
end

function CW:BuildLastRecipeButton(browsePage)
	if self.lastRecipeButton then return end

	local searchBar = browsePage.SearchBar
	local favBtn = searchBar and searchBar.FavoritesSearchButton
	if not favBtn then return end

	local btn = CreateFrame("Button", nil, searchBar, "SquareIconButtonTemplate")
	btn:SetSize(UI_CONFIG.lastRecipeButtonSize, UI_CONFIG.lastRecipeButtonSize)
	btn:SetPoint("RIGHT", favBtn, "LEFT", UI_CONFIG.lastRecipeButtonOffsetX, 0)
	if btn.Icon then btn.Icon:SetAtlas("common-dropdown-icon-back") end

	btn:SetScript("OnClick", function() CW:ManualRestoreLastContext() end)

	btn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
		local ctx = CW.db.lastOrderContext
		GameTooltip_AddHighlightLine(GameTooltip, ctx and ctx.isRecraft and TEXT.lastRecipe.labelRecraft or TEXT.lastRecipe.label)
		if ctx then
			if ctx.isRecraft then
				local link = ctx.recraftItemHyperlink or (ctx.recraftGUID and C_Item and C_Item.GetItemLinkByGUID and C_Item.GetItemLinkByGUID(ctx.recraftGUID))
				if link then GameTooltip_AddNormalLine(GameTooltip, link) end
			elseif ctx.spellID and C_Spell and C_Spell.GetSpellName then
				local name = C_Spell.GetSpellName(ctx.spellID)
				if name then GameTooltip_AddNormalLine(GameTooltip, name) end
			end
		end
		GameTooltip:Show()
	end)

	btn:SetScript("OnLeave", GameTooltip_Hide)
	self.lastRecipeButton = btn
	self:UpdateLastRecipeButton()
end
