-- @description Auto Trim Split Items
-- @version 1.0.4
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(...)
  for _, v in ipairs({...}) do
    reaper.ShowConsoleMsg(tostring(v) .. " ") 
  end
  reaper.ShowConsoleMsg("\n")
end

if not reaper.SNM_GetIntConfigVar then
  local retval = reaper.ShowMessageBox("This script requires the SWS Extension.\n該脚本需要 SWS 擴展。\n\nDo you want to download it now? \n你想現在就下載它嗎？", "Warning 警告", 1)
  if retval == 1 then
    if not OS then local OS = reaper.GetOS() end
    if OS=="OSX32" or OS=="OSX64" then
      os.execute("open " .. "http://www.sws-extension.org/download/pre-release/")
    else
      os.execute("start " .. "http://www.sws-extension.org/download/pre-release/")
    end
  end
  return
end

if not reaper.APIExists("JS_Localize") then
  reaper.MB("Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\n請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n\nThen restart REAPER and run the script again, thank you!\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n", "You must install JS_ReaScriptAPI 你必須安裝JS_ReaScriptAPI", 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, "錯誤", 0)
  end
  return reaper.defer(function() end)
end

function getSystemLanguage()
  local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))
  local os = reaper.GetOS()
  local lang

  if os == "Win32" or os == "Win64" then -- Windows
    if locale == 936 then -- Simplified Chinese
      lang = "简体中文"
    elseif locale == 950 then -- Traditional Chinese
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  elseif os == "OSX32" or os == "OSX64" then -- macOS
    local handle = io.popen("/usr/bin/defaults read -g AppleLocale")
    local result = handle:read("*a")
    handle:close()
    lang = result:gsub("_", "-"):match("[a-z]+%-[A-Z]+")
    if lang == "zh-CN" then -- 简体中文
      lang = "简体中文"
    elseif lang == "zh-TW" then -- 繁体中文
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  elseif os == "Linux" then -- Linux
    local handle = io.popen("echo $LANG")
    local result = handle:read("*a")
    handle:close()
    lang = result:gsub("%\n", ""):match("[a-z]+%-[A-Z]+")
    if lang == "zh_CN" then -- 简体中文
      lang = "简体中文"
    elseif lang == "zh_TW" then -- 繁體中文
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  end

  return lang
end

function table.serialize(obj)
  local lua = ""
  local t = type(obj)
  if t == "number" then
    lua = lua .. obj
  elseif t == "boolean" then
    lua = lua .. tostring(obj)
  elseif t == "string" then
    lua = lua .. string.format("%q", obj)
  elseif t == "table" then
    lua = lua .. "{\n"
  for k, v in pairs(obj) do
    lua = lua .. "[" .. table.serialize(k) .. "]=" .. table.serialize(v) .. ",\n"
  end
  local metatable = getmetatable(obj)
  if metatable ~= nil and type(metatable.__index) == "table" then
    for k, v in pairs(metatable.__index) do
      lua = lua .. "[" .. table.serialize(k) .. "]=" .. table.serialize(v) .. ",\n"
    end
  end
  lua = lua .. "}"
  elseif t == "nil" then
    return nil
  else
    error("can not serialize a " .. t .. " type.")
  end
  return lua
end

function table.unserialize(lua)
  local t = type(lua)
  if t == "nil" or lua == "" then
    return nil
  elseif t == "number" or t == "string" or t == "boolean" then
    lua = tostring(lua)
  else
    error("can not unserialize a " .. t .. " type.")
  end
  lua = "return " .. lua
  local func = load(lua)
  if func == nil then return nil end
  return func()
end

function to_string_ex(value)
  if type(value)=='table' then
    return table_to_str(value)
  elseif type(value)=='string' then
    return value
  else
    return tostring(value)
  end
end

function table_to_str(t)
  if t == nil then return "" end
  local retstr= ""
  
  local i = 1
  for key,value in pairs(t) do
    local signal = "" .. ','
    if i == 1 then
      signal = ""
    end

    if key == i then
      retstr = retstr .. signal .. to_string_ex(value)
    else
      if type(key) == 'number' or type(key) == 'string' then
        retstr = retstr .. signal .. to_string_ex(value)
      else
        if type(key) == 'userdata' then
          retstr = retstr .. signal .. "*s" .. table_to_str(getmetatable(key)) .. "*e" .. "=" .. to_string_ex(value)
        else
          retstr = retstr .. signal .. key .. "=" .. to_string_ex(value)
        end
      end
    end
    i = i + 1
  end
  
  retstr = retstr .. ""
  return retstr
end
  
function string.split(input, delimiter)
  input = tostring(input)
  delimiter = tostring(delimiter)
  if (delimiter == "") then return false end
  local pos, arr = 0, {}
  for st, sp in function() return string.find(input, delimiter, pos, true) end do
      table.insert(arr, string.sub(input, pos, st - 1))
      pos = sp + 1
  end
  table.insert(arr, string.sub(input, pos))
  return arr
