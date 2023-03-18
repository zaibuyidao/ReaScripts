-- @description Trim Items Edge Settings
-- @version 1.1.8
-- @author zaibuyidao
-- @changelog Fix fade pad
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(...)
  local params = {...}
  for i = 1, #params do
    if i ~= 1 then reaper.ShowConsoleMsg(" ") end
    reaper.ShowConsoleMsg(tostring(params[i]))
  end
  reaper.ShowConsoleMsg("\n")
end

function table.print(t)
  local print_r_cache = {}
  local function sub_print_r(t, indent)
    if (print_r_cache[tostring(t)]) then
      print(indent .. "*" .. tostring(t))
    else
      print_r_cache[tostring(t)] = true
      if (type(t) == "table") then
        for pos, val in pairs(t) do
          if (type(val) == "table") then
            print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(t) .. " {")
            sub_print_r(val, indent .. string.rep(" ", string.len(tostring(pos)) + 8))
            print(indent .. string.rep(" ", string.len(tostring(pos)) + 6) .. "}")
          elseif (type(val) == "string") then
            print(indent .. "[" .. tostring(pos) .. '] => "' .. val .. '"')
          else
            print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(val))
          end
        end
      else
        print(indent .. tostring(t))
      end
    end
  end
  if (type(t) == "table") then
    print(tostring(t) .. " {")
    sub_print_r(t, "  ")
    print("}")
  else
    sub_print_r(t, "  ")
  end
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

get = getSavedDataList("TRIM_ITEMS_EDGE", "Parameters")

if get == nil then   -- 默认预设
  threshold_l = -60  -- 阈值(dB)
  threshold_r = -6   -- 滯後(dB)
  leading_pad = 0    -- 前导填充(ms)
  trailing_pad = 0   -- 尾部填充(ms)
  length_limit = 100 -- 长度限制(ms)
  snap_offset = 0    -- 吸附偏移(ms)
  step = 0           -- 采样点步进
  fade = "n"         -- 是否淡变
else
  if get[1] == nil or not tonumber(get[1]) then get[1] = -60 end
  if get[2] == nil or not tonumber(get[2]) then get[2] = -6 end
  if get[3] == nil or not tonumber(get[3]) then get[3] = 0 end
  if get[4] == nil or not tonumber(get[4]) then get[4] = 0 end
  if get[5] == nil or not tonumber(get[5]) then get[5] = 100 end
  if get[6] == nil or not tonumber(get[6]) then get[6] = 0 end
  if get[7] == nil or not tonumber(get[7]) then get[7] = 0 end
  if get[8] == nil or not tostring(get[8]) then get[8] = "n" end
  threshold_l = get[1]
  threshold_r = get[2]
  leading_pad = get[3]
  trailing_pad = get[4]
  length_limit = get[5]
  snap_offset = get[6]
  step = get[7]
  fade = get[8]
end

default = threshold_l ..','.. threshold_r ..','.. leading_pad ..','.. trailing_pad ..','.. length_limit ..','.. snap_offset ..','.. step ..','.. fade

if language == "简体中文" then
  title = "修剪对象边缘设置"
  lable = "阈值 (dB),滞后 (dB),前导填充 (ms),尾部填充 (ms),最小对象长度 (ms),吸附偏移到峰值 (ms),采样点步进,是否淡变 (y/n)"
elseif language == "繁体中文" then
  title = "修剪對象邊緣設置"
  lable = "閾值 (dB),滯後 (dB),前導填充 (ms),尾部填充 (ms),最小對象長度 (ms),吸附偏移到峰值 (ms),采樣點步進,是否淡變 (y/n)"
else
  title = "Trim Items Edge Settings"
  lable = "Threshold (dB),Hysteresis (dB),Leading pad (ms),Trailing pad (ms),Min item length (ms),Snap offset to peak (ms),Sample step,Fade pad (y/n)"
end

reaper.Undo_BeginBlock()
set = getMutiInput(title, 8, lable, default)
if set == nil or not tonumber(threshold_l) or not tonumber(threshold_r) or not tonumber(leading_pad) or not tonumber(trailing_pad) or not tonumber(length_limit) or not tonumber(snap_offset) or not tonumber(step) or not tostring(fade) then return end

for i = 1, #set do
  if i == 8 then
    if not tostring(set[8]) then return end
  else
    if not tonumber(set[i]) then return end
  end
end

saveDataList("TRIM_ITEMS_EDGE", "Parameters", set, true)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()