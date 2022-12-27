-- @noindex
-- From Schwa's GUI example
-----------------
-- Mouse table --
-----------------

local mouse = {  
                  -- Constants
                  LB = 1,
                  RB = 2,
                  CTRL = 4,
                  SHIFT = 8,
                  ALT = 16,
                  
                  -- "cap" function
                  cap = function (mask)
                          if mask == nil then
                            return gfx.mouse_cap end
                          return gfx.mouse_cap&mask == mask
                        end,
                          
                  uptime = 0,
                  
                  last_x = -1, last_y = -1,
                 
                  dx = 0,
                  dy = 0,
                  
                  ox_l = 0, oy_l = 0,    -- left click positions
                  ox_r = 0, oy_r = 0,    -- right click positions
                  capcnt = 0,
                  last_LMB_state = false,
                  last_RMB_state = false,
                  last_pressed_button = false,
                  
                  -- Function to read and reset the mousewheel info
                  mouse_wheel = 
                    function()
                      local cur_scroll = gfx.mouse_wheel
                      if cur_scroll ~= 0 then
                        gfx.mouse_wheel = 0
                        return cur_scroll
                      else
                        return false
                      end
                    end


                    
               }

return mouse
