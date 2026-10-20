-- @noindex
-- 1175 UI only: resize its containing REAPER FX window, including native meters.
-- Called on demand by window-zoom.js; no defer loop, audio edits or startup action.
local section = 'ReaWeb1175WindowSize'
local request = reaper.GetExtState(section, 'request')
if request == '' then return end

reaper.DeleteExtState(section, 'request', false)

local fields = {}

for field in request:gmatch('[^|]+') do
  fields[#fields+1] = field
end

local token = fields[1]
if not token or not token:match('^[%w%-]+$') then return end

function reply(value)
  reaper.SetExtState(section, 'reply-'..token, value, false)
end

local ok, err = pcall(function()
  if not reaper.APIExists('JS_Window_Resize') then error('JS_ReaScriptAPI is required') end
  local x,y,w,h,tw,th = table.unpack(fields,2,7)
  x,y,w,h,tw,th = tonumber(x),tonumber(y),tonumber(w),tonumber(h),tonumber(tw),tonumber(th)

  if not th or not tw or tw<100 or th<100 or tw>16384 or th>16384 or not x or not y or not w or not h then
    error('Invalid bounds')
  end

  local matched, seen = {}, {}

  local function inspect(hwnd)
    if seen[hwnd] then return end
    seen[hwnd] = true
    if reaper.JS_Window_GetClassName(hwnd) ~= 'ReaWebAPI.Window' then return end
    local valid,l,t,r,b = reaper.JS_Window_GetRect(hwnd)
    if valid and math.abs(l-x)<2 and math.abs(t-y)<2 and math.abs(r-l-w)<2 and math.abs(b-t-h)<2 then matched[#matched+1]=hwnd end
  end

  local _, tops = reaper.JS_Window_ListAllTop()

  for address in tops:gmatch('[^,]+') do
    local top = reaper.JS_Window_HandleFromAddress(tonumber(address))
    inspect(top)
    local _, children = reaper.JS_Window_ListAllChild(top)
    for child in children:gmatch('[^,]+') do inspect(reaper.JS_Window_HandleFromAddress(tonumber(child))) end
  end

  if #matched~=1 then error('FX window could not be identified uniquely ('..#matched..')') end

  local web = matched[1]
  local owner = web

  for _=1,16 do
    if (math.floor(reaper.JS_Window_GetLong(owner,'STYLE')) & 0x40000000)==0 then break end
    local parent = reaper.JS_Window_GetParent(owner)
    if not parent then error('FX window parent is unavailable') end
    owner = parent
  end

  if owner==reaper.GetMainHwnd() or reaper.DockIsChildOfDock(web)>=0 then error('Open this FX in a floating window to resize it') end
  local valid,l,t,r,b = reaper.JS_Window_GetRect(owner)
  if not valid then error('FX window is unavailable') end
  local width,height = math.floor(r-l+tw-w+.5), math.floor(b-t+th-h+.5)
  reaper.JS_Window_Resize(owner,width,height)
  local _,nl,nt,nr,nb = reaper.JS_Window_GetRect(owner)
  reply(table.concat({'ok',nl,nt,nr-nl,nb-nt,r-l,b-t},'|'))
end)

if not ok then reply('error|'..tostring(err)) end
