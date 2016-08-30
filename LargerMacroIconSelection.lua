--[[
LargerMacroIconSelection
Copyright (C) 2016 Xinhuan, Ketho

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local LMIS = CreateFrame("Frame", "LargerMacroIconSelection")
local LibAIS = LibStub("LibAdvancedIconSelector-1.0-LMIS")

local NAME, S = ...
local L = S.L
local db

local ICONS_PER_ROW, ICON_ROWS, ICONS_SHOWN
local previousbuttons = 0

local popup_regions, sf_regions = {}, {}
local origSize, origNum = {}, {}
local activeFrame = {}

local searchObject, activeSearch
local searchIcons = {}

local GB_ICON_FILENAMES

-- Put this in global namespace for consistency/simplicity
function GetGuildBankIconInfo(index)
	return GB_ICON_FILENAMES[index]
end

-- Remove custom/duplicate icons from icon packs
--  until Blizzard fixes their non-FileDataID icon support
GetLooseMacroItemIcons = function() end
GetLooseMacroIcons = function() end

local defaults = {
	width = 10,
	height = 10,
}

local LibAIS_options = {
	sectionOrder = {"FileDataIcons"},
}

-- Sometimes we need the variable name instead of value/pointer
local frames = {
	MacroPopupScrollFrame = function() return {
			icons_per_row = "NUM_ICONS_PER_ROW", -- 5
			icon_rows = "NUM_ICON_ROWS", -- 4
			icons_shown = "NUM_MACRO_ICONS_SHOWN", -- 20
			icon_row_height = MACRO_ICON_ROW_HEIGHT, -- 36
			geticoninfo = "GetSpellorMacroIconInfo",
			button = "MacroPopupButton",
			template = "MacroPopupButtonTemplate",
			update = "MacroPopupFrame_Update",
			okaybutton = MacroPopupOkayButton,
			extrawidth = -2,
		}
	end,
	GearManagerDialogPopupScrollFrame = function() return {
			icons_per_row = "NUM_GEARSET_ICONS_PER_ROW", -- 5
			icon_rows = "NUM_GEARSET_ICON_ROWS", -- 3
			icons_shown = "NUM_GEARSET_ICONS_SHOWN", -- 15
			icon_row_height = GEARSET_ICON_ROW_HEIGHT, -- 36
			geticoninfo = "GetEquipmentSetIconInfo",
			button = "GearManagerDialogPopupButton",
			template = "GearSetPopupButtonTemplate",
			update = "GearManagerDialogPopup_Update",
			okaybutton = GearManagerDialogPopupOkay,
			extrawidth = -2,
			topcoords = 212/256, -- Different TexCoord
		}
	end,
	GuildBankPopupScrollFrame = function() return {
			icons_per_row = "NUM_GUILDBANK_ICONS_PER_ROW", -- 4
			icon_rows = "NUM_GUILDBANK_ICON_ROWS", -- 4
			icons_shown = "NUM_GUILDBANK_ICONS_SHOWN", -- 16
			icon_row_height = GUILDBANK_ICON_ROW_HEIGHT, -- 36
			geticoninfo = "GetGuildBankIconInfo", -- custom
			button = "GuildBankPopupButton",
			template = "GuildBankPopupButtonTemplate",
			update = "GuildBankPopupFrame_Update",
			okaybutton = GuildBankPopupOkayButton,
			extrawidth = 8,
		}
	end,
}

-- Save memory by only loading FileData when needed
local function LoadFileData()
	if not S.FileData then
		local addon = "LargerMacroIconSelectionData"
		local loaded, reason = LoadAddOn(addon)
		
		if not loaded then
			if reason == "DISABLED" then
				EnableAddOn(addon, true)
				LoadAddOn(addon)
			else
				error(addon.." is "..reason)
			end
		end
		S.FileData = LargerMacroIconSelectionData:GetFileData()
	end
end

local function RefreshMouseFocus()
	local focus = GetMouseFocus()
	if focus and focus:GetObjectType() == "CheckButton" then
		local parent = focus:GetParent()
		-- Make sure we have the right buttons
		if parent and frames[parent.ScrollFrame] then
			focus:GetScript("OnEnter")(focus)
		end
	end
end

local function UpdateSearchPopup(sf)
	sf:GetParent().selectedIcon = nil
	sf:SetVerticalScroll(0)	
	_G[frames[sf].update]()
	RefreshMouseFocus()
	-- The Blizzard UI remembers the ScrollFrame offset id instead
	--  of the previously selected icon when starting a new search
	-- Make this apparent by showing the question mark icon again
	if sf == MacroPopupScrollFrame then
		MacroFrameSelectedMacroButtonIcon:SetTexture("Interface\\Icons\\INV_MISC_QUESTIONMARK")
	end
end

local function InitSearch()
	if not searchObject then
		searchObject = LibAIS:CreateSearch(LibAIS_options)
		
		searchObject:SetScript("OnSearchStarted", function(self)
			wipe(searchIcons)
		end)
		
		searchObject:SetScript("OnSearchResultAdded", function(self, texture, _, _, _, FileDataID)
			tinsert(searchIcons, FileDataID)
		end)
		
		searchObject:SetScript("OnSearchComplete", function(self)
			if activeSearch then
				local popup = activeSearch:GetParent()
				if not popup:IsShown() then return end
				
				if #searchIcons == 0 then
					popup.SearchBox:SetTextColor(1, 0, 0)
				else
					popup.SearchBox:SetTextColor(1, 1, 1)
				end
				UpdateSearchPopup(activeSearch)
				activeSearch = nil
			end
		end)
	end
end

local function ClearSearch()
	activeSearch = nil
	wipe(searchIcons)
	searchObject:Stop()
end

local f = LMIS

function f:OnEvent(event, addon)
	if addon == NAME then
		LargerMacroIconSelectionDB = LargerMacroIconSelectionDB or CopyTable(defaults)
		db = LargerMacroIconSelectionDB
		
		ICONS_PER_ROW = db.width
		ICON_ROWS = db.height
		ICONS_SHOWN = ICONS_PER_ROW * ICON_ROWS
		
		self:Initialize(GearManagerDialogPopupScrollFrame)
		
		-- Someone else made it load before us
		if IsAddOnLoaded("Blizzard_MacroUI") then
			self:Initialize(MacroPopupScrollFrame)
		end
		
	elseif addon == "Blizzard_MacroUI" then
		self:Initialize(MacroPopupScrollFrame)
		
	elseif addon == "Blizzard_GuildBankUI" then
		if IsGuildLeader() then
			self:Initialize(GuildBankPopupScrollFrame)
		end
	end
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", f.OnEvent)

function f:Initialize(sf)
	local popup = sf:GetParent()
	popup.ScrollFrame = sf
	
	-- Only initialize when the popupframe shows
	popup:HookScript("OnShow", function()
		if activeFrame[sf] then return end
		
		LoadFileData()
		InitSearch()
		frames[sf] = frames[sf:GetName()]()
		
		-- Group the anonymous textures into a table before adding more regions
		popup_regions[sf] = {popup:GetRegions()}
		sf_regions[sf] = {sf:GetRegions()}
		
		origSize[sf] = {
			width = popup:GetWidth(),
			height = popup:GetHeight(),
			sfwidth = sf:GetWidth(),
			sfheight = sf:GetHeight(),
		}
		
		origNum[sf] = {
			icons_per_row = _G[frames[sf].icons_per_row],
			icon_rows = _G[frames[sf].icon_rows],
			icons_shown =  _G[frames[sf].icons_shown],
		}
		
		-- Create extra background textures
		for i = 1, 6 do
			popup["largertexture"..i] = popup:CreateTexture(nil, "BACKGROUND")
		end
		sf.largertexture1 = sf:CreateTexture(nil, "BACKGROUND") -- Scrollframe texture
		
		-- Movable
		popup:SetMovable(true)
		popup:SetClampedToScreen(true)
		popup:SetFrameStrata("HIGH") -- Up from "Medium", GearManager was hidden behind stuff
		
		popup:EnableMouse(true) -- GearManager not mouse enabled
		popup:RegisterForDrag("LeftButton")
		popup:SetScript("OnDragStart", popup.StartMoving)
		popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
		
		-- Update GameTooltip when scrollling
		sf:HookScript("OnMouseWheel", RefreshMouseFocus)
		
		if popup == GuildBankPopupFrame then
			-- Can not make the Guild Bank support icon search; at least support GameTooltip info
			-- Since the guild bank gets the icon info locally in the update func
			GB_ICON_FILENAMES = {}
			GB_ICON_FILENAMES[1] = "INV_MISC_QUESTIONMARK"
			
			GetLooseMacroItemIcons(GB_ICON_FILENAMES)
			GetLooseMacroIcons(GB_ICON_FILENAMES)
			GetMacroItemIcons(GB_ICON_FILENAMES)
			GetMacroIcons(GB_ICON_FILENAMES)
		else
			local searchLabel = popup:CreateFontString()
			searchLabel:SetFontObject("GameFontNormal")
			searchLabel:SetPoint("BOTTOMLEFT", 20, 18)
			searchLabel:SetText(SEARCH..":")
			
			local eb = CreateFrame("EditBox", "$parentEditBox", popup, "InputBoxTemplate")
			eb:SetPoint("LEFT", searchLabel, "RIGHT", 7, -1)
			eb:SetPoint("RIGHT", frames[sf].okaybutton, "LEFT", 0, 0)
			eb:SetHeight(15)
			popup.SearchBox = eb
			
			local linkLabel = popup:CreateFontString()
			linkLabel:SetFontObject("GameFontNormal")
			linkLabel:SetPoint("RIGHT", frames[sf].okaybutton, "LEFT", -5, 0)
			linkLabel:SetTextColor(1, 1, 1)
			
			eb:SetScript("OnTextChanged", function(self, userInput)
				if not userInput then return end
				
				local text = self:GetText()
				
				if strfind(text, "[:=]") then -- Search by spell/item/achievement id
					local link, id, id2 = text:lower():match("(%a+)[:=](%d+)")
					local linkSearch
					ClearSearch()
					
					if link == "spell" and id then
						linkSearch = S.FileData[select(3, GetSpellInfo(id))]
					elseif link == "item" and id then
						linkSearch = S.FileData[select(5, GetItemInfoInstant(id))]
					elseif link == "achievement" and id then
						-- Returns the texture path instead of FileDataID
						local path = select(10, GetAchievementInfo(id))
						linkSearch = path and path:lower():match("interface\\icons\\(.+)")
					elseif link == "filedata" and id then
						linkSearch = S.FileData[tonumber(id)]
					end
					
					if linkSearch then
						searchIcons[1] = linkSearch
						eb:SetTextColor(1, 1, 1)
						linkLabel:SetText(linkSearch)
					else
						searchIcons[1] = "INV_MISC_QUESTIONMARK"
						eb:SetTextColor(1, 0, 0)
						linkLabel:SetText()
					end
					UpdateSearchPopup(sf)
				else
					eb:SetTextColor(1, 1, 1)
					linkLabel:SetText()
					
					if #text > 0 then -- Search by texture name
						searchObject:SetSearchParameter(text)
						activeSearch = sf
					else
						ClearSearch()
						UpdateSearchPopup(sf)
					end
				end
			end)
			
			eb:SetScript("OnEnterPressed", function(self)
				self:ClearFocus()
			end)
			
			popup:HookScript("OnHide", function()
				ClearSearch()
				eb:SetText("")
				eb:SetTextColor(1, 1, 1)
				linkLabel:SetText()
			end)
			
			-- Update scrollbar for the filtered icons
			hooksecurefunc(frames[sf].update, function()
				if #searchIcons > 0 then
					FauxScrollFrame_Update(sf, ceil(#searchIcons / ICONS_PER_ROW), ICON_ROWS, frames[sf].icon_row_height)
				end
			end)
			
			local isGearManager = (popup == GearManagerDialogPopup)
			
			-- Prehook GetIconInfo for search functionality 
			local oldGetIconInfo = _G[frames[sf].geticoninfo]
			_G[frames[sf].geticoninfo] = function(index)
				if #searchIcons > 0 then
					-- GearManager does not cope well with nil values
					return searchIcons[index] or isGearManager and "INV_MISC_QUESTIONMARK"
				else
					return oldGetIconInfo(index)
				end
			end
		end
		
		self:UpdateButtons(sf)
		self:UpdateTextures(sf)
		-- Only initialized with OnShow, update again
		_G[frames[sf].update]()
		
		activeFrame[sf] = true
	end)
end

function f:UpdateButtons(sf)
	local popup = sf:GetParent()
	local button = frames[sf].button
	local template = frames[sf].template
	
	-- Set the frame specific globals to the new values
	_G[frames[sf].icons_per_row] = ICONS_PER_ROW
	_G[frames[sf].icon_rows] = ICON_ROWS
	_G[frames[sf].icons_shown] = ICONS_SHOWN
	
	local isGearManager = (popup == GearManagerDialogPopup)
	
	for i = 1, ICONS_SHOWN do
		local b = _G[button..i]
		
		if not b then -- Create button
			b = CreateFrame("CheckButton", button..i, popup, template)
			b:SetID(i) -- Assign corresponding Id
			
			if isGearManager then
				tinsert(popup.buttons, b)
			end
		end
		
		-- Position buttons
		if i > 1 then
			b:ClearAllPoints()
			if i % ICONS_PER_ROW == 1 then
				b:SetPoint("TOPLEFT", _G[button..(i-ICONS_PER_ROW)], "BOTTOMLEFT", 0, -8)
			else
				b:SetPoint("LEFT", _G[button..i-1], "RIGHT", 10, 0)
			end
		end
		
		-- Show icon information
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
			
			local id = FauxScrollFrame_GetOffset(sf)*ICONS_PER_ROW + self:GetID()
			GameTooltip:AddLine(id)
			
			local texture = _G[frames[sf].geticoninfo](id)
			GameTooltip:AddLine(type(texture) == "number" and S.FileData[texture] or texture, 1, 1, 1)
			GameTooltip:Show()
		end)
		
		b:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)
	end
	
	-- Hide any superfluous buttons
	for i = ICONS_SHOWN + 1, previousbuttons do
		local b = _G[button..i]
		if b then
			b:Hide()
		end
	end
end

function f:UpdateTextures(sf)	
	local popup = sf:GetParent()
	local button = frames[sf].button
	
	-- Calculate the extra width and height due to the new size
	local extrawidth = (_G[button.."1"]:GetWidth() + 10) * (ICONS_PER_ROW - origNum[sf].icons_per_row) + frames[sf].extrawidth
	local extraheight = (_G[button.."1"]:GetHeight() + 8) * (ICON_ROWS - origNum[sf].icon_rows) + 2
	
	-- Resize the frames
	local size = origSize[sf]
	popup:SetWidth(size.width + extrawidth)
	popup:SetHeight(size.height + extraheight)
	sf:SetWidth(size.sfwidth + extrawidth)
	sf:SetHeight(size.sfheight + extraheight)
	
	local isGuildBank = (popup == GuildBankPopupFrame)
	
	-- Reposition the unnamed textures, as well as init the extra ones to cover up the extra areas
	for _, child in ipairs(popup_regions[sf]) do
		if child.GetTexture then
			local texture = child:GetTexture()
			
			if texture == "Interface\\MacroFrame\\MacroPopup-TopLeft" then
				popup.largertexture1:SetTexture(texture)
				popup.largertexture1:SetTexCoord(0.5, 0.7, 0, frames[sf].topcoords or 1) 
				popup.largertexture1:SetWidth(extrawidth)
				popup.largertexture1:SetHeight(child:GetHeight())
				popup.largertexture1:ClearAllPoints()
				popup.largertexture1:SetPoint("TOPLEFT", child, "TOPRIGHT") -- top side

				popup.largertexture2:SetTexture(texture)
				popup.largertexture2:SetTexCoord(0, 1, 0.5, 0.7)
				popup.largertexture2:SetWidth(child:GetWidth())
				popup.largertexture2:SetHeight(extraheight)
				popup.largertexture2:ClearAllPoints()
				popup.largertexture2:SetPoint("TOPLEFT", child, "BOTTOMLEFT") -- left side

				popup.largertexture3:SetTexture(texture)
				popup.largertexture3:SetTexCoord(0.5, 0.7, 0.5, 0.7)
				popup.largertexture3:SetWidth(extrawidth)
				popup.largertexture3:SetHeight(extraheight)
				popup.largertexture3:ClearAllPoints()
				popup.largertexture3:SetPoint("TOPLEFT", child, "BOTTOMRIGHT") -- middle
				
			elseif texture == "Interface\\MacroFrame\\MacroPopup-TopRight" then
				if not isGuildBank then
					child:ClearAllPoints()
					child:SetPoint("TOPRIGHT", 23, 0)
				end
				
			elseif texture == "Interface\\MacroFrame\\MacroPopup-BotLeft" then
				if not isGuildBank then
					child:ClearAllPoints() -- Resize this one
					child:SetPoint("BOTTOMLEFT", 0, -21)
					child:SetWidth(256 * 0.1)
					child:SetTexCoord(0, 0.1, 0, 1)
				end

				popup.largertexture5:SetWidth(256 * 0.55)
				popup.largertexture6:ClearAllPoints()
				popup.largertexture6:SetPoint("BOTTOMLEFT", child, "BOTTOMRIGHT")
				
			elseif texture == "Interface\\MacroFrame\\MacroPopup-BotRight" then
				if not isGuildBank then
					child:ClearAllPoints()
					child:SetPoint("BOTTOMRIGHT", 23, -21)
				end

				popup.largertexture4:SetTexture("Interface\\MacroFrame\\MacroPopup-TopRight")
				popup.largertexture4:SetTexCoord(0, 1, 0.5, 0.7)
				popup.largertexture4:SetWidth(child:GetWidth())
				popup.largertexture4:SetHeight(extraheight)
				popup.largertexture4:ClearAllPoints()
				popup.largertexture4:SetPoint("BOTTOMRIGHT", child, "TOPRIGHT") -- right side

				popup.largertexture5:SetTexture("Interface\\MacroFrame\\MacroPopup-BotLeft")
				popup.largertexture5:SetTexCoord(0.45, 1, 0, 1)
				popup.largertexture5:SetHeight(child:GetHeight())
				popup.largertexture5:ClearAllPoints()
				popup.largertexture5:SetPoint("BOTTOMRIGHT", child, "BOTTOMLEFT") -- bottom side1

				popup.largertexture6:SetTexture("Interface\\MacroFrame\\MacroPopup-BotLeft")
				popup.largertexture6:SetTexCoord(0.1, 0.45, 0, 1)
				popup.largertexture6:SetPoint("BOTTOMRIGHT", popup.largertexture5, "BOTTOMLEFT") -- bottom side2
			end
		end
	end
	
	-- And some more for the scrollframe
	for _, child in ipairs(sf_regions[sf]) do
		if child.GetTexture then
			local a, b, c, d = child:GetTexCoord()
			if c - 0.0234375 < 0.01 then
				sf.largertexture1:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-ScrollBar")
				sf.largertexture1:SetTexCoord(0, 0.46875, 0.2, 0.9)
				sf.largertexture1:SetWidth(30)
				sf.largertexture1:SetHeight(extraheight)
				sf.largertexture1:SetPoint("TOPLEFT", child, "BOTTOMLEFT")
			end
		end
	end
end

for i, v in pairs({"lmis", "largermacro", "largermacroicon", "largermacroiconselection"}) do
	_G["SLASH_LARGERMACROICONSELECTION"..i] = "/"..v
end

SlashCmdList.LARGERMACROICONSELECTION = function(msg)
	local width, height = strmatch(msg, "(%d+)[^%d]+(%d+)")
	width = floor(tonumber(width) or 0)
	height = floor(tonumber(height) or 0)
	
	if width >= 5 and height >= 4 then
		-- Avoid outgrowing the screen (1920x1080, normal UI Scale)
		width = min(width, 40)
		height = min(height, 21)
		print(L.SETTING_VALUES:format(width, height))
		
		db.width = width
		db.height = height
		
		previousbuttons = ICONS_SHOWN or 0
		ICONS_PER_ROW = width
		ICON_ROWS = height
		ICONS_SHOWN = ICONS_PER_ROW * ICON_ROWS
		
		for k, v in pairs(frames) do
			if type(v) == "table" then
				f:UpdateButtons(k)
				f:UpdateTextures(k)
				if k:GetParent():IsShown() then
					_G[frames[k].update]()
				end
			end
		end
	else
		print( format("%s |cffADFF2F%s|r", NAME, GetAddOnMetadata(NAME, "Version")) )
		print(L.USAGE)
		print(L.USAGE_VALUES)
		print(L.CURRENT_VALUES:format(db.width, db.height))
	end
end
