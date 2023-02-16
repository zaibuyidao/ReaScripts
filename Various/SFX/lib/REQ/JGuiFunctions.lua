--[[
@author n0ne
@version 0.7.0
@noindex
--]]

-- Some functions to help working with the JGui

-- Create multiple controls of controlType in a grid
function createControls(controlType, num, perRow, settings, x, y, w, h, x_space, y_space)
    local tResult = {}
    local xOffs = 0
    local yOffs = 0
    
    for i = 1, num do
        if (i-1) % perRow == 0 and i > perRow then
            yOffs = yOffs + h + y_space
            xOffs = 0
        end
        
        c = controlType:new()
        c:setSettings(settings)
        c.width = w
        c.height = h
        c.x = x + xOffs
        c.y = y + yOffs
        
        table.insert(tResult, c)
        
        xOffs = xOffs + w + x_space
    end

    return tResult
end
