local _, S = ...
local L = S.L
LargerMacroIconSelection = CreateFrame("Frame")
local LMIS = LargerMacroIconSelection

local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local ICONS_PER_ROW, ICON_ROWS, ICONS_SHOWN
local origSize, origNum = {}, {}

-- remove custom/duplicate icons from icon packs
-- until Blizzard fixes their non-FileDataID icon support
GetLooseMacroItemIcons = function() end
GetLooseMacroIcons = function() end

local defaults = {
	width = 10,
	height = 10,
}

LMIS.frameInfo = {}
LMIS.frameData = {
	MacroPopupFrame = function() return {
			popup = MacroPopupFrame,
			sf = MacroPopupScrollFrame,
			editbox = MacroPopupEditBox,
			okaybutton = MacroPopupFrame.BorderBox.OkayButton,
			buttons = "MacroPopupButton",
			geticoninfo = "GetSpellorMacroIconInfo",
			update = "MacroPopupFrame_Update",
			icons_per_row = "NUM_ICONS_PER_ROW", -- 10
			icon_rows = "NUM_ICON_ROWS", -- 9
			icons_shown = "NUM_MACRO_ICONS_SHOWN", -- 90
			icon_row_height = MACRO_ICON_ROW_HEIGHT, -- 36
			template = "MacroPopupButtonTemplate",
		}
	end,
	GearManagerDialogPopup = function() return {
			popup = GearManagerDialogPopup,
			sf = GearManagerDialogPopupScrollFrame,
			editbox = GearManagerDialogPopupEditBox,
			okaybutton = GearManagerDialogPopupOkay,
			buttons = "GearManagerDialogPopupButton",
			geticoninfo = "GetEquipmentSetIconInfo",
			update = "GearManagerDialogPopup_Update",
			icons_per_row = "NUM_GEARSET_ICONS_PER_ROW", -- 10
			icon_rows = "NUM_GEARSET_ICON_ROWS", -- 9
			icons_shown = "NUM_GEARSET_ICONS_SHOWN", -- 90
			icon_row_height = GEARSET_ICON_ROW_HEIGHT, -- 36
			template = "GearSetPopupButtonTemplate",
		}
	end,
	GuildBankPopupFrame = function() return {
			popup = GuildBankPopupFrame,
			sf = GuildBankPopupFrame.ScrollFrame,
			editbox = GuildBankPopupEditBox,
			okaybutton = GuildBankPopupFrame.OkayButton,
			buttons = "GuildBankPopupButton",
			geticoninfo = "GetGuildBankIconInfo", -- custom
			update = GuildBankPopupFrame.Update,
			--icons_per_row = "NUM_GUILDBANK_ICONS_PER_ROW", -- 10
			--icon_rows = "NUM_GUILDBANK_ICON_ROWS", -- 9
			--icons_shown = "NUM_GUILDBANK_ICONS_SHOWN", -- 90
			--icon_row_height = GUILDBANK_ICON_ROW_HEIGHT, -- 36
			--template = "GuildBankPopupButtonTemplate",
		}
	end,
}

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
		S.FileData = isRetail and fd:GetFileDataRetail() or fd:GetFileDataClassic()
	end
end

function LMIS:OnEvent(event, addon)
	if addon == "LargerMacroIconSelection" then
		LargerMacroIconSelectionDB = LargerMacroIconSelectionDB or CopyTable(defaults)
		self.db = LargerMacroIconSelectionDB

		ICONS_PER_ROW = self.db.width
		ICON_ROWS = self.db.height
		ICONS_SHOWN = ICONS_PER_ROW * ICON_ROWS
		if isRetail then
			self:Initialize(GearManagerDialogPopup)
		end
		if IsAddOnLoaded("Blizzard_MacroUI") then -- someone else made it load before us
			self:Initialize(MacroPopupFrame)
		end
		if IsAddOnLoaded("Blizzard_GuildBankUI") then
			self:Initialize(GuildBankPopupFrame)
		end
	elseif addon == "Blizzard_MacroUI" then
		self:Initialize(MacroPopupFrame)
	-- guild leader and permitted ranks can change the guild bank tab icon
	-- too lazy to check for SetCurrentGuildBankTab / CanEditGuildBankTabInfo, so just initialize anyway
	-- 2.5.2 guild bank was rewritten, remove support for now
	elseif addon == "Blizzard_GuildBankUI" then
		self:Initialize(GuildBankPopupFrame)
	end
end

LMIS:RegisterEvent("ADDON_LOADED")
LMIS:SetScript("OnEvent", LMIS.OnEvent)

