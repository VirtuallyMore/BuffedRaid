-----------------------------------------------------------------------------------------------
-- BuffedRaid
-- Addon to track if your raid is fed and potioned up.
-- Slash command: /br or /BuffedRaid
-- Created by: Caleb - calebzor@gmail.com
-----------------------------------------------------------------------------------------------

--[[
	TODO:
		flask support perhaps
]]--

require "Window"
require "GameLib"
require "GroupLib"
require "ChatSystemLib"
require "MatchingGame"

local sVersion = "9.0.1.30"

-----------------------------------------------------------------------------------------------
-- Upvalues
-----------------------------------------------------------------------------------------------
local MatchingGame = MatchingGame
local GameLib = GameLib
local ChatSystemLib = ChatSystemLib
local GroupLib = GroupLib
local Apollo = Apollo
local ApolloColor = ApolloColor
local Print = Print
local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local type = type
local Event_FireGenericEvent = Event_FireGenericEvent

-----------------------------------------------------------------------------------------------
-- Load packages
-----------------------------------------------------------------------------------------------
local addon = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon("BuffedRaid", false, {}, "Gemini:Timer-1.0")
local GeminiConfig = Apollo.GetPackage("Gemini:Config-1.0").tPackage
local GeminiGUI = Apollo.GetPackage("Gemini:GUI-1.0").tPackage

-----------------------------------------------------------------------------------------------
-- Window definitions
-----------------------------------------------------------------------------------------------
local tSingleBuffDef = {
	AnchorOffsets = { 0, 0, 24, 24 },
	Class = "Button",
	Base = "",
	Font = "CRB_Interface7_BB",
	ButtonType = "PushButton",
	DT_VCENTER = true,
	BGColor = "UI_BtnBGDefault",
	TextColor = "UI_BtnTextDefault",
	NormalTextColor = "UI_BtnTextDefault",
	PressedTextColor = "UI_BtnTextDefault",
	FlybyTextColor = "UI_BtnTextDefault",
	PressedFlybyTextColor = "UI_BtnTextDefault",
	DisabledTextColor = "UI_BtnTextDefault",
	Name = "SingleBuff",
	AutoScaleTextOff = 0,
	ewWindowDepth = 1,
	Events = {
		ButtonSignal = function(...) addon:OnSingleBuffButton(...) end,
	},
	Children = {
		{
			AnchorOffsets = { 4, 0, 1000, 20 },
			AnchorPoints = { 1, 0, 0, 0 },
			RelativeToClient = true,
			Font = "CRB_Interface9_BO",
			BGColor = "UI_WindowBGDefault",
			TextColor = "UI_WindowTextDefault",
			Name = "Name",
			IgnoreMouse = true,
			NoClip = true,
			AutoScaleTextOff = 1,
			NewWindowDepth = 1,
			IgnoreTooltipDelay = true,
		},
		{
			AnchorOffsets = { 1, 1, 1, 1 },
			AnchorPoints = { 0, 0, 1, 1 },
			RelativeToClient = true,
			BGColor = "UI_WindowBGDefault",
			TextColor = "UI_WindowTextDefault",
			Name = "Icon",
			Picture = true,
			NewWindowDepth = 1,
			IgnoreTooltipDelay = true,
			IgnoreMouse = true,
		},
	},
}

local tBackgroundDef = {
	AnchorOffsets = { 1, 1, 31, 351 },
	RelativeToClient = true,
	BGColor = "UI_WindowBGDefault",
	TextColor = "UI_WindowTextDefault",
	Name = "Background",
	Picture = true,
	Sprite = "CRB_DatachronSprites:sprDCM_ListModeBacker",
	IgnoreMouse = true,
	SwallowMouseClicks = true,
	NeverBringToFront = 1,
}