end
  
function saveData(key1, key2, data, boolean)
  reaper.SetExtState(key1, key2, data, boolean)
end
  
function getSavedData(key1, key2)
  return table.unserialize(reaper.GetExtState(key1, key2))
end
  
function saveDataList(key1, key2, data, boolean)
  reaper.SetExtState(key1, key2, table_to_str(data), boolean)
end
  
function getSavedDataList(key1, key2)
  local check_state = reaper.GetExtState(key1, key2)
  if check_state == nil or check_state == "" then
    return nil
  end
  return string.split(reaper.GetExtState(key1, key2), ",")
end
  
function getMutiInput(title,num,lables,defaults)
  title = title or "Title"
  lables = lables or "Lable:"
  local uok, uinput = reaper.GetUserInputs(title, num, lables, defaults)
  if uok then return string.split(uinput,",") end
end

local language = getSystemLanguage()

get = getSavedDataList("AUTO_TRIM_SPLIT_ITEMS", "Parameters")
if get == nil then
  THRESHOLD = -24.1 -- 阈值(dB)
  HYSTERESIS = 0  -- 滯後(dB)
  IGNORE_SILENCE_SHORTER = 100
  NONSILENT_CLIPS_SHORTER = 100
  LEADING_PAD = 3
  TRAILING_PAD = 3
  FADE_PAD = "y"
  SNAP_OFFSET = 50
  MODE = "del"

  default = THRESHOLD ..','.. HYSTERESIS ..','.. IGNORE_SILENCE_SHORTER ..','.. NONSILENT_CLIPS_SHORTER ..','.. LEADING_PAD ..','.. TRAILING_PAD ..','.. FADE_PAD ..','.. SNAP_OFFSET ..','.. MODE

  if language == "简体中文" then
    title = "自动修剪分割对象设置"
    lable = "阈值 (dB),滞后 (dB),最小静默长度 (ms),最小片段长度 (ms),前导填充 (ms),尾部填充 (ms),是否淡变 (y/n),峰值吸附偏移 (ms),模式 (del/keep/begin/end)"
  elseif language == "繁体中文" then
    title = "自動修剪分割對象設置"
    lable = "閾值 (dB),滯後 (dB),最小靜默長度 (ms),最小片段長度 (ms),前導填充 (ms),尾部填充 (ms),是否淡變 (y/n),峰值吸附偏移 (ms),模式 (del/keep/begin/end)"
  else
    title = "Auto Trim Split Items Settings"
    lable = "Threshold (dB),Hysteresis (dB),Min silence length (ms),Min clips length (ms),Leading pad (ms),Trailing pad (ms),Fade pad (y/n),Peak snap offset (ms),Mode (del/keep/begin/end)"
  end

  set = getMutiInput(title, 9, lable, default)
  if set == nil or not tonumber(THRESHOLD) or not tonumber(HYSTERESIS) or not tonumber(IGNORE_SILENCE_SHORTER) or not tonumber(NONSILENT_CLIPS_SHORTER) or not tonumber(LEADING_PAD) or not tonumber(TRAILING_PAD) or not tostring(FADE_PAD) or not tonumber(SNAP_OFFSET) or not tostring(MODE) then return end
  
  saveDataList("AUTO_TRIM_SPLIT_ITEMS", "Parameters", set, true)
  get = getSavedDataList("AUTO_TRIM_SPLIT_ITEMS", "Parameters")
end

function set_default_value(index, default_value, is_number)
  if get[index] == nil or (is_number and not tonumber(get[index])) then
    get[index] = default_value
  end
end

set_default_value(1, -24.1, true)
set_default_value(2, 0, true)
set_default_value(3, 100, true)
set_default_value(4, 100, true)
set_default_value(5, 3, true)
set_default_value(6, 3, true)
set_default_value(7, "y", false)
set_default_value(8, 50, true)
set_default_value(9, "del", false)

THRESHOLD = get[1]
HYSTERESIS = get[2]
IGNORE_SILENCE_SHORTER = get[3]
NONSILENT_CLIPS_SHORTER = get[4]
LEADING_PAD = get[5]
TRAILING_PAD = get[6]
FADE_PAD = get[7]
SNAP_OFFSET = get[8]
MODE = get[9]

if FADE_PAD == "n" then FADE_PAD = 0 elseif FADE_PAD == "y" then FADE_PAD = 1 else return end
if MODE == "del" then MODE = 0 elseif MODE == "keep" then MODE = 1 elseif MODE == "begin" then MODE = 2 elseif MODE == "end" then MODE = 3 else return end