function LMIS:Initialize(popup)
	popup:HookScript("OnShow", function() -- Only initialize when the popupframe shows
		if self.frameInfo[popup] then
			return
		else
			self.frameInfo[popup] = self.frameData[popup:GetName()]()
		end
		local info = self.frameInfo[popup]
		self:LoadFileData("LargerMacroIconSelectionData")
		self:InitSearch()

		origSize[popup] = {
			width = popup:GetWidth(),
			height = popup:GetHeight(),
			sfwidth = info.sf:GetWidth(),
			sfheight = info.sf:GetHeight(),
		}
		origNum[popup] = {
			icons_per_row = _G[info.icons_per_row],
			icon_rows = _G[info.icon_rows],
			icons_shown =  _G[info.icons_shown],
		}
		-- movable
		popup:SetMovable(true)
		popup:SetClampedToScreen(true)
		popup:SetFrameStrata("HIGH") -- up from "Medium", GearManager was hidden behind stuff
		popup:EnableMouse(true) -- GearManager not mouse enabled
		popup:RegisterForDrag("LeftButton")
		popup:SetScript("OnDragStart", popup.StartMoving)
		popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
		info.sf:HookScript("OnMouseWheel", self.RefreshMouseFocus) -- update GameTooltip when scrollling

		local sb = CreateFrame("EditBox", "$parentSearchBox", popup, "InputBoxTemplate")
		sb:SetPoint("BOTTOMLEFT", 72, 15)
		sb:SetPoint("RIGHT", info.okaybutton, "LEFT", 0, 0)
		sb:SetHeight(15)
		sb:SetFrameLevel(70) -- FrameStrata or level changed in 7.1
		sb.info = info -- LMIS:InitSearch()
		popup.SearchBox = sb -- LMIS.SearchBox_OnTextChanged()
		-- no idea why fontstrings are drawn below the popup frame in 7.1
		-- using the OVERLAY layer didnt help; workaround by parenting to editbox instead
		sb.searchLabel = sb:CreateFontString()
		sb.searchLabel:SetFontObject("GameFontNormal")
		sb.searchLabel:SetPoint("RIGHT", sb, "LEFT", -6, 0)
		sb.searchLabel:SetText(SEARCH..":")
		sb.linkLabel = sb:CreateFontString()
		sb.linkLabel:SetFontObject("GameFontNormal")
		sb.linkLabel:SetPoint("RIGHT", info.okaybutton, "LEFT", -5, -1)
		sb.linkLabel:SetTextColor(.62, .62, .62)

		sb:SetScript("OnTextChanged", self.SearchBox_OnTextChanged)
		sb:SetScript("OnEnterPressed", function()
			info.editbox:SetFocus() -- in 7.1 :ClearFocus() on SearchBox does not work anymore(?)
		end)
		sb:SetScript("OnEscapePressed", function()
			info.editbox:SetFocus()
		end)
		popup:HookScript("OnHide", function()
			self:ClearSearch(info)
			sb:SetText("")
			sb:SetTextColor(1, 1, 1)
			sb.linkLabel:SetText()
		end)
 		-- update scrollbar for the filtered icons
		local isGuildBank = (popup == GuildBankPopupFrame)
		if not isGuildBank then
			hooksecurefunc(info.update, function()
				if #self.searchIcons > 0 then
					FauxScrollFrame_Update(info.sf, ceil(#self.searchIcons / ICONS_PER_ROW), ICON_ROWS, info.icon_row_height)
					if popup == GearManagerDialogPopup then -- gear manager update func shows the buttons again, hide them
						self:UpdateButtons(info, #self.searchIcons)
					end
				end
			end)
		end
		-- prehook for search functionality
		local oldGetIconInfo = _G[info.geticoninfo]
		_G[info.geticoninfo] = function(index)
			if #self.searchIcons > 0 then
				-- gear manager does not cope well with nil values
				return self.searchIcons[index] or popup == GearManagerDialogPopup and "INV_MISC_QUESTIONMARK"
			else
				return oldGetIconInfo(index)
			end
		end
		-- support shift-clicking links to the search box
		-- maybe also hide StackSplitFrame but will have to hook ContainerFrameItemButton_OnModifiedClick
		hooksecurefunc("ChatEdit_InsertLink", function(text)
			if text and sb:IsVisible() then
				sb:SetText(strmatch(text, "H(%l+:%d+)") or "")
			end
		end)
		if isGuildBank then
			self:InitGuildBank(info)
			info.update(popup)
		else
			self:UpdateButtons(info)
			self:UpdateTextures(info)
			_G[info.update]()
		end
	end)
end

function LMIS:UpdateButtons(info, amount)
	local popup = info.popup
	local buttons = info.buttons
	-- set the frame specific globals to the new values
	_G[info.icons_per_row] = ICONS_PER_ROW
	_G[info.icon_rows] = ICON_ROWS
	_G[info.icons_shown] = ICONS_SHOWN
	-- the GearManager does not like nil values
	-- so we have to manually hide the buttons for them, at least when we show just a few icons
	local numIcons = amount and min(amount, ICONS_SHOWN) or ICONS_SHOWN
	local isGearManager = (popup == GearManagerDialogPopup)
	for i = 1, numIcons do
		local b = _G[buttons..i]
		if not b then -- Create button
			b = CreateFrame("CheckButton", buttons..i, popup, info.template)
			b:SetID(i) -- Assign corresponding Id
			if isGearManager then
				tinsert(popup.buttons, b)
			end
		end
		-- position buttons
		if i > 1 then
			b:ClearAllPoints()
			if i % ICONS_PER_ROW == 1 then
				b:SetPoint("TOPLEFT", _G[buttons..(i-ICONS_PER_ROW)], "BOTTOMLEFT", 0, -8)
			else
				b:SetPoint("LEFT", _G[buttons..i-1], "RIGHT", 10, 0)
			end
		end
		-- show icon information
		b:SetScript("OnEnter", function(_self)
			GameTooltip:SetOwner(_self, "ANCHOR_TOPLEFT")
			local id = FauxScrollFrame_GetOffset(info.sf)*ICONS_PER_ROW + _self:GetID()
			local texture = _G[info.geticoninfo](id)
			GameTooltip:AddLine(format("%s |cff71D5FF%s|r", id, texture))
			GameTooltip:AddLine(type(texture) == "number" and S.FileData[texture] or texture, 1, 1, 1)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function(_self)
			GameTooltip:Hide()
		end)
	end
	-- hide any superfluous buttons
	local i = numIcons + 1
	while _G[buttons..i] do
		_G[buttons..i]:Hide()
		i = i + 1
	end
end

-- in 7.1 Blizzard shows 90 icons, with 9th row half visible
-- and an extra empty row as the very last row to make up for it
function LMIS:UpdateTextures(info)
	local popup = info.popup
	-- calculate the extra width and height due to the new size
	local extrawidth = (_G[info.buttons.."1"]:GetWidth() + 10) * (ICONS_PER_ROW - origNum[popup].icons_per_row)
	local extraheight = (_G[info.buttons.."1"]:GetHeight() + 8) * (ICON_ROWS - origNum[popup].icon_rows) + 30
	-- resize the frames
	local size = origSize[popup]
	popup:SetWidth(size.width + extrawidth)
	popup:SetHeight(size.height + extraheight)
	info.sf:SetWidth(size.sfwidth + extrawidth)
	info.sf:SetHeight(size.sfheight + extraheight)
end

function LMIS.RefreshMouseFocus(_self)
	local focus = GetMouseFocus()
	if focus and focus:GetObjectType() == "CheckButton" then
		local parent = focus:GetParent()
		if parent and LMIS.frameInfo[parent] then
			focus:GetScript("OnEnter")(focus)
		end
	end
end

for i, v in pairs({"lmis", "largermacro", "largermacroicon", "largermacroiconselection"}) do
	_G["SLASH_LARGERMACROICONSELECTION"..i] = "/"..v
end

SlashCmdList.LARGERMACROICONSELECTION = function(msg)
	local width, height = strmatch(msg, "(%d+)[^%d]+(%d+)")
	width = tonumber(width) or 10
	height = tonumber(height) or 10
	if width >= 5 and height >= 4 then
		-- avoid outgrowing the screen (1920x1080, normal UI Scale)
		width = min(width, 40)
		height = min(height, 21)
		LMIS.db.width = width
		LMIS.db.height = height
		print(L.SETTING_VALUES:format(width, height))

		ICONS_PER_ROW = width
		ICON_ROWS = height
		ICONS_SHOWN = ICONS_PER_ROW * ICON_ROWS
		for frame, info in pairs(LMIS.frameInfo) do
			LMIS:UpdateButtons(info)
			LMIS:UpdateTextures(info)
			if frame:IsShown() then
				_G[info.update]()
			end
		end
	else
		local version = GetAddOnMetadata("LargerMacroIconSelection", "Version")
		print( format("%s |cffADFF2F%s|r", "LargerMacroIconSelection", version) )
		print(L.USAGE)
		print(L.USAGE_VALUES)
		print(L.CURRENT_VALUES:format(LMIS.db.width, LMIS.db.height))
	end
end
