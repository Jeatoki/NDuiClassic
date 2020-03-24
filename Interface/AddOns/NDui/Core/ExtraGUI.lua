local _, ns = ...
local B, C, L, DB = unpack(ns)
local G = B:GetModule("GUI")

local function sortBars(barTable)
	local num = 1
	for _, bar in pairs(barTable) do
		if num == 1 then
			bar:SetPoint("TOPLEFT", 10, -10)
		else
			bar:SetPoint("TOPLEFT", 10, -10 - 35*(num-1))
		end
		num = num + 1
	end
end

local extraGUIs = {}
local function createExtraGUI(parent, name, title, bgFrame)
	local frame = CreateFrame("Frame", name, parent)
	frame:SetSize(300, 600)
	frame:SetPoint("TOPLEFT", parent:GetParent(), "TOPRIGHT", 3, 0)
	B.SetBackground(frame)
	parent:HookScript("OnHide", function()
		if frame:IsShown() then frame:Hide() end
	end)

	if title then
		B.CreateFS(frame, 14, title, "system", "TOPLEFT", 20, -25)
	end

	if bgFrame then
		frame.bg = CreateFrame("Frame", nil, frame)
		frame.bg:SetSize(280, 540)
		frame.bg:SetPoint("TOPLEFT", 10, -50)
		B.CreateBD(frame.bg, .3)
	end

	tinsert(extraGUIs, frame)
	return frame
end

local function toggleExtraGUI(name)
	for _, frame in next, extraGUIs do
		if frame:GetName() == name then
			ToggleFrame(frame)
		else
			frame:Hide()
		end
	end
end

local function clearEdit(options)
	for i = 1, #options do
		G:ClearEdit(options[i])
	end
end

local raidDebuffsGUI, clickCastGUI, buffIndicatorGUI, plateGUI, unitframeGUI, castbarGUI, raidframeGUI, bagFilterGUI

local function updateRaidDebuffs()
	B:GetModule("UnitFrames"):UpdateRaidDebuffs()
end

