-- NoIndex: true
reaper.SetExtState("Soundmole", "CMD_AddSelectedToTarget", "1", false)
if reaper.APIExists('JS_Window_Find') then
  local hwnd = reaper.JS_Window_Find("Soundmole - Explore, Tag, and Organize Audio Resources", true)
  if hwnd then
    reaper.JS_Window_SetForeground(hwnd)
    reaper.JS_Window_SetFocus(hwnd)
  end
end