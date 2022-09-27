-- @description Trim Items Edge Settings
-- @version 1.0.5
-- @author zaibuyidao
-- @changelog Adjusting the pre-programmed parameters
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

function saveData(key1,key2,data)
  reaper.SetExtState(key1, key2, data, false)
end

function getSavedData(key1, key2)
  return table.unserialize(reaper.GetExtState(key1, key2))
end

function getMutiInput(title,num,lables,defaults)
  title=title or "Title"
  lables=lables or "Lable:"
  local userOK, getValue = reaper.GetUserInputs(title, num, lables, defaults)
  if userOK then return string.split(getValue,",") end
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
        retstr = retstr .. signal .. to_string_ex(remove_name_suffix(value))
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

local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))

function check_locale(locale)
  if locale == 936 then
    return true
  elseif locale == 950 then
    return true
  end
  return false
end

get = getSavedData("Trim Items Edge", "Parameters")
-- print(table_to_str(get))

if get == nil then   -- 默认预设
  threshold_l = -96  -- 左阈值(dB)
  threshold_r = -96  -- 右阈值(dB)
  leading_pad =  50  -- 前导填充(ms)
  trailing_pad = 100 -- 尾部填充(ms)
  fade_in = 3        -- 淡入(ms)
  fade_out = 3       -- 淡出(ms)
  length_limit = 100 -- 长度限制(ms)
else
  threshold_l = get[1]
  threshold_r = get[2]
  leading_pad = get[3]
  trailing_pad = get[4]
  fade_in = get[5]
  fade_out = get[6]
  length_limit = get[7]
end

os = reaper.GetOS()
if os ~= "Win32" and os ~= "Win64" then
  -- MAC 默認英文
  title = "Trim Items Edge Settings"
  lable = "Left Threshold (dB),Right Threshold (dB),Leading Pad (ms),Trailing Pad (ms),Fade In (ms),Fade Out (ms),Min Item Length (ms)"
else
  if check_locale(locale) == false then
    -- WIN 英文
    title = "Trim Items Edge Settings"
    lable = "Left Threshold (dB),Right Threshold (dB),Leading Pad (ms),Trailing Pad (ms),Fade In (ms),Fade Out (ms),Min Item Length (ms)"
  else
    -- WIN 中文
    title = "Trim Items Edge 設置"
    lable = "左閾值 (dB),右閾值 (dB),前導填充 (ms),尾部填充 (ms),淡入 (ms),淡出 (ms),最小對象長度 (ms)"
  end
end

default = threshold_l ..','.. threshold_r ..','.. leading_pad ..','.. trailing_pad ..','.. fade_in ..','.. fade_out ..','.. length_limit

reaper.Undo_BeginBlock()
set = getMutiInput(title, 7, lable, default)
if set == nil then return end

reaper.SetExtState("Trim Items Edge", "Parameters", table.serialize(set), false)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()