function SetComboBoxIndex(hwnd, index)
  local id = reaper.JS_Window_AddressFromHandle(reaper.JS_Window_GetLongPtr(hwnd, "ID"))
  reaper.JS_WindowMessage_Send(hwnd, "CB_SETCURSEL", index, 0,0,0)
  reaper.JS_WindowMessage_Send(reaper.JS_Window_GetParent(hwnd), "WM_COMMAND", id, 1, reaper.JS_Window_AddressFromHandle(hwnd), 0) -- 1 = CBN_SELCHANGE
end

function auto_trim()
  local title_top = reaper.JS_Localize("Auto trim/split items", "common")
  local parent = reaper.JS_Window_Find(title_top, true)
  
  if parent then
    reaper.JS_Window_SetTitle(reaper.JS_Window_FindChildByID(parent, 1011), THRESHOLD) -- Threshold
    reaper.JS_Window_SetTitle(reaper.JS_Window_FindChildByID(parent, 1010), HYSTERESIS) -- Hysteresis
    reaper.JS_Window_SetTitle(reaper.JS_Window_FindChildByID(parent, 1007), IGNORE_SILENCE_SHORTER) -- Ignore silence shorter than
    reaper.JS_Window_SetTitle(reaper.JS_Window_FindChildByID(parent, 1008), NONSILENT_CLIPS_SHORTER) -- Make non-silent clips no shorter than
    reaper.JS_Window_SetTitle(reaper.JS_Window_FindChildByID(parent, 1012), LEADING_PAD) -- Leading pad
    reaper.JS_Window_SetTitle(reaper.JS_Window_FindChildByID(parent, 1013), TRAILING_PAD) -- Trailing pad
    chkBox = reaper.JS_Window_FindChildByID(parent, 1044) -- FadePad
    reaper.JS_WindowMessage_Send(chkBox, "BM_SETCHECK", FADE_PAD, 0, 0 ,0) -- 1,0,0,0 = 选中 0,0,0,0 = 非选中
    reaper.JS_Window_SetTitle(reaper.JS_Window_FindChildByID(parent, 1009), SNAP_OFFSET) -- Auto adjust snap offset to peak value in the first x ms
    
    SetComboBoxIndex(reaper.JS_Window_FindChildByID(parent, 1000), MODE) -- 模式： 0 = 分割并删除静音区域 1 = 分割并保留静音区域 2 = 仅在非静音之前分割 3 = 仅在静音之前分割
    
    -- 以下三个勾选项的功能屏蔽，请直接打开操作列表的 Auto trim/split items 进行设置
    -- Split grouped items at times of selected item splits
    -- Preserve timing of non-silent areas
    -- Run signal through track FX for detection

    -- chkBox = reaper.JS_Window_FindChildByID(parent, 1042) -- Split grouped items at times of selected item splits
    -- reaper.JS_WindowMessage_Send(chkBox, "BM_SETCHECK", 0,0,0,0) -- 1,0,0,0 = 选中 0,0,0,0 = 非选中
    -- chkBox = reaper.JS_Window_FindChildByID(parent, 1043) -- Preserve timing of non-silent areas
    -- reaper.JS_WindowMessage_Send(chkBox, "BM_SETCHECK", 1,0,0,0) -- 默认为选中
    -- chkBox = reaper.JS_Window_FindChildByID(parent, 1057) -- Run signal through track FX for detection
    -- reaper.JS_WindowMessage_Send(chkBox, "BM_SETCHECK", 0,0,0,0)

    reaper.JS_Window_OnCommand(parent, 1) -- Process = 1, Cancel = 2
  else
    reaper.defer(auto_trim) -- 循环直到找到窗口
  end
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

auto_trim()
reaper.JS_WindowMessage_Post(reaper.GetMainHwnd(), "WM_COMMAND", 40315, 0, 0, 0)

-- 第二种方案，等待 x 秒之后执行下一个动作

-- wait_time_in_seconds = 2 -- 等待秒数

-- -- 首先执行
-- auto_trim()
-- reaper.JS_WindowMessage_Post(reaper.GetMainHwnd(), "WM_COMMAND", 40315, 0, 0, 0)

-- lasttime = os.time()
-- loopcount = 0

-- function runloop()
--   local newtime=os.time()
  
--   if (loopcount < 1) then
--     if newtime - lasttime >= wait_time_in_seconds then
--       lasttime = newtime
--       -- 每 x 秒你想做什么事情
--       -- reaper.ShowConsoleMsg("等待了 " .. wait_time_in_seconds .. " 秒")
--       loopcount = loopcount+1
--     end
--   else
--     -- 等待 x 秒之后执行
--     auto_trim()
--     reaper.JS_WindowMessage_Post(reaper.GetMainHwnd(), "WM_COMMAND", 40315, 0, 0, 0)

--     loopcount = loopcount+1
--   end
--   if 
--     (loopcount < 2) then reaper.defer(runloop) 
--   end
-- end

-- reaper.defer(runloop)

if language == "简体中文" then
  title = "自动修剪分割对象"
elseif language == "繁体中文" then
  title = "自動修剪分割對象"
else
  title = "Auto Trim Split Items"
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()