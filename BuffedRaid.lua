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

local sVersion = "8.0.0.2"

local MatchingGame = MatchingGame
local GameLib = GameLib
local ChatSystemLib = ChatSystemLib
local GroupLib = GroupLib
local Apollo = Apollo
local ApolloColor = ApolloColor
local Print = Print
local pairs = pairs
local ipairs = ipairs

local addon = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon("BuffedRaid", false, {}, "Gemini:Timer-1.0")

function addon:OnEnable()
	self.tClassToColor = {
	-- Colors apparently defined by Duran by a forum post by Orbish who never got back to us with hex codes
	--[[Warrior]] ApolloColor.new("ffde1818"),	-- Warrior
	--[[Engineer]] ApolloColor.new("fffae843"),	-- Yellow (Web Icon)
	--[[Esper]] ApolloColor.new("ff07a8df"),	-- Esper
	--[[Medic]] ApolloColor.new("ff96cd18"),	-- Green (Web Icon)
	--[[Stalker]] ApolloColor.new("ffb137f6"),	-- Stalker
	ApolloColor.new("ffffffff"),	-- Corrupted
	--[[Spellslinger]] ApolloColor.new("ffec8626"),	-- Orange (Web Icon)
	}
	self.RaidFrameBase = Apollo.GetAddon("RaidFrameBase")

	self.wBackground = Apollo.LoadForm("BuffedRaid.xml", "Background", nil, self)
	self.wBackground:Show(true)
	self.wBackground2 = Apollo.LoadForm("BuffedRaid.xml", "Background", nil, self)
	self.wBackground2:Show(true)
	self.wBackground3 = Apollo.LoadForm("BuffedRaid.xml", "Background", nil, self)
	self.wBackground3:Show(true)
	self.nTime = 0
	self.nTimerSpeed = 1
	self.nLastReport = 0
	self:ScheduleRepeatingTimer("HookToRaidFrame", self.nTimerSpeed)
	self.tFoodIcons = {}
	for i= 1, 40 do
		self.tFoodIcons[i] = Apollo.LoadForm("BuffedRaid.xml", "SingleBuff", nil, self)
		self.tFoodIcons[i]:Show(false)
	end
	self.tPotionIcons = {}
	for i= 1, 40 do
		self.tPotionIcons[i] = Apollo.LoadForm("BuffedRaid.xml", "SingleBuff", nil, self)
		self.tPotionIcons[i]:Show(false)
	end
	self.tFieldTechIcons = {}
	for i= 1, 40 do
		self.tFieldTechIcons[i] = Apollo.LoadForm("BuffedRaid.xml", "SingleBuff", nil, self)
		self.tFieldTechIcons[i]:Show(false)
	end
	Apollo.RegisterEventHandler("UnitEnteredCombat", "CombatStateChanged", self)
	self.bRaidInCombat = false
	self.nRaidMembersInCombat = 0
	self.bRaidInCombatLastState = false
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
	for k, sBuff in pairs(tBuffList) do
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
		if (self.nTime - self.nLastReport) > 5 then
			ChatSystemLib.Command(("/p %s"):format(sWithoutFood))
			self.nLastReport = self.nTime
		else
			Print(("Can't spam party chat! Wait another: %.1f then try again."):format(5- self.nTime - self.nLastReport))
		end
	else
		Print("Everyone is stuffed!")
	end
end

function addon:ReportPotionToParty()
	local sWithoutPotion = "Combat started 5 sec ago. Potionless (poop a poot?): "
	if not self.RaidFrameBase then return end
	if self.nRaidMembersInCombat < 7 then return end
	local nPotionless = 0
	for k, v in pairs(self.RaidFrameBase.arMemberIndexToWindow) do
		local sName = v.wndRaidMemberBtn:FindChild("RaidMemberName"):GetText()
		local unit = self:GetPartyMemberByName(sName)
		if unit then
			local potionStuff = self:FindBuffFromListByName(unit, tBuffList)
			if not potionStuff then
				nPotionless = nPotionless + 1
				sWithoutPotion = ("%s %s"):format(sWithoutPotion, unit:GetName())
			end
		end
	end
	if nPotionless > 0 then
		if (self.nTime - self.nLastReport) > 1 then
			ChatSystemLib.Command(("/p %s"):format(sWithoutPotion))
			self.nLastReport = self.nTime
		else
			Print(("Can't spam party chat! Wait another: %.1f then try again."):format(5- self.nTime - self.nLastReport))
		end
	else
		Print("Everyone has potions!")
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

local nOffsetFromTop = 100
local nIconSize = 21
function addon:HookToRaidFrame()
	self.nTime = self.nTime + self.nTimerSpeed
	-- well not really hooking now are we? :D
	-- if MatchingGame.IsInPVPGame() then return end -- maybe don't show up in PvP games?
	if not self.RaidFrameBase then self.RaidFrameBase = Apollo.GetAddon("RaidFrameBase") return end
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
	local l,t,r,b = self.RaidFrameBase.wndMain:GetAnchorOffsets()
	self.wBackground:SetAnchorOffsets(r-2, t+nOffsetFromTop-2, r+nIconSize+2, t+nOffsetFromTop+#self.RaidFrameBase.arMemberIndexToWindow*nIconSize+2)
	self.wBackground2:SetAnchorOffsets(r+nIconSize+2, t+nOffsetFromTop-2, r+2*nIconSize+5, t+nOffsetFromTop+#self.RaidFrameBase.arMemberIndexToWindow*nIconSize+2)
	self.wBackground3:SetAnchorOffsets(r+nIconSize*2+2, t+nOffsetFromTop-2, r+3*nIconSize+5, t+nOffsetFromTop+#self.RaidFrameBase.arMemberIndexToWindow*nIconSize+2)
	for k = 1, 40 do
		if self.RaidFrameBase.arMemberIndexToWindow[k] then
			local sName = self.RaidFrameBase.arMemberIndexToWindow[k].wndRaidMemberBtn:FindChild("RaidMemberName"):GetText()
			local unit = self:GetPartyMemberByName(sName)
			if unit then
				self.tPotionIcons[k]:SetAnchorOffsets(r+nIconSize+3, t+nOffsetFromTop+(k-1)*nIconSize, 3+r+2*nIconSize, t+nOffsetFromTop+k*nIconSize)
				self.tFieldTechIcons[k]:SetAnchorOffsets(r+nIconSize*2+3, t+nOffsetFromTop+(k-1)*nIconSize, 3+r+3*nIconSize, t+nOffsetFromTop+k*nIconSize)
				local foodStuff = self:FindBuffByName(unit, "Stuffed!")
				self.tFoodIcons[k]:SetAnchorOffsets(r, t+nOffsetFromTop+(k-1)*nIconSize, r+nIconSize, t+nOffsetFromTop+k*nIconSize)
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
		else
			self.tFoodIcons[k]:Show(false)
		end
	end

	if self.bRaidInCombat and self.bRaidInCombat ~= self.bRaidInCombatLastState then
		self:ScheduleTimer("ReportPotionToParty", 5)
		self.bRaidInCombatLastState = self.bRaidInCombat
	end
end
