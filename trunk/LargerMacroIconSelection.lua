--[[
Copyright LargerMacroIconSelection by Xinhuan
Modified by Ketho

-- License
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

-- Note: compared with Expanded Macro Selection (EMS) they are doing it much simpler :S
local NAME, S = ...
local L = S.L
local db

-- Fix WoD too, even though the TOC is for Legion
local tocversion = select(4, GetBuildInfo())
local isLegion = (tocversion == 70000)
local SetFileDataTexture = isLegion and "SetTexture" or "SetToFileData"
local blp = isLegion and ".blp" or ""

local defaults = {
	width = 10,
	height = 10,
}

-- Local constants
local ICONS_PER_ROW, ICON_ROWS, ICONS_SHOWN
local ICON_FILENAMES = {}
local NUM_ICONS = {}
local previousbuttons = 0

local popup_regions, sf_regions = {}, {}
local origSize = {}

local active, pendingChange = {}, {}

local function RefreshGuildBankIconInfo()
	ICON_FILENAMES[1] = "INV_MISC_QUESTIONMARK"
	
	GetLooseMacroItemIcons(ICON_FILENAMES)
	GetLooseMacroIcons(ICON_FILENAMES)
	GetMacroItemIcons(ICON_FILENAMES) -- Counted 12528 icons on 7.0.3.22124
	GetMacroIcons(ICON_FILENAMES) -- Counted 2121 icons
end

-- GB_ICON_FILENAMES is not accessible
local function GetGuildBankIconInfo(index)
	return ICON_FILENAMES[index]
end

-- There are still some differences between the 3 of them though
local frames = {
	MacroPopupScrollFrame = function() return {
			icons_per_row = NUM_ICONS_PER_ROW, -- 5
			icon_rows = NUM_ICON_ROWS, -- 4
			icons_shown = NUM_MACRO_ICONS_SHOWN, -- 20
			icon_row_height = MACRO_ICON_ROW_HEIGHT, -- 36
			geticoninfo = GetSpellorMacroIconInfo,
			button = "MacroPopupButton",
			buttontemplate = "MacroPopupButtonTemplate",
		}
	end,
	GearManagerDialogPopupScrollFrame = function() return {
			icons_per_row = NUM_GEARSET_ICONS_PER_ROW, -- 5
			icon_rows = NUM_GEARSET_ICON_ROWS, -- 3
			icons_shown = NUM_GEARSET_ICONS_SHOWN, -- 15
			icon_row_height = GEARSET_ICON_ROW_HEIGHT, -- 36
			geticoninfo = GetEquipmentSetIconInfo,
			button = "GearManagerDialogPopupButton",
			buttontemplate = "GearSetPopupButtonTemplate",
			topcoords = 212/256, -- different TexCoord
		}
	end,
	GuildBankPopupScrollFrame = function() return {
			icons_per_row = NUM_GUILDBANK_ICONS_PER_ROW, -- 4
			icon_rows = NUM_GUILDBANK_ICON_ROWS, -- 4
			icons_shown = NUM_GUILDBANK_ICONS_SHOWN, -- 16
			icon_row_height = GUILDBANK_ICON_ROW_HEIGHT, -- 36
			geticoninfo = GetGuildBankIconInfo, -- custom
			button = "GuildBankPopupButton",
			buttontemplate = "GuildBankPopupButtonTemplate",
		}
	end,
}

-- Lets not account for multiple popups being shown at the same time
local function GetActiveScrollFrame()
	for k in pairs(frames) do
		local sf = _G[k]
		if sf and sf:IsVisible() then
			return sf
		end
	end
end

local f = CreateFrame("Frame")

function f:OnEvent(event, addon)
	if addon == NAME then
		LargerMacroIconSelectionDB = LargerMacroIconSelectionDB or CopyTable(defaults)
		db = LargerMacroIconSelectionDB
		
		ICONS_PER_ROW = db.width
		ICON_ROWS = db.height
		ICONS_SHOWN = ICONS_PER_ROW * ICON_ROWS
		
		-- Get numItems through hooking, since MACRO_ICON_FILENAMES and the like are not accessible
		-- luckily for GearManagerDialogPopupScrollFrame and MacroPopupScrollFrame, they fire twice before f:PopupFrame_Update()
		hooksecurefunc("FauxScrollFrame_Update", function(frame, numItems)
			NUM_ICONS[frame] = numItems
		end)
		
		self:SetHook(GearManagerDialogPopupScrollFrame, "GearManagerDialogPopup_Update")
		
		-- Known bug, RecalculateGearManagerDialogPopup needs to be updated/hooked or equipment manager scrolls to an empty spot
		-- when pressing the EditButton, but for that we also need EM_ICON_FILENAMES and RefreshEquipmentSetIconInfo(), its too much trouble
		--hooksecurefunc("RecalculateGearManagerDialogPopup", f.RecalculateGearManagerDialogPopup)
		
	elseif addon == "Blizzard_MacroUI" then
		self:SetHook(MacroPopupScrollFrame, "MacroPopupFrame_Update")
		
	elseif addon == "Blizzard_GuildBankUI" then
		if not IsGuildLeader() then return end -- No access to guild bank icons
		RefreshGuildBankIconInfo() -- Prepare Guild Bank icon info
		self:SetHook(GuildBankPopupScrollFrame, "GuildBankPopupFrame_Update")
	end
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", f.OnEvent)

-- Cant get the textures yet because of the releaseUITextures cvar, hook OnShow
function f:SetHook(sf, hook)
	local popup = sf:GetParent()
	
	popup:HookScript("OnShow", function()
		if pendingChange[sf] then -- Popup window already initialized, but size was changed
			self:InitTextures(sf) -- Textures available now
			self:PopupFrame_Update(sf)
			pendingChange[sf] = false
		elseif active[sf] then -- Nothing to change
			return
		else
			self:InitOnce(sf, hook)
			active[sf] = true
		end
	end)
end

function f:InitOnce(sf, hook)
	-- Get the anonymous textures into a table before adding more regions
	local popup = sf:GetParent()
	popup_regions[popup] = {popup:GetRegions()}
	sf_regions[popup] = {sf:GetRegions()}
	
	origSize[popup] = {
		width = popup:GetWidth(),
		height = popup:GetHeight(),
		sfwidth = sf:GetWidth(),
		sfheight = sf:GetHeight(),
	}
	
	frames[sf] = frames[sf:GetName()]() -- Get popup specific information
	
	for i = 1, 6 do	-- Create extra background textures
		popup["largertexture"..i] = popup:CreateTexture(nil, "BACKGROUND")
	end
	sf.largertexture1 = sf:CreateTexture(nil, "BACKGROUND") -- Scrollframe textures
	
	self:InitButtons(sf) -- Setup buttons
	self:InitTextures(sf) -- Setup popup window
	self:PopupFrame_Update(sf) -- Initial update
	
	hooksecurefunc(hook, f.PopupFrame_Update) -- Further updates
end

-- Initialization that should be called when the width/height values change
function f:InitButtons(sf)
	local popup = sf:GetParent()
	local button = frames[sf].button
	local template = frames[sf].buttontemplate
	
	-- Create the extra buttons
	for i = 16, ICONS_SHOWN do -- 15 is the minimum for the GearManager
		local a = button..i
		if not _G[a] then
			CreateFrame("CheckButton", a, popup, template)
		end
	end
	
	-- Reposition all the buttons except the first one
	for i = 2, ICONS_SHOWN do
		local a = _G[button..i]
		a:ClearAllPoints()
		if i % ICONS_PER_ROW == 1 then
			a:SetPoint("TOPLEFT", _G[button..(i-ICONS_PER_ROW)], "BOTTOMLEFT", 0, -8)
		else
			a:SetPoint("LEFT", _G[button..i-1], "RIGHT", 10, 0)
		end
		a:Show()
	end
	
	-- Hide any leftover buttons after a decrease
	for i = ICONS_SHOWN + 1, previousbuttons do
		_G[button..i]:Hide()
	end
end

function f:InitTextures(sf)	
	local popup = sf:GetParent()
	local button = frames[sf].button
	
	-- Calculate the extra width and height due to the new size
	local extrawidth = (_G[button.."1"]:GetWidth() + 10) * (ICONS_PER_ROW - frames[sf].icons_per_row) + 1
	local extraheight = (_G[button.."1"]:GetHeight() + 8) * (ICON_ROWS - frames[sf].icon_rows) + 1
	
	-- Resize the frames
	local size = origSize[popup]
	popup:SetWidth(size.width + extrawidth)
	popup:SetHeight(size.height + extraheight)
	sf:SetWidth(size.sfwidth + extrawidth)
	sf:SetHeight(size.sfheight + extraheight)
	
	local isGuildBank = (sf == GuildBankPopupScrollFrame) -- bit hacky
	
	-- Reposition the unnamed textures, as well as init
	-- the extra ones to cover up the extra areas
	for _, child in ipairs(popup_regions[popup]) do
		if child.GetTexture then
			if child:GetTexture() == "Interface\\MacroFrame\\MacroPopup-TopLeft"..blp then -- Legion: .blp is included in path
				popup.largertexture1:SetTexture("Interface\\MacroFrame\\MacroPopup-TopLeft")
				popup.largertexture1:SetTexCoord(0.5, 0.7, 0, frames[sf].topcoords or 1) 
				popup.largertexture1:SetWidth(extrawidth)
				popup.largertexture1:SetHeight(child:GetHeight())
				popup.largertexture1:ClearAllPoints()
				popup.largertexture1:SetPoint("TOPLEFT", child, "TOPRIGHT")

				popup.largertexture2:SetTexture("Interface\\MacroFrame\\MacroPopup-TopLeft")
				popup.largertexture2:SetTexCoord(0, 1, 0.5, 0.7)
				popup.largertexture2:SetWidth(child:GetWidth())
				popup.largertexture2:SetHeight(extraheight)
				popup.largertexture2:SetPoint("TOPLEFT", child, "BOTTOMLEFT")

				popup.largertexture3:SetTexture("Interface\\MacroFrame\\MacroPopup-TopLeft")
				popup.largertexture3:SetTexCoord(0.5, 0.7, 0.5, 0.7)
				popup.largertexture3:SetWidth(extrawidth)
				popup.largertexture3:SetHeight(extraheight)
				popup.largertexture3:SetPoint("TOPLEFT", child, "BOTTOMRIGHT")
				
			elseif child:GetTexture() == "Interface\\MacroFrame\\MacroPopup-TopRight"..blp then
				if not isGuildBank then
					child:ClearAllPoints()
					child:SetPoint("TOPRIGHT", 23, 0)
				end
				
			elseif child:GetTexture() == "Interface\\MacroFrame\\MacroPopup-BotLeft"..blp then
				if not isGuildBank then
					-- Resize this one
					child:ClearAllPoints()
					child:SetPoint("BOTTOMLEFT", 0, -21)
					child:SetWidth(256 * 0.1)
					child:SetTexCoord(0, 0.1, 0, 1)
				end

				popup.largertexture5:SetWidth(256 * 0.55)
				popup.largertexture6:SetPoint("BOTTOMLEFT", child, "BOTTOMRIGHT")
				
			elseif child:GetTexture() == "Interface\\MacroFrame\\MacroPopup-BotRight"..blp then
				if not isGuildBank then
					child:ClearAllPoints()
					child:SetPoint("BOTTOMRIGHT", 23, -21)
				end

				popup.largertexture4:SetTexture("Interface\\MacroFrame\\MacroPopup-TopRight")
				popup.largertexture4:SetTexCoord(0, 1, 0.5, 0.7)
				popup.largertexture4:SetWidth(child:GetWidth())
				popup.largertexture4:SetHeight(extraheight)
				popup.largertexture4:SetPoint("BOTTOMRIGHT", child, "TOPRIGHT")

				popup.largertexture5:SetTexture("Interface\\MacroFrame\\MacroPopup-BotLeft")
				popup.largertexture5:SetTexCoord(0.45, 1, 0, 1)
				popup.largertexture5:SetHeight(child:GetHeight())
				popup.largertexture5:SetPoint("BOTTOMRIGHT", child, "BOTTOMLEFT")

				popup.largertexture6:SetTexture("Interface\\MacroFrame\\MacroPopup-BotLeft")
				popup.largertexture6:SetTexCoord(0.1, 0.45, 0, 1)
				popup.largertexture6:SetPoint("BOTTOMRIGHT", popup.largertexture5, "BOTTOMLEFT")
			end
		end
	end
	
	-- And some more for the scrollframe
	for _, child in ipairs(sf_regions[popup]) do
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

-- Hook the display of the macro icons to re-display to our size.
-- Most of this function is copied from the hooked update function, except
-- that it uses our local constants instead of the global ones, and it
-- has an extra popupButton:SetID() line.
function f:PopupFrame_Update(sf)
	-- GearManagerDialogPopup_Update: fires (but passes nothing) on clicking buttons/OnShow; passes GearManagerDialogPopupScrollFrame on scrolling
	-- MacroPopupFrame_Update: passes MacroPopupFrame on clicking buttons/OnShow; passes MacroPopupScrollFrame on scrolling
	-- GuildBankPopupFrame_Update: passes 1 on clicking buttons/OnShow; passes GuildBankPopupScrollFrame on scrolling
	if not sf or sf == MacroPopupFrame or sf == 1 then -- Seems to only pas nil when this addon is enabled and doing something
		sf = GetActiveScrollFrame()
	end
	
	local popup = sf:GetParent()
	local popupOffset = FauxScrollFrame_GetOffset(sf)
	local button = frames[sf].button
	local isGuildBank = (sf == GuildBankPopupScrollFrame)
	
	-- the posthook for GuildBankPopupScrollFrame() only fires after GuildBankPopupFrame_Update(), but luckily we can just use the standard ICON_FILENAMES
	-- otherwise multiply with the original icons_per_row to get the original amount of icons
	local numIcons = isGuildBank and #ICON_FILENAMES or NUM_ICONS[sf] * frames[sf].icons_per_row
	local GetIconInfo = frames[sf].geticoninfo
	
	for i = 1, ICONS_SHOWN do
		local popupButton = _G[button..i]
		local popupIcon = _G[button..i.."Icon"]
		
		local index = (popupOffset * ICONS_PER_ROW) + i
		local texture = GetIconInfo(index)
		
		if index <= numIcons and texture then
			if type(texture) == "number" then -- Legion / WoD FileDataIds
				popupIcon[SetFileDataTexture](popupIcon, texture)
				popupButton:Show()
			else -- WoD texture paths
				popupIcon:SetTexture("Interface\\ICONS\\"..texture)
				popupButton:Show()
			end
		else
			popupIcon:SetTexture("")
			popupButton:Hide()
		end
		
		if popup.selectedIcon and index == popup.selectedIcon then
			popupButton:SetChecked(1)
		elseif popup.selectedIconTexture == texture then
			popupButton:SetChecked(1)
		else
			popupButton:SetChecked(nil)
		end
		popupButton:SetID(i + (ICONS_PER_ROW - frames[sf].icons_per_row) * popupOffset) -- new line
	end
	
	FauxScrollFrame_Update(sf, ceil(numIcons / ICONS_PER_ROW), ICON_ROWS, frames[sf].icon_row_height)
end

-- Slash commands
for i, v in ipairs({"lmis", "largermacro", "largermacroiconselection"}) do
	_G["SLASH_LARGERMACROICONSELECTION"..i] = "/"..v
end

SlashCmdList.LARGERMACROICONSELECTION = function(msg, editbox)
	local width, height = strmatch(msg, "(%d+)[^%d]+(%d+)")
	width = floor(tonumber(width) or 0)
	height = floor(tonumber(height) or 0)
	
	if width >= 5 and height >= 4 then -- sanitize
		print(L.SETTING_VALUES:format(width, height))
		
		-- Update db
		db.width = width
		db.height = height
		
		-- Update upvalues
		previousbuttons = ICONS_SHOWN or 0 -- remember last amount
		ICONS_PER_ROW = width
		ICON_ROWS = height
		ICONS_SHOWN = ICONS_PER_ROW * ICON_ROWS
		
		-- Update buttons
		for k in pairs(frames) do
			local sf = _G[k] -- The functions types on the same table should be skipped
			if sf and active[sf] then -- Must wait for the initial posthook
				if sf:IsVisible() then
					f:InitButtons(sf)
					f:InitTextures(sf)
					f:PopupFrame_Update(sf)
				else -- Cant get textures if not visible, wait for OnShow
					f:InitButtons(sf) -- We can set up buttons first
					pendingChange[sf] = true
				end
			end
		end
	else
		print(format("%s |cffFFFF00v%s|r", NAME, GetAddOnMetadata(NAME, "Version")))
		print(L.USAGE)
		print(L.USAGE_VALUES)
		print(L.CURRENT_VALUES:format(db.width, db.height))
	end
end
