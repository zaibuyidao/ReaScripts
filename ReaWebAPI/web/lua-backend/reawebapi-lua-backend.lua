-- @noindex
-- @description ReaWebAPI: Lua backend and WebView UI
local reaper = reaper
if not reaper.APIExists("ReaWeb_Send") then
  reaper.MB("Install a ReaWebAPI version with the Lua message bridge.", "ReaWebAPI", 0)
  return
end
local directory = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])")
local instanceKey = debug.getinfo(1, "S").source
local id = reaper.ReaWeb_Open(directory .. "index.html", instanceKey)
if id == 0 then
  reaper.MB(reaper.ReaWeb_GetLastError(), "ReaWebAPI", 0)
  return
end
-- ExtState owns the Lua polling loop. C++ owns window reuse.
if tonumber(reaper.GetExtState("ReaWebAPI.Backends", instanceKey)) == id then return end
reaper.SetExtState("ReaWebAPI.Backends", instanceKey, tostring(id), false)
reaper.atexit(function()
  reaper.ReaWeb_Close(id)
  if reaper.GetExtState("ReaWebAPI.Backends", instanceKey) == tostring(id) then
    reaper.DeleteExtState("ReaWebAPI.Backends", instanceKey, false)
  end
end)

local escapes = { ['"'] = '\\"', ['\\'] = '\\\\' }
local function json_string(text)
  return '"' .. text:gsub('[%z\1-\31\\"]', function(c)
    return escapes[c] or string.format('\\u%04x', c:byte())
  end) .. '"'
end

local previous, next_update = nil, 0
local function state()
  local track = reaper.GetSelectedTrack(0, 0)
  if not track then return '{"type":"state","track":null}' end
  local _, name = reaper.GetTrackName(track)
  local volume = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
  return '{"type":"state","track":{"name":' .. json_string(name)
    .. ',"volume":' .. string.format('%.10f', volume):gsub(',', '.') .. '}}'
end

local function loop()
  if not reaper.ReaWeb_IsOpen(id) then return end
  for _ = 1, 32 do
    local message = reaper.ReaWeb_Receive(id)
    if message == "" then break end
    if message == "ready" then previous, next_update = nil, 0 end
    local value = tonumber(message:match("^volume ([%d%.]+)$"))
    if value and value >= 0 and value <= 2 then
      local track = reaper.GetSelectedTrack(0, 0)
      if track then
        reaper.SetMediaTrackInfo_Value(track, "D_VOL", value)
        reaper.UpdateArrange()
        next_update = 0
      end
    end
  end
  local now = reaper.time_precise()
  if reaper.ReaWeb_IsReady(id) and now >= next_update then
    local message = state()
    if message ~= previous and reaper.ReaWeb_Send(id, message) then previous = message end
    next_update = now + 0.1
  end
  reaper.defer(loop)
end
loop()
