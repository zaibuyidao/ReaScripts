-- @description Copy/Paste Razor Edit Content
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about
--   Integrated copy/paste tool for razor edit content, markers, regions, and tempo/time signature markers.
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

local EXT_SECTION = "COPY_PASTE_RAZOR_EDIT_CONTENT"
local SETTINGS_SECTION = EXT_SECTION .. "_SETTINGS"

local TEXT = {
  ["简体中文"] = {
    title = "剃刀编辑复制/粘贴",
    missing_reaimgui = "该脚本需要 ReaImGui。请先通过 ReaPack 安装 'ReaImGui: ReaScript binding for Dear ImGui'。",
    ready = "就绪。",
    copy_no_options = "请至少勾选一个复制内容。",
    paste_no_options = "请至少勾选一个粘贴内容。",
    no_razor_edit = "未检测到剃刀编辑范围。请先创建剃刀编辑范围再复制。",
    no_copied_data = "未找到已复制的剃刀编辑数据。请先使用本脚本复制。",
    copied_status = "已复制：内容 %d，标记 %d，区域 %d，速度/拍号 %d。",
    pasted_status = "已粘贴：内容 %d，标记 %d，区域 %d，速度/拍号 %d。",
    copy_failed = "复制失败。",
    paste_failed = "粘贴失败。",
    all = "全部",
    content = "内容",
    markers = "标记",
    regions = "区域",
    tempo = "速度/拍号",
    copy = "复制",
    paste = "粘贴",
    copy_button = "C  复制",
    paste_button = "P  粘贴",
    undo_paste = "粘贴剃刀编辑内容"
  },
  ["繁體中文"] = {
    title = "剃刀編輯複製/貼上",
    missing_reaimgui = "該腳本需要 ReaImGui。請先透過 ReaPack 安裝 'ReaImGui: ReaScript binding for Dear ImGui'。",
    ready = "就緒。",
    copy_no_options = "請至少勾選一個複製內容。",
    paste_no_options = "請至少勾選一個貼上內容。",
    no_razor_edit = "未偵測到剃刀編輯範圍。請先建立剃刀編輯範圍再複製。",
    no_copied_data = "未找到已複製的剃刀編輯資料。請先使用本腳本複製。",
    copied_status = "已複製：內容 %d，標記 %d，區域 %d，速度/拍號 %d。",
    pasted_status = "已貼上：內容 %d，標記 %d，區域 %d，速度/拍號 %d。",
    copy_failed = "複製失敗。",
    paste_failed = "貼上失敗。",
    all = "全部",
    content = "內容",
    markers = "標記",
    regions = "區域",
    tempo = "速度/拍號",
    copy = "複製",
    paste = "貼上",
    copy_button = "C  複製",
    paste_button = "P  貼上",
    undo_paste = "貼上剃刀編輯內容"
  },
  English = {
    title = "Razor Edit Copy/Paste",
    missing_reaimgui = "This script requires ReaImGui. Please install 'ReaImGui: ReaScript binding for Dear ImGui' from ReaPack.",
    ready = "Ready.",
    copy_no_options = "Please enable at least one copy option.",
    paste_no_options = "Please enable at least one paste option.",
    no_razor_edit = "No razor edit area found. Please create a razor edit area before copying.",
    no_copied_data = "No copied razor edit data found. Copy with this script first.",
    copied_status = "Copied: content %d, markers %d, regions %d, tempo/time signatures %d.",
    pasted_status = "Pasted: content %d, markers %d, regions %d, tempo/time signatures %d.",
    copy_failed = "Copy failed.",
    paste_failed = "Paste failed.",
    all = "All",
    content = "Content",
    markers = "Markers",
    regions = "Regions",
    tempo = "Tempo / time signature",
    copy = "Copy",
    paste = "Paste",
    copy_button = "C  Copy",
    paste_button = "P  Paste",
    undo_paste = "Paste Razor Edit Content"
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
    "source_start", "source_end", "marker_count", "tempo_count",
    "has_content", "has_markers", "has_regions", "has_tempo", "last_copy_time"
  }

  for i = 1, #names do
    reaper.DeleteExtState(EXT_SECTION, names[i], false)
  end
end

local function parse_razor_data(data, ranges)
  local found = false

  for start_text, end_text in data:gmatch('([%-%d%.]+)%s+([%-%d%.]+)%s+"[^"]*"') do
    local start_pos = tonumber(start_text)
    local end_pos = tonumber(end_text)
    if start_pos and end_pos and end_pos > start_pos then
      ranges[#ranges + 1] = { start_pos = start_pos, end_pos = end_pos }
      found = true
    end
  end

  if found then return end

  for start_text, end_text in data:gmatch("([%-%d%.]+)%s+([%-%d%.]+)") do
    local start_pos = tonumber(start_text)
    local end_pos = tonumber(end_text)
    if start_pos and end_pos and end_pos > start_pos then
      ranges[#ranges + 1] = { start_pos = start_pos, end_pos = end_pos }
    end
  end
end

local function get_razor_ranges()
  local ranges = {}
  local seen = {}
  local track_count = reaper.CountTracks(0)

  for track_index = 0, track_count - 1 do
    local track = reaper.GetTrack(0, track_index)
    local _, data = reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", "", false)
    if data and data ~= "" then
      local parsed = {}
      parse_razor_data(data, parsed)
      for i = 1, #parsed do
        local range = parsed[i]
        local range_key = string.format("%.12f:%.12f", range.start_pos, range.end_pos)
        if not seen[range_key] then
          seen[range_key] = true
          ranges[#ranges + 1] = range
        end
      end
    end
  end

  table.sort(ranges, function(a, b)
    if a.start_pos == b.start_pos then return a.end_pos < b.end_pos end
    return a.start_pos < b.start_pos
  end)

  local merged = {}
  for i = 1, #ranges do
    local range = ranges[i]
    local last = merged[#merged]
    if not last or range.start_pos > last.end_pos then
      merged[#merged + 1] = { start_pos = range.start_pos, end_pos = range.end_pos }
    elseif range.end_pos > last.end_pos then
      last.end_pos = range.end_pos
    end
  end

  return merged
end

local function position_in_ranges(position, ranges)
  for i = 1, #ranges do
    local range = ranges[i]
    if position >= range.start_pos and position <= range.end_pos then
      return true
    end
  end
  return false
end

local function region_in_ranges(region_start, region_end, ranges)
  for i = 1, #ranges do
    local range = ranges[i]
    if region_start >= range.start_pos and region_end <= range.end_pos then
      return true
    end
  end
  return false
end

local function copy_project_markers(ranges, want_markers, want_regions)
  local total = select(1, reaper.CountProjectMarkers(0)) or 0
  local copied = 0
  local marker_count = 0
  local region_count = 0

  for i = 0, total - 1 do
    local _, is_region, position, region_end, name, marker_index, color = reaper.EnumProjectMarkers3(0, i)
    local include = false

    if is_region then
      include = want_regions and region_in_ranges(position, region_end, ranges)
    else
      include = want_markers and position_in_ranges(position, ranges)
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

local function copy_tempo_markers(ranges)
  local total = reaper.CountTempoTimeSigMarkers(0)
  local copied = 0

  for i = 0, total - 1 do
    local ok, time_pos, measure_pos, beat_pos, bpm, timesig_num, timesig_denom, linear_tempo = reaper.GetTempoTimeSigMarker(0, i)
    if ok and position_in_ranges(time_pos, ranges) then
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

local function paste_content()
  if not get_ext_bool("has_content") then return 0 end
  prepare_arrange_command()
  reaper.Main_OnCommand(42398, 0) -- Item: Paste items/tracks
  return 1
end

local function option_has_any(options)
  return options.content or options.markers or options.regions or options.tempo
end

local last_status = T.ready

local function copy_razor_edit(options)
  if not option_has_any(options) then
    message(T.copy_no_options)
    return
  end

  local ranges = get_razor_ranges()
  if #ranges == 0 then
    message(T.no_razor_edit)
    return
  end

  local source_start = ranges[1].start_pos
  local source_end = ranges[#ranges].end_pos

  reaper.PreventUIRefresh(1)

  local ok, err = pcall(function()
    clear_clipboard()
    set_ext("source_start", source_start)
    set_ext("source_end", source_end)
    set_ext("last_copy_time", os.time())

    local copied_content = 0
    if options.content then
      prepare_arrange_command()
      reaper.Main_OnCommand(40057, 0) -- Edit: Copy items/tracks/envelope points (depending on focus)
      copied_content = 1
      set_ext("has_content", "1")
    else
      set_ext("has_content", "0")
    end

    local copied_markers, copied_regions = 0, 0
    if options.markers or options.regions then
      copied_markers, copied_regions = copy_project_markers(ranges, options.markers, options.regions)
    else
      set_ext("marker_count", 0)
      set_ext("has_markers", "0")
      set_ext("has_regions", "0")
    end

    local copied_tempo = options.tempo and copy_tempo_markers(ranges) or 0
    if not options.tempo then
      set_ext("tempo_count", 0)
      set_ext("has_tempo", "0")
    end

    last_status = string.format(T.copied_status, copied_content, copied_markers, copied_regions, copied_tempo)
  end)

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()

  if not ok then
    last_status = T.copy_failed
    message(T.copy_failed .. "\n\n" .. tostring(err))
  end
end

local function paste_razor_edit(options)
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
    local pasted_content = options.content and paste_content() or 0

    last_status = string.format(T.pasted_status, pasted_content, pasted_markers, pasted_regions, pasted_tempo)
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
  content = load_bool("copy_content", true),
  markers = load_bool("copy_markers", true),
  regions = load_bool("copy_regions", true),
  tempo = load_bool("copy_tempo", true)
}

local function refresh_all(options)
  options.all = options.content and options.markers and options.regions and options.tempo
end

local function set_all(options, value)
  options.all = value
  options.content = value
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

  changed, value = reaper.ImGui_Checkbox(ctx, T.content .. "##" .. prefix .. "_content", options.content)
  if changed then options.content = value end

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
  save_bool("copy_content", copy_options.content)
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
    draw_action_button(T.copy_button, { 0x2D8C7EFF, 0x36A997FF, 0x24766BFF }, copy_options, copy_razor_edit)
    -- reaper.ImGui_Spacing(ctx)
    draw_action_button(T.paste_button, { 0xC9772BFF, 0xD98B42FF, 0xAA6322FF }, copy_options, paste_razor_edit)
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
