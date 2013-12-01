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
		conditional = "[mod:lshift,mod:lalt][@target,nodead,harm]fadein;fadeout",
		{7},
		{5, 6, 8, 9, 15, 19, 24},
		{4, 10, 14, 16, 17, 18, 23, 25},
		{2, 3, 11, 12, 21, 22, 26, 27},
		{1, 13, 20, 28},
	},
}

-- The duration in seconds of each fade animation
local FADE_DURATION = 0.5

-- The delay in seconds between the start of each group's fade animation
local FADE_DELAY = 0.5

-------------------
-- END OF CONFIG --
-------------------

-- List globals here for Mikk's FindGlobals script
-- GLOBALS: InCombatLockdown, SecureCmdOptionParse

local printargs = {}
local function PRINT(self, format, ...)
	if self.id == 1 or self.id == 24 then
		local numArgs = select("#", ...)
		for i = 1, numArgs do
			local arg = select(i, ...)
			if type(arg) == "boolean" or arg == nil then
				printargs[i] = arg and "|cff00FFFFYes|r" or "|cff0011FFNo|r"
			else
				printargs[i] = tostring(arg)
			end
		end

		print(self:GetName(), format:format(unpack(printargs, 1, numArgs)))
	end
end

local ipairs, pairs = ipairs, pairs
local Dominos_Frame = Dominos.Frame

------
-- Group timekeeper Animation scripts
------
local function GroupFadeIn_OnPlay(self)
	local group = self.group
	for i = 1, #group do
		local frame = Dominos_Frame:Get(group[i])
		if frame then
			frame:FadeIn(false, true)
		end
	end
end

local function GroupFadeOut_OnPlay(self)
	local group = self.group
	for i = 1, #group do
		local frame = Dominos_Frame:Get(group[i])
		if frame then
			frame:FadeOut(false)
		end
	end
end

------
-- Frame methods
------
local FrameMethods = {}

-- Overrides the Dominos Frame:Fade() method. Called by the Dominos fade manager when the frame gains or loses mouse focus.
function FrameMethods:Fade()
	PRINT(self, "Frame:Fade() Conditional? %s. Focused? %s", self.conditionalFadeIn, self.focused)
	-- If the most recent fade was a fade in triggered by a conditional update, ignore mouse focus
	if self.conditionalFadeIn then return end

	if self.focused then
		self:FadeIn(false, false)
	else
		self:FadeOut(false)
	end
end

-- Fades in a frame.
-- The conditionalFadeIn argument will be true for fades triggered by a conditional update and false for fades triggered by mouse focus.
function FrameMethods:FadeIn(delay, conditionalFadeIn)
	self.conditionalFadeIn = conditionalFadeIn

	-- self.fadeIn.animation:SetStartDelay(delay and 0.001 or 0)

	if self:IsFadingOut() then -- If the frame is currently fading out, fade in when it completes
		PRINT(self, "|cffFF0000Queued fade in. Delay? %s|r", delay)
		self.needsFadeIn = true
	else -- Otherwise fade in now
		PRINT(self, "Fade in started. Delay? %s", delay)
		self.fadeIn:Play()
	end
end

-- Fades out a frame.
function FrameMethods:FadeOut(delay)
	self.conditionalFadeIn = nil

	-- self.fadeOut.animation:SetStartDelay(delay and 0.001 or 0)

	if self:IsFadingIn() then -- If the frame is currently fading in, fade out when it completes
		PRINT(self, "|cffFF0000Queued fade out. Delay? %s|r", delay)
		self.needsFadeOut = true
	else -- Otherwise fade out now
		PRINT(self, "Fade out started. Delay? %s", delay)
		self.fadeOut:Play()
	end
end

-- Is the frame fading in?
function FrameMethods:IsFadingIn()
	return self.fadeIn:IsPlaying()
end

-- Is the frame fading out?
function FrameMethods:IsFadingOut()
	return self.fadeOut:IsPlaying()
end

------
-- Frame fader AnimationGroup scripts
------
local function FrameFadeIn_OnPlay(self)
	local frame = self:GetParent()
	frame.needsFadeIn = false

	PRINT(frame, "Fading in")

	if not InCombatLockdown and not frame:FrameIsShown() then
		frame:ShowFrame()
	end
end

local function FrameFadeIn_OnFinished(self)
	local frame = self:GetParent()
	frame:SetAlpha(1)

	PRINT(frame, "Fade in complete. IsFadingIn? %s Needs fade out? %s", frame:IsFadingIn(), frame.needsFadeOut)

	if frame.needsFadeOut then -- If we're waiting for a fade out, fade out now
		frame:FadeOut(true)
	end
end

local function FrameFadeOut_OnPlay(self)
	local frame = self:GetParent()
	frame.needsFadeOut = false

	PRINT(frame, "Fading out")
end

local function FrameFadeOut_OnFinished(self)
	local frame = self:GetParent()
	frame:SetAlpha(0)

	PRINT(frame, "Fade out complete. IsFadingOut? %s Needs fade in? %s", frame:IsFadingOut(), frame.needsFadeIn)

	if frame.needsFadeIn then -- If we're waiting for a fade in, fade in now
		frame:FadeIn(true, true)
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

TKP = TimekeeperParent

TimekeeperParent:SetScript("OnAttributeChanged", function(self, name, value)
	print("OAC", name, value)
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

for setName, set in pairs(FRAME_SETS) do
	setName = setName:lower()

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

hooksecurefunc(Dominos_Frame, "New", function(self, id)
	local frame = Dominos_Frame:Get(id)
	if not frame.hasFadeInOut then
		frame.hasFadeInOut = true
		frame.fadeIn = CreateFrameFader(frame, 1, FrameFadeIn_OnPlay, FrameFadeIn_OnFinished)
		frame.fadeOut = CreateFrameFader(frame, -1, nil, FrameFadeOut_OnFinished)

		for name, method in pairs(FrameMethods) do -- Copy all frame methods into the frame
			frame[name] = method
		end
	end

	TimekeeperParent:ForceUpdate()
end)