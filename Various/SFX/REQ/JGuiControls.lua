--[[
@author n0ne
@version 0.7.0
@noindex
--]]

function msg(m)
	return reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

function showTable(st)
	msg("Showing table")
	for i,v in pairs(st) do
			msg("I: " .. tostring(i) .. ", V: " .. tostring(v))
	end
end

---------
-- The standard GUI control is a clickable label

jGuiControl = {
	label = "",
	
	colors_label = {
		normal = {.8, .8, .8, .8},
		hover = {.8, .8, .8, 1},
		focus = {.5, .5, .5, 1},
		active = {1, .9, 0, .5}
	},
	color_focus_border = {1, .9, 0, .5},

	label_fontsize = 10,
	label_font = "Calibri",
	label_align = "c",
	label_valign = "t",
	label_padding = 0,
	label_vpadding = 0,
	
	x = 0,
	y = 0,
	z = 0,

	width = -1,
	height = -1,
	value = false,
	visible = true,
	border = true,
	border_focus = false,
	fill = false,
	
	active = false,
	hover = false,
	focus = false,
	
	controlType = "control",
	parentGui = false,-- a reference to the parent GUI
	focus_index = false, -- Used for tab indexing
	mouse_input = true
}

function jGuiControl:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
			
	return o
end

function jGuiControl:setSettings(t)
	for k, v in pairs(t) do
		self[k] = v
	end
end

function jGuiControl:_init()
	bFromLabel = false
	if self.width == -1 then
		self.width = self:_calculateLabelSize()[1]
		end
		if self.height == -1 then
		self.height = self:_calculateLabelSize()[2]
		end
		self:_calculateDimensions()
	
	self:__init()
end

function jGuiControl:__init()
	-- specific to control type init
end

function jGuiControl:_calculateDimensions()
	 	
	 	self.area = {self.x, self.y, self.x + self.width, self.y + self.height}
end

function jGuiControl:_calculateLabelSize()
	gfx.setfont(1, self.label_font, self.label_fontsize)
	x, y = gfx.measurestr(self.label)
	return {x, y}
end

function jGuiControl:setPos(x, y, bCenter)
	x = x or self.x
	y = y or self.y
	
	if not bCenter then
		-- position is left upper corner
		self.x = x
		self.y = y
	else
		if not self.width == -1 or self.height == -1 then
			msg("width or height is not set, is control initialized?")
			return false
		end
		-- calculate position form center
		self.x = x - self.width/2
		self.y = y - self.height/2
	end
			
end

function jGuiControl:getPos()
	return {self.x, self.y}
end

function jGuiControl:getPosCenter()
	return {self.x + self.width/2, self.y + self.height/2}
end

function jGuiControl:_draw()
	self:update()
	if not self.visible then
		return false
	end
	
	-- else
	-- gfx.setfont(1, self.label_font, self.label_fontsize)
	
	-- self:_setStateColor()
	
	self:_drawLabel()
	
	-- Draw a border around the control
	if self.border then
		gfx.rect(self.x, self.y, self.width, self.height, 0)
	end

	-- Draw a border if the element has focus
	if self.focus == true and self.border_focus then
		self:__setGfxColor(self.color_focus_border)
		local distance = 2
		gfx.rect(self.x - distance, self.y - distance, self.width + distance*2, self.height + distance*2, 0)
	end
end

function jGuiControl:_drawLabel()
	gfx.setfont(1, self.label_font, self.label_fontsize)
	self:_setStateColor()
	self:__setLabelXY()
	gfx.drawstr(tostring(self.label))
end

function jGuiControl:update()
	-- to be defined by user, called before the control is drawn
end

function jGuiControl:_onMouseDown()
	self.active = true
end

function jGuiControl:_onMouseUp()
	if self.active then
		self:_onMouseClick() -- first do internal click then the user defined onMouseClick()
	end
	
	self.active = false
end

function jGuiControl:_onRightMouseDown()
	self.active = true
end

