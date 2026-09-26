-- -- NoIndex: true
for _, name in ipairs({ 'ReaWeb_Open', 'ReaGBA_Create' }) do
  if not reaper.APIExists(name) then
    reaper.MB('Install ReaWebAPI v0.3.6.4 or later and ReaGBA in UserPlugins, then restart REAPER.\nMissing API: ' .. name, 'ReaGBA', 0)
    return
  end
end

local source = debug.getinfo(1, 'S').source
local directory = source:sub(2):match('^(.*[/\\])')
local id = reaper.ReaWeb_Open(directory .. 'index.html', source)
if id == 0 then reaper.MB(reaper.ReaWeb_GetLastError(), 'ReaGBA', 0) end
