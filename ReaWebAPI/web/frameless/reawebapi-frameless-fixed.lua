-- @noindex
-- @description ReaWebAPI: Frameless Window (Fixed Size)
local source = debug.getinfo(1, 'S').source
local directory = source:sub(2):match('^(.*[/\\])')
assert(loadfile(directory .. 'launch.lua'))(source, false)
