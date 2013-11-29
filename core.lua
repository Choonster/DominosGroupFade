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

local ipairs, pairs = ipairs, pairs
local Dominos_Frame = Dominos.Frame

local FramesToHide = {}
local FramesToShow = {}

-- Returns a match when a conditional string uses `fadein` with the [combat] conditional
local CombatFadeInPattern = "[%[,]combat[%],]%[?[^;]*%]?fadein"

-- Sets that need to fade in in combat
local NumCombatFadeInSets = 0
local CombatFadeInSets = {}

------
-- Set methods
------
local function Set_ShowAll(self)
	for groupID = 1, #self do
		self[groupID]:ShowAll()
	end
end

------
-- Group methods
------
local function Group_ShowAll(self)
	for i = 1, #self do
		Dominos_Frame:Get(self[i]):ShowFrame()
	end
end

------
-- Group scripts
------
local function GroupFadeIn_OnPlay(self)
	local group = self.group
	for i = 1, #group do
		local frame = Dominos_Frame:Get(group[i])
		if frame then
			frame:FadeIn(true)
		end
	end
end

local function GroupFadeOut_OnPlay(self)
	local group = self.group
	for i = 1, #group do
		local frame = Dominos_Frame:Get(group[i])
		if frame then
			frame:FadeOut()
		end
	end
end

------
-- Frame methods
------
local function Frame_Fade(self)
	if self.fadeConditional then return end
	
	if self.focused then
		self:FadeIn(false)
	else
		self:FadeOut()
	end
end

local function Frame_FadeIn(self, fadeConditional)
	self.fadeConditional = fadeConditional
	self.fadeIn:Play()
end

local function Frame_FadeOut(self)
	self.fadeConditional = false
	self.fadeOut:Play()
end

------
-- Frame scripts
------
local function FrameFadeIn_OnPlay(self)
	local frame = self:GetParent()
	if not InCombatLockdown and not frame:FrameIsShown() then
		frame:ShowFrame()
	end
end

local function FrameFadeIn_OnFinished(self)
	self:GetParent():SetAlpha(1)
end

local function FrameFadeOut_OnFinished(self)
	local frame = self:GetParent()
	frame:SetAlpha(0)

	-- if InCombatLockdown() then
		-- FramesToHide[frame] = true
	-- else
		-- FramesToShow[frame] = nil
		-- frame:HideFrame()
	-- end
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

local function CreateFrameFader(frame, change, onPlayFunc, onFinishedFunc)
	local animGroup = frame:CreateAnimationGroup()
	animGroup.animation = animGroup:CreateAnimation("Alpha")
	animGroup.animation:SetDuration(FADE_DURATION)
	animGroup.animation:SetChange(change)
	animGroup:SetScript("OnPlay", onPlayFunc)
	animGroup:SetScript("OnFinished", onFinishedFunc)
	return animGroup
end

local TimekeeperParent = CreateFrame("Frame")
local FadeInTimekeepers = {}
local FadeOutTimekeepers = {}

TimekeeperParent:SetScript("OnAttributeChanged", function(self, name, value)
	print("OAC", self, name, value)
	if value == "fadein" then
		FadeInTimekeepers[name]:Play()
	elseif value == "fadeout" then
		FadeOutTimekeepers[name]:Play()
	end
end)

function TimekeeperParent:ForceUpdate()
	for setName, set in pairs(FRAME_SETS) do
		self:SetAttribute(setName:lower(), SecureCmdOptionParse(set.conditional))
	end
end

TimekeeperParent:RegisterEvent("PLAYER_REGEN_DISABLED")
TimekeeperParent:RegisterEvent("PLAYER_REGEN_ENABLED")
TimekeeperParent:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)

-- Pre-show all frames that need to fade in in combat just before it starts
function TimekeeperParent:PLAYER_REGEN_DISABLED()
	for i = 1, NumCombatFadeInSets do
		CombatFadeInSets[i]:ShowAll()
	end
end

-- When combat ends, show/hide any frames that were meant to show/hide during combat
function TimekeeperParent:PLAYER_REGEN_ENABLED()
	for frame, _ in pairs(FramesToShow) do
		frame:ShowFrame()
		FramesToShow[frame] = nil
	end

	for frame, _ in pairs(FramesToHide) do
		frame:HideFrame()
		FramesToHide[frame] = nil
	end
end

for setName, set in pairs(FRAME_SETS) do
	setName = setName:lower()

	set.ShowAll = Set_ShowAll

	local FadeInTimekeeper = TimekeeperParent:CreateAnimationGroup()
	FadeInTimekeeper.animations = {}
	FadeInTimekeepers[setName] = FadeInTimekeeper

	local FadeOutTimekeeper = TimekeeperParent:CreateAnimationGroup()
	FadeOutTimekeeper.animations = {}
	FadeOutTimekeepers[setName] = FadeOutTimekeeper

	RegisterAttributeDriver(TimekeeperParent, setName, set.conditional)

	if set.conditional:find(CombatFadeInPattern) then
		NumCombatFadeInSets = NumCombatFadeInSets + 1
		CombatFadeInSets[NumCombatFadeInSets] = set
	end

	local numGroups = #set
	for groupID, group in ipairs(set) do
		group.ShowAll = Group_ShowAll

		FadeInTimekeeper.animations[groupID] = CreateGroupFader(FadeInTimekeeper, groupID, group, GroupFadeIn_OnPlay)

		-- Add 1 to the order argument so it's in the range [1,numGroups] instead of [0,numGroups-1]
		FadeOutTimekeeper.animations[groupID] = CreateGroupFader(FadeOutTimekeeper, numGroups - groupID + 1, group, GroupFadeOut_OnPlay)
	end
end

hooksecurefunc(Dominos_Frame, "New", function(self, id)
	local frame = Dominos_Frame:Get(id)
	if not frame.hasFadeInOut then
		frame.hasFadeInOut = true
		frame.fadeIn = CreateFrameFader(frame, 1, FrameFadeIn_OnPlay, FrameFadeIn_OnFinished)
		frame.fadeOut = CreateFrameFader(frame, -1, nil, FrameFadeOut_OnFinished)
		
		frame.Fade = Frame_Fade
		frame.FadeIn = Frame_FadeIn
		frame.FadeOut = Frame_FadeOut
	end

	TimekeeperParent:ForceUpdate()
end)