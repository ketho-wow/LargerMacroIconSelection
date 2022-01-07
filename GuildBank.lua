local _, S = ...
local LMIS = LargerMacroIconSelection

local NUM_GUILDBANK_ICONS_PER_ROW = 10
local NUM_GUILDBANK_ICON_ROWS = 9

-- put this in global namespace for consistency/simplicity
function GetGuildBankIconInfo(index)
	return GB_ICON_FILENAMES[index]
end

function LMIS:InitGuildBank(info)
	self.GB_ORIGINAL = CopyTable(GB_ICON_FILENAMES)
	local buttons = info.buttons
	for i = 1, NUM_GUILDBANK_ICONS_PER_ROW * NUM_GUILDBANK_ICON_ROWS do
		local b = _G[buttons..i]
		b:SetScript("OnEnter", function(_self)
			GameTooltip:SetOwner(_self, "ANCHOR_TOPLEFT")
			local id = FauxScrollFrame_GetOffset(info.sf)*NUM_GUILDBANK_ICONS_PER_ROW + _self:GetID()
			local texture = _G[info.geticoninfo](id)
			GameTooltip:AddLine(format("%s |cff71D5FF%s|r", id, texture))
			GameTooltip:AddLine(type(texture) == "number" and S.FileData[texture] or texture, 1, 1, 1)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function(_self)
			GameTooltip:Hide()
		end)
	end
end
