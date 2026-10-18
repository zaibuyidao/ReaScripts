-- @noindex
if not reaper.APIExists("ReaWeb_Open") then
  reaper.MB("Install ReaWebAPI v0.3.8.21 or later and restart REAPER.", "ReaWebamp", 0)
  return
end

local source = debug.getinfo(1, "S").source
local directory = source:sub(2):match("^(.*[/\\])")
local id = reaper.ReaWeb_Open(directory .. "index.html", source)
if id == 0 then reaper.MB(reaper.ReaWeb_GetLastError(), "ReaWebamp", 0) end

if id ~= 0 then
  local backend = dofile(directory .. "backend.lua").attach(id, directory)
  if backend then backend.step() end
end
