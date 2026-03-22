local CW = CraftWarn
if not CW then
	return
end

local IsContextFresh = CW.IsContextFresh
local RUNTIME_CONFIG = CW.RUNTIME_CONFIG
local UI_CONFIG = CW.UI_CONFIG
local TEXT = CW.TEXT

---------------------------------------------------------------------------
-- Order context capture / restore
---------------------------------------------------------------------------

function CW:ClearCachedRecipeContext()
	if self.db then
		self.db.lastOrderContext = nil
	end
	if CraftWarnDB then
		CraftWarnDB.lastOrderContext = nil
	end
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

function CW:IsAutoOpenSuppressed()
	return self.suppressAutoOpen
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

function CW:CaptureCurrentOrderContext(form)
	if self.isShuttingDown then
		return
	end

	if not self:IsCaptureContext(form) then
		return
	end

	if not form or not form.transaction or not form.order then
		return
	end

	local spellID = form.order.spellID
	local skillLineAbilityID = form.order.skillLineAbilityID
	if not spellID or not skillLineAbilityID then
		return
	end

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
	}
	self:UpdateLastRecipeButton()
end

function CW:ApplySavedContext(form, context)
	if not form or type(context) ~= "table" then
		return
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

	self.pendingRestoreContext = context
	self.pendingRestoreIsManual = isManual and true or false
	self.restoreRequested = true
	self.restoreRequestToken = (self.restoreRequestToken or 0) + 1

	local token = self.restoreRequestToken
	local timeoutSeconds = tonumber(RUNTIME_CONFIG.restoreRequestTimeoutSeconds) or 0
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
	---@diagnostic disable: need-check-nil
	EventRegistry:TriggerEvent(
		"ProfessionsCustomerOrders.RecipeSelected",
		context.itemID,
		context.spellID,
		context.skillLineAbilityID,
		unusableBOP
	)
	---@diagnostic enable: need-check-nil
	self.recipeSelectionOrigin = nil
end

---------------------------------------------------------------------------
-- Last-recipe button
---------------------------------------------------------------------------

function CW:UpdateLastRecipeButton()
	local btn = self.lastRecipeButton
	if not btn then
		return
	end

	local hasContext = (self.db.lastOrderContext ~= nil) and IsContextFresh(self.db.lastOrderContext)
	btn:SetEnabled(hasContext)
	if btn.Icon then
		btn.Icon:SetDesaturated(not hasContext)
	end
end

function CW:BuildLastRecipeButton(browsePage)
	if self.lastRecipeButton then
		return
	end

	local searchBar = browsePage.SearchBar
	local favBtn = searchBar and searchBar.FavoritesSearchButton
	if not favBtn then
		return
	end

	local btn = CreateFrame("Button", nil, searchBar, "SquareIconButtonTemplate")
	btn:SetSize(UI_CONFIG.lastRecipeButtonSize, UI_CONFIG.lastRecipeButtonSize)
	btn:SetPoint("RIGHT", favBtn, "LEFT", UI_CONFIG.lastRecipeButtonOffsetX, 0)
	if btn.Icon then
		btn.Icon:SetAtlas("common-dropdown-icon-back")
	end

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
