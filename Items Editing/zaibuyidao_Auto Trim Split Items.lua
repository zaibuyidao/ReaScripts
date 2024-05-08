-- @description Auto Trim Split Items
-- @version 2.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Trim Items Script Series, filter "zaibuyidao trim item" in ReaPack or Actions to access all scripts.

local ZBYDFuncPath = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Utility/zaibuyidao_Functions.lua'
if reaper.file_exists(ZBYDFuncPath) then
  dofile(ZBYDFuncPath)
  if not checkSWSExtension() or not checkJSAPIExtension() then return end
else
  local errorMsg = "Error - Missing Script (错误 - 缺失脚本)\n\n" ..
  "[English]\nThe required 'zaibuyidao Functions' script file was not found. Please ensure the file is correctly placed at:\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\nIf the file is missing, you can install it via ReaPack by searching for 'zaibuyidao Functions' in the ReaPack package browser.\n\n" ..
  "[中文]\n必需的 'zaibuyidao Functions' 脚本文件未找到。请确保文件正确放置在以下位置：\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\n如果文件缺失，您可以通过 ReaPack 包浏览器搜索并安装 'zaibuyidao Functions'。\n"

  reaper.MB(errorMsg, "Missing Script Error/脚本文件缺失错误", 0)

  if reaper.APIExists('ReaPack_BrowsePackages') then
    reaper.ReaPack_BrowsePackages('zaibuyidao Functions')
  else
    local reapackErrorMsg = "Error - ReaPack Not Found (错误 - 未找到 ReaPack)\n\n" ..
    "[English]\nThe ReaPack extension is not found. Please install ReaPack to manage and install REAPER scripts and extensions easily. Visit https://reapack.com for installation instructions.\n\n" ..
    "[中文]\n未找到 ReaPack 扩展。请安装 ReaPack 来便捷地管理和安装 REAPER 脚本及扩展。访问 https://reapack.com 获取安装指南。\n"

    reaper.MB(reapackErrorMsg, "ReaPack Not Found/未找到 ReaPack", 0)
  end
  return
end

local language = getSystemLanguage()

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

function checkTrimSetting()
  local trimSetting = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Items Editing/zaibuyidao_Auto Trim Split Items Settings.lua'

  if reaper.file_exists(trimSetting) then
    dofile(trimSetting)
  else
    reaper.MB(trimSetting:gsub('%\\', '/')..' not found. Please ensure the script is correctly placed.', '', 0)
    if reaper.APIExists('ReaPack_BrowsePackages') then
      reaper.ReaPack_BrowsePackages('zaibuyidao_Auto Trim Split Items Settings')
    else
      reaper.MB('ReaPack extension not found', '', 0)
    end
  end
end

local get = getSavedDataList("AUTO_TRIM_SPLIT_ITEMS", "Parameters")
if get == nil then
  checkTrimSetting()
  reaper.defer(function() end) -- 终止执行
  get = getSavedDataList("AUTO_TRIM_SPLIT_ITEMS", "Parameters")
end
--print(get)

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
  script_title = "自动修剪分割对象"
elseif language == "繁体中文" then
  script_title = "自動修剪分割對象"
else
  script_title = "Auto Trim Split Items"
end

reaper.Undo_EndBlock(script_title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()