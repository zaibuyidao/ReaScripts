-- @noindex
local source, resizable = ...
if type(source) ~= 'string' or type(resizable) ~= 'boolean' then
  reaper.MB('Run reawebapi-frameless-resizable.lua or reawebapi-frameless-fixed.lua. launch.lua is a helper and cannot be run directly.\n请运行 reawebapi-frameless-resizable.lua 或 reawebapi-frameless-fixed.lua，launch.lua 是辅助文件，不能单独运行。', 'ReaWebAPI', 0)
  return
end
if not reaper.APIExists('ReaWeb_OpenEx') then
  reaper.MB('Install ReaWebAPI v0.3.8.16 or later and restart REAPER.', 'ReaWebAPI', 0)
  return
end
local directory = source:sub(2):match('^(.*[/\\])')
local key = source:gsub('[%z\1-\31\\"]', function(c)
  if c == '\\' then return '\\\\' end
  if c == '"' then return '\\"' end
  return string.format('\\u%04x', c:byte())
end)
local options = string.format('{"instanceKey":"%s","frameless":true,"resizable":%s}', key, tostring(resizable))
local id = reaper.ReaWeb_OpenEx(directory .. 'index.html', options)
if id == 0 then reaper.MB(reaper.ReaWeb_GetLastError(), 'ReaWebAPI', 0) end
