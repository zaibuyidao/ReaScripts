-- @description Trim Split Items Settings
-- @version 2.0.6
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

function default_if_invalid(input, default, convert)
  return (input == nil or not convert(input)) and default or convert(input)
end

get = getSavedDataList("TRIM_SPLIT_ITEMS_SETTINGS", "Parameters")

if get == nil then      -- 默认预设
  THRESHOLD = -24.1     -- 阈值(dB)
  HYSTERESIS = 0        -- 滯後(dB)
  MIN_SILENCE_LEN = 100 -- 最小静默长度
  MIN_CLIPS_LEN = 100   -- 最小片段长度
  LEFT_PAD = 3          -- 前导填充(ms)
  RIGHT_PAD = 3         -- 尾部填充(ms)
  FADE = "y"            -- 是否淡变
  SNAP_OFFSET = 50      -- 峰值吸附偏移(ms)
  SKIP_SAMPLE = 0       -- 采样点步进
  MODE = "del"          -- 保持静默
else
  THRESHOLD = default_if_invalid(get[1], -24.1, tonumber)
  HYSTERESIS = default_if_invalid(get[2], 0, tonumber)
  MIN_SILENCE_LEN = default_if_invalid(get[3], 100, tonumber)
  MIN_CLIPS_LEN = default_if_invalid(get[4], 100, tonumber)
  LEFT_PAD = default_if_invalid(get[5], 3, tonumber)
  RIGHT_PAD = default_if_invalid(get[6], 3, tonumber)
  FADE = default_if_invalid(get[7], "y", tostring)
  SNAP_OFFSET = default_if_invalid(get[8], 50, tonumber)
  SKIP_SAMPLE = default_if_invalid(get[9], 0, tonumber)
  MODE = default_if_invalid(get[10], "del", tostring)
end

default = THRESHOLD ..','.. HYSTERESIS ..','.. MIN_SILENCE_LEN ..','.. MIN_CLIPS_LEN ..','.. LEFT_PAD ..','.. RIGHT_PAD ..','.. FADE ..','.. SNAP_OFFSET ..','.. SKIP_SAMPLE ..','.. MODE

if language == "简体中文" then
  title = "修剪分割对象设置"
  lable = "阈值 (dB),滞后 (dB),最小无声长度 (ms),最小剪辑长度 (ms),前导填充 (ms),尾部填充 (ms),是否淡化 (y/n),峰值吸附偏移 (ms),采样点步长,模式 (del/keep/begin/end)"
elseif language == "繁体中文" then
  title = "修剪分割對象設置"
  lable = "閾值 (dB),滯後 (dB),最小無聲長度 (ms),最小剪輯長度 (ms),前導填充 (ms),尾部填充 (ms),是否淡化 (y/n),峰值吸附偏移 (ms),采樣點步長,模式 (del/keep/begin/end)"
else
  title = "Trim Split Items Settings"
  lable = "Threshold (dB),Hysteresis (dB),Min silence length (ms),Min clips length (ms),Leading pad (ms),Trailing pad (ms),Fade pad (y/n),Peaks snap offset (ms),Samples step size,Mode (del/keep/begin/end)"
end

reaper.Undo_BeginBlock()
set = getMutiInput(title, 10, lable, default)

local parameters = {
  {name = "THRESHOLD", func = tonumber},
  {name = "HYSTERESIS", func = tonumber},
  {name = "MIN_SILENCE_LEN", func = tonumber},
  {name = "MIN_CLIPS_LEN", func = tonumber},
  {name = "LEFT_PAD", func = tonumber},
  {name = "RIGHT_PAD", func = tonumber},
  {name = "FADE", func = tostring},
  {name = "SNAP_OFFSET", func = tonumber},
  {name = "SKIP_SAMPLE", func = tonumber},
  {name = "MODE", func = tostring}
}

for _, param in ipairs(parameters) do
  if set == nil or not param.func(_G[param.name]) then
    return
  end
end

saveDataList("TRIM_SPLIT_ITEMS_SETTINGS", "Parameters", set, true)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()