--[[
@author n0ne
@version 0.7.2
@noindex
--]]

J_SCRIPT_DIR = reaper.GetResourcePath() .. "/Scripts/LUA/" -- This should not be there for reascript version??
package.path = package.path .. ";" .. J_SCRIPT_DIR .. "?.lua"

require('REQ.JGuiColors')
require ('REQ.JGuiControls')
require ('REQ.JGuiFunctions')

----------
-- This GUI class deals with the GUI and sending mouse info to the controls in it
-- Mouse script was largeley based of Schwa's GUI example


jGui = {
	title = "",
	width = 400,
	height = 500,
	x = 0,
	y = 0,
	dockstate = 0,
	
	mouse = require ('REQ.mouse'),
	kb = require('REQ.jKeyboard'),
	
	controls = {},
	controlActive = false,
	controlHover = false,
	controlDrag = false,
	
	focus = false,
	focusOrder = {},
	focusOrderIndex = false,
	
	settings = {
		fontsize = 10,
		font = "Arial",
		mouse_double_click_speed = 0.10,
		font_color = {1,1,1,1}
	},
	
	doExit = false,
	imageId = 0,
	
	lastChar = false -- this is where reapers gfx.getChar() is stored
}

function jGui:new(o)
	o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function jGui:init()
	gfx.init(self.title, self.width, self.height, self.dockstate, self.x, self.y)
	gfx.setfont(1, self.settings.font, self.settings.fontsize)

	gfx.clear = self.background_color or 3355443
	self:_resize() -- call once to do initial drawing
	self:updateFocusOrder()
end

function jGui:refresh()
	if (self.width ~= gfx.w or self.height ~= gfx.h) then
		self:_resize()
	end
	self:getControlHover()
	self:mouseUpdate()
	self:draw()
	gfx.drawstr(" ")
end

function jGui:_resize()
	self.width = gfx.w
	self.height = gfx.h
	self:onResize()
end

function jGui:onResize()
	-- user defined
end

function jGui:processKeyboard()
	-- this function handles the keyboard presses
	self.lastChar = gfx.getchar()
	if self.lastChar > 0 then
		-- Process special keys
		-- TODO process ESC here too!
		if self.lastChar == self.kb.escape then
			-- The escape closes the script and is not passed on to the control
			self:onEsc()		
		elseif self.lastChar == self.kb.enter and self.focus then -- ENTER
			self.focus:_onEnter()
		elseif self.lastChar == self.kb.tab and not self.kb.shift() then -- TAB
			if self.focus then
				self.focus:_onTab()
			else
				self:focusNext()
			end
		-- elseif self.lastChar == self.kb.arrow_down then -- ARROW DOWN
		-- 	if self.focus then
		-- 		self.focus:_onArrowDown()
		-- 	else
		-- 		self:focusNext()
		-- 	end
		elseif (self.lastChar == self.kb.tab and self.kb.shift()) then -- SHIFT TAB
			if self.focus then
				self.focus:_onShiftTab()
			else
				self:focusPrev()
			end		
		-- elseif self.lastChar == self.kb.arrow_up then --   ARROW UP
		-- 	if self.focus then
		-- 		self.focus:_onArrowUp()
		-- 	else
		-- 		self:focusPrev()
		-- 	end			
		else -- A key was pressed. Send it to the control with keyboard focus
			if self.focus then
				self.focus:_onKeyboard(self.lastChar)
			end
		end
	elseif self.lastChar == -1 then
		-- The window was closed
		self:onClose()
	end
	return self.lastChar
end

function jGui:focusNext()
	self:setFocus(self:getNextFocus())
end

function jGui:focusPrev()
	self:setFocus(self:getNextFocus(true))
end

function jGui:update()
	-- To be defined by user. Main program should go here. Excecuted after the keyboard is processed, before the gui is refreshed and drawn
end

function jGui:loop()
	-- Get the keypresses
	self:processKeyboard()
	
	self:update()
	
	self:refresh()

	-- Refresh the gfx window
	gfx.update()

	return not self.doExit