function G:SetupRaidDebuffs(parent)
	toggleExtraGUI("NDuiGUI_RaidDebuffs")
	if raidDebuffsGUI then return end

	raidDebuffsGUI = createExtraGUI(parent, "NDuiGUI_RaidDebuffs", L["RaidFrame Debuffs"].."*", true)
	raidDebuffsGUI:SetScript("OnHide", updateRaidDebuffs)

	local setupBars
	local frame = raidDebuffsGUI.bg
	local bars, options = {}, {}

	local iType = G:CreateDropdown(frame, L["Type*"], 10, -30, {RAID, OTHER}, L["Instance Type"], 150, 30)
	for i = 1, 2 do
		iType.options[i]:HookScript("OnClick", function()
			for k = 1, #bars do
				bars[k]:Hide()
			end
		end)
	end

	local typeIndex = {
		[RAID] = "raid",
		[OTHER] = "other",
	}

	options[1] = G:CreateEditbox(frame, "ID*", 10, -90, L["ID Intro"])
	options[2] = G:CreateEditbox(frame, L["Priority"], 120, -90, L["Priority Intro"])

	local function analyzePrio(priority)
		priority = priority or 2
		priority = min(priority, 6)
		priority = max(priority, 1)
		return priority
	end

	local function isAuraExisted(instType, spellID)
		local localPrio = C.RaidDebuffs[instType][spellID]
		local savedPrio = NDuiADB["RaidDebuffs"][instType] and NDuiADB["RaidDebuffs"][instType][spellID]
		if (localPrio and savedPrio and savedPrio == 0) or (not localPrio and not savedPrio) then
			return false
		end
		return true
	end

	local function addClick(options)
		local instType, spellID, priority = iType.Text:GetText(), tonumber(options[1]:GetText()), tonumber(options[2]:GetText())
		instType = typeIndex[instType]
		if not instType or not spellID then UIErrorsFrame:AddMessage(DB.InfoColor..L["Incomplete Input"]) return end
		if spellID and not GetSpellInfo(spellID) then UIErrorsFrame:AddMessage(DB.InfoColor..L["Incorrect SpellID"]) return end
		if isAuraExisted(instType, spellID) then UIErrorsFrame:AddMessage(DB.InfoColor..L["Existing ID"]) return end

		priority = analyzePrio(priority)
		if not NDuiADB["RaidDebuffs"][instType] then NDuiADB["RaidDebuffs"][instType] = {} end
		NDuiADB["RaidDebuffs"][instType][spellID] = priority
		setupBars(instType)
		G:ClearEdit(options[1])
		G:ClearEdit(options[2])
	end

	local scroll = G:CreateScroll(frame, 240, 350)
	scroll.reset = B.CreateButton(frame, 70, 25, RESET)
	scroll.reset:SetPoint("TOPLEFT", 10, -140)
	StaticPopupDialogs["RESET_NDUI_RAIDDEBUFFS"] = {
		text = L["Reset your raiddebuffs list?"],
		button1 = YES,
		button2 = NO,
		OnAccept = function()
			NDuiADB["RaidDebuffs"] = {}
			ReloadUI()
		end,
		whileDead = 1,
	}
	scroll.reset:SetScript("OnClick", function()
		StaticPopup_Show("RESET_NDUI_RAIDDEBUFFS")
	end)
	scroll.add = B.CreateButton(frame, 70, 25, ADD)
	scroll.add:SetPoint("TOPRIGHT", -10, -140)
	scroll.add:SetScript("OnClick", function()
		addClick(options)
	end)
	scroll.clear = B.CreateButton(frame, 70, 25, KEY_NUMLOCK_MAC)
	scroll.clear:SetPoint("RIGHT", scroll.add, "LEFT", -10, 0)
	scroll.clear:SetScript("OnClick", function()
		clearEdit(options)
	end)

	local function iconOnEnter(self)
		local spellID = self:GetParent().spellID
		if not spellID then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()
		GameTooltip:SetSpellByID(spellID)
		GameTooltip:Show()
	end

	local function createBar(index, texture)
		local bar = CreateFrame("Frame", nil, scroll.child)
		bar:SetSize(220, 30)
		B.CreateBD(bar, .3)
		bar.index = index

		local icon, close = G:CreateBarWidgets(bar, texture)
		icon:SetScript("OnEnter", iconOnEnter)
		icon:SetScript("OnLeave", B.HideTooltip)
		bar.icon = icon

		close:SetScript("OnClick", function()
			bar:Hide()
			if C.RaidDebuffs[bar.instType][bar.spellID] then
				if not NDuiADB["RaidDebuffs"][bar.instType] then NDuiADB["RaidDebuffs"][bar.instType] = {} end
				NDuiADB["RaidDebuffs"][bar.instType][bar.spellID] = 0
			else
				NDuiADB["RaidDebuffs"][bar.instType][bar.spellID] = nil
			end
			setupBars(bar.instType)
		end)

		local spellName = B.CreateFS(bar, 14, "", false, "LEFT", 30, 0)
		spellName:SetWidth(120)
		spellName:SetJustifyH("LEFT")
		bar.spellName = spellName

		local prioBox = B.CreateEditBox(bar, 30, 24)
		prioBox:SetPoint("RIGHT", close, "LEFT", -15, 0)
		prioBox:SetTextInsets(10, 0, 0, 0)
		prioBox:SetMaxLetters(1)
		prioBox:SetTextColor(0, 1, 0)
		prioBox:SetBackdropColor(1, 1, 1, .2)
		prioBox:HookScript("OnEscapePressed", function(self)
			self:SetText(bar.priority)
		end)
		prioBox:HookScript("OnEnterPressed", function(self)
			local prio = analyzePrio(tonumber(self:GetText()))
			if not NDuiADB["RaidDebuffs"][bar.instType] then NDuiADB["RaidDebuffs"][bar.instType] = {} end
			NDuiADB["RaidDebuffs"][bar.instType][bar.spellID] = prio
			self:SetText(prio)
		end)
		prioBox.title = L["Tips"]
		B.AddTooltip(prioBox, "ANCHOR_RIGHT", L["Prio Editbox"], "info")
		bar.prioBox = prioBox

		return bar
	end

	local function applyData(index, instType, spellID, priority)
		local name, _, texture = GetSpellInfo(spellID)
		if not bars[index] then
			bars[index] = createBar(index, texture)
		end
		bars[index].instType = instType
		bars[index].spellID = spellID
		bars[index].priority = priority
		bars[index].spellName:SetText(name)
		bars[index].prioBox:SetText(priority)
		bars[index].icon.Icon:SetTexture(texture)
		bars[index]:Show()
	end

	function setupBars(self)
		local instType = self
		if self.text then
			instType = typeIndex[self.text]
		end
		local index = 0

		for spellID, priority in pairs(C.RaidDebuffs[instType]) do
			if not (NDuiADB["RaidDebuffs"][instType] and NDuiADB["RaidDebuffs"][instType][spellID]) then
				index = index + 1
				applyData(index, instType, spellID, priority)
			end
		end

		if NDuiADB["RaidDebuffs"][instType] then
			for spellID, priority in pairs(NDuiADB["RaidDebuffs"][instType]) do
				if priority > 0 then
					index = index + 1
					applyData(index, instType, spellID, priority)
				end
			end
		end

		for i = 1, #bars do
			if i > index then
				bars[i]:Hide()
			end
		end

		for i = 1, index do
			if i == 1 then
				bars[i]:SetPoint("TOPLEFT", 10, -10)
			else
				bars[i]:SetPoint("TOPLEFT", bars[i-1], "BOTTOMLEFT", 0, -5)
			end
		end
	end

	for i = 1, 2 do
		iType.options[i]:HookScript("OnClick", setupBars)
	end
