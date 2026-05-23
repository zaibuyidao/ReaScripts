-- NoIndex: true
local section = "Soundmole"
local key = "CMD_ToggleMainCollapse"

local value = tonumber(reaper.GetExtState(section, key)) or 0
reaper.SetExtState(section, key, tostring(value + 1), false)
