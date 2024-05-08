-- @description Trim Item Edges
-- @version 1.0.1
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
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local loop_source = reaper.GetMediaItemInfo_Value(item, "B_LOOPSRC")

  if loop_source == 0 then
    -- 获取item的起始位置和长度
    local item_start_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local source = reaper.GetMediaItemTake_Source(take)
    local source_length, is_section = reaper.GetMediaSourceLength(source)
    -- 计算绝对左边界和右边界
    local source_absolute_start = item_start - item_start_offset
    local source_absolute_end = source_absolute_start + source_length

    -- 计算循环偏移值
    local left_offset = (item_start - source_absolute_start) % source_length
    local right_offset = (item_start + item_length - source_absolute_end) % source_length

    if item_start + item_length > source_absolute_end then
      item_length = source_absolute_end
    end
  end

  -- print(item_start, item_start + item_length)
  -- table.print(keep_ranges)
  local left = item
  for i, range in ipairs(keep_ranges) do
    if not eq(range[1], item_start) then
      -- print("sl", left)
      local right = reaper.SplitMediaItem(left, range[1])
      -- print("rr", right)
      delete_item(left)
      left = right
    end
    -- print("ll", left)
    right = reaper.SplitMediaItem(left, range[2])

    reaper.SetMediaItemInfo_Value(left, "D_FADEINLEN", range.fade[1])
    reaper.SetMediaItemInfo_Value(left, "D_FADEOUTLEN", range.fade[2])

    left = right
  end

  if #keep_ranges > 0 and keep_ranges[#keep_ranges][2] < item_start + item_length then
    delete_item(left)
  end
end

function trim_edge(item, keep_ranges)
  for i, range in ipairs(keep_ranges) do
    reaper.BR_SetItemEdges(item, range[1], range[2])
    reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", range.fade[1])
    reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", range.fade[2])
  end
end