end

function jGui:draw()
	for i, curControl in ipairs(self:getControlsByZ()) do
		if curControl.visible then
			curControl:_draw()
		end
	end
end

function jGui:drawStr(sString, iX, iY, tFontColor)
	tFontColor = tFontColor or self.settings.font_color
	  
	gfx.setfont(1, self.settings.font, self.settings.fontsize)
	self:__setGfxColor(tFontColor)
	gfx.x = iX
	gfx.y = iY
	gfx.drawstr(sString)
end

function jGui:getControlHover()
	for i, curControl in ipairs(self:getControlsByZInv()) do
		curArea = curControl:getArea()
		if curControl.mouse_input and 
			curControl.visible and curArea[1] < gfx.mouse_x and gfx.mouse_x < curArea[3] and 
			curArea[2] < gfx.mouse_y and gfx.mouse_y < curArea[4] then
			
			if curControl ~= self.controlHover and self.controlHover then -- When the user hovers from one button directly onto another
				self.controlHover:_onMouseHoverOut()
			end
			
			self.controlHover = curControl
			curControl:_onMouseHover()

			-- Pass along potential mousewheel movement
			local mouse_wheel = self.mouse.mouse_wheel()
			if mouse_wheel then
				curControl:_onMouseWheel(mouse_wheel)
			end

			return true
		end
	end
	if self.controlHover then
		self.controlHover:_onMouseHoverOut()
		self.controlHover = false
	end
	return false
end

