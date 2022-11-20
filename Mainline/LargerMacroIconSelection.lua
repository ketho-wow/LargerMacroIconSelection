local _, S = ...
--local L = S.L
LargerMacroIconSelection = CreateFrame("Frame")
local LMIS = LargerMacroIconSelection

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
		S.FileData = fd:GetFileDataRetail()
	end
end

function LMIS:OnEvent(event, addon)
	if addon == "LargerMacroIconSelection" then
		LargerMacroIconSelectionDB = LargerMacroIconSelectionDB or CopyTable(defaults)
		self.db = LargerMacroIconSelectionDB
		self:Initialize(GearManagerPopupFrame)
		if IsAddOnLoaded("Blizzard_MacroUI") then -- someone else made it load before us
			self:Initialize(MacroPopupFrame)
		end
		if IsAddOnLoaded("Blizzard_GuildBankUI") then
			self:Initialize(GuildBankPopupFrame)
		end
	elseif addon == "Blizzard_MacroUI" then
		self:Initialize(MacroPopupFrame)
	elseif addon == "Blizzard_GuildBankUI" then
		self:Initialize(GuildBankPopupFrame)
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
		for _, b in pairs(popup.IconSelector.ScrollBox:GetFrames()) do
			b:HookScript("OnEnter", function()
				GameTooltip:SetOwner(b, "ANCHOR_TOPLEFT")
				local idx = b:GetSelectionIndex()
				local fileid = b:GetSelection()
				local isValid = (type(fileid) == "number")
				GameTooltip:AddLine(isValid and format("%s |cff71D5FF%s|r", idx, fileid) or idx)
				if idx == 1 then
					GameTooltip:AddLine("inv_misc_questionmark", 1, 1, 1)
				else
					GameTooltip:AddLine(isValid and S.FileData[fileid] or fileid, 1, 1, 1)
				end
				GameTooltip:Show()
			end)
			b:HookScript("OnLeave", function()
				GameTooltip:Hide()
			end)
		end
		-- need all buttons created and hooked before changing the data provider
		self:UpdateIconSelector(popup)
	end)
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
	popup:Update()
end