local tAnchorDef = {
	AnchorOffsets = { 169, 8, 289, 37 },
	RelativeToClient = true,
	Text = "   BuffedRaid anchor",
	Name = "Anchor",
	Border = true,
	Picture = true,
	SwallowMouseClicks = true,
	Moveable = true,
	Overlapped = true,
	BGColor = "white",
	IgnoreTooltipDelay = true,
	Sprite = "CRB_Basekit:kitBase_HoloBlue_InsetBorder_Thin",
	DT_VCENTER = true,
	Events = {
		WindowMove = function() addon:OnAnchorMove() end,
	},
}

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
local nOffsetFromTop = 30
local nIconSize = 21

local defaults = {
	profile = {
		tPos = {169, 8, 321, 37},
		bAnchorLocked = false,
		bShowInPvP = false,
		bReportAtStartOfCombat = true,
		bReportEvery3MinInCombat = true,
		bReportInInstance = false,
		bEnabled = true,
		bShowInCombat = true,
	}
}

function addon:OnInitialize()
	self.tBoostIds = {
		--[32821] = true, -- bolster
		[35078] = true, -- Liquid Focus -- Reactive Strikethrough Boost
		[36588] = true, -- Expert Moxie Boost - Moxie Boost
		[36573] = true, -- Expert Finess Boost - Finess Boost
		[36594] = true, -- Expert Insight Boost - Insight Boost
		[35028] = true, -- Expert Brutality Boost - Brutality Boost
		[38157] = true, -- Expert Grid Boost - Grit boost
		[36579] = true, -- Expert Tech Boost - Tech boost
		[35062] = true, -- Reactive Brutality Boost
		[37054] = true, -- Reactive Finess Boost
		[37074] = true, -- Reactive Insight Boost
		[37103] = true, -- Reactive Tech Boost
		[37091] = true, -- Reactive Moxie Boost
		[39733] = true, -- zerkOut Neurochems - Unstable Critical Hit Boost
		[39735] = true, -- Temporal Shimmy Tonic - Unstable Critical Hit Boost
		[39725] = true, -- Quickstrike Serum - Reactive Critical Hit boost

		[39742] = true, -- Avoidance Formatic Foam - Deflect Boost -- even though this is marked as field tech, it does not stack with boosts
		[39748] = true, -- QuickReact Formatic Foam - Deflect Critical Hit Boost
		[35122] = true, -- Adventus Enduro Boost - Endurance Boost -- this stacks with other boosts - so maybe don't track it?
		[39715] = true, -- Adventus Critical Hit Boost - Critical Hit Boost
		[35093] = true, -- Adventus Strikethrough Boost - Unstable Strikethrough Boost
		[36595] = true, -- Adventus Insight Boost - Insight Boost
		[36580] = true, -- Adventus Tech Boost - Tech Boost
		[36574] = true, -- Adventus Finess Boost - Finess Boost
		[35029] = true, -- Adventus Brutality Boost - Brutality Boost
		[36589] = true, -- Adventus Moxie Boost - Moxie Boost
		[35080] = true, -- Aggo-Momentum Focuser - Reactive Strikethrough Boost -- even though this is marked as field tech, it does not stack with boosts
		[35052] = true, -- Aggression Neurotrancer - Strikethrough Boost -- yep another boost
		[39736] = true, -- zerkOut Neurotrancer - Unstable Critical Hit Boost -- yep another boost
	}
	self.tFieldTechtIds = {
		--[32821] = true, -- bolster
		[35213] = true, -- Liquid Confidence - Siphon
		[35145] = true, -- Life Drain
		[35164] = true, -- Bioreactive Acid Membrane - Cleave

		[35166] = true, -- Echo Impact Synchronizer - Cleave
		[35202] = true, -- Impact Filtration Reflector - Reflect
		[35147] = true, -- Regenerative Draining Gel - Life Drain -- this stacks with Regenerative Impact Gel
		[35213] = true, -- Regenerative Impact Gel - Siphon -- this stacks with Regenerative Draining Gel
	}
	self.tFoodIds = {
		-- actually just use "Stuffed!" cuz I can't be bothered to add all food spellIds,
		GameLib.GetSpell(48443):GetName(), -- "Stuffed!" from Exile Empanadas, we track food by this not by spellId
	}

	self.db = Apollo.GetPackage("Gemini:DB-1.0").tPackage:New(self, defaults)

	self.nTime = 0
	self.nTimerSpeed = 1
	self.nLastPotionReport = 0
	self.nLastFieldTechReport = 0

	self.bRaidInCombat = false
	self.nRaidMembersInCombat = 0
	self.bRaidInCombatLastState = false

	self.tFoodIcons = {}
	self.tPotionIcons = {}
	self.tFieldTechIcons = {}

	self.tClassToColor = {
		-- Colors apparently defined by Duran by a forum post by Orbish who never got back to us with hex codes
		--[[Warrior]] ApolloColor.new("ffde1818"),	-- Warrior
		--[[Engineer]] ApolloColor.new("fffae843"),	-- Yellow (Web Icon)
		--[[Esper]] ApolloColor.new("ff07a8df"),	-- Esper
		--[[Medic]] ApolloColor.new("ff96cd18"),	-- Green (Web Icon)
		--[[Stalker]] ApolloColor.new("ffb137f6"),	-- Stalker
		nil,
		--[[Spellslinger]] ApolloColor.new("ffec8626"),	-- Spellslinger Orange (Web Icon)
	}