end

function G:SetupClickCast(parent)
	toggleExtraGUI("NDuiGUI_ClickCast")
	if clickCastGUI then return end

	clickCastGUI = createExtraGUI(parent, "NDuiGUI_ClickCast", L["Add ClickSets"], true)

	local textIndex, barTable = {
		["target"] = TARGET,
		["follow"] = FOLLOW,
	}, {}

	local function createBar(parent, data)
		local key, modKey, value = unpack(data)
		local clickSet = modKey..key
		local texture
		if tonumber(value) then
			texture = GetSpellTexture(value)
		else
			value = textIndex[value] or value
			texture = 136243
		end

		local bar = CreateFrame("Frame", nil, parent)
		bar:SetSize(220, 30)
		B.CreateBD(bar, .3)
		barTable[clickSet] = bar

		local icon, close = G:CreateBarWidgets(bar, texture)
		B.AddTooltip(icon, "ANCHOR_RIGHT", value, "system")
		close:SetScript("OnClick", function()
			bar:Hide()
			NDuiDB["RaidClickSets"][clickSet] = nil
			barTable[clickSet] = nil
			sortBars(barTable)
		end)

		local key1 = B.CreateFS(bar, 14, key, false, "LEFT", 35, 0)
		key1:SetTextColor(.6, .8, 1)
		modKey = modKey ~= "" and "+ "..modKey or ""
		local key2 = B.CreateFS(bar, 14, modKey, false, "LEFT", 130, 0)
		key2:SetTextColor(0, 1, 0)

		sortBars(barTable)
	end

	local frame = clickCastGUI.bg
	local keyList, options = {
		KEY_BUTTON1,
		KEY_BUTTON2,
		KEY_BUTTON3,
		KEY_BUTTON4,
		KEY_BUTTON5,
		L["WheelUp"],
		L["WheelDown"],
	}, {}

	options[1] = G:CreateEditbox(frame, L["Action*"], 10, -30, L["Action Intro"], 260, 30)
	options[2] = G:CreateDropdown(frame, L["Key*"], 10, -90, keyList, L["Key Intro"], 120, 30)
	options[3] = G:CreateDropdown(frame, L["Modified Key"], 170, -90, {NONE, "ALT", "CTRL", "SHIFT"}, L["ModKey Intro"], 85, 30)

	local scroll = G:CreateScroll(frame, 240, 350)
	scroll.reset = B.CreateButton(frame, 70, 25, RESET)
	scroll.reset:SetPoint("TOPLEFT", 10, -140)
	StaticPopupDialogs["RESET_NDUI_CLICKSETS"] = {
		text = L["Reset your click sets?"],
		button1 = YES,
		button2 = NO,
		OnAccept = function()
			NDuiDB["RaidClickSets"] = nil
			ReloadUI()
		end,
		whileDead = 1,
	}
	scroll.reset:SetScript("OnClick", function()
		StaticPopup_Show("RESET_NDUI_CLICKSETS")
	end)

	local function addClick(scroll, options)
		local value, key, modKey = options[1]:GetText(), options[2].Text:GetText(), options[3].Text:GetText()
		if not value or not key then UIErrorsFrame:AddMessage(DB.InfoColor..L["Incomplete Input"]) return end
		if tonumber(value) and not GetSpellInfo(value) then UIErrorsFrame:AddMessage(DB.InfoColor..L["Incorrect SpellID"]) return end
		if (not tonumber(value)) and value ~= "target" and value ~= "follow" and not value:match("/") then UIErrorsFrame:AddMessage(DB.InfoColor..L["Invalid Input"]) return end
		if not modKey or modKey == NONE then modKey = "" end
		local clickSet = modKey..key
		if NDuiDB["RaidClickSets"][clickSet] then UIErrorsFrame:AddMessage(DB.InfoColor..L["Existing ClickSet"]) return end

		NDuiDB["RaidClickSets"][clickSet] = {key, modKey, value}
		createBar(scroll.child, NDuiDB["RaidClickSets"][clickSet])
		clearEdit(options)
	end

	scroll.add = B.CreateButton(frame, 70, 25, ADD)
	scroll.add:SetPoint("TOPRIGHT", -10, -140)
	scroll.add:SetScript("OnClick", function()
		addClick(scroll, options)
	end)

	scroll.clear = B.CreateButton(frame, 70, 25, KEY_NUMLOCK_MAC)
	scroll.clear:SetPoint("RIGHT", scroll.add, "LEFT", -10, 0)
	scroll.clear:SetScript("OnClick", function()
		clearEdit(options)
	end)

	for _, v in pairs(NDuiDB["RaidClickSets"]) do
		createBar(scroll.child, v)
	end
