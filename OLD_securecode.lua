--[[
	This file contains partially-complete code for adding sets to TimekeeperParent's secure environment.
	It's currently not loaded, but I may use it if I need to show/hide frames in combat.
]]

TimekeeperParent:SetAttribute("NewSet", [==[
	CURRENTSET = newtable()
	SETS[self:GetAttribute("_setname")] = CURRENTSET
]==])

TimekeeperParent:SetAttribute("AddGroup", [==[
	local group = newtable(strsplit("~", self:GetAttribute("_groupvals")))
	CURRENTSET[self:GetAttribute("_groupid")] = group
]==])

function TimekeeperParent:NewSet(setName)
	self:SetAttribute("_setname", setName)
	self:Execute("NewSet")
end

function TimekeeperParent:AddGroup(groupID, group)
	self:SetAttribute("_groupid", tostring(groupID))
	self:SetAttribute("_groupvals", table.concat(group, "~"))
	self:Execute("AddGroup")
end

TimekeeperParent:SetAttribute("_onattributechanged", [==[ -- Arguments: self, name, value
	local set = SETS[name]
	
]==])