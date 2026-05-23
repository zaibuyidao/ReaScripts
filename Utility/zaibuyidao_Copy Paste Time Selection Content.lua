-- @description Copy/Paste Time Selection Content
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about
--   Integrated copy/paste tool for media items, markers, regions, and tempo/time signature markers in the time selection.
--   Requires ReaImGui and SWS Extension

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

-- Check for ReaImGui dependency
if not reaper.ImGui_GetBuiltinPath then
  if reaper.APIExists('ReaPack_BrowsePackages') then
    reaper.ReaPack_BrowsePackages('ReaImGui: ReaScript binding for Dear ImGui')
    reaper.MB(
      "ReaImGui is not installed or is out of date.\n\n" ..
      "The ReaPack package browser has been opened. Please search for 'ReaImGui' and install or update it before running this script.",
      "Batch Rename Plus", 0)
  else
    local reapackErrorMsg = 
      "ReaPack is not installed.\n\n" ..
      "To use this script, please install ReaPack first:\n" ..
      "https://reapack.com\n\n" ..
      "After installing ReaPack, use it to install 'ReaImGui: ReaScript binding for Dear ImGui'."
    reaper.MB(reapackErrorMsg, "ReaPack Not Found", 0)
  end
  return
end

if not reaper.APIExists("JS_Window_Find") then
  local jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
  local jstitle = "You must install JS_ReaScriptAPI"
  reaper.MB(jsmsg, jstitle, 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, "Error", 0)
  end
  return reaper.defer(function() end)
end

local ImGui
if reaper.ImGui_GetBuiltinPath then
  package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
  ImGui = require 'imgui' '0.10'
end

local language = getSystemLanguage()

local EXT_SECTION = "COPY_PASTE_TIME_SELECTION_CONTENT"
local SETTINGS_SECTION = EXT_SECTION .. "_SETTINGS"

local TEXT = {
  ["简体中文"] = {
    title = "时间选区复制/粘贴",
    missing_reaimgui = "该脚本需要 ReaImGui。请先通过 ReaPack 安装 'ReaImGui: ReaScript binding for Dear ImGui'。",
    ready = "就绪。",
    copy_no_options = "请至少勾选一个复制内容。",
    paste_no_options = "请至少勾选一个粘贴内容。",
    no_time_selection = "未检测到时间选区。请先创建时间选区再复制。",
    no_copied_data = "未找到已复制的时间选区数据。请先使用本脚本复制。",
    copied_status = "已复制：媒体对象 %d，标记 %d，区域 %d，速度/拍号 %d。",
    pasted_status = "已粘贴：媒体对象 %d，标记 %d，区域 %d，速度/拍号 %d。",
    copy_failed = "复制失败。",
    paste_failed = "粘贴失败。",
    all = "全部",
    items = "媒体对象",
    markers = "标记",
    regions = "区域",
    tempo = "速度/拍号",
    copy = "复制",
    paste = "粘贴",
    copy_button = "C  复制",
    paste_button = "P  粘贴",
    undo_paste = "粘贴时间选区内容"
  },
  ["繁體中文"] = {
    title = "時間選區複製/貼上",
    missing_reaimgui = "該腳本需要 ReaImGui。請先透過 ReaPack 安裝 'ReaImGui: ReaScript binding for Dear ImGui'。",
    ready = "就緒。",
    copy_no_options = "請至少勾選一個複製內容。",
    paste_no_options = "請至少勾選一個貼上內容。",
    no_time_selection = "未偵測到時間選區。請先建立時間選區再複製。",
    no_copied_data = "未找到已複製的時間選區資料。請先使用本腳本複製。",
    copied_status = "已複製：媒體物件 %d，標記 %d，區域 %d，速度/拍號 %d。",
    pasted_status = "已貼上：媒體物件 %d，標記 %d，區域 %d，速度/拍號 %d。",
    copy_failed = "複製失敗。",
    paste_failed = "貼上失敗。",
    all = "全部",
    items = "媒體物件",
    markers = "標記",
    regions = "區域",
    tempo = "速度/拍號",
    copy = "複製",
    paste = "貼上",
    copy_button = "C  複製",
    paste_button = "P  貼上",
    undo_paste = "貼上時間選區內容"
  },
  English = {
    title = "Time Selection Copy/Paste",
    missing_reaimgui = "This script requires ReaImGui. Please install 'ReaImGui: ReaScript binding for Dear ImGui' from ReaPack.",
    ready = "Ready.",
    copy_no_options = "Please enable at least one copy option.",
    paste_no_options = "Please enable at least one paste option.",
    no_time_selection = "No time selection found. Please create a time selection before copying.",
    no_copied_data = "No copied time selection data found. Copy with this script first.",
    copied_status = "Copied: media items %d, markers %d, regions %d, tempo/time signatures %d.",
    pasted_status = "Pasted: media items %d, markers %d, regions %d, tempo/time signatures %d.",
    copy_failed = "Copy failed.",
    paste_failed = "Paste failed.",
    all = "All",
    items = "Media items",
    markers = "Markers",
    regions = "Regions",
    tempo = "Tempo / time signature",
    copy = "Copy",
    paste = "Paste",
    copy_button = "C  Copy",
    paste_button = "P  Paste",
    undo_paste = "Paste Time Selection Content"
  }
}

