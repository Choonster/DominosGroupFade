--[[
Format:
	["SETNAME"] = {
		conditional = "[harm][dead]fadein;fadeout",
		{1, 2, 4},   -- Group 1
		{3, 7, 6},   -- Group 2
		{5, 10, 11}, -- Group 3
	},
	
Each set (which must have a unique case-insensitive name) consists of one or more groups of frame numbers and a string describing the conditions under which the frames in the set should fade in and out.
The first group in a set will fade in first and fade out last. The last group in a set will fade in last and fade out first.
The frames in each group will fade in and out simultaneously.
]]

local FRAME_SETS = {
    ["SETONE"] = {
		conditional = "[combat]fadein;fadeout",
		{7, 15, 19},
		{4, 5, 6, 8, 9, 10},
		{2, 3, 11, 12, 14, 16, 17, 18},
		{1, 13},
	},
}

-- The duration in seconds of each fade animation
local FADE_DURATION = 0.5

-- The delay in seconds between the start of each group's fade animation
local FADE_DELAY = 0.4

-------------------
-- END OF CONFIG --
-------------------

-- List globals here for Mikk's FindGlobals script
-- GLOBALS: InCombatLockdown

local pairs = pairs
local Dominos_Frame = Dominos.Frame

local FramesToHide = {}
local FramesToShow = {}

------
-- Group scripts
------
local function GroupFadeIn_OnPlay(self)
	local group = self.group
	for i = 1, #group do
		Dominos_Frame:Get(group[i]).fadeIn:Play()
	end
end

local function GroupFadeOut_OnPlay(self)
	local group = self.group
	for i = 1, #group do
		Dominos_Frame:Get(group[i]).fadeOut:Play()
	end
end

------
-- Frame scripts
------
local function FrameFadeIn_OnPlay(self)
	local frame = self:GetParent()
	if InCombatLockdown() then
		FramesToShow[frame] = true
	else
		FramesToHide[frame] = nil
		frame:ShowFrame()
	end
end

local function FrameFadeOut_OnFinished(self)
	local frame = self:GetParent()
	frame:SetAlpha(0)
	
	if InCombatLockdown() then
		FramesToHide[frame] = true
	else
		FramesToShow[frame] = nil
		frame:HideFrame()
	end
end

------
-- Initialisation
------
local function CreateGroupFader(timekeeper, order, group, onPlayFunc)
	local fader = timekeeper:CreateAnimation("Animation")
	fader:SetOrder(order)
	fader.group = group
	fader:SetScript("OnPlay", onPlayFunc)
	fader:SetDuration(FADE_DELAY)
	return fader
end

local function CreateFrameFader(frame, change, scriptName, scriptFunc)
	local animGroup = frame:CreateAnimationGroup()
	animGroup.animation = animGroup:CreateAnimation("Alpha")
	animGroup.animation:SetDuration(FADE_DURATION)
	animGroup.animation:SetChange(change)
	animGroup.animation:SetScript(scriptName, scriptFunc)
	return animGroup
end

local TimekeeperParent = CreateFrame("Frame", nil, nil, "SecureHandlerAttributeTemplate")
local FadeInTimekeepers = {}
local FadeOutTimekeepers = {}

TimekeeperParent:RegisterEvent("PLAYER_REGEN_ENABLED")
TimekeeperParent:SetScript("OnEvent", function(self, event, ...)
	for frame, _ in pairs(FramesToShow) do
		frame:ShowFrame()
		FramesToShow[frame] = nil
	end
	
	for frame, _ in pairs(FramesToHide) do
		frame:HideFrame()
		FramesToHide[frame] = nil
	end
end)

for setName, set in pairs(FRAME_SETS) do
	setName = setName:upper()
	
	local FadeInTimekeeper = TimekeeperParent:CreateAnimationGroup()
	FadeInTimekeeper.animations = {}
	FadeInTimekeepers[setName] = FadeInTimekeeper
	
	local FadeOutTimekeeper = TimekeeperParent:CreateAnimationGroup()
	FadeOutTimekeeper.animations = {}
	FadeOutTimekeepers[setName] = FadeOutTimekeeper

	RegisterAttributeDriver(TimekeeperParent, setName, set.conditional)

	local numGroups = #set
	for groupID, group in ipairs(set) do
		FadeInTimekeeper.animations[groupID] = CreateGroupFader(FadeInTimekeeper, groupID, group, GroupFadeIn_OnPlay)
		
		-- Add 1 to the order argument so it's in the range [1,numGroups] instead of [0,numGroups-1]
		FadeOutTimekeeper.animations[groupID] = CreateGroupFader(FadeOutTimekeeper, numGroups - groupID + 1, group, GroupFadeOut_OnPlay)
	end
end

hooksecurefunc(Dominos_Frame, "Create", function(self, id)
	local frame = Dominos_Frame:Get(id)
	
	frame.fadeIn = CreateFrameFader(frame, 1, "OnPlay", FrameFadeIn_OnPlay)
	frame.fadeOut = CreateFrameFader(frame, -1, "OnFinished", FrameFadeOut_OnFinished)
end)