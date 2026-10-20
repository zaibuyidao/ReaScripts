-- @noindex
-- UI-only action: do not create a project undo point.
reaper.defer(function() end)
local section = 'ReaWeb1175WindowSize'
local request = reaper.GetExtState(section, 'request')
if request == '' then return end
reaper.DeleteExtState(section, 'request', false)
local fields = {}
for field in request:gmatch('[^|]+') do fields[#fields+1] = field end
local token, identity = fields[1], fields[2]
if not token or not token:match('^[%w%-]+$') then return end
local function reply(value) reaper.SetExtState(section, 'reply-'..token, value, false) end
local scales = {[0.5]=true,[0.75]=true,[1]=true,[1.5]=true,[2]=true,[2.5]=true,[3]=true}
local ok, err = pcall(function()
  local zoom, units, mode = tonumber(fields[3]), tonumber(fields[4]), fields[5]
  if not identity or not identity:match('^[%w%-]+$') or not scales[zoom] or
      not units or units < 0.5 or units > 8 or
      (mode ~= 'change' and mode ~= 'init' and mode ~= 'sync') then error('Invalid scale request') end
  local title = '1175 ReaWeb UI [zoom-'..identity..']'
  local matched, seen = {}, {}
  local function inspect(hwnd)
    if not hwnd or seen[hwnd] then return end
    seen[hwnd] = true
    if reaper.JS_Window_GetTitle(hwnd) == title then matched[#matched+1] = hwnd end
  end
  local _, tops = reaper.JS_Window_ListAllTop()
  for address in tops:gmatch('[^,]+') do
    local top = reaper.JS_Window_HandleFromAddress(tonumber(address))
    inspect(top)
    local _, children = reaper.JS_Window_ListAllChild(top)
    for child in children:gmatch('[^,]+') do inspect(reaper.JS_Window_HandleFromAddress(tonumber(child))) end
  end
  if #matched ~= 1 then reply('retry|FX view is being attached'); return end
  local web, owner, chain = matched[1], matched[1], false
  -- Runtime reports activation before present() shows a cached view. Keep the
  -- request pending until it is visible; JS cancels it if activation is lost.
  -- Returning "skip" here permanently leaves the chain at manifest size.
  if not reaper.JS_Window_IsVisible(web) then reply('retry|FX view is not visible yet'); return end
  for _=1,32 do
    local list = reaper.JS_Window_FindChildByID(owner,1076)
    if list and reaper.JS_Window_GetParent(list) == owner then chain = true end
    if (math.floor(reaper.JS_Window_GetLong(owner,'STYLE')) & 0x40000000) == 0 then break end
    owner = reaper.JS_Window_GetParent(owner)
    if not owner then error('FX window parent is unavailable') end
  end
  -- Both hosts must fit the page on activation. A chain->floating move reuses
  -- the page but REAPER may restore a different native frame size. Floating
  -- editors use the page's current zoom; only chains read/publish chain-zoom.
  if chain and mode ~= 'change' then
    local saved = tonumber(reaper.GetExtState(section,'chain-zoom'))
    if scales[saved] then zoom = saved end
  end
  if owner == reaper.GetMainHwnd() or reaper.DockIsChildOfDock(web) >= 0 then
    error('Open this FX chain outside the Docker to resize it')
  end
  local valid,wl,wt,wr,wb = reaper.JS_Window_GetRect(web)
  local outer,l,t,r,b = reaper.JS_Window_GetRect(owner)
  if not valid or not outer then reply('retry|FX window is unavailable'); return end
  local w,h = math.abs(wr-wl),math.abs(wb-wt)
  local tw = math.floor(1380*zoom*units+0.5)
  local th = math.ceil((30+1380*258/1400+34)*zoom*units)
  local width,height = math.floor(math.abs(r-l)+tw-w+0.5),math.floor(math.abs(b-t)+th-h+0.5)
  if width < 100 or height < 100 or width > 16384 or height > 16384 then error('Invalid window size') end
  if chain then reaper.SetExtState(section,'chain-zoom',tostring(zoom),true) end
  if math.abs(tw-w)>1 or math.abs(th-h)>1 then
    if reaper.GetOS():match('OSX') or reaper.GetOS():match('macOS') then
      -- SWELL screen Y increases upward. Preserve the top edge when resizing.
      reaper.JS_Window_SetPosition(owner,l,math.max(t,b)-height,width,height)
    else
      reaper.JS_Window_Resize(owner,width,height)
    end
    local changed,nl,nt,nr,nb = reaper.JS_Window_GetRect(web)
    if not changed or math.abs(math.abs(nr-nl)-tw)>2 or math.abs(math.abs(nb-nt)-th)>2 then
      reply('retry|FX chain layout is settling'); return
    end
  end
  reply('ok|'..zoom..'|'..(chain and 'chain' or 'floating'))
end)
if not ok then reply('error|'..tostring(err)) end
