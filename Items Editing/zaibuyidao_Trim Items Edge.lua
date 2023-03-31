-- @description Trim Items Edge
-- @version 1.2.6
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
  -- print(item_pos, item_pos + item_len)
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

    reaper.SetMediaItemInfo_Value(left, "D_FADEINLEN", range.fade[1])
    reaper.SetMediaItemInfo_Value(left, "D_FADEOUTLEN", range.fade[2])

    left = right
    ::continue::
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
function expand_ranges(item, keep_ranges, left_pad, right_pad, fade_in, fade_out)
  local item_pos = reaper.GetMediaItemInfo_Value(item,"D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item,"D_LENGTH")
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
    if keep_ranges[i][1] - left_inc <= item_pos + 0.000001 then
      left_inc = keep_ranges[i][1] - item_pos
      actual_fade_in = 0
    end
    if keep_ranges[i][2] + right_inc >= item_pos + item_len - 0.000001 then
      right_inc = item_pos + item_len - keep_ranges[i][2]
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

  local samples_per_block = math.floor(0.5+samplerate*(pend*2))
  local samples_per_block_i = samplerate*(pstart*2)
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

local language = getSystemLanguage()

get = getSavedDataList("TRIM_ITEMS_EDGE", "Parameters")

if get == nil then   -- 默认预设
  threshold_l = -60  -- 阈值(dB)
  threshold_r = -6   -- 滯後(dB)
  length_limit = 100 -- 长度限制(ms)
  leading_pad = 0    -- 前导填充(ms)
  trailing_pad = 0   -- 尾部填充(ms)
  fade = "n"         -- 是否淡变
  snap_offset = 0    -- 吸附偏移(ms)
  step = 0           -- 采样点步进

  default = threshold_l ..','.. threshold_r ..','.. length_limit ..','.. leading_pad ..','.. trailing_pad ..','.. fade ..','.. snap_offset ..','.. step

  if language == "简体中文" then
    title = "修剪对象边缘设置"
    lable = "阈值 (dB),滞后 (dB),最小对象长度 (ms),前导填充 (ms),尾部填充 (ms),是否淡变 (y/n),峰值吸附偏移 (ms),采样点步进"
    set_complete = "设置完毕，请重新运行脚本。"
  elseif language == "繁体中文" then
    title = "修剪對象邊緣設置"
    lable = "閾值 (dB),滯後 (dB),最小對象長度 (ms),前導填充 (ms),尾部填充 (ms),是否淡變 (y/n),峰值吸附偏移 (ms),采樣點步進"
    set_complete = "設置完畢，請重新運行腳本。"
  else
    title = "Trim Items Edge Settings"
    lable = "Threshold (dB),Hysteresis (dB),Min item length (ms),Leading pad (ms),Trailing pad (ms),Fade pad (y/n),Peak snap offset (ms),Sample step"
    set_complete = "Setup is complete, please re-run the script."
  end

  set = getMutiInput(title, 8, lable, default)
  if set == nil or not tonumber(threshold_l) or not tonumber(threshold_r) or not tonumber(length_limit) or not tonumber(leading_pad) or not tonumber(trailing_pad) or not tostring(fade) or not tonumber(snap_offset) or not tonumber(step) then return end

  saveDataList("TRIM_ITEMS_EDGE", "Parameters", set, true)
  get = getSavedDataList("TRIM_ITEMS_EDGE", "Parameters")

  return reaper.MB(set_complete, title, 0)
end

-- table.print(get)

if get[1] == nil or not tonumber(get[1]) then get[1] = -60 end
if get[2] == nil or not tonumber(get[2]) then get[2] = -6 end
if get[3] == nil or not tonumber(get[3]) then get[3] = 100 end
if get[4] == nil or not tonumber(get[4]) then get[4] = 0 end
if get[5] == nil or not tonumber(get[5]) then get[5] = 0 end
if get[6] == nil or not tostring(get[6]) then get[6] = "n" end
if get[7] == nil or not tonumber(get[7]) then get[7] = 0 end
if get[8] == nil or not tonumber(get[8]) then get[8] = 0 end

threshold_l = get[1]
threshold_r = get[2]
length_limit = get[3]
leading_pad = get[4]
trailing_pad = get[5]
fade = get[6]
snap_offset = get[7]
step = get[8]

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
    item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local ret, peak_value_L, peak_pos_L, peak_value_R, peak_pos_R = get_sample_val_and_pos(take, step, threshold_l, threshold_r)

    if ret and item_len > length_limit / 1000 then
      local ranges = { { item_pos + peak_pos_L, item_pos + peak_pos_R } }
      ranges = expand_ranges(item, ranges, leading_pad / 1000, trailing_pad / 1000, fade_in / 1000, fade_out / 1000)

      --trim_item(item, ranges) -- 切割item并删除
      trim_edge(item, ranges)

      if snap_offset > 0 then
        reaper.SetMediaItemInfo_Value(item, 'D_SNAPOFFSET', max_peak_pos(item, step, (leading_pad + snap_offset) / 1000, leading_pad / 1000))
      elseif snap_offset == 0 then
        reaper.SetMediaItemInfo_Value(item, 'D_SNAPOFFSET', 0)
      end
    end
  end
end

if language == "简体中文" then
  title = "修剪对象边缘"
elseif language == "繁体中文" then
  title = "修剪對象邊緣"
else
  title = "Trim Items Edge"
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()