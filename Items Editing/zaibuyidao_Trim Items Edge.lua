-- @description Trim Items Edge
-- @version 1.0.3
-- @author zaibuyidao
-- @changelog Optimize speed
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

function get_sample_val_and_pos(take, val_is_dB)
  local ret = false
  if take == nil then
    return
  end

  local item = reaper.GetMediaItemTake_Item(take)

  if item == nil then
    return
  end

  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

  local take_pcm_source = reaper.GetMediaItemTake_Source(take)
  if take_pcm_source == nil then
    return
  end

  local aa = reaper.CreateTakeAudioAccessor(take)
  if aa == nil then
    return
  end

  -- Get the start time of the audio that can be returned from this accessor
  local aa_start = reaper.GetAudioAccessorStartTime(aa)
  -- Get the end time of the audio that can be returned from this accessor
  local aa_end = reaper.GetAudioAccessorEndTime(aa)

  -- Get the length of the source media. If the media source is beat-based,
  -- the length will be in quarter notes, otherwise it will be in seconds.
  local take_source_len, length_is_QN = reaper.GetMediaSourceLength(take_pcm_source)

  if length_is_QN then
    return
  end

  -- Get the number of channels in the source media.
  local take_source_num_channels = reaper.GetMediaSourceNumChannels(take_pcm_source)

  -- Get the sample rate. MIDI source media will return zero.
  local take_source_sample_rate = reaper.GetMediaSourceSampleRate(take_pcm_source)
  if take_source_sample_rate == 0 then
    return
  end

  local log10 = function(x) if not x then return end return math.log(x, 10) end
  local todb = function (x) if not x then return end return 20 * log10(x) end
  local lv, rv
  local l, r

  -- How many samples are taken from audio accessor and put in the buffer
  local samples_per_channel = math.ceil((aa_end - aa_start) * take_source_sample_rate)

  local sample_index
  local offset
  local samples_per_block = take_source_sample_rate

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
    -- Samples are collected to this buffer
    local buffer = reaper.new_array(samples_per_block * take_source_num_channels)
    local aa_ret = reaper.GetAudioAccessorSamples(
      aa,                       -- AudioAccessor accessor
      take_source_sample_rate,  -- integer samplerate
      take_source_num_channels, -- integer numchannels
      offset,                   -- number starttime_sec
      samples_per_block,        -- integer numsamplesperchannel
      buffer                    -- reaper.array samplebuffer
    )
    if aa_ret <= 0 then 
      sample_index = sample_index + samples_per_block 
      goto next_block 
    end
    -- print("samples_per_block", samples_per_block)
    for i=0, samples_per_block - 1 do
      -- for each channel
      for j=0, take_source_num_channels - 1 do
        local v = math.abs(buffer[take_source_num_channels * i + j + 1])
        if todb(v) > threshold_l then
          lv = v
          l = sample_index
          goto found_l
        end
      end
      sample_index = sample_index + 1
      if sample_index >= samples_per_channel then
        return
      end
    end
    ::next_block::
    offset = offset + samples_per_block / take_source_sample_rate -- new offset in take source (seconds)
  end
  ::found_l::
  
  -- print("found l", lv, l, l / take_source_sample_rate)
  -- print("sample_index", sample_index)
  -- Find right bound
  sample_index = samples_per_channel - 1
  offset = aa_end - samples_per_block / take_source_sample_rate
  -- print("offset r start", offset)
  while sample_index >= 0 do
    -- print("block in find r", offset)
    -- Samples are collected to this buffer
    local buffer = reaper.new_array(samples_per_block * take_source_num_channels)
    local aa_ret = reaper.GetAudioAccessorSamples(
      aa,                       -- AudioAccessor accessor
      take_source_sample_rate,  -- integer samplerate
      take_source_num_channels, -- integer numchannels
      offset,                   -- number starttime_sec
      samples_per_block,        -- integer numsamplesperchannel
      buffer                    -- reaper.array samplebuffer
    )
    -- print("aa_ret", aa_ret)
    if aa_ret <= 0 then 
      sample_index = sample_index - samples_per_block 
      goto next_block 
    end
    for i=samples_per_block - 1, 0, -1 do
      -- for each channel
      for j=0, take_source_num_channels - 1 do
        local v = math.abs(buffer[take_source_num_channels * i + j + 1])
        -- print2(v, sample_index, i)
        if todb(v) > threshold_r then
          -- print(v, sample_index, i)
          rv = v
          r = sample_index
          goto found_r
        end
      end
      sample_index = sample_index - 1
      if sample_index < 0 then
        return
      end
    end
    ::next_block::
    offset = offset - samples_per_block / take_source_sample_rate -- new offset in take source (seconds)
  end
  ::found_r::

  -- print("found r", rv, r, r/ take_source_sample_rate)

  reaper.DestroyAudioAccessor(aa)
  
  -- local cursor_pos = item_pos + sample_index/take_source_sample_rate
  -- reaper.SetEditCurPos(cursor_pos, true, false)

  if lv and rv then
    return lv and rv, todb(lv), l / take_source_sample_rate, todb(rv), r / take_source_sample_rate
  end
  return nil
end

get = getSavedData("Trim Items Edge", "Parameters")

if get == nil then   -- 默认预设
  threshold_l = -96  -- 左阈值(dB)
  threshold_r = -96  -- 右阈值(dB)
  leading_pad = 3    -- 前导填充(ms)
  trailing_pad = 3   -- 尾部填充(ms)
  fade_in = 0        -- 淡入(ms)
  fade_out = 0       -- 淡出(ms)
  length_limit = 100 -- 长度限制(ms)

  set = getMutiInput("Trim Items Edge Settings", 7, "Left Threshold (dB),Right Threshold (dB),Leading Pad (ms),Trailing Pad (ms),Fade In (ms),Fade Out (ms),Item Length Limit (ms)", threshold_l ..','.. threshold_r ..','.. leading_pad ..','.. trailing_pad ..','.. fade_in ..','.. fade_out ..','.. length_limit)
  if set == nil then return end
  reaper.SetExtState("Trim Items Edge", "Parameters", table.serialize(set), false)
  get = getSavedData("Trim Items Edge", "Parameters")
  return
end

-- table.print(get)

threshold_l = tonumber(get[1])
threshold_r = tonumber(get[2])
leading_pad = tonumber(get[3])
trailing_pad = tonumber(get[4])
fade_in = tonumber(get[5])
fade_out = tonumber(get[6])
length_limit = tonumber(get[7])

local count_sel_items = reaper.CountSelectedMediaItems(0)
local track_items = {}

for i = 0, count_sel_items - 1  do
  local item = reaper.GetSelectedMediaItem(0, i)
  local track = reaper.GetMediaItem_Track(item)
  if not track_items[track] then track_items[track] = {} end
  table.insert(track_items[track], item)
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
for _, items in pairs(track_items) do
  for i, item in ipairs(items) do
    take = reaper.GetActiveTake(item)
    item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local ret, peak_value_L, peak_pos_L, peak_value_R, peak_pos_R = get_sample_val_and_pos(take, true)

    if ret and item_len > length_limit/1000 then
      reaper.SetMediaItemInfo_Value(item, 'D_SNAPOFFSET', peak_pos_L)
      reaper.BR_SetItemEdges(item, item_pos + peak_pos_L - leading_pad/1000, (item_pos + peak_pos_R + 0.000001) + trailing_pad/1000)
      reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", fade_in/1000)
      reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", fade_out/1000)
    end
  end
end
reaper.Undo_EndBlock("Trim Items Edge", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()