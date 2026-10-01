-- NoIndex: true
local r = reaper

for _, api in ipairs({"ReaWeb_Open", "ReaWeb_Send", "ReaWeb_Receive", "ReaWeb_IsReady"}) do
  if not r.APIExists(api) then
    r.MB("Install the current ReaWebAPI extension in UserPlugins and restart REAPER.", "TrackAxis", 0)
    return
  end
end

local source = debug.getinfo(1, "S").source
local directory = source:sub(2):match("^(.*[/\\])")
local window = r.ReaWeb_Open(directory .. "index.html", source)

if window == 0 then r.MB(r.ReaWeb_GetLastError(), "TrackAxis", 0) return end
if tonumber(r.GetExtState("ReaWebAPI.Backends", source)) == window then return end
r.SetExtState("ReaWebAPI.Backends", source, tostring(window), false)

local json = dofile(directory .. "json.lua")
local backend = dofile(directory .. "backend.lua")(r, json, function(data)
  return r.ReaWeb_Send(window, json.encode(data))
end)

r.atexit(function()
  backend.close()
  r.ReaWeb_Close(window)
  if r.GetExtState("ReaWebAPI.Backends", source) == tostring(window) then
    r.DeleteExtState("ReaWebAPI.Backends", source, false)
  end
end)

function loop()
  if not r.ReaWeb_IsOpen(window) then return end

  for _ = 1, 24 do
    local raw = r.ReaWeb_Receive(window)
    if raw == "" then break end

    if #raw <= 65536 then
      local ok, message = pcall(json.decode, raw)
      if ok and type(message) == "table" then backend.receive(message) end
    end
  end

  if r.ReaWeb_IsReady(window) then backend.tick(r.time_precise()) end
  r.defer(loop)
end

loop()