end

function addon:OnEnable()
	self.wAnchor = GeminiGUI:Create(tAnchorDef):GetInstance()
	self.wAnchor:SetAnchorOffsets(unpack(self.db.profile.tPos))
	self.wAnchor:Show(self.db.profile.bAnchorLocked)

	self.wBackground = GeminiGUI:Create(tBackgroundDef):GetInstance()
	self.wBackground:Show(true)
	self.wBackground2 = GeminiGUI:Create(tBackgroundDef):GetInstance()
	self.wBackground2:Show(true)
	self.wBackground3 = GeminiGUI:Create(tBackgroundDef):GetInstance()
	self.wBackground3:Show(true)

	for i= 1, 40 do
		self.tFoodIcons[i] = GeminiGUI:Create(tSingleBuffDef):GetInstance()
		self.tFoodIcons[i]:Show(false)
		self.tPotionIcons[i] = GeminiGUI:Create(tSingleBuffDef):GetInstance()
		self.tPotionIcons[i]:Show(false)
		self.tFieldTechIcons[i] = GeminiGUI:Create(tSingleBuffDef):GetInstance()
		self.tFieldTechIcons[i]:Show(false)
	end

	self:RepositionWindows()

	self:CreateConfigTables()

	Apollo.RegisterEventHandler("Group_Updated", "OnGroup_Updated", self)
	Apollo.RegisterEventHandler("Group_Join", "OnGroup_Updated", self)

	Apollo.RegisterEventHandler("OnGroup_Remove", "GroupLeft", self)
	Apollo.RegisterEventHandler("OnGroup_Left", "GroupLeft", self)
	Apollo.RegisterEventHandler("Group_Remove", "GroupLeft", self)
	Apollo.RegisterEventHandler("Group_Left", "GroupLeft", self)

	Apollo.RegisterEventHandler("UnitEnteredCombat", "CombatStateChanged", self)
	self:ScheduleRepeatingTimer("OnUpdate", self.nTimerSpeed)

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("BR_OpenMenu", "OpenMenu", self)
end

-----------------------------------------------------------------------------------------------
-- Options and GUI
-----------------------------------------------------------------------------------------------
function addon:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "BuffedRaid", { "BR_OpenMenu", "", ""})
 
	self:UpdateInterfaceMenuAlerts()
end

