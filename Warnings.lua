local CW = CraftWarn

local warningCache = {
	spellID = nil,
	enableSpecStatWarning = nil,
	enableArmorTypeWarning = nil,
	enableSpecStatMatch = nil,
	enableArmorTypeMatch = nil,
	enableNoPrimaryStatInfo = nil,
	statRow = nil,
	armorRow = nil,
}

local function AreSettingKeysUnchanged(self)
	return self.db.enableSpecStatWarning == warningCache.enableSpecStatWarning
		and self.db.enableSpecStatMatch == warningCache.enableSpecStatMatch
		and self.db.enableNoPrimaryStatInfo == warningCache.enableNoPrimaryStatInfo
		and self.db.enableArmorTypeWarning == warningCache.enableArmorTypeWarning
		and self.db.enableArmorTypeMatch == warningCache.enableArmorTypeMatch
end

function CW:InvalidateWarningCache()
	warningCache.spellID = nil
	warningCache.enableSpecStatWarning = nil
	warningCache.enableSpecStatMatch = nil
	warningCache.enableNoPrimaryStatInfo = nil
	warningCache.enableArmorTypeWarning = nil
	warningCache.enableArmorTypeMatch = nil
	warningCache.statRow = nil
	warningCache.armorRow = nil
end

function CW:RefreshFormWarnings(form)
	if not form or not form:IsShown() then
		return
	end

	if not self:IsOperationalContext(form) then
		self:RenderWarnings(form, nil)
		return
	end

	local spellID = form.order and form.order.spellID
	local now = GetTime and GetTime() or time()
	local embellishRow = self:BuildEmbellishmentRow(form)

	if not form.cwWarningDirty and spellID == warningCache.spellID and AreSettingKeysUnchanged(self) then
		self:RenderWarnings(form, { warningCache.statRow, warningCache.armorRow, embellishRow })
		form.cwLastWarningRefreshTime = now
		return
	end

	local itemLink = self:GetCurrentOutputContext(form)

	warningCache.spellID = spellID
	warningCache.enableSpecStatWarning = self.db.enableSpecStatWarning
	warningCache.enableSpecStatMatch = self.db.enableSpecStatMatch
	warningCache.enableNoPrimaryStatInfo = self.db.enableNoPrimaryStatInfo
	warningCache.enableArmorTypeWarning = self.db.enableArmorTypeWarning
	warningCache.enableArmorTypeMatch = self.db.enableArmorTypeMatch

	local itemAnalysis = self:GetItemAnalysis(itemLink)
	local statRow, armorRow = CW.CollapseUniversalRows(
		self:BuildSpecMismatchWarning(form, itemLink, itemAnalysis),
		self:BuildArmorTypeWarning(form, itemLink, itemAnalysis)
	)

	warningCache.statRow = statRow
	warningCache.armorRow = armorRow

	self:RenderWarnings(form, { statRow, armorRow, embellishRow })

	form.cwWarningDirty = false
	form.cwLastWarningRefreshTime = now
end
