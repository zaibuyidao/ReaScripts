-- @description Auto Trim Split Items Settings
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

get = getSavedDataList("AUTO_TRIM_SPLIT_ITEMS", "Parameters")

function set_default_value(value, default_value, is_number)
  if value == nil or (is_number and not tonumber(value)) then
    return default_value
  end
  return value
end

get = get or {}

THRESHOLD = set_default_value(get[1], -24.1, true)
HYSTERESIS = set_default_value(get[2], 0, true)
IGNORE_SILENCE_SHORTER = set_default_value(get[3], 100, true)
NONSILENT_CLIPS_SHORTER = set_default_value(get[4], 100, true)
LEADING_PAD = set_default_value(get[5], 3, true)
TRAILING_PAD = set_default_value(get[6], 3, true)
FADE_PAD = set_default_value(get[7], "y", false)
SNAP_OFFSET = set_default_value(get[8], 50, true)
MODE = set_default_value(get[9], "del", false)

default = THRESHOLD ..','.. HYSTERESIS ..','.. IGNORE_SILENCE_SHORTER ..','.. NONSILENT_CLIPS_SHORTER ..','.. LEADING_PAD ..','.. TRAILING_PAD ..','.. FADE_PAD ..','.. SNAP_OFFSET ..','.. MODE

if language == "简体中文" then
  title = "自动修剪分割对象设置"
  lable = "阈值 (dB),滞后 (dB),最小无声长度 (ms),最小剪辑长度 (ms),前导填充 (ms),尾部填充 (ms),是否淡化 (y/n),峰值吸附偏移 (ms),模式 (del/keep/begin/end)"
elseif language == "繁体中文" then
  title = "自動修剪分割對象設置"
  lable = "閾值 (dB),滯後 (dB),最小無聲長度 (ms),最小剪輯長度 (ms),前導填充 (ms),尾部填充 (ms),是否淡化 (y/n),峰值吸附偏移 (ms),模式 (del/keep/begin/end)"
else
  title = "Auto Trim Split Items Settings"
  lable = "Threshold (dB),Hysteresis (dB),Min silence length (ms),Min clips length (ms),Leading pad (ms),Trailing pad (ms),Fade pad (y/n),Peak snap offset (ms),Mode (del/keep/begin/end)"
end

reaper.Undo_BeginBlock()
set = getMutiInput(title, 9, lable, default)
if set == nil or not tonumber(THRESHOLD) or not tonumber(HYSTERESIS) or not tonumber(IGNORE_SILENCE_SHORTER) or not tonumber(NONSILENT_CLIPS_SHORTER) or not tonumber(LEADING_PAD) or not tonumber(TRAILING_PAD) or not tostring(FADE_PAD) or not tonumber(SNAP_OFFSET) or not tostring(MODE) then return end

saveDataList("AUTO_TRIM_SPLIT_ITEMS", "Parameters", set, true)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()