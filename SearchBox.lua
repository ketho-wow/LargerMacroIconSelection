local _, S = ...
local LMIS = LargerMacroIconSelection
local LibAIS = LibStub("LibAdvancedIconSelector-1.0-LMIS")

LMIS.searchIcons = {}
local LibAIS_options = {
	sectionOrder = {"FileDataIcons"},
}

function LMIS:CreateSearchBox(popup)
	local sb = CreateFrame("EditBox", "$parentSearchBox", popup, "InputBoxTemplate")
	sb:SetPoint("BOTTOMLEFT", 74, 15)
	sb:SetPoint("RIGHT", popup.BorderBox.OkayButton, "LEFT", 0, 0)
	sb:SetHeight(15)
	sb:SetFrameLevel(popup.BorderBox:GetFrameLevel()+1)
	sb.searchLabel = sb:CreateFontString()
	sb.searchLabel:SetPoint("RIGHT", sb, "LEFT", -8, 0)
	sb.searchLabel:SetFontObject("GameFontNormal")
	sb.searchLabel:SetText(SEARCH..":")
	sb.linkLabel = sb:CreateFontString()
	sb.linkLabel:SetPoint("RIGHT", popup.BorderBox.OkayButton, "LEFT", -5, -1)
	sb.linkLabel:SetFontObject("GameFontNormal")
	sb.linkLabel:SetTextColor(.62, .62, .62)
	sb:SetScript("OnTextChanged", self.SearchBox_OnTextChanged)
	sb:SetScript("OnEnterPressed", function()
		sb:ClearFocus()
	end)
	sb.spinner = CreateFrame("Frame", nil, sb, "LoadingSpinnerTemplate")
	sb.spinner:SetPoint("RIGHT", -4, -1)
	sb.spinner:SetSize(20, 20)
	sb.spinner:Hide()
	popup:HookScript("OnHide", function()
		self:ClearSearch(popup)
		sb:SetText("")
		sb:SetTextColor(1, 1, 1)
		sb.linkLabel:SetText()
	end)
	-- support shift-clicking links to the search box
	hooksecurefunc("ChatEdit_InsertLink", function(text)
		if text and sb:IsVisible() then
			sb:SetText(strmatch(text, "H(%l+:%d+)") or "")
			RunNextFrame(function() StackSplitFrame:Hide() end)
		end
	end)
	sb.popup = popup
	popup.SearchBox = sb
end

function LMIS:InitSearch()
	if not self.searchObject then
		self.searchObject = LibAIS:CreateSearch(LibAIS_options)
		self.searchObject:SetScript("OnSearchStarted", function()
			wipe(self.searchIcons)
			self.activeSearch.SearchBox.spinner:Show()
		end)
		self.searchObject:SetScript("OnSearchResultAdded", function(_self, texture, _, _, _, fdid)
			tinsert(self.searchIcons, fdid)
		end)
		self.searchObject:SetScript("OnSearchComplete", function()
			local popup = self.activeSearch
			if popup then
				if not popup:IsShown() then return end
				if #self.searchIcons == 0 then
					popup.SearchBox:SetTextColor(1, 0, 0)
				else
					popup.SearchBox:SetTextColor(1, 1, 1)
					self:SetSearchData(popup)
					self:UpdateSearchPopup(popup)
				end
				self.activeSearch = nil
				popup.SearchBox.spinner:Hide()
			end
		end)
	end
end

function LMIS:ClearSearch(popup)
	popup.SearchBox.spinner:Hide()
	self.activeSearch = nil
	wipe(self.searchIcons)
	self.searchObject:Stop()
end

function LMIS:SetSearchData(popup)
	wipe(popup.iconDataProvider.extraIcons)
	popup.iconDataProvider:SetIconData(LMIS.searchIcons)
end

function LMIS:UpdateSearchPopup(popup)
	local text = popup.BorderBox.IconSelectorEditBox:GetText()
	popup.Update(popup) -- updating clears the EditBox
	popup.BorderBox.IconSelectorEditBox:SetText(text)
end

function LMIS.SearchBox_OnTextChanged(sb, userInput)
	local popup = sb.popup
	local text = sb:GetText()
	local isNumber = tonumber(text)
	if isNumber or strfind(text, "[:=]") then -- search by spell/item/achievement id
		local link, id = text:lower():match("(%a+)[:=](%d+)")
		local linkSearch
		LMIS:ClearSearch(popup)
		if isNumber or link == "filedata" and id then
			linkSearch = S.FileData[isNumber or tonumber(id)]
		elseif link == "spell" and id then
			linkSearch = S.FileData[select(3, GetSpellInfo(id))]
		elseif link == "item" and id then
			linkSearch = S.FileData[select(5, GetItemInfoInstant(id))]
		elseif link == "achievement" and id then
			linkSearch = S.FileData[select(10, GetAchievementInfo(id))]
		end
		if linkSearch then
			LMIS.activeSearch = popup
			LMIS.searchIcons[1] = linkSearch
			sb:SetTextColor(1, 1, 1)
			sb.linkLabel:SetText(linkSearch)
			LMIS:SetSearchData(popup)
			LMIS:UpdateSearchPopup(popup)
		else
			LMIS.searchIcons[1] = "INV_MISC_QUESTIONMARK"
			sb:SetTextColor(1, 0, 0)
			sb.linkLabel:SetText()
		end
	else
		sb:SetTextColor(1, 1, 1)
		sb.linkLabel:SetText()
		if #text > 0 then -- search by texture name
			LMIS.searchObject:SetSearchParameter(text)
			LMIS.activeSearch = popup
		else
			LMIS:ClearSearch(popup)
			LMIS:UpdateSearchPopup(popup)
			LMIS:UpdateIconSelector(popup)
		end
	end
end
