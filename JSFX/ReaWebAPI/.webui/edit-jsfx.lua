-- @noindex
-- Suppress the automatic ReaScript undo point for this UI-only action.
reaper.defer(function() end)
-- Open only the source editor belonging to the requesting 1175 WebUI.
-- Windows / REAPER 7, using the same js_ReaScriptAPI dependency as window zoom.
local section = 'ReaWeb1175SourceEditor'
local request = reaper.GetExtState(section, 'request')
if request == '' then return end
reaper.DeleteExtState(section, 'request', false)

local fields={}

for f in request:gmatch('[^|]+') do
  fields[#fields+1] = f
end

local token = fields[1]
if not token or not token:match('^[%w%-]+$') then return end
local function reply(s) reaper.SetExtState(section,'reply-'..token,s,false) end

local ok, err = pcall(function()
  if not reaper.GetOS():match('Win') then error('EDIT JSFX is currently supported on Windows.') end
  if not reaper.APIExists('JS_WindowMessage_Post') then error('js_ReaScriptAPI is required.') end
  local x, y, w, h = tonumber(fields[2]), tonumber(fields[3]), tonumber(fields[4]), tonumber(fields[5])
  if not x or not y or not w or not h or w <= 0 or h <= 0 then error('Invalid FX window bounds.') end

  local matched, seen = {}, {}
  local function inspect(hwnd)
    if seen[hwnd] then return end
    seen[hwnd] = true

    if reaper.JS_Window_GetClassName(hwnd) ~= 'ReaWebAPI.Window' then return end
    if not reaper.JS_Window_GetTitle(hwnd):find('1175',1,true) then return end
    local valid, l, t, r, b = reaper.JS_Window_GetRect(hwnd)

    if valid and math.abs(l-x) < 2 and math.abs(t-y) < 2 and math.abs(r-l-w) < 2 and math.abs(b-t-h) < 2 then
      matched[#matched+1] = hwnd
    end
  end

  local _, tops = reaper.JS_Window_ListAllTop()

  for a in tops:gmatch('[^,]+') do
    local top = reaper.JS_Window_HandleFromAddress(tonumber(a));inspect(top)
    local _, children = reaper.JS_Window_ListAllChild(top)

    for c in children:gmatch('[^,]+') do
      inspect(reaper.JS_Window_HandleFromAddress(tonumber(c)))
    end
  end

  if #matched ~= 1 then
    error('The current FX window could not be identified uniquely.')
  end

  local owner = reaper.JS_Window_GetParent(matched[1])
  local button = nil

  for _ = 1, 12 do
    if not owner or owner == reaper.GetMainHwnd() then break end
    local candidates = {}

    local function inspectButton(c)
      if reaper.JS_Window_GetLong(c,'ID') ~= 1062 or reaper.JS_Window_GetClassName(c) ~= 'Button' then
        return
      end

      local parent = reaper.JS_Window_GetParent(c)
      local label = reaper.JS_Window_FindChildByID(parent,1023)
      local gfx = reaper.JS_Window_FindChildByID(parent,65295)

      if label and gfx and reaper.JS_Window_GetTitle(label):match('^1175') then
        candidates[#candidates+1] = c
      end
    end

    local _, children = reaper.JS_Window_ListAllChild(owner)
  
    for a in children:gmatch('[^,]+') do
      inspectButton(reaper.JS_Window_HandleFromAddress(tonumber(a)))
    end
  
    if #candidates > 1 then
      error('More than one native JSFX editor was found. Open this FX in a floating window.')
    end
  
    if #candidates == 1 then
      button = candidates[1]

      break
    end
  
    owner = reaper.JS_Window_GetParent(owner)
  end

  if not button then error('The native JSFX Edit control is unavailable. Reopen this FX and try again.') end
  -- BM_CLICK is posted, never synchronously sent, so opening the IDE cannot
  -- block a WebView request waiting on the REAPER UI thread.
  if not reaper.JS_WindowMessage_Post(button, '0x00F5', 0, 0, 0, 0) then error('Could not open the JSFX editor.') end
  reply('ok')
end)

if not ok then reply('error|'..tostring(err)) end