end

function G:SetupNameplateFilter(parent)
	toggleExtraGUI("NDuiGUI_NameplateFilter")
	if plateGUI then return end

	plateGUI = createExtraGUI(parent, "NDuiGUI_NameplateFilter")

	local frameData = {
		[1] = {text = L["WhiteList"].."*", offset = -25, barList = {}},
		[2] = {text = L["BlackList"].."*", offset = -315, barList = {}},
	}

	local function createBar(parent, index, spellID)
		local name, _, texture = GetSpellInfo(spellID)
		local bar = CreateFrame("Frame", nil, parent)
		bar:SetSize(220, 30)
		B.CreateBD(bar, .3)
		frameData[index].barList[spellID] = bar

		local icon, close = G:CreateBarWidgets(bar, texture)
		B.AddTooltip(icon, "ANCHOR_RIGHT", spellID)
		close:SetScript("OnClick", function()
			bar:Hide()
			NDuiADB["NameplateFilter"][index][spellID] = nil
			frameData[index].barList[spellID] = nil
			sortBars(frameData[index].barList)
		end)

		local spellName = B.CreateFS(bar, 14, name, false, "LEFT", 30, 0)
		spellName:SetWidth(180)
		spellName:SetJustifyH("LEFT")
		if index == 2 then spellName:SetTextColor(1, 0, 0) end

		sortBars(frameData[index].barList)
	end

	local function addClick(parent, index)
		local spellID = tonumber(parent.box:GetText())
		if not spellID or not GetSpellInfo(spellID) then UIErrorsFrame:AddMessage(DB.InfoColor..L["Incorrect SpellID"]) return end
		if NDuiADB["NameplateFilter"][index][spellID] then UIErrorsFrame:AddMessage(DB.InfoColor..L["Existing ID"]) return end

		NDuiADB["NameplateFilter"][index][spellID] = true
		createBar(parent.child, index, spellID)
		parent.box:SetText("")
	end

	for index, value in ipairs(frameData) do
		B.CreateFS(plateGUI, 14, value.text, "system", "TOPLEFT", 20, value.offset)
		local frame = CreateFrame("Frame", nil, plateGUI)
		frame:SetSize(280, 250)
		frame:SetPoint("TOPLEFT", 10, value.offset - 25)
		B.CreateBD(frame, .3)

		local scroll = G:CreateScroll(frame, 240, 200)
		scroll.box = B.CreateEditBox(frame, 185, 25)
		scroll.box:SetPoint("TOPLEFT", 10, -10)
		scroll.add = B.CreateButton(frame, 70, 25, ADD)
		scroll.add:SetPoint("TOPRIGHT", -8, -10)
		scroll.add:SetScript("OnClick", function()
			addClick(scroll, index)
		end)

		for spellID in pairs(NDuiADB["NameplateFilter"][index]) do
			createBar(scroll.child, index, spellID)
		end
	end
end

local function refreshNameList()
	B:GetModule("AurasTable"):BuildNameListFromID()
end

