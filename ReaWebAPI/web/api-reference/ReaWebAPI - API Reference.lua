-- @noindex
-- @description ReaWebAPI: API Reference

if not reaper.APIExists("ReaWeb_Open") then
  reaper.MB("Install ReaWebAPI and restart REAPER to open the API reference.", "ReaWebAPI", 0)
  return
end

local source = debug.getinfo(1, "S").source
local directory = source:sub(2):match("^(.*[/\\])")
if reaper.ReaWeb_Open(directory .. "reawebapihelp.html", source) == 0 then
  reaper.MB(reaper.ReaWeb_GetLastError(), "ReaWebAPI: API Reference", 0)
end
