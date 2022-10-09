-- @description Trim Items Edge
-- @version 1.1.7
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

function eq(a, b) return math.abs(a - b) < 0.000001 end
function log10(x) if not x then return end return math.log(x, 10) end
function todb(x) if not x then return end return 20 * log10(x) end
function topower(x) if not x then return end return 10 ^ (x / 20) end

local print2_count = 0
function print2(...)
  if print2_count == 0 then
    print(...)
  end
  print2_count = print2_count + 1
  if print2_count >= 5000 then
    print2_count = 0
  end
end

function delete_item(item)
  if item then
    local track = reaper.GetMediaItem_Track(item)
    reaper.DeleteTrackMediaItem(track, item)
  end
end

--根据ranges保留item指定区域，并删除剩余区域
--例：keep_ranges = { {1, 3}, {5, 8} } 代表将item中 1-3 与 5-8区域保留，其余地方删除
function trim_item(item, keep_ranges)
  local item_pos = reaper.GetMediaItemInfo_Value(item,"D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item,"D_LENGTH")
  -- table.print(keep_ranges)
  local left = item
  for i, range in ipairs(keep_ranges) do
    if not eq(range[1], item_pos) then
      -- print("sl", left)
      local right = reaper.SplitMediaItem(left, range[1])
      -- print("rr", right)
      delete_item(left)
      left = right
    end
    -- print("ll", left)
    right = reaper.SplitMediaItem(left, range[2])
    left = right
    -- print("left", left, "right", right)
  end

  if #keep_ranges > 0 and keep_ranges[#keep_ranges][2] < item_pos + item_len then
    delete_item(left)
  end
end

function trim_edge(item, keep_ranges)

  for i, range in ipairs(keep_ranges) do
    reaper.BR_SetItemEdges(item, range[1], range[2])
  end
end

-- 扩展保留区域
function expand_ranges(item, keep_ranges, left_pad, right_pad)
  local item_pos = reaper.GetMediaItemInfo_Value(item,"D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item,"D_LENGTH")
  -- table.print(keep_ranges)
  for i = 1, #keep_ranges do
    local left_inc = left_pad
    local right_inc = right_pad
    if (i > 1 and keep_ranges[i][1] - left_inc < keep_ranges[i - 1][2]) then
      left_inc = 0
    end
    if (i < #keep_ranges and keep_ranges[i][2] + right_inc > keep_ranges[i + 1][1]) then
      right_inc = 0
    end
    if keep_ranges[i][1] - left_inc <= item_pos + 0.000001 then
      left_inc = keep_ranges[i][1] - item_pos
    end
    if keep_ranges[i][2] + right_inc >= item_pos + item_len - 0.000001 then
      right_inc = item_pos + item_len - keep_ranges[i][2]
    end
    keep_ranges[i] = { keep_ranges[i][1] - left_inc, keep_ranges[i][2] + right_inc }
  end
  return keep_ranges
end

function get_sample_val_and_pos(take, step, threshold, hysteresis)
  local ret = false
  if take == nil then return end

  local item = reaper.GetMediaItemTake_Item(take)
  if item == nil then return end

  local source = reaper.GetMediaItemTake_Source(take)
  if source == nil then return end

  local accessor = reaper.CreateTakeAudioAccessor(take)
  if accessor == nil then return end

  local aa_start = reaper.GetAudioAccessorStartTime(accessor)
  local aa_end = reaper.GetAudioAccessorEndTime(accessor)

  local take_source_len, length_is_QN = reaper.GetMediaSourceLength(source)
  if length_is_QN then return end

  local channels = reaper.GetMediaSourceNumChannels(source)
  local samplerate = reaper.GetMediaSourceSampleRate(source)
  if samplerate == 0 then return end

  local left_min = topower(threshold)
  local right_min = topower(threshold + hysteresis)

  local lv, rv
  local l, r

  local samples_per_channel = math.ceil((aa_end - aa_start) * samplerate)
  local sample_index
  local offset
  local samples_per_block = samplerate

  if step <= 0 then
    step = 1
  elseif step > 0 then
    step = reaper.GetMediaSourceSampleRate(source) / step
  end

  -- print("aa start", aa_start)
  -- print("aa end", aa_end)
  -- print("samples_per_channel", samples_per_channel)
  -- print("samples_per_block", samples_per_block)
  -- Find left bound
  sample_index = 0
  offset = aa_start
  -- print("offset l start", offset)
  while sample_index < samples_per_channel do
    -- print("block in find l", offset)
    local buffer = reaper.new_array(samples_per_block * channels)
    local aa_ret = reaper.GetAudioAccessorSamples(accessor, samplerate, channels, offset, samples_per_block, buffer)
    if aa_ret <= 0 then
      goto next_block
    end
    -- print("samples_per_block", samples_per_block)
    for i = 0, samples_per_block - 1, step do
      if sample_index + i >= samples_per_channel then
        return
      end
      for j = 0, channels - 1 do
        local v = buffer[channels * i + j + 1]
        if v > left_min then
          lv = v
          l = sample_index + i
          goto found_l
        end
      end
    end
    ::next_block::
    sample_index = sample_index + samples_per_block
    offset = offset + samples_per_block / samplerate
    buffer.clear()
  end
  ::found_l::
  
  -- print("found l", lv, l, l / samplerate)
  -- print("sample_index", sample_index)
  -- Find right bound
  sample_index = samples_per_channel - 1
  offset = aa_end - samples_per_block / samplerate
  -- print("offset r start", offset)
  while sample_index >= 0 do
    -- print("block in find r", offset)
    local buffer = reaper.new_array(samples_per_block * channels)
    local aa_ret = reaper.GetAudioAccessorSamples(accessor, samplerate, channels, offset, samples_per_block, buffer)
    -- print("aa_ret", aa_ret)
    if aa_ret <= 0 then 
      goto next_block 
    end
    -- print("start sample index", sample_index)
    for i = samples_per_block - 1, 0, -step do
      if sample_index - (samples_per_block - 1 - i) < 0 then
        return
      end

      for j = 0, channels - 1 do
        local v = buffer[channels * i + j + 1]
        -- print(v, sample_index, i, j)
        if v > right_min and v < 1 then
          -- print("found", v, sample_index)
          -- print("buffer index", channels, i, j, channels * i + j + 1)
          rv = v
          r = sample_index - (samples_per_block - 1 - i)
          -- print(r)
          goto found_r
        end
      end
    end
    ::next_block::
    sample_index = sample_index - samples_per_block
    -- print("sample_index", sample_index)
    offset = offset - samples_per_block / samplerate
    buffer.clear()
  end
  ::found_r::
  -- print("found r", rv, r, r/ samplerate)

  reaper.DestroyAudioAccessor(accessor)
  
  if lv and rv then
    return lv and rv, todb(lv), l / samplerate, todb(rv), r / samplerate
  end
  return nil
end

function max_peak_pos(item, step, pend, pstart)
  local ret = false
  -- if reaper.TakeIsMIDI(take) then return end
  local take = reaper.GetActiveTake(item)
  local source = reaper.GetMediaItemTake_Source(take)
  local accessor = reaper.CreateTakeAudioAccessor(take)
  local samplerate = reaper.GetMediaSourceSampleRate(source)
  local channels = reaper.GetMediaSourceNumChannels(source)
  local startpos = 0

  local samples_per_block = samplerate*pend
  local samples_per_block_i = samplerate*pstart
  if samples_per_block_i == 0 then samples_per_block_i = 1 end

  local buffer = reaper.new_array(samples_per_block * channels)
  reaper.GetAudioAccessorSamples(accessor, samplerate, channels, startpos, samples_per_block, buffer)

  local v_max, max_peak, max_zero = 0

  if step <= 0 then
    step = 1
  elseif step > 0 then
    step = reaper.GetMediaSourceSampleRate(source) / step
  end

  for i = samples_per_block_i, samples_per_block, step do -- 设定采样点范围和步数
    local v = math.abs(buffer[i])
    v_max = math.max(v, v_max)
    if v_max ~= max_zero then
      max_peak = i / channels
    end
    max_zero = v_max
  end

  local snap_offset_pos = max_peak / samplerate
  reaper.DestroyAudioAccessor(accessor)

  if max_peak then
    return snap_offset_pos
  end
  return nil
end

get = getSavedDataList("Trim Items Edge", "Parameters")

if get == nil then   -- 默认预设
  threshold_l = -60  -- 阈值(dB)
  threshold_r = -6   -- 滯後(dB)
  leading_pad = 50   -- 前导填充(ms)
  trailing_pad = 100 -- 尾部填充(ms)
  fade_in = 50       -- 淡入(ms)
  fade_out = 100     -- 淡出(ms)
  length_limit = 100 -- 长度限制(ms)
  snap_offset = 0    -- 吸附偏移(ms)
  step = 0         -- 采样点读取步数

  set = getMutiInput("Trim Items Edge Settings", 9, "Threshold (dB),Hysteresis (dB),Leading pad (ms),Trailing pad (ms),Fade in (ms),Fade out (ms),Min item length (ms),Snap offset to peak (ms),Sample step (0 to disable)", threshold_l ..','.. threshold_r ..','.. leading_pad ..','.. trailing_pad ..','.. fade_in ..','.. fade_out ..','.. length_limit ..','.. snap_offset ..','.. step)
  saveDataList("Trim Items Edge", "Parameters", set, true)
  get = getSavedDataList("Trim Items Edge", "Parameters")
  return
end

-- table.print(get)

if get[1] == nil then get[1] = -60 end
if get[2] == nil then get[2] = -6 end
if get[3] == nil then get[3] = 50 end
if get[4] == nil then get[4] = 100 end
if get[5] == nil then get[5] = 50 end
if get[6] == nil then get[6] = 100 end
if get[7] == nil then get[7] = 100 end
if get[8] == nil then get[8] = 0 end
if get[9] == nil then get[9] = 0 end

threshold_l = tonumber(get[1])
threshold_r = tonumber(get[2])
leading_pad = tonumber(get[3])
trailing_pad = tonumber(get[4])
fade_in = tonumber(get[5])
fade_out = tonumber(get[6])
length_limit = tonumber(get[7])
snap_offset = tonumber(get[8])
step = tonumber(get[9])

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local count_sel_items = reaper.CountSelectedMediaItems(0)
local track_items = {}

for i = 0, count_sel_items - 1  do
  local item = reaper.GetSelectedMediaItem(0, i)
  local track = reaper.GetMediaItem_Track(item)
  if not track_items[track] then track_items[track] = {} end
  table.insert(track_items[track], item)
end

for _, items in pairs(track_items) do
  for i, item in ipairs(items) do
    take = reaper.GetActiveTake(item)
    item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local ret, peak_value_L, peak_pos_L, peak_value_R, peak_pos_R = get_sample_val_and_pos(take, step, threshold_l, threshold_r)

    if ret and item_len > length_limit / 1000 then
      local ranges = { { item_pos + peak_pos_L, item_pos + peak_pos_R } }
      ranges = expand_ranges(item, ranges, leading_pad / 1000, trailing_pad / 1000)

      --trim_item(item, ranges) -- 切割item并删除
      trim_edge(item, ranges)

      if snap_offset > 0 then
        reaper.SetMediaItemInfo_Value(item, 'D_SNAPOFFSET', max_peak_pos(item, step, ((leading_pad + snap_offset)*2) / 1000, leading_pad / 1000))
      elseif snap_offset == 0 then
        reaper.SetMediaItemInfo_Value(item, 'D_SNAPOFFSET', peak_pos_L - (leading_pad / 1000))
      end
      if fade_in >= 0 or fade_out >= 0 then
        reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", fade_in / 1000)
        reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", fade_out / 1000)
      end
    end
  end
end

reaper.Undo_EndBlock("Trim Items Edge", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()