local T = TEXT[language] or TEXT.English
local TITLE = T.title

local function message(text)
  reaper.MB(text, TITLE, 0)
end

if not reaper.APIExists or not reaper.APIExists("ImGui_CreateContext") then
  message(T.missing_reaimgui)
  return
end

local function key(prefix, index)
  return string.format("%s%04d", prefix, index)
end

local function set_ext(name, value)
  reaper.SetExtState(EXT_SECTION, name, tostring(value), false)
end

local function get_ext(name)
  return reaper.GetExtState(EXT_SECTION, name)
end

local function get_ext_number(name, default)
  local value = tonumber(get_ext(name))
  if value == nil then return default end
  return value
end

local function get_ext_bool(name)
  return get_ext(name) == "1"
end

local function prepare_arrange_command()
  if reaper.SetCursorContext then
    reaper.SetCursorContext(1, nil)
  end
end

local function pack_values(values)
  local out = {}
  for i = 1, #values do
    local value = values[i]
    local value_type = type(value)
    local value_text = tostring(value)
    out[#out + 1] = value_type .. ":" .. #value_text .. ":" .. value_text
  end
  return table.concat(out)
end

local function unpack_values(text)
  local values = {}
  local pos = 1

  while pos <= #text do
    local type_end = text:find(":", pos, true)
    if not type_end then break end

    local value_type = text:sub(pos, type_end - 1)
    local length_end = text:find(":", type_end + 1, true)
    if not length_end then break end

    local length = tonumber(text:sub(type_end + 1, length_end - 1))
    if not length then break end

    local value_text = text:sub(length_end + 1, length_end + length)
    pos = length_end + length + 1

    if value_type == "number" then
      values[#values + 1] = tonumber(value_text)
    elseif value_type == "boolean" then
      values[#values + 1] = value_text == "true"
    else
      values[#values + 1] = value_text
    end
  end

  return values
end

local function clear_clipboard()
  local marker_count = math.max(get_ext_number("marker_count", 0), 0)
  local tempo_count = math.max(get_ext_number("tempo_count", 0), 0)

  for i = 1, marker_count do
    reaper.DeleteExtState(EXT_SECTION, key("marker", i), false)
  end

  for i = 1, tempo_count do
    reaper.DeleteExtState(EXT_SECTION, key("tempo", i), false)
  end

  local names = {
    "source_start", "source_end", "item_offset", "marker_count", "tempo_count",
    "has_items", "has_markers", "has_regions", "has_tempo", "last_copy_time"
  }

  for i = 1, #names do
    reaper.DeleteExtState(EXT_SECTION, names[i], false)
  end
end

local function capture_item_selection()
  local selected = {}
  local count = reaper.CountSelectedMediaItems(0)
  for i = 0, count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if item then selected[item] = true end
  end
  return selected
end

local function for_each_item(fn)
  local track_count = reaper.CountTracks(0)
  for track_index = 0, track_count - 1 do
    local track = reaper.GetTrack(0, track_index)
    local item_count = reaper.CountTrackMediaItems(track)
    for item_index = 0, item_count - 1 do
      local item = reaper.GetTrackMediaItem(track, item_index)
      fn(item)
    end
  end
end

local function restore_item_selection(selected)
  for_each_item(function(item)
    reaper.SetMediaItemSelected(item, selected[item] == true)
  end)
end

local function item_overlaps_time_selection(item, start_time, end_time)
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  return item_start < end_time and item_end > start_time
end

local function collect_items_for_time_selection(start_time, end_time)
  local any_selected = false
  local selected_in_range = false
  local selected_outside_range = false
  local items = {}

  for_each_item(function(item)
    local overlaps = item_overlaps_time_selection(item, start_time, end_time)
    local selected = reaper.IsMediaItemSelected(item)

    if selected then
      any_selected = true
      if overlaps then
        selected_in_range = true
      else
        selected_outside_range = true
      end
    end

    items[#items + 1] = {
      item = item,
      selected = selected,
      overlaps = overlaps,
      position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    }
  end)

  local targets = {}
  local earliest = nil

  for i = 1, #items do
    local data = items[i]
    local should_copy = false

    if not any_selected then
      should_copy = data.overlaps
    elseif selected_outside_range and not selected_in_range then
      should_copy = data.overlaps
    else
      should_copy = data.selected and data.overlaps
    end

    if should_copy then
      targets[#targets + 1] = data.item
      if earliest == nil or data.position < earliest then
        earliest = data.position
      end
    end
  end

  return targets, earliest
end

local function select_only_items(items)
  local target = {}
  for i = 1, #items do
    target[items[i]] = true
  end

  for_each_item(function(item)
    reaper.SetMediaItemSelected(item, target[item] == true)
  end)
end

local function copy_items(start_time, end_time)
  local targets, earliest = collect_items_for_time_selection(start_time, end_time)
  if #targets == 0 or earliest == nil then
    set_ext("has_items", "0")
    return 0
  end

  local original_selection = capture_item_selection()
  select_only_items(targets)
  local ok, err = pcall(function()
    set_ext("item_offset", earliest - start_time)
    prepare_arrange_command()
    reaper.Main_OnCommand(40698, 0) -- Edit: Copy items
  end)
  restore_item_selection(original_selection)

  if not ok then error(err) end

  set_ext("has_items", "1")
  return #targets
end

local function copy_project_markers(start_time, end_time, want_markers, want_regions)
  local total = select(1, reaper.CountProjectMarkers(0)) or 0
  local copied = 0
  local marker_count = 0
  local region_count = 0

  for i = 0, total - 1 do
    local _, is_region, position, region_end, name, marker_index, color = reaper.EnumProjectMarkers3(0, i)
    local include = false

    if is_region then
      include = want_regions and position >= start_time and region_end <= end_time
    else
      include = want_markers and position >= start_time and position <= end_time
    end

    if include then
      copied = copied + 1
      if is_region then
        region_count = region_count + 1
      else
        marker_count = marker_count + 1
      end

      local data = { is_region, position, region_end, name or "", marker_index or -1, color or 0 }
      reaper.SetExtState(EXT_SECTION, key("marker", copied), pack_values(data), false)
    end
  end

  set_ext("marker_count", copied)
  set_ext("has_markers", marker_count > 0 and "1" or "0")
  set_ext("has_regions", region_count > 0 and "1" or "0")
  return marker_count, region_count
end

local function copy_tempo_markers(start_time, end_time)
  local total = reaper.CountTempoTimeSigMarkers(0)
  local copied = 0

  for i = 0, total - 1 do
    local ok, time_pos, measure_pos, beat_pos, bpm, timesig_num, timesig_denom, linear_tempo = reaper.GetTempoTimeSigMarker(0, i)
    if ok and time_pos >= start_time and time_pos <= end_time then
      copied = copied + 1
      local data = { time_pos, measure_pos, beat_pos, bpm, timesig_num, timesig_denom, linear_tempo }
      reaper.SetExtState(EXT_SECTION, key("tempo", copied), pack_values(data), false)
    end
  end

  set_ext("tempo_count", copied)
  set_ext("has_tempo", copied > 0 and "1" or "0")
  return copied
end

local function read_project_markers()
  local markers = {}
  local count = get_ext_number("marker_count", 0)

  for i = 1, count do
    local text = get_ext(key("marker", i))
    if text ~= "" then
      markers[#markers + 1] = unpack_values(text)
    end
  end

  return markers
end

local function paste_project_markers(want_markers, want_regions)
  local source_start = tonumber(get_ext("source_start"))
  local source_end = tonumber(get_ext("source_end"))
  if not source_start or not source_end then return 0, 0 end

  local source_length = math.max(0, source_end - source_start)
  local cursor = reaper.GetCursorPosition()
  local offset = cursor - source_start
  local markers = read_project_markers()
  local pasted_markers = 0
  local pasted_regions = 0

  for i = 1, #markers do
    local marker = markers[i]
    local is_region = marker[1] == true

    if (is_region and want_regions) or ((not is_region) and want_markers) then
      local new_start = (tonumber(marker[2]) or 0) + offset
      local new_end = is_region and ((tonumber(marker[3]) or tonumber(marker[2]) or 0) + offset) or 0

      if is_region and source_length > 0 and new_end - new_start > source_length then
        new_end = new_start + source_length
      end

      reaper.AddProjectMarker2(0, is_region, new_start, new_end, marker[4] or "", -1, tonumber(marker[6]) or 0)

      if is_region then
        pasted_regions = pasted_regions + 1
      else
        pasted_markers = pasted_markers + 1
      end
    end
  end

  return pasted_markers, pasted_regions
end

local function read_tempo_markers()
  local markers = {}
  local count = get_ext_number("tempo_count", 0)

  for i = 1, count do
    local text = get_ext(key("tempo", i))
    if text ~= "" then
      markers[#markers + 1] = unpack_values(text)
    end
  end

  return markers
end

local function paste_tempo_markers()
  local source_start = tonumber(get_ext("source_start"))
  if not source_start then return 0 end

  local cursor = reaper.GetCursorPosition()
  local offset = cursor - source_start
  local markers = read_tempo_markers()
  local pasted = 0

  for i = 1, #markers do
    local marker = markers[i]
    local new_pos = (tonumber(marker[1]) or 0) + offset
    reaper.SetTempoTimeSigMarker(
      0,
      -1,
      new_pos,
      -1,
      -1,
      tonumber(marker[4]) or 120,
      tonumber(marker[5]) or 4,
      tonumber(marker[6]) or 4,
      marker[7] == true
    )
    pasted = pasted + 1
  end

  return pasted
end

local function paste_items()
  if not get_ext_bool("has_items") then return 0 end

  local cursor = reaper.GetCursorPosition()
  local item_offset = get_ext_number("item_offset", 0)
  reaper.SetEditCurPos(cursor + item_offset, false, false)
  prepare_arrange_command()
  reaper.Main_OnCommand(42398, 0) -- Item: Paste items/tracks
  reaper.SetEditCurPos(cursor, false, false)
  return 1
end

local function set_pasted_time_selection()
  local source_start = tonumber(get_ext("source_start"))
  local source_end = tonumber(get_ext("source_end"))
  if not source_start or not source_end then return end

  local cursor = reaper.GetCursorPosition()
  local offset = cursor - source_start
  reaper.GetSet_LoopTimeRange(true, false, source_start + offset, source_end + offset, false)
end

local function option_has_any(options)
  return options.items or options.markers or options.regions or options.tempo
end

local last_status = T.ready

local function copy_time_selection(options)
  if not option_has_any(options) then
    message(T.copy_no_options)
    return
  end

  local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if start_time == end_time then
    message(T.no_time_selection)
    return
  end

  reaper.PreventUIRefresh(1)

  local ok, err = pcall(function()
    clear_clipboard()
    set_ext("source_start", start_time)
    set_ext("source_end", end_time)
    set_ext("last_copy_time", os.time())

    local copied_items = options.items and copy_items(start_time, end_time) or 0
    local copied_markers, copied_regions = 0, 0
    if options.markers or options.regions then
      copied_markers, copied_regions = copy_project_markers(start_time, end_time, options.markers, options.regions)
    else
      set_ext("marker_count", 0)
      set_ext("has_markers", "0")
      set_ext("has_regions", "0")
    end

    local copied_tempo = options.tempo and copy_tempo_markers(start_time, end_time) or 0
    if not options.tempo then
      set_ext("tempo_count", 0)
      set_ext("has_tempo", "0")
    end

    last_status = string.format(T.copied_status, copied_items, copied_markers, copied_regions, copied_tempo)
  end)

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()

  if not ok then
    last_status = T.copy_failed
    message(T.copy_failed .. "\n\n" .. tostring(err))
  end
end

local function paste_time_selection(options)
  if not option_has_any(options) then
    message(T.paste_no_options)
    return
  end

  if get_ext("source_start") == "" then
    message(T.no_copied_data)
    return
  end

  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()

  local ok, err = pcall(function()
    local pasted_tempo = options.tempo and paste_tempo_markers() or 0
    local pasted_markers, pasted_regions = 0, 0
    if options.markers or options.regions then
      pasted_markers, pasted_regions = paste_project_markers(options.markers, options.regions)
    end
    local pasted_items = options.items and paste_items() or 0

    if pasted_items > 0 or pasted_markers > 0 or pasted_regions > 0 then
      set_pasted_time_selection()
    end

    last_status = string.format(T.pasted_status, pasted_items, pasted_markers, pasted_regions, pasted_tempo)
  end)

  reaper.Undo_EndBlock(T.undo_paste, -1)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()

  if not ok then
    last_status = T.paste_failed
    message(T.paste_failed .. "\n\n" .. tostring(err))
  end
end

local function load_bool(name, default_value)
  local value = reaper.GetExtState(SETTINGS_SECTION, name)
  if value == "" then return default_value end
  return value == "1"
end

local function save_bool(name, value)
  reaper.SetExtState(SETTINGS_SECTION, name, value and "1" or "0", true)
end

local copy_options = {
  all = load_bool("copy_all", true),
  items = load_bool("copy_items", true),
  markers = load_bool("copy_markers", true),
  regions = load_bool("copy_regions", true),
  tempo = load_bool("copy_tempo", true)
}

local function refresh_all(options)
  options.all = options.items and options.markers and options.regions and options.tempo
end

local function set_all(options, value)
  options.all = value
  options.items = value
  options.markers = value
  options.regions = value
  options.tempo = value
end

refresh_all(copy_options)

local function create_ui_font(size)
  if not reaper.ImGui_CreateFont then return nil end

  local os_name = reaper.GetOS()
  local names
  if os_name == "Win32" or os_name == "Win64" then
    names = { "Microsoft YaHei UI", "Microsoft YaHei", "SimHei", "sans-serif" }
  elseif os_name == "OSX32" or os_name == "OSX64" or os_name == "macOS-arm64" then
    names = { "PingFang SC", "Hiragino Sans GB", "Heiti SC", "sans-serif" }
  else
    names = { "Noto Sans CJK SC", "WenQuanYi Micro Hei", "sans-serif" }
  end

  for i = 1, #names do
    local font = reaper.ImGui_CreateFont(names[i], size)
    if font then return font end
  end

  return nil
end

local ctx = reaper.ImGui_CreateContext(TITLE)
local font_normal_size = 15
local font_button_size = 22
local font_small_size = 13
local font_normal = create_ui_font(font_normal_size)
local font_button = create_ui_font(font_button_size)
local font_small = create_ui_font(font_small_size)

if font_normal then reaper.ImGui_Attach(ctx, font_normal) end
if font_button then reaper.ImGui_Attach(ctx, font_button) end
if font_small then reaper.ImGui_Attach(ctx, font_small) end

reaper.ImGui_SetNextWindowSize(ctx, 200, 380, reaper.ImGui_Cond_FirstUseEver())

local function push_font(font, size)
  if font then reaper.ImGui_PushFont(ctx, font, size) end
end

local function pop_font(font)
  if font then reaper.ImGui_PopFont(ctx) end
end

local function colored_button(label, colors)
  local width = -1
  local height = 52
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 8)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), colors[1])
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), colors[2])
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), colors[3])
  push_font(font_button, font_button_size)
  local clicked = reaper.ImGui_Button(ctx, label, width, height)
  pop_font(font_button)
  reaper.ImGui_PopStyleColor(ctx, 3)
  reaper.ImGui_PopStyleVar(ctx)
  return clicked
