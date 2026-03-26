local CW = CraftWarn
if not CW then
	return
end

local RUNTIME_CONFIG = CW.RUNTIME_CONFIG

local function MarkAndRefresh(self, form, includeDelayed)
	self:MarkWarningStateDirty(form)
	self:QueueWarningRefresh(form, 0)
	if includeDelayed then
		self:QueueWarningRefresh(form, RUNTIME_CONFIG.delayedWarningRefreshSeconds)
	end
end

local function ClearFormWarningState(form)
	form.cwWarningDirty = false
	form.cwLastWarningRefreshTime = nil
	form.cwLastContextCaptureTime = nil
	form.cwRefreshToken = nil
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
			if eventName == "ProfessionsCustomerOrders.RecipeSelected" and self.recipeSelectionOrigin == nil then
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
			if frame and frame:IsShown() then
				self:TryRestoreLastContext(false)
			end
		end)
	end)

	frame.Form:HookScript("OnShow", function(form)
		if not self:IsOperationalContext(form) then
			self:RenderWarnings(form, nil)
			return
		end
		MarkAndRefresh(self, form, false)
		self:StartFormTicker(form)
	end)

	frame.Form:HookScript("OnHide", function(form)
		self:CaptureCurrentOrderContext(form)
		self:StopFormTicker(form)
		self:InvalidateWarningCache()
		ClearFormWarningState(form)
		self:RenderWarnings(form, nil)
	end)

	hooksecurefunc(frame.Form, "Init", function(form, order)
		self:InvalidateWarningCache()

		if not self:IsOperationalContext(form) then
			self:RenderWarnings(form, nil)
			return
		end

		-- Don't re-capture context if restore is requested
		if not self.restoreRequested then
			self:CaptureCurrentOrderContext(form)
		end
		self:MarkWarningStateDirty(form)

		local didScheduleRestore = false
		if self.pendingRestoreContext and order and order.spellID and self.pendingRestoreContext.spellID == order.spellID then
			local context = self.pendingRestoreContext
			local wasManualRestore = self.pendingRestoreIsManual
			self:ClearRestoreRequest()
			if wasManualRestore then
				self:ClearAutoOpenSuppression()
			end

			didScheduleRestore = true
			C_Timer.After(RUNTIME_CONFIG.restoreApplyDelaySeconds, function()
				if self:IsOperationalContext(form) then
					self:ApplySavedContext(form, context)
				end
			end)
		elseif self.restoreRequested then
			-- A different recipe won the race; clear stale pending restore state.
			self:ClearRestoreRequest()
		end

		if not didScheduleRestore then
			form.cwRestoredFromContext = false
			MarkAndRefresh(self, form, true)
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
		self:ClearItemAnalysisCache()

		if frame.Form then
			frame.Form.cwWarningDirty = false
			self:RenderWarnings(frame.Form, nil)
		end
	end)

	if frame.BrowseOrders then
		self:BuildLastRecipeButton(frame.BrowseOrders)
	end
end
