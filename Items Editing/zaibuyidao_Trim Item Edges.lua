-- @description Trim Item Edges
-- @version 1.0.7
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

function eq(a, b, epsilon)
  epsilon = epsilon or 1e-5  -- 将 epsilon 增大到 1e-5
  return math.abs(a - b) < epsilon
end

function log10(x) if not x then return end return math.log(x, 10) end
function todb(x) if not x then return end return 20 * log10(x) end
function topower(x) if not x then return end return 10 ^ (x / 20) end

function trim_edge(item, keep_ranges)
  -- 获取原始的淡入淡出设置
  local orig_fade_in = reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN")
  local orig_fade_out = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN")

  for i, range in ipairs(keep_ranges) do
    -- 获取处理前的左右边界
    local item_left = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_right = item_left + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

    -- 设置新的左右边界
    reaper.BR_SetItemEdges(item, range[1], range[2])

    -- 如果左边界有变动且左边界没有与淡入设置相同，则修改淡入设置
    if not eq(range[1], item_left) and not eq(range.fade[1], orig_fade_in) then
      reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", range.fade[1])
    end

    -- 如果右边界有变动且右边界没有与淡出设置相同，则修改淡出设置
    if not eq(range[2], item_right) and not eq(range.fade[2], orig_fade_out) then
      reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", range.fade[2])
    end
  end
end

-- 扩展保留区域
function expand_ranges(item, keep_ranges, left_pad, right_pad, fade_in, fade_out)
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = item_start + item_length
  local epsilon = 1e-5

  -- 获取采样率，用于将时间转换为采样点
  local take = reaper.GetActiveTake(item)
  local source = reaper.GetMediaItemTake_Source(take)
  local samplerate = reaper.GetMediaSourceSampleRate(source)
  if not samplerate or samplerate == 0 then
    samplerate = 44100  -- 默认采样率
  end

  for i = 1, #keep_ranges do
    -- 将时间转换为采样点，避免浮点误差
    local left_sample = math.floor((keep_ranges[i][1] - left_pad - item_start) * samplerate + 0.5)
    local right_sample = math.floor((keep_ranges[i][2] + right_pad - item_start) * samplerate + 0.5)

    -- 确保不会超出 item 的范围
    if left_sample < 0 then
      left_sample = 0
      fade_in = 0
    end
    if right_sample > item_length * samplerate then
      right_sample = item_length * samplerate
      fade_out = 0
    end

    -- 将采样点转换回时间
    local new_left = item_start + left_sample / samplerate
    local new_right = item_start + right_sample / samplerate

    keep_ranges[i] = { new_left, new_right, fade = { fade_in, fade_out } }
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

  -- 获取采样率和通道数
  local samplerate = reaper.GetMediaSourceSampleRate(source)
  if not samplerate or samplerate == 0 then
    samplerate = 44100  -- 默认采样率
  end
  local channels = reaper.GetMediaSourceNumChannels(source)

  local left_min = topower(threshold)
  local right_min = topower(threshold + hysteresis)

  local lv, rv
  local l, r

  local samples_per_channel = math.ceil((aa_end - aa_start) * samplerate)
  local buffer = reaper.new_array(samples_per_channel * channels)

  -- 读取所有样本
  local aa_ret = reaper.GetAudioAccessorSamples(accessor, samplerate, channels, aa_start, samples_per_channel, buffer)
  if aa_ret <= 0 then
    reaper.DestroyAudioAccessor(accessor)
    return nil
  end

  -- 查找左边界
  for i = 0, samples_per_channel - 1 do
    for j = 0, channels - 1 do
      local idx = i * channels + j + 1
      local v = math.abs(buffer[idx])
      if v > left_min then
        lv = v
        l = i
        goto found_l
      end
    end
  end
  ::found_l::

  -- 查找右边界
  for i = samples_per_channel - 1, 0, -1 do
    for j = 0, channels - 1 do
      local idx = i * channels + j + 1
      local v = math.abs(buffer[idx])
      if v > right_min then
        rv = v
        r = i
        goto found_r
      end
    end
  end
  ::found_r::

  reaper.DestroyAudioAccessor(accessor)

  if lv and rv then
    return true, todb(lv), l / samplerate, todb(rv), r / samplerate
  end
  return nil
end

function max_peak_pos(item, step, pend, pstart)
  if not item then return nil end

  local take = reaper.GetActiveTake(item)
  if not take then return nil end

  local source = reaper.GetMediaItemTake_Source(take)
  if not source then return nil end

  local accessor = reaper.CreateTakeAudioAccessor(take)
  if not accessor then return nil end

  local samplerate = reaper.GetMediaSourceSampleRate(source)
  if not samplerate or samplerate == 0 then
    samplerate = 44100  -- 默认采样率
  end
  local channels = reaper.GetMediaSourceNumChannels(source)

  -- 计算起始和结束的采样块
  local samples_per_block = math.max(1, math.floor(samplerate * pend * channels)) -- 确保至少有一个样本
  local samples_per_block_i = math.max(1, math.floor(samplerate * pstart * channels))

  -- 创建缓冲区并读取样本
  local buffer = reaper.new_array(samples_per_block * channels)
  reaper.GetAudioAccessorSamples(accessor, samplerate, channels, 0, samples_per_block, buffer)

  local v_max, max_peak, max_zero = 0, 0, 0

  -- 确保步长设置合理
  if step <= 0 then
    step = 1
  else
    step = math.max(1, math.floor(samplerate / step))
  end

  -- 遍历样本数据，查找最大峰值
  for i = samples_per_block_i, samples_per_block, step do
    local v = math.abs(buffer[i])
    if v > v_max then
      v_max = v
      max_peak = i / channels - 1  -- 记录最大峰值位置
    end
    max_zero = v_max
  end

  -- 计算snap_offset_pos
  local snap_offset_pos = max_peak / samplerate
  reaper.DestroyAudioAccessor(accessor)

  if max_peak > 0 then
    return snap_offset_pos
  end
  return nil
end

function default_if_invalid(input, default, convert)
  local status, result = pcall(convert, input)
  if not status or result == nil then
    return default
  end
  return result
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

local track_items = {}

-- 缓存所有选中的媒体项到对应的轨道
local total_items = reaper.CountMediaItems(0)
for i = 0, total_items - 1 do
  local item = reaper.GetMediaItem(0, i)
  if reaper.IsMediaItemSelected(item) then
    local track = reaper.GetMediaItem_Track(item)
    if not track_items[track] then 
      track_items[track] = {} 
    end
    table.insert(track_items[track], item)
  end
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
  
      if item_start + item_length > source_absolute_end then
        item_length = source_absolute_end - item_start
        -- 对于超出左右边界的item直接将其复位
        reaper.BR_SetItemEdges(item, item_start, item_start + item_length)
      end
    end

    local ret, peak_value_L, peak_pos_L, peak_value_R, peak_pos_R = get_sample_val_and_pos(take, step, threshold_l, threshold_r)
    if ret and item_length > length_limit / 1000 then
      local ranges = { { item_start + peak_pos_L, item_start + peak_pos_R } }
      
      ranges = expand_ranges(item, ranges, leading_pad / 1000, trailing_pad / 1000, fade_in / 1000, fade_out / 1000)

      trim_edge(item, ranges)

      if snap_offset > 0 and step == 0 then
        reaper.SetMediaItemInfo_Value(item, 'D_SNAPOFFSET', max_peak_pos(item, step, (leading_pad + snap_offset) / 1000, leading_pad / 1000))
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