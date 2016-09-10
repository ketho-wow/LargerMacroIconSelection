local _, S = ...

local L = {
	enUS = {
		CURRENT_VALUES = "Current width is %d and current height is %d",
		SETTING_VALUES = "Setting macro icon selection width to %d and height to %d",
		USAGE = "Usage: /lmis width height",
		USAGE_VALUES = "Width must be 5 or larger, height must be 4 or larger",
	},
	deDE = {
		CURRENT_VALUES = "Aktuelle Breite ist: %d, aktuelle Höhe ist: %d",
		SETTING_VALUES = "Macrosymbol-Auswahlfenster ist nun %d Symbole breit und %d Symbole hoch",
		USAGE = "So geht's: /lmis Breite Höhe",
		USAGE_VALUES = "Breite muss mindestens 5, Höhe mindestens 4 sein",
	},
	esES = {
	},
	esMX = {
	},
	frFR = {
		CURRENT_VALUES = "La largeur actuelle est %d et la hauteur actuelle est %d.",
		SETTING_VALUES = "La sélection d'icône a maintenant une largeur de %d et un hauteur de %d.",
		USAGE = "Utilisation : /lmis largeur hauteur",
		USAGE_VALUES = "Largeur doit être 5 ou plus, hauteur doit être 4 ou plus.",
	},
	itIT = {
	},
	koKR = {
	},
	ptBR = {
	},
	ruRU = {
	},
	--zhCN = {},
	zhTW = {
		CURRENT_VALUES = "目前寬度是 %d 以及高度是 %d",
		SETTING_VALUES = "設置巨集圖標選擇寬度為%d及高度為%d",
		USAGE = "使用：/lmis 寬 高",
		USAGE_VALUES = "寬度必須等於或大於5，高度必須等於或大於4。",
	},
}

L.zhCN = L.zhTW

S.L = setmetatable(L[GetLocale()] or L.enUS, {__index = function(t, k)
	local v = rawget(L.enUS, k) or k
	rawset(t, k, v)
	return v
end})