function jGuiControl:_onRightMouseUp()
	if self.active then
		self:_onRightMouseClick() -- first do internal click then the user defined onMouseClick()
	end
	
	self.active = false
end

function jGuiControl:_onMouseClick()
	-- default mouse click stuff
	self:onMouseClick() -- this function should be defined by the user
end

function jGuiControl:_onRightMouseClick()
	-- default mouse click stuff
	self:onRightMouseClick() -- this function should be defined by the user
end

function jGuiControl:_onMouseHover()
	self.hover = true
end

function jGuiControl:_onMouseHoverOut()
	self.hover = false
	self.active = false
end

function jGuiControl:_onMouseDrag(dx, dy)
	-- empty
	return 0
end

function jGuiControl:_onMouseWheel(amount)
	self:onMouseWheel(amount)
end

function jGuiControl:onMouseWheel(amount)
	-- User Defined
end

function jGuiControl:onMouseClick()
	-- To be defined by user
	--msg("onMouseClick() not defined yet")
end

function jGuiControl:onRightMouseClick()
	-- To be defined by user
	--msg("onMouseClick() not defined yet")
end

function jGuiControl:_setStateColor()
	if self.active == true and self.colors_label.active then
		self:__setGfxColor(self.colors_label.active)
	elseif self.hover == true and self.colors_label.hover then
		self:__setGfxColor(self.colors_label.hover)
	elseif self.focus == true and self.colors_label.focus then
		self:__setGfxColor(self.colors_label.focus)
	else
		self:__setGfxColor(self.colors_label.normal)
	end
end

function jGuiControl:__setGfxColor(tColors)
	gfx.set(tColors[1], tColors[2], tColors[3], tColors[4])
end

function jGuiControl:getArea()
	return self.area
end

function jGuiControl:__setLabelXY(str)
	-- sets gfx x and y to conform with align settings
	
	str = str or self.label
	if self.label_align == "l" then
		gfx.x = self.x + self.label_padding
	elseif self.label_align == "c" then
		gfx.x = self.x + self.width/2 - gfx.measurestr(str)/2
	elseif self.label_align == "r" then
		gfx.x = self.x + self.width - gfx.measurestr(str) - self.label_padding
	else
		-- unknown
		gfx.x = self.x
	end
	if self.label_valign == "t" then
		gfx.y = self.y + self.label_vpadding
	elseif self.label_valign == "c" then
		_, v = gfx.measurestr(str)
		gfx.y = self.y + self.height/2 - v/2
	elseif self.label_valign == "b" then
		_, v = gfx.measurestr(str)
		gfx.y = self.y + self.height - v - self.label_vpadding
	else
		-- unknown
		gfx.y = self.y
	end
end

function jGuiControl:_onKeyboard(key)
	-- Called when the control has focus and a key was pressed
	self:onKeyboard(key)
end

function jGuiControl:onKeyboard(key)
	-- User defined
end

function jGuiControl:_onTab()
	if self:onTab() then
		self.parentGui:focusNext()
	end
end

function jGuiControl:_onShiftTab()
	if self:onShiftTab() then
		self.parentGui:focusPrev()
	end
end

function jGuiControl:onTab()
	-- user defined, return true to shift focus, false to keep it
	return true
end

function jGuiControl:onShiftTab()
	-- user defined, return true to shift focus, false to keep it
	return true
end

function jGuiControl:_onArrowDown()
	if self:onArrowDown() then
		self.parentGui:focusNext()
	end
end

function jGuiControl:_onArrowUp()
	if self:onArrowUp() then
		self.parentGui:focusPrev()
	end
end

function jGuiControl:onArrowDown()
	-- user defined, return true to shift focus, false to keep it
	return true
end

function jGuiControl:onArrowUp()
	-- user defined, return true to shift focus, false to keep it
	return true
end

function jGuiControl:_onFocus()
	-- Called when a control gets focus by clicking on it or by the keyboard
	self.focus = true
	self:onFocus()
end

function jGuiControl:onFocus()
	-- User defined
end

function jGuiControl:_onBlur()
	-- Called when a control loses focus
	self.focus = false
	self:onBlur()
