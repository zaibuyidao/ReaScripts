-- @noindex
-- @description ReaWebAPI: Native Streams
if not reaper.APIExists('ReaWeb_Open') then
  reaper.MB('Install ReaWebAPI v0.3.6.4 or later and restart REAPER.', 'ReaWebAPI', 0)
  return
end
local source = debug.getinfo(1, 'S').source
local directory = source:sub(2):match('^(.*[/\\])')
local id = reaper.ReaWeb_Open(directory .. 'index.html', source)
if id == 0 then reaper.MB(reaper.ReaWeb_GetLastError(), 'ReaWebAPI', 0) end
