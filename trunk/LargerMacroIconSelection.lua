--[[
LargerMacroIconSelection v1.0.7
5th July 2016
Copyright (C) 2016 Xinhuan

Shows you a much bigger macro icon selection frame instead of the
standard 5x4 one.

Slash commands:
/lmis width height

-----
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

-- Note: learned a lot from Expanded Macro Selection (EMS)
local NAME, S = ...
local L = S.L -- Localization
local db

local isLegion = (select(4, GetBuildInfo()) >= 70000)
local blp = isLegion and ".blp" or "" -- GetTexture() includes ".blp" in Legion

local defaults = {
	width = 10,
	height = 10,
}

-- Local constants
local ICONS_PER_ROW, ICON_ROWS, ICONS_SHOWN
local previousbuttons = 0

local popup_regions, sf_regions = {}, {}
local origSize, origNum = {}, {}
local active, pending = {}, {}

local frames = {
	MacroPopupScrollFrame = function() return {
			icons_per_row = "NUM_ICONS_PER_ROW", -- 5
			icon_rows = "NUM_ICON_ROWS", -- 4
			icons_shown = "NUM_MACRO_ICONS_SHOWN", -- 20
			button = "MacroPopupButton",
			template = "MacroPopupButtonTemplate",
			update = MacroPopupFrame_Update,
		}
	end,
	GearManagerDialogPopupScrollFrame = function() return {
			icons_per_row = "NUM_GEARSET_ICONS_PER_ROW", -- 5
			icon_rows = "NUM_GEARSET_ICON_ROWS", -- 3
			icons_shown = "NUM_GEARSET_ICONS_SHOWN", -- 15
			button = "GearManagerDialogPopupButton",
			template = "GearSetPopupButtonTemplate",
			update = GearManagerDialogPopup_Update,
			topcoords = 212/256, -- Different TexCoord
		}
	end,
	GuildBankPopupScrollFrame = function() return {
			icons_per_row = "NUM_GUILDBANK_ICONS_PER_ROW", -- 4
			icon_rows = "NUM_GUILDBANK_ICON_ROWS", -- 4
			icons_shown = "NUM_GUILDBANK_ICONS_SHOWN", -- 16
			button = "GuildBankPopupButton",
			template = "GuildBankPopupButtonTemplate",
			update = GuildBankPopupFrame_Update,
			extrawidth = 4, -- GuildBank is slightly thinner
		}
	end,
}

local f = CreateFrame("Frame")

function f:OnEvent(event, addon)
	if addon == NAME then
		LargerMacroIconSelectionDB = LargerMacroIconSelectionDB or CopyTable(defaults)
		db = LargerMacroIconSelectionDB
		
		ICONS_PER_ROW = db.width
		ICON_ROWS = db.height
		ICONS_SHOWN = ICONS_PER_ROW * ICON_ROWS
		
		self:SetHook(GearManagerDialogPopupScrollFrame)
		
		if IsAddOnLoaded("Blizzard_MacroUI") then -- Someone else made it load before us
			self:SetHook(MacroPopupScrollFrame)
		end
		
	elseif addon == "Blizzard_MacroUI" then
		self:SetHook(MacroPopupScrollFrame)
	elseif addon == "Blizzard_GuildBankUI" then
		if not IsGuildLeader() then return end -- No access to guild bank tabs
		self:SetHook(GuildBankPopupScrollFrame)
	end
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", f.OnEvent)

-- Cant get the textures yet because of the releaseUITextures cvar, hook OnShow
function f:SetHook(sf)
	local popup = sf:GetParent()
	
	popup:HookScript("OnShow", function()
		if pending[sf] then -- Size was changed
			self:UpdateTextures(sf) -- Textures available now
			pending[sf] = false
		elseif active[sf] then -- Nothing to change
			return
		else
			self:Initialize(sf)
			active[sf] = true
		end
	end)
end

function f:Initialize(sf)
	local popup = sf:GetParent()
	
	-- Get frame specific data
	frames[sf] = frames[sf:GetName()]()
	
	-- Group the anonymous textures into a table before adding more regions
	popup_regions[sf] = {popup:GetRegions()}
	sf_regions[sf] = {sf:GetRegions()}
	
	-- Get original dimensions
	origSize[sf] = {
		width = popup:GetWidth(),
		height = popup:GetHeight(),
		sfwidth = sf:GetWidth(),
		sfheight = sf:GetHeight(),
	}
	
	-- Get original amount of rows and columns
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
	
	-- Add buttons, move textures
	self:UpdateButtons(sf)
	self:UpdateTextures(sf)
	frames[sf].update() -- Initialized after OnShow, so not all icons are properly shown; force update
end

-- Initialization that should be called when the width/height values change
function f:UpdateButtons(sf)
	local popup = sf:GetParent()
	local button = frames[sf].button
	local template = frames[sf].template
	
	-- Set the frame specific globals to the new values
	local frame = frames[sf]
	_G[frame.icons_per_row] = ICONS_PER_ROW
	_G[frame.icon_rows] = ICON_ROWS
	_G[frame.icons_shown] = ICONS_SHOWN
	
	-- Add buttons
	for i = 2, ICONS_SHOWN do
		local b = _G[button..i]
		
		if not b then -- Create button
			b = CreateFrame("CheckButton", button..i, popup, template)
			b:SetID(i) -- Assign corresponding Id
			
			if popup == GearManagerDialogPopup then -- GearManager fix
				tinsert(GearManagerDialogPopup.buttons, b)
			end
		end
		
		b:ClearAllPoints()
		if i % ICONS_PER_ROW == 1 then
			b:SetPoint("TOPLEFT", _G[button..(i-ICONS_PER_ROW)], "BOTTOMLEFT", 0, -8)
		else
			b:SetPoint("LEFT", _G[button..i-1], "RIGHT", 10, 0)
		end
	end
	
	-- Hide any superfluous buttons
	for i = ICONS_SHOWN + 1, previousbuttons do
		local b = _G[button..i]
		if b then -- Sanity check
			b:Hide()
		end
	end
end

function f:UpdateTextures(sf)	
	local popup = sf:GetParent()
	local button = frames[sf].button
	
	-- Calculate the extra width and height due to the new size
	local extrawidth = (_G[button.."1"]:GetWidth() + 10) * (ICONS_PER_ROW - origNum[sf].icons_per_row) + (frames[sf].extrawidth or -6)
	local extraheight = (_G[button.."1"]:GetHeight() + 8) * (ICON_ROWS - origNum[sf].icon_rows) + 2
	
	-- Resize the frames
	local size = origSize[sf]
	popup:SetWidth(size.width + extrawidth)
	popup:SetHeight(size.height + extraheight)
	sf:SetWidth(size.sfwidth + extrawidth)
	sf:SetHeight(size.sfheight + extraheight)
	
	local isGuildBank = (popup == GuildBankPopupFrame) -- GuildBank fix
	
	-- Reposition the unnamed textures, as well as init
	-- the extra ones to cover up the extra areas
	for _, child in ipairs(popup_regions[sf]) do
		if child.GetTexture then
			local texture = child:GetTexture()
			
			if texture == "Interface\\MacroFrame\\MacroPopup-TopLeft"..blp then
				popup.largertexture1:SetTexture("Interface\\MacroFrame\\MacroPopup-TopLeft")
				popup.largertexture1:SetTexCoord(0.5, 0.7, 0, frames[sf].topcoords or 1) 
				popup.largertexture1:SetWidth(extrawidth)
				popup.largertexture1:SetHeight(child:GetHeight())
				popup.largertexture1:ClearAllPoints()
				popup.largertexture1:SetPoint("TOPLEFT", child, "TOPRIGHT") -- top side

				popup.largertexture2:SetTexture("Interface\\MacroFrame\\MacroPopup-TopLeft")
				popup.largertexture2:SetTexCoord(0, 1, 0.5, 0.7)
				popup.largertexture2:SetWidth(child:GetWidth())
				popup.largertexture2:SetHeight(extraheight)
				popup.largertexture2:ClearAllPoints()
				popup.largertexture2:SetPoint("TOPLEFT", child, "BOTTOMLEFT") -- left side

				popup.largertexture3:SetTexture("Interface\\MacroFrame\\MacroPopup-TopLeft")
				popup.largertexture3:SetTexCoord(0.5, 0.7, 0.5, 0.7)
				popup.largertexture3:SetWidth(extrawidth)
				popup.largertexture3:SetHeight(extraheight)
				popup.largertexture3:ClearAllPoints()
				popup.largertexture3:SetPoint("TOPLEFT", child, "BOTTOMRIGHT") -- middle
				
			elseif texture == "Interface\\MacroFrame\\MacroPopup-TopRight"..blp then
				if not isGuildBank then
					child:ClearAllPoints()
					child:SetPoint("TOPRIGHT", 23, 0)
				end
				
			elseif texture == "Interface\\MacroFrame\\MacroPopup-BotLeft"..blp then
				if not isGuildBank then
					child:ClearAllPoints() -- Resize this one
					child:SetPoint("BOTTOMLEFT", 0, -21)
					child:SetWidth(256 * 0.1)
					child:SetTexCoord(0, 0.1, 0, 1)
				end

				popup.largertexture5:SetWidth(256 * 0.55)
				popup.largertexture6:ClearAllPoints()
				popup.largertexture6:SetPoint("BOTTOMLEFT", child, "BOTTOMRIGHT")
				
			elseif texture == "Interface\\MacroFrame\\MacroPopup-BotRight"..blp then
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

-- Slash commands
for i, v in ipairs({"lmis", "largermacro", "largermacroiconselection"}) do
	_G["SLASH_LARGERMACROICONSELECTION"..i] = "/"..v
end

SlashCmdList.LARGERMACROICONSELECTION = function(msg)
	local width, height = strmatch(msg, "(%d+)[^%d]+(%d+)")
	width = floor(tonumber(width) or 0)
	height = floor(tonumber(height) or 0)
	
	if width >= 5 and height >= 4 then -- sanitize
		print(L.SETTING_VALUES:format(width, height))
		
		-- Update db
		db.width = width
		db.height = height
		
		-- Update upvalues
		previousbuttons = ICONS_SHOWN or 0 -- Remember last amount
		ICONS_PER_ROW = width
		ICON_ROWS = height
		ICONS_SHOWN = ICONS_PER_ROW * ICON_ROWS
		
		-- Update buttons
		for k in pairs(frames) do
			local sf = _G[k] -- Get the frames, the function types on the same table are skipped
			if sf and active[sf] then
				f:UpdateButtons(sf)
				
				if sf:IsVisible() then
					f:UpdateTextures(sf)
					frames[sf].update()
				else -- Cant get textures yet
					pending[sf] = true
				end
			end
		end
	else
		print(format("%s |cffADFF2Fv%s|r", NAME, GetAddOnMetadata(NAME, "Version")))
		print(L.USAGE)
		print(L.USAGE_VALUES)
		print(L.CURRENT_VALUES:format(db.width, db.height))
	end
end
