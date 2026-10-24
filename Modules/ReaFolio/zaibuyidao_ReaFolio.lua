-- @noindex
local source = debug.getinfo(1, "S").source
local directory = source:sub(2):match("^(.*[/\\])")

if not reaper.APIExists("ReaWeb_OpenEx") then
  reaper.MB("Install ReaWebAPI v0.3.9.2 or later, then restart REAPER.", "reafolio", 0)
  return
end

-- Whole native caption, including its occupied height, with the preference persisted in REAPER.
local frameless = reaper.GetExtState('reafolio', 'hideTitleBar') ~= 'false'
local key = source:gsub('[%z\1-\31\\"]', function(c)
  if c == '\\' then return '\\\\' end
  if c == '"' then return '\\"' end
  return string.format('\\u%04x', c:byte())
end)

local options = string.format('{"instanceKey":"%s","frameless":%s,"resizable":true}', key, tostring(frameless))
local window = reaper.ReaWeb_OpenEx(directory .. "index.html", options)
if window == 0 then
  reaper.MB(reaper.ReaWeb_GetLastError(), "reafolio", 0)
  return
end

local backend = dofile(directory .. 'lua/backend.lua')
backend.run(reaper, window, source, reaper.GetResourcePath() .. '/ReaWebAPI/Apps/reafolio/Data')
