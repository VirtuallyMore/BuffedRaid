-----------------------------------------------------------------------------------------------
-- BuffedRaid
-- Addon to track if your raid is fed and potioned up.
-- Slash command: /br or /BuffedRaid
-- Created by: Caleb - calebzor@gmail.com
-----------------------------------------------------------------------------------------------
require "Window"
require "GameLib"
require "GroupLib"
require "ChatSystemLib"
require "MatchingGame"

local sVersion = "8.0.0.17"

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
	}
}

function addon:OnInitialize()
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
	Apollo.RegisterEventHandler("UnitEnteredCombat", "CombatStateChanged", self)
	self:ScheduleRepeatingTimer("OnUpdate", self.nTimerSpeed)
end

-----------------------------------------------------------------------------------------------
-- Options and GUI
-----------------------------------------------------------------------------------------------
function addon:CreateConfigTables()
	self.myOptionsTable = {
		type = "group",
		args = {
			usageHeader = {
				order = 1,
				name = "Usage:",
				type = "header",
				width = "full",
			},
			usageWithClick = {
				order = 2,
				name = "Clicking one of the icons will make you target that group member. (So you know, you can trade food/pots/field tech to them)",
				type = "description",
				width = "full",
			},
			usageWithAlt = {
				order = 3,
				name = "If you hold down ALT and then click one of the icons, you'll report who is missing food in the party chat.",
				type = "description",
				width = "full",
			},
			usageWithCtrl = {
				order = 4,
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
			bShowInPvP = {
				order = 10,
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
				set = function(info, v) self.db.profile[info[#info]] = v end,
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

function addon:OnGroup_Updated()
	self:ResizeBackground()
end

function addon:ResizeBackground()
	local nGroupMemberCount = GroupLib.GetMemberCount()
	local l,t,r,b = self.wAnchor:GetAnchorOffsets()
	self.wBackground:SetAnchorOffsets(l-2, t+nOffsetFromTop-2, l+nIconSize+2, t+nOffsetFromTop+nGroupMemberCount*nIconSize+2)
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
	end

	self:ResizeBackground()
end

function addon:OnSingleBuffButton(_, wHandler, wControl)
	if Apollo.IsAltKeyDown() then
		self:ReportFoodToParty()
	elseif Apollo.IsControlKeyDown() then
		self:ReportPotionsToParty()
	else
		GameLib.SetTargetUnit(wHandler:GetData())
	end
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
function addon:GetClassColor(unit)
	return self.tClassToColor[unit:GetClassId()]
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

local tBuffList = {
	"Reactive",
	"Grit Boost",
	"Moxie Boost",
	"Insight Boost",
	"Tech Boost",
	"Finesse Boost",
	"Finess Boost",
	"Brutality Boost",
}

local tFieldTechBuffList = {
	"Life Drain", -- Elemental Life Drain
	"Siphon", -- Liquid Confidence
}

function addon:FindBuffFromListByName(unit, tList)
	for k, sBuff in pairs(tList) do
		local buffStuff = self:FindBuffByName(unit, sBuff)
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
					local foodStuff = self:FindBuffByName(unit, "Stuffed!")
					if not foodStuff then
						nStarving = nStarving + 1
						sWithoutFood = ("%s %s"):format(sWithoutFood, unit:GetName())
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

function addon:ReportPotionsToParty()
	local sWithoutPotion = "Combat started 5 sec ago. Potionless (poop a poot?): "
	local sWithoutFieldTech = "Combat started 5 sec ago. FieldTechless (poop a poot?): "
	if self.nRaidMembersInCombat < 7 then return end
	local nPotionless = 0
	local nFieldTechless = 0
	for k = 1, 40 do
		local groupMember = GroupLib.GetGroupMember(k)
		if groupMember then
			local sName = groupMember.strCharacterName
			if sName then
				local unit = self:GetPartyMemberByName(sName)
				if unit and not unit:IsDead() then
					local potionStuff = self:FindBuffFromListByName(unit, tBuffList)
					if not potionStuff then
						nPotionless = nPotionless + 1
						sWithoutPotion = ("%s %s"):format(sWithoutPotion, unit:GetName())
					end
					local fieldTechStuff = self:FindBuffFromListByName(unit, tFieldTechBuffList)
					if not fieldTechStuff then
						nFieldTechless = nFieldTechless + 1
						sWithoutFieldTech = ("%s %s"):format(sWithoutFieldTech, unit:GetName())
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
	-- well not really hooking now are we? :D
	if MatchingGame.IsInPVPGame() and not self.db.profile.bShowInPvP then self:HideAll() return end -- don't show in PvP

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
				if unit then
					local foodStuff = self:FindBuffByName(unit, "Stuffed!")

					self.tFoodIcons[k]:Show(bGrouped)
					self.tFoodIcons[k]:SetData(unit)
					if foodStuff then
						self.tFoodIcons[k]:FindChild("Icon"):SetSprite(foodStuff[1])
						self.tFoodIcons[k]:SetTooltip(sName.." - "..foodStuff[2])
					else
						self.tFoodIcons[k]:FindChild("Icon"):FindChild("Icon"):SetSprite(unit:IsDead() and "CRB_GuildSprites:sprGuild_Skull" or "ClientSprites:LootCloseBox_Holo")
						self.tFoodIcons[k]:SetTooltip(sName)
					end

					local potionStuff = self:FindBuffFromListByName(unit, tBuffList)

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

					local fieldTechStuff = self:FindBuffFromListByName(unit, tFieldTechBuffList)

					self.tFieldTechIcons[k]:Show(bGrouped)
					self.tFieldTechIcons[k]:SetData(unit)
					if fieldTechStuff then
						self.tFieldTechIcons[k]:FindChild("Icon"):SetSprite(fieldTechStuff[1])
						self.tFieldTechIcons[k]:SetTooltip(sName.." - "..fieldTechStuff[2])
						self.tFieldTechIcons[k]:FindChild("Name"):SetText("")
					else
						self.tFieldTechIcons[k]:FindChild("Icon"):SetSprite(unit:IsDead() and "CRB_GuildSprites:sprGuild_Skull" or "ClientSprites:LootCloseBox_Holo")
						self.tFieldTechIcons[k]:SetTooltip(sName)
						self.tFieldTechIcons[k]:FindChild("Name"):SetText(sName)
						self.tFieldTechIcons[k]:FindChild("Name"):SetTextColor(self:GetClassColor(unit))
					end
				end
			end
		else
			self.tFoodIcons[k]:Show(false)
		end
	end

	if bGrouped and self.bRaidInCombat and self.bRaidInCombat ~= self.bRaidInCombatLastState then
		if self.db.profile.bReportAtStartOfCombat then
			self:ScheduleTimer("ReportPotionsToParty", 5)
			self.bRaidInCombatLastState = self.bRaidInCombat
		end
		if self.db.profile.bReportEvery3MinInCombat and not self.combatAnnounceTimer then
			self.combatAnnounceTimer = self:ScheduleRepeatingTimer("ReportPotionsToParty", 180)
		end
	end
end