end

function jGuiControl:onBlur()
	-- User defined
end

function jGuiControl:_onEnter()
	-- Called when the control has focus and the ENTER key is pressed
	self:onEnter()
end

function jGuiControl:onEnter()
	-- User defined but the default behavior is to "click" the button
	self:onMouseClick()
end

function jGuiControl:_onChange()
	self:onChange()
end

function jGuiControl:onChange()
end

---------
-- Toggle Button Control

jGuiButtonToggle = jGuiControl:new(
{
	toggle_state = false,
	colors_label = {
		normal = {.8, .8, .8, .8},
		hover = {.8, .8, .8, 1},
		active = {1, .9, 0, .5},
		toggle = {1, .9, 0, .5},
		hover_toggle = {1, .9, 0, .7}
	}
})

function jGuiButtonToggle:_onMouseClick()
	if self.toggle_state then
		self.toggle_state = false
	else
		self.toggle_state = true
	end
	self:onMouseClick()
end

function jGuiButtonToggle:_draw()
	if not self.visible then
		return false
	end
	-- else

	
	self:_drawLabel()
	
	if self.border then
		gfx.rect(self.x, self.y, self.width, self.height, 0)
	end
end

function jGuiButtonToggle:_drawLabel()
	gfx.setfont(1, self.label_font, self.label_fontsize)
	
	if self.active == true then
		jGuiControl:__setGfxColor(self.colors_label.active)
	elseif self.hover == true and self.toggle_state == false then
		jGuiControl:__setGfxColor(self.colors_label.hover)
	elseif self.hover == true and self.toggle_state == true then
		jGuiControl:__setGfxColor(self.colors_label.hover_toggle)
	elseif self.toggle_state == true then
		jGuiControl:__setGfxColor(self.colors_label.toggle)
	else
		jGuiControl:__setGfxColor(self.colors_label.normal)
	end

	self:__setLabelXY()
	gfx.drawstr(tostring(self.label))
end

----------
-- Input box control

jGuiTextInput = jGuiControl:new(
{
	value = "",
	controlType = "text_input",
	kb = require('REQ.jKeyboard'),

	border_focus = true,
	-- color_focus_border = {1, .9, 0, .5},
	color_focus_border = jGuiColors:get("yellow", 0.5),

	carret_pos = 0,
	carret_draw = true,
	carret_color = {1, .9, .5, 1},
	_carret_blink_timer = 0,
	_carret_blink = false
})

