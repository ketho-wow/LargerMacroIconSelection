local _, S = ...
local LMIS = LargerMacroIconSelection
local LibAIS = LibStub("LibAdvancedIconSelector-1.0-LMIS")

LMIS.searchIcons = {}

local LibAIS_options = {
	sectionOrder = {"FileDataIcons"},
}

function LMIS:InitSearch()
	if not self.searchObject then
		self.searchObject = LibAIS:CreateSearch(LibAIS_options)
		self.searchObject:SetScript("OnSearchStarted", function(_self)
			wipe(self.searchIcons)
		end)
		self.searchObject:SetScript("OnSearchResultAdded", function(_self, texture, _, _, _, fdid)
			tinsert(self.searchIcons, fdid)
		end)
		self.searchObject:SetScript("OnSearchComplete", function(_self)
			if self.activeSearch then
				local info = self.activeSearch
				local popup = info.popup
				if not popup:IsShown() then return end
				-- in 7.2 GB_ICON_FILENAMES was made accessible (thanks!), but as a table instead of function
				if popup == GuildBankPopupFrame then
					GB_ICON_FILENAMES = self.searchIcons
				end
				if #self.searchIcons == 0 then
					popup.SearchBox:SetTextColor(1, 0, 0)
				else
					popup.SearchBox:SetTextColor(1, 1, 1)
				end
				self:UpdateSearchPopup(info)
				self.activeSearch = nil
			end
		end)
	end
end

function LMIS:ClearSearch(info)
	self.activeSearch = nil
	wipe(self.searchIcons)
	self.searchObject:Stop()
	if info.popup == GuildBankPopupFrame then
		GB_ICON_FILENAMES = CopyTable(LMIS.GB_ORIGINAL)
	end
end

function LMIS:UpdateSearchPopup(info)
	local popup = info.popup
	popup.selectedIcon = nil
	info.sf:SetVerticalScroll(0)
	if popup == GuildBankPopupFrame then
		self.frameInfo[popup].update(popup)
	else
		local text = info.editbox:GetText()
		_G[info.update]()
		info.editbox:SetText(text) -- updating clears the EditBox; remember the macro name
	end
	if popup == GearManagerDialogPopup and #self.searchIcons > 0 then
		self:UpdateButtons(info, #self.searchIcons)
	end
	self:RefreshMouseFocus()
	-- the Blizzard UI remembers the ScrollFrame offset id instead
	-- of the previously selected icon when starting a new search
	if popup == MacroPopupFrame then
		MacroFrameSelectedMacroButtonIcon:SetTexture("Interface\\Icons\\INV_MISC_QUESTIONMARK")
	end
end

function LMIS.SearchBox_OnTextChanged(sb, userInput)
	local info = sb.info
	local text = sb:GetText()
	if strfind(text, "[:=]") then -- search by spell/item/achievement id
		local link, id = text:lower():match("(%a+)[:=](%d+)")
		local linkSearch
		LMIS:ClearSearch(info)
		if link == "spell" and id then
			linkSearch = S.FileData[select(3, GetSpellInfo(id))]
		elseif link == "item" and id then
			linkSearch = S.FileData[select(5, GetItemInfoInstant(id))]
		elseif link == "achievement" and id then
			linkSearch = S.FileData[select(10, GetAchievementInfo(id))]
		elseif link == "filedata" and id then
			linkSearch = S.FileData[tonumber(id)]
		end
		if linkSearch then
			LMIS.activeSearch = info
			LMIS.searchIcons[1] = linkSearch
			sb:SetTextColor(1, 1, 1)
			sb.linkLabel:SetText(linkSearch)
			if info.popup == GuildBankPopupFrame then
				GB_ICON_FILENAMES = {linkSearch}
			end
		else
			LMIS.searchIcons[1] = "INV_MISC_QUESTIONMARK"
			sb:SetTextColor(1, 0, 0)
			sb.linkLabel:SetText()
		end
		LMIS:UpdateSearchPopup(info)
		_G[info.buttons.."1"]:Click()
	else
		sb:SetTextColor(1, 1, 1)
		sb.linkLabel:SetText()
		if #text > 0 then -- search by texture name
			LMIS.searchObject:SetSearchParameter(text)
			LMIS.activeSearch = info
		else
			LMIS:ClearSearch(info)
			LMIS:UpdateSearchPopup(info)
		end
	end
end
