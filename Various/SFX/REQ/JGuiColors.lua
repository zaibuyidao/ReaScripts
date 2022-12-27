--[[
@author n0ne
@version 0.7.1
@noindex
--]]

jGuiColors = {}

function jGuiColors:get(sColor, opacity)
	opacity = opacity or 1
	
	local myColors = {
		white 			= 	    {	1,		1, 		1		},
		black 			= 	    {	0, 		0, 		0		},
		red 			=    	{	1, 		0, 		0		},
		green 			= 	    {	0, 		1, 		0		},
		blue 			=    	{	0,	 	0, 		1		},
		yellow			=		{	1,		1,		0		}
	} 
	
	if not myColors[sColor] then
		msg("Unknown color: " .. sColor)
		return false
	end
	local res = {table.unpack(myColors[sColor])}
	res[4] = opacity
	return res
end

function jGuiColors:setAllStates(tColors)
	local res = {}
	assert(#tColors == 4, "Colors table does not have 4 entries")
	res.normal = 	tColors
	res.hover = 	tColors
	res.focus = 	tColors
	res.active = 	tColors
	return res
end

function jGuiColors:lighter(x)
	x = x or 1.2
	return {self[1] * x, self[2] * x, self[3] * x, self[4]}
end

-------------
-- new color class
jColor = {1, 1, 1, 1}

function jColor:new(o)
	local newObject = {}

	if type(o) == "table" then
		newObject = o
	end
	
	setmetatable(newObject, self)
	self.__index = self

	if type(o) == "string" then
		newObject:make(o)
	end
	
	return newObject
end

function jColor:make(sColor, opacity)
	opacity = opacity or 1
	
	local myColors = {
		white 			= 	    {	1,		1, 		1		},
		black 			= 	    {	0, 		0, 		0		},
		red 			=    	{	1, 		0, 		0		},
		green 			= 	    {	0, 		1, 		0		},
		blue 			=    	{	0,	 	0, 		1		},
		yellow			=		{	1,		1,		0		}
	}

	if not myColors[sColor] then
		msg("Unknown color: " .. sColor)
		return false
	end
	local res = {table.unpack(myColors[sColor])}
	self[1] = res[1]
	self[2] = res[2]
	self[3] = res[3]
	self[4] = opacity

	return self
end

function jColor:lighter(x)
	x = x or 0.1
	-- self[1] = self[1] * x -- this will also change the original color this function is called on
	-- self[2] = self[2] * x
	-- self[3] = self[3] * x
	-- self[4] = self[4] * x
	-- return self
	return {self[1] + x, self[2] + x, self[3] + x, self[4]}
end