function jGuiTextInput:_onKeyboard(key)
	-- print(key)
	if key == self.kb.backspace and not self.kb.control() then
		if self.carret_pos > 0 then -- Can't backspace when at the beginning of the string
			self.value = self.value:sub(0, self.carret_pos - 1) .. self.value:sub(self.carret_pos + 1, -1)
			self:__setCarretPos(self.carret_pos - 1)
		end
	elseif key == self.kb.delete then
		self.value = self.value:sub(0, self.carret_pos) .. self.value:sub(self.carret_pos + 2, -1)
	elseif key == self.kb.backspace and self.kb.shift() and self.kb.control() then
		self.value = ""
		self:__setCarretPos(0)
	elseif key == self.kb.backspace and self.kb.control() then --self.kb.ctrl_backspace then
		self.value = self.value:match("(.-)%s*$") -- trim ending spaced
		local last_space = self.value:find("%s[^%s]*$") or 0
		self.value = self.value:sub(1, last_space)
		self:__setCarretPos(last_space)
	elseif key == self.kb.control_v and self.kb.control() then
		local clip = reaper.CF_GetClipboard()
		self.value = self.value:sub(0, self.carret_pos) .. clip .. self.value:sub(self.carret_pos + 1, -1)
		self:__setCarretPos(self.carret_pos + #clip)	
	elseif key == self.kb.control_c and self.kb.control() then
		reaper.CF_SetClipboard(self.value)
	elseif key == self.kb.arrow_left then
		self:__setCarretPos(self.carret_pos - 1)
	elseif key == self.kb.arrow_right then
		self:__setCarretPos(self.carret_pos + 1)
	elseif key == self.kb.home then
		self:__setCarretPos(0)
	elseif key == self.kb._end then
		self:__setCarretPos(#self.value)
	elseif key >= 0 and key <= 255 then -- if self.kb:isChar(key) then
		self.value = self.value:sub(0, self.carret_pos) .. string.char(key) .. self.value:sub(self.carret_pos + 1, -1)
		self:__setCarretPos(self.carret_pos + 1)
	end
	self.label = self.value
	
	self:onKeyboard(key) -- pass on the keypress to the used defined function
end

function jGuiTextInput:__setCarretPos(p)
	self.carret_pos = math.max(0, math.min(p, string.len(self.value)))
end

function jGuiTextInput:_draw()
	self:update()
	if not self.visible then
		return false
	end
	
	-- gfx.setfont(1, self.label_font, self.label_fontsize)
	
	-- self:_setStateColor()
	-- self:__setLabelXY()
	
	-- gfx.drawstr(tostring(self.label))
	self:_drawLabel()
	
	-- Draw a border around the control
	if self.border then
		gfx.rect(self.x, self.y, self.width, self.height, 0)
	end

	if self.focus == true and self.border_focus then
		self:__setGfxColor(self.color_focus_border)
		local distance = 2
		gfx.rect(self.x - distance, self.y - distance, self.width + distance*2, self.height + distance*2, 0)
	end

	if self.carret_draw and self.focus then
		self:_drawCarret()
	end
end

function jGuiTextInput:_drawCarret()
	local TIME_ON, TIME_OFF = 0.7, 0.7
	if self._carret_blink == false and (reaper.time_precise() - self._carret_blink_timer) > TIME_ON then
		self._carret_blink_timer = reaper.time_precise()
		self._carret_blink = true
		return false
	elseif self._carret_blink == true and (reaper.time_precise() - self._carret_blink_timer) > TIME_OFF then
		self._carret_blink_timer = reaper.time_precise()
		self._carret_blink = false
	end

	if self._carret_blink then return false end

	local carretStringLen = gfx.measurestr(self.value:sub(0, self.carret_pos))
	local carret_w = 2 --self.label_fontsize / 10	
	local carret_h = self.label_fontsize - self.label_fontsize / 5

	self:__setGfxColor(self.carret_color)
	self:__setLabelXY()
	local x = gfx.x + carretStringLen
	local y = gfx.x
	gfx.rect(x, y, carret_w, carret_h)

end


function jGuiTextInput:_onFocus()
	-- Called when a control gets focus by clicking on it or by the keyboard
	self.focus = true
	self._carret_blink_timer = reaper.time_precise()
	self._carret_blink = false
	self:onFocus()
end
----------
-- Slider control

jGuiSlider = jGuiControl:new(
{
	value = 0,
	init_value = 0,
	
	value_scaled = 0,
	value_scaled_label = false,
	value_min = 0,
	value_max = 1,
	value_stepsize = 0,
	value_options = {},
	value_options_labels = {},
	value_mode = "cont", -- cont/step/option
	
	-- mouse_y1 = false, 
	mouse_sensitivity = 0.005,
	mouse_sensitivity_fine_factor = 0.5,
	mouse_wheel_sensitivity = .4,
	mouse_wheel_sensitivity_fine_factor = 0.5,
	draw_fill = true,
	draw_direction = "horizontal",
	colors_label = {
		normal = {.8, .8, .8, .8},
		hover = {.8, .8, .8, 1},
		active = {1, .9, 0, .5},
		fill = {.5, .5, .5, .5}
	}
})

function jGuiSlider:onMouseDrag()
	-- to be defined by user
end

function jGuiSlider:valueScale()
	if self.value_mode == "cont" then
		range = self.value_max - self.value_min
		self.value_scaled = self.value_min + range * self.value
	elseif self.value_mode == "step" then
		range = self.value_max - self.value_min
		v = self.value_min + range * self.value
		self.value_scaled = v - (v % self.value_stepsize)
	elseif self.value_mode == "option" then
		if self.value == 1 then
			v = #self.value_options
		else
			range = #self.value_options
			v = 1 + self.value * range
			v = v - (v % 1)
		end
		self.value_scaled = self.value_options[v]
		if self.value_options_labels[v] then
			self.value_scaled_label = self.value_options_labels[v]
		else
			self.value_scaled_label = false
		end
 	end
	
	--msg(self.value .. " : " .. self.value_scaled)
end

function jGuiSlider:valueUnscale()
	if self.value_mode == "cont" or self.value_mode == "step" then
		range = self.value_max - self.value_min
		self.value = (self.value_scaled - self.value_min) / range
		--msg(self.value)
	elseif self.value_mode == "option" then
		r = self:__findOption(self.value_scaled)
		if not r then
			self.value = 0
			return false
		end
		self.value = (r - 1) / (#self.value_options - 1)
		
		if self.value_options_labels[r] then
			self.value_scaled_label = self.value_options_labels[r]
		else
			self.value_scaled_label = false
		end
	end
	
	--msg(self.value .. " : " .. self.value_scaled)
end

function jGuiSlider:_onMouseClick()
	self:onMouseClick()
end

function jGuiSlider:_draw()
	self:update()
	if not self.visible then
		return false
	end

	-- else
	-- gfx.setfont(1, self.label_font, self.label_fontsize)
	
	-- self:_setStateColor()
	-- self:__setLabelXY()
	
	-- gfx.drawstr(tostring(self.label))
	self:_drawLabel()
	
	local valueLabel = self:_makeLabel()
	
	self:__setLabelXY(valueLabel)
	gfx.y = gfx.y + self.label_fontsize
	gfx.drawstr(tostring(valueLabel))
	
	-- Draw a border around the control
	if self.border then
		gfx.rect(self.x, self.y, self.width, self.height, 0)
	end
	
	
	
	if self.draw_fill then
		jGuiControl:__setGfxColor(self.colors_label.fill)
		if self.draw_direction == "horizontal" then
			gfx.rect(self.x, self.y, self.width * self.value, self.height, 1)
		elseif self.draw_direction == "vertical" then
			gfx.rect(self.x, self.y + self.height * (1 - self.value), self.width, self.height * self.value	, 1)
		end
	end
end

function jGuiSlider:_onMouseDown()
	self.active = true
	self.mouse_y1 = gfx.mouse_y
	self.init_value = self.value
end

function jGuiSlider:_onMouseUp()
	if self.active then		
		self:_onMouseClick() -- first do internal click then the user defined onMouseClick()
	end
	self.active = false
end

function jGuiSlider:_onMouseClick()
	-- default mouse click stuff
	self:onMouseClick() -- this function should be defined by the user
end

function jGuiSlider:_onMouseHover()
	self.hover = true
end

function jGuiSlider:_onMouseHoverOut()
	self.hover = false
	--self.active = false
end

function jGuiSlider:_onMouseDrag(dx, dy)
	local fineFactor = 1
	if self.parentGui.kb:control() then
		fineFactor = self.mouse_sensitivity_fine_factor
	end
	local dragResultY = self.init_value + dy * self.mouse_sensitivity * -1 * fineFactor
	local result = 0
	
	dragResultY = self:__limitValue(dragResultY)
	-- if dragResultY == 1 or dragResultY == 0 then
	-- 	result = result + 2 -- reset y axis
	-- 	self.init_value = self.value
	-- end

	if dragResultY ~= self.value then
		self.value = dragResultY
		self:valueScale()
		self:_onChange()
		self:onMouseDrag() -- user function
	end

	-- result = result + 1 -- to reset x axis

	-- Changed to always reset (this fixes fine control). Maybe the drag shsould be handled like a scrollwheel in increments
	self.init_value = self.value
	result = result + 2
	return result
end

function jGuiSlider:_onMouseWheel(amount)
	local fineFactor = 1
	if self.parentGui.kb:control() then
		fineFactor = self.mouse_wheel_sensitivity_fine_factor
	end

	local mouseWheelResult = self.value + self.mouse_wheel_sensitivity * amount / 1200 * fineFactor
	mouseWheelResult = self:__limitValue(mouseWheelResult)
	if mouseWheelResult ~= self.value then
		self.value = mouseWheelResult
		self:valueScale()
		self:_onChange()
	end

	self:onMouseWheel(amount)
end

function jGuiSlider:__init()
	self.value = self.min_value
end

function jGuiSlider:__findOption(option)
	for i = 1, #self.value_options, 1 do
		if self.value_options[i] == option then
			return i
		end
	end
	return false
end

function jGuiSlider:_makeLabel()
	local unitStr = ""
	if self.label_unit then
		unitStr = " " .. self.label_unit
	end

	if self.value_scaled_label then
		return self.value_scaled_label .. unitStr
	else
		return self.value_scaled .. unitStr
	end
end

function jGuiSlider:__limitValue(v)
	local MIN_VALUE = 0
	local MAX_VALUE = 1
	return math.max(MIN_VALUE, math.min(v, MAX_VALUE))
end
---------
-- Dial/knob, based on slider

jGuiDial = jGuiSlider:new({
	dialStartPoint = 0.35, -- Where 0 is 3 o clock, .5 is 9 o clock and 1 is 3 o clock
	dialEndPoint = 1.15,
	dialPointerWidth = 0.02, -- as a fraction of dial width
	dialPointerHeight = 0.2, -- as a fraction of the dial width
	border = false,
	label_unit = "", -- string like ms or Hz etc

	colors_label = {
		normal = {.8, .8, .8, .8},
		hover = {.8, .8, .8, 1},
		active = {1, .9, 0, .5},
		fill = {.5, .5, .5, .5}
	},

	colors_dial = {
		normal = {.8, .8, .8, .8},
		hover = {.8, .8, .8, 1},
		active = {1, .9, 0, .5},
		fill = {1, 1, 1, 1},
		fill_hover = {1, 1, 1, 1},
		pointer = {0, 0, 0, 1},
		pointer_hover = {.5, 0.5, 0.5 , 1}
	}

})

function jGuiDial:_draw()
	self:update()
	if not self.visible then
		return false
	end

	-- else
	gfx.setfont(1, self.label_font, self.label_fontsize)
	
	if self.active == true then
		self:__setGfxColor(self.colors_label.active)
	elseif self.hover == true then
		self:__setGfxColor(self.colors_label.hover)
	else
		self:__setGfxColor(self.colors_label.normal)
	end
		
	gfx.x = self.x + self.width/2 - gfx.measurestr(self.label)/2
	gfx.y = self.y + self.height/5 - self.label_fontsize
	gfx.drawstr(tostring(self.label))
	
	local valueLabel = self:_makeLabel()
	
	gfx.x = self.x + self.width/2 - gfx.measurestr(valueLabel)/2
	gfx.y = self.y + self.height - (self.height/5) -- - self.label_fontsize
	gfx.drawstr(tostring(valueLabel))
	
	-- Draw a border around the control
	if self.border then
		gfx.rect(self.x, self.y, self.width, self.height, 0)
	end
	
	local center_x = self.x + self.width/2
	local center_y = self.y + self.height/2
	local r = self.height/4

	-- Draw the dial itself:
	if self.hover or self.active == true then
		self:__setGfxColor(self.colors_dial.fill_hover)
	else
		self:__setGfxColor(self.colors_dial.fill)
	end

	gfx.circle(center_x, center_y, r, 1, 1)
	
	-- Draw the pointer
	if self.hover or self.active == true then
		self:__setGfxColor(self.colors_dial.pointer_hover)
	else
		self:__setGfxColor(self.colors_dial.pointer)
	end
	
	local pointerHeight = (self.dialPointerHeight * self.height / 2)
	local x1, y1 = self:__getEdgePoint(center_x, center_y, r, self.value)
	local x3, y3 = self:__getEdgePoint(center_x, center_y, r - pointerHeight, self.value)
	gfx.line(x1, y1, x3, y3, 1)
	
	-- Making a thicker pointer, didn't look nice
	--[[
	local pointerWidth = self.dialPointerWidth
	local pointerHeight = (self.dialPointerHeight * self.height / 2)

	local x1, y1 = self:__getEdgePoint(center_x, center_y, r, self.value - pointerWidth)
	local x2, y2 = self:__getEdgePoint(center_x, center_y, r, self.value + pointerWidth)
	local x3, y3 = self:__getEdgePoint(center_x, center_y, r - pointerHeight, self.value - pointerWidth)
	local x4, y4 = self:__getEdgePoint(center_x, center_y, r - pointerHeight, self.value + pointerWidth)
	gfx.triangle(x1, y1, x2, y2, x3, y3, x4, y4)
	]]
end


function jGuiDial:__getEdgePoint(center_x, center_y, r, v)
	local val = v * (self.dialEndPoint - self.dialStartPoint) + self.dialStartPoint
	local x = center_x + r * math.cos(2*math.pi*val)
	local y = center_y + r * math.sin(2*math.pi*val)
	return x, y
end

function jGuiDial:__setLabelXY(str)
	-- sets gfx x and y to conform with align settings
	
	str = str or self.label
	if self.label_align == "l" then
		gfx.x = self.x
	elseif self.label_align == "c" then
		gfx.x = self.x + self.width/2 - gfx.measurestr(str)/2
	elseif self.label_align == "r" then
		gfx.x = self.x + self.width - gfx.measurestr(str)
	else
		-- unknown
		gfx.x = self.x
	end
	if self.label_valign == "t" then
		gfx.y = self.y
	elseif self.label_valign == "c" then
		_, v = gfx.measurestr(str)
		gfx.y = self.y + self.height/2 - v/2
	elseif self.label_valign == "b" then
		_, v = gfx.measurestr(str)
		gfx.y = self.y + self.height - v
	else
		-- unknown
		gfx.y = self.y
	end
end
---------
-- Clickable Image

jGuiImg = jGuiControl:new(
{
	image_file = false,
	image_id = false,
	colors_border = {
		normal = {.8, .8, .8, .8},
		hover = {.8, .8, .8, 1},
		active = {1, .9, 0, .5},
		toggle = {1, .9, 0, .5},
		hover_toggle = {1, .9, 0, .7}
	}
})

function jGuiImg:_init()
	if not self.image_file or not self.image_id then
		msg("jGuiImg Error: file or id not set")
		return false
	end
	
	gfx.loadimg(self.image_id, self.image_file)
	
	if self.width == -1 then
		self.width, _ = gfx.getimgdim(self.image_id)
		end
		if self.height == -1 then
		_, self.height = gfx.getimgdim(self.image_id)
		end
	
	
	
	self:_calculateDimensions()
	self:__init()
end

function jGuiImg:_draw()
	self:update()
	if not self.visible then
		return false
	end
	
	-- else
	--Lua: gfx.blit(source, scale, rotation[, srcx, srcy, srcw, srch, destx, desty, destw, desth, rotxoffs, rotyoffs])
	jGuiControl:__setGfxColor(self.colors_border.normal)
	gfx.blit(self.image_id, 1, 0, 0, 0, self.width, self.height, self.x, self.y)
	
	-- Draw a border around the control
	if self.border then
		if self.active == true then
			jGuiControl:__setGfxColor(self.colors_border.active)
		elseif self.hover == true then
			jGuiControl:__setGfxColor(self.colors_border.hover)
		else
			jGuiControl:__setGfxColor(self.colors_border.normal)
		end
		
		gfx.rect(self.x, self.y, self.width, self.height, 0)
	end
end

---------
-- Text label

jGuiText = jGuiControl:new({
	label = "",
	
	colors_label = {.8, .8, .8, 1},
	colors_fill = {.8, .8, .8, 1},
	colors_border = {.8, .8, .8, 1},

	label_align = "c",
	label_valign = "t",
	
	x = 0,
	y = 0,
	width = -1,
	height = -1,
	visible = true,
	border = false,
		
	controlType = "text",
	mouse_input = false
})


function jGuiText:_draw()
	self:update()
	if not self.visible then
		return false
	end
	
	-- Draw a fill
	jGuiControl:__setGfxColor(self.colors_fill)
	if self.fill then
		gfx.rect(self.x, self.y, self.width, self.height, 1)
	end

	jGuiControl:__setGfxColor(self.colors_border)
	-- Draw a border around the control
	if self.border then
		gfx.rect(self.x, self.y, self.width, self.height, 0)
	end

	gfx.setfont(1, self.label_font, self.label_fontsize)
	
	jGuiControl:__setGfxColor(self.colors_label)

	self:__setLabelXY()
	gfx.drawstr(tostring(self.label))

end

---------
-- Sub Menu

jGuiSub = jGuiControl:new(
{
	controlHover = false,
	
	-- jGuiParent = false,
	-- width = 400,
	-- height = 200,


	-- visible = true,

	controls = {}
	-- radialHover = false,
	-- radialActive = false,
	-- radialSubmenuActive = false
	-- controlActive = false, -- not used
	-- controlHover = false, -- note used


})

function jGuiSub:set(t)
	for k, v in pairs(t) do
		self[k] = v
	end
end

function jGuiSub:_init()
	self:_calculateDimensions()
	
	for i, curControl in ipairs(self.controls) do
		curControl:_init()
	end
end

function jGuiSub:_draw()
	if not self.visible then
		return false
	end

	-- This menu can be drawn
	for i, curControl in ipairs(self.controls) do
		if curControl.visible then
			curControl:_draw()
		end
	end

end

function jGuiSub:_onMouseHover()
	for i, curControl in ipairs(self:getControlsByZInv()) do
		local curArea = curControl:getArea()
		if curControl.mouse_input and 
			curControl.visible and curArea[1] < gfx.mouse_x and gfx.mouse_x < curArea[3] and 
			curArea[2] < gfx.mouse_y and gfx.mouse_y < curArea[4] then
			
			if curControl ~= self.controlHover and self.controlHover then -- When the user hovers from one button directly onto another
				self.controlHover:_onMouseHoverOut()
			end
			
			self.controlHover = curControl
			curControl:_onMouseHover()

			-- Pass along potential mousewheel movement
			-- local mouse_wheel = self.mouse.mouse_wheel()
			-- if mouse_wheel then
			-- 	curControl:_onMouseWheel(mouse_wheel)
			-- end

			return true
		end
	end
	if self.controlHover then
		self.controlHover:_onMouseHoverOut()
		self.controlHover = false
	end
	return false
end

function jGuiSub:_onMouseHoverOut()
	self.hover = false
	self.active = false

	if self.controlHover then
		self.controlHover:_onMouseHoverOut()
		self.controlHover = false
	end
end

function jGuiSub:_onMouseClick()
	-- Control the radial behaviour from here

	-- Submenu is active, pass on click
	if self.controlHover then
		self.controlHover:_onMouseClick()
	end
end


function jGuiSub:getArea()
	return self.area
end



function jGuiSub:controlAdd(oControl)
	oControl:_init()
	self.controls[#self.controls +1] = oControl
end


function jGuiSub._sortByZ(a, b)
	if a.z > b.z then
		return true
	else
		return false
	end
end

function jGuiSub._sortByZInv(b, a)
	if a.z > b.z then
		return true
	else
		return false
	end
end

function jGuiSub:getControlsByZ()
	local res = {table.unpack(self.controls)}
	table.sort(res, self._sortByZ)
	return res
end

function jGuiSub:getControlsByZInv()
	local res = {table.unpack(self.controls)}
	table.sort(res, self._sortByZInv)
	return res
end


--------------
function jGuiSub:onMouseClick()
	-- Add user stuff to do when a sub menu is clicked here
end