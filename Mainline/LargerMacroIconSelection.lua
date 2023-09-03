local _, S = ...
LargerMacroIconSelection = CreateFrame("Frame")
local LMIS = LargerMacroIconSelection
LMIS.isMainline = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
LMIS.isWrath = (WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC )

-- remove custom/duplicate icons from icon packs
-- until Blizzard fixes their non-FileDataID icon support
GetLooseMacroItemIcons = function() end
GetLooseMacroIcons = function() end

local defaults = {
	width = 10,
	height = 10,
}
LMIS.loadedFrames = {}

-- save memory by only loading FileData when needed
function LMIS:LoadFileData(addon)
	if not S.FileData then
		local loaded, reason = LoadAddOn(addon)
		if not loaded then
			if reason == "DISABLED" then
				EnableAddOn(addon, true)
				LoadAddOn(addon)
			else
				error(addon.." is "..reason)
			end
		end
		local fd = _G[addon]
		if self.isMainline then
			S.FileData = fd:GetFileDataRetail()
		elseif self.isWrath then
			S.FileData = fd:GetFileDataWrath()
		end
	end
end

function LMIS:OnEvent(event, addon)
	if addon == "LargerMacroIconSelection" then
		LargerMacroIconSelectionDB = LargerMacroIconSelectionDB or CopyTable(defaults)
		self.db = LargerMacroIconSelectionDB
		if self.isMainline then
			self:Initialize(GearManagerPopupFrame)
		end
		EventUtil.ContinueOnAddOnLoaded("Blizzard_MacroUI", function() self:Initialize(MacroPopupFrame) end)
		EventUtil.ContinueOnAddOnLoaded("Blizzard_GuildBankUI", function() self:Initialize(GuildBankPopupFrame) end)
	end
end

LMIS:RegisterEvent("ADDON_LOADED")
LMIS:SetScript("OnEvent", LMIS.OnEvent)

function LMIS:Initialize(popup)
	popup:HookScript("OnShow", function() -- only initialize when the popupframe shows
		if not self.loadedFrames[popup] then
			self.loadedFrames[popup] = true
		else
			self:UpdateIconSelector(popup) -- original iconDataProvider gets updated OnShow
			return
		end
		popup:HookScript("OnHide", function()
			if popup.iconDataProvider then
				popup.iconDataProvider:Release()
			end
		end)
		self:LoadFileData("LargerMacroIconSelectionData")
		self:InitSearch()
		-- movable
		popup:SetMovable(true)
		popup:SetClampedToScreen(true)
		popup:RegisterForDrag("LeftButton")
		popup:SetScript("OnDragStart", popup.StartMoving)
		popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
		-- searchbox
		self:CreateSearchBox(popup)
		-- icon tooltip
		for _, btn in pairs(popup.IconSelector.ScrollBox:GetFrames()) do
			btn:HookScript("OnEnter", LMIS.ShowTooltip)
			btn:HookScript("OnLeave", LMIS.GameTooltip_Hide)
		end
		popup.BorderBox.SelectedIconArea.SelectedIconButton:HookScript("OnEnter", function(btn)
			local fileid = btn:GetIconTexture()
			self:SetIconTooltip(btn, function()
				if fileid ~= 134400 then -- inv_misc_questionmark
					GameTooltip:AddLine(format("|cff71D5FF%s|r", fileid))
					if S.FileData[fileid] then
						GameTooltip:AddLine(S.FileData[fileid], 1, 1, 1)
					end
				end
			end)
		end)
		-- need all buttons created and hooked before changing the data provider
		self:UpdateIconSelector(popup)
	end)
end

function LMIS.ShowTooltip(btn)
	local idx = btn:GetSelectionIndex()
	local fileid = btn:GetSelection()
	local isValid = (type(fileid) == "number")
	LMIS:SetIconTooltip(btn, function()
		GameTooltip:AddLine(isValid and format("%s |cff71D5FF%s|r", idx, fileid) or idx)
		if idx == 1 then
			GameTooltip:AddLine("inv_misc_questionmark", 1, 1, 1)
		else
			GameTooltip:AddLine(isValid and S.FileData[fileid] or fileid, 1, 1, 1)
		end
	end)
end

function LMIS.GameTooltip_Hide()
	GameTooltip:Hide()
end

function LMIS:SetIconTooltip(parent, func)
	GameTooltip:SetOwner(parent, "ANCHOR_TOPLEFT")
	func()
	GameTooltip:Show()
end

local ProviderTypes = {
	MacroPopupFrame = IconDataProviderExtraType.Spell,
	GearManagerPopupFrame = IconDataProviderExtraType.Equipment,
}

-- probably not the most efficient way
function LMIS:UpdateIconSelector(popup)
	if popup.iconDataProvider then
		popup.iconDataProvider:Release()
	end
	popup.iconDataProvider = CreateAndInitFromMixin(IconDataProviderLmisMixin, ProviderTypes[popup:GetName()])
	self:UpdatePopup(popup)
end

-- updating clears the editbox and selected icon
function LMIS:UpdatePopup(popup)
	local text = popup.BorderBox.IconSelectorEditBox:GetText()
	local selectedIcon = popup.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture()
	popup.Update(popup)
	popup.BorderBox.IconSelectorEditBox:SetText(text)
	-- update selected icon and related functionality
	popup.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(selectedIcon)
	local index = popup.iconDataProvider:GetIndexOfIcon(selectedIcon)
	popup.IconSelector:SetSelectedIndex(index)
	popup:SetSelectedIconText()
	-- new icon type dropdown
	popup.BorderBox.IconTypeDropDown:SetSelectedValue(IconSelectorPopupFrameIconFilterTypes.All)
end
