-- @noindex
if reaper.set_action_options then reaper.set_action_options(1) end
local source = debug.getinfo(1, "S").source
local directory = source:sub(2):match("^(.*[/\\])")
if not reaper.APIExists("ReaWeb_OpenEx") then
  reaper.MB("Install ReaWebAPI v0.3.9.43 or later, then restart REAPER.", "ReaEmulator", 0)
  return
end
local key = source:gsub('[%z\1-\31\\"]', function(c)
  if c == '\\' then return '\\\\' end
  if c == '"' then return '\\"' end
  return string.format('\\u%04x', c:byte())
end)
local window = reaper.ReaWeb_OpenEx(directory .. "index.html",
  string.format('{"instanceKey":"%s","resizable":true}', key))
if window == 0 then
  reaper.MB(reaper.ReaWeb_GetLastError(), "ReaEmulator", 0)
else
  dofile(directory .. 'app/host/native-files.lua')(window)
end