end

local function draw_options(prefix, options)
  local changed, value = reaper.ImGui_Checkbox(ctx, T.all .. "##" .. prefix .. "_all", options.all)
  if changed then
    set_all(options, value)
  end

  changed, value = reaper.ImGui_Checkbox(ctx, T.items .. "##" .. prefix .. "_items", options.items)
  if changed then options.items = value end

  changed, value = reaper.ImGui_Checkbox(ctx, T.markers .. "##" .. prefix .. "_markers", options.markers)
  if changed then options.markers = value end

  changed, value = reaper.ImGui_Checkbox(ctx, T.regions .. "##" .. prefix .. "_regions", options.regions)
  if changed then options.regions = value end

  changed, value = reaper.ImGui_Checkbox(ctx, T.tempo .. "##" .. prefix .. "_tempo", options.tempo)
  if changed then options.tempo = value end

  refresh_all(options)
end

local function save_settings()
  save_bool("copy_all", copy_options.all)
  save_bool("copy_items", copy_options.items)
  save_bool("copy_markers", copy_options.markers)
  save_bool("copy_regions", copy_options.regions)
  save_bool("copy_tempo", copy_options.tempo)
end

local function draw_action_button(button_label, button_colors, options, action)
  if colored_button(button_label, button_colors) then
    save_settings()
    action(options)
  end
end

local function loop()
  if font_normal then reaper.ImGui_PushFont(ctx, font_normal, font_normal_size) end
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 8)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 5)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 10, 8)

  local visible, open = reaper.ImGui_Begin(ctx, TITLE, true)
  if visible then
    draw_action_button(T.copy_button, { 0x2D8C7EFF, 0x36A997FF, 0x24766BFF }, copy_options, copy_time_selection)
    -- reaper.ImGui_Spacing(ctx)
    draw_action_button(T.paste_button, { 0xC9772BFF, 0xD98B42FF, 0xAA6322FF }, copy_options, paste_time_selection)
    reaper.ImGui_Separator(ctx)
    draw_options("shared", copy_options)
    reaper.ImGui_Separator(ctx)
    push_font(font_small, font_small_size)
    reaper.ImGui_TextWrapped(ctx, last_status)
    pop_font(font_small)
    reaper.ImGui_End(ctx)
  end

  reaper.ImGui_PopStyleVar(ctx, 3)
  if font_normal then reaper.ImGui_PopFont(ctx) end

  if open then
    reaper.defer(loop)
  else
    save_settings()
    if reaper.ImGui_DestroyContext then
      reaper.ImGui_DestroyContext(ctx)
    end
  end
end

loop()