function addon:CreateConfigTables()
	self.myOptionsTable = {
		type = "group",
		args = {
			bEnabled = {
				order = 1,
				name = "Turn the addon on/off",
				type = "toggle",
				width = "full",
				get = function(info) return self.db.profile[info[#info]] end,
				set = function(info, v) self.db.profile[info[#info]] = v end,
			},
			usageHeader = {
				order = 2,
				name = "Usage:",
				type = "header",
				width = "full",
			},
			usageWithClick = {
				order = 3,
				name = "Clicking one of the icons will make you target that group member. (So you know, you can trade food/pots/field tech to them)",
				type = "description",
				width = "full",
			},
			usageWithAlt = {
				order = 4,
				name = "If you hold down ALT and then click one of the icons, you'll report who is missing food in the party chat.",
				type = "description",
				width = "full",
			},
			usageWithCtrl = {
				order = 5,
				name = "If you hold down CTRL and then click one of the icons, you'll report who is missing potions and field tech in the party chat.",
				type = "description",
				width = "full",
			},
			optionsHeader = {
				order = 8,
				name = "Options",
				type = "header",
				width = "full",
			},
			bAnchorLocked = {
				order = 9,
				name = "Lock/Unlock anchor",
				type = "toggle",
				width = "full",
				get = function(info) return self.db.profile[info[#info]] end,
				set = function(info, v) self.db.profile[info[#info]] = v; self.wAnchor:Show(v) end,
			},
			bShowInCombat = {
				order = 10,
				name = "Show in combat",
				desc = "Toggle if the display should be shown during combat or not.",
				type = "toggle",
				width = "full",
				get = function(info) return self.db.profile[info[#info]] end,
				set = function(info, v) self.db.profile[info[#info]] = v end,
			},
			bShowInPvP = {
				order = 11,
				name = "Show in isntanced PvP",
				desc = "Toggle where to show the buff tracker when inside instanced PvP ( Battlegrounds, Arena, Warplots )",
				type = "toggle",
				width = "full",
				get = function(info) return self.db.profile[info[#info]] end,
				set = function(info, v) self.db.profile[info[#info]] = v end,
			},
			reportingHeader = {
				order = 14,
				name = "Reporting",
				type = "header",
				width = "full",
			},
			bReportInInstance = {
				order = 16,
				name = "Report in /instance when in instanced group",
				desc = "Allow reporting to /instance.",
				type = "toggle",
				width = "full",
				get = function(info) return self.db.profile[info[#info]] end,
				set = function(info, v) self.db.profile[info[#info]] = v end,
			},
			bReportAtStartOfCombat = {
				order = 20,
				name = "Report at start of combat",
				desc = "Report who is missing potions or field tech 5 sec after combat has started.",
				type = "toggle",
				width = "full",
				get = function(info) return self.db.profile[info[#info]] end,
				set = function(info, v) self.db.profile[info[#info]] = v end,
			},
			bReportEvery3MinInCombat = {
				order = 30,
				name = "Report every 3 minutes in combat",
				desc = "Report those missing potions and field tech every 3 minutes after the combat has started.",
				type = "toggle",
				width = "full",
				get = function(info) return self.db.profile[info[#info]] end,
				set = function(info, v) self.db.profile[info[#info]] = v
					if not v then
						if self.combatAnnounceTimer then
							self:CancelTimer(self.combatAnnounceTimer, true)
							self.combatAnnounceTimer = nil
						end
					end
				end,
			},
			GeminiConfigScrollingFrameBottomWidgetFix = {
				order = 9999,
				name = "",
				type = "description",
			},
		},
	}

	GeminiConfig:RegisterOptionsTable("BuffedRaid", self.myOptionsTable)

	Apollo.RegisterSlashCommand("BuffedRaid", "OpenMenu", self)
	Apollo.RegisterSlashCommand("buffedraid", "OpenMenu", self)
	Apollo.RegisterSlashCommand("br", "OpenMenu", self)
end

function addon:OpenMenu(_, input)
	Apollo.GetPackage("Gemini:ConfigDialog-1.0").tPackage:Open("BuffedRaid")
end

function addon:OnAnchorMove()
	--D("window moved")
	local l,t,r,b = self.wAnchor:GetAnchorOffsets()
	self.db.profile.tPos = {l,t,r,b}
	self:RepositionWindows()
end

function addon:GetSmartGroupCount()
	local nMemberCount = GroupLib.GetMemberCount()
	if self.bRaidInCombat then
		self.nRaidMembersInCombat = 0
		for i=1, nMemberCount do
			local unit = GroupLib.GetUnitForGroupMember(i)
			if unit and unit:IsInCombat() then
				self.nRaidMembersInCombat = self.nRaidMembersInCombat + 1
			end
		end
		local nAlive = nMemberCount-self.nRaidMembersInCombat
		Event_FireGenericEvent("InterfaceMenuList_AlertAddOn", "BuffedRaid", {false, "Group member alive: "..nAlive, nAlive})
	else
		Event_FireGenericEvent("InterfaceMenuList_AlertAddOn", "BuffedRaid", {false, "Group member count: "..nMemberCount, nMemberCount})
	end
end

function addon:UpdateInterfaceMenuAlerts()
	self:GetSmartGroupCount()
end

function addon:GroupLeft()
	Event_FireGenericEvent("InterfaceMenuList_AlertAddOn", "BuffedRaid", {false, "", 0}) -- clean up
end

function addon:OnGroup_Updated()
	self:UpdateInterfaceMenuAlerts()
	self:ResizeBackground()
end

function addon:ResizeBackground()
	local nGroupMemberCount = GroupLib.GetMemberCount()
	local l,t,r,b = self.wAnchor:GetAnchorOffsets()
	self.wBackground:SetAnchorOffsets(l-2, t+nOffsetFromTop-2, l+nIconSize+5, t+nOffsetFromTop+nGroupMemberCount*nIconSize+2)
	self.wBackground2:SetAnchorOffsets(l+nIconSize+2, t+nOffsetFromTop-2, l+2*nIconSize+5, t+nOffsetFromTop+nGroupMemberCount*nIconSize+2)
	self.wBackground3:SetAnchorOffsets(l+nIconSize*2+2, t+nOffsetFromTop-2, l+3*nIconSize+5, t+nOffsetFromTop+nGroupMemberCount*nIconSize+2)
end

function addon:RepositionWindows()
	local nGroupMemberCount = GroupLib.GetMemberCount()
	local l,t,r,b = self.wAnchor:GetAnchorOffsets()

	for k=1, 40 do
		self.tFoodIcons[k]:SetAnchorOffsets(l, t+nOffsetFromTop+(k-1)*nIconSize, l+nIconSize, t+nOffsetFromTop+k*nIconSize)
		self.tPotionIcons[k]:SetAnchorOffsets(l+nIconSize+3, t+nOffsetFromTop+(k-1)*nIconSize, 3+l+2*nIconSize, t+nOffsetFromTop+k*nIconSize)
		self.tFieldTechIcons[k]:SetAnchorOffsets(l+nIconSize*2+3, t+nOffsetFromTop+(k-1)*nIconSize, 3+l+3*nIconSize, t+nOffsetFromTop+k*nIconSize)
		--self.tFieldTechIcons[k]:SetAnchorOffsets(l+nIconSize*3+3, t+nOffsetFromTop+(k-1)*nIconSize, 3+l+4*nIconSize, t+nOffsetFromTop+k*nIconSize)
	end

	self:ResizeBackground()
end

function addon:OnSingleBuffButton(_, wHandler, wControl)
	if Apollo.IsAltKeyDown() and Apollo.IsControlKeyDown() then
		self:ReportToPlayer(wHandler:GetData())
		return
	end
	if Apollo.IsAltKeyDown() then
		self:ReportFoodToParty()
		return
	end
	if Apollo.IsControlKeyDown() then
		self:ReportPotionsToParty(true)
		return
	end
	GameLib.SetTargetUnit(wHandler:GetData())
end

-----------------------------------------------------------------------------------------------
-- Wipe check
-----------------------------------------------------------------------------------------------
function addon:WipeCheck()
	self.nRaidMembersInCombat = 0
	for i=1, GroupLib.GetMemberCount() do
		local unit = GroupLib.GetUnitForGroupMember(i)
		if unit then
			if unit:IsInCombat() then
				self.bRaidInCombat = true
				self.nRaidMembersInCombat = self.nRaidMembersInCombat + 1
			end
		end
	end
	if self.bRaidInCombat then
		return
	end
	self:CancelTimer(self.wipeTimer)
	self.wipeTimer = nil
	self.bRaidInCombat = false
	self.bRaidInCombatLastState = false
	self:CancelTimer(self.combatAnnounceTimer)
	self.combatAnnounceTimer = nil
end

function addon:CombatStateChanged(unit, bInCombat)
	if unit == GameLib.GetPlayerUnit() and not self.wipeTimer then
		self.wipeTimer = self:ScheduleRepeatingTimer("WipeCheck", 0.5)
	end
end

-----------------------------------------------------------------------------------------------
-- Utility
-----------------------------------------------------------------------------------------------
function addon:GetClassColor(eClassId)
	return self.tClassToColor[eClassId]
end

function addon:GetPartyMemberByName(sName)
	for i=1, GroupLib.GetMemberCount() do
		local unit = GroupLib.GetUnitForGroupMember(i)
		if unit then
			if unit:GetName() == sName then
				return unit
			end
		end
	end
	return false
end

function addon:FindBuffById(unit, nSpellId)
	local tBuffs = unit:GetBuffs().arBeneficial
	if not tBuffs then return false end
	for k, v in pairs(tBuffs) do
		if v.splEffect:GetId() == nSpellId then
			return {v.splEffect:GetIcon(), v.splEffect:GetName()}
		end
	end
	return false
end

function addon:FindBuffByName(unit, sBuff)
	local tBuffs = unit:GetBuffs().arBeneficial
	if not tBuffs then return false end
	for k, v in pairs(tBuffs) do
		if v.splEffect:GetName():lower():find(sBuff:lower()) then
			return {v.splEffect:GetIcon(), v.splEffect:GetName()}
		end
	end
	return false
end

function addon:FindBuffFromListById(unit, tList)
	for nSpellId, _ in pairs(tList) do
		local buffStuff = self:FindBuffById(unit, nSpellId)
		if buffStuff then
			return buffStuff
		end
	end
	return false
end

-----------------------------------------------------------------------------------------------
-- Reporting
-----------------------------------------------------------------------------------------------
function addon:ReportToChat(sMsg)
	local bInMatchIngGame = MatchingGame.IsInMatchingInstance()
	if not bInMatchIngGame then -- don't try to report to party when in instanced stuff
		ChatSystemLib.Command(("/p %s"):format(sMsg))
	elseif bInMatchIngGame and self.db.profile.bReportInInstance then -- only report in instance chat if it is also turned in the options
		ChatSystemLib.Command(("/i %s"):format(sMsg))
	end
end

function addon:Whisper(sTarget, sMsg)
	ChatSystemLib.Command(("/w %s %s"):format(sTarget, sMsg))
end

function addon:ReportToPlayer(unit)
	-- I guess spamming in whispers is fine :D
	if unit then
		if not unit:IsInCombat() then -- you can't eat in combat
			local foodStuff = self:FindBuffByName(unit, self.tFoodIds[1])
			if not foodStuff then
				self:Whisper(unit:GetName(), "You must be starving. Eat some food maybe? (food buff missing)")
			end
		end
		local potionStuff = self:FindBuffFromListById(unit, self.tBoostIds)
		if not potionStuff then
			self:Whisper(unit:GetName(), "You don't have any boost (buffs) on. Poop a poot?")
		end
		local fieldTechStuff = self:FindBuffFromListById(unit, self.tFieldTechtIds)
		if not fieldTechStuff then
			self:Whisper(unit:GetName(), "You don't have any field tech buffs on. Poop a poot?")
		end
	end
end

function addon:ReportFoodToParty()
	local sWithoutFood = "Starving people (give them some food maybe?): "
	local nStarving = 0
	for k = 1, 40 do
		local groupMember = GroupLib.GetGroupMember(k)
		if groupMember then
			local sName = groupMember.strCharacterName
			if sName then
				local unit = self:GetPartyMemberByName(sName)
				if unit then
					local foodStuff = self:FindBuffByName(unit, self.tFoodIds[1])
					if not foodStuff then
						nStarving = nStarving + 1
						if nStarving == 1 then
							sWithoutFood = ("%s %s"):format(sWithoutFood, unit:GetName())
						else
							sWithoutFood = ("%s, %s"):format(sWithoutFood, unit:GetName())
						end
					end
				end
			end
		end
	end
	if nStarving > 0 then
		if (self.nTime - self.nLastPotionReport) > 5 then
			self:ReportToChat(sWithoutFood)
			self.nLastPotionReport = self.nTime
		else
			Print(("Can't spam party chat! Wait another: %.1f then try again."):format(5- self.nTime - self.nLastPotionReport))
		end
	else
		Print("Everyone is stuffed!")
	end
end

function addon:ReportPotionsToParty(bFromClick)
	local sWithoutPotion = "Potionless (poop a poot?): "
	local sWithoutFieldTech = "FieldTechless (poop a poot?): "
	if self.nRaidMembersInCombat < 7 and not bFromClick then return end
	local nPotionless = 0
	local nFieldTechless = 0
	for k = 1, 40 do
		local groupMember = GroupLib.GetGroupMember(k)
		if groupMember then
			local sName = groupMember.strCharacterName
			if sName then
				local unit = self:GetPartyMemberByName(sName)
				if unit and not unit:IsDead() then
					local potionStuff = self:FindBuffFromListById(unit, self.tBoostIds)
					if not potionStuff then
						nPotionless = nPotionless + 1
						if nPotionless == 1 then
							sWithoutPotion = ("%s %s"):format(sWithoutPotion, unit:GetName())
						else
							sWithoutPotion = ("%s, %s"):format(sWithoutPotion, unit:GetName())
						end
					end
					local fieldTechStuff = self:FindBuffFromListById(unit, self.tFieldTechtIds)
					if not fieldTechStuff then
						nFieldTechless = nFieldTechless + 1
						if nFieldTechless == 1 then
							sWithoutFieldTech = ("%s %s"):format(sWithoutFieldTech, unit:GetName())
						else
							sWithoutFieldTech = ("%s, %s"):format(sWithoutFieldTech, unit:GetName())
						end
					end
				end
			end
		end
	end
	if nPotionless > 0 then
		if (self.nTime - self.nLastPotionReport) > 1 then
			self:ReportToChat(sWithoutPotion)
			self.nLastPotionReport = self.nTime
		else
			Print(("Can't spam party chat! Wait another: %.1f then try again."):format(5- self.nTime - self.nLastPotionReport))
		end
	else
		Print("Everyone has potions!")
	end
	if nFieldTechless > 0 then
		if (self.nTime - self.nLastFieldTechReport) > 1 then
			self:ReportToChat(sWithoutFieldTech)
			self.nLastFieldTechReport = self.nTime
		else
			Print(("Can't spam party chat! Wait another: %.1f then try again."):format(5- self.nTime - self.nLastFieldTechReport))
		end
	else
		Print("Everyone has field tech!")
	end
end

function addon:HideAll()
	self.wBackground:Show(false)
	self.wBackground2:Show(false)
	self.wBackground3:Show(false)
	for k = 1, 40 do
		self.tFoodIcons[k]:Show(false)
		self.tPotionIcons[k]:Show(false)
		self.tFieldTechIcons[k]:Show(false)
	end
end

-----------------------------------------------------------------------------------------------
-- OnUpdate ( or well 0.1 timer )
-----------------------------------------------------------------------------------------------
function addon:OnUpdate()
	self.nTime = self.nTime + self.nTimerSpeed
	if not self.db.profile.bEnabled then self:HideAll() return end
	-- well not really hooking now are we? :D
	if MatchingGame.IsInPVPGame() and not self.db.profile.bShowInPvP or (not self.db.profile.bShowInCombat and GameLib.GetPlayerUnit():IsInCombat()) then self:HideAll() return end -- don't show in PvP

	if not self.wBackground then return end

	local bGrouped = GameLib.GetPlayerUnit():IsInYourGroup()

	-- hide everything before doing anything else
	self:HideAll()
	-- we just hid everything so if we are not in a group STOP
	if not bGrouped then return end
	-- else show stuff
	self.wBackground:Show(true)
	self.wBackground2:Show(true)
	self.wBackground3:Show(true)

	for k = 1, 40 do
		local groupMember = GroupLib.GetGroupMember(k)
		if groupMember then
			local sName = groupMember.strCharacterName
			if sName then
				local unit = self:GetPartyMemberByName(sName)
				self.tFieldTechIcons[k]:FindChild("Name"):SetText(sName)
				self.tFieldTechIcons[k]:FindChild("Name"):SetTextColor(self:GetClassColor(groupMember.eClassId))
				self.tFieldTechIcons[k]:Show(bGrouped)
				if unit then
					local foodStuff = self:FindBuffByName(unit, self.tFoodIds[1])

					self.tFoodIcons[k]:Show(bGrouped)
					self.tFoodIcons[k]:SetData(unit)
					if foodStuff then
						self.tFoodIcons[k]:FindChild("Icon"):SetSprite(foodStuff[1])
						self.tFoodIcons[k]:SetTooltip(sName.." - "..foodStuff[2])
					else
						self.tFoodIcons[k]:FindChild("Icon"):FindChild("Icon"):SetSprite(unit:IsDead() and "CRB_GuildSprites:sprGuild_Skull" or "ClientSprites:LootCloseBox_Holo")
						self.tFoodIcons[k]:SetTooltip(sName)
					end

					local potionStuff = self:FindBuffFromListById(unit, self.tBoostIds)

					self.tPotionIcons[k]:Show(bGrouped)
					self.tPotionIcons[k]:SetData(unit)
					if potionStuff then
						self.tPotionIcons[k]:FindChild("Icon"):SetSprite(potionStuff[1])
						self.tPotionIcons[k]:SetTooltip(sName.." - "..potionStuff[2])
						self.tPotionIcons[k]:FindChild("Name"):SetText("")
					else
						self.tPotionIcons[k]:FindChild("Icon"):SetSprite(unit:IsDead() and "CRB_GuildSprites:sprGuild_Skull" or "ClientSprites:LootCloseBox_Holo")
						self.tPotionIcons[k]:SetTooltip(sName)
					end

					local fieldTechStuff = self:FindBuffFromListById(unit, self.tFieldTechtIds)

					self.tFieldTechIcons[k]:Show(bGrouped)
					self.tFieldTechIcons[k]:SetData(unit)
					if fieldTechStuff then
						self.tFieldTechIcons[k]:FindChild("Icon"):SetSprite(fieldTechStuff[1])
						self.tFieldTechIcons[k]:SetTooltip(sName.." - "..fieldTechStuff[2])
						self.tFieldTechIcons[k]:FindChild("Name"):SetText("")
					else
						self.tFieldTechIcons[k]:FindChild("Icon"):SetSprite(unit:IsDead() and "CRB_GuildSprites:sprGuild_Skull" or "ClientSprites:LootCloseBox_Holo")
						self.tFieldTechIcons[k]:SetTooltip(sName)
					end
				else
					self.tFieldTechIcons[k]:SetTooltip("Out of range: "..sName)
				end
			end
		else
			self.tFoodIcons[k]:Show(false)
		end
	end

	if bGrouped and self.bRaidInCombat then
		self:UpdateInterfaceMenuAlerts()
		if self.bRaidInCombat ~= self.bRaidInCombatLastState then
			if self.db.profile.bReportAtStartOfCombat then
				self:ScheduleTimer("ReportPotionsToParty", 5)
				self.bRaidInCombatLastState = self.bRaidInCombat
			end
			if self.db.profile.bReportEvery3MinInCombat and not self.combatAnnounceTimer then
				self.combatAnnounceTimer = self:ScheduleRepeatingTimer("ReportPotionsToParty", 180)
			end
		end
	end
end