-- 扩展保留区域
function expand_ranges(item, keep_ranges, left_pad, right_pad, fade_in, fade_out)
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local loop_source = reaper.GetMediaItemInfo_Value(item, "B_LOOPSRC")
  
  if loop_source == 0 then
    -- 获取item的起始位置和长度
    local item_start_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local source = reaper.GetMediaItemTake_Source(take)
    local source_length, is_section = reaper.GetMediaSourceLength(source)
    -- 计算绝对左边界和右边界
    local source_absolute_start = item_start - item_start_offset
    local source_absolute_end = source_absolute_start + source_length

    -- 计算循环偏移值
    local left_offset = (item_start - source_absolute_start) % source_length
    local right_offset = (item_start + item_length - source_absolute_end) % source_length
    
    if item_start + item_length > source_absolute_end then
      item_length = source_absolute_end
    end
  end

  -- table.print(keep_ranges)
  for i = 1, #keep_ranges do
    local left_inc = left_pad
    local right_inc = right_pad
    local actual_fade_in = fade_in
    local actual_fade_out = fade_out
    if (i > 1 and keep_ranges[i][1] - left_inc < keep_ranges[i - 1][2]) then
      left_inc = 0
      actual_fade_in = 0
    end
    if (i < #keep_ranges and keep_ranges[i][2] + right_inc > keep_ranges[i + 1][1]) then
      right_inc = 0
      actual_fade_out = 0
    end
    if keep_ranges[i][1] - left_inc <= item_start + 0.000001 then
      left_inc = keep_ranges[i][1] - item_start
      actual_fade_in = 0
    end
    if keep_ranges[i][2] + right_inc >= item_start + item_length - 0.000001 then
      right_inc = item_start + item_length - keep_ranges[i][2]
      actual_fade_out = 0
    end
    keep_ranges[i] = { keep_ranges[i][1] - left_inc, keep_ranges[i][2] + right_inc, fade = { actual_fade_in, actual_fade_out } }
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
  local aa_end = reaper.GetAudioAccessorEndTime(accessor) -- 测试数值同 item_length

  -- 获取item的起始位置和长度
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local loop_source = reaper.GetMediaItemInfo_Value(item, "B_LOOPSRC")
  -- 如果loopsource为0，调整aa_end为源item的结束位置
  if loop_source == 0 then
    local item_start_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local source = reaper.GetMediaItemTake_Source(take)
    local source_length, is_section = reaper.GetMediaSourceLength(source)
    -- 计算绝对左边界和右边界
    local source_absolute_start = item_start - item_start_offset
    local source_absolute_end = source_absolute_start + source_length

    -- 计算循环偏移值
    local left_offset = (item_start - source_absolute_start) % source_length
    local right_offset = (item_start + item_length - source_absolute_end) % source_length -- 或 (item_start + item_length - source_absolute_end) % source_length
    
    -- 计算新的aa_end
    if item_start + item_length > source_absolute_end then
      aa_end = source_absolute_end
    end
  end

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
    -- step = reaper.GetMediaSourceSampleRate(source) / step -- 每秒处理几个样本
    step = samplerate / (samplerate / step) -- 跳过几个样本
  end

  step = math.floor(0.5 + step)

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
        local v = math.abs(buffer[channels * i + j + 1])
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
        local v = math.abs(buffer[channels * i + j + 1])
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

  local samples_per_block = samplerate*(pend*channels)  -- local samples_per_block = math.floor(0.5+samplerate*(pend*channels))
  local samples_per_block_i = samplerate*(pstart*channels)
  if samples_per_block_i == 0 then samples_per_block_i = 1 end

  local buffer = reaper.new_array(samples_per_block*channels)
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

function default_if_invalid(input, default, convert)
  return (input == nil or not convert(input)) and default or convert(input)
end

function checkTrimSetting()
  local trimSetting = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Items Editing/zaibuyidao_Trim Item Edges Settings.lua'

  if reaper.file_exists(trimSetting) then
    dofile(trimSetting)
  else
    reaper.MB(trimSetting:gsub('%\\', '/')..' not found. Please ensure the script is correctly placed.', '', 0)
    if reaper.APIExists('ReaPack_BrowsePackages') then
      reaper.ReaPack_BrowsePackages('zaibuyidao Trim Item Edges Settings')
    else
      reaper.MB('ReaPack extension not found', '', 0)
    end
  end
end

local get = getSavedDataList("TRIM_ITEM_EDGES_SETTINGS", "Parameters")
if get == nil then
  checkTrimSetting()
  reaper.defer(function() end) -- 终止执行
  get = getSavedDataList("TRIM_ITEM_EDGES_SETTINGS", "Parameters")
end
--print(get)

threshold_l = default_if_invalid(get[1], -60, tonumber)
threshold_r = default_if_invalid(get[2], -6, tonumber)
length_limit = default_if_invalid(get[3], 100, tonumber)
leading_pad = default_if_invalid(get[4], 0, tonumber)
trailing_pad = default_if_invalid(get[5], 0, tonumber)
fade = default_if_invalid(get[6], "n", tostring)
snap_offset = default_if_invalid(get[7], 0, tonumber)
step = default_if_invalid(get[8], 0, tonumber)

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

if fade == "n" then
  fade_in = 0
  fade_out = 0
else
  fade_in = leading_pad
  fade_out = trailing_pad
end

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
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local loop_source = reaper.GetMediaItemInfo_Value(item, "B_LOOPSRC")

    if loop_source == 0 then
      -- 获取item的起始位置和长度
      local item_start_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
      local source = reaper.GetMediaItemTake_Source(take)
      local source_length, is_section = reaper.GetMediaSourceLength(source)
      -- 计算绝对左边界和右边界
      local source_absolute_start = item_start - item_start_offset
      local source_absolute_end = source_absolute_start + source_length
  
      -- 计算循环偏移值
      local left_offset = (item_start - source_absolute_start) % source_length
      local right_offset = (item_start + item_length - source_absolute_end) % source_length
      
      if item_start + item_length > source_absolute_end then
        item_length = source_absolute_end
        -- 对于超出左右边界的item直接将其复位
        reaper.BR_SetItemEdges(item, item_start, item_length)
        -- reaper.BR_SetItemEdges(item, item_start + fade_in / 1000, item_length + fade_out / 1000)
      end
    end

    local ret, peak_value_L, peak_pos_L, peak_value_R, peak_pos_R = get_sample_val_and_pos(take, step, threshold_l, threshold_r)

    if ret and item_length > length_limit / 1000 then
      local ranges = { { item_start + peak_pos_L, item_start + peak_pos_R } }
      ranges = expand_ranges(item, ranges, leading_pad / 1000, trailing_pad / 1000, fade_in / 1000, fade_out / 1000)

      --trim_item(item, ranges) -- 切割item并删除
      trim_edge(item, ranges)

      if snap_offset > 0 then
        reaper.SetMediaItemInfo_Value(item, 'D_SNAPOFFSET', max_peak_pos(item, step, (leading_pad + snap_offset) / 1000, leading_pad / 1000))
      elseif snap_offset == 0 then
        reaper.SetMediaItemInfo_Value(item, 'D_SNAPOFFSET', leading_pad / 1000)
      end
    end
  end
end

if language == "简体中文" then
  script_title = "修剪对象边缘"
elseif language == "繁體中文" then
  script_title = "修剪對象邊緣"
else
  script_title = "Trim Item Edges"
end

reaper.Undo_EndBlock(script_title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()