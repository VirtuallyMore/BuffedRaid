-----------------------------------------------------------------------------------------------
-- BuffedRaid
-- Addon to track if your raid is fed and potioned up.
-- Created by: Caleb - calebzor@gmail.com
-----------------------------------------------------------------------------------------------
require "Window"
require "GameLib"
require "GroupLib"
require "ChatSystemLib"
require "MatchingGame"

local sVersion = "8.0.0.3"

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

local addon = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon("BuffedRaid", false, {}, "Gemini:Timer-1.0")
local GeminiConfig = Apollo.GetPackage("Gemini:Config-1.0").tPackage

local defaults = {
	profile = {
		tPos = {169, 8, 321, 37},
		bAnchorLocked = false,
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
	self.wAnchor = Apollo.LoadForm("BuffedRaid.xml", "Anchor", nil, self)
	self.wAnchor:SetAnchorOffsets(unpack(self.db.profile.tPos))
	self.wAnchor:Show(self.db.profile.bAnchorLocked)

	self.wBackground = Apollo.LoadForm("BuffedRaid.xml", "Background", nil, self)
	self.wBackground:Show(true)
	self.wBackground2 = Apollo.LoadForm("BuffedRaid.xml", "Background", nil, self)
	self.wBackground2:Show(true)
	self.wBackground3 = Apollo.LoadForm("BuffedRaid.xml", "Background", nil, self)
	self.wBackground3:Show(true)

	self:ScheduleRepeatingTimer("OnUpdate", self.nTimerSpeed)

	for i= 1, 40 do
		self.tFoodIcons[i] = Apollo.LoadForm("BuffedRaid.xml", "SingleBuff", nil, self)
		self.tFoodIcons[i]:Show(false)
	end

	for i= 1, 40 do
		self.tPotionIcons[i] = Apollo.LoadForm("BuffedRaid.xml", "SingleBuff", nil, self)
		self.tPotionIcons[i]:Show(false)
	end

	for i= 1, 40 do
		self.tFieldTechIcons[i] = Apollo.LoadForm("BuffedRaid.xml", "SingleBuff", nil, self)
		self.tFieldTechIcons[i]:Show(false)
	end
	Apollo.RegisterEventHandler("UnitEnteredCombat", "CombatStateChanged", self)

	self:CreateConfigTables()
end

function addon:CreateConfigTables()
	self.myOptionsTable = {
		type = "group",
		args = {
			bAnchorLocked = {
				order = 1,
				name = "Lock/Unlock anchor",
				type = "toggle",
				width = "full",
				get = function(info) return self.db.profile[info[#info]] end,
				set = function(info, v) self.db.profile[info[#info]] = v; self.wAnchor:Show(v) end,
			},
		},
	}

	GeminiConfig:RegisterOptionsTable("BuffedRaid", self.myOptionsTable)

	Apollo.RegisterSlashCommand("BuffedRaid", "OpenMenu", self)
	Apollo.RegisterSlashCommand("br", "OpenMenu", self)
end

function addon:OpenMenu(_, input)
	Apollo.GetPackage("Gemini:ConfigDialog-1.0").tPackage:Open("BuffedRaid")
end

function addon:OnAnchorMove()
	local l,t,r,b = self.wAnchor:GetAnchorOffsets()
	self.db.profile.tPos = {l,t,r,b}
end

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
end

function addon:CombatStateChanged(unit, bInCombat)
	if unit == GameLib.GetPlayerUnit() and not self.wipeTimer then
		self.wipeTimer = self:ScheduleRepeatingTimer("WipeCheck", 0.5)
	end
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

function addon:ReportFoodToParty()
	local sWithoutFood = "Starving people (give them some food maybe?): "
	if not self.RaidFrameBase then return end
	local nStarving = 0
	for k, v in pairs(self.RaidFrameBase.arMemberIndexToWindow) do
		local sName = v.wndRaidMemberBtn:FindChild("RaidMemberName"):GetText()
		local unit = self:GetPartyMemberByName(sName)
		if unit then
			local foodStuff = self:FindBuffByName(unit, "Stuffed!")
			if not foodStuff then
				nStarving = nStarving + 1
				sWithoutFood = ("%s %s"):format(sWithoutFood, unit:GetName())
			end
		end
	end
	if nStarving > 0 then
		if (self.nTime - self.nLastPotionReport) > 5 then
			ChatSystemLib.Command(("/p %s"):format(sWithoutFood))
			self.nLastPotionReport = self.nTime
		else
			Print(("Can't spam party chat! Wait another: %.1f then try again."):format(5- self.nTime - self.nLastPotionReport))
		end
	else
		Print("Everyone is stuffed!")
	end
end

function addon:ReportPotionToParty()
	local sWithoutPotion = "Combat started 5 sec ago. Potionless (poop a poot?): "
	local sWithoutFieldTech = "Combat started 5 sec ago. FieldTechless (poop a poot?): "
	if not self.RaidFrameBase then return end
	if self.nRaidMembersInCombat < 7 then return end
	local nPotionless = 0
	local nFieldTechless = 0
	for k = 1, 40 do
		local groupMember = GroupLib.GetGroupMember(k)
		if groupMember then
			local sName = groupMember.strCharacterName
			if sName then
		--local sName = v.wndRaidMemberBtn:FindChild("RaidMemberName"):GetText()
				local unit = self:GetPartyMemberByName(sName)
				if unit then
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
			ChatSystemLib.Command(("/p %s"):format(sWithoutPotion))
			self.nLastPotionReport = self.nTime
		else
			Print(("Can't spam party chat! Wait another: %.1f then try again."):format(5- self.nTime - self.nLastPotionReport))
		end
	else
		Print("Everyone has potions!")
	end
	if nFieldTechless > 0 then
		if (self.nTime - self.self.nLastFieldTechReport) > 1 then
			ChatSystemLib.Command(("/p %s"):format(sWithoutFieldTech))
			self.nLastFieldTechReport = self.nTime
		else
			Print(("Can't spam party chat! Wait another: %.1f then try again."):format(5- self.nTime - self.self.nLastFieldTechReport))
		end
	else
		Print("Everyone has field tech!")
	end
end

function addon:OnSingleBuffButton(wHandler)
	if Apollo.IsAltKeyDown() then
		self:ReportFoodToParty()
	else
		GameLib.SetTargetUnit(wHandler:GetData())
	end
end

function addon:GetClassColor(unit)
	return self.tClassToColor[unit:GetClassId()]
end

local nOffsetFromTop = 30
local nIconSize = 21
function addon:OnUpdate()
	self.nTime = self.nTime + self.nTimerSpeed
	-- well not really hooking now are we? :D
	-- if MatchingGame.IsInPVPGame() then return end -- maybe don't show up in PvP games?
	--if not self.RaidFrameBase then self.RaidFrameBase = Apollo.GetAddon("RaidFrameBase") return end
	if not self.wBackground then return end

	local bGrouped = GameLib.GetPlayerUnit():IsInYourGroup()
	self.wBackground:Show(bGrouped)
	self.wBackground2:Show(bGrouped)
	self.wBackground3:Show(bGrouped)
	-- hide everything if we are not in a group
	if not bGrouped then
		for k = 1, 40 do
			self.tFoodIcons[k]:Show(bGrouped)
			self.tPotionIcons[k]:Show(bGrouped)
			self.tFieldTechIcons[k]:Show(bGrouped)
		end
		return
	end

	--/eval SVR("a", Apollo.GetAddon("RaidFrameBase").arMemberIndexToWindow)
	--local l,t,r,b = self.RaidFrameBase.wndMain:GetAnchorOffsets()
	local l,t,r,b = self.wAnchor:GetAnchorOffsets()

	self.wBackground:SetAnchorOffsets(l-2, t+nOffsetFromTop-2, l+nIconSize+2, t+nOffsetFromTop+GroupLib.GetMemberCount()*nIconSize+2)
	self.wBackground2:SetAnchorOffsets(l+nIconSize+2, t+nOffsetFromTop-2, l+2*nIconSize+5, t+nOffsetFromTop+GroupLib.GetMemberCount()*nIconSize+2)
	self.wBackground3:SetAnchorOffsets(l+nIconSize*2+2, t+nOffsetFromTop-2, l+3*nIconSize+5, t+nOffsetFromTop+GroupLib.GetMemberCount()*nIconSize+2)
	for k = 1, 40 do
		local groupMember = GroupLib.GetGroupMember(k)
		if groupMember then
			local sName = groupMember.strCharacterName
			if sName then
		--if self.RaidFrameBase.arMemberIndexToWindow[k] then
		--	local sName = self.RaidFrameBase.arMemberIndexToWindow[k].wndRaidMemberBtn:FindChild("RaidMemberName"):GetText()
				local unit = self:GetPartyMemberByName(sName)
				if unit then
					self.tPotionIcons[k]:SetAnchorOffsets(l+nIconSize+3, t+nOffsetFromTop+(k-1)*nIconSize, 3+l+2*nIconSize, t+nOffsetFromTop+k*nIconSize)
					self.tFieldTechIcons[k]:SetAnchorOffsets(l+nIconSize*2+3, t+nOffsetFromTop+(k-1)*nIconSize, 3+l+3*nIconSize, t+nOffsetFromTop+k*nIconSize)
					local foodStuff = self:FindBuffByName(unit, "Stuffed!")
					self.tFoodIcons[k]:SetAnchorOffsets(l, t+nOffsetFromTop+(k-1)*nIconSize, l+nIconSize, t+nOffsetFromTop+k*nIconSize)
					self.tFoodIcons[k]:Show(bGrouped)
					self.tFoodIcons[k]:SetData(unit)
					if foodStuff then
						self.tFoodIcons[k]:SetSprite(foodStuff[1])
						self.tFoodIcons[k]:SetTooltip(sName.." - "..foodStuff[2])
					else
						self.tFoodIcons[k]:SetSprite(unit:IsDead() and "CRB_GuildSprites:sprGuild_Skull" or "ClientSprites:LootCloseBox_Holo")
						self.tFoodIcons[k]:SetTooltip(sName)
					end

					local potionStuff = self:FindBuffFromListByName(unit, tBuffList)

					self.tPotionIcons[k]:Show(bGrouped)
					self.tPotionIcons[k]:SetData(unit)
					if potionStuff then
						self.tPotionIcons[k]:SetSprite(potionStuff[1])
						self.tPotionIcons[k]:SetTooltip(sName.." - "..potionStuff[2])
						self.tPotionIcons[k]:FindChild("Name"):SetText("")
					else
						self.tPotionIcons[k]:SetSprite(unit:IsDead() and "CRB_GuildSprites:sprGuild_Skull" or "ClientSprites:LootCloseBox_Holo")
						self.tPotionIcons[k]:SetTooltip(sName)
					end

					local fieldTechStuff = self:FindBuffFromListByName(unit, tFieldTechBuffList)

					self.tFieldTechIcons[k]:Show(bGrouped)
					self.tFieldTechIcons[k]:SetData(unit)
					if fieldTechStuff then
						self.tFieldTechIcons[k]:SetSprite(fieldTechStuff[1])
						self.tFieldTechIcons[k]:SetTooltip(sName.." - "..fieldTechStuff[2])
						self.tFieldTechIcons[k]:FindChild("Name"):SetText("")
					else
						self.tFieldTechIcons[k]:SetSprite(unit:IsDead() and "CRB_GuildSprites:sprGuild_Skull" or "ClientSprites:LootCloseBox_Holo")
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

	if self.bRaidInCombat and self.bRaidInCombat ~= self.bRaidInCombatLastState then
		self:ScheduleTimer("ReportPotionToParty", 5)
		self.bRaidInCombatLastState = self.bRaidInCombat
	end
end