function jGui:controlAdd(oControl)
	oControl:_init()
	local iPos = #self.controls +1
	self.controls[iPos] = oControl
	
	if oControl.focus_index then -- check if this control is tab-able
		self.focusOrder[#self.focusOrder + 1] = oControl
	end
	
	oControl.parentGui = self
	return iPos
end

function jGui:controlAddAll(tControls)
	for _, c in pairs(tControls) do
		self:controlAdd(c)
	end
end

function jGui:controlGet(id)
	if id > #self.controls then
		msg("Control get id > # controls: " .. id .. ", " .. #self.controls)
	end
	if self.controls[id] == nil then
		msg("Control doenst exist: " .. id .. ", " .. #self.controls)
	end
	return self.controls[id]
end

function jGui:controlDeleteAll()
	self.controls = {}
	self.controlActive = false
	self.controlHover = false
end

function jGui:controlDelete(inC)
	-- msg("num controls: " .. #self.controls)
	-- msg("num focus: " .. #self.focusOrder)
	local bSucces = false
	for i, c in ipairs(self.controls) do
		if self.controls[i] == inC then
			-- self:controlDeleteId(i)
			table.remove(self.controls, i)
			bSucces = true
		end
	end
	if not bSucces then msg("Unable to remove control!") end
	for i, c in pairs(self.focusOrder) do
		if self.focusOrder[i] == inC then
			table.remove(self.focusOrder, i)
			-- msg("remove from focus order")
		end
	end

	if self.controlActive == inC then self.controlActive = false end
	if self.controlHover == inC then self.controlHover = false end
	if self.controlDrag == inC then self.controlDrag = false end
	if self.focus == inC then self.focus = false end

	self:updateFocusOrder()

end

function jGui:mouseUpdate()
	local mouse = self.mouse
  	local LB_DOWN = mouse.cap(mouse.LB)           -- Get current left mouse button state
  	local RB_DOWN = mouse.cap(mouse.RB)          -- Get current right mouse button state
  	local mx, my = gfx.mouse_x, gfx.mouse_y
  
  -- (modded Schwa's GUI example)
  if (LB_DOWN and not RB_DOWN) or (RB_DOWN and not LB_DOWN) then   -- LMB or RMB pressed down?
    if (mouse.last_LMB_state == false and not RB_DOWN) or (mouse.last_RMB_state == false and not LB_DOWN) then      
      if mouse.uptime and os.clock() - mouse.uptime < self.settings.mouse_double_click_speed and mouse.last_pressed_button == mouse.LB and LB_DOWN then
        self:OnMouseDoubleClickLMB(mx, my)
      else
      	self:OnMouseDown(mx, my, LB_DOWN, RB_DOWN)
      end
    elseif mx ~= mouse.last_x or my ~= mouse.last_y then
      self:OnMouseDrag(mx, my, LB_DOWN, RB_DOWN)
    end
      
  elseif not LB_DOWN and mouse.last_RMB_state or not RB_DOWN and mouse.last_LMB_state then
    self:OnMouseUp(mx, my, LB_DOWN, RB_DOWN)
  end
  
end

function jGui:OnMouseDown(x, y, lmb_down, rmb_down)
	local mouse = self.mouse
  -- LMB clicked
	if not rmb_down and lmb_down and mouse.last_LMB_state == false then
		mouse.last_LMB_state = true
		mouse.ox_l, mouse.oy_l = x, y
		mouse.last_pressed_button = mouse.LB
		--msg("lmb click")
		if self.controlHover then
			self.controlHover:_onMouseDown()
			self.controlActive = self.controlHover
			-- Shift focus
			self:setFocus(self.controlHover)
		else
		-- now new control, blur focus
			self:setFocus(false)
		end
	end
	-- RMB clicked
	if not lmb_down and rmb_down and mouse.last_RMB_state == false then
		mouse.last_RMB_state = true
		mouse.ox_r, mouse.oy_r = x, y
		mouse.last_pressed_button = mouse.RB
		-- msg("rmb click")
		if self.controlHover then
			self.controlHover:_onRightMouseDown()
			self.controlActive = self.controlHover
			-- Shift focus
			self:setFocus(self.controlHover)
		else
		-- now new control, blur focus
			self:setFocus(false)
		end
	end
	mouse.capcnt = 0       -- reset mouse capture count
end

function jGui:OnMouseUp(x, y, lmb_down, rmb_down)
  self.mouse.uptime = os.clock()
  self.mouse.dx = 0
  self.mouse.dy = 0
  if not lmb_down and self.mouse.last_LMB_state then 
  	self.mouse.last_LMB_state = false 
  	 if self.controlHover and self.controlHover == self.controlActive then
    	self.controlHover:_onMouseUp()
    elseif self.controlActive and self.controlDrag == self.controlActive then
		-- Ending a drag (no not hovering)
		self.controlActive:_onMouseUp()
    end
  end
  if not rmb_down and self.mouse.last_RMB_state then 
	self.mouse.last_RMB_state = false 
  	 if self.controlHover and self.controlHover == self.controlActive then
    	self.controlHover:_onRightMouseUp()
    elseif self.controlActive and self.controlDrag == self.controlActive then
		self.controlActive:_onRightMouseUp()
    end
  end
  
  self.controlActive = false
end

function jGui:OnMouseDoubleClickLMB(x, y)
  -- handle mouse double click here
  local mouse = self.mouse
  mouse.last_LMB_state = true
  mouse.ox_l, mouse.oy_l = x, y
  mouse.last_pressed_button = false
  --msg("double click")
end

function jGui:OnMouseDrag(x, y, lmb_down, rmb_down)
  -- handle mouse dragging here, left mouse button only
  local mouse = self.mouse
  
  if lmb_down then
  	mouse.last_x, mouse.last_y = x, y
  	mouse.dx = gfx.mouse_x - mouse.ox_l
  	mouse.dy = gfx.mouse_y - mouse.oy_l
  	mouse.capcnt = mouse.capcnt + 1
  end
  
 -- self.self.controlHover
	if self.controlActive then
		self.controlDrag = self.controlActive
		local res = self.controlActive:_onMouseDrag(mouse.dx, mouse.dy)
		if res&1==1 then -- control maxed out, reset startpoint
			mouse.ox_l = gfx.mouse_x
		end
		if res&2==2 then -- control maxed out, reset startpoint
			mouse.oy_l = gfx.mouse_y
		end
	end
end

function jGui:__setGfxColor(tColors)
	gfx.set(tColors[1], tColors[2], tColors[3], tColors[4])
end

function jGui:controlSetAll(tControls, key, value)
	for i, j in pairs(tControls) do
		j[key] = value
	end
end

function jGui:controlInitAll()
	for i, j in pairs(self.controls) do
		j:_init()
	end
end

function jGui:controlGetAll(tControls, key, value)
	local tResult = {}
	
	for i, j in pairs(tControls) do
		if j[key] == value then
			tResult[#tResult + 1] = j
		end
	end
	
	return tResult
end

function jGui:controlGetAllValues(tControls, key)
	local tResult = {}
	
	for i, j in pairs(tControls) do
		tResult[#tResult + 1] = j[key]
	end
	
	return tResult
end

function jGui:setFocus(c)
	-- Sets which gui control has focus.
	-- Set c to false to lose all focus
	if c == self.focus then -- already focussed on this control, nothing changes
		return false
	end
	
	if self.focus then -- blur the current focused control
		self.focus:_onBlur()
	end
	
	if c then
		self.focus = c
		c:_onFocus()
	else
		self.focus = false
	end
	-- msg("focus on: " .. tostring(self.focus) .. "/" .. #self.focusOrder)
end

function jGui:getFocusIndex()
	return #self.focusOrder + 1
end

function jGui:getNextFocus(bGetPrev)
	local bGetPrev = bGetPrev or false
	
	if #self.focusOrder < 1 then -- nothing to be focussed on
		return false
	end

	-- Check if there are any visible controls in the focus order
	local focusOrderVisible = {}
	for i, v in ipairs(self.focusOrder) do
		if v.visible then 
			table.insert(focusOrderVisible, v)
		end
	end
	if #focusOrderVisible < 1 then return false end -- There are no visible controls in the order
	
	if not self.focus then -- not focussed yet, start at 1 or last
		if bGetPrev then
			return focusOrderVisible[#focusOrderVisible]
		else
			return focusOrderVisible[1]
		end
	end
	
	for i, v in ipairs(focusOrderVisible) do
		if v == self.focus then
			if bGetPrev then
				local target = i - 1
				if i == 1 then -- first element, loop around
					target = #focusOrderVisible
				end
				return focusOrderVisible[target]
			else
				local target = i + 1
				if i == #focusOrderVisible then -- this is the last element, loop around
					target = 1
				end
				return focusOrderVisible[target]
			end
		end
	end
end

function jGui:updateFocusOrder()
	table.sort(self.focusOrder, jGui.__focusSort)
end

function jGui.__focusSort(a, b)
	-- used to sort tab indexes
	if a.focus_index < b.focus_index then
		return true
	else
		return false
	end
end

function jGui:exit()
	self:onExit()
	self.doExit = true
end

function jGui:onClose()
	-- Called when the window is closed. Default closes the script but could be overwritten by the user
	self:exit()
end

function jGui:onEsc()
	-- Called when the user presses Escape. Default closes the window but can be overwritten...
	self:exit()
end

function jGui:onExit()
	-- Called when the GUI is closed, to be defined by user
end

function jGui:getImgId()
	local r = self.imageId
	self.imageId = self.imageId + 1
	
	return r
end

function jGui._sortByZ(a, b)
	if a.z > b.z then
		return true
	else
		return false
	end
end

function jGui._sortByZInv(b, a)
	if a.z > b.z then
		return true
	else
		return false
	end
end

function jGui:getControlsByZ()
	local res = {table.unpack(self.controls)}
	table.sort(res, self._sortByZ)
	return res
end

function jGui:getControlsByZInv()
	local res = {table.unpack(self.controls)}
	table.sort(res, self._sortByZInv)
	return res
end

function jGui:setReaperFocus()
	if reaper.JS_Window_Find == nil then -- JS Extention not installed
		return false
	end

	local window = reaper.JS_Window_Find(self.title, true)
	if window then
		reaper.JS_Window_SetFocus(window)
		return true
	else
		return false
	end
end
