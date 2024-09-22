-- @description Trim Split Items
-- @version 2.0.5
-- @author zaibuyidao
-- @changelog
--   # Optimize sampling point calculation and improve floating-point processing accuracy.
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

function get_sample_pos_value(take, skip_sample, item)
  if not take or reaper.TakeIsMIDI(take) then
    return false, false, false
  end

  -- 获取item的起始位置和长度
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

  local playrate_ori = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  local item_len_ori = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", item_len_ori * playrate_ori)
  reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", 1)

  local accessor = reaper.CreateTakeAudioAccessor(take)
  local source = reaper.GetMediaItemTake_Source(take)
  local samplerate = reaper.GetMediaSourceSampleRate(source)

  if skip_sample <= 0 or not tonumber(skip_sample) then
    skip_sample = 0
  elseif skip_sample > 0 then
    skip_sample = samplerate / (samplerate / skip_sample) -- 跳过几个样本
  end

  skip_sample = math.floor(0.5 + skip_sample)

  local channels = reaper.GetMediaSourceNumChannels(source)
  local item_len_idx = math.ceil(item_length)

  local sample_min = {}
  local sample_max = {}
  local time_sample = {}
  local breakX

  for i1 = 1, item_len_idx do
    local buffer = reaper.new_array(samplerate * channels) -- 1秒
    local accessor_samples = reaper.GetAudioAccessorSamples(accessor, samplerate , channels, i1-1, samplerate, buffer)
    local continue_count = (i1-1) * samplerate

    for i2 = 1, samplerate * channels, channels * (skip_sample + 1) do
      local sample_point_num = (i2-1) / channels + continue_count

      -- 所有通道的最小/最大采样
      local sample_min_chan = 9^99
      local sample_max_chan = 0
      for i3 = 1, channels do
        local sample_buf = math.abs(buffer[i2 + (i3-1)])
        sample_min_chan = math.min(sample_buf, sample_min_chan)
        sample_max_chan = math.max(sample_buf, sample_max_chan)
      end

      sample_min[#sample_min+1] = sample_min_chan
      sample_max[#sample_max+1] = sample_max_chan

      time_sample[#time_sample + 1] = sample_point_num / samplerate / playrate_ori + item_start
      if time_sample[#time_sample] > item_len_ori + item_start then breakX = 1 break end
    end
    buffer.clear()
    if breakX == 1 then break end
  end

  reaper.DestroyAudioAccessor(accessor)

  -- 恢复播放速率
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", item_length / playrate_ori)
  reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", playrate_ori)

  time_sample[1] = item_start
  time_sample[#time_sample] = item_start + item_len_ori

  return sample_min, sample_max, time_sample
end

function delete_item(item)
  if item then
    local track = reaper.GetMediaItem_Track(item)
    reaper.DeleteTrackMediaItem(track, item)
  end
end

function eq(a, b) return math.abs(a - b) < 0.000001 end

-- 根据ranges保留item指定区域，并删除剩余区域。例：keep_ranges = { {1, 3}, {5, 8} } 代表将item中 1-3 与 5-8区域保留，其余地方删除
function trim_item(item, keep_ranges, min_len, snap_offset, left_pad)
  local take = reaper.GetActiveTake(item)
  if not take then
    reaper.ShowConsoleMsg("No active take found for the item.\n")
    return
  end

  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = item_start + item_length
  local left = item

  for i, range in ipairs(keep_ranges) do
    if not eq(range[1], item_start) then
      local right = reaper.SplitMediaItem(left, range[1])
      if not right then
        reaper.ShowConsoleMsg(string.format("Failed to split at position %.6f\n", range[1]))
        goto continue_trim_item
      end
      delete_item(left)
      left = right
    end

    -- 修改范围的结束位置，确保不小于最小长度
    if range[2] - range[1] < min_len then
      range[2] = math.min(range[1] + min_len, item_end)
    end

    -- 确保范围的结束位置不超过 Item 的结束位置
    if range[2] > item_end then
      range[2] = item_end
    end

    -- 使用更精确的条件判断，仅当 range[2] 明显小于 item_end 时拆分
    if range[2] < item_end - 0.000001 then
      local right = reaper.SplitMediaItem(left, range[2])
      if not right then
        reaper.ShowConsoleMsg(string.format("Failed to split at position %.6f\n", range[2]))
        goto continue_trim_item
      end

      -- 设置淡入淡出长度，确保 range.fade 存在
      if range.fade then
        reaper.SetMediaItemInfo_Value(left, "D_FADEINLEN", range.fade[1])
        reaper.SetMediaItemInfo_Value(left, "D_FADEOUTLEN", range.fade[2])
      else
        reaper.SetMediaItemInfo_Value(left, "D_FADEINLEN", 0)
        reaper.SetMediaItemInfo_Value(left, "D_FADEOUTLEN", 0)
      end

      -- 设置 Snap Offset
      if snap_offset > 0 and SKIP_SAMPLE == 0 then
        local r = max_peak_pos(left, SKIP_SAMPLE, (left_pad + snap_offset) / 1000, left_pad / 1000)
        if r then
          reaper.SetMediaItemInfo_Value(left, 'D_SNAPOFFSET', r)
        end
      -- elseif snap_offset == 0 then
      --   reaper.SetMediaItemInfo_Value(left, 'D_SNAPOFFSET', left_pad / 1000)
      end

      left = right
    else
      -- 当范围结束于 Item 末尾时，只设置淡入淡出
      -- if range.fade then
      --   reaper.SetMediaItemInfo_Value(left, "D_FADEINLEN", range.fade[1])
      --   reaper.SetMediaItemInfo_Value(left, "D_FADEOUTLEN", range.fade[2])
      -- else
      --   reaper.SetMediaItemInfo_Value(left, "D_FADEINLEN", 0)
      --   reaper.SetMediaItemInfo_Value(left, "D_FADEOUTLEN", 0)
      -- end
    end

    ::continue_trim_item::
  end

  -- 确保所有范围都被处理
  if #keep_ranges > 0 and keep_ranges[#keep_ranges][2] < item_start + item_length then
    delete_item(left)
  end
end

function trim_item_keep_silence(item, keep_ranges, min_len, snap_offset, left_pad)
  local take = reaper.GetActiveTake(item)
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = item_start + item_length
  local left = item

  for i, range in ipairs(keep_ranges) do
    if not eq(range[1], item_start) then
      local right = reaper.SplitMediaItem(left, range[1])
      if not right then
        reaper.ShowConsoleMsg(string.format("Failed to split at position %.6f\n", range[1]))
        goto continue_trim_item
      end
      left = right
    end

    if range[2] - range[1] < min_len then
      range[2] = math.min(range[1] + min_len, item_end)
    end

    if range[2] > item_end then
      range[2] = item_end
    end

    -- 使用更精确的条件判断，仅当 range[2] 明显小于 item_end 时拆分
    if range[2] < item_end - 0.000001 then
      local right = reaper.SplitMediaItem(left, range[2])
      if not right then
        reaper.ShowConsoleMsg(string.format("Failed to split at position %.6f\n", range[2]))
        goto continue_trim_item
      end

      -- 设置淡入淡出长度，确保 range.fade 存在
      if range.fade then
        reaper.SetMediaItemInfo_Value(left, "D_FADEINLEN", range.fade[1])
        reaper.SetMediaItemInfo_Value(left, "D_FADEOUTLEN", range.fade[2])
      else
        reaper.SetMediaItemInfo_Value(left, "D_FADEINLEN", 0)
        reaper.SetMediaItemInfo_Value(left, "D_FADEOUTLEN", 0)
      end
  
      if snap_offset > 0 and SKIP_SAMPLE == 0 then
        local r = max_peak_pos(left, SKIP_SAMPLE, (left_pad + snap_offset) / 1000, left_pad / 1000)
        if r then
          reaper.SetMediaItemInfo_Value(left, 'D_SNAPOFFSET', r)
        end
      -- elseif snap_offset == 0 then
      --   reaper.SetMediaItemInfo_Value(left, 'D_SNAPOFFSET', left_pad / 1000)
      end

      left = right
    else
      -- 当范围结束于 Item 末尾时，只设置淡入淡出
      -- if range.fade then
      --   reaper.SetMediaItemInfo_Value(left, "D_FADEINLEN", range.fade[1])
      --   reaper.SetMediaItemInfo_Value(left, "D_FADEOUTLEN", range.fade[2])
      -- else
      --   reaper.SetMediaItemInfo_Value(left, "D_FADEINLEN", 0)
      --   reaper.SetMediaItemInfo_Value(left, "D_FADEOUTLEN", 0)
      -- end
    end

    ::continue_trim_item::
  end
end

function trim_item_before_nonsilence(item, keep_ranges, snap_offset, left_pad)
  local take = reaper.GetActiveTake(item)
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = item_start + item_length
  local left = item

  for i, range in ipairs(keep_ranges) do
    if not eq(range[1], item_start) then
      local right = reaper.SplitMediaItem(left, range[1])
      if not right then
        reaper.ShowConsoleMsg(string.format("Failed to split at position %.6f\n", range[1]))
        goto continue_trim_item
      end
      reaper.SetMediaItemInfo_Value(left, "D_FADEOUTLEN", FADE_OUT/1000)
      left = right
      reaper.SetMediaItemInfo_Value(left, "D_FADEINLEN", FADE_IN/1000)
    end

    if snap_offset > 0 and SKIP_SAMPLE == 0 then
      local r = max_peak_pos(left, SKIP_SAMPLE, (left_pad + snap_offset) / 1000, left_pad / 1000)
      if r then
        reaper.SetMediaItemInfo_Value(left, 'D_SNAPOFFSET', r)
      end
    -- elseif snap_offset == 0 then
    --   reaper.SetMediaItemInfo_Value(left, 'D_SNAPOFFSET', left_pad / 1000)
    end

    ::continue_trim_item::
  end
end

function trim_item_before_silence(item, keep_ranges, min_len)
  local take = reaper.GetActiveTake(item)
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = item_start + item_length
  local left = item

  for i, range in ipairs(keep_ranges) do
    if range[2] - range[1] < min_len then
      range[2] = math.min(range[1] + min_len, item_end)
    end

    if range[2] > item_end then
      range[2] = item_end
    end

    if range[2] < item_end - 0.000001 then
      local right = reaper.SplitMediaItem(left, range[2])
      if not right then
        reaper.ShowConsoleMsg(string.format("Failed to split at position %.6f\n", range[1]))
        goto continue_trim_item
      end

      if SNAP_OFFSET > 0 then
        local r = max_peak_pos(left, 0, (LEFT_PAD + SNAP_OFFSET) / 1000, LEFT_PAD / 1000)
        if r then
          reaper.SetMediaItemInfo_Value(left, 'D_SNAPOFFSET', r)
        end
      elseif SNAP_OFFSET == 0 then
        reaper.SetMediaItemInfo_Value(left, 'D_SNAPOFFSET', LEFT_PAD / 1000)
      end

      reaper.SetMediaItemInfo_Value(left, "D_FADEOUTLEN", FADE_OUT/1000)
      left = right
      reaper.SetMediaItemInfo_Value(left, "D_FADEINLEN", FADE_IN/1000)
    else
      -- 当范围结束于 Item 末尾时，只设置淡入淡出
      -- if range.fade then
      --   reaper.SetMediaItemInfo_Value(left, "D_FADEINLEN", range.fade[1])
      --   reaper.SetMediaItemInfo_Value(left, "D_FADEOUTLEN", range.fade[2])
      -- else
      --   reaper.SetMediaItemInfo_Value(left, "D_FADEINLEN", 0)
      --   reaper.SetMediaItemInfo_Value(left, "D_FADEOUTLEN", 0)
      -- end
    end

    ::continue_trim_item::
  end
end

-- 合并间隔较小的保留区域，如果item长度小于MIN_CLIPS_LEN，则全部区域保留
function merge_ranges(item, keep_ranges, min_len)
  local take = reaper.GetActiveTake(item)
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = item_start + item_length  -- 确保 item_end 被正确计算
  local loop_source = reaper.GetMediaItemInfo_Value(item, "B_LOOPSRC")

  if loop_source == 0 then
    local item_start_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local source = reaper.GetMediaItemTake_Source(take)
    local source_length, is_section = reaper.GetMediaSourceLength(source)
    local source_absolute_start = item_start - item_start_offset
    local source_absolute_end = source_absolute_start + source_length

    if item_start + item_length > source_absolute_end then
        item_length = source_absolute_end - item_start
        item_end = item_start + item_length
    end
  end

  if item_length < MIN_CLIPS_LEN / 1000 then -- 对象长度限制
    return { { item_start, item_end } }
  end

  local r = {}
  for i = 1, #keep_ranges do
    if i > 1 and keep_ranges[i][1] - r[#r][2] < min_len then
      r[#r][2] = keep_ranges[i][2]
    else
      table.insert(r, keep_ranges[i])
    end
  end

  -- 删除较小的保留区域，并确保 range[1] 和 range[2] 存在
  local r2 = {}
  for i, range in ipairs(r) do
    if type(range[1]) == "number" and type(range[2]) == "number" then
      if math.abs(range[1] - range[2]) > 0.000001 then
        table.insert(r2, range)
      end
    else
      reaper.ShowConsoleMsg(string.format("无效的范围在索引 %d: range[1]=%s, range[2]=%s\n", 
        i, tostring(range[1]), tostring(range[2])))
    end
  end

  return r2
end

-- 扩展保留区域
function expand_ranges(item, keep_ranges, left_pad, right_pad, fade_in, fade_out)
  local item_pos = reaper.GetMediaItemInfo_Value(item,"D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item,"D_LENGTH")

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
    if keep_ranges[i][1] - left_inc <= item_pos + 0.000001 then
      left_inc = keep_ranges[i][1] - item_pos
      actual_fade_in = 0
    end
    if keep_ranges[i][2] + right_inc >= item_pos + item_len - 0.000001 then
      right_inc = item_pos + item_len - keep_ranges[i][2]
      actual_fade_out = 0
    end

    keep_ranges[i] = {
      math.max(keep_ranges[i][1] - left_inc, item_pos),
      math.min(keep_ranges[i][2] + right_inc, item_pos + item_len),
      fade = { actual_fade_in, actual_fade_out }
    }

  end
  return keep_ranges
end

function max_peak_pos(item, skip, right, left)
  -- 获取当前Item的Take
  local take = reaper.GetActiveTake(item)
  if not take then 
    return nil 
  end
  
  -- 获取音频源和Item的起始位置
  local source = reaper.GetMediaItemTake_Source(take)
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

  -- 计算跳过的采样数
  if skip <= 0 then
    skip = 0
  elseif skip > 0 then
    skip = reaper.GetMediaSourceSampleRate(source) / skip -- 每秒处理几个样本
  end

  -- 获取采样值
  local sample_min, sample_max, time_sample = get_sample_pos_value(take, skip, item)
  if not time_sample then 
    return nil 
  end

  -- 定义检查范围的左边界和右边界（相对于Item的起始时间）
  local right_bound = item_start + right
  local left_bound = item_start + left
  local max_value
  local max_pos

  -- 用于记录唯一的sample_max值
  local unique_max = {}

  -- 遍历所有采样点
  for i = 1, #time_sample do
    if time_sample[i] >= left_bound then
      if time_sample[i] > right_bound then
        break -- 超出右边界，停止检查
      end
      -- 更新最高峰值和位置
      if max_value == nil or sample_max[i] > max_value then
        max_pos = time_sample[i]
        max_value = sample_max[i]
      end
      -- 记录当前采样点的最大值
      unique_max[sample_max[i]] = true
    end
  end

  -- 计算唯一的sample_max值的数量
  local unique_count = 0
  for _ in pairs(unique_max) do
    unique_count = unique_count + 1
  end

  if unique_count == 1 then
    -- 如果所有sample_max值都相同（无声），则将max_pos设置为指定的最大范围值
    max_pos = right
  else
    -- 如果存在不同的sample_max值，则按照原有逻辑返回最高峰值的位置
    if max_pos == nil then
      max_pos = 0
    else
      max_pos = max_pos - item_start
    end
  end

  return max_pos
end

function default_if_invalid(input, default, convert)
  return (input == nil or not convert(input)) and default or convert(input)
end

function checkTrimSetting()
  local trimSetting = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Items Editing/zaibuyidao_Trim Split Items Settings.lua'

  if reaper.file_exists(trimSetting) then
    dofile(trimSetting)
  else
    reaper.MB(trimSetting:gsub('%\\', '/')..' not found. Please ensure the script is correctly placed.', '', 0)
    if reaper.APIExists('ReaPack_BrowsePackages') then
      reaper.ReaPack_BrowsePackages('zaibuyidao _Trim Split Items Settings')
    else
      reaper.MB('ReaPack extension not found', '', 0)
    end
  end
end

local get = getSavedDataList("TRIM_SPLIT_ITEMS_SETTINGS", "Parameters")
if get == nil then
  checkTrimSetting()
  reaper.defer(function() end) -- 终止执行
  get = getSavedDataList("TRIM_SPLIT_ITEMS_SETTINGS", "Parameters")
end

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

if FADE == "n" then
  FADE_IN = 0
  FADE_OUT = 0
else
  FADE_IN = LEFT_PAD
  FADE_OUT = RIGHT_PAD
end

if not tonumber(THRESHOLD) or THRESHOLD < -150 or THRESHOLD > 24 then THRESHOLD = -80 end

dB_to_val = 10 ^ (THRESHOLD / 20)
dB_to_val2 = 10 ^ ((THRESHOLD + HYSTERESIS) / 20)

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

-- 获取初始选中的媒体项数量
local total_items = reaper.CountMediaItems(0)

-- 使用逆序循环，从最后一个Item开始处理
for i = total_items - 1, 0, -1 do
  local item = reaper.GetMediaItem(0, i)

  if reaper.IsMediaItemSelected(item) then
    local take = reaper.GetActiveTake(item)
    if take == nil then goto continue_end_loop end

    -- 获取采样值
    local sample_min, sample_max, time_sample = get_sample_pos_value(take, SKIP_SAMPLE, item)
    if not time_sample then goto continue_end_loop end

    -- 初始化保留范围
    local keep_ranges = {}
    local l = nil

    -- 内部循环使用不同的变量名 'j'
    for j = 1, #time_sample do
      if sample_max[j] >= dB_to_val and l == nil then
        l = j
      elseif sample_min[j] < dB_to_val2 and l ~= nil then
        table.insert(keep_ranges, { 
          time_sample[l], 
          time_sample[j - 1], 
          l, 
          j, 
          sample_min[l], 
          sample_max[j], 
          fade = { FADE_IN / 1000, FADE_OUT / 1000 } 
        })
        l = nil
      -- elseif sample_max[j] >= dB_to_val2 and l == nil and #keep_ranges > 0  then -- 只处理左右不分割
      elseif sample_max[j] >= dB_to_val2 and l == nil and #keep_ranges > 0 and (time_sample[j] - keep_ranges[#keep_ranges][2] < MIN_SILENCE_LEN / 1000) then
        l = keep_ranges[#keep_ranges][3]
        table.remove(keep_ranges, #keep_ranges)
      end
    end
    
    if l ~= nil then
      table.insert(keep_ranges, { 
        time_sample[l], 
        time_sample[#time_sample], 
        fade = { FADE_IN / 1000, FADE_OUT / 1000 } 
      })
    end

    -- 合并和扩展范围
    keep_ranges = merge_ranges(item, keep_ranges, MIN_SILENCE_LEN / 1000)
    keep_ranges = expand_ranges(item, keep_ranges, LEFT_PAD / 1000, RIGHT_PAD / 1000, FADE_IN / 1000, FADE_OUT / 1000)

    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = item_start + item_length

    -- 根据模式进行修剪
    if MODE == "del" then
      trim_item(item, keep_ranges, MIN_CLIPS_LEN / 1000, SNAP_OFFSET, LEFT_PAD)
    elseif MODE == "keep" then
      trim_item_keep_silence(item, keep_ranges, MIN_CLIPS_LEN / 1000, SNAP_OFFSET, LEFT_PAD)
    elseif MODE == "begin" then
      trim_item_before_nonsilence(item, keep_ranges, SNAP_OFFSET, LEFT_PAD)
    elseif MODE == "end" then
      trim_item_before_silence(item, keep_ranges, MIN_CLIPS_LEN / 1000)
    end

    ::continue_end_loop::
  end
end

if language == "简体中文" then
  script_title = "修剪分割对象"
elseif language == "繁体中文" then
  script_title = "修剪分割對象"
else
  script_title = "Trim Split Items"
end

reaper.Undo_EndBlock(script_title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()