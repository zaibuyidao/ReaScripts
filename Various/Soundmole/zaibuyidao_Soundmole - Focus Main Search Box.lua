-- NoIndex: true
local section = "Soundmole"
local key = "CMD_FocusMainSearchBox"

local value = tonumber(reaper.GetExtState(section, key)) or 0
reaper.SetExtState(section, key, tostring(value + 1), false)
if reaper.APIExists('JS_Window_Find') then
  local hwnd = reaper.JS_Window_Find("Soundmole - Explore, Tag, and Organize Audio Resources", true)
  if hwnd then
    reaper.JS_Window_SetForeground(hwnd)
    reaper.JS_Window_SetFocus(hwnd)
  end
end