function G:SetupBuffIndicator(parent)
	toggleExtraGUI("NDuiGUI_BuffIndicator")
	if buffIndicatorGUI then return end

	buffIndicatorGUI = createExtraGUI(parent, "NDuiGUI_BuffIndicator")
	buffIndicatorGUI:SetScript("OnHide", refreshNameList)

	local frameData = {
		[1] = {text = L["RaidBuffWatch"].."*", offset = -25, width = 160, barList = {}},
		[2] = {text = L["BuffIndicator"].."*", offset = -315, width = 50, barList = {}},
	}
	local decodeAnchor = {
		["TL"] = "TOPLEFT",
		["T"] = "TOP",
		["TR"] = "TOPRIGHT",
		["L"] = "LEFT",
		["R"] = "RIGHT",
		["BL"] = "BOTTOMLEFT",
		["B"] = "BOTTOM",
		["BR"] = "BOTTOMRIGHT",
	}
	local anchors = {"TL", "T", "TR", "L", "R", "BL", "B", "BR"}

	local function createBar(parent, index, spellID, anchor, r, g, b, showAll)
		local name, _, texture = GetSpellInfo(spellID)
		local bar = CreateFrame("Frame", nil, parent)
		bar:SetSize(220, 30)
		B.CreateBD(bar, .3)
		frameData[index].barList[spellID] = bar

		local icon, close = G:CreateBarWidgets(bar, texture)
		B.AddTooltip(icon, "ANCHOR_RIGHT", spellID)
		close:SetScript("OnClick", function()
			bar:Hide()
			if index == 1 then
				NDuiADB["RaidAuraWatch"][spellID] = nil
			else
				NDuiADB["CornerBuffs"][DB.MyClass][spellID] = nil
			end
			frameData[index].barList[spellID] = nil
			sortBars(frameData[index].barList)
		end)

		name = L[anchor] or name
		local text = B.CreateFS(bar, 14, name, false, "LEFT", 30, 0)
		text:SetWidth(180)
		text:SetJustifyH("LEFT")
		if anchor then text:SetTextColor(r, g, b) end
		if showAll then B.CreateFS(bar, 14, "ALL", false, "RIGHT", -30, 0) end

		sortBars(frameData[index].barList)
	end

	local function addClick(parent, index)
		local spellID = tonumber(parent.box:GetText())
		if not spellID or not GetSpellInfo(spellID) then UIErrorsFrame:AddMessage(DB.InfoColor..L["Incorrect SpellID"]) return end
		local anchor, r, g, b, showAll
		if index == 1 then
			if NDuiADB["RaidAuraWatch"][spellID] then UIErrorsFrame:AddMessage(DB.InfoColor..L["Existing ID"]) return end
			NDuiADB["RaidAuraWatch"][spellID] = true
		else
			anchor, r, g, b = parent.dd.Text:GetText(), parent.swatch.tex:GetVertexColor()
			showAll = parent.showAll:GetChecked() or nil
			if NDuiADB["CornerBuffs"][DB.MyClass][spellID] then UIErrorsFrame:AddMessage(DB.InfoColor..L["Existing ID"]) return end
			anchor = decodeAnchor[anchor]
			NDuiADB["CornerBuffs"][DB.MyClass][spellID] = {anchor, {r, g, b}, showAll}
		end
		createBar(parent.child, index, spellID, anchor, r, g, b, showAll)
		parent.box:SetText("")
	end

	local currentIndex
	StaticPopupDialogs["RESET_NDUI_RaidAuraWatch"] = {
		text = L["Reset your raiddebuffs list?"],
		button1 = YES,
		button2 = NO,
		OnAccept = function()
			if currentIndex == 1 then
				NDuiADB["RaidAuraWatch"] = nil
			else
				NDuiADB["CornerBuffs"][DB.MyClass] = nil
			end
			ReloadUI()
		end,
		whileDead = 1,
	}

	local function optionOnEnter(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(L[decodeAnchor[self.text]], 1, 1, 1)
		GameTooltip:Show()
	end

	for index, value in ipairs(frameData) do
		B.CreateFS(buffIndicatorGUI, 14, value.text, "system", "TOPLEFT", 20, value.offset)

		local frame = CreateFrame("Frame", nil, buffIndicatorGUI)
		frame:SetSize(280, 250)
		frame:SetPoint("TOPLEFT", 10, value.offset - 25)
		B.CreateBD(frame, .3)

		local scroll = G:CreateScroll(frame, 240, 200)
		scroll.box = B.CreateEditBox(frame, value.width, 25)
		scroll.box:SetPoint("TOPLEFT", 10, -10)
		scroll.box:SetMaxLetters(6)
		scroll.box.title = L["Tips"]
		B.AddTooltip(scroll.box, "ANCHOR_RIGHT", L["ID Intro"], "info")

		scroll.add = B.CreateButton(frame, 45, 25, ADD)
		scroll.add:SetPoint("TOPRIGHT", -8, -10)
		scroll.add:SetScript("OnClick", function()
			addClick(scroll, index)
		end)
		scroll.reset = B.CreateButton(frame, 45, 25, RESET)
		scroll.reset:SetPoint("RIGHT", scroll.add, "LEFT", -5, 0)
		scroll.reset:SetScript("OnClick", function()
			currentIndex = index
			StaticPopup_Show("RESET_NDUI_RaidAuraWatch")
		end)
		if index == 1 then
			for spellID in pairs(NDuiADB["RaidAuraWatch"]) do
				createBar(scroll.child, index, spellID)
			end
		else
			scroll.dd = B.CreateDropDown(frame, 45, 25, anchors)
			scroll.dd:SetPoint("TOPLEFT", 10, -10)
			scroll.dd.options[1]:Click()

			for i = 1, 8 do
				scroll.dd.options[i]:HookScript("OnEnter", optionOnEnter)
				scroll.dd.options[i]:HookScript("OnLeave", B.HideTooltip)
			end
			scroll.box:SetPoint("TOPLEFT", scroll.dd, "TOPRIGHT", 20, 0)

			local swatch = B.CreateColorSwatch(frame, "")
			swatch:SetPoint("LEFT", scroll.box, "RIGHT", 5, 0)
			scroll.swatch = swatch

			local showAll = B.CreateCheckBox(frame)
			showAll:SetPoint("LEFT", swatch, "RIGHT", 2, 0)
			showAll:SetHitRectInsets(0, 0, 0, 0)
			showAll.title = L["Tips"]
			B.AddTooltip(showAll, "ANCHOR_RIGHT", L["ShowAllTip"], "info")
			scroll.showAll = showAll

			for spellID, value in pairs(NDuiADB["CornerBuffs"][DB.MyClass]) do
				local r, g, b = unpack(value[2])
				createBar(scroll.child, index, spellID, value[1], r, g, b, value[3])
			end
		end
	end
end

local function createOptionTitle(parent, title, offset)
	B.CreateFS(parent, 14, title, nil, "TOP", 0, offset)
	local l = CreateFrame("Frame", nil, parent)
	l:SetPoint("TOPLEFT", 30, offset-20)
	B.CreateGF(l, 200, C.mult, "Horizontal", 1, 1, 1, .25, .25)
end

local function sliderValueChanged(self, v)
	local current = tonumber(format("%.0f", v))
	self.value:SetText(current)
	NDuiDB["UFs"][self.__value] = current
	self.__update()
end

local function createOptionSlider(parent, title, minV, maxV, x, y, value, func)
	local slider = B.CreateSlider(parent, title, minV, maxV, x, y)
	slider:SetValue(NDuiDB["UFs"][value])
	slider.value:SetText(NDuiDB["UFs"][value])
	slider.__value = value
	slider.__update = func
	slider:SetScript("OnValueChanged", sliderValueChanged)
end

function G:SetupUnitFrame(parent)
	toggleExtraGUI("NDuiGUI_UnitFrameSetup")
	if unitframeGUI then return end

	unitframeGUI = createExtraGUI(parent, "NDuiGUI_UnitFrameSetup", L["UnitFrame Size"].."*")

	local scroll = G:CreateScroll(unitframeGUI, 260, 540)

	local sliderRange = {
		["Player"] = {200, 300},
		["Pet"] = {100, 200},
	}

	local defaultValue = {
		["Player"] = {245, 24, 4},
		["Pet"] = {120, 18, 2},
	}

	local function createOptionGroup(parent, title, offset, value, func)
		createOptionTitle(parent, title, offset)
		createOptionSlider(parent, L["Health Width"].."("..defaultValue[value][1]..")", sliderRange[value][1], sliderRange[value][2], 30, offset-60, value.."Width", func)
		createOptionSlider(parent, L["Health Height"].."("..defaultValue[value][2]..")", 15, 50, 30, offset-130, value.."Height", func)
		createOptionSlider(parent, L["Power Height"].."("..defaultValue[value][3]..")", 2, 30, 30, offset-200, value.."PowerHeight", func)
	end

	local mainFrames = {_G.oUF_Player, _G.oUF_Target}
	local function updatePlayerSize()
		for _, frame in pairs(mainFrames) do
			frame:SetSize(NDuiDB["UFs"]["PlayerWidth"], NDuiDB["UFs"]["PlayerHeight"])
			frame.Power:SetHeight(NDuiDB["UFs"]["PlayerPowerHeight"])
		end
	end
	createOptionGroup(scroll.child, L["Player&Target"], -10, "Player", updatePlayerSize)

	local subFrames = {_G.oUF_Pet, _G.oUF_ToT, _G.oUF_ToToT}
	local function updatePetSize()
		for _, frame in pairs(subFrames) do
			frame:SetSize(NDuiDB["UFs"]["PetWidth"], NDuiDB["UFs"]["PetHeight"])
			frame.Power:SetHeight(NDuiDB["UFs"]["PetPowerHeight"])
		end
	end
	createOptionGroup(scroll.child, L["Pet&*Target"], -270, "Pet", updatePetSize)
end

function G:SetupRaidFrame(parent)
	toggleExtraGUI("NDuiGUI_RaidFrameSetup")
	if raidframeGUI then return end

	raidframeGUI = createExtraGUI(parent, "NDuiGUI_RaidFrameSetup", L["RaidFrame Size"])

	local scroll = G:CreateScroll(raidframeGUI, 260, 540)

	local minRange = {
		["Party"] = {80, 25},
		["PartyPet"] = {80, 20},
		["Raid"] = {60, 25},
	}

	local defaultValue = {
		["Party"] = {100, 32, 2},
		["PartyPet"] = {100, 22, 2},
		["Raid"] = {80, 32, 2},
	}

	local function createOptionGroup(parent, title, offset, value, func)
		createOptionTitle(parent, title, offset)
		createOptionSlider(parent, L["Health Width"].."("..defaultValue[value][1]..")", minRange[value][1], 200, 30, offset-60, value.."Width", func)
		createOptionSlider(parent, L["Health Height"].."("..defaultValue[value][2]..")", minRange[value][2], 60, 30, offset-130, value.."Height", func)
		createOptionSlider(parent, L["Power Height"].."("..defaultValue[value][3]..")", 2, 30, 30, offset-200, value.."PowerHeight", func)
	end

	local function resizeRaidFrame()
		for _, frame in pairs(ns.oUF.objects) do
			if frame.mystyle == "raid" and not frame.isPartyFrame then
				if NDuiDB["UFs"]["SimpleMode"] then
					frame:SetSize(100*NDuiDB["UFs"]["SimpleRaidScale"]/10, 20*NDuiDB["UFs"]["SimpleRaidScale"]/10)
				else
					frame:SetSize(NDuiDB["UFs"]["RaidWidth"], NDuiDB["UFs"]["RaidHeight"])
					frame.Power:SetHeight(NDuiDB["UFs"]["RaidPowerHeight"])
				end
			end
		end
	end
	createOptionGroup(scroll.child, L["RaidFrame"], -10, "Raid", resizeRaidFrame)
	createOptionSlider(scroll.child, "|cff00cc4c"..L["SimpleMode Scale"], 8, 15, 30, -280, "SimpleRaidScale", resizeRaidFrame)

	local function resizePartyFrame()
		for _, frame in pairs(ns.oUF.objects) do
			if frame.isPartyFrame then
				frame:SetSize(NDuiDB["UFs"]["PartyWidth"], NDuiDB["UFs"]["PartyHeight"])
				frame.Power:SetHeight(NDuiDB["UFs"]["PartyPowerHeight"])
			end
		end
	end
	createOptionGroup(scroll.child, L["PartyFrame"], -340, "Party", resizePartyFrame)

	local function resizePartyPetFrame()
		for _, frame in pairs(ns.oUF.objects) do
			if frame.mystyle == "partypet" then
				frame:SetSize(NDuiDB["UFs"]["PartyPetWidth"], NDuiDB["UFs"]["PartyPetHeight"])
				frame.Power:SetHeight(NDuiDB["UFs"]["PartyPetPowerHeight"])
			end
		end
	end
	createOptionGroup(scroll.child, L["PartyPetFrame"], -600, "PartyPet", resizePartyPetFrame)
end

local function createOptionSwatch(parent, name, value, x, y)
	local swatch = B.CreateColorSwatch(parent, name, value)
	swatch:SetPoint("TOPLEFT", x, y)
	swatch.text:SetTextColor(1, .8, 0)
end

function G:SetupCastbar(parent)
	toggleExtraGUI("NDuiGUI_CastbarSetup")
	if castbarGUI then return end

	castbarGUI = createExtraGUI(parent, "NDuiGUI_CastbarSetup", L["Castbar Settings"].."*")

	local scroll = G:CreateScroll(castbarGUI, 260, 540)

	createOptionTitle(scroll.child, L["Castbar Colors"], -10)
	createOptionSwatch(scroll.child, "", NDuiDB["UFs"]["CastingColor"], 120, -55)

	local defaultValue = {
		["Player"] = {300, 20},
		["Target"] = {280, 20},
	}

	local function createOptionGroup(parent, title, offset, value, func)
		createOptionTitle(parent, title, offset)
		createOptionSlider(parent, L["Castbar Width"].."("..defaultValue[value][1]..")", 200, 400, 30, offset-60, value.."CBWidth", func)
		createOptionSlider(parent, L["Castbar Height"].."("..defaultValue[value][2]..")", 10, 50, 30, offset-130, value.."CBHeight", func)
	end

	local function updatePlayerCastbar()
		if _G.oUF_Player then
			local width, height = NDuiDB["UFs"]["PlayerCBWidth"], NDuiDB["UFs"]["PlayerCBHeight"]
			_G.oUF_Player.Castbar:SetSize(width, height)
			_G.oUF_Player.Castbar.Icon:SetSize(height, height)
			_G.oUF_Player.Castbar.mover:Show()
			_G.oUF_Player.Castbar.mover:SetSize(width+height+5, height+5)
			if _G.oUF_Player.Swing then
				_G.oUF_Player.Swing:SetWidth(width-height-5)
			end
		end
	end
	createOptionGroup(scroll.child, L["Player Castbar"], -110, "Player", updatePlayerCastbar)

	local function updateTargetCastbar()
		if _G.oUF_Target then
			local width, height = NDuiDB["UFs"]["TargetCBWidth"], NDuiDB["UFs"]["TargetCBHeight"]
			_G.oUF_Target.Castbar:SetSize(width, height)
			_G.oUF_Target.Castbar.Icon:SetSize(height, height)
			_G.oUF_Target.Castbar.mover:Show()
			_G.oUF_Target.Castbar.mover:SetSize(width+height+5, height+5)
		end
	end
	createOptionGroup(scroll.child, L["Target Castbar"], -310, "Target", updateTargetCastbar)

	castbarGUI:HookScript("OnHide", function()
		if _G.oUF_Player then _G.oUF_Player.Castbar.mover:Hide() end
		if _G.oUF_Target then _G.oUF_Target.Castbar.mover:Hide() end
	end)
end

local function createOptionCheck(parent, offset, text)
	local box = B.CreateCheckBox(parent)
	box:SetPoint("TOPLEFT", 10, -offset)
	B.CreateFS(box, 14, text, false, "LEFT", 30, 0)
	return box
end

function G:SetupBagFilter(parent)
	toggleExtraGUI("NDuiGUI_BagFilterSetup")
	if bagFilterGUI then return end

	bagFilterGUI = createExtraGUI(parent, "NDuiGUI_BagFilterSetup", L["BagFilterSetup"].."*")

	local scroll = G:CreateScroll(bagFilterGUI, 260, 540)

	local filterOptions = {
		[1] = "FilterJunk",
		[2] = "FilterConsumble",
		[3] = "FilterAmmo",
		[4] = "FilterEquipment",
		[5] = "FilterLegendary",
		[6] = "FilterFavourite",
		[7] = "FilterGoods",
		[8] = "FilterQuest",
	}

	local Bags = B:GetModule("Bags")
	local function filterOnClick(self)
		local value = self.__value
		NDuiDB["Bags"][value] = not NDuiDB["Bags"][value]
		self:SetChecked(NDuiDB["Bags"][value])
		Bags:UpdateAllBags()
	end

	local offset = 10
	for _, value in ipairs(filterOptions) do
		local box = createOptionCheck(scroll, offset, L[value])
		box:SetChecked(NDuiDB["Bags"][value])
		box.__value = value
		box:SetScript("OnClick", filterOnClick)

		offset = offset + 35
	end
end