-- @noindex
-- @description ReaWebAPI: Native Service with Lua Backend
if not reaper.APIExists("ReaWeb_Open") then
  reaper.MB("Install ReaWebAPI v0.3.6.3 or later and restart REAPER.", "ReaWebAPI", 0)
  return
end
local source = debug.getinfo(1, "S").source
local directory = source:sub(2):match("^(.*[/\\])")
local id = reaper.ReaWeb_Open(directory .. "index.html")
if id == 0 then reaper.MB(reaper.ReaWeb_GetLastError(), "ReaWebAPI", 0) return end
local function loop()
  if not reaper.ReaWeb_IsOpen(id) then return end
  for _ = 1, 32 do
    local message = reaper.ReaWeb_Receive(id)
    if message == "" then break end
    reaper.ReaWeb_Send(id, message)
  end
  reaper.defer(loop)
end
reaper.defer(loop)
