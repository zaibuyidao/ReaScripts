-- @description Trim Items Edge Settings
-- @version 1.1.4
-- @author zaibuyidao
-- @changelog Fix snap offset
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires SWS Extensions

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

local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))

function check_locale(locale)
  if locale == 936 then
    return true
  elseif locale == 950 then
    return true
  end
  return false
end

get = getSavedDataList("Trim Items Edge", "Parameters")

if get == nil then   -- 默认预设
  threshold_l = -60  -- 阈值(dB)
  threshold_r = -6   -- 滯後(dB)
  leading_pad =  50  -- 前导填充(ms)
  trailing_pad = 100 -- 尾部填充(ms)
  fade_in = 50       -- 淡入(ms)
  fade_out = 100     -- 淡出(ms)
  length_limit = 100 -- 长度限制(ms)
  snap_offset = 0    -- 吸附偏移(ms)
  step = 0         -- 采样点读取步数
else
  if get[1] == nil then get[1] = -60 end
  if get[2] == nil then get[2] = -6 end
  if get[3] == nil then get[3] = 50 end
  if get[4] == nil then get[4] = 100 end
  if get[5] == nil then get[5] = 50 end
  if get[6] == nil then get[6] = 100 end
  if get[7] == nil then get[7] = 100 end
  if get[8] == nil then get[8] = 0 end
  if get[9] == nil then get[9] = 0 end
  threshold_l = get[1]
  threshold_r = get[2]
  leading_pad = get[3]
  trailing_pad = get[4]
  fade_in = get[5]
  fade_out = get[6]
  length_limit = get[7]
  snap_offset = get[8]
  step = get[9]
end

default = threshold_l ..','.. threshold_r ..','.. leading_pad ..','.. trailing_pad ..','.. fade_in ..','.. fade_out ..','.. length_limit ..','.. snap_offset ..','.. step

os = reaper.GetOS()
if os ~= "Win32" and os ~= "Win64" then
  title = "Trim Items Edge Settings"
  lable = "Threshold (dB),Hysteresis (dB),Leading pad (ms),Trailing pad (ms),Fade in (ms),Fade out (ms),Min item length (ms),Snap offset to peak (ms),Sample step (0 to disable)"
else
  if check_locale(locale) == false then
    title = "Trim Items Edge Settings"
    lable = "Threshold (dB),Hysteresis (dB),Leading pad (ms),Trailing pad (ms),Fade in (ms),Fade out (ms),Min item length (ms),Snap offset to peak (ms),Sample step (0 to disable)"
  else
    title = "Trim Items Edge 設置"
    lable = "閾值 (dB),滯後 (dB),前導填充 (ms),尾部填充 (ms),淡入 (ms),淡出 (ms),最小對象長度 (ms),吸附偏移到峰值 (ms),采樣點步數 (0為禁用)"
  end
end

reaper.Undo_BeginBlock()
set = getMutiInput(title, 9, lable, default)
if set == nil then return end
for i = 1, #set do
  if not tonumber(set[i]) then return end
end

saveDataList("Trim Items Edge", "Parameters", set, true)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()