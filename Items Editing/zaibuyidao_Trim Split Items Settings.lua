-- @description Trim Split Items Settings
-- @version 1.0.8
-- @author zaibuyidao
-- @changelog Preset parameter optimization
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

get = getSavedDataList("TRIM_SPLIT_ITEMS", "Parameters")

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
  SPLIT = "y"           -- 是否切割item
  MODE = "del"          -- 保持静默
else
  if get[1] == nil or not tonumber(get[1]) then get[1] = -24.1 end
  if get[2] == nil or not tonumber(get[2]) then get[2] = 0 end
  if get[5] == nil or not tonumber(get[3]) then get[3] = 100 end
  if get[6] == nil or not tonumber(get[4]) then get[4] = 100 end
  if get[3] == nil or not tonumber(get[5]) then get[5] = 3 end
  if get[4] == nil or not tonumber(get[6]) then get[6] = 3 end
  if get[9] == nil or not tostring(get[7]) then get[7] = "y" end
  if get[7] == nil or not tonumber(get[8]) then get[8] = 50 end
  if get[8] == nil or not tonumber(get[9]) then get[9] = 0 end
  if get[10] == nil or not tostring(get[10]) then get[10] = "y" end
  if get[11] == nil or not tostring(get[11]) then get[11] = "del" end
  THRESHOLD = tonumber(get[1])
  HYSTERESIS = tonumber(get[2])
  MIN_SILENCE_LEN = tonumber(get[3])
  MIN_CLIPS_LEN = tonumber(get[4])
  LEFT_PAD = tonumber(get[5])
  RIGHT_PAD = tonumber(get[6])
  FADE = tostring(get[7])
  SNAP_OFFSET = tonumber(get[8])
  SKIP_SAMPLE = tonumber(get[9])
  SPLIT = tostring(get[10])
  MODE = tostring(get[11])
end

default = THRESHOLD ..','.. HYSTERESIS ..','.. MIN_SILENCE_LEN ..','.. MIN_CLIPS_LEN ..','.. LEFT_PAD ..','.. RIGHT_PAD ..','.. FADE ..','.. SNAP_OFFSET ..','.. SKIP_SAMPLE ..','.. SPLIT ..','.. MODE

if language == "简体中文" then
  title = "修剪分割对象设置"
  lable = "阈值 (dB),滞后 (dB),最小静默长度 (ms),最小片段长度 (ms),前导填充 (ms),尾部填充 (ms),是否淡变 (y/n),峰值吸附偏移 (ms),采样点步进,是否切割 (y/n),模式 (del/keep/begin/end)"
elseif language == "繁体中文" then
  title = "修剪分割對象設置"
  lable = "閾值 (dB),滯後 (dB),最小靜默長度 (ms),最小片段長度 (ms),前導填充 (ms),尾部填充 (ms),是否淡變 (y/n),峰值吸附偏移 (ms),采樣點步進,是否切割 (y/n),模式 (del/keep/begin/end)"
else
  title = "Trim Split Items Settings"
  lable = "Threshold (dB),Hysteresis (dB),Min silence length (ms),Min clips length (ms),Leading pad (ms),Trailing pad (ms),Fade pad (y/n),Peak snap offset (ms),Sample step,Is it split? (y/n),Mode (del/keep/begin/end)"
end

reaper.Undo_BeginBlock()
set = getMutiInput(title, 11, lable, default)
if set == nil or not tonumber(THRESHOLD) or not tonumber(HYSTERESIS) or not tonumber(MIN_SILENCE_LEN) or not tonumber(MIN_CLIPS_LEN) or not tonumber(LEFT_PAD) or not tonumber(RIGHT_PAD) or not tostring(FADE) or not tonumber(SNAP_OFFSET) or not tonumber(SKIP_SAMPLE) or not tostring(SPLIT) or not tostring(MODE) then return end
if MODE ~= "del" or MODE ~= "keep" or MODE ~= "begin" or MODE ~= "end" then return end

saveDataList("TRIM_SPLIT_ITEMS", "Parameters", set, true)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()