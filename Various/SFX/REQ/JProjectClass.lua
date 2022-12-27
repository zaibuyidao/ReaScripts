--[[
@author n0ne
@version 0.7.0
@noindex
--]]

-- J_SCRIPT_DIR = reaper.GetResourcePath() .. "/Scripts/LUA/"
-- package.path = package.path .. ";" .. J_SCRIPT_DIR .. "?.lua"
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"
require ('REQ.JProjectClassReq')

-- TODO:
-- Make the new index functions so that if its not in one of the lists or in .prototype to show an error msg


local JParam = {}
JParam.mt = {}
JParam.prototype = {iParam = false, _parent = false}

function JParam:new(o)
    local o = o or {}
    setmetatable(o, JParam.mt)
    return o
end

JParam.mt.__index = function (self, key, args)
    -- msg("looking in fx for: " .. key)
    --msg(table._parent.pTrack)
    if key == "name" then
		local _, r = reaper.TrackFX_GetParamName(self:getTrack(), self:getFx(), self.iParam, "")
		return r
    end
    return JParam.prototype[key]
end

function JParam.prototype:getTrack()
	-- Returns the reaper MediaTrack pointer to the track that the FX belongs to for which this is a paramater
	return self._parent:getTrack() -- Returns parent FX
end

function JParam.prototype:getFx()
	-- Returns the index of the FX for which this is a paramater
	return self._parent.iFx
end

function JParam.prototype:set(value)
	-- Set the parameter
	-- Returns reaper's bolean value for succes or not
	return reaper.TrackFX_SetParam(self:getTrack():getReaperTrack(), self:getFx(), self.iParam, value)
end

function JParam.prototype:setNormalized(value)
	-- Set the NORMALIZED parameter
	-- Returns reaper's bolean value for succes or not
	return reaper.TrackFX_SetParamNormalized(self:getTrack():getReaperTrack(), self:getFx(), self.iParam, value)
end

-- FX
-- This is an FX class. It can be created bt a Track class. It holds a reference to its parent Track class.
-- It should be noted that in reaper an actual effect is linked to a JTrack. I.e. an FX can't excist without its parent JTrack.
-- Here an instance of this FX class could still live while its parent track was deleted. It wouldnt know. However when calling
-- most functions in this class the pointer to the parent track would be pointing to nothing which will result in errors.
-- Because there are some usages advantages to having a seperate FX class this implementation was chosen. Mostly because
-- it makes it a lot easier to find a certain fx (either by name or index) and then do multiple things with this JFx.
JFx = {}
JFx.mt = {}
JFx.prototype = {iFx = false, _parent = false}

function JFx:new(o)
    local o = o or {}
    setmetatable(o, JFx.mt)
    return o
end

JFx.mt.__index = function (self, key, args)
    -- msg("looking in fx for: " .. key)
    -- msg(table._parent.pTrack)
    if key == "name" then
		local _, r = reaper.TrackFX_GetFXName(self:getTrack():getReaperTrack(), self.iFx, "")
		return r
	elseif key == "paramcount" then
		return reaper.TrackFX_GetNumParams(self:getTrack():getReaperTrack(), self.iFx)
	elseif key == "enabled" then
		return reaper.TrackFX_GetEnabled(self:getTrack():getReaperTrack(), self.iFx)
	end
    return JFx.prototype[key]
end

JFx.mt.__newindex = function (self, key, value)
	if key == "enabled" then
		return reaper.TrackFX_SetEnabled(self:getTrack():getReaperTrack(), self.iFx, value)
    else
        rawset(table, key, value)
    end
end

function JFx.prototype:getTrack()
	-- Returns the reaper MediaTrack pointer to the track that the FX belongs to
	-- TODO?: Should this remain a direct access or should this turn into a function that also checks if the track still exists?
	-- TODO?: Should this not just return a JTrack object?
	return self._parent
end

function JFx.prototype:show(showFlag)
	-- Shows the floating window. 
	-- Showflag can be used to use reaper functionality to show it with the chain (or even to hide it)
	showFlag = showFlag or 3
	reaper.TrackFX_Show(self:getTrack():getReaperTrack(), self.iFx, showFlag)
	return true
end

function JFx.prototype:hide()
	reaper.TrackFX_Show(self:getTrack():getReaperTrack(), self.iFx, 2)
	return true
end

function JFx.prototype:getParam(iParam)
	-- Get an fx parameter by number, 0 for the first
	-- Returns number retval, number minval, number maxval
	--[[ SAFETY CHECK?
	if iParam >= self.paramcount then
		jError("JFx:getParam(), effect param not found, iParam: " .. tostring(iParam), J_ERROR_WARNING) 
		return false
	end
	]]
	retval, minval, maxval = reaper.TrackFX_GetParam(self:getTrack():getReaperTrack(), self.iFx, iParam)
	local p = JParam:new({iParam = iParam, value = retval, minval = minval, maxval = maxval, _parent = self})
	return p
end

function JFx.prototype:setParam(iParam, value)
	-- Directly set an FX's parameter, can be handy sometimes
	return reaper.TrackFX_SetParam(self:getTrack():getReaperTrack(), self.iFx, iParam, value)	
end

function JFx.prototype:params(start, num)
	-- Iterator to go through all the tracks in the project
	-- start: index of the track to start at
	-- num: (maximum) amount of track to return
	local i = start or 0
	local n = 0
	if num and i + num <= self.paramcount then
		n = i + num
	else
		n = self.paramcount
	end

	return function ()
		i = i + 1
		if i <= n then 
			return self:getParam(i-1) 
		end
	end
end

function JFx.prototype:getParamsByName(sPattern, iInstance, find_init, find_plain)
    -- Search by name
	-- sPattern: Specify pattern to look for
	-- iInstance: leave empty (or false) to get a TABLE of all the tracks that match the pattern. Specify a number > 0 to get the nth track that matches
	-- The default searches from the first character (find_init = 1) and uses plain string (find_plain = true). See Lua's string.find() for more info

	local iInstance = iInstance or false
	local find_init = find_init or 1
	local find_plain = find_plain or true

    local tResult = {}
    local iCount = 0
    
	if type(iInstance) == "number" and iInstance <= 0 then 
		jError("JFx:getParamsByName(), instance <= 0. First instance is 1! iInstance: " .. tostring(iInstance), J_ERROR_ERROR) 
		return false
	end	
	
    local iTracks = self.trackcount
	
	for t in self:params() do
		if t.name:lower():find(sPattern:lower(), find_init, find_plain) then
			iCount = iCount + 1
            if iInstance == false then
                tResult[#tResult + 1] = t
            elseif iInstance == iCount then
                return t
            end
        end
    end
    
    if not iInstance then
        -- return table
        if #tResult == 0 then
            return false
        else
            return tResult
        end
    else
        -- instance not found
        return false
    end
end

-- SEND
JSend = {}
JSend.mt = {}
JSend.prototype = {iSend = false, category = 0, _parent = false}

function JSend:new(o)
    local o = o or {}
    setmetatable(o, JSend.mt)
    return o
end

JSend.mt.__index = function (self, key)
    if TRACK_SEND_GET_INFO_VALUES[key] ~= nil then
        if not self.iSend then
			jError("JSend not initialized", J_ERROR_ERROR)
            return false
        end
        return reaper.GetTrackSendInfo_Value(self:getTrack():getReaperTrack(), self.category, self.iSend, TRACK_SEND_GET_INFO_VALUES[key])
	elseif key == "name" then
		local _, v = reaper.GetTrackSendName(self:getTrack():getReaperTrack(), self.iSend, "")
		return v
	elseif JSend.prototype[key] ~= nil then
		return JSend.prototype[key]
	else
		jError("JSend key: ''" .. key .. "'' is not a GET property", J_ERROR_ERROR)
		return false
    end

end

JSend.mt.__newindex = function (self, key, value)
    if TRACK_SEND_SET_INFO_VALUES[key] ~= nil then
        if not self.iSend then
			jError("JSend not initialized", J_ERROR_ERROR)
            return false
        end
        reaper.SetTrackSendInfo_Value(self:getTrack():getReaperTrack(), self.category, self.iSend, TRACK_SEND_GET_INFO_VALUES[key], value)
	elseif JItem.prototype[key] ~= nil then
		rawset(self, key, value)
	else
		jError("JSend key: ''" .. key .. "'' is not a SET property", J_ERROR_ERROR)
		return false
	end
end

function JSend.prototype:getTrack() -- Returns the track the send belongs to
	return self._parent -- This used to return self._partent.pTrack but its better if it just returns the track instead of the pTrack
end

function JSend.prototype:getDestTrack()
	return JTrack:new(reaper.BR_GetMediaTrackSendInfo_Track(self:getTrack():getReaperTrack(), 0, self.iSend, 1))
end

function JSend.prototype:delete()
	local r = reaper.RemoveTrackSend(self:getTrack():getReaperTrack(), self.category, self.iSend)
	if not r then
		jError("Deleting send failed, index: " .. self.iSend, J_ERROR_ERROR)
	end
	return r
end
-- TRACK
-- This is a Track "class". It can be created by a Project class and is linked to a track in reaper by its MediaTrack pointer.
JTrack = {fx = {}}
JTrack.prototype = {pTrack = false, _parentProject = false}
JTrack.mt = {}

function JTrack:new(input)
	local o
	if type(input) == "table" then
		o = input
	elseif input == nil then
		o = {}
	else
		o = {pTrack = input}
	end
	setmetatable(o, JTrack.mt)    
	return o
end

JTrack.mt.__index = function (self, key)
    if MEDIA_TRACK_GET_INFO_VALUES[key] ~= nil then
        if not self.pTrack then
            --msg("Track not initialized!")
            return false
        end
        return reaper.GetMediaTrackInfo_Value(self.pTrack, MEDIA_TRACK_GET_INFO_VALUES[key])
    elseif MEDIA_TRACK_GET_SET_INFO_STRINGS[key] ~= nil then
        if not self.pTrack then
            --msg("Track not initialized!")
            return false
        end
        local _, r = reaper.GetSetMediaTrackInfo_String(self.pTrack, MEDIA_TRACK_GET_SET_INFO_STRINGS[key], "", false)
        return r
    elseif key == "fxcount" then
        return reaper.TrackFX_GetCount(self.pTrack)
    elseif key == "sendcount" then
		return reaper.GetTrackNumSends(self.pTrack, 0)
	elseif key == "receivecount" then
		return reaper.GetTrackNumSends(self.pTrack, -1)
	elseif key == "hardwareoutcount" then
		return reaper.GetTrackNumSends(self.pTrack, 1)
	elseif key == "itemcount" then
		return reaper.GetTrackNumMediaItems(self.pTrack)
	end

    return JTrack.prototype[key]

end

JTrack.mt.__newindex = function (table, key, value)
    if MEDIA_TRACK_SET_INFO_VALUES[key] ~= nil then
        if not table.pTrack then
            --msg("Track not initialized!")
            return false
        end
        reaper.SetMediaTrackInfo_Value(table.pTrack, MEDIA_TRACK_SET_INFO_VALUES[key], value)
    elseif MEDIA_TRACK_GET_SET_INFO_STRINGS[key] ~= nil then
        if not table.pTrack then
            --msg("Track not initialized!")
            return false
        end
        reaper.GetSetMediaTrackInfo_String(table.pTrack, MEDIA_TRACK_GET_SET_INFO_STRINGS[key], value, true)
    else
        rawset(table, key, value)
    end
end

function JTrack.prototype:getReaperTrack()
	return self.pTrack
end

function JTrack.prototype:getItem(idx)
	local i = reaper.GetTrackMediaItem(self:getReaperTrack(), idx)

	if not i then
		jError("JTrack:getItem(idx), returned false for idx: " .. tostring(idx), J_ERROR_WARNING) 
		return false
	end
	return JItem:new({pItem = i, _parent = self})
end

function JTrack.prototype:getFx(idx)
	-- Returns fx at position idx. Starts with 0.
	-- Returns false if there is no fx at that position
	-- SAFETY CHECK?
	if idx >= self.fxcount then
		jError("JTrack:getFx(idx), no fx idx: " .. tostring(idx), J_ERROR_WARNING) 
		return false
	end
	
	return JFx:new({iFx = idx, _parent = self})
end

function JTrack.prototype:getSend(idx)
	-- Returns send at position idx. Starts with 0.
	-- Returns false if there is no send at that position
	-- SAFETY CHECK?
	if idx >= self.sendcount then
		jError("JTrack:getSend(idx), no send idx: " .. tostring(idx), J_ERROR_WARNING) 
		return false
	end
	
	return JSend:new({iSend = idx, category = 0, _parent = self})
end

function JTrack.prototype:getInstrument()
	local r = reaper.TrackFX_GetInstrument(self.pTrack)
	if r >= 0 then
		return JFx:new({iFx = r, _parent = self})
	else
		return false
	end
end

function JTrack.prototype:getFxByName(sPattern, iInstance, find_init, find_plain)
    -- Search by name
	-- sPattern: Specify pattern to look for, case insensitive.
	-- iInstance: leave empty (or false) to get a TABLE of all the tracks that match the pattern. Specify a number >= 0 to get the nth track that matches
	-- The default searches from the first character (find_init = 1) and uses plain string (find_plain = true). See Lua's string.find() for more info
	
	local iInstance = iInstance or false
	local find_init = find_init or 1
	local find_plain = find_plain or true
	
    local tResult = {}
    local iCount = 0
  
	if type(iInstance) == "number" and iInstance <= 0 then 
		jError("JTrack:getFxByName(), instance <= 0. First instance is 1! iInstance: " .. tostring(iInstance), J_ERROR_ERROR) 
		return false
	end	
	
    local iTracks = self.fxcount
	
	for t in self:fx() do
		if t.name:lower():find(sPattern:lower(), find_init, find_plain) then
			iCount = iCount + 1
            if iInstance == false then
                tResult[#tResult + 1] = t
            elseif iInstance == iCount then
                return t
            end
        end
    end
    
    if not iInstance then
        -- return table
        if #tResult == 0 then
            return false
        else
            return tResult
        end
    else
        -- instance not found
        return false
    end
end

function JTrack.prototype:getSendByName(sPattern, iInstance, find_init, find_plain)
    -- Search by name
	-- sPattern: Specify pattern to look for, case insensitive.
	-- iInstance: leave empty (or false) to get a TABLE of all the tracks that match the pattern. Specify a number >= 0 to get the nth track that matches
	-- The default searches from the first character (find_init = 1) and uses plain string (find_plain = true). See Lua's string.find() for more info
	-- When a table is requested it will be returned in reverse order
	
	local iInstance = iInstance or false
	local find_init = find_init or 1
	local find_plain = find_plain or true
	
    local tResult = {}
    local iCount = 0
  
	if type(iInstance) == "number" and iInstance <= 0 then 
		jError("JTrack:getSendByName(), instance <= 0. First instance is 1! iInstance: " .. tostring(iInstance), J_ERROR_ERROR) 
		return false
	end	
	
    local iTracks = self.sendcount
	
	for t in self:sends() do
		if t.name:lower():find(sPattern:lower(), find_init, find_plain) then
			iCount = iCount + 1
            if iInstance == false then
                -- tResult[#tResult + 1] = t
                table.insert(tResult, 1, t) -- Reverse the order, this makes sense when deleting
            elseif iInstance == iCount then
                return t
            end
        end
    end
    
    if not iInstance then
        -- return table
        if #tResult == 0 then
            return false
        else
            return tResult
        end
    else
        -- instance not found
        return false
    end
end

function JTrack.prototype:fx(start, num)
	-- Iterator to go through all the fx on the track
	-- start: index of the track to start at
	-- num: (maximum) amount of track to return
	local i = start or 0
	local n = 0
	if num and i + num <= self.fxcount then
		n = i + num
	else
		n = self.fxcount
	end

	return function ()
		i = i + 1
		if i <= n then 
			return self:getFx(i-1) 
		end
	end
end

function JTrack.prototype:sends(start, num)
	-- Iterator to go through all the sends on the track
	-- start: index of the track to start at
	-- num: (maximum) amount of track to return
	local i = start or 0
	local n = 0
	if num and i + num <= self.sendcount then
		n = i + num
	else
		n = self.sendcount
	end

	return function ()
		i = i + 1
		if i <= n then 
			return self:getSend(i-1) 
		end
	end
end

function JTrack.prototype:items(start, num, returnTable)
	-- Iterator to go through all the items on a tracks
	-- start: nth selected track to start at to start at. First one is 0.
	-- num: (maximum) amount of track to return
	-- returnTable: to true to get the whole table instead of iterator
	local returnTable = returnTable or false

	local i = start or 0
	local n = 0
	if num and i + num <= self.itemcount then
		n = i + num
	else
		n = self.itemcount
	end

	local itemTable = {}
	for j = i, n - 1 do
		table.insert(itemTable, self:getItem(j) )
	end

	if returnTable then
		return itemTable
	else
		i = 0
		return function ()
			i = i + 1
			if i <= n then 
				return itemTable[i]
			end
		end
	end
end

function JTrack.prototype:addFx(sFxName, recFx)
	-- Inserts an effect by name. If succesful returns the fx (class)
	
	local bRecFx = recFx or false
	local r = reaper.TrackFX_AddByName(self.pTrack, sFxName, bRecFx, -1)
	if r >= 0 then
		return self:getFx(r)
	else 
		return false
	end
end

function JTrack.prototype:addSend(tDest)
	local r = reaper.CreateTrackSend(self.pTrack, tDest:getReaperTrack())
	if r >= 0 then
		return self:getSend(r)
	else
		return false
	end
end

function JTrack.prototype:getParentTrack()
	local r = reaper.GetParentTrack(self.pTrack)
	if r then
		return JTrack:new({pTrack = r, _parentProject = self._parentProject})
	else
		return false
	end
end

function JTrack.prototype:getTopParentTrack()
	-- If this track is a child of a child track (so in a subgroup) this function will return the highest group parent
	-- If this track is not part of any group it will return the track itself

	local parent = self:getParentTrack()
	local topMost = false
	while parent do
		topMost = parent
		parent = parent:getParentTrack()
	end

	if topMost then
		return topMost
	else
		return self
	end
end

function JTrack.prototype:getLastRelatedChildTrack()
	if not self:isChildTrack() and not self:isParentTrack() then
		return self
	end

	local topMostParent = self:getTopParentTrack()
	return topMostParent:getChildTracks(false, true, true)
end

function JTrack.prototype:isParentTrack()
	return self.folderdepth == 1
end

function JTrack.prototype:isChildTrack()
	return reaper.GetParentTrack(self.pTrack) ~= nil
end

function JTrack.prototype:getNextTrack()
	return self._parentProject:getTrack(self.tracknumber)
end

function JTrack.prototype:getChildTracks(returnTable, recursive, returnOnlyLastTrack)
	local returnTable = returnTable or false
	local recursive = recursive or false
	local returnOnlyLastTrack = returnOnlyLastTrack or false

	if not self:isParentTrack() then
		jError("getChildTracks(): not a parent track", J_ERROR_NOTICE)
		if returnTable or returnOnlyLastTrack then -- Must check otherwise expecting an iterator
			return false
		else
			return function() end
		end
	end

	local tChildren = {}
	local nextTrack = self:getNextTrack()
    local iLevel = 1
	while nextTrack do
		-- Keep a score of entering folder tracks and leaving them
		iLevel = iLevel + nextTrack.folderdepth

		if recursive or iLevel - nextTrack.folderdepth == 1 then
			table.insert(tChildren, nextTrack)
		end
        if iLevel <= 0 then -- found the closing child
			if returnTable then
				return tChildren
			elseif returnOnlyLastTrack then
				return tChildren[#tChildren]
			else -- return iterator
				local i = 0
				return function () 
					i = i + 1
					return tChildren[i]
				end
			end

		end
        nextTrack = nextTrack:getNextTrack()
	end
	
	jError("getChildTracks(): did not find a closing track, it could be that the parent track is not properly closed.	", J_ERROR_ERROR)
	return false -- coult not find a closing child

end

function JTrack.prototype:getStateChunk(bIsUndo)
	local bIsUndo = bIsUndo or false
	local retval, str = reaper.GetTrackStateChunk(self.pTrack, "", bIsUndo)

	if not retval then
		jError("JTrack:getStateChunk() unsuccesful, return value: " .. tostring(retval), J_ERROR_NOTICE)
		return false
	else
		return str
	end
end

function JTrack.prototype:setStateChunk(strIn, bIsUndo)
	local bIsUndo = bIsUndo or false
	local retval = reaper.SetTrackStateChunk(self.pTrack, strIn, bIsUndo)

	if not retval then
		jError("JTrack:setStateChunk() unsuccesful, return value: " .. tostring(retval), J_ERROR_NOTICE)
	end
	return retval
end

-- MEDIA ITEM TAKE STRETCH MARKER
JStretchMarker = {}
JStretchMarker.prototype = {iStretchMarker = false, pos = false, srcpos = false, _parentTake = false}
JStretchMarker.mt = {}

function JStretchMarker:new(o)
    local o = o or {}
    setmetatable(o, JStretchMarker.mt)    
    return o
end

JStretchMarker.mt.__index = function (self, key)
	if key == "slope" then
		return reaper.GetTakeStretchMarkerSlope(self._parentTake.pTake, self.iStretchMarker)
    end

    return JStretchMarker.prototype[key]

end

function JStretchMarker.prototype:set(p, srcp)
	if srcp then
		self.pos = p
		self.srcpos = srcp
		return reaper.SetTakeStretchMarker(self._parentTake.pTake, self.iStretchMarker, p, srcp)
	else
		self.pos = p
		return reaper.SetTakeStretchMarker(self._parentTake.pTake, self.iStretchMarker, p)
	end
end

function JStretchMarker.prototype:getTake()
	return self._parentTake
end

function JStretchMarker.prototype:isFirst()
	return self.iStretchMarker == 0
end

function JStretchMarker.prototype:isLast()
	return self.iStretchMarker == self._parentTake.stretchmarkercount - 1
end
--[[
JStretchMarker.mt.__newindex = function (table, key, value)
	if key == "pos" then
		self.pos = value
		return reaper.SetTakeStretchMarker(self._parentTake, self._iStretchMarker, self.pos, self.srcpos)
    else
        rawset(table, key, value)
    end
end
]]

-- MEDIA ITEM TAKE
JTake = {}
JTake.prototype = {pTake = false, _parentItem = false}
JTake.mt = {}

function JTake:new(o)
    local o = o or {}
    setmetatable(o, JTake.mt)    
    return o
end

JTake.mt.__index = function (self, key)
    if MEDIA_ITEM_TAKE_GET_INFO_VALUES[key] ~= nil then
        if not self.pTake then
			msg("Take not initialized!")
            return false
		end
        return reaper.GetMediaItemTakeInfo_Value(self.pTake, MEDIA_ITEM_TAKE_GET_INFO_VALUES[key])
	elseif MEDIA_ITEM_TAKE_GET_SET_INFO_STRINGS[key] ~= nil then
		if not self.pTake then
			msg("Take not initialized!")
			return false
		end
		local retval, val = reaper.GetSetMediaItemTakeInfo_String(self.pTake, MEDIA_ITEM_TAKE_GET_SET_INFO_STRINGS[key], "", false)
		return val
	elseif key == "stretchmarkercount" then 
         return reaper.GetTakeNumStretchMarkers(self.pTake)
    end

    return JTake.prototype[key]

end

JTake.mt.__newindex = function (table, key, value)
    if MEDIA_ITEM_TAKE_SET_INFO_VALUES[key] ~= nil then
        if not table.pTake then
            msg("Take not initialized!")
            return false
        end
		reaper.SetMediaItemTakeInfo_Value(table.pTake, MEDIA_ITEM_TAKE_SET_INFO_VALUES[key], value)
	elseif MEDIA_ITEM_TAKE_GET_SET_INFO_STRINGS[key] ~= nil then
        if not table.pTake then
            --msg("Track not initialized!")
            return false
        end
        reaper.GetSetMediaItemTakeInfo_String(table.pTake, MEDIA_ITEM_TAKE_GET_SET_INFO_STRINGS[key], value, true)
    else
        rawset(table, key, value)
    end
end

function JTake.prototype:getReaperTake()
	return self.pTake
end

function JTake.prototype:getItem()
	return self._parentItem
end

function JTake.prototype:getStretchMarker(idx)
	local idx = idx or 0
	local retval, pos, srcpos = reaper.GetTakeStretchMarker(self.pTake, idx)
	if retval >= 0 then
		local sm = JStretchMarker:new({iStretchMarker = idx, pos = pos, srcpos = srcpos, _parentTake = self})
		return sm
	else
		msg("Trying to get stretchmarker that doesn't exist, idx: " .. idx .. ", pTake: " .. tostring(self.pTake))
	end
end

function JTake.prototype:getStretchMarkers(start, num)
	-- Iterator to go through all the takes in the item
	-- start: nth selected item to start at to start at. First one is 0.
	-- num: (maximum) amount of items to return
	local i = start or 0
	local n = 0
	if num and i + num <= self.stretchmarkercount then
		n = i + num
	else
		n = self.stretchmarkercount
	end

	return function ()
		i = i + 1
		if i <= n then 
			return self:getStretchMarker(i-1) 
		end
	end
end

function JTake.prototype:addStretchMarker(p, srcp)
	local r = reaper.SetTakeStretchMarker(self.pTake, -1, p, srcp)
	if r >= 0 then
		return self:getStretchMarker(r)
	else
		msg("Could not insert stretchmarker")
		return false
	end
end

function JTake.prototype:deleteStretchMarkers(idx, num)
	return reaper.DeleteTakeStretchMarkers(self.pTake, idx, num)
end

function JTake.prototype:deleteAllStretchMarkers()
	return reaper.DeleteTakeStretchMarkers(self.pTake, 0, self.stretchmarkercount)
end

function JTake.prototype:addFx(sFxName)
	-- Inserts an effect by name. If succesful returns the fx index (number)

	local r = reaper.TakeFX_AddByName(self.pTake, sFxName, -1)
	if r >= 0 then
		return r
	else 
		return false
	end
end

-- MEDIA ITEM
JItem = {}
JItem.prototype = {pItem = false}
JItem.mt = {}

function JItem:new(o)
    local o = o or {}
    setmetatable(o, JItem.mt)    
    return o
end

JItem.mt.__index = function (self, key)
    if MEDIA_ITEM_GET_INFO_VALUES[key] ~= nil then
        if not self.pItem then
			jError("JItem not initialized", J_ERROR_ERROR)
            return false
        end
        return reaper.GetMediaItemInfo_Value(self.pItem, MEDIA_ITEM_GET_INFO_VALUES[key])
	elseif MEDIA_ITEM_GET_SET_INFO_STRINGS[key] ~= nil then
		if not self.pItem then
			jError("JItem not initialized", J_ERROR_ERROR)
			return false
		end
		local retval, val = reaper.GetSetMediaItemInfo_String(self.pItem, MEDIA_ITEM_GET_SET_INFO_STRINGS[key], "", false)
		return val
	elseif key == "takecount" then
		return reaper.GetMediaItemNumTakes(self.pItem)
	-- end
	elseif JItem.prototype[key] ~= nil then
		return JItem.prototype[key]
	else
		jError("JItem key: ''" .. key .. "'' is not a GET property", J_ERROR_ERROR)
		return false
    end

    -- return JItem.prototype[key]

end

JItem.mt.__newindex = function (table, key, value)
    if MEDIA_ITEM_SET_INFO_VALUES[key] ~= nil then
        if not table.pItem then
			jError("JItem not initialized", J_ERROR_ERROR)
            return false
        end
        reaper.SetMediaItemInfo_Value(table.pItem, MEDIA_ITEM_SET_INFO_VALUES[key], value)
	elseif MEDIA_ITEM_GET_SET_INFO_STRINGS[key] ~= nil then
        if not table.pItem then
			jError("JItem not initialized", J_ERROR_ERROR)
			return false
        end
        reaper.GetSetMediaItemInfo_String(table.pItem, MEDIA_ITEM_GET_SET_INFO_STRINGS[key], value, true)
	elseif JItem.prototype[key] ~= nil then
		rawset(table, key, value)
	else
		jError("JItem key: ''" .. key .. "'' is not a SET property", J_ERROR_ERROR)
		return false
	end
end

function JItem.prototype:getReaperItem()
	return self.pItem
end

function JItem.prototype:getTake(idx)
	local idx = idx or 0
	local ta = JTake:new({pTake = reaper.GetMediaItemTake(self.pItem, idx), _parentItem = self})
	return ta
end

function JItem.prototype:getActiveTake()
	local ta = JTake:new({pTake = reaper.GetActiveTake(self.pItem)})
	return ta
end

function JItem.prototype:getTakes(start, num)
	-- Iterator to go through all the takes in the item
	-- start: nth selected item to start at to start at. First one is 0.
	-- num: (maximum) amount of items to return
	local i = start or 0
	local n = 0
	if num and i + num <= self.takecount then
		n = i + num
	else
		n = self.takecount
	end

	return function ()
		i = i + 1
		if i <= n then 
			return self:getTake(i-1) 
		end
	end
end

function JItem.prototype:split(p)
	pItemRightHand = reaper.SplitMediaItem(self.pItem, p)
	if pItemRightHand ~= nil then
		return JItem:new({pItem = pItemRightHand})
	else
		--msg("Nothing was split...")
		return false
	end
end

function JItem.prototype:getTrack()
	return self._parent
end

function JItem.prototype:delete()
	local res = reaper.DeleteTrackMediaItem(self:getTrack():getReaperTrack(), self.pItem)
	self = nil
	return res
end

function JItem.prototype:getStateChunk()
	local r, str = reaper.GetItemStateChunk(self:getReaperItem(), "")
	if r then
		return str
	end
end

function JItem.prototype:setStateChunk(newChunk)
	local r = reaper.SetItemStateChunk(self:getReaperItem(), newChunk)
	return r
end
-- PROJECT
JProject = {}
JProject.prototype = {pId = 0}
JProject.mt = {}

function JProject:new(o)
    local o = o or {}
    setmetatable(o, JProject.mt)
    
    return o
end

JProject.mt.__index = function (table, key)
	if key == "trackcount" then
        return reaper.CountTracks(table.pId)
	elseif key == "selectedtrackcount" then
		return reaper.CountSelectedTracks2(table.pId, true)
	elseif key == "selecteditemcount" then
		return reaper.CountSelectedMediaItems(table.pId)
	elseif JProject.prototype[key] ~= nil then
		return JProject.prototype[key]
	else
		jError("JProject key: ''" .. key .. "'' is not a GET property", J_ERROR_ERROR)
		return false
	end

end	

function JProject.prototype:tracks(start, num)
	-- Iterator to go through all the tracks in the project
	-- start: index of the track to start at
	-- num: (maximum) amount of track to return
	local i = start or 0
	local n = 0
	if num and i + num <= self.trackcount then
		n = i + num
	else
		n = self.trackcount
	end

	return function ()
		i = i + 1
		if i <= n then 
			return self:getTrack(i-1) 
		end
	end
end

function JProject.prototype:selectedTracks(start, num, bReturnAll)
	-- Iterator to go through all the SELECTED tracks in the project
	-- start: nth selected track to start at to start at. First one is 0.
	-- num: (maximum) amount of track to return, set to 0 for ALL.
	-- bReturnAll: set to true to get a table.
	local i = start or 0
	local n = 0
	if num and num > 0 and i + num <= self.selectedtrackcount then
		n = i + num
	else
		n = self.selectedtrackcount
	end

	-- UPDATED this function so it first gets the full list of selected tracks before it starts iterating
	-- otherwise deselecting tracks while in the loop could cause strange behavior
	-- ALL other iterators should be changed to this behavior...
	local selectedTracks = {}
	for j = i, n - 1 do
		table.insert(selectedTracks, self:getSelectedTrack(j) )
	end

	if bReturnAll then return selectedTracks end

	i = 0
	return function ()
		i = i + 1
		if i <= n then 
			return selectedTracks[i] 
		end
	end
end

function JProject.prototype:unselectAllTracks()
	local selectedTracks = self:selectedTracks(0, 0, true)
	for _, t in pairs(selectedTracks) do
		t.selected = 0
	end
end

function JProject.prototype:getTrack(idx)
	-- Return's the track at index position idx for the project. First track is 0
	-- If there is no such track then it returns false
	local idx = idx or 0
	local t = JTrack:new({pTrack = reaper.GetTrack(self.pId, idx), _parentProject = self})
	if not t.pTrack then 
		jError("project:getTrack(idx), no track idx: " .. tostring(i), J_ERROR_NOTICE) 
		return false
	end	
	return t
end

function JProject.prototype:getSelectedTrack(i)
	-- First track is 0
    local i = i or 0
	--local project = project or 0
    local t = JTrack:new()
	t.pTrack = reaper.GetSelectedTrack2(self.pId, i, true)
	t._parentProject = self
	if not t.pTrack then 
		jError("project:getSelectedTrack(), no selected track i: " .. tostring(i), J_ERROR_NOTICE) 
		return false
	end
    return t
end

function JProject.prototype:insertTrackAtIndex(i)
	reaper.InsertTrackAtIndex(i, false)
	return self:getTrack(i)
end

function JProject.prototype:getId()
	return self.pId
end

-- ITEM FUNCTIONS

function JProject.prototype:getItem(idx)
	local idx = idx or 0
	local it = JItem:new({pItem = reaper.GetMediaItem(self.pId, idx)})
	return it
end

function JProject.prototype:getSelectedItem(i)
	local i = i or 0
	local it = JItem:new()
	it.pItem = reaper.GetSelectedMediaItem(self.pId, i)
	return it
end

function JProject.prototype:selectedItems(start, num, bWantTable)
	-- Iterator to go through all the SELECTED items in the project
	-- start: nth selected item to start at to start at. First one is 0.
	-- num: (maximum) amount of items to return
	local i = start or 0
	local bWantTable = false or bWantTable
	local n = 0
	if num and i + num <= self.selecteditemcount and num ~= -1 then
		n = i + num
	else
		n = self.selecteditemcount
	end

	-- UPDATED this function so it first gets the full list of selected tracks before it starts iterating
	-- otherwise deselecting tracks while in the loop could cause strange behavior
	-- ALL other iterators should be changed to this behavior...
	local selectedTable = {}
	for j = i, n - 1 do
		-- local x = self:getSelectedItem(j)
		-- msg("J: " .. j .. ": " .. x.length .. " pitem: " .. tostring(x.pItem))
		table.insert(selectedTable, self:getSelectedItem(j))
	end
	if bWantTable then
		return selectedTable
	end
	-- for k,v in ipairs(selectedTable) do
	-- 	msg("table, k: " .. k .. ", v: " .. v.length .. ", p: " .. tostring(v.pItem))
	-- end
	i = 0
	return function ()
		i = i + 1
		if i <= n then 
			-- msg(i .. " : " .. selectedTable[i].length)
			return selectedTable[i] 
		end
	end

end

function JProject.prototype:getTracksByName(sPattern, iInstance, find_init, find_plain)
    -- Search track(s) by name
	-- sPattern: Specify pattern to look for
	-- iInstance: leave empty (or false) to get a TABLE of all the tracks that match the pattern. Specify a number > 0 to get the nth track that matches
	-- The default searches from the first character (find_init = 1) and uses plain string (find_plain = true). See Lua's string.find() for more info

	
	local iInstance = iInstance or false
	local find_init = find_init or 1
	local find_plain = find_plain or true
	
    local tResult = {}
    local iCount = 0
  
	if type(iInstance) == "number" and iInstance <= 0 then 
		jError("project:getTracksByName(), instance <= 0. First instance is 1! iInstance: " .. tostring(iInstance), J_ERROR_ERROR) 
		return false
	end	
	
    local iTracks = self.trackcount
	
	for t in self:tracks() do
		if t.name:lower():find(sPattern:lower(), find_init, find_plain) then
			iCount = iCount + 1
            if iInstance == false then
                tResult[#tResult + 1] = t
            elseif iInstance == iCount then
                return t
            end
        end
    end
    
    if not iInstance then
        -- return table
        if #tResult == 0 then
            return false
        else
            return tResult
        end
    else
        -- instance not found
        return false
    end
end

function JProject.prototype:getTrackByName(sPattern, iInstance, find_init, find_plain)
	local iInstance = iInstance or 1
	return self:getTracksByName(sPattern, iInstance, find_init, find_plain)
end

function JProject.prototype:getMaster()
	local t = JTrack:new({pTrack = reaper.GetMasterTrack(self.pId), _parentProject = self})
	return t
end