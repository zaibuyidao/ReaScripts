-- @description Trim Split Items
-- @version 1.0.7
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

function get_sample_pos_value(take, skip_sample)
  if not take or reaper.TakeIsMIDI(take) then
    return false, false, false
  end

  local item = reaper.GetMediaItemTake_Item(take)
  local playrate_ori = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  local item_len_ori = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", item_len_ori * playrate_ori)
  reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", 1)

  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local accessor = reaper.CreateTakeAudioAccessor(take)
  local source = reaper.GetMediaItemTake_Source(take)
  local samplerate = reaper.GetMediaSourceSampleRate(source)

  if skip_sample <= 0 or not tonumber(skip_sample) then
    skip_sample = 0
  elseif skip_sample > 0 then
    -- skip_sample = samplerate / skip_sample -- 每秒处理几个样本
    skip_sample = samplerate / (samplerate / skip_sample) -- 跳过几个样本
  end

  skip_sample = math.floor(0.5 + skip_sample)

  local channels = reaper.GetMediaSourceNumChannels(source)
  local item_len_idx = math.ceil(item_len)

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

      time_sample[#time_sample + 1] = sample_point_num / samplerate / playrate_ori + item_pos
      if time_sample[#time_sample] > item_len_ori + item_pos then breakX = 1 break end
    end
    buffer.clear()
    if breakX == 1 then break end
  end

  reaper.DestroyAudioAccessor(accessor)

  -- 恢复播放速率
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", item_len / playrate_ori)
  reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", playrate_ori)

  time_sample[1] = item_pos
  time_sample[#time_sample] = item_pos + item_len_ori

  return sample_min, sample_max, time_sample
end

function delete_item(item)
  if item then
    local track = reaper.GetMediaItem_Track(item)
    reaper.DeleteTrackMediaItem(track, item)
  end
end

-- 扩展item边界, limit_left/right代表未分割前的item区域，如果最左边或最右边大于等于阈值那么不需要扩展边界
function expand_item(item, left, right, limit_left, limit_right)
  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  if eq(limit_left, item_pos - left) then
    left = 0
  end
  if eq(limit_right, item_pos + right) then
    right = 0
  end
  reaper.BR_SetItemEdges(item, item_pos - left, item_pos + item_len + right)
end

function eq(a, b) return math.abs(a - b) < 0.000001 end

-- 根据ranges保留item指定区域，并删除剩余区域
-- 例：keep_ranges = { {1, 3}, {5, 8} } 代表将item中 1-3 与 5-8区域保留，其余地方删除
function trim_item(item, keep_ranges)
  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  -- print(item_pos, item_pos + item_len)
  -- table.print(keep_ranges)
  local left = item
  for i, range in ipairs(keep_ranges) do
    if not eq(range[1], item_pos) then
      local right = reaper.SplitMediaItem(left, range[1])
      delete_item(left)
      left = right
    end

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

function trim_item_keep_silence(item, keep_ranges)
  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  -- print(item_pos, item_pos + item_len)
  -- table.print(keep_ranges)
  local left = item
  for i, range in ipairs(keep_ranges) do
    if not eq(range[1], item_pos) then
      local right = reaper.SplitMediaItem(left, range[1])
      --delete_item(left)
      left = right
    end

    right = reaper.SplitMediaItem(left, range[2])

    reaper.SetMediaItemInfo_Value(left, "D_FADEINLEN", range.fade[1])
    reaper.SetMediaItemInfo_Value(left, "D_FADEOUTLEN", range.fade[2])

    left = right
    ::continue::
  end

  if #keep_ranges > 0 and keep_ranges[#keep_ranges][2] < item_pos + item_len then
    --delete_item(left)
  end
end

function trim_item_before_silence(item, keep_ranges)
  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  -- print(item_pos, item_pos + item_len)
  -- table.print(keep_ranges)
  local left = item
  for i, range in ipairs(keep_ranges) do
    if not eq(range[1], item_pos) then
      --local right = reaper.SplitMediaItem(left, range[1])
      --delete_item(left)
      left = right
    end

    right = reaper.SplitMediaItem(left, range[2])

    reaper.SetMediaItemInfo_Value(left, "D_FADEINLEN", range.fade[1])
    reaper.SetMediaItemInfo_Value(left, "D_FADEOUTLEN", range.fade[2])

    left = right
    ::continue::
  end

  if #keep_ranges > 0 and keep_ranges[#keep_ranges][2] < item_pos + item_len then
    --delete_item(left)
  end
end

-- 合并间隔较小的保留区域，如果item长度小于MIN_ITEM_LEN，则全部区域保留
function merge_ranges(item, keep_ranges, min_len)
  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  if item_len < MIN_ITEM_LEN / 1000 then
    return { { item_pos, item_pos + item_len } }
  end
  local r = {}
  for i = 1, #keep_ranges do
    if i > 1 and keep_ranges[i][1] - r[#r][2] < min_len then
      r[#r][2] = keep_ranges[i][2]
    else
      table.insert(r, keep_ranges[i])
    end
  end

  -- 删除较小的保留区域
  local r2 = {}
  for i, range in ipairs(r) do
    if math.abs(range[1] - range[2]) > 0.000001 then 
      table.insert(r2, range)
    end
  end

  return r2
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

-- 指定长度范围内最大峰值位置
function max_peak_pos(item, skip, right, left)
  local take = reaper.GetActiveTake(item)
  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local source = reaper.GetMediaItemTake_Source(take)

  if skip <= 0 then
    skip = 0
  elseif skip > 0 then
    skip = reaper.GetMediaSourceSampleRate(source) / skip -- 每秒处理几个样本
  end

  local sample_min, sample_max, time_sample = get_sample_pos_value(take, skip)
  if not time_sample then return nil end

  local right_bound = item_pos + right
  local left_bound = item_pos + left
  -- print(left_bound,right_bound)
  local max_value
  local max_pos

  for i = 1, #time_sample do
    if time_sample[i] >= left_bound then
      if time_sample[i] > right_bound then
        break
      end
      if max_value == nil or sample_max[i] > max_value then
        max_pos = time_sample[i]
        max_value = sample_max[i]
      end
    end
  end
  if max_pos == nil then
    max_pos = item_pos
  else
    max_pos = max_pos - item_pos
  end
  return max_pos
end

local language = getSystemLanguage()

get = getSavedDataList("TRIM_SPLIT_ITEMS", "Parameters")

if get == nil then    -- 默认预设
  THRESHOLD = -60     -- 阈值(dB)
  HYSTERESIS = -6     -- 滯後(dB)
  LEFT_PAD = 0        -- 前导填充(ms)
  RIGHT_PAD = 0       -- 尾部填充(ms)
  MIN_SLICE_LEN = 100 -- 最小切片长度(将不会被删除)
  MIN_ITEM_LEN = 100  -- 最小item长度(ms)
  SNAP_OFFSET = 0     -- 吸附偏移(ms)
  SKIP_SAMPLE = 0     -- 采样点步进
  FADE = "n"          -- 是否淡变
  SPLIT = "y"         -- 是否切割item
  REMOVE = "del"      -- 保持静默

  default = THRESHOLD ..','.. HYSTERESIS ..','.. LEFT_PAD ..','.. RIGHT_PAD ..','.. MIN_SLICE_LEN ..','.. MIN_ITEM_LEN ..','.. SNAP_OFFSET ..','.. SKIP_SAMPLE ..','.. FADE ..','.. SPLIT ..','.. REMOVE

  if language == "简体中文" then
    set = getMutiInput("修剪分割对象设置", 11, "阈值 (dB),滞后 (dB),前导填充 (ms),尾部填充 (ms),最小切片长度 (ms),最小对象长度 (ms),吸附偏移到峰值 (ms),采样点步进,是否淡变 (y/n),是否切割 (y/n),静默模式 (del/keep/before)", default)
  elseif language == "繁体中文" then
    set = getMutiInput("修剪分割對象設置", 11, "閾值 (dB),滯後 (dB),前導填充 (ms),尾部填充 (ms),最小切片長度 (ms),最小對象長度 (ms),吸附偏移到峰值 (ms),采樣點步進,是否淡變 (y/n),是否切割 (y/n),靜默模式 (del/keep/before)", default)
  else
    set = getMutiInput("Trim Split Items Settings", 11, "Threshold (dB),Hysteresis (dB),Leading pad (ms),Trailing pad (ms),Min slice length (ms),Min item length (ms),Snap offset to peak (ms),Sample step,Fade pad (y/n),Is it split? (y/n),Silence mode (del/keep/before)", default)
  end

  if not tonumber(THRESHOLD) or not tonumber(HYSTERESIS) or not tonumber(LEFT_PAD) or not tonumber(RIGHT_PAD) or not tonumber(MIN_SLICE_LEN) or not tonumber(MIN_ITEM_LEN) or not tonumber(SNAP_OFFSET) or not tonumber(SKIP_SAMPLE) or not tostring(FADE) or not tostring(SPLIT) or not tostring(REMOVE) then return end
  saveDataList("TRIM_SPLIT_ITEMS", "Parameters", set, true)
  get = getSavedDataList("TRIM_SPLIT_ITEMS", "Parameters")
  return
end

-- table.print(get)

if get[1] == nil or not tonumber(get[1]) then get[1] = -60 end
if get[2] == nil or not tonumber(get[2]) then get[2] = -6 end
if get[3] == nil or not tonumber(get[3]) then get[3] = 0 end
if get[4] == nil or not tonumber(get[4]) then get[4] = 0 end
if get[5] == nil or not tonumber(get[5]) then get[5] = 100 end
if get[6] == nil or not tonumber(get[6]) then get[6] = 100 end
if get[7] == nil or not tonumber(get[7]) then get[7] = 0 end
if get[8] == nil or not tonumber(get[8]) then get[8] = 0 end
if get[9] == nil or not tostring(get[9]) then get[9] = "n" end
if get[10] == nil or not tostring(get[10]) then get[10] = "y" end
if get[11] == nil or not tostring(get[11]) then get[11] = "del" end

THRESHOLD = tonumber(get[1])
HYSTERESIS = tonumber(get[2])
LEFT_PAD = tonumber(get[3])
RIGHT_PAD = tonumber(get[4])
MIN_SLICE_LEN = tonumber(get[5])
MIN_ITEM_LEN = tonumber(get[6])
SNAP_OFFSET = tonumber(get[7])
SKIP_SAMPLE = tonumber(get[8])
FADE = tostring(get[9])
SPLIT = tostring(get[10])
REMOVE = get[11]

local count_sel_item = reaper.CountSelectedMediaItems(0)

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

for i = count_sel_item - 1, 0, -1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

  local take = reaper.GetActiveTake(item)
  if take == nil then goto continue end

  local sample_min, sample_max, time_sample = get_sample_pos_value(take, SKIP_SAMPLE)
  if not time_sample then goto continue end

  local keep_ranges = {}
  local l
  for i = 1, #time_sample do
    if sample_max[i] >= dB_to_val and l == nil then
      l = i
    elseif sample_min[i] < dB_to_val2 and l ~= nil then
      table.insert(keep_ranges, { time_sample[l], time_sample[i], l, i, sample_min[l], sample_max[i]})
      -- table.insert(keep_ranges, { time_sample[l], time_sample[i - 1], l, i - 1, sample_min[l], sample_max[i - 1]})
      l = nil
    elseif sample_max[i] >= dB_to_val2 and l == nil and #keep_ranges > 0 and time_sample[i] - keep_ranges[#keep_ranges][2] < MIN_SLICE_LEN / 1000 then
      l = keep_ranges[#keep_ranges][3]
      table.remove(keep_ranges, #keep_ranges)
    end
  end
  
  if l ~= nil then
    table.insert(keep_ranges, { time_sample[l], time_sample[#time_sample]})
  end

  if SPLIT == "n" and #keep_ranges > 0 then
    keep_ranges = { { keep_ranges[1][1], keep_ranges[#keep_ranges][2]} }
  end

  -- table.print(keep_ranges)
  -- print(#keep_ranges)
  -- for i = 1, 10 do
  --   table.print(keep_ranges[i])
  -- end
  -- print(keep_ranges[#keep_ranges][2])
  keep_ranges = merge_ranges(item, keep_ranges, MIN_SLICE_LEN / 1000)
  expand_ranges(item, keep_ranges, LEFT_PAD / 1000, RIGHT_PAD / 1000, FADE_IN / 1000, FADE_OUT / 1000)
  -- print(keep_ranges[#keep_ranges][2])
  if REMOVE == "del" then
    trim_item(item, keep_ranges)
  elseif REMOVE == "keep" then
    trim_item_keep_silence(item, keep_ranges)
  elseif REMOVE == "before" then
    trim_item_before_silence(item, keep_ranges)
  end
  ::continue::
end

count_sel_item = reaper.CountSelectedMediaItems(0)
for i = count_sel_item - 1, 0, -1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  if reaper.GetActiveTake(item) == nil then goto continue end
  -- if (LEFT_PAD - SNAP_OFFSET > 0 and SNAP_OFFSET > 0) or (SNAP_OFFSET - LEFT_PAD > 0 and SNAP_OFFSET > 0) then
  if SNAP_OFFSET > 0 then
    local r = max_peak_pos(item, SKIP_SAMPLE, (LEFT_PAD + SNAP_OFFSET) / 1000, LEFT_PAD / 1000)
    if r then
      reaper.SetMediaItemInfo_Value(item, 'D_SNAPOFFSET', r)
    end
  elseif SNAP_OFFSET == 0 then
    reaper.SetMediaItemInfo_Value(item, 'D_SNAPOFFSET', 0)
  end
  ::continue::
end

if language == "简体中文" then
  title = "修剪分割对象"
elseif language == "繁体中文" then
  title = "修剪分割對象"
else
  title = "Trim Split Items"
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()