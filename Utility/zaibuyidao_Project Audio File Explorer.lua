-- @description Project Audio Explorer
-- @version 1.5.7
-- @author zaibuyidao
-- @changelog
--   The peektree section now uses CollapsingHeader instead of TreeNode for a cleaner and more intuitive interface.
--   Pressing ESC will now quickly exit the script if there is no selection in the waveform preview window.
-- @links
--   https://www.soundengine.cn/u/zaibuyidao
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI, SWS Extension, and ReaImGui.

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

local ImGui
if reaper.ImGui_GetBuiltinPath then
  package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
  ImGui = require 'imgui' '0.9'
end

local SCRIPT_NAME = 'Project Audio Explorer - Browse, Search, and Preview Audio Files'
local FLT_MIN, FLT_MAX = reaper.ImGui_NumericLimits_Float()
local ctx = reaper.ImGui_CreateContext(SCRIPT_NAME)
local sans_serif = reaper.ImGui_CreateFont('sans-serif', 14)
local font_small = reaper.ImGui_CreateFont("", 12)
local font_medium = reaper.ImGui_CreateFont("", 14)
local font_large = reaper.ImGui_CreateFont("", 20)
reaper.ImGui_Attach(ctx, sans_serif)
reaper.ImGui_Attach(ctx, font_small)
reaper.ImGui_Attach(ctx, font_medium)
reaper.ImGui_Attach(ctx, font_large)
reaper.ImGui_SetNextWindowSize(ctx, 1400, 857, reaper.ImGui_Cond_FirstUseEver())
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]

-- 状态变量
local CACHE_PIXEL_WIDTH      = 2048
local font_size              = 14    -- 默认字体大小
local need_refresh_font      = false
local FONT_SIZE_MIN          = 10
local FONT_SIZE_MAX          = 20
local selected_row           = -1
local playing_preview        = nil
local playing_path           = nil
local playing_source         = nil
local loop_enabled           = false -- 是否自动循环
local preview_play_len       = 0     -- 当前预览音频长度
local peak_chans             = 6     -- 默认显示6路电平
local seek_pos               = nil   -- 拖动时记住目标位置
local play_rate              = 1     -- 默认速率1.0
local pitch                  = 0     -- 音高调节（半音，正负）
local preserve_pitch         = true  -- 变速时是否保持音高
local is_paused              = false -- 是否处于暂停状态
local paused_position        = 0     -- 暂停时的进度
local base_height            = reaper.ImGui_GetFrameHeight(ctx) * 1.5 -- 底部进度条和电平条一致的高度控制
local volume                 = 1     -- 线性音量默认值（1=0dB，0.5=-6dB，2=+6dB）
local max_db                 = 12    -- 音量最大值
local min_db                 = -150  -- 音量最小值
local pitch_knob_min         = -6    -- 音高旋钮最低
local pitch_knob_max         = 6     -- 音高旋钮最高
local rate_min               = 0.25  -- 速率旋钮最低
local rate_max               = 4.0   -- 速率旋钮最高
local last_audio_idx         = nil
local auto_scroll_enabled    = false -- 自动滚屏
local auto_play_next         = false -- 连续播放勾选
local auto_play_next_pending = nil
local files_idx_cache        = nil   -- 文件缓存

last_selected_info           = nil -- 上次选中的音频信息
last_playing_info            = nil  -- 上次播放的音频信息
is_knob_dragging             = false
prev_preview_pos             = 0
-- 表格排序常量
local COL_FILENAME         = 2
local COL_SIZE             = 3
local COL_TYPE             = 4
local COL_DATE             = 5
local COL_GENRE            = 6
local COL_COMMENT          = 7
local COL_DESCRIPTION      = 8
local COL_LENGTH           = 9
local COL_CHANNELS         = 10
local COL_SAMPLERATE       = 11
local COL_BITS             = 12
-- ExtState持久化设置
local EXT_SECTION          = "ProjectAudioFileExplorer"
local EXT_KEY_PEAKS        = "PeakChans"
local EXT_KEY_FONT_SIZE    = "FontSize"
local EXT_KEY_MAX_DB       = "MaxDB"
local EXT_KEY_PITCH_MIN    = "PitchKnobMin"
local EXT_KEY_PITCH_MAX    = "PitchKnobMax"
local EXT_KEY_RATE_MIN     = "RateMin"
local EXT_KEY_RATE_MAX     = "RateMax"
local EXT_KEY_VOLUME       = "Volume"
local EXT_KEY_CACHE_DIR    = "CacheDir"
local EXT_KEY_AUTOSCROLL   = "AutoScroll"
-- 列表过滤
local filename_filter      = nil
-- 预览已读标记
local previewed_files = {}
local function MarkPreviewed(path) previewed_files[path] = true end
local function IsPreviewed(path) return previewed_files[path] == true end
-- 波形缓存路径
local DEFAULT_CACHE_DIR = script_path .. "waveform_cache/"
local cache_dir = reaper.GetExtState(EXT_SECTION, EXT_KEY_CACHE_DIR)
if not cache_dir or cache_dir == "" then
  cache_dir = DEFAULT_CACHE_DIR
end
local function EnsureCacheDir()
  local sep = package.config:sub(1,1)
  if not reaper.EnumerateFiles(cache_dir, 0) then
    os.execute((sep == "/" and "mkdir -p " or "mkdir ") .. '"' .. cache_dir .. '"')
  end
end
EnsureCacheDir()

-- 波形预览状态变量
local wf_step = 400                    -- 波形预览步长
local img_w, img_h = 1200, 120         -- 波形图像宽度和高度
local base_img_h = 120                 -- 波形基础高度
local img_h_offset = 0                 -- 偏移高度，用于实时调整
local timeline_height = 20             -- 时间线高度
local max_sec = nil                    -- 最大秒数
local wf_play_start_time = nil         -- 播放开始时间（os.clock）
local wf_play_start_cursor = nil       -- 播放开始时光标位置
local selecting = false                -- 是否正在拖拽选区
local drag_start_x = nil               -- 拖拽起点像素
local select_start_time = nil          -- 选区起点时间
local select_end_time = nil            -- 选区终点时间
local last_play_cursor_before_play = 0 -- 记录播放前光标
local prev_play_cursor = nil
local peaks, pixel_cnt, src_len, channel_count
local last_pixel_cnt, last_view_len, last_scroll
local last_wave_info -- 记录上次渲染的info
local peak_hold = {} -- 存放各通道的峰值保持
local waveform_vertical_zoom = 1 -- 默认纵向缩放为1（100%）
local VERTICAL_ZOOM_MIN = 0.3
local VERTICAL_ZOOM_MAX = 4.0
local show_vertical_zoom = false
local show_vertical_zoom_timer = 0
-- 定义Wave类
local Wave = {
  play_cursor = 0,
  src_len = 0,
  scroll = 0,
  zoom = 1,
  w = 0, -- 波形宽度
}

-- 读取ExtState
local last_peak_chans = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_PEAKS))
if last_peak_chans then peak_chans = math.min(math.max(last_peak_chans, 6), 128) end
local last_font_size = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_FONT_SIZE))
if last_font_size then font_size = math.min(math.max(last_font_size, FONT_SIZE_MIN), FONT_SIZE_MAX) end
local last_max_db = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_MAX_DB))
if last_max_db then max_db = last_max_db end
local last_pitch_knob_min = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_PITCH_MIN))
if last_pitch_knob_min then pitch_knob_min = last_pitch_knob_min end
local last_pitch_knob_max = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_PITCH_MAX))
if last_pitch_knob_max then pitch_knob_max = last_pitch_knob_max end
local last_rate_min = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_RATE_MIN))
if last_rate_min then rate_min = last_rate_min end
local last_rate_max = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_RATE_MAX))
if last_rate_max then rate_max = last_rate_max end
local last_volume = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_VOLUME))
if last_volume then volume = last_volume end
local last_auto_scroll = reaper.GetExtState(EXT_SECTION, EXT_KEY_AUTOSCROLL)
if last_auto_scroll == "0" then auto_scroll_enabled = false end
if last_auto_scroll == "1" then auto_scroll_enabled = true end

-- 默认收集模式（0=Items, 1=RPP, 2=Directory, 3=Media Items, 4=This Computer, 5=Shortcuts）
local collect_mode           = -1 -- -1 表示未设置
local COLLECT_MODE_ITEMS     = 0
local COLLECT_MODE_RPP       = 1
local COLLECT_MODE_DIR       = 2
local COLLECT_MODE_ALL_ITEMS = 3
local COLLECT_MODE_TREE      = 4
local COLLECT_MODE_SHORTCUT  = 5
local COLLECT_MODE_CUSTOMFOLDER = 6 -- 自定义文件夹模式

-- 设置相关
local auto_play_selected  = true
local DOUBLECLICK_INSERT  = 0
local DOUBLECLICK_PREVIEW = 1
local DOUBLECLICK_NONE    = 2
local doubleclick_action  = DOUBLECLICK_NONE -- 默认 Do Do nothing
local bg_alpha            = 1.0              -- 默认背景不透明

-- 保存设置
local function SaveSettings()
  -- reaper.SetExtState(EXT_SECTION, "collect_mode", tostring(collect_mode), true)
  reaper.SetExtState(EXT_SECTION, "doubleclick_action", tostring(doubleclick_action), true)
  reaper.SetExtState(EXT_SECTION, "auto_play_selected", tostring(auto_play_selected and 1 or 0), true)
  reaper.SetExtState(EXT_SECTION, "preserve_pitch", tostring(preserve_pitch and 1 or 0), true)
  reaper.SetExtState(EXT_SECTION, "bg_alpha", tostring(bg_alpha), true)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_PEAKS, tostring(peak_chans), true)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_FONT_SIZE, tostring(font_size), true)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_MAX_DB, tostring(max_db), true)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_PITCH_MIN, tostring(pitch_knob_min), true)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_PITCH_MAX, tostring(pitch_knob_max), true)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_RATE_MIN, tostring(rate_min), true)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_RATE_MAX, tostring(rate_max), true)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_CACHE_DIR, tostring(cache_dir), true)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_AUTOSCROLL, tostring(auto_scroll_enabled and 1 or 0), true)
end

-- 恢复设置
-- local last_collect_mode = tonumber(reaper.GetExtState(EXT_SECTION, "collect_mode"))
-- if last_collect_mode then collect_mode = last_collect_mode end

local last_doubleclick_action = tonumber(reaper.GetExtState(EXT_SECTION, "doubleclick_action"))
if last_doubleclick_action then doubleclick_action = last_doubleclick_action end

local last_auto_play = reaper.GetExtState(EXT_SECTION, "auto_play_selected")
if last_auto_play == "1" then auto_play_selected = true
elseif last_auto_play == "0" then auto_play_selected = false end

local last_preserve_pitch = reaper.GetExtState(EXT_SECTION, "preserve_pitch")
if last_preserve_pitch == "1" then preserve_pitch = true
elseif last_preserve_pitch == "0" then preserve_pitch = false end

local last_bg_alpha = tonumber(reaper.GetExtState(EXT_SECTION, "bg_alpha"))
if last_bg_alpha then bg_alpha = last_bg_alpha end

local last_img_h_offset = tonumber(reaper.GetExtState(EXT_SECTION, "ImgHOffset"))
if last_img_h_offset then img_h_offset = last_img_h_offset end

-- 文件夹快捷方式
local EXT_KEY_SHORTCUTS = "FolderShortcuts"

function SaveFolderShortcuts()
  local t = {}
  for _, sc in ipairs(folder_shortcuts) do
    local name = (sc.name or ""):gsub(";", "%%3B"):gsub("%|%|", "%%7C%%7C")
    local path = (sc.path or ""):gsub(";", "%%3B"):gsub("%|%|", "%%7C%%7C")
    table.insert(t, name .. ";;" .. path)
  end
  local str = table.concat(t, "||")
  reaper.SetExtState(EXT_SECTION, EXT_KEY_SHORTCUTS, str, true)
end

function LoadFolderShortcuts()
  local str = reaper.GetExtState(EXT_SECTION, EXT_KEY_SHORTCUTS)
  local shortcuts = {}
  if str and str ~= "" then
    for pair in str:gmatch("[^|][^|]*;;[^|]+") do
      local name, path = pair:match("^(.-);;(.*)$")
      if name and path then
        name = name:gsub("%%3B", ";"):gsub("%%7C%%7C", "||")
        path = path:gsub("%%3B", ";"):gsub("%%7C%%7C", "||")
        table.insert(shortcuts, { name = name, path = path })
      end
    end
  end
  return shortcuts
end

folder_shortcuts = LoadFolderShortcuts()

--------------------------------------------- 颜色相关 ---------------------------------------------

-- 完全透明
local transparent = 0x00000000 -- R=00 G=00 B=00 A=00
local yellow      = 0xFFFF00FF -- 纯黄，RGBA 全不透明
-- 基本色 (100% 不透明)
local white       = 0xFFFFFFFF -- 白色
local black       = 0x000000FF -- 黑色
local red         = 0xFF0000FF -- 红色
local green       = 0x00FF00FF -- 绿色
local blue        = 0x0000FFFF -- 蓝色
local yellow      = 0xFFFF00FF -- 黄色
local cyan        = 0x00FFFFFF -- 青色
local magenta     = 0xFF00FFFF -- 品红
-- 灰度
local gray        = 0x808080FF -- 中灰
local lightGray   = 0xC0C0C0FF -- 浅灰
local darkGray    = 0x404040FF -- 深灰
-- 其他常用色
local orange      = 0xFFA500FF -- 橙色
local purple      = 0x800080FF -- 紫色
local pink        = 0xFFC0CBFF -- 粉色
local brown       = 0xA52A2AFF -- 棕色
local lime        = 0x32CD32FF -- 酸橙绿
local gold        = 0xFFD700FF -- 金色
local silver      = 0xC0C0C0FF -- 银色
-- 表格标题字体、悬停与激活颜色
local table_header_hovered = 0x294A7A60 -- 鼠标悬停时表头颜色 0x404040FF
local table_header_active  = 0x294A7AFF -- 鼠标点击时表头颜色 0x303030FF
local normal_text          = 0xFFF0F0F0 -- -- 0xCCCCCCFF -- 柔和灰白
local previewed_text       = 0x888888FF -- 已预览过的更暗
local timeline_default_color = 0xCFCFCFFF -- 时间线默认颜色 0x3F3F48FF 0xA9A9A9FF 0xA6B3C0FF 0xBFC6D1FF 0xE6ECFFFF 0xD8E1F2FF

--------------------------------------------- 波形缓存相关函数 ---------------------------------------------

local function GetFileSize(filepath)
  local f = io.open(filepath, "rb")
  if not f then return 0 end
  f:seek("end")
  local sz = f:seek()
  f:close()
  return sz or 0
end

local function SimpleHash(str)
  local hash = 0
  for i = 1, #str do
    hash = (hash * 31 + str:byte(i)) % 2^32
  end
  return ("%08x"):format(hash)
end

local function CacheFilename(filepath)
  local size = tostring(GetFileSize(filepath))
  return cache_dir .. SimpleHash(filepath .. "@" .. size) .. ".wfc"
end

-- 保存缓存
local function SaveWaveformCache(filepath, data)
  local f = io.open(CacheFilename(filepath), "w+b")
  if not f then return end
  -- 第一行info，后面每行为每个像素的峰值
  f:write(string.format("%d,%d,%f\n", data.pixel_cnt, data.channel_count, data.src_len))
  for px = 1, data.pixel_cnt do
    for ch = 1, data.channel_count do
      local minv, maxv = data.peaks[ch][px][1], data.peaks[ch][px][2]
      f:write(string.format("%f,%f", minv, maxv))
      if ch < data.channel_count then f:write(",") end
    end
    f:write("\n")
  end
  f:close()
end

-- 读取缓存
local function LoadWaveformCache(filepath)
  local f = io.open(CacheFilename(filepath), "rb")
  if not f then return nil end
  local line = f:read("*l")
  if not line then f:close() return nil end
  local pixel_cnt, channel_count, src_len = line:match("^(%d+),(%d+),([%d%.]+)")
  pixel_cnt, channel_count, src_len = tonumber(pixel_cnt), tonumber(channel_count), tonumber(src_len)
  local peaks = {}
  for ch = 1, channel_count do peaks[ch] = {} end
  local px = 1
  for l in f:lines() do
    local vals = {}
    for v in l:gmatch("([%-%d%.]+)") do table.insert(vals, tonumber(v)) end
    for ch = 1, channel_count do
      peaks[ch][px] = {vals[(ch-1)*2+1], vals[(ch-1)*2+2]}
    end
    px = px + 1
  end
  f:close()
  return {peaks=peaks, pixel_cnt=pixel_cnt, channel_count=channel_count, src_len=src_len}
end

local function RemapWaveformToWindow(cache, pixel_cnt, start_time, end_time)
  local cache_len = cache.src_len
  local cache_pixel_cnt = cache.pixel_cnt
  local chs = cache.channel_count
  local peaks_new = {}
  for ch = 1, chs do peaks_new[ch] = {} end
  local window_len = end_time - start_time
  -- 对每个显示像素，找到在缓存中的位置做插值
  for px = 1, pixel_cnt do
    -- 当前像素在窗口中的时间
    local t = (px-1)/(pixel_cnt-1) * window_len + start_time
    -- 时间 t 在缓存中的采样点位置
    local src_px = t / cache_len * (cache_pixel_cnt-1) + 1
    local i = math.floor(src_px)
    local frac = src_px - i
    for ch = 1, chs do
      local v1 = cache.peaks[ch][i] or {0,0}
      local v2 = cache.peaks[ch][i+1] or v1
      local minv = v1[1] + (v2[1] - v1[1]) * frac
      local maxv = v1[2] + (v2[2] - v1[2]) * frac
      peaks_new[ch][px] = {minv, maxv}
    end
  end
  return peaks_new, pixel_cnt, window_len, chs
end

-- 获取波形数据
function GetPeaksWithCache(info, wf_step, pixel_cnt, start_time, end_time)
  if not info or not info.path or info.path == "" then return end
  local cache = LoadWaveformCache(info.path)
  if not cache then
    -- 第一次采样，直接全量采样最大宽度
    local peaks, _, src_len, channel_count = GetPeaksForInfo(info, wf_step, CACHE_PIXEL_WIDTH, start_time, end_time)
    if peaks and src_len and channel_count then
      SaveWaveformCache(info.path, {peaks=peaks, pixel_cnt=CACHE_PIXEL_WIDTH, channel_count=channel_count, src_len=src_len})
      cache = {peaks=peaks, pixel_cnt=CACHE_PIXEL_WIDTH, channel_count=channel_count, src_len=src_len}
    end
  end
  if not cache then return end

  -- 波形放大/缩小时，直接对缓存数据做插值采样。例如pixel_cnt=窗口宽度
  local peaks_new = {}
  for ch = 1, cache.channel_count do peaks_new[ch] = {} end
  for px = 1, pixel_cnt do
    local src_px = (px-1) / (pixel_cnt-1) * (cache.pixel_cnt-1) + 1
    local i = math.floor(src_px)
    local frac = src_px - i
    for ch = 1, cache.channel_count do
      local v1 = cache.peaks[ch][i] or {0, 0}
      local v2 = cache.peaks[ch][i+1] or v1  -- 越界时用v1
      -- 线性插值
      local minv = v1[1] + (v2[1] - v1[1]) * frac
      local maxv = v1[2] + (v2[2] - v1[2]) * frac
      peaks_new[ch][px] = {minv, maxv}
    end
  end
  return peaks_new, pixel_cnt, cache.src_len, cache.channel_count
end

--------------------------------------------- 收集工程音频相关函数 ---------------------------------------------

-- 过滤音频文件
function IsValidAudioFile(path)
  local ext = path:match("%.([^.]+)$")
  if not ext then return false end
  ext = ext:lower()
  return (ext == "wav" or ext == "mp3" or ext == "flac" or ext == "ogg" or ext == "aiff" or ext == "ape" or ext == "wv")
end

function GetItemSectionStartPos(item)
  local take = reaper.GetActiveTake(item)
  if not take then return 0 end
  local src = reaper.GetMediaItemTake_Source(take)
  local src_type = reaper.GetMediaSourceType(src, "")
  if src_type ~= "SECTION" then return 0 end

  local track = reaper.GetMediaItem_Track(item)
  local rv, chunk = reaper.GetTrackStateChunk(track, "", false)
  if not rv then return 0 end

  local item_count = reaper.CountTrackMediaItems(track)
  local item_idx = -1
  for j = 0, item_count - 1 do
    if reaper.GetTrackMediaItem(track, j) == item then
      item_idx = j + 1
      break
    end
  end

  if item_idx == -1 then return 0 end
  local cur = 0
  for block in chunk:gmatch("<ITEM.-\n>") do
    cur = cur + 1
    if cur == item_idx then
      local source_section = block:match("<SOURCE SECTION(.-)\n>")
      if source_section then
        local startpos = source_section:match("STARTPOS ([%d%.]+)")
        if startpos then
          return tonumber(startpos)
        else
          return 0
        end
      else
        return 0
      end
    end
  end
  return 0
end

function GetTakeSectionStartPos(take)
  if not take then return 0 end
  local item = reaper.GetMediaItemTake_Item(take)
  return GetItemSectionStartPos(item)
end

function GetSectionInfo(item, src)
  local start_offset, length = 0, 0
  if reaper.GetMediaSourceType(src, "") == "SECTION" then
    start_offset = GetItemSectionStartPos(item) or 0
    length = reaper.GetMediaSourceLength(src) or 0
  else
    length = reaper.GetMediaSourceLength(src) or 0
  end
  return start_offset, length
end

local function GetRootSource(src)
  while reaper.GetMediaSourceType(src, "") == "SECTION" do
    local parent = reaper.GetMediaSourceParent(src)
    if not parent then break end
    src = parent
  end
  return src
end

-- Items 收集工程中当前使用的音频文件
local function CollectFromItems()
  local files, files_idx = {}, {}
  local item_cnt = reaper.CountMediaItems(0)
  for i = 0, item_cnt - 1 do
    local item = reaper.GetMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    if take then
      local source = reaper.GetMediaItemTake_Source(take)
      local path = reaper.GetMediaSourceFileName(source, "")
      local typ = reaper.GetMediaSourceType(source, "")
      if path and path ~= "" and not files[path] and (typ == "WAVE" or typ == "MP3" or typ == "FLAC" or typ == "OGG" or typ == "AIFF" or typ == "APE" or typ == "WV") then
        -- 获取文件大小并格式化
        local size = 0
        local size_str = "0 B"
        local f = io.open(path, "rb")
        if f then
          f:seek("end")
          size = f:seek()
          f:close()
        end

        local bits = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(source) or "-"
        local _, genre = reaper.GetMediaFileMetadata(source, "XMP:dm/genre")
        local _, comment = reaper.GetMediaFileMetadata(source, "MP:dm/logComment")
        local _, description = reaper.GetMediaFileMetadata(source, "BWF:Description")
        local _, orig_date   = reaper.GetMediaFileMetadata(source, "BWF:OriginationDate")
        files[path] = {
          path = path,
          filename = path:match("([^/\\]+)$") or path,
          type = typ,
          samplerate = reaper.GetMediaSourceSampleRate(source),
          channels = reaper.GetMediaSourceNumChannels(source),
          length = reaper.GetMediaSourceLength(source),
          bits   = bits,
          genre = genre or "",
          comment = comment or "",
          description = description or "",
          bwf_orig_date = orig_date or "",
          size = size,
          source = source
        }
        files_idx[#files_idx+1] = files[path]
      end
    end
  end
  return files, files_idx
end

-- Media Items 收集所有工程对象
function CollectMediaItems()
  local files_idx = {}
  local item_cnt = reaper.CountMediaItems(0)
  for i = 0, item_cnt - 1 do
    local item = reaper.GetMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    local src, path, typ, size, bits, samplerate, channels, length = nil, "", "", 0, "-", "-", "-", "-"
    local description, comment = "", ""
    if take then
      src = reaper.GetMediaItemTake_Source(take)
      local take_offset = GetItemSectionStartPos(item) or 0
      local take_length = reaper.GetMediaSourceLength(src) or 0
      path = reaper.GetMediaSourceFileName(src, "")
      -- 通过源文件路径获取type，保证类型准确
      if path and path ~= "" then
        local real_src = reaper.PCM_Source_CreateFromFile(path)
        if real_src then
          typ = reaper.GetMediaSourceType(real_src, "")
          reaper.PCM_Source_Destroy(real_src)
        else
          typ = ""
        end
      else
        typ = ""
      end
      if not (typ == "WAVE" or typ == "MP3" or typ == "FLAC" or typ == "OGG" or typ == "AIFF" or typ == "APE" or typ == "WV") then
        goto continue
      end
      -- typ = reaper.GetMediaSourceType(src, "") -- 通过take获取type，无法保证类型准确。会混入SECTION 等非音频类型
      bits = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(src) or "-"
      samplerate = reaper.GetMediaSourceSampleRate(src)
      channels = reaper.GetMediaSourceNumChannels(src)
      length = reaper.GetMediaSourceLength(src)
      -- 文件大小
      local f = io.open(path, "rb")
      if f then
        f:seek("end")
        size = f:seek()
        f:close()
      end
      local _, desc = reaper.GetMediaFileMetadata(src, "BWF:Description")
      local _, comm = reaper.GetMediaFileMetadata(src, "MP:dm/logComment")  -- 兼容BWF/MP3
      description = desc or ""
      comment = comm or ""
    end
    local track = reaper.GetMediaItem_Track(item)
    local _, track_name = reaper.GetTrackName(track)
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local _, take_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    table.insert(files_idx, {
      item = item,
      take = take,
      source = src,
      path = path,
      filename = take_name ~= "" and take_name or (path:match("[^/\\]+$") or path),
      type = typ,
      samplerate = samplerate,
      channels = channels,
      length = length,
      bits = bits,
      size = size,
      description = description,
      comment = comment,
      track = track,
      track_name = track_name,
      position = pos,
      section_offset = take_offset,
      section_length = take_length,
    })
    ::continue::
  end
  return files_idx
end

-- RPP 收集所有引用的音频文件
function CollectFromRPP()
  local files_idx = {}
  local path_set = {}

  -- 获取RPP所有引用路径
  local tracks = {}
  local track_count = reaper.CountTracks(0)
  for i = 0, track_count-1 do
    tracks[#tracks+1] = reaper.GetTrack(0, i)
  end
  for _, track in ipairs(tracks) do
    local ret, chunk = reaper.GetTrackStateChunk(track, "", false)
    if ret and chunk then
      for path in chunk:gmatch('FILE%s+"(.-)"') do
        if path and path ~= "" then
          path_set[path] = true
        end
      end
    end
  end

  local item_cnt = reaper.CountMediaItems(0)
  for i = 0, item_cnt - 1 do
    local item = reaper.GetMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    if take then
      local src = reaper.GetMediaItemTake_Source(take)
      local root_src = GetRootSource(src) -- 统一获取音频源
      local path = reaper.GetMediaSourceFileName(root_src, "")
      if path and path_set[path] then
        local typ, bits, samplerate, channels, length, size = "", "-", "-", "-", "-", 0
        local description, comment = "", ""
        -- 获取元数据
        local real_src = reaper.PCM_Source_CreateFromFile(path)
        if real_src then
          typ = reaper.GetMediaSourceType(real_src, "")
          samplerate = reaper.GetMediaSourceSampleRate(real_src)
          channels = reaper.GetMediaSourceNumChannels(real_src)
          length = reaper.GetMediaSourceLength(real_src)
          bits = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(real_src) or "-"
          local f = io.open(path, "rb")
          if f then
            f:seek("end")
            size = f:seek()
            f:close()
          end
          local _, desc = reaper.GetMediaFileMetadata(real_src, "BWF:Description")
          local _, comm = reaper.GetMediaFileMetadata(real_src, "MP:dm/logComment")
          description = desc or ""
          comment = comm or ""
          reaper.PCM_Source_Destroy(real_src)
        end
        local track = reaper.GetMediaItem_Track(item)
        local _, track_name = reaper.GetTrackName(track)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local _, take_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        table.insert(files_idx, {
          item = item,
          take = take,
          source = src,
          path = path,
          filename = path:match("[^/\\]+$") or path,
          type = typ,
          samplerate = samplerate,
          channels = channels,
          length = length,
          bits = bits,
          size = size,
          description = description,
          comment = comment,
          track = track,
          track_name = track_name,
          position = pos,
        })
      end
    end
  end

  return files_idx
end

-- Project Directory 收集工程目录的音频文件
function CollectFromProjectDirectory()
  local files, files_idx = {}, {}
  -- 获取当前工程路径
  local proj_path = reaper.GetProjectPath()
  if not proj_path or proj_path == "" then return files, files_idx end
  -- 支持的扩展名
  local valid_exts = {wav=true, mp3=true, flac=true, ogg=true, aiff=true, ape=true, wv=true}
  local i = 0
  while true do
    local file = reaper.EnumerateFiles(proj_path, i)
    if not file then break end
    local ext = file:match("^.+%.([^.]+)$")
    if ext and valid_exts[ext:lower()] and ext:lower() ~= "rpp" then
      local fullpath = proj_path .. "/" .. file
      if IsValidAudioFile(fullpath) and not files[fullpath] then
        local info = { path = fullpath, filename = file }
        -- 获取文件大小
        local f = io.open(fullpath, "rb")
        if f then
          f:seek("end")
          info.size = f:seek()
          f:close()
        else
          info.size = 0
        end

        local src = reaper.PCM_Source_CreateFromFile(fullpath)

        -- 测试元数据内容，可获取元数据信息用于对应列读取
        -- local retval, metadata_list = reaper.GetMediaFileMetadata(src, "")
        -- reaper.ShowConsoleMsg(metadata_list)

        if src then
          info.source = src
          info.type = reaper.GetMediaSourceType(src, "")
          info.length = reaper.GetMediaSourceLength(src)
          info.samplerate = reaper.GetMediaSourceSampleRate(src)
          info.channels = reaper.GetMediaSourceNumChannels(src)
          info.bits = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(src) or "-"
          local _, genre = reaper.GetMediaFileMetadata(src, "XMP:dm/genre")
          local _, comment = reaper.GetMediaFileMetadata(src, "XMP:dm/logComment")
          local _, description = reaper.GetMediaFileMetadata(src, "BWF:Description")
          local _, orig_date  = reaper.GetMediaFileMetadata(src, "BWF:OriginationDate")
          info.genre = genre or ""
          info.comment = comment or ""
          info.description = description or ""
          info.bwf_orig_date = orig_date or ""
        end
        files[fullpath] = info
        files_idx[#files_idx+1] = info
      end
    end
    i = i + 1
  end

  return files, files_idx
end

function CollectFromCustomFolder(paths)
  local files_idx = {}
  for _, path in ipairs(paths or {}) do
    if type(path) == "string" and path ~= "" then
      if not IsValidAudioFile(path) then
        goto continue
      end

      local typ, size, bits, samplerate, channels, length = "", 0, "-", "-", "-", "-"
      local genre, description, comment, orig_date = "", "", "", ""

      -- 通过PCM_Source采集属性
      if reaper.file_exists and reaper.file_exists(path) then
        local src = reaper.PCM_Source_CreateFromFile(path)
        if src then
          typ = reaper.GetMediaSourceType(src, "")
          bits = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(src) or "-"
          samplerate = reaper.GetMediaSourceSampleRate(src)
          channels = reaper.GetMediaSourceNumChannels(src)
          length = reaper.GetMediaSourceLength(src)
          -- 直接赋值到外部变量
          local _, _genre = reaper.GetMediaFileMetadata(src, "XMP:dm/genre")
          local _, _comment = reaper.GetMediaFileMetadata(src, "XMP:dm/logComment")
          local _, _description = reaper.GetMediaFileMetadata(src, "BWF:Description")
          local _, _orig_date  = reaper.GetMediaFileMetadata(src, "BWF:OriginationDate")
          genre = _genre or ""
          comment = _comment or ""
          description = _description or ""
          orig_date = _orig_date or ""
          reaper.PCM_Source_Destroy(src)
        end
      end

      -- 音频格式
      if not (typ == "WAVE" or typ == "MP3" or typ == "FLAC" or typ == "OGG" or typ == "AIFF" or typ == "APE" or typ == "WV") then
        goto continue
      end

      -- 文件大小
      local f = io.open(path, "rb")
      if f then
        f:seek("end")
        size = f:seek()
        f:close()
      end

      local filename = path:match("[^/\\]+$") or path

      table.insert(files_idx, {
        path = path,
        filename = filename,
        type = typ,
        samplerate = samplerate,
        channels = channels,
        length = length,
        bits = bits,
        size = size,
        genre = genre,
        description = description,
        comment = comment,
        bwf_orig_date = orig_date,
        position = 0,
        section_offset = 0,
        section_length = length,
      })
    end
    ::continue::
  end
  return files_idx
end

-- 按文件名排序
local function SortFilesByFilenameAsc()
  if files_idx_cache then
    table.sort(files_idx_cache, function(a, b)
      return (a.filename or "") < (b.filename or "")
    end)
  end
end

function MergeUsagesByPath(files_idx)
  local merged = {}
  local map = {}
  for _, info in ipairs(files_idx) do
    local key = info.path or ""
    if not map[key] then
      -- 拷贝一份新的结构
      local newinfo = {}
      for k, v in pairs(info) do newinfo[k] = v end
      newinfo.usages = {info}
      map[key] = newinfo
      table.insert(merged, newinfo)
    else
      table.insert(map[key].usages, info)
    end
  end
  return merged
end

function MergeUsagesBySection(files_idx)
  local merged = {}
  local map = {}
  for _, info in ipairs(files_idx) do
    -- 先得到原始path，再判断区段
    local root_src = GetRootSource(info.source)
    local path = reaper.GetMediaSourceFileName(root_src, "")
    local start_offset, length = 0, 0
    if reaper.GetMediaSourceType(info.source, "") == "SECTION" then
      start_offset, length = GetSectionInfo(info.item, info.source)
    else
      length = reaper.GetMediaSourceLength(root_src) or 0
      start_offset = 0
    end
    -- key 由 path, start_offset, length 唯一确定
    local key = string.format("%s|%0.9f|%0.9f", path, start_offset, length)
    if not map[key] then
      local newinfo = {}
      for k, v in pairs(info) do newinfo[k] = v end
      newinfo.path = path
      newinfo.section_offset = start_offset
      newinfo.section_length = length
      newinfo.usages = {info}
      map[key] = newinfo
      table.insert(merged, newinfo)
    else
      table.insert(map[key].usages, info)
    end
  end
  return merged
end

function CollectFiles()
  local files, files_idx
  if collect_mode == COLLECT_MODE_ITEMS then
    files, files_idx = CollectFromItems()
    files_idx_cache = files_idx
  elseif collect_mode == COLLECT_MODE_DIR then
    files, files_idx = CollectFromProjectDirectory()
    files_idx_cache = files_idx
  elseif collect_mode == COLLECT_MODE_TREE then
    local dir = tree_state.cur_path or "" -- 或默认某个盘符/目录
    files_idx_cache = GetAudioFilesFromDirCached(dir)
    selected_row = nil
  elseif collect_mode == COLLECT_MODE_RPP then
    files_idx = CollectFromRPP()
    files_idx_cache = MergeUsagesByPath(files_idx)
  elseif collect_mode == COLLECT_MODE_ALL_ITEMS then
    files_idx = CollectMediaItems()
    files_idx_cache = MergeUsagesBySection(files_idx)
  elseif collect_mode == COLLECT_MODE_SHORTCUT then
    local dir = tree_state.cur_path or ""
    files_idx_cache = GetAudioFilesFromDirCached(dir)
    selected_row = nil
  elseif collect_mode == COLLECT_MODE_CUSTOMFOLDER then
    local folder = tree_state.cur_custom_folder or ""
    local paths = (folder ~= "" and custom_folders_content[folder]) or {}
    files_idx_cache = CollectFromCustomFolder(paths)
    selected_row = nil
  elseif collect_mode == COLLECT_MODE_ADVANCEDFOLDER then -- 高级文件夹模式
      local folder_id = tree_state.cur_advanced_folder or ""
      local folder = advanced_folders[folder_id]
      local paths = (folder and folder.files) or {}
      files_idx_cache = CollectFromCustomFolder(paths)
      selected_row = nil
  else
    files_idx_cache = {} -- collect_mode全部清空
  end

  if files_idx_cache then
    for _, info in ipairs(files_idx_cache) do
      info.group = GetCustomGroupsForPath(info.path)
    end
  end

  previewed_files = {}
  SortFilesByFilenameAsc()
end

-- 资源释放函数
function DestroySources(files_idx)
  for _, info in ipairs(files_idx) do
    if info.source then
      reaper.PCM_Source_Destroy(info.source)
      info.source = nil
    end
  end
end

local function StopPlay()
  if playing_preview then
    reaper.CF_Preview_Stop(playing_preview)
    playing_preview = nil
  else
    reaper.CF_Preview_StopAll()
  end
  is_paused = false
  paused_position = 0
end

-- 播放文件
local function PlayFile(source, path, do_loop)
  StopPlay()
  if source then
    playing_preview = reaper.CF_CreatePreview(source)
    if playing_preview then
      if reaper.CF_Preview_SetValue then
        reaper.CF_Preview_SetValue(playing_preview, "B_LOOP", do_loop and 1 or 0)
        reaper.CF_Preview_SetValue(playing_preview, "D_VOLUME", volume)      -- 设置音量
        reaper.CF_Preview_SetValue(playing_preview, "D_PLAYRATE", play_rate) -- 设置播放速率
        reaper.CF_Preview_SetValue(playing_preview, "D_PITCH", pitch)
        reaper.CF_Preview_SetValue(playing_preview, "B_PPITCH", preserve_pitch and 1 or 0)
      end
      reaper.CF_Preview_Play(playing_preview)
      playing_path = path
      playing_source = source
      preview_play_len = reaper.GetMediaSourceLength(source) or 0
      MarkPreviewed(path)
    end
  end
end

function RestartPreviewWithParams(from_wave_pos)
  if not playing_source then return end
  local cur_pos = 0

  if from_wave_pos then
    cur_pos = from_wave_pos / play_rate -- 用新的速率换算
  else
    if playing_preview and reaper.CF_Preview_GetValue then
      local ok, pos = reaper.CF_Preview_GetValue(playing_preview, "D_POSITION")
      if ok then cur_pos = pos end
    end
  end

  StopPlay()
  playing_preview = reaper.CF_CreatePreview(playing_source)
  if playing_preview then
    reaper.CF_Preview_SetValue(playing_preview, "B_LOOP", loop_enabled and 1 or 0)
    reaper.CF_Preview_SetValue(playing_preview, "D_VOLUME", volume)
    reaper.CF_Preview_SetValue(playing_preview, "D_PLAYRATE", play_rate)
    reaper.CF_Preview_SetValue(playing_preview, "D_PITCH", pitch)
    reaper.CF_Preview_SetValue(playing_preview, "B_PPITCH", preserve_pitch and 1 or 0)
    reaper.CF_Preview_SetValue(playing_preview, "D_POSITION", cur_pos)
    reaper.CF_Preview_Play(playing_preview)
    is_paused = false
  end
end

local function VAL2DB(x)
  if x < 0.0000000298023223876953125 then
    return -150
  else
    return math.max(-150, math.log(x) * 8.6858896380650365530225783783321)
  end
end

-- dB转线性增益
local function dB_to_gain(db)
  return 10 ^ (db / 20)
end

local function RefreshFont()
  sans_serif = reaper.ImGui_CreateFont('sans-serif', font_size)
  reaper.ImGui_Attach(ctx, sans_serif)
end

local function MarkFontDirty()
  need_refresh_font = true
end

local function GetPhysicalPath(path_or_source)
  if type(path_or_source) == "string" then
    return path_or_source
  elseif type(path_or_source) == "userdata" then
    return reaper.GetMediaSourceFileName(path_or_source, "")
  else
    return nil
  end
end

function InsertSelectedAudioSection(path, sel_start, sel_end, section_offset, move_cursor_to_end)
  -- 保存Arrange视图状态 - 避免滚屏
  reaper.PreventUIRefresh(1) -- 防止UI刷新
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_SAVEVIEW"), 0)

  -- 检查自动交叉淡化状态
  local crossfade_state = reaper.GetToggleCommandStateEx(0, 40041) -- Options: Auto-crossfade media items when editing
  local need_restore = false
  if crossfade_state == 1 then
    reaper.Main_OnCommand(40041, 0) -- 当前激活，先关闭
    need_restore = true
  end

  local before = {}
  for i = 0, reaper.CountMediaItems(0) - 1 do before[reaper.GetMediaItem(0, i)] = true end
  reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
  reaper.InsertMedia(path, 0)
  local new_item = nil
  for i = 0, reaper.CountMediaItems(0) - 1 do
    local item = reaper.GetMediaItem(0, i)
    if not before[item] then new_item = item break end
  end
  if not new_item then
    reaper.ShowMessageBox("Insert Media failed.", "Insert Error", 0)
    if need_restore then reaper.Main_OnCommand(40041, 0) end
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_RESTOREVIEW"), 0)
    reaper.PreventUIRefresh(-1)
    return
  end
  local take = reaper.GetActiveTake(new_item)
  if not take then
    reaper.ShowMessageBox("Take error.", "Insert Error", 0)
    if need_restore then reaper.Main_OnCommand(40041, 0) end
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_RESTOREVIEW"), 0)
    reaper.PreventUIRefresh(-1)
    return
  end

  -- 偏移和长度
  local sel_len = math.abs(sel_end - sel_start)
  local src_offset = math.min(sel_start, sel_end)
  if section_offset then src_offset = src_offset + section_offset end

  reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", src_offset)
  reaper.SetMediaItemInfo_Value(new_item, "D_LENGTH", sel_len)
  local pos = reaper.GetMediaItemInfo_Value(new_item, "D_POSITION")
  -- 是否移动光标到结尾
  if move_cursor_to_end then
    reaper.SetEditCurPos(pos + sel_len, false, false)
  end

  -- 恢复交叉淡化
  if need_restore then reaper.Main_OnCommand(40041, 0) end
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_RESTOREVIEW"), 0)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  return new_item
end

function HelpMarker(desc)
  reaper.ImGui_TextDisabled(ctx, '(?)')
  if reaper.ImGui_BeginItemTooltip(ctx) then
    reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
    reaper.ImGui_Text(ctx, desc)
    reaper.ImGui_PopTextWrapPos(ctx)
    reaper.ImGui_EndTooltip(ctx)
  end
end

-- 旋钮控件，在函数最前面加静态表存储drag偏移
ImGui_Knob_drag_y = ImGui_Knob_drag_y or {}

function ImGui_Knob(ctx, label, value, v_min, v_max, size, default_value)
  local radius = size * 0.5
  local center_x, center_y = reaper.ImGui_GetCursorScreenPos(ctx)
  center_x = center_x + radius
  center_y = center_y + radius

  local ANGLE_MIN = -3 * math.pi / 4
  local ANGLE_MAX =  3 * math.pi / 4
  local t = (value - v_min) / (v_max - v_min)
  local angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t - math.pi/2
  -- 交互
  reaper.ImGui_SetCursorScreenPos(ctx, center_x - radius, center_y - radius)
  reaper.ImGui_InvisibleButton(ctx, label .. "_knob", size, size)
  local active = reaper.ImGui_IsItemActive(ctx)
  local hovered = reaper.ImGui_IsItemHovered(ctx)
  -- 颜色
  local col_idle = 0x1D2F49FF -- 未经过
  local col_hovered = 0x23456DFF -- 悬停
  local col_active = 0x316AADFF -- 拖动
  local col_fill
  if active then
    col_fill = col_active
  elseif hovered then
    col_fill = col_hovered
  else
    col_fill = col_idle
  end
  -- 绘制
  local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
  reaper.ImGui_DrawList_AddCircleFilled(draw_list, center_x, center_y, radius, col_fill)
  local hand_x = center_x + math.cos(angle) * (radius * 0.87)
  local hand_y = center_y + math.sin(angle) * (radius * 0.87)
  reaper.ImGui_DrawList_AddLine(draw_list, center_x, center_y, hand_x, hand_y, 0x3D85E0FF, 2)
  reaper.ImGui_DrawList_AddCircle(draw_list, center_x, center_y, radius, 0x23456DFF, 32, 1)

  local show_label = label and (label ~= "") and (not label:match("^##"))
  if show_label then
    reaper.ImGui_SameLine(ctx) -- 在旋钮右侧显示
    reaper.ImGui_Text(ctx, label:gsub("##.*", "")) -- 只显示"##"前的内容
  end
  -- 交互
  reaper.ImGui_SetCursorScreenPos(ctx, center_x - radius, center_y - radius)
  reaper.ImGui_InvisibleButton(ctx, label .. "_knob", size, size)
  local active = reaper.ImGui_IsItemActive(ctx)
  local hovered = reaper.ImGui_IsItemHovered(ctx)
  local changed = false
  local step
  if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl()) then
    step = (v_max - v_min) / 2000 -- 按住Ctrl超精细
  elseif reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftShift()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightShift()) then
    step = (v_max - v_min) / 1000 -- 按住Shift精细
  else
    step = (v_max - v_min) / 100 -- 默认灵敏度，拖动100像素
  end

  -- 上下拖动改变参数
  if reaper.ImGui_IsItemActivated(ctx) then
    ImGui_Knob_drag_y[label] = { y = select(2, reaper.ImGui_GetMousePos(ctx)), start_value = value }
  elseif active and ImGui_Knob_drag_y[label] then
    local cur_y = select(2, reaper.ImGui_GetMousePos(ctx))
    local delta = ImGui_Knob_drag_y[label].y - cur_y -- 上移为正，下移为负
    local new_value = ImGui_Knob_drag_y[label].start_value + delta * step
    new_value = math.max(v_min, math.min(v_max, new_value))
    if math.abs(new_value - value) > 1e-6 then
      value = new_value
      changed = true
    end
  elseif not active then
    ImGui_Knob_drag_y[label] = nil
  end

  -- 右键单击恢复默认
  if hovered and reaper.ImGui_IsMouseClicked(ctx, 1) then
    value = default_value or v_min
    changed = true
  end
  -- 左键双击恢复默认
  if hovered and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
    value = default_value or v_min
    changed = true
    ImGui_Knob_drag_y[label] = nil -- 重置drag偏移
  end
  return changed, value
end

--------------------------------------------- 波形预览相关函数 ---------------------------------------------

-- 波形峰值采样
function GetWavPeaks(filepath, step, pixel_cnt, start_time, end_time)
  if not IsValidAudioFile(filepath) then
    return
  end

  reaper.PreventUIRefresh(1) -- 防止UI刷新
  local src = reaper.PCM_Source_CreateFromFile(filepath)
  if not src then return end
  local srate = reaper.GetMediaSourceSampleRate(src)
  if not srate or srate == 0 then srate = 44100 end
  local channels = math.min(reaper.GetMediaSourceNumChannels(src), 6)
  local src_len = reaper.GetMediaSourceLength(src)

  -- 支持整段还是窗口
  start_time = start_time or 0
  end_time = end_time or src_len
  start_time = math.max(0, start_time)
  end_time = math.min(src_len, end_time)
  local win_len = end_time - start_time

  local total_samples = math.floor(win_len * srate)
  local samples_per_pixel = math.max(1, math.floor(total_samples / pixel_cnt))

  -- 临时插入 item/take
  local track_idx = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(track_idx, true)
  local track = reaper.GetTrack(0, track_idx)
  local item = reaper.AddMediaItemToTrack(track)
  reaper.SetMediaItemLength(item, src_len, false)
  local take = reaper.AddTakeToMediaItem(item)
  reaper.SetMediaItemTake_Source(take, src)
  local accessor = reaper.CreateTakeAudioAccessor(take)

  local peaks = {}
  for ch = 1, channels do peaks[ch] = {} end
  local buf = reaper.new_array(samples_per_pixel * channels)

  -- 动态计算实际步长
  local function calcAdaptiveStep(read_samples)
    -- read_samples 当前像素对应的采样点数量。例如1秒音频采样率为44100Hz，波形窗口宽度是 1200 Px，那么samples_per_pixel = floor(44100 / 1200) ≈ 36.75，表示每个像素对应 36.75 个采样点
    if read_samples >= 1000 then
      return step -- 使用原始step
    elseif read_samples >= 100 then
      return math.max(1, math.floor(read_samples / 20))
    elseif read_samples >= 10 then
      return 1
    else
      return 1
    end
  end

  for px = 1, pixel_cnt do
    local sample_start = (px - 1) * samples_per_pixel
    local read_samples = math.min(samples_per_pixel, total_samples - sample_start)
    if read_samples <= 0 then
      for ch = 1, channels do peaks[ch][px] = {0, 0} end
    else
      buf.clear()
      local offset = start_time + sample_start / srate
      reaper.GetAudioAccessorSamples(accessor, srate, channels, offset, read_samples, buf)
      local actual_step = calcAdaptiveStep(read_samples)
      for ch = 1, channels do
        local min, max = math.huge, -math.huge
        for i = 0, read_samples - 1, actual_step do
          local v = buf[(i * channels) + ch]
          if v then
            if v < min then min = v end
            if v > max then max = v end
          end
        end
        if min == math.huge or max == -math.huge then
          min, max = 0, 0
        end
        peaks[ch][px] = {min, max}
      end
    end
  end

  -- 清理
  reaper.DestroyAudioAccessor(accessor)
  reaper.DeleteTrackMediaItem(track, item)
  reaper.DeleteTrack(track)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  return peaks, pixel_cnt, src_len, channels
end

function GetPeaksFromTake(take, step, pixel_cnt, start_time, end_time)
  reaper.PreventUIRefresh(1) -- 防止UI刷新
  local src = reaper.GetMediaItemTake_Source(take)
  local srate = reaper.GetMediaSourceSampleRate(src)
  if not srate or srate == 0 then srate = 44100 end
  local channel_count = math.min(reaper.GetMediaSourceNumChannels(src), 6)
  local src_len = reaper.GetMediaSourceLength(src)
  -- 强制读取媒体源完整长度，而不是take修剪区段
  start_time = start_time or 0
  end_time = math.min(end_time or src_len, src_len)
  local win_len = end_time - start_time
  local total_samples = math.floor(win_len * srate)
  local samples_per_pixel = math.max(1, math.floor(total_samples / pixel_cnt))
  local peaks = {}
  for ch = 1, channel_count do peaks[ch] = {} end
  local buf = reaper.new_array(samples_per_pixel * channel_count)

  -- 临时插入 item/take 访问 full source
  local track_idx = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(track_idx, true)
  local track = reaper.GetTrack(0, track_idx)
  local item = reaper.AddMediaItemToTrack(track)
  reaper.SetMediaItemLength(item, src_len, false)
  local tmp_take = reaper.AddTakeToMediaItem(item)
  reaper.SetMediaItemTake_Source(tmp_take, src)
  local accessor = reaper.CreateTakeAudioAccessor(tmp_take)

  -- 动态计算实际步长
  local function calcAdaptiveStep(read_samples)
    if read_samples >= 1000 then
      return step
    elseif read_samples >= 100 then
      return math.max(1, math.floor(read_samples / 20))
    elseif read_samples >= 10 then
      return 1
    else
      return 1
    end
  end

  for px = 1, pixel_cnt do
    local sample_start = (px - 1) * samples_per_pixel
    local read_samples = math.min(samples_per_pixel, total_samples - sample_start)
    if read_samples <= 0 then
      for ch = 1, channel_count do peaks[ch][px] = {0, 0} end
    else
      buf.clear()
      local offset = start_time + sample_start / srate
      reaper.GetAudioAccessorSamples(accessor, srate, channel_count, offset, read_samples, buf)
      local actual_step = calcAdaptiveStep(read_samples)
      for ch = 1, channel_count do
        local min, max = math.huge, -math.huge
        for i = 0, read_samples - 1, actual_step do
          local v = buf[(i * channel_count) + ch]
          if v then
            if v < min then min = v end
            if v > max then max = v end
          end
        end
        if min == math.huge or max == -math.huge then
          min, max = 0, 0
        end
        peaks[ch][px] = {min, max}
      end
    end
  end

  -- 清理
  reaper.DestroyAudioAccessor(accessor)
  reaper.DeleteTrackMediaItem(track, item)
  reaper.DeleteTrack(track)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  return peaks, pixel_cnt, src_len, channel_count
end

function DrawWaveformInImGui(ctx, peaks, img_w, img_h, src_len, channel_count) 
  reaper.ImGui_InvisibleButton(ctx, "##wave", img_w, img_h)
  local min_x, min_y = reaper.ImGui_GetItemRectMin(ctx)
  local max_x, max_y = reaper.ImGui_GetItemRectMax(ctx)
  local drawlist = reaper.ImGui_GetWindowDrawList(ctx)

  if peaks then
    local w = img_w
    local h = img_h
    for ch = 1, channel_count do
      local ch_y = min_y + (ch - 1) * h / channel_count
      local ch_h = h / channel_count
      local y_mid = ch_y + ch_h / 2
      -- 先画一条横线，作为静音参考线
      reaper.ImGui_DrawList_AddLine(drawlist, min_x, y_mid, max_x, y_mid, 0x808004FF, 1.0) -- 波形颜色-中心线 0x525F6FFF, 0x868C82FF 0x80C0FFFF
      -- 再画波形竖线
      for i = 1, w do
        local frac = (i - 1) / (w - 1)
        local idx = math.floor(frac * #peaks[ch]) + 1
        local p = (peaks[ch] and peaks[ch][idx]) or {0, 0}
        local minv = p[1] or 0
        local maxv = p[2] or 0
        local y1 = y_mid - minv * ch_h / 2 * waveform_vertical_zoom
        local y2 = y_mid - maxv * ch_h / 2 * waveform_vertical_zoom

        -- 波形覆盖在中线上
        reaper.ImGui_DrawList_AddLine(drawlist, min_x + i, y1, min_x + i, y2, 0xCCCC06FF, 1.0) -- 波形颜色 0xFFFF08FF, 0xBBE1E9FF 0x96B4BBFF 0x87A2A8FF 0x96A688FF 0x80C0FFFF
      end
    end
  end
end

-- 停止播放预览
local function StopPreview()
  -- 重置峰值
  for i = 1, peak_chans do
    peak_hold[i] = 0
  end
  if playing_preview then
    reaper.CF_Preview_Stop(playing_preview)
    playing_preview = nil
    playing_source = nil
  else
    reaper.CF_Preview_StopAll()
  end
  wf_play_start_time = nil
  wf_play_start_cursor = nil

  -- 强制复位
  -- if last_play_cursor_before_play then
  --   Wave.play_cursor = last_play_cursor_before_play
  -- end
end

-- 从头播放
local function PlayFromStart(info)
  last_play_cursor_before_play = 0
  -- 重置峰值
  for i = 1, peak_chans do
    peak_hold[i] = 0
  end
  StopPreview()
  Wave.play_cursor = 0
  local source
  if collect_mode == COLLECT_MODE_RPP and info and info.path and IsValidAudioFile(info.path) then -- RPP模式下强制用源音频路径
    source = reaper.PCM_Source_CreateFromFile(info.path)
  elseif info and info.take and reaper.ValidatePtr(info.take, "MediaItem_Take*") then
    source = reaper.GetMediaItemTake_Source(info.take)
  elseif info and info.path and IsValidAudioFile(info.path) then
    source = reaper.PCM_Source_CreateFromFile(info.path)
  end
  if source then
    playing_preview = reaper.CF_CreatePreview(source)
    playing_source = source
    if playing_preview then
      if reaper.CF_Preview_SetValue then
        reaper.CF_Preview_SetValue(playing_preview, "B_LOOP", loop_enabled and 1 or 0)
        reaper.CF_Preview_SetValue(playing_preview, "D_VOLUME", volume)
        reaper.CF_Preview_SetValue(playing_preview, "D_PLAYRATE", play_rate)
        reaper.CF_Preview_SetValue(playing_preview, "D_PITCH", pitch)
        reaper.CF_Preview_SetValue(playing_preview, "B_PPITCH", preserve_pitch and 1 or 0)
        reaper.CF_Preview_SetValue(playing_preview, "D_POSITION", 0)
      end
      reaper.CF_Preview_Play(playing_preview)
      wf_play_start_time = os.clock()
      wf_play_start_cursor = 0
    end
    MarkPreviewed(info.path)
    -- 保存最后播放的信息
    last_playing_info = {}
    for k, v in pairs(info) do last_playing_info[k] = v end
    -- 顺序播放新增
    preview_play_len = reaper.GetMediaSourceLength(source) or 0
    playing_path = info.path or ""
  end
end

-- 从光标开始播放
local function PlayFromCursor(info)
  last_play_cursor_before_play = Wave.play_cursor or 0
  -- 重置峰值
  for i = 1, peak_chans do
    peak_hold[i] = 0
  end
  StopPreview()
  local source
  if collect_mode == COLLECT_MODE_RPP and info and info.path and IsValidAudioFile(info.path) then -- RPP模式下强制用源音频路径
    source = reaper.PCM_Source_CreateFromFile(info.path)
  elseif info and info.take and reaper.ValidatePtr(info.take, "MediaItem_Take*") then
    source = reaper.GetMediaItemTake_Source(info.take)
  elseif info and info.path and IsValidAudioFile(info.path) then
    source = reaper.PCM_Source_CreateFromFile(info.path)
  end
  if source then
    playing_preview = reaper.CF_CreatePreview(source)
    playing_source = source
    if playing_preview then
      if reaper.CF_Preview_SetValue then
        reaper.CF_Preview_SetValue(playing_preview, "B_LOOP", loop_enabled and 1 or 0)
        reaper.CF_Preview_SetValue(playing_preview, "D_VOLUME", volume)
        reaper.CF_Preview_SetValue(playing_preview, "D_PLAYRATE", play_rate)
        reaper.CF_Preview_SetValue(playing_preview, "D_PITCH", pitch)
        reaper.CF_Preview_SetValue(playing_preview, "B_PPITCH", preserve_pitch and 1 or 0)
        reaper.CF_Preview_SetValue(playing_preview, "D_POSITION", Wave.play_cursor or 0)
      end
      reaper.CF_Preview_Play(playing_preview)
      wf_play_start_time = os.clock()
      wf_play_start_cursor = Wave.play_cursor or 0
    end
    MarkPreviewed(info.path)
    -- 保存最后播放的信息
    last_playing_info = {}
    for k, v in pairs(info) do last_playing_info[k] = v end
  end
end

-- 绘制时间线
local function DrawTimeLine(ctx, wave, view_start, view_end)
  local y_offset = -9     -- 距离波形底部-9像素
  local tick_long = 20    -- 主刻度高度
  local tick_middle = 10  -- 中间刻度高度
  local tick_secmid = 7   -- 次中间刻度高度
  local tick_short = 3    -- 次刻度高度
  local min_tick_px = 150 -- 两个主刻度最小像素距离

  -- 绘制时间线基础线
  local min_x, min_y = reaper.ImGui_GetItemRectMin(ctx)
  local max_x, max_y = reaper.ImGui_GetItemRectMax(ctx)
  local x0, y0 = min_x, max_y - y_offset
  local x1 = max_x
  local drawlist = reaper.ImGui_GetWindowDrawList(ctx)

  -- 设置基础线颜色
  reaper.ImGui_DrawList_AddLine(drawlist, x0, y0, x1, y0, 0x3F3F48FF, 1.0)

  -- 智能自适应主刻度数
  local avail_w = max_x - min_x
  local target_ticks_visible = math.max(1, math.floor(avail_w / min_tick_px + 0.5))

  -- 计算自适应的主刻度间隔
  local view_len = view_end - view_start
  if view_len <= 0 then view_len = 1 end -- 防止为0
  local pixels_per_sec = wave.w / view_len
  local tick_steps = {0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 30, 60, 120, 300}
  local tick_step = view_len / target_ticks_visible
  for _, v in ipairs(tick_steps) do
    if v * pixels_per_sec >= min_tick_px then
      tick_step = v
      break
    end
  end
  if not tick_step or tick_step <= 0 or tick_step ~= tick_step then
    tick_step = 1
  end

  -- 绘制主刻度和时间标签
  local start_tick = math.ceil(view_start / tick_step) * tick_step
  for t = start_tick, view_end, tick_step do
    local frac = (t - view_start) / view_len
    local x = min_x + frac * (max_x - min_x)
    -- 主刻度线
    reaper.ImGui_DrawList_AddLine(drawlist, x, y0, x, y0 + tick_long, timeline_default_color, 1.0)
    -- 时间标签
    local text = reaper.format_timestr(t or 0, "")
    -- 计算文字高度
    local text = reaper.format_timestr(t or 0, "")
    local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, text)
    local text_y = y0 + tick_long - text_h + 0  -- 最后一个值是上下位置细调
    reaper.ImGui_DrawList_AddText(drawlist, x + 4, text_y, timeline_default_color, text)
    -- reaper.ImGui_DrawList_AddText(drawlist, x + 2, y0 + tick_long + 1, 0xE6ECFFFF, reaper.format_timestr(t or 0, ""))
  end

  -- 绘制次刻度
  local sub_divs = 20 -- 主刻度之间分20份
  local sub_tick_step = tick_step / sub_divs

  if sub_tick_step >= 0.00001 then
    local sub_start_tick = math.ceil(view_start / sub_tick_step) * sub_tick_step
    for t = sub_start_tick, view_end, sub_tick_step do
      -- 判断是不是主刻度
      local is_on_main_tick = math.abs((t / tick_step) - math.floor(t / tick_step + 0.5)) < 0.01
      if not is_on_main_tick then
        -- 计算本 tick 在主刻度间的第几根
        local main_tick_index = math.floor((t - start_tick) / tick_step)
        local sub_index = math.floor(((t - (start_tick + main_tick_index * tick_step)) / sub_tick_step) + 0.5)
        local frac = (t - view_start) / view_len
        local x = min_x + frac * (max_x - min_x)
        -- 主->中->次中->短->中->次中->主...
        if sub_index == 10 then -- 中间刻度线
          reaper.ImGui_DrawList_AddLine(drawlist, x, y0, x, y0 + tick_middle, timeline_default_color, 1.0)
        elseif sub_index == 5 or sub_index == 15 then
          -- 次中间刻度线
          reaper.ImGui_DrawList_AddLine(drawlist, x, y0, x, y0 + tick_secmid, timeline_default_color, 1.0)
        else
          -- 次刻度
          reaper.ImGui_DrawList_AddLine(drawlist, x, y0, x, y0 + tick_short, timeline_default_color, 1.0)
        end
      end
    end
  end
end

-- 智能波形采集入口，info 必须包含 .path 字段
function GetPeaksForInfo(info, wf_step, pixel_cnt, start_time, end_time)
  -- 优先用已有 item/take 的 accessor
  if info.take and reaper.ValidatePtr(info.take, "MediaItem_Take*") then
    return GetPeaksFromTake(info.take, wf_step, pixel_cnt, start_time, end_time)
  else
    -- 没有 take，用 PCM_Source_CreateFromFile 的方式
    return GetWavPeaks(info.path, wf_step, pixel_cnt, start_time, end_time)
  end
end

-- 禁用自动交叉淡化
function WithAutoCrossfadeDisabled(fn)
  local crossfade_state = reaper.GetToggleCommandStateEx(0, 40041) -- Options: Auto-crossfade media items when editing
  local need_restore = false
  if crossfade_state == 1 then
    reaper.Main_OnCommand(40041, 0)
    need_restore = true
  end
  fn()
  if need_restore then
    reaper.Main_OnCommand(40041, 0)
  end
end

-- 鼠标框选相关变量
local pending_clear_selection = pending_clear_selection or false
local function has_selection()
  return select_start_time and select_end_time and math.abs(select_end_time - select_start_time) > 0.01
end
local function mouse_in_selection()
  if not mouse_time then return false end
  if not select_start_time or not select_end_time then return false end
  local sel_min = math.min(select_start_time, select_end_time)
  local sel_max = math.max(select_start_time, select_end_time)
  return mouse_time >= sel_min and mouse_time <= sel_max
end

--------------------------------------------- 树状文件夹 ---------------------------------------------

local sep = package.config:sub(1,1)
local audio_types = { WAVE=true, MP3=true, FLAC=true, OGG=true, AIFF=true, APE=true }
tree_state = tree_state or { cur_path = '', sel_audio = '' }
local tree_open = {}
local dir_cache = {} -- path -> {dirs=..., audios=..., ok=...}
local drive_cache = nil
local drives_loaded = false
local audio_file_cache = {}
local last_dir = ""
local drive_name_map = {} -- 盘符到卷标的映射
local need_load_drives = false
local is_loading_drives = false
folder_shortcuts = folder_shortcuts or {} -- 选择文件夹快捷方式

left_ratio = tonumber(reaper.GetExtState(EXT_SECTION, "left_ratio")) or 0.15 -- 启动时读取上次保存的
splitter_drag = splitter_drag or false
splitter_drag_offset = splitter_drag_offset or 0

local collect_mode_labels = {
  {label = "Source Media", value = COLLECT_MODE_RPP},
  {label = "Media Items", value = COLLECT_MODE_ALL_ITEMS},
  {label = "Project Directory", value = COLLECT_MODE_DIR},
  {label = "Item Assets", value = COLLECT_MODE_ITEMS},
}
local selected_index = nil

function GetAudioFilesFromDirCached(dir_path)
  if not audio_file_cache[dir_path] then
    local _, files_idx = CollectFromDirectory(dir_path)
    audio_file_cache[dir_path] = files_idx
  end
  return audio_file_cache[dir_path]
end

function RefreshAudioDirCache(dir_path)
  audio_file_cache[dir_path] = nil
end

-- 获取指定目录下所有有效音频文件
function CollectFromDirectory(dir_path)
  local files, files_idx = {}, {}
  local valid_exts = {wav=true, mp3=true, flac=true, ogg=true, aiff=true, ape=true, wv=true}
  if not dir_path or dir_path == "" then return files, files_idx end
  local i = 0
  while true do
    local file = reaper.EnumerateFiles(dir_path, i)
    if not file then break end
    local ext = file:match("^.+%.([^.]+)$")
    if ext and valid_exts[ext:lower()] and ext:lower() ~= "rpp" then
      local fullpath = dir_path .. sep .. file
      if IsValidAudioFile(fullpath) and not files[fullpath] then
        local info = { path = fullpath, filename = file }
        -- 获取文件大小
        local f = io.open(fullpath, "rb")
        if f then
          f:seek("end")
          info.size = f:seek()
          f:close()
        else
          info.size = 0
        end

        local src = reaper.PCM_Source_CreateFromFile(fullpath)
        if src then
          info.source = src
          info.type = reaper.GetMediaSourceType(src, "")
          info.length = reaper.GetMediaSourceLength(src)
          info.samplerate = reaper.GetMediaSourceSampleRate(src)
          info.channels = reaper.GetMediaSourceNumChannels(src)
          info.bits = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(src) or "-"
          local _, genre = reaper.GetMediaFileMetadata(src, "XMP:dm/genre")
          local _, comment = reaper.GetMediaFileMetadata(src, "XMP:dm/logComment")
          local _, description = reaper.GetMediaFileMetadata(src, "BWF:Description")
          local _, orig_date  = reaper.GetMediaFileMetadata(src, "BWF:OriginationDate")
          info.genre = genre or ""
          info.comment = comment or ""
          info.description = description or ""
          info.bwf_orig_date = orig_date or ""
        end
        files[fullpath] = info
        files_idx[#files_idx+1] = info
      end
    end
    i = i + 1
  end

  return files, files_idx
end

local function get_drives()
  if drive_cache and drives_loaded then return drive_cache end
  local drives = {}
  drive_name_map = {} -- 重置映射
  if reaper.GetOS():find('Win') then
    local handle = io.popen('wmic logicaldisk get name,volumename')
    if handle then
      for line in handle:lines() do
        local name, volumename = line:match('^%s*([A-Z]:)%s*(.-)%s*$')
        if name then
          local drv = name .. '\\'
          table.insert(drives, drv)
          if volumename and volumename ~= "" then
            drive_name_map[drv] = volumename
          else
            drive_name_map[drv] = "" -- 无卷标也要填表
          end
        end
      end
      handle:close()
    end
  else
    table.insert(drives, '/')
  end
  table.sort(drives)
  drive_cache = drives
  drives_loaded = true
  return drives
end

-- 获取目录下所有子文件夹和支持类型的音频文件
local function list_dir(path)
  local dirs, audios = {}, {}
  local ok = true
  local i = 0
  while true do
    local file = reaper.EnumerateFiles(path, i)
    if not file then break end
    local full = path .. ((path:sub(-1)==sep) and '' or sep) .. file
    local ext = file:match('%.([^.]+)$')
    if ext and audio_types[ext:upper()] then
      local src = reaper.PCM_Source_CreateFromFile(full)
      if src then
        local typ = reaper.GetMediaSourceType(src, '')
        reaper.PCM_Source_Destroy(src)
        if typ and audio_types[typ:upper()] then
          table.insert(audios, file)
        end
      end
    end
    i = i + 1
  end

  -- 子文件夹
  local j = 0
  while true do
    local subdir = reaper.EnumerateSubdirectories(path, j)
    if not subdir then break end
    table.insert(dirs, subdir)
    j = j + 1
  end

  table.sort(dirs)
  table.sort(audios)
  return dirs, audios, ok
end

-- 树状目录
local function draw_tree(name, path)
  local show_name = name
  if drive_name_map and drive_name_map[path] and drive_name_map[path] ~= "" then
    show_name = name .. " (" .. drive_name_map[path] .. ")"
  end

  local open = tree_open[path]
  local flag = open and reaper.ImGui_TreeNodeFlags_DefaultOpen() or 0
  local highlight = (tree_state.cur_path == path) and reaper.ImGui_TreeNodeFlags_Selected() or 0
  local node_open = reaper.ImGui_TreeNode(ctx, show_name .. "##" .. path, flag | highlight)
  -- 只要点击树节点，不管当前什么模式，都切换到tree模式
  if reaper.ImGui_IsItemClicked(ctx, 0) then
    if collect_mode ~= COLLECT_MODE_TREE then
      collect_mode = COLLECT_MODE_TREE
      files_idx_cache = nil
      CollectFiles()
    end
    tree_state.cur_path = path
    if collect_mode == COLLECT_MODE_TREE then
      files_idx_cache = GetAudioFilesFromDirCached(path)
      selected_row = nil
    end
  end

  if node_open then
    if not dir_cache[path] then
      local dirs, audios, ok = list_dir(path)
      dir_cache[path] = {dirs=dirs, audios=audios, ok=ok}
    end
    local cache = dir_cache[path] or {dirs={}, audios={}, ok=true}
    for _, sub in ipairs(cache.dirs) do
      draw_tree(sub, path .. sep .. sub)
    end
    reaper.ImGui_TreePop(ctx)
    tree_open[path] = true
  else
    tree_open[path] = false
  end
end

-- 绘制快捷方式
local function draw_shortcut_tree(sc, base_path)
  local shortcut_name = sc.name or sc.path
  local show_name = shortcut_name
  local path = sc.path
  local open = tree_open[path]
  local highlight = (collect_mode == COLLECT_MODE_SHORTCUT and tree_state.cur_path == path) and reaper.ImGui_TreeNodeFlags_Selected() or 0 -- 去掉 collect_mode == COLLECT_MODE_SHORTCUT 则保持高亮
  local node_open = reaper.ImGui_TreeNode(ctx, show_name .. "##shortcut_" .. path, highlight)
  if reaper.ImGui_IsItemClicked(ctx, 0) then
    tree_state.cur_path = path
    collect_mode = COLLECT_MODE_SHORTCUT
    files_idx_cache = GetAudioFilesFromDirCached(path)
    selected_row = nil
  end

  -- 右键菜单
  local remove_this = false
  if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
    reaper.ImGui_OpenPopup(ctx, "ShortcutMenu_" .. path)
  end
  if reaper.ImGui_BeginPopup(ctx, "ShortcutMenu_" .. path) then
    -- 只在顶级快捷方式节点支持重命名
    local is_root_shortcut = false
    for _, v in ipairs(folder_shortcuts) do
      if v.path == sc.path then
        is_root_shortcut = true
        break
      end
    end
    if is_root_shortcut then
      if reaper.ImGui_MenuItem(ctx, "Rename") then
        local ret, newname = reaper.GetUserInputs("Rename Shortcut", 1, "New Name:,extrawidth=200", sc.name)
        if ret and newname and newname ~= "" then
          sc.name = newname
          SaveFolderShortcuts()
        end
      end
    end
    if reaper.ImGui_MenuItem(ctx, "Show in Explorer/Finder") then
      if sc.path and sc.path ~= "" then
        reaper.CF_ShellExecute(sc.path)
      end
    end
    if is_root_shortcut then
      if reaper.ImGui_MenuItem(ctx, "Remove") then
        remove_this = true
      end
    end
    reaper.ImGui_EndPopup(ctx)
  end

  -- 递归绘制子文件夹
  if node_open then
    if not dir_cache[path] then
      local dirs, audios, ok = list_dir(path)
      dir_cache[path] = {dirs=dirs, audios=audios, ok=ok}
    end
    local cache = dir_cache[path] or {dirs={}, audios={}, ok=true}
    for _, sub in ipairs(cache.dirs) do
      draw_shortcut_tree({name=sub, path=path .. sep .. sub}, path)
    end
    reaper.ImGui_TreePop(ctx)
    tree_open[path] = true
  else
    tree_open[path] = false
  end

  if remove_this then
    for idx, v in ipairs(folder_shortcuts) do
      if v.path == sc.path then
        table.remove(folder_shortcuts, idx)
        SaveFolderShortcuts()
        break
      end
    end
  end
end

--------------------------------------------- 自定义文件夹节点 ---------------------------------------------

local EXT_KEY_CUSTOM_FOLDERS = "CustomFolders"
local EXT_KEY_CUSTOM_CONTENT = "CustomFoldersContent"
custom_folders = custom_folders or {} -- { "monster", "bgm", ... }
custom_folders_content = custom_folders_content or {} -- { ["monster"] = { path1, path2 }, ... }

function SaveCustomFolders()
  local segments = {}
  for _, folder in ipairs(custom_folders) do
    local exist = {}
    local paths = {}
    for _, v in ipairs(custom_folders_content[folder] or {}) do
      if type(v) == "string" and v ~= "" and not exist[v] then
        table.insert(paths, v)
        exist[v] = true
      end
    end
    if #paths > 0 then
      table.insert(segments, folder .. "|" .. table.concat(paths, ";"))
    end
  end
  local plain = table.concat(segments, "||")
  local encoded = reaper.NF_Base64_Encode(plain, true)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_CUSTOM_CONTENT, encoded, true)
end

function split_by_delimiter(str, delimiter)
  local result = {}
  local from = 1
  local delim_from, delim_to = string.find(str, delimiter, from, true)
  while delim_from do
    table.insert(result, string.sub(str, from, delim_from - 1))
    from = delim_to + 1
    delim_from, delim_to = string.find(str, delimiter, from, true)
  end
  if from <= #str then
    table.insert(result, string.sub(str, from))
  end
  return result
end

function LoadCustomFolders()
  local content_str = reaper.GetExtState(EXT_SECTION, EXT_KEY_CUSTOM_CONTENT)
  local decoded = ""
  if content_str and content_str ~= "" then
    local ret, dec = reaper.NF_Base64_Decode(content_str)
    if ret and dec and dec ~= "" then
      decoded = dec
    end
  end
  local contents = {}
  local folders = {}
  if decoded ~= "" then
    local segments = split_by_delimiter(decoded, "||")
    for _, segment in ipairs(segments) do
      local folder, items = segment:match("^([^|]+)|(.+)$")
      if folder then
        table.insert(folders, folder)
        local exist = {}
        local paths = {}
        for path in items:gmatch("[^;]+") do
          if path ~= "" and not exist[path] then
            table.insert(paths, path)
            exist[path] = true
          end
        end
        contents[folder] = paths
      end
    end
  end
  custom_folders = folders
  custom_folders_content = contents
end

-- 清除自定义文件夹内容
function clear_custom_folders_content_key()
  local extstate_ini = reaper.get_ini_file():gsub("reaper%.ini$", "reaper-extstate.ini")
  local file = io.open(extstate_ini, "r")
  if not file then
    reaper.MB("无法打开 reaper-extstate.ini 文件", "错误", 0)
    return
  end
  local lines = {}
  for line in file:lines() do
    if not line:match("^CustomFoldersContent=") then
      table.insert(lines, line)
    end
  end
  file:close()
  local filew = io.open(extstate_ini, "w+")
  if not filew then
    reaper.MB("无法写入 reaper-extstate.ini 文件", "错误", 0)
    return
  end
  for _, l in ipairs(lines) do
    filew:write(l, "\n")
  end
  filew:close()
end

function GetCustomGroupsForPath(path)
  local groups = {}
  for folder, paths in pairs(custom_folders_content or {}) do
    for _, p in ipairs(paths) do
      if p == path then
        table.insert(groups, folder)
        break
      end
    end
  end
  return table.concat(groups, ", ")
end

function ShowGroupMenu(info)
  -- 获取所有 group 名称
  for _, group_name in ipairs(custom_folders or {}) do
    local in_group = false
    for _, path in ipairs(custom_folders_content[group_name] or {}) do
      if path == info.path then
        in_group = true
        break
      end
    end
    -- 显示菜单项，已属于则带勾
    if reaper.ImGui_MenuItem(ctx, group_name, nil, in_group) then
      if in_group then
        -- 如果已属于，点击则移除
        for i, p in ipairs(custom_folders_content[group_name]) do
          if p == info.path then
            table.remove(custom_folders_content[group_name], i)
            break
          end
        end
      else
        -- 如果未属于，点击则加入
        table.insert(custom_folders_content[group_name], info.path)
      end
      SaveCustomFolders()
    end
  end
  -- 菜单底部提供新建分组功能
  reaper.ImGui_Separator(ctx)
  if reaper.ImGui_MenuItem(ctx, "Create Group...") then
    local ret, name = reaper.GetUserInputs("Create Group", 1, "Group Name:,extrawidth=200", "")
    if ret and name and name ~= "" then
      table.insert(custom_folders, name)
      custom_folders_content[name] = {}
      table.insert(custom_folders_content[name], info.path)
      SaveCustomFolders()
    end
  end
end

-- 启动时加载自定义文件夹
LoadCustomFolders()

--------------------------------------------- 高级文件夹节点 ---------------------------------------------

local EXT_KEY_ADVANCED_FOLDERS = "AdvancedFolders"
local EXT_KEY_ADVANCED_ROOT = "AdvancedFoldersRoot"
advanced_folders = advanced_folders or {}           -- [id] = {id=, name=, parent=, children={}, files={}}
root_advanced_folders = root_advanced_folders or {} -- 存根节点id的数组

function sanitize(str)
  return (str or ""):gsub("[\r\n]", "")
end

function parse_line(line)
  local parts = {}
  for part in line:gmatch("([^|]*)") do
    table.insert(parts, part)
    if #parts >= 5 then break end
  end
  -- 不足 5 段的补 ""
  for i = #parts+1, 5 do parts[i] = "" end
  return parts[1], parts[2], parts[3], parts[4], parts[5]
end

function SaveAdvancedFolders()
  local lines = {}
  for id, node in pairs(advanced_folders) do
    local cs = table.concat(node.children or {}, ",")
    local fs = table.concat(node.files    or {}, ",")
    local ps = node.parent or ""
    local line = string.format("%s|%s|%s|%s|%s",
      sanitize(id), sanitize(node.name), sanitize(ps),
      sanitize(cs), sanitize(fs)
    )
    table.insert(lines, line)
  end
  local plain = table.concat(lines, "\n")
  local enc = reaper.NF_Base64_Encode(plain, 0):gsub("[\r\n]", "")
  reaper.SetExtState(EXT_SECTION, EXT_KEY_ADVANCED_FOLDERS, enc, true)
  local root_csv = table.concat(root_advanced_folders, ",")
  reaper.SetExtState(EXT_SECTION, EXT_KEY_ADVANCED_ROOT, root_csv, true)
end

function LoadAdvancedFolders()
  advanced_folders, root_advanced_folders = {}, {}
  -- 读 Root
  local rootstr = reaper.GetExtState(EXT_SECTION, EXT_KEY_ADVANCED_ROOT)
  if rootstr and rootstr~="" then
    for id in rootstr:gmatch("[^,]+") do
      table.insert(root_advanced_folders, id)
    end
  end
  -- 读主数据
  local enc = reaper.GetExtState(EXT_SECTION, EXT_KEY_ADVANCED_FOLDERS)
  if not enc or enc=="" then return end
  enc = enc:gsub("[\r\n]", "")
  local ok, dec = reaper.NF_Base64_Decode(enc)
  if not ok or not dec or dec=="" then return end
  local idx = 0
  for line in dec:gmatch("([^\n]+)") do
    idx = idx + 1
    local id, name, parent, cs, fs = parse_line(line)
    if id and id ~= "" then
      local node = {
        id       = id,
        name     = name,
        parent   = (parent~="" and parent or nil),
        children = {},
        files    = {}
      }
      for cid in cs:gmatch("[^,]+") do table.insert(node.children, cid) end
      for f   in fs:gmatch("[^,]+") do table.insert(node.files,    f)   end
      advanced_folders[id] = node
    else
      -- 跳过空 id 行\n
    end
  end
  -- 清理无效 root 的代码
  for i = #root_advanced_folders, 1, -1 do
    if not advanced_folders[root_advanced_folders[i]] then
      table.remove(root_advanced_folders, i)
    end
  end
  SaveAdvancedFolders()
end

function new_guid()
  return (reaper.genGuid() or ""):gsub("[{}]", "")
end

function draw_advanced_folder_node(id, selected_id)
  local node = advanced_folders[id]
  if not node then return end
  -- 仅在 COLLECT_MODE_ADVANCEDFOLDER 模式下高亮
  local flags = reaper.ImGui_TreeNodeFlags_OpenOnArrow()
  if collect_mode == COLLECT_MODE_ADVANCEDFOLDER and selected_id == id then
    flags = flags | reaper.ImGui_TreeNodeFlags_Selected()
  end
  local node_open = reaper.ImGui_TreeNode(ctx, node.name .. "##" .. id, flags)
  -- 选中
  if reaper.ImGui_IsItemClicked(ctx, 0) then
    tree_state.cur_advanced_folder = id
    collect_mode = COLLECT_MODE_ADVANCEDFOLDER
    files_idx_cache = nil
    CollectFiles()
  end
  -- 右键菜单
  if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
    reaper.ImGui_OpenPopup(ctx, "AdvancedFolderMenu_" .. id)
  end
  if reaper.ImGui_BeginPopup(ctx, "AdvancedFolderMenu_" .. id) then
    if reaper.ImGui_MenuItem(ctx, "Rename") then
      local ret, newname = reaper.GetUserInputs("Rename Collection", 1, "New Name:,extrawidth=200", node.name)
      if ret and newname and newname ~= "" then
        node.name = newname
        SaveAdvancedFolders()
      end
    end
    if reaper.ImGui_MenuItem(ctx, "Remove") then
      if node.parent then
        local parent_node = advanced_folders[node.parent]
        for i,v in ipairs(parent_node.children) do if v==id then table.remove(parent_node.children, i) break end end
      else
        for i,v in ipairs(root_advanced_folders) do if v==id then table.remove(root_advanced_folders, i) break end end
      end
      -- 递归删除所有子节点
      local function del_node(cid)
        for _,ch in ipairs(advanced_folders[cid].children) do del_node(ch) end
        advanced_folders[cid]=nil
      end
      del_node(id)
      SaveAdvancedFolders()
    end
    if reaper.ImGui_MenuItem(ctx, "Add Subfolder") then
      local ret, name = reaper.GetUserInputs("New Subfolder", 1, "Name:,extrawidth=200", "")
      if ret and name and name ~= "" then
        local new_id = new_guid()
        advanced_folders[new_id] = { id = new_id, name = name, parent = id, children = {}, files = {} }
        table.insert(node.children, new_id)
        SaveAdvancedFolders()
      end
    end

    reaper.ImGui_EndPopup(ctx)
  end
  -- 拖拽文件到高级文件夹中
  if reaper.ImGui_BeginDragDropTarget(ctx) then
    if reaper.ImGui_AcceptDragDropPayload(ctx, "AUDIO_PATH") then
      local retval, dtype, payload = reaper.ImGui_GetDragDropPayload(ctx)
      if retval and dtype == "AUDIO_PATH" and type(payload) == "string" and payload ~= "" then
        local drag_path = payload
        node.files = node.files or {}
        local exists = false
        for _, p in ipairs(node.files) do
          if p == drag_path then exists = true break end
        end
        if not exists then
          table.insert(node.files, drag_path)
          SaveAdvancedFolders()
          if collect_mode == COLLECT_MODE_ADVANCEDFOLDER and tree_state.cur_advanced_folder == id then
            CollectFiles()
          end
        end
      end
    end
    reaper.ImGui_EndDragDropTarget(ctx)
  end
  -- 递归子节点
  if node_open then
    for _, cid in ipairs(node.children) do
      draw_advanced_folder_node(cid, selected_id)
    end
    reaper.ImGui_TreePop(ctx)
  end
end

-- 启动时加载高级自定义文件夹
LoadAdvancedFolders()

function loop()
  -- 首次使用时收集音频文件
  if not files_idx_cache then
    CollectFiles()
  end
  if need_refresh_font then
    sans_serif = reaper.ImGui_CreateFont('sans-serif', font_size)
    reaper.ImGui_Attach(ctx, sans_serif)
    need_refresh_font = false
  end
  reaper.ImGui_PushFont(ctx, sans_serif)
  reaper.ImGui_SetNextWindowBgAlpha(ctx, bg_alpha) -- 背景不透明度

  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 6.0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(),  4.0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowTitleAlign(), 0.5, 0.5)

  local visible, open = reaper.ImGui_Begin(ctx, SCRIPT_NAME, true)
  if visible then
    -- 圆角处理: 弹出菜单、子区域、滚动条、滑块
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_PopupRounding(),     4.0) -- 弹窗
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarRounding(), 4.0) -- 滚动条
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabRounding(),      4.0) -- 滑块
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(),     0.0) -- 子窗口
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(),    4.0) -- 主窗口
    local ix, iy = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), ix, iy * 2.0)

    -- 过滤器控件居中
    reaper.ImGui_Dummy(ctx, 1, 1) -- 控件上方 + 1px 间距
    local region_w = reaper.ImGui_GetContentRegionAvail(ctx)
    local label_w = reaper.ImGui_CalcTextSize(ctx, "Filter:")
    local filter_w = 800 -- 输入框宽度
    local button_w = reaper.ImGui_CalcTextSize(ctx, "Clear") + 24 -- 24为按钮额外padding
    local total_w = label_w + filter_w + button_w  + 16 -- 16为间隔
    reaper.ImGui_SetCursorPosX(ctx, (region_w - total_w) / 2)

    -- 过滤器
    reaper.ImGui_Text(ctx, "Filter:")
    reaper.ImGui_SameLine(ctx)
    if not filename_filter then
      filename_filter = reaper.ImGui_CreateTextFilter()
      reaper.ImGui_Attach(ctx, filename_filter)
    end
    reaper.ImGui_SetNextItemWidth(ctx, filter_w)
    reaper.ImGui_TextFilter_Draw(filename_filter, ctx, "##FilterQWERT")
    -- 清空过滤器内容
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Clear") then
      reaper.ImGui_TextFilter_Set(filename_filter, "")
    end
    -- 刷新按钮
    reaper.ImGui_SameLine(ctx, nil, 10)
    if reaper.ImGui_Button(ctx, "Rescan") then
      CollectFiles()
    end
    if reaper.ImGui_IsItemHovered(ctx) then
      reaper.ImGui_BeginTooltip(ctx)
      reaper.ImGui_Text(ctx, "F5 will rescan and refresh the audio file list.")
      reaper.ImGui_EndTooltip(ctx)
    end
    -- F5
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F5()) then
      CollectFiles()
    end
    reaper.ImGui_Dummy(ctx, 1, 1) -- 控件下方 + 1px 间距

    -- 自动缩放音频表格
    local line_h = reaper.ImGui_GetTextLineHeight(ctx)
    local avail_x, avail_y = reaper.ImGui_GetContentRegionAvail(ctx)
    -- 减去标题栏高度和底部间距。减去播放控件+波形预览+时间线9+进度条+地址栏的高度=228 +加分割条的厚度3=240
    local child_h = math.max(10, avail_y - line_h - 240 - img_h_offset)
    if child_h < 10 then child_h = 10 end -- 最小高度保护(需要使用 if reaper.ImGui_BeginChild 才有效)
    
    local splitter_w = 3 -- 分割条宽度
    local min_left = math.floor(avail_x * 0.005) -- 最小左侧宽度占比
    local max_left = math.floor(avail_x * 0.5) -- 最大左侧宽度占比

    -- 用 left_ratio 实时计算宽度
    local left_w = math.floor(avail_x * left_ratio)
    local right_w = avail_x - left_w - splitter_w

    -- 左侧树状目录(此处需要使用 if 才有效，否则报错)
    if reaper.ImGui_BeginChild(ctx, "##left", left_w, child_h, 0, reaper.ImGui_WindowFlags_HorizontalScrollbar()) then
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), normal_text) -- 文本颜色
      
      -- 渲染单选列表
      -- local sel_mode = reaper.ImGui_TreeNode(ctx, "Project Collection", reaper.ImGui_TreeNodeFlags_DefaultOpen())
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), transparent)
      local sel_mode = reaper.ImGui_CollapsingHeader(ctx, "Project Collection") -- , nil, reaper.ImGui_TreeNodeFlags_DefaultOpen())
      if sel_mode then
        reaper.ImGui_Indent(ctx, 7) -- 手动缩进16像素
        for i, v in ipairs(collect_mode_labels) do
          local selected = (collect_mode == v.value)
          reaper.ImGui_AlignTextToFramePadding(ctx)
          if reaper.ImGui_Selectable(ctx, v.label, selected) then
            collect_mode = v.value
            selected_index = i
            tree_open = {} -- 切到非tree时收起tree
            files_idx_cache = nil
            CollectFiles()
          end
        end
        reaper.ImGui_Unindent(ctx, 7)
        --reaper.ImGui_TreePop(ctx)
      end

      -- Tree模式特殊处理（折叠节点）
      local flag = (collect_mode == COLLECT_MODE_TREE) and reaper.ImGui_TreeNodeFlags_DefaultOpen() or 0
      -- local tree_expanded = reaper.ImGui_TreeNode(ctx, "This Computer", flag)
      local tree_expanded = reaper.ImGui_CollapsingHeader(ctx, "This Computer") -- , nil, flag)
      if tree_expanded then
        reaper.ImGui_Indent(ctx, 7) -- 手动缩进16像素
        if not drives_loaded then
          reaper.ImGui_Text(ctx, "Loading drives, please wait...")
          if not need_load_drives then
            need_load_drives = true
          end
        else
          for _, drv in ipairs(drive_cache or {}) do
            draw_tree(drv, drv)
          end
        end
        reaper.ImGui_Unindent(ctx, 7)
        --reaper.ImGui_TreePop(ctx)
      end

      -- 文件夹快捷方式节点
      -- local create_folder_open = reaper.ImGui_TreeNode(ctx, "Folder Shortcuts", reaper.ImGui_TreeNodeFlags_DefaultOpen())
      local create_folder_open = reaper.ImGui_CollapsingHeader(ctx, "Folder Shortcuts") -- , nil, reaper.ImGui_TreeNodeFlags_DefaultOpen())
      if create_folder_open then
        reaper.ImGui_Indent(ctx, 7) -- 手动缩进16像素
        for i = 1, #folder_shortcuts do
          draw_shortcut_tree(folder_shortcuts[i])
        end
        -- 添加新快捷方式按钮
        if reaper.ImGui_Button(ctx, "Create Shortcut##add_folder_shortcut") then
          local rv, folder = reaper.JS_Dialog_BrowseForFolder("Choose folder to add shortcut:", "")
          if rv == 1 and folder and folder ~= "" then
            local exists = false
            for _, v in ipairs(folder_shortcuts) do
              if v.path == folder then exists = true break end
            end
            if not exists then
              table.insert(folder_shortcuts, { name = folder:match("[^/\\]+$"), path = folder })
              SaveFolderShortcuts()
            end
          end
        end
        reaper.ImGui_Unindent(ctx, 7)
        --reaper.ImGui_TreePop(ctx)
      end

      -- 高级文件夹节点 Collections
      local flags = reaper.ImGui_TreeNodeFlags_DefaultOpen()
      -- local advanced_folder_open = reaper.ImGui_TreeNode(ctx, "Collections", flags)
      local advanced_folder_open = reaper.ImGui_CollapsingHeader(ctx, "Collections") --, nil, flags)
      if advanced_folder_open then
        reaper.ImGui_Indent(ctx, 7) -- 手动缩进16像素
        for _, id in ipairs(root_advanced_folders) do
          local node = advanced_folders[id]
          if node then
            draw_advanced_folder_node(id, tree_state.cur_advanced_folder)
          else
            -- 如果节点在 advanced_folders 中找不到，输出警告
            -- reaper.ShowConsoleMsg("root_advanced_folders中的节点id="..id.."未在advanced_folders表找到\n")
          end
        end
        if reaper.ImGui_Button(ctx, "Create Collection##add_adv_folder") then
          local ret, name = reaper.GetUserInputs("Create Collection", 1, "Collection Name:,extrawidth=200", "")
          if ret and name and name ~= "" then
            local new_id = new_guid()
            advanced_folders[new_id] = { id = new_id, name = name, parent = nil, children = {}, files = {} } -- 写入 advanced_folders 表
            table.insert(root_advanced_folders, new_id)
            SaveAdvancedFolders()
          end
        end
        reaper.ImGui_Unindent(ctx, 7)
        --reaper.ImGui_TreePop(ctx)
      end

      -- 自定义文件夹节点 Group
      -- local custom_folder_open = reaper.ImGui_TreeNode(ctx, "Group##group", reaper.ImGui_TreeNodeFlags_DefaultOpen())
      local custom_folder_open = reaper.ImGui_CollapsingHeader(ctx, "Group##group") -- , nil, reaper.ImGui_TreeNodeFlags_DefaultOpen())
      reaper.ImGui_Indent(ctx, 7) -- 手动缩进16像素
      if custom_folder_open then
        for i, folder in ipairs(custom_folders) do
          local is_selected = (collect_mode == COLLECT_MODE_CUSTOMFOLDER and tree_state.cur_custom_folder == folder)
          if reaper.ImGui_Selectable(ctx, folder, is_selected) then
            collect_mode = COLLECT_MODE_CUSTOMFOLDER
            tree_state.cur_custom_folder = folder
            files_idx_cache = nil
            CollectFiles()
          end
          -- 右键菜单
          if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
            reaper.ImGui_OpenPopup(ctx, "CustomFolderMenu_" .. folder)
          end
          if reaper.ImGui_BeginPopup(ctx, "CustomFolderMenu_" .. folder) then
            if reaper.ImGui_MenuItem(ctx, "Rename") then
              local ret, newname = reaper.GetUserInputs("Rename Group", 1, "New Name:,extrawidth=200", folder)
              if ret and newname and newname ~= "" then
                custom_folders[i] = newname
                custom_folders_content[newname] = custom_folders_content[folder] or {}
                custom_folders_content[folder] = nil
                if tree_state.cur_custom_folder == folder then
                  tree_state.cur_custom_folder = newname
                end
                SaveCustomFolders()
              end
            end
            if reaper.ImGui_MenuItem(ctx, "Remove") then
              table.remove(custom_folders, i)
              custom_folders_content[folder] = nil
              if tree_state.cur_custom_folder == folder then
                tree_state.cur_custom_folder = ""
                files_idx_cache = {}
              end
              SaveCustomFolders()
            end
            reaper.ImGui_EndPopup(ctx)
          end
          -- 拖拽目标
          if reaper.ImGui_BeginDragDropTarget(ctx) then
            if reaper.ImGui_AcceptDragDropPayload(ctx, "AUDIO_PATH") then
              local retval, dtype, payload, is_preview, is_delivery = reaper.ImGui_GetDragDropPayload(ctx)
              if retval and dtype == "AUDIO_PATH" and type(payload) == "string" and payload ~= "" then
                local drag_path = payload
                custom_folders_content[folder] = custom_folders_content[folder] or {}
                local exists = false
                for _, p in ipairs(custom_folders_content[folder]) do
                  if p == drag_path then exists = true break end
                end
                if not exists then
                  table.insert(custom_folders_content[folder], drag_path)
                  SaveCustomFolders()
                  if collect_mode == COLLECT_MODE_CUSTOMFOLDER and tree_state.cur_custom_folder == folder then
                    CollectFiles()
                  end
                end
              end
            end
            reaper.ImGui_EndDragDropTarget(ctx)
          end
        end
        -- 新建自定义文件夹按钮
        if reaper.ImGui_Button(ctx, "Create Group##add_custom_folder") then
          local ret, name = reaper.GetUserInputs("Create Group", 1, "Group Name:,extrawidth=200", "")
          if ret and name and name ~= "" then
            local exists = false
            for _, v in ipairs(custom_folders) do
              if v == name then exists = true break end
            end
            if not exists then
              table.insert(custom_folders, name)
              custom_folders_content[name] = {}
              SaveCustomFolders()
            end
          end
        end
        reaper.ImGui_Unindent(ctx, 7)
        --reaper.ImGui_TreePop(ctx)
      end
      reaper.ImGui_PopStyleColor(ctx, 2) -- 恢复文本和折叠标题按钮颜色
      reaper.ImGui_EndChild(ctx)
    end

    -- 表格中间分割条
    reaper.ImGui_SameLine(ctx, nil, 0)
    reaper.ImGui_InvisibleButton(ctx, "##splitter", splitter_w, child_h)
    local splitter_active = reaper.ImGui_IsItemActive(ctx)
    local splitter_hovered = reaper.ImGui_IsItemHovered(ctx)
    local mx = select(1, reaper.ImGui_GetMousePos(ctx))
    local wx = select(1, reaper.ImGui_GetWindowPos(ctx))

    -- 防止分割条跳变
    if reaper.ImGui_IsItemActivated(ctx) then
      -- 鼠标按下时，记录当前偏移
      splitter_drag = true
      splitter_drag_offset = mx - wx - left_w
    end

    if splitter_drag and splitter_active then
      -- 拖动时，基于初始点击的偏移修正
      local new_left = mx - wx - splitter_drag_offset
      new_left = math.max(min_left, math.min(max_left, new_left))
      left_ratio = new_left / avail_x
      reaper.SetExtState(EXT_SECTION, "left_ratio", tostring(left_ratio), true) -- 保存分割条位置
    end

    if not splitter_active then
      splitter_drag = false
    end

    -- 分割条高亮
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local min_x, min_y = reaper.ImGui_GetItemRectMin(ctx)
    local max_x, max_y = reaper.ImGui_GetItemRectMax(ctx)
    local color = splitter_hovered and 0x00AFFF88 or 0x77777744
    reaper.ImGui_DrawList_AddRectFilled(draw_list, min_x, min_y, max_x, max_y, color)

    -- 鼠标悬停或拖动分割条时，设置鼠标为左右拖动样式
    if splitter_hovered or splitter_active then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeEW())
    end

    reaper.ImGui_SameLine(ctx)

    -- 设置表格线条颜色 - 表格颜色
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableBorderStrong(), 0x07192EFF) -- 边框线，深灰0xFF404040 透明0x00000000
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableBorderLight(),  0x07192EFF) -- 列表线/分割线，深灰0xFF404040 透明0x00000000
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableRowBg(),        0xFF0F0F0F) -- 表格行背景色 0xFF0F0F0F
    -- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableRowBgAlt(),     0xFF0F0F0F)
    -- 右侧表格列表, 支持表格排序和冻结首行
    if reaper.ImGui_BeginChild(ctx, "##file_table_child", right_w, child_h, 0) then
      if reaper.ImGui_BeginTable(ctx, "filelist", 14,
        -- reaper.ImGui_TableFlags_RowBg() -- 表格背景交替颜色
        reaper.ImGui_TableFlags_Borders() -- 表格分隔线
        | reaper.ImGui_TableFlags_BordersOuter() -- 表格边界线
        | reaper.ImGui_TableFlags_Resizable()
        | reaper.ImGui_TableFlags_ScrollY()
        | reaper.ImGui_TableFlags_ScrollX()
        | reaper.ImGui_TableFlags_Sortable()
        | reaper.ImGui_TableFlags_Hideable()
      ) then
        reaper.ImGui_TableSetupScrollFreeze(ctx, 0, 1) -- 只冻结表头
        if collect_mode == COLLECT_MODE_ALL_ITEMS then -- Media Items
          reaper.ImGui_TableSetupColumn(ctx, "Mark",        reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 17)
          reaper.ImGui_TableSetupColumn(ctx, "Take Name",   reaper.ImGui_TableColumnFlags_WidthFixed(), 200, COL_FILENAME)
          reaper.ImGui_TableSetupColumn(ctx, "Size",        reaper.ImGui_TableColumnFlags_WidthFixed(), 55, COL_SIZE)
          reaper.ImGui_TableSetupColumn(ctx, "Type",        reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_TYPE)
          reaper.ImGui_TableSetupColumn(ctx, "Track",       reaper.ImGui_TableColumnFlags_WidthFixed(), 100, COL_DATE)
          reaper.ImGui_TableSetupColumn(ctx, "Position",    reaper.ImGui_TableColumnFlags_WidthFixed(), 80, COL_GENRE)
          reaper.ImGui_TableSetupColumn(ctx, "Comment",     reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_COMMENT)
          reaper.ImGui_TableSetupColumn(ctx, "Description", reaper.ImGui_TableColumnFlags_WidthFixed(), 200, COL_DESCRIPTION)
          reaper.ImGui_TableSetupColumn(ctx, "Length",      reaper.ImGui_TableColumnFlags_WidthFixed(), 60, COL_LENGTH)
          reaper.ImGui_TableSetupColumn(ctx, "Channels",    reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_CHANNELS)
          reaper.ImGui_TableSetupColumn(ctx, "Samplerate",  reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_SAMPLERATE)
          reaper.ImGui_TableSetupColumn(ctx, "Bits",        reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_BITS)
          reaper.ImGui_TableSetupColumn(ctx, "Group",       reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 40)
          reaper.ImGui_TableSetupColumn(ctx, "Path",        reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 300)
        elseif collect_mode == COLLECT_MODE_RPP then -- RPP
          reaper.ImGui_TableSetupColumn(ctx, "Mark",        reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 17)
          reaper.ImGui_TableSetupColumn(ctx, "File Name",   reaper.ImGui_TableColumnFlags_WidthFixed(), 200, COL_FILENAME)
          reaper.ImGui_TableSetupColumn(ctx, "Size",        reaper.ImGui_TableColumnFlags_WidthFixed(), 55, COL_SIZE)
          reaper.ImGui_TableSetupColumn(ctx, "Type",        reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_TYPE)
          reaper.ImGui_TableSetupColumn(ctx, "Track",       reaper.ImGui_TableColumnFlags_WidthFixed(), 100, COL_DATE)
          reaper.ImGui_TableSetupColumn(ctx, "Position",    reaper.ImGui_TableColumnFlags_WidthFixed(), 80, COL_GENRE)
          reaper.ImGui_TableSetupColumn(ctx, "Comment",     reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_COMMENT)
          reaper.ImGui_TableSetupColumn(ctx, "Description", reaper.ImGui_TableColumnFlags_WidthFixed(), 200, COL_DESCRIPTION)
          reaper.ImGui_TableSetupColumn(ctx, "Length",      reaper.ImGui_TableColumnFlags_WidthFixed(), 60, COL_LENGTH)
          reaper.ImGui_TableSetupColumn(ctx, "Channels",    reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_CHANNELS)
          reaper.ImGui_TableSetupColumn(ctx, "Samplerate",  reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_SAMPLERATE)
          reaper.ImGui_TableSetupColumn(ctx, "Bits",        reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_BITS)
          reaper.ImGui_TableSetupColumn(ctx, "Group",       reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 40)
          reaper.ImGui_TableSetupColumn(ctx, "Path",        reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 300)
        else
          reaper.ImGui_TableSetupColumn(ctx, "Mark",        reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 17)
          reaper.ImGui_TableSetupColumn(ctx, "File Name",        reaper.ImGui_TableColumnFlags_WidthFixed(), 250, COL_FILENAME)
          reaper.ImGui_TableSetupColumn(ctx, "Size",        reaper.ImGui_TableColumnFlags_WidthFixed(), 55, COL_SIZE)
          reaper.ImGui_TableSetupColumn(ctx, "Type",        reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_TYPE)
          reaper.ImGui_TableSetupColumn(ctx, "Date",        reaper.ImGui_TableColumnFlags_WidthFixed(), 55, COL_DATE)
          reaper.ImGui_TableSetupColumn(ctx, "Genre",       reaper.ImGui_TableColumnFlags_WidthFixed(), 55, COL_GENRE)
          reaper.ImGui_TableSetupColumn(ctx, "Comment",     reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_COMMENT)
          reaper.ImGui_TableSetupColumn(ctx, "Description", reaper.ImGui_TableColumnFlags_WidthFixed(), 200, COL_DESCRIPTION)
          reaper.ImGui_TableSetupColumn(ctx, "Length",      reaper.ImGui_TableColumnFlags_WidthFixed(), 60, COL_LENGTH)
          reaper.ImGui_TableSetupColumn(ctx, "Channels",    reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_CHANNELS)
          reaper.ImGui_TableSetupColumn(ctx, "Samplerate",  reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_SAMPLERATE)
          reaper.ImGui_TableSetupColumn(ctx, "Bits",        reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_BITS)
          reaper.ImGui_TableSetupColumn(ctx, "Group",       reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 40)
          reaper.ImGui_TableSetupColumn(ctx, "Path",        reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 300)
        end
        -- 此处新增时，记得累加 filelist 的列表数量。测试元数据内容 - CollectFromProjectDirectory()
        reaper.ImGui_TableHeadersRow(ctx)

        -- 排序，只对缓存排序一次
        local need_sort, has_specs = reaper.ImGui_TableNeedSort(ctx)
        if need_sort and has_specs and files_idx_cache then
          local sort_specs = {}
          local id = 0
          while true do
            local rv, col_index, col_user_id, sort_dir = reaper.ImGui_TableGetColumnSortSpecs(ctx, id)
            if not rv then break end
            sort_specs[#sort_specs + 1] = {
              col_index = col_index,
              user_id = col_user_id,
              sort_dir = sort_dir
            }
            id = id + 1
          end
    
          table.sort(files_idx_cache, function(a, b)
            for _, spec in ipairs(sort_specs) do
              if spec.user_id == COL_FILENAME then
                if a.filename ~= b.filename then -- File 列排序
                  if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                    return a.filename > b.filename
                  else
                    return a.filename < b.filename
                  end
                end
              elseif spec.user_id == COL_SIZE then -- Size 列排序
                local asize = tonumber(a.size) or 0
                local bsize = tonumber(b.size) or 0
                if asize ~= bsize then
                  if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                    return asize > bsize
                  else
                    return asize < bsize
                  end
                end
              elseif spec.user_id == COL_TYPE then -- Type 列排序
                if a.type ~= b.type then
                  if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                    return a.type > b.type
                  else
                    return a.type < b.type
                  end
                end
              elseif spec.user_id == COL_DATE then -- Date 列排序
                if (a.bwf_orig_date or "") ~= (b.bwf_orig_date or "") then
                  if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                    return (a.bwf_orig_date or "") > (b.bwf_orig_date or "")
                  else
                    return (a.bwf_orig_date or "") < (b.bwf_orig_date or "")
                  end
                end
              elseif spec.user_id == COL_GENRE then -- Genre & Position 列排序
                if collect_mode == COLLECT_MODE_ALL_ITEMS or collect_mode == COLLECT_MODE_RPP then -- Media items or RPP
                  local apos = tonumber(a.position) or 0
                  local bpos = tonumber(b.position) or 0
                  if apos ~= bpos then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return apos > bpos
                    else
                      return apos < bpos
                    end
                  end
                else
                  if (a.genre or "") ~= (b.genre or "") then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return (a.genre or "") > (b.genre or "")
                    else
                      return (a.genre or "") < (b.genre or "")
                    end
                  end
                end
              elseif spec.user_id == COL_COMMENT then -- Comment 列排序
                if (a.comment or "") ~= (b.comment or "") then
                  if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                    return (a.comment or "") > (b.comment or "")
                  else
                    return (a.comment or "") < (b.comment or "")
                  end
                end
              elseif spec.user_id == COL_DESCRIPTION then -- Description 列排序
                if (a.description or "") ~= (b.description or "") then
                  if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                    return (a.description or "") > (b.description or "")
                  else
                    return (a.description or "") < (b.description or "")
                  end
                end
              elseif spec.user_id == COL_LENGTH then -- Length 列排序
                local alen = tonumber(a.length) or 0
                local blen = tonumber(b.length) or 0
                if alen ~= blen then
                  if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                    return alen > blen
                  else
                    return alen < blen
                  end
                end
              elseif spec.user_id == COL_CHANNELS then -- Channels 列排序
                local achan = tonumber(a.channels) or 0
                local bchan = tonumber(b.channels) or 0
                if achan ~= bchan then
                  if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                    return achan > bchan
                  else
                    return achan < bchan
                  end
                end
              elseif spec.user_id == COL_SAMPLERATE then -- Samplerate 列排序
                local asr = tonumber(a.samplerate) or 0
                local bsr = tonumber(b.samplerate) or 0
                if asr ~= bsr then
                  if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                    return asr > bsr
                  else
                    return asr < bsr
                  end
                end
              elseif spec.user_id == COL_BITS then -- Bits 列排序
                local abits = tonumber(a.bits) or 0
                local bbits = tonumber(b.bits) or 0
                if abits ~= bbits then
                  if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                    return abits > bbits
                  else
                    return abits < bbits
                  end
                end
              end
            end
            return false
          end)
        end

        -- 上下方向键选中文件
        local num_files = files_idx_cache and #files_idx_cache or 0
        if num_files > 0 then
          local played = false
        
          if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_DownArrow()) then
            if not selected_row or selected_row < 1 then
              selected_row = 1
              played = true
            elseif selected_row < num_files then
              selected_row = selected_row + 1
              played = true
            end
          end
          if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_UpArrow()) then
            if not selected_row or selected_row < 1 then
              selected_row = 1
              played = true
            elseif selected_row > 1 then
              selected_row = selected_row - 1
              played = true
            end
          end

          -- 若勾选auto_play_selected，且确实有移动，则自动播放
          if auto_play_selected and played and selected_row and files_idx_cache[selected_row] then
            local info = files_idx_cache[selected_row]
            PlayFromStart(info)
            is_paused = false
            paused_position = 0
          end
        end

        -- 上下按键滚动表格项，上一帧选中的行号
        local prev_selected_row = _G.prev_selected_row or -1
        -- 滚动目标，nil表示不滚动
        _G.scroll_target = nil
        -- 检查上下键并设置滚动目标
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_DownArrow()) and selected_row ~= prev_selected_row then
          _G.scroll_target = 0.5 -- 1.0=底部
        end
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_UpArrow()) and selected_row ~= prev_selected_row then
          _G.scroll_target = 0.5 -- 0.0=顶部
        end

        for i, info in ipairs(files_idx_cache) do
          local filter_text = reaper.ImGui_TextFilter_Get(filename_filter) or ""
          -- 拆分为多个关键词
          local keywords = {}
          for word in filter_text:gmatch("%S+") do
            keywords[#keywords+1] = word:lower()
          end
          -- 合并所有要检索的内容，全部转小写
          local target = ((info.filename or "") .. " " .. (info.description or "")):lower()
          local match = true
          for _, kw in ipairs(keywords) do
            if not target:find(kw, 1, true) then
              match = false
              break
            end
          end

          if match then
            reaper.ImGui_TableNextRow(ctx)
            -- 表格标题文字颜色 -- 文字颜色
            if IsPreviewed(info.path) then
              reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), previewed_text)
            else
              reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), normal_text)
            end
            -- 表格标题悬停及激活时颜色 -- 表格颜色 悬停颜色 激活颜色
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), table_header_hovered)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), table_header_active)
            local row_hovered = false

            -- mark
            reaper.ImGui_TableSetColumnIndex(ctx, 0)
            if IsPreviewed(info.path) then
              local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
              local cx, cy = reaper.ImGui_GetCursorScreenPos(ctx)
              local radius = 1.5
              local color = 0xFFF0F0F0 -- 0x00FFFFFF -- 0x22ff22ff
              reaper.ImGui_DrawList_AddCircleFilled(draw_list, cx + radius + 10, cy + radius + 5, radius, color)
              reaper.ImGui_Dummy(ctx, radius*2+4, radius*2+4)
            else
              reaper.ImGui_Dummy(ctx, 10, 10)
            end

            -- File & Teak name
            reaper.ImGui_TableSetColumnIndex(ctx, 1)
            if collect_mode == COLLECT_MODE_ALL_ITEMS or collect_mode == COLLECT_MODE_RPP then -- Media items or RPP
              local selectable_label = (info.filename or "-") .. "##ALLITEMS_" .. tostring(i)
              if reaper.ImGui_Selectable(ctx, selectable_label, selected_row == i, reaper.ImGui_SelectableFlags_SpanAllColumns()) then
                selected_row = i
              end
              -- 右键菜单定位item/静音/重命名/插入到工程中
              local popup_id = "item_context_menu_" .. tostring(i)
              if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
                reaper.ImGui_OpenPopup(ctx, popup_id)
              end

              if reaper.ImGui_BeginPopup(ctx, popup_id) then
                local is_muted = false
                if info.usages and #info.usages > 0 then
                  is_muted = (reaper.GetMediaItemInfo_Value(info.usages[1].item, "B_MUTE") == 1)
                else
                  is_muted = (reaper.GetMediaItemInfo_Value(info.item, "B_MUTE") == 1)
                end

                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), normal_text)
                if reaper.ImGui_MenuItem(ctx, "Mute", nil, is_muted) then
                  local new_mute = is_muted and 0 or 1
                  if info.usages and #info.usages > 0 then
                    for _, usage in ipairs(info.usages) do
                      reaper.SetMediaItemInfo_Value(usage.item, "B_MUTE", new_mute)
                    end
                    reaper.UpdateArrange()
                  else
                    reaper.SetMediaItemInfo_Value(info.item, "B_MUTE", new_mute)
                    reaper.UpdateArrange()
                  end
                  reaper.ImGui_CloseCurrentPopup(ctx)
                end

                if reaper.ImGui_BeginMenu(ctx, "Usage") then
                  for _, usage in ipairs(info.usages or {}) do
                    local label = string.format('Track %d "%s" %s',
                      reaper.GetMediaTrackInfo_Value(usage.track, "IP_TRACKNUMBER") or 0,
                      usage.track_name or "-",
                      reaper.format_timestr(usage.position or 0, "")
                    )
                    if reaper.ImGui_MenuItem(ctx, label) then
                      reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
                      reaper.SetMediaItemSelected(usage.item, true)
                      reaper.UpdateArrange()
                      reaper.SetEditCurPos(usage.position, true, false)
                      reaper.ImGui_CloseCurrentPopup(ctx)
                    end
                  end
                  reaper.ImGui_EndMenu(ctx)
                end

                if collect_mode == COLLECT_MODE_RPP then
                  if reaper.ImGui_MenuItem(ctx, "Rename file...") then
                    local old_path = info.path
                    local dir = old_path:match("^(.*)[/\\][^/\\]+$")
                    local old_filename = old_path:match("[^/\\]+$")
                    local ext = old_filename:match("%.[^%.]+$") or "" -- 提取原始后缀

                    local ok, new_filename = reaper.GetUserInputs("Rename File", 1, "New Name:,extrawidth=200", old_filename)
                    if ok and new_filename and new_filename ~= "" and new_filename ~= old_filename then
                      -- 如果新文件名没有后缀，自动补全原后缀
                      if not new_filename:lower():match("%.[a-z0-9]+$") and ext ~= "" then
                        new_filename = new_filename .. ext
                      end
                      local new_path = dir .. "/" .. new_filename

                      -- 拷贝物理文件
                      local srcfile = io.open(old_path, "rb")
                      local dstfile = io.open(new_path, "wb")
                      if srcfile and dstfile then
                        dstfile:write(srcfile:read("*a"))
                        srcfile:close()
                        dstfile:close()
                        -- 替换所有usages的source
                        for _, usage in ipairs(info.usages or {}) do
                          reaper.BR_SetTakeSourceFromFile(usage.take, new_path, true)
                        end
                        -- 刷新
                        CollectFiles()
                        reaper.ShowMessageBox("File copied and relinked!", "OK", 0)
                      else
                        reaper.ShowMessageBox("Copy failed!", "Error", 0)
                      end
                    end
                    reaper.ImGui_CloseCurrentPopup(ctx)
                  end
                else
                  if reaper.ImGui_MenuItem(ctx, "Rename active take") then
                    local ok, new_name = reaper.GetUserInputs("Rename Active Take", 1, "New Name:,extrawidth=200", info.filename)
                    if ok and new_name and new_name ~= "" then
                      -- 遍历所有usages
                      if info.usages and #info.usages > 0 then
                        for _, usage in ipairs(info.usages) do
                          reaper.GetSetMediaItemTakeInfo_String(usage.take, "P_NAME", new_name, true)
                        end
                      else
                        reaper.GetSetMediaItemTakeInfo_String(info.take, "P_NAME", new_name, true)
                      end
                      CollectFiles()
                    end
                    reaper.ImGui_CloseCurrentPopup(ctx)
                  end
                end

                if reaper.ImGui_MenuItem(ctx, "Insert into project") then
                  WithAutoCrossfadeDisabled(function()
                    reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_SAVEVIEW"), 0)
                    local old_cursor = reaper.GetCursorPosition()
                    reaper.PreventUIRefresh(1) -- 防止UI刷新
                    reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
                    if info.path and info.path ~= "" then
                      reaper.InsertMedia(info.path, 0)
                      reaper.SetEditCurPos(old_cursor, false, false) -- 恢复光标到插入前
                    end
                    reaper.PreventUIRefresh(-1)
                    reaper.UpdateArrange()
                    reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_RESTOREVIEW"), 0)
                    reaper.ImGui_CloseCurrentPopup(ctx)
                  end)
                end

                if reaper.ImGui_MenuItem(ctx, "Remove from project") then
                  if info.usages and #info.usages > 0 then
                    for _, usage in ipairs(info.usages) do
                      if usage.track and usage.item then
                        reaper.DeleteTrackMediaItem(usage.track, usage.item)
                      end
                    end
                  elseif info.track and info.item then
                    -- 单个
                    reaper.DeleteTrackMediaItem(info.track, info.item)
                  end
                  CollectFiles() -- 删除后刷新列表
                  reaper.UpdateArrange()
                  reaper.ImGui_CloseCurrentPopup(ctx)
                end
                reaper.ImGui_PopStyleColor(ctx, 1)
                reaper.ImGui_EndPopup(ctx)
              end

              -- 键盘快捷键
              if selected_row == i then
                -- Q: 定位item并选中
                if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Q()) then
                  local shift = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftShift()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightShift())
                  if info.usages and #info.usages > 0 then
                    -- 当前索引
                    info.__usage_sel_index = info.__usage_sel_index or 1
                    if shift then
                      -- 反向循环
                      info.__usage_sel_index = info.__usage_sel_index - 1
                      if info.__usage_sel_index < 1 then
                        info.__usage_sel_index = #info.usages
                      end
                    else
                      -- 正向循环
                      info.__usage_sel_index = info.__usage_sel_index + 1
                      if info.__usage_sel_index > #info.usages then
                        info.__usage_sel_index = 1
                      end
                    end
                    local target = info.usages[info.__usage_sel_index]
                    reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
                    reaper.SetMediaItemSelected(target.item, true)
                    reaper.UpdateArrange()
                    local pos = reaper.GetMediaItemInfo_Value(target.item, "D_POSITION")
                    reaper.SetEditCurPos(pos, true, false)
                  else
                    -- 只有一个item的情况
                    reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
                    reaper.SetMediaItemSelected(info.item, true)
                    reaper.UpdateArrange()
                    local pos = reaper.GetMediaItemInfo_Value(info.item, "D_POSITION")
                    reaper.SetEditCurPos(pos, true, false)
                  end
                end

                -- F2: 更改item名称
                if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F2()) then
                  if collect_mode == COLLECT_MODE_RPP then
                    local old_path = info.path
                    local dir = old_path:match("^(.*)[/\\][^/\\]+$")
                    local old_filename = old_path:match("[^/\\]+$")
                    local ext = old_filename:match("%.[^%.]+$") or "" -- 提取原始后缀

                    local ok, new_filename = reaper.GetUserInputs("Rename File", 1, "New Name:,extrawidth=200", old_filename)
                    if ok and new_filename and new_filename ~= "" and new_filename ~= old_filename then
                      -- 如果新文件名没有后缀，自动补全原后缀
                      if not new_filename:lower():match("%.[a-z0-9]+$") and ext ~= "" then
                        new_filename = new_filename .. ext
                      end
                      local new_path = dir .. "/" .. new_filename

                      -- 拷贝物理文件
                      local srcfile = io.open(old_path, "rb")
                      local dstfile = io.open(new_path, "wb")
                      if srcfile and dstfile then
                        dstfile:write(srcfile:read("*a"))
                        srcfile:close()
                        dstfile:close()
                        -- 替换所有usages的source
                        for _, usage in ipairs(info.usages or {}) do
                          reaper.BR_SetTakeSourceFromFile(usage.take, new_path, true)
                        end
                        -- 刷新
                        CollectFiles()
                        reaper.ShowMessageBox("File copied and relinked!", "OK", 0)
                      else
                        reaper.ShowMessageBox("Copy failed!", "Error", 0)
                      end
                    end
                  elseif collect_mode == COLLECT_MODE_ALL_ITEMS then
                    local ok, new_name = reaper.GetUserInputs("Rename Active Take", 1, "New Name:,extrawidth=200", info.filename)
                    if ok and new_name and new_name ~= "" then
                      -- 遍历所有usages
                      if info.usages and #info.usages > 0 then
                        for _, usage in ipairs(info.usages) do
                          reaper.GetSetMediaItemTakeInfo_String(usage.take, "P_NAME", new_name, true)
                        end
                      else
                        reaper.GetSetMediaItemTakeInfo_String(info.take, "P_NAME", new_name, true)
                      end
                      CollectFiles()
                    end
                  end
                end

                -- M: mute item
                if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_M()) then
                  if info.usages and #info.usages > 0 then
                    -- 按第一个item的当前状态决定全组mute还是unmute
                    local first_mute = reaper.GetMediaItemInfo_Value(info.usages[1].item, "B_MUTE")
                    local new_mute = (first_mute == 1) and 0 or 1
                    for _, usage in ipairs(info.usages) do
                      reaper.SetMediaItemInfo_Value(usage.item, "B_MUTE", new_mute)
                    end
                    reaper.UpdateArrange()
                  else
                    -- 单个
                    local mute = reaper.GetMediaItemInfo_Value(info.item, "B_MUTE")
                    reaper.SetMediaItemInfo_Value(info.item, "B_MUTE", mute == 1 and 0 or 1)
                    reaper.UpdateArrange()
                  end
                end

                -- Ctrl+D: 删除item
                if (reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl()))
                  and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_D()) then
                  if info.usages and #info.usages > 0 then
                    for _, usage in ipairs(info.usages) do
                      if usage.track and usage.item then
                        reaper.DeleteTrackMediaItem(usage.track, usage.item)
                      end
                    end
                  elseif info.track and info.item then
                    -- 单个
                    reaper.DeleteTrackMediaItem(info.track, info.item)
                  end
                  CollectFiles() -- 删除后刷新列表
                  reaper.UpdateArrange()
                end
              end
            else
              local selectable_label = (info.filename or "-") .. "##RowContext__" .. tostring(i)
              if reaper.ImGui_Selectable(ctx, selectable_label, selected_row == i, reaper.ImGui_SelectableFlags_SpanAllColumns()) then
                selected_row = i
              end

              local popup_id = "row_context_" .. tostring(i)
              if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
                reaper.ImGui_OpenPopup(ctx, popup_id)
              end

              if reaper.ImGui_BeginPopup(ctx, popup_id) then
                -- 右键打开文件所在目录
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), normal_text) -- 菜单文字颜色
                if reaper.ImGui_MenuItem(ctx, "Show in Explorer/Finder") then
                  local path = info.path
                  if path and path ~= "" then
                    reaper.CF_LocateInExplorer(path)
                  end
                end
                reaper.ImGui_PopStyleColor(ctx, 1)
                reaper.ImGui_EndPopup(ctx)
              end
            end

            if reaper.ImGui_IsItemHovered(ctx) then
              row_hovered = true
            end

            -- 双击播放
            if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
              if doubleclick_action == DOUBLECLICK_INSERT then
                WithAutoCrossfadeDisabled(function()
                  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_SAVEVIEW"), 0)
                  local old_cursor = reaper.GetCursorPosition()
                  reaper.PreventUIRefresh(1) -- 防止UI刷新
                  reaper.InsertMedia(info.path, 0)
                  reaper.SetEditCurPos(old_cursor, true, false) -- 恢复光标到插入前
                  reaper.PreventUIRefresh(-1)
                  reaper.UpdateArrange()
                  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_RESTOREVIEW"), 0)
                end)
              elseif doubleclick_action == DOUBLECLICK_PREVIEW then
                PlayFromStart(info)
              elseif doubleclick_action == DOUBLECLICK_NONE then
                -- Do nothing
              end
            end

            -- 拖动音频到REAPER或自定义文件夹
            if reaper.ImGui_BeginDragDropSource(ctx) then
              reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), normal_text) -- 菜单文字颜色
              reaper.ImGui_Text(ctx, "Drag to insert or collect")
              dragging_audio = {
                path = info and info.path,
                start_time = 0,
                end_time = info and info.section_length or 0,
                section_offset = info and info.section_offset or 0
              }
              -- 自定义文件夹，用 AUDIO_PATH 作为类型
              local path = info and info.path
              if path and path ~= "" then
                -- reaper.ImGui_Text(ctx, "Drag to collect")
                reaper.ImGui_SetDragDropPayload(ctx, "AUDIO_PATH", path)
              end
              reaper.ImGui_PopStyleColor(ctx, 1)
              reaper.ImGui_EndDragDropSource(ctx)
            end

            -- Ctrl+左键 或 Ctrl+S 插入文件到工程
            local ctrl = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl())
            local is_ctrl_click = reaper.ImGui_IsItemClicked(ctx, 0) and ctrl
            local is_ctrl_I = ctrl and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_S())
            if (is_ctrl_click or (selected_row == i and is_ctrl_I)) then
              WithAutoCrossfadeDisabled(function()
                reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_SAVEVIEW"), 0)
                local old_cursor = reaper.GetCursorPosition()
                reaper.PreventUIRefresh(1) -- 防止UI刷新
                reaper.InsertMedia(info.path, 0)
                reaper.SetEditCurPos(old_cursor, false, false) -- 恢复光标到插入前
                reaper.PreventUIRefresh(-1)
                reaper.UpdateArrange()
                reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_RESTOREVIEW"), 0)
              end)
            end

            -- Size
            reaper.ImGui_TableSetColumnIndex(ctx, 2)
            local size_str
            if info.size >= 1024*1024 then
              size_str = string.format("%.2f MB", info.size / 1024 / 1024)
            elseif info.size >= 1024 then
              size_str = string.format("%.2f KB", info.size / 1024)
            else
              size_str = string.format("%d B", info.size)
            end
            reaper.ImGui_Text(ctx, size_str)
            if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
            if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
              PlayFromStart(info)
            end

            -- Type
            reaper.ImGui_TableSetColumnIndex(ctx, 3)
            reaper.ImGui_Text(ctx, info.type)
            if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
            if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
              PlayFromStart(info)
            end

            -- Date & Track name
            if collect_mode == COLLECT_MODE_ALL_ITEMS or collect_mode == COLLECT_MODE_RPP then -- Media items or RPP
              reaper.ImGui_TableSetColumnIndex(ctx, 4)
              if info.usages and #info.usages > 1 then
                reaper.ImGui_Text(ctx, ("%d instances"):format(#info.usages))
              -- elseif info.usages and #info.usages == 1 then
              --   reaper.ImGui_Text(ctx, info.usages[1].track_name or "-")
              else
                reaper.ImGui_Text(ctx, info.track_name or "-")
              end
              local popup_id2 = "item_context_menu__" .. tostring(i)
              if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
                reaper.ImGui_OpenPopup(ctx, popup_id2)
              end
              if reaper.ImGui_BeginPopup(ctx, popup_id2) then
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), normal_text) -- 菜单文字颜色
                for _, usage in ipairs(info.usages or {}) do
                  local label = string.format('Track %d "%s" %s',
                    reaper.GetMediaTrackInfo_Value(usage.track, "IP_TRACKNUMBER") or 0,
                    usage.track_name or "-",
                    reaper.format_timestr(usage.position or 0, "")
                  )
                  if reaper.ImGui_MenuItem(ctx, label) then
                    reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
                    reaper.SetMediaItemSelected(usage.item, true)
                    reaper.UpdateArrange()
                    reaper.SetEditCurPos(usage.position, true, false)
                    reaper.ImGui_CloseCurrentPopup(ctx)
                  end
                end
                reaper.ImGui_PopStyleColor(ctx, 1)
                reaper.ImGui_EndPopup(ctx)
              end
            else
              reaper.ImGui_TableSetColumnIndex(ctx, 4)
              reaper.ImGui_Text(ctx, info.bwf_orig_date or "-")
              if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
              if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
                PlayFromStart(info)
              end
            end

            -- Genre & Position
            if collect_mode == COLLECT_MODE_ALL_ITEMS or collect_mode == COLLECT_MODE_RPP then -- Media items or RPP
              reaper.ImGui_TableSetColumnIndex(ctx, 5)
              if info.usages and #info.usages > 1 then
                reaper.ImGui_Text(ctx, ("%d instances"):format(#info.usages))
              else
                local pos_str = reaper.format_timestr(info.position or 0, "") or "-"
                reaper.ImGui_Text(ctx, pos_str)
              end
              local popup_id3 = "item_context_menu___" .. tostring(i)
              if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
                reaper.ImGui_OpenPopup(ctx, popup_id3)
              end
              if reaper.ImGui_BeginPopup(ctx, popup_id3) then
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), normal_text) -- 菜单文字颜色
                for _, usage in ipairs(info.usages or {}) do
                  local label = string.format('Track %d "%s" %s',
                    reaper.GetMediaTrackInfo_Value(usage.track, "IP_TRACKNUMBER") or 0,
                    usage.track_name or "-",
                    reaper.format_timestr(usage.position or 0, "")
                  )
                  if reaper.ImGui_MenuItem(ctx, label) then
                    reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
                    reaper.SetMediaItemSelected(usage.item, true)
                    reaper.UpdateArrange()
                    reaper.SetEditCurPos(usage.position, true, false)
                    reaper.ImGui_CloseCurrentPopup(ctx)
                  end
                end
                reaper.ImGui_PopStyleColor(ctx, 1)
                reaper.ImGui_EndPopup(ctx)
              end
            else
              reaper.ImGui_TableSetColumnIndex(ctx, 5)
              reaper.ImGui_Text(ctx, info.genre or "-")
              if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
              if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
                PlayFromStart(info)
              end
            end

            -- Comment
            reaper.ImGui_TableSetColumnIndex(ctx, 6)
            reaper.ImGui_Text(ctx, info.comment or "-")
            -- if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
            -- if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            --   PlayFromStart(info)
            -- end

            -- Description
            reaper.ImGui_TableSetColumnIndex(ctx, 7)
            reaper.ImGui_Text(ctx, info.description or "-")
            -- if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
            -- if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            --   PlayFromStart(info)
            -- end

            -- Length
            reaper.ImGui_TableSetColumnIndex(ctx, 8)
            local len_str = (info.length and info.length > 0) and reaper.format_timestr(info.length, "") or "-"
            reaper.ImGui_Text(ctx, len_str)
            
            -- if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
            -- if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            --   PlayFromStart(info)
            -- end

            -- Channels
            reaper.ImGui_TableSetColumnIndex(ctx, 9)
            reaper.ImGui_Text(ctx, info.channels)
            -- if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
            -- if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            --   PlayFromStart(info)
            -- end

            -- Samplerate
            reaper.ImGui_TableSetColumnIndex(ctx, 10)
            reaper.ImGui_Text(ctx, info.samplerate or "-") -- reaper.ImGui_Text(ctx, info.samplerate and (info.samplerate .. " Hz") or "-")
            -- if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
            -- if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            --   PlayFromStart(info)
            -- end

            -- Bits
            reaper.ImGui_TableSetColumnIndex(ctx, 11)
            reaper.ImGui_Text(ctx, info.bits or "-")
            -- if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
            -- if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            --   PlayFromStart(info)
            -- end

            -- Group
            reaper.ImGui_TableSetColumnIndex(ctx, 12)
            local group_names = GetCustomGroupsForPath(info.path)
            if group_names ~= "" then
              reaper.ImGui_Text(ctx, group_names)
            else
              -- 用固定像素宽度撑大区域
              reaper.ImGui_InvisibleButton(ctx, "GroupCell_", 100, reaper.ImGui_GetTextLineHeight(ctx))
            end

            -- 右键弹出group菜单
            if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
              reaper.ImGui_OpenPopup(ctx, "GroupMenu_" .. i)
            end
            if reaper.ImGui_BeginPopup(ctx, "GroupMenu_" .. i) then
              reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), normal_text) -- 菜单文字颜色
              ShowGroupMenu(info)
              reaper.ImGui_PopStyleColor(ctx, 1)
              reaper.ImGui_EndPopup(ctx)
            end

            -- Path
            reaper.ImGui_TableSetColumnIndex(ctx, 13)
            reaper.ImGui_Text(ctx, info.path)
            -- if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
            -- if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            --   PlayFromStart(info)
            -- end

            reaper.ImGui_PopStyleColor(ctx, 3) -- 恢复默认颜色, Popx3
    
            -- 在所有列渲染之后，再设置背景色 -- 此处设置无效
            -- if row_hovered or selected_row == i then
            --   reaper.ImGui_TableSetBgColor(ctx, reaper.ImGui_TableBgTarget_RowBg1(), 0x2d83ec66)
            -- end

            -- 上下按键自动滚动到可见
            if selected_row == i and _G.scroll_target ~= nil then
              reaper.ImGui_SetScrollHereY(ctx, _G.scroll_target)
              _G.scroll_target = nil -- 只滚动一次
            end
          end

          -- 自动播放切换表格中的音频文件
          if auto_play_next_pending and type(auto_play_next_pending) == "table" then
            local next_idx = -1
            for i, info in ipairs(files_idx_cache or {}) do
              if info.path == auto_play_next_pending.path then
                next_idx = i
                break
              end
            end
            if next_idx > 0 then
              selected_row = next_idx
              _G.scroll_target = 0.5  -- 下一帧表格自动滚动到中间
            end
            PlayFromStart(auto_play_next_pending)
            auto_play_next_pending = nil
          end
        end

        reaper.ImGui_EndTable(ctx)
      end
      -- 上下按键滚动保存选中项
      _G.prev_selected_row = selected_row

      -- 拖动音频到REAPER
      if dragging_audio then
        local window, _, _ = reaper.BR_GetMouseCursorContext()
        if not reaper.ImGui_IsMouseDown(ctx, 0) then -- 鼠标释放
          if window == "arrange" then -- 只允许在arrange窗口松开时插入
            WithAutoCrossfadeDisabled(function()
              reaper.PreventUIRefresh(1) -- 防止UI刷新
              reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_SAVEVIEW"), 0)
              local old_cursor = reaper.GetCursorPosition()
              local insert_time = reaper.BR_GetMouseCursorContext_Position()
              reaper.SetEditCurPos(insert_time, false, false)
              local tr = reaper.BR_GetMouseCursorContext_Track()
              if tr then reaper.SetOnlyTrackSelected(tr) end
              reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
              -- 判断是全长源音频还是item区段
              if dragging_audio.start_time and dragging_audio.end_time and math.abs(dragging_audio.end_time - dragging_audio.start_time) > 0.01 then
                InsertSelectedAudioSection(
                  dragging_audio.path,
                  dragging_audio.start_time,
                  dragging_audio.end_time,
                  dragging_audio.section_offset or 0,
                  false
                )
              else
                -- 只插入全长源音频
                reaper.InsertMedia(dragging_audio.path, 0)
              end
              reaper.SetEditCurPos(old_cursor, false, false) -- 恢复光标到插入前
              reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_RESTOREVIEW"), 0)
              reaper.PreventUIRefresh(-1)
              reaper.UpdateArrange()
            end)
          end
          dragging_audio = nil -- 鼠标释放时重置
        end
      end

      reaper.ImGui_EndChild(ctx)
    end
    reaper.ImGui_PopStyleColor(ctx, 3) -- 恢复颜色
    reaper.ImGui_Separator(ctx)

    -- 播放控制按钮
    -- Play 按钮
    if reaper.ImGui_Button(ctx, "Play", 45) then
      if is_paused and playing_source then
        -- 以Wave.play_cursor为准恢复播放
        playing_preview = reaper.CF_CreatePreview(playing_source)
        if playing_preview then
          if reaper.CF_Preview_SetValue then
            reaper.CF_Preview_SetValue(playing_preview, "B_LOOP", loop_enabled and 1 or 0)
            reaper.CF_Preview_SetValue(playing_preview, "D_VOLUME", volume)
            reaper.CF_Preview_SetValue(playing_preview, "D_PLAYRATE", play_rate)
            reaper.CF_Preview_SetValue(playing_preview, "D_PITCH", pitch)
            reaper.CF_Preview_SetValue(playing_preview, "B_PPITCH", preserve_pitch and 1 or 0)
            reaper.CF_Preview_SetValue(playing_preview, "D_POSITION", Wave.play_cursor or 0)
          end
          reaper.CF_Preview_Play(playing_preview)
          is_paused = false
          paused_position = 0
          wf_play_start_time = os.clock()
          wf_play_start_cursor = Wave.play_cursor or 0
        end
      elseif selected_row > 0 and files_idx_cache[selected_row] then
        -- 非暂停时，从头开始或当前位置
        -- if Wave and Wave.play_cursor and Wave.play_cursor > 0 then
        --   PlayFromCursor(files_idx_cache[selected_row])
        -- else
        --   PlayFromStart(files_idx_cache[selected_row])
        -- end
        PlayFromCursor(files_idx_cache[selected_row])
        is_paused = false
        paused_position = 0
      end
    end

    -- Pause 按钮
    reaper.ImGui_SameLine(ctx)
    -- 播放暂停按钮始终显示，自动切换文字
    local label = "Pause"
    local highlight_resume = false
    if is_paused and playing_source then
      label = "Pause" -- Resume
      highlight_resume = true
    end

    reaper.ImGui_SameLine(ctx)
    -- 仅在 Resume 时高亮
    if highlight_resume then
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x2ee72eff)
    end
    local clicked = reaper.ImGui_Button(ctx, label, 45)
    if highlight_resume then
      reaper.ImGui_PopStyleColor(ctx)
    end

    if clicked then
      if playing_preview and not is_paused then
        -- 当前在播放，暂停
        local ok, pos = reaper.CF_Preview_GetValue(playing_preview, "D_POSITION")
        if ok then
          paused_position = pos
          wf_play_start_cursor = paused_position
          Wave.play_cursor = paused_position
        end
        reaper.CF_Preview_Stop(playing_preview)
        is_paused = true
        playing_preview = nil
      elseif is_paused and playing_source then
        -- 处于暂停，恢复
        playing_preview = reaper.CF_CreatePreview(playing_source)
        if playing_preview then
          if reaper.CF_Preview_SetValue then
            reaper.CF_Preview_SetValue(playing_preview, "B_LOOP", loop_enabled and 1 or 0)
            reaper.CF_Preview_SetValue(playing_preview, "D_VOLUME", volume)
            reaper.CF_Preview_SetValue(playing_preview, "D_PLAYRATE", play_rate)
            reaper.CF_Preview_SetValue(playing_preview, "D_PITCH", pitch)
            reaper.CF_Preview_SetValue(playing_preview, "B_PPITCH", preserve_pitch and 1 or 0)
            reaper.CF_Preview_SetValue(playing_preview, "D_POSITION", paused_position)
          end
          reaper.CF_Preview_Play(playing_preview)
          wf_play_start_time = os.clock()
          wf_play_start_cursor = paused_position
          is_paused = false
        end
      end
    end

    -- Stop 按钮
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Stop", 45) then
      StopPreview()
      is_paused = false
      paused_position = 0

      -- 强制播放光标复位
      if last_play_cursor_before_play then
        Wave.play_cursor = last_play_cursor_before_play
      end
    end

    -- 随机播放按钮
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Rand", 45) then
      -- 随机选择表格中的一行
      local count = #files_idx_cache
      if count > 0 then
        -- math.randomseed 可根据实际需要加上 os.time() 进行初始化
        local rand_idx = math.random(1, count)
        selected_row = rand_idx -- 高亮选中行
        PlayFromCursor(files_idx_cache[rand_idx])
        is_paused = false
        paused_position = 0
      end
    end

    -- 循环开关
    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_Text(ctx, "Loop:")
    reaper.ImGui_SameLine(ctx)
    local rv
    rv, loop_enabled = reaper.ImGui_Checkbox(ctx, "##loop_checkbox", loop_enabled)
    if rv then
      -- 只要Loop勾选状态变化就立即重启播放，确保loop生效
      if playing_preview then
        RestartPreviewWithParams()
      end
    end

    -- 自动播放切换按钮
    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_Text(ctx, "Auto Play Next:")
    reaper.ImGui_SameLine(ctx)
    local rv6
    rv6, auto_play_next = reaper.ImGui_Checkbox(ctx, "##AutoPlayNext", auto_play_next)

    if auto_play_next and playing_preview and not is_paused and not auto_play_next_pending then
      local ok, pos = reaper.CF_Preview_GetValue(playing_preview, "D_POSITION")
      local ok2, length = reaper.CF_Preview_GetValue(playing_preview, "D_LENGTH")
      if ok and ok2 then
        if prev_preview_pos and prev_preview_pos < length and pos >= length then
          local cur_idx = -1
          for i, info in ipairs(files_idx_cache) do
            if info.path == playing_path then cur_idx = i break end
          end
          if cur_idx > 0 and cur_idx < #files_idx_cache then
            auto_play_next_pending = files_idx_cache[cur_idx + 1]
          else
            auto_play_next_pending = false
            StopPreview()
          end
        end
       prev_preview_pos = pos
      end
    end

    -- 音高旋钮
    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_Text(ctx, "Pitch:")
    reaper.ImGui_SameLine(ctx)
    -- local pitch_knob_min, pitch_knob_max = -6, 6 -- ±6 半音
    local pitch_knob_size = 20
    local pitch_knob_changed, pitch_knob_value = ImGui_Knob(ctx, "##pitch_knob", pitch, pitch_knob_min, pitch_knob_max, pitch_knob_size, 0)
    if reaper.ImGui_IsItemActive(ctx) then
      is_knob_dragging = true
    end
    if pitch_knob_changed then
      pitch = pitch_knob_value
      if playing_preview then RestartPreviewWithParams() end
    end
    -- 防止手动输入越界
    if pitch < pitch_knob_min then pitch = pitch_knob_min end
    if pitch > pitch_knob_max then pitch = pitch_knob_max end

    -- 音高输入框
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_PushItemWidth(ctx, 50)
    local rv3
    rv3, pitch = reaper.ImGui_InputDouble(ctx, "##Pitch", pitch) -- (ctx, "Pitch", pitch, 1, 12, "%.3f")
    reaper.ImGui_PopItemWidth(ctx)
    if rv3 then
      if playing_preview then RestartPreviewWithParams() end
    end

    -- 播放速率旋钮
    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_Text(ctx, "Rate:")
    reaper.ImGui_SameLine(ctx)
    local knob_size = 20
    local knob_changed, knob_value = ImGui_Knob(ctx, "##rate_knob", play_rate, rate_min, rate_max, knob_size, 1)
    if reaper.ImGui_IsItemActive(ctx) then
      is_knob_dragging = true
    end
    if knob_changed then
      local r1 = play_rate  -- 当前速率
      local r2 = knob_value -- 新速率
      local wave_pos

      -- 保存视觉时间，反推新的数据时间
      if select_start_time and select_end_time then
        local select_start_visual = select_start_time * r1
        local select_end_visual = select_end_time * r1
        select_start_time = select_start_visual / r2
        select_end_time = select_end_visual / r2
      end

      if playing_preview and reaper.CF_Preview_GetValue then
        local ok, pos = reaper.CF_Preview_GetValue(playing_preview, "D_POSITION")
        if ok then
          wave_pos = pos * r1 -- 播放时
        end
      else
        wave_pos = Wave.play_cursor * r1 -- 停止时
      end

      play_rate = r2
      Wave.play_cursor = wave_pos / play_rate -- 更新光标位置，确保视觉稳定
      if playing_preview then RestartPreviewWithParams(wave_pos) end
    end
    -- 双向同步（输入框改了也会更新旋钮，下次刷新界面）
    if play_rate < rate_min then play_rate = rate_min end
    if play_rate > rate_max then play_rate = rate_max end

    -- 播放速率输入框
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_PushItemWidth(ctx, 50)
    local rv4
    rv4, play_rate = reaper.ImGui_InputDouble(ctx, "##RatePlayrate", play_rate) -- (ctx, "Rate##RatePlayrate", play_rate, 0.05, 0.1, "%.3f")
    reaper.ImGui_PopItemWidth(ctx)
    if rv4 then
      local r1 = play_rate    -- 当前速率
      local r2 = new_play_rate -- 新速率
      local wave_pos

      if select_start_time and select_end_time then
        local select_start_visual = select_start_time * r1
        local select_end_visual = select_end_time * r1
        select_start_time = select_start_visual / r2
        select_end_time = select_end_visual / r2
      end

      if playing_preview and reaper.CF_Preview_GetValue then
        local ok, pos = reaper.CF_Preview_GetValue(playing_preview, "D_POSITION")
        if ok then
          wave_pos = pos * r1 -- 播放时
        end
      else
        wave_pos = Wave.play_cursor * r1 -- 停止时
      end

      play_rate = r2
      Wave.play_cursor = wave_pos / play_rate -- 更新光标位置，确保视觉稳定
      if playing_preview then RestartPreviewWithParams(wave_pos) end
    end

    -- 音量
    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_Text(ctx, "Volume:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_PushItemWidth(ctx, 200)
    local rv2 -- 0.0000000316 -150, 0.00001 -100
    local max_gain = dB_to_gain(max_db)
    rv2, volume = reaper.ImGui_SliderDouble(ctx, "##volume", volume, 0.0000000316, max_gain, string.format("%.2f dB", VAL2DB(volume)), reaper.ImGui_SliderFlags_Logarithmic())
    reaper.ImGui_PopItemWidth(ctx)
    if rv2 then
      if playing_preview then RestartPreviewWithParams() end
      reaper.SetExtState(EXT_SECTION, EXT_KEY_VOLUME, tostring(volume), true)
    end
    -- 右键归零
    if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
      volume = 1 -- 0dB
      if playing_preview then RestartPreviewWithParams() end
      reaper.SetExtState(EXT_SECTION, EXT_KEY_VOLUME, tostring(volume), true)
    end

    -- 设置弹窗
    reaper.ImGui_SameLine(ctx, nil, 10)
    if reaper.ImGui_Button(ctx, "Settings##Popup") then
      reaper.ImGui_OpenPopup(ctx, "Settings##Popup")
    end
    -- 支持 Ctrl+P 快捷键打开设置
    if (reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl()))
      and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_P()) then
      reaper.ImGui_OpenPopup(ctx, "Settings##Popup")
    end
    if reaper.ImGui_BeginPopupModal(ctx, "Settings##Popup", nil) then
      -- 字体大小
      reaper.ImGui_Text(ctx, "Font size:")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_PushItemWidth(ctx, -65)
      local changed_font, new_font_size = reaper.ImGui_SliderInt(ctx, "##font_size_slider", font_size, FONT_SIZE_MIN, FONT_SIZE_MAX, "%d px")
      reaper.ImGui_PopItemWidth(ctx)
      if changed_font then
        font_size = new_font_size
        reaper.SetExtState(EXT_SECTION, EXT_KEY_FONT_SIZE, tostring(font_size), true)
        MarkFontDirty()
      end
      reaper.ImGui_SameLine(ctx)
      HelpMarker("Adjust the font size for the interface. Range: 10-20 px.")

      -- 收集切换
      -- reaper.ImGui_Text(ctx, "Audio File Source:")
      -- local changed_collect_mode = false
      -- if reaper.ImGui_RadioButton(ctx, "None", collect_mode == -1) then
      --   if collect_mode ~= -1 then changed_collect_mode = true end
      --   collect_mode = -1 -- None/未选中选项
      -- end
      -- if reaper.ImGui_RadioButton(ctx, "Audio Assets", collect_mode == COLLECT_MODE_ITEMS) then
      --   if collect_mode ~= COLLECT_MODE_ITEMS then changed_collect_mode = true end
      --   collect_mode = COLLECT_MODE_ITEMS
      -- end
      -- if reaper.ImGui_RadioButton(ctx, "Source Media", collect_mode == COLLECT_MODE_RPP) then
      --   if collect_mode ~= COLLECT_MODE_RPP then changed_collect_mode = true end
      --   collect_mode = COLLECT_MODE_RPP
      -- end
      -- if reaper.ImGui_RadioButton(ctx, "Project Directory", collect_mode == COLLECT_MODE_DIR) then
      --   if collect_mode ~= COLLECT_MODE_DIR then changed_collect_mode = true end
      --   collect_mode = COLLECT_MODE_DIR
      -- end
      -- if reaper.ImGui_RadioButton(ctx, "Media Items", collect_mode == COLLECT_MODE_ALL_ITEMS) then
      --   if collect_mode ~= COLLECT_MODE_ALL_ITEMS then changed_collect_mode = true end
      --   collect_mode = COLLECT_MODE_ALL_ITEMS
      -- end
      -- if reaper.ImGui_RadioButton(ctx, "This Computer", collect_mode == COLLECT_MODE_TREE) then
      --   if collect_mode ~= COLLECT_MODE_TREE then changed_collect_mode = true end
      --   collect_mode = COLLECT_MODE_TREE
      -- end
      -- if changed_collect_mode and collect_mode >= 0 then
      --   CollectFiles()
      -- end

      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, "Double-Click Action:")
      if reaper.ImGui_RadioButton(ctx, "Insert media file to arrange", doubleclick_action == DOUBLECLICK_INSERT) then
        doubleclick_action = DOUBLECLICK_INSERT
      end
      if reaper.ImGui_RadioButton(ctx, "Preview media", doubleclick_action == DOUBLECLICK_PREVIEW) then
        doubleclick_action = DOUBLECLICK_PREVIEW
      end
      if reaper.ImGui_RadioButton(ctx, "Do nothing", doubleclick_action == DOUBLECLICK_NONE) then
        doubleclick_action = DOUBLECLICK_NONE
      end

      reaper.ImGui_Separator(ctx)
      local changed
      changed, auto_play_selected = reaper.ImGui_Checkbox(ctx, "Auto-play selected media", auto_play_selected)

      -- 更改速率是否保持音高
      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, "Playback Settings:")
      local changed_pp
      changed_pp, preserve_pitch = reaper.ImGui_Checkbox(ctx, "Preserve pitch when changing rate", preserve_pitch)
      if changed_pp and playing_preview and reaper.CF_Preview_SetValue then
        reaper.CF_Preview_SetValue(playing_preview, "B_PPITCH", preserve_pitch and 1 or 0)
      end

      -- 波形预览设置
      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, "Waveform Preview Settings:")

      -- 波形预览自动滚屏
      local changed_scroll, new_scroll = reaper.ImGui_Checkbox(ctx, "Auto scroll waveform during playback", auto_scroll_enabled)
      if changed_scroll then
        auto_scroll_enabled = new_scroll
      end

      -- 背景不透明度
      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, "Window background alpha:")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_PushItemWidth(ctx, -65)
      local changed, new_bg_alpha = reaper.ImGui_InputDouble(ctx, "##bg_alpha", bg_alpha, 0.05, 0.1, "%.2f")
      reaper.ImGui_PopItemWidth(ctx)
      if changed then
        -- 范围在 0 ~ 1
        bg_alpha = math.max(0, math.min(1, new_bg_alpha or 1))
      end

      -- Peaks
      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, "Peaks meter channels:")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_PushItemWidth(ctx, -65)
      local changed_peaks, new_peaks = reaper.ImGui_InputDouble(ctx, "##peaks_input", peak_chans, 1, 10, "%.0f")
      reaper.ImGui_PopItemWidth(ctx)
      if changed_peaks then
        peak_chans = math.floor((new_peaks or 2) + 0.5)
        if peak_chans < 2 then peak_chans = 2 end
        if peak_chans > 128 then peak_chans = 128 end
        reaper.SetExtState(EXT_SECTION, EXT_KEY_PEAKS, tostring(peak_chans), true)
      end
      reaper.ImGui_SameLine(ctx)
      HelpMarker("Number of peak meter channels to show. Range: 2~128.")

      -- 播放控件设置
      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, "Playback Control Settings:")

      -- 最大音量dB
      reaper.ImGui_Text(ctx, "Max Volume (dB):")
      reaper.ImGui_PushItemWidth(ctx, -65)
      reaper.ImGui_SameLine(ctx)
      local changed_maxdb, new_max_db = reaper.ImGui_InputDouble(ctx, "##Max Volume (dB)", max_db, 1, 5, "%.2f")
      reaper.ImGui_PopItemWidth(ctx)
      if changed_maxdb then
        -- 可根据需要限制范围
        if new_max_db < 0 then new_max_db = 0 end
        if new_max_db > 24 then new_max_db = 24 end
        max_db = new_max_db
      end
      reaper.ImGui_SameLine(ctx)
      HelpMarker("Set the maximum output volume, in dB. Default: 12.")

      -- 音高旋钮最小值
      reaper.ImGui_Text(ctx, "Pitch Knob Min:")
      reaper.ImGui_PushItemWidth(ctx, -65)
      reaper.ImGui_SameLine(ctx)
      local changed_pmin, new_pmin = reaper.ImGui_InputDouble(ctx, "##Pitch Knob Min", pitch_knob_min, 1, 2, "%.2f")
      reaper.ImGui_PopItemWidth(ctx)
      if changed_pmin then
        -- 限制最大不超过最大值
        if new_pmin > pitch_knob_max then new_pmin = pitch_knob_max end
        pitch_knob_min = new_pmin
      end

      -- 音高旋钮最大值
      reaper.ImGui_Text(ctx, "Pitch Knob Max:")
      reaper.ImGui_PushItemWidth(ctx, -65)
      reaper.ImGui_SameLine(ctx)
      local changed_pmax, new_pmax = reaper.ImGui_InputDouble(ctx, "##Pitch Knob Max", pitch_knob_max, 1, 2, "%.2f")
      reaper.ImGui_PopItemWidth(ctx)
      if changed_pmax then
        if new_pmax < pitch_knob_min then new_pmax = pitch_knob_min end
        pitch_knob_max = new_pmax
      end

      -- 速率旋钮最小值
      reaper.ImGui_Text(ctx, "Rate Min:")
      reaper.ImGui_PushItemWidth(ctx, -65)
      reaper.ImGui_SameLine(ctx)
      local changed_rmin, new_rmin = reaper.ImGui_InputDouble(ctx, "##Rate Min", rate_min, 0.01, 0.1, "%.2f")
      reaper.ImGui_PopItemWidth(ctx)
      if changed_rmin then
        if new_rmin < 0.01 then new_rmin = 0.01 end
        if new_rmin > rate_max then new_rmin = rate_max end
        rate_min = new_rmin
      end

      -- 速率旋钮最大值
      reaper.ImGui_Text(ctx, "Rate Max:")
      reaper.ImGui_PushItemWidth(ctx, -65)
      reaper.ImGui_SameLine(ctx)
      local changed_rmax, new_rmax = reaper.ImGui_InputDouble(ctx, "##Rate Max", rate_max, 0.01, 0.1, "%.2f")
      reaper.ImGui_PopItemWidth(ctx)
      if changed_rmax then
        if new_rmax < rate_min then new_rmax = rate_min end
        rate_max = new_rmax
      end

      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, "Waveform Cache Folder:")
      reaper.ImGui_PushItemWidth(ctx, -65)
      local changed_cache_dir, new_cache_dir = reaper.ImGui_InputText(ctx, "##cache_dir", cache_dir, 512)
      reaper.ImGui_PopItemWidth(ctx)
      if changed_cache_dir then
        cache_dir = new_cache_dir
        reaper.SetExtState(EXT_SECTION, EXT_KEY_CACHE_DIR, cache_dir, true)
      end
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, "Browse##SelectCacheDir") then
        local rv, out = reaper.JS_Dialog_BrowseForFolder("Select a directory:", cache_dir)
        if rv == 1 and out and out ~= "" then
          cache_dir = out
          if not cache_dir:match("[/\\]$") then cache_dir = cache_dir .. "/" end
          reaper.SetExtState(EXT_SECTION, EXT_KEY_CACHE_DIR, cache_dir, true)
        end
      end

      -- 关闭按钮
      reaper.ImGui_Separator(ctx)
      if reaper.ImGui_Button(ctx, "Save and Close##Rate_close") then
        SaveSettings()
        reaper.ImGui_CloseCurrentPopup(ctx)
      end

      -- 默认值定义
      local DEFAULTS = {
        collect_mode = -1,
        doubleclick_action = DOUBLECLICK_NONE,
        auto_play_selected = true,
        preserve_pitch = true,
        auto_scroll_enabled = false,
        bg_alpha = 1.0,
        peak_chans = 6,
        font_size = 14,
        max_db = 12,         -- 音量最大值
        pitch_knob_min = -6, -- 音高旋钮最低
        pitch_knob_max = 6,  -- 音高旋钮最高
        rate_min = 0.25,     -- 速率旋钮最低
        rate_max = 4.0,      -- 速率旋钮最高
        cache_dir = DEFAULT_CACHE_DIR,
      }

      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, "Reset##Settings_reset") then
        -- 恢复各项设置为默认值
        collect_mode = DEFAULTS.collect_mode
        doubleclick_action = DEFAULTS.doubleclick_action
        auto_play_selected = DEFAULTS.auto_play_selected
        preserve_pitch = DEFAULTS.preserve_pitch
        bg_alpha = DEFAULTS.bg_alpha
        peak_chans = DEFAULTS.peak_chans
        font_size = DEFAULTS.font_size -- 字体大小
        -- 恢复播放控件设置
        max_db = DEFAULTS.max_db
        pitch_knob_min = DEFAULTS.pitch_knob_min
        pitch_knob_max = DEFAULTS.pitch_knob_max
        rate_min = DEFAULTS.rate_min
        rate_max = DEFAULTS.rate_max
        cache_dir = DEFAULTS.cache_dir
        auto_scroll_enabled = DEFAULTS.auto_scroll_enabled
        -- 保存设置到ExtState
        reaper.SetExtState(EXT_SECTION, EXT_KEY_PEAKS, tostring(peak_chans), true)
        reaper.SetExtState(EXT_SECTION, EXT_KEY_FONT_SIZE, tostring(font_size), true)
        reaper.SetExtState(EXT_SECTION, EXT_KEY_CACHE_DIR, tostring(cache_dir), true)
        reaper.SetExtState(EXT_SECTION, EXT_KEY_AUTOSCROLL, tostring(auto_scroll_enabled and 1 or 0), true)
        MarkFontDirty()
        CollectFiles()
      end
      if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Reset all settings to default values")
      end

      reaper.ImGui_EndPopup(ctx)
    end

    -- 电平表通道选项
    -- reaper.ImGui_Separator(ctx)
    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_Text(ctx, "Peaks:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 100)
    local rv5, new_peaks = reaper.ImGui_InputInt(ctx, '##Peaks', peak_chans, 1, 1)
    if rv5 then
      peak_chans = math.max(2, math.min(128, new_peaks or 2))
    end
    -- reaper.ImGui_SameLine(ctx)
    -- HelpMarker("Open settings to adjust playback and audio file collection options.\n\n" .. 
    -- "Audio file source modes:\n" ..
    -- "1. From Items (Default):\n" ..
    -- "   Only lists audio files actually used by items in the current project.\n" ..
    -- "2. From RPP (All in project state):\n" ..
    -- "   Lists all audio files referenced anywhere in the project file, including those not currently placed on tracks.\n" ..
    -- "3. From Project Directory:\n" ..
    -- "   Scans and lists all audio files in the project directory, whether or not they are used or referenced in the project.\n\n" ..
    -- "You can change file source and enable pitch preservation.")

    -- 插入选区音频到REAPER
    reaper.ImGui_SameLine(ctx, nil, 10)
    if select_start_time and select_end_time and math.abs(select_end_time - select_start_time) > 0.01 then
      local cur_info = files_idx_cache and files_idx_cache[selected_row]
      if not cur_info then
        cur_info = last_selected_info
      end
      local do_insert = false
      -- Shift+S
      local shift = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftShift()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightShift())
      if shift and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_S()) then
        do_insert = true
      end
      if reaper.ImGui_Button(ctx, "Insert Selection Into Project") then
        do_insert = true
      end
      if do_insert and cur_info and cur_info.path then
        InsertSelectedAudioSection(cur_info.path, select_start_time * play_rate, select_end_time * play_rate, cur_info.section_offset or 0, true)
      end
      if reaper.ImGui_IsItemHovered(ctx) then
          reaper.ImGui_BeginTooltip(ctx)
          reaper.ImGui_Text(ctx, "Shift+S to insert the selected audio section into the project.")
          reaper.ImGui_EndTooltip(ctx)
      end
    end

    -- 竖直电平条 mini
    reaper.ImGui_SameLine(ctx, nil, 10)
    local bar_height = reaper.ImGui_GetFrameHeight(ctx) -- base_height -- 或 reaper.ImGui_GetFrameHeight(ctx)
    local bar_width = 7
    local spacing = 2
    local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    for i = 0, peak_chans - 1 do
      local peak = 0
      if playing_preview and reaper.CF_Preview_GetPeak then
        local valid, value = reaper.CF_Preview_GetPeak(playing_preview, i)
        if valid then peak = value end
      end
      -- 画竖直电平条（底灰、顶色高亮）
      local bar_x1 = x + i * (bar_width + spacing)
      local bar_x2 = bar_x1 + bar_width
      local bar_y1 = y
      local bar_y2 = y + bar_height
      -- 先画底
      reaper.ImGui_DrawList_AddRectFilled(draw_list, bar_x1, bar_y1, bar_x2, bar_y2, 0x222222ff)
      -- 再画峰值
      local peak_y = bar_y2 - peak * bar_height
      reaper.ImGui_DrawList_AddRectFilled(draw_list, bar_x1, peak_y, bar_x2, bar_y2, 0x33dd33ff) -- 0x33dd33ff
    end
    -- Dummy 占位
    reaper.ImGui_Dummy(ctx, peak_chans * (bar_width + spacing), bar_height)

    -- 横向分割条
    reaper.ImGui_InvisibleButton(ctx, "##h_splitter", avail_x, splitter_w)
    local active  = reaper.ImGui_IsItemActive(ctx)
    local hovered = reaper.ImGui_IsItemHovered(ctx)
    local mx, my = reaper.ImGui_GetMousePos(ctx)
    local wx, wy = reaper.ImGui_GetWindowPos(ctx)

    -- 鼠标按下时记录起始值
    if reaper.ImGui_IsItemActivated(ctx) then
      h_splitter_drag = true
      h_splitter_start_mouse_y = my
      h_splitter_start_offset  = img_h_offset
    end

    -- 拖动中，反向更新 img_h_offset
    if h_splitter_drag and active then
      local delta = my - h_splitter_start_mouse_y
      local new_off = h_splitter_start_offset - delta
      img_h_offset = math.max(-70, math.min(300, new_off))
      reaper.SetExtState(EXT_SECTION, "ImgHOffset", tostring(img_h_offset), true)
    end

    -- 松开时结束拖拽
    if not active then
      h_splitter_drag = false
    end

    -- 绘制分割条
    local dl = reaper.ImGui_GetWindowDrawList(ctx)
    local x1,y1 = reaper.ImGui_GetItemRectMin(ctx)
    local x2,y2 = reaper.ImGui_GetItemRectMax(ctx)
    local col = hovered and 0x00AFFF88 or 0x77777744
    reaper.ImGui_DrawList_AddRectFilled(dl, x1, y1, x2, y2, col)

    -- 光标样式
    if hovered or active then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeNS())
    end

    -- 波形预览
    img_h = base_img_h + img_h_offset -- 补偿高度
    -- reaper.ImGui_Separator(ctx)
    local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
    if reaper.ImGui_BeginChild(ctx, "waveform", avail_w, img_h + timeline_height+9) then -- 微调波形宽度（计划预留右侧空间-75用于放置专辑图片）和高度（补偿时间线高度+时间线间隔9）
      local pw_min_x, pw_min_y = reaper.ImGui_GetItemRectMin(ctx)
      local pw_max_x, max_y = reaper.ImGui_GetItemRectMax(ctx)
      local pw_region_w = math.max(64, math.floor(pw_max_x - pw_min_x))

      local view_len = Wave.src_len / Wave.zoom
      local window_start = Wave.scroll
      local window_end = Wave.scroll + view_len

      -- 获取峰值
      local cur_info = files_idx_cache and files_idx_cache[selected_row]
      if not cur_info then
        cur_info = last_selected_info
      end
      if cur_info then
        -- 限制只有在选中表格项或双击预览播放时加载波形，但效果不佳。目前默认只要选中就会加载波形。
        -- if (auto_play_selected and last_selected_row ~= selected_row) or (doubleclick_action == DOUBLECLICK_PREVIEW and reaper.ImGui_IsMouseDoubleClicked(ctx, 0)) then
        -- 获取完整源音频及区段参数
        local section_offset = cur_info.section_offset or 0
        local section_length = cur_info.section_length or 0

        -- 用完整源音频路径
        local root_src = cur_info.source
        if root_src and type(root_src) == "userdata" then
          if reaper.GetMediaSourceType(root_src, "") == "SECTION" then
            if GetRootSource then
              root_src = GetRootSource(cur_info.source)
            end
          end
        end
        local root_path
        if root_src and type(root_src) == "userdata" then
          root_path = reaper.GetMediaSourceFileName(root_src, "")
        else
          root_path = cur_info.path
        end
        local cur_key = (root_path or cur_info.path) .. "|" .. tostring(section_offset) .. "|" .. tostring(section_length)
        if (not peaks)
          or (last_wave_info ~= cur_key)
          or (last_pixel_cnt ~= pw_region_w)
          or (last_view_len ~= view_len)
          or (last_scroll ~= Wave.scroll)
        then
          local cache = LoadWaveformCache(root_path)
          if not cache then
            local peaks_raw, pixel_cnt_raw, src_len_raw, channel_count_raw = GetPeaksForInfo(
              { path = root_path }, wf_step, CACHE_PIXEL_WIDTH, 0, nil)
            SaveWaveformCache(root_path, {
              peaks=peaks_raw, pixel_cnt=pixel_cnt_raw, channel_count=channel_count_raw, src_len=src_len_raw
            })
            cache = {peaks=peaks_raw, pixel_cnt=pixel_cnt_raw, channel_count=channel_count_raw, src_len=src_len_raw}
          end

          if collect_mode == COLLECT_MODE_ALL_ITEMS and section_length > 0 then
            -- 区段音频
            local zoom = Wave.zoom or 1
            local section_len = section_length
            local visible_len = math.max(section_len / zoom, 0.01)
            if visible_len > section_len then visible_len = section_len end

            local max_scroll = math.max(0, section_len - visible_len)
            local scroll = math.max(0, math.min(Wave.scroll or 0, max_scroll))

            window_start = section_offset + scroll
            window_end = window_start + visible_len
            Wave.src_len = section_len -- 始终用区段长度
          else
            -- 全音频
            local audio_len = cache.src_len
            local zoom = Wave.zoom or 1
            local visible_len = math.max(audio_len / zoom, 0.01)
            if visible_len > audio_len then visible_len = audio_len end

            local max_scroll = math.max(0, audio_len - visible_len)
            local scroll = math.max(0, math.min(Wave.scroll or 0, max_scroll))

            window_start = scroll
            window_end = window_start + visible_len
            Wave.src_len = audio_len -- 始终用源音频长度
          end

          peaks, pixel_cnt, _, channel_count = RemapWaveformToWindow(cache, pw_region_w, window_start, window_end)
          last_wave_info = cur_key
          last_pixel_cnt = pw_region_w
          last_view_len = view_len
          last_scroll = Wave.scroll
        end
        -- end
      end

      DrawWaveformInImGui(ctx, peaks, pw_region_w, img_h, src_len, channel_count)
      if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_TextInput())
      end
      -- 空格播放
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Space()) then
        if playing_preview then
          StopPreview()
          -- 强制播放光标复位
          if last_play_cursor_before_play then
            Wave.play_cursor = last_play_cursor_before_play
          end
        else
          PlayFromCursor(cur_info)
        end
      end

      -- 右方向键播放
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_RightArrow()) then
        PlayFromCursor(cur_info)
      end

      -- 左方向键停止
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_LeftArrow()) then
        StopPreview()
        if last_play_cursor_before_play then
          Wave.play_cursor = last_play_cursor_before_play
        end
      end

      -- 小键盘 + 号放大波形
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_KeypadAdd()) then
        local prev_zoom = Wave.zoom
        Wave.zoom = math.min(Wave.zoom * 1.25, 16)
        if Wave.zoom ~= prev_zoom then
          local old_view_len = Wave.src_len / prev_zoom
          local center = Wave.scroll + old_view_len / 2
          local new_view_len = Wave.src_len / Wave.zoom
          Wave.scroll = center - new_view_len / 2
          if Wave.scroll < 0 then Wave.scroll = 0 end
          local max_scroll = math.max(0, Wave.src_len - new_view_len)
          if Wave.scroll > max_scroll then Wave.scroll = max_scroll end
        end
      end

      -- 小键盘 - 号缩小波形
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_KeypadSubtract()) then
        local prev_zoom = Wave.zoom
        Wave.zoom = math.max(Wave.zoom / 1.25, 1)
        if Wave.zoom ~= prev_zoom then
          local old_view_len = Wave.src_len / prev_zoom
          local center = Wave.scroll + old_view_len / 2
          local new_view_len = Wave.src_len / Wave.zoom
          Wave.scroll = center - new_view_len / 2
          if Wave.scroll < 0 then Wave.scroll = 0 end
          local max_scroll = math.max(0, Wave.src_len - new_view_len)
          if Wave.scroll > max_scroll then Wave.scroll = max_scroll end
        end
      end

      -- 单击自动播放，选中项变化时触发
      if auto_play_selected and selected_row and selected_row > 0 and files_idx_cache then
        if last_selected_row ~= selected_row then
          local cur_info = files_idx_cache[selected_row]
          if cur_info then
            PlayFromStart(cur_info)
            last_selected_info = {}
            for k,v in pairs(cur_info) do last_selected_info[k]=v end
          end
          last_selected_row = selected_row
        end
      else
        last_selected_row = selected_row
      end

      local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)
      local min_x, min_y = reaper.ImGui_GetItemRectMin(ctx)
      local max_x, max_y = reaper.ImGui_GetItemRectMax(ctx)
      local region_w = max_x - min_x

      if reaper.ImGui_IsItemHovered(ctx) then
        local rel_x = mouse_x - min_x
        local frac = rel_x / region_w
        frac = math.max(0, math.min(1, frac))
        -- 速率变化时调整光标位置
        local visible_len = Wave.src_len / Wave.zoom
        local mouse_time_visual = Wave.scroll + frac * visible_len
        local mouse_time = mouse_time_visual / play_rate

        -- 鼠标滚轮缩放
        if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl()) then
          -- Ctrl+鼠标滚轮纵向缩放波形
          local mouse_wheel = reaper.ImGui_GetMouseWheel(ctx)
          if mouse_wheel ~= 0 then
            waveform_vertical_zoom = waveform_vertical_zoom + (mouse_wheel > 0 and 0.1 or -0.1)
            if waveform_vertical_zoom < VERTICAL_ZOOM_MIN then waveform_vertical_zoom = VERTICAL_ZOOM_MIN end
            if waveform_vertical_zoom > VERTICAL_ZOOM_MAX then waveform_vertical_zoom = VERTICAL_ZOOM_MAX end

            show_vertical_zoom = true
            show_vertical_zoom_timer = reaper.time_precise() -- 记录当前时间
          end
        else
          -- 鼠标滚轮横向缩放
          local mouse_wheel = reaper.ImGui_GetMouseWheel(ctx)
          if mouse_wheel ~= 0 then
            local min_zoom, max_zoom = 1, 16

            if (mouse_wheel > 0 and Wave.zoom >= max_zoom) or (mouse_wheel < 0 and Wave.zoom <= min_zoom) then
              -- 判断是否到缩放边界
            else
              local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)
              local min_x, min_y = reaper.ImGui_GetItemRectMin(ctx)
              local max_x, max_y = reaper.ImGui_GetItemRectMax(ctx)
              local region_w = max_x - min_x

              -- 获取当前鼠标位置在波形上的时间
              local rel_x = mouse_x - min_x
              local frac = rel_x / region_w
              frac = math.max(0, math.min(1, frac))
              local mouse_time = Wave.scroll + frac * (Wave.src_len / Wave.zoom)

              -- 向上滚动放大
              if mouse_wheel > 0 then
                Wave.zoom = math.min(Wave.zoom * 1.25, 16) -- 最大放大倍数16
              -- 向下滚动缩小
              else
                Wave.zoom = math.max(Wave.zoom / 1.25, 1) -- 最小缩小倍数1
              end

              -- 缩放后，保持当前鼠标位置不变
              local view_len = Wave.src_len / Wave.zoom
              Wave.scroll = mouse_time - frac * view_len

              -- 保证滚动不会超出音频范围
              if Wave.scroll < 0 then Wave.scroll = 0 end
              if Wave.scroll > Wave.src_len - view_len then Wave.scroll = Wave.src_len - view_len end

              -- 最小缩放时，显示整条音频
              if Wave.zoom == 1 then
                Wave.scroll = 0
              end

              last_view_len = nil
            end
          end
        end

        -- 鼠标左键点击
        if reaper.ImGui_IsMouseClicked(ctx, 0) and not is_knob_dragging then
          if has_selection() then
            if mouse_in_selection() then
              pending_clear_selection = false
            else
              pending_clear_selection = true -- 只挂起，不做任何清空
            end
          else
            local mouse_time_visual = Wave.scroll + frac * visible_len
            local mouse_time = mouse_time_visual / play_rate
            selecting = true
            drag_start_x = mouse_x
            select_start_time = mouse_time
            select_end_time = mouse_time
            pending_clear_selection = false
          end
        end

        -- 框选/拖拽
        if selecting and reaper.ImGui_IsMouseDown(ctx, 0) and not is_knob_dragging then
          local mouse_time_visual = Wave.scroll + frac * visible_len
          local mouse_time = mouse_time_visual / play_rate
          select_end_time = mouse_time
        end

        -- 框选松开
        if selecting and not reaper.ImGui_IsMouseDown(ctx, 0) and not is_knob_dragging then
          selecting = false
          if has_selection() then
            local select_min = math.min(select_start_time, select_end_time)
            just_selected_range = true
            Wave.play_cursor = select_min
            wf_play_start_cursor = select_min
            if playing_preview then
              if reaper.CF_Preview_SetValue then -- 移动播放位置
                reaper.CF_Preview_SetValue(playing_preview, "D_POSITION", select_min)
              end
              -- if reaper.CF_Preview_SetValue then
              --   PlayFromCursor(cur_info)
              -- end
            end
          end
        end

        -- 框选自动跳转到起始位置
        if selecting and not reaper.ImGui_IsMouseDown(ctx, 0) and not is_knob_dragging then
          selecting = false
          -- 框选松开时自动跳光标
          if select_start_time and select_end_time and math.abs(select_end_time - select_start_time) > 0.01 then
            local select_min = math.min(select_start_time, select_end_time)
            Wave.play_cursor = select_min
            wf_play_start_cursor = select_min
            if playing_preview then
              -- 直接设置播放位置
              if reaper.CF_Preview_SetValue then
                PlayFromCursor(cur_info) -- 从框选区域的起始位置开始播放
              end
            end
          end
        end

        -- 框选松开后自动播放并跳转回到起始位置待命 未激活LOOP时
        if playing_preview and select_start_time and select_end_time and math.abs(select_end_time - select_start_time) > 0.01 and not loop_enabled then
          local ok, pos = reaper.CF_Preview_GetValue(playing_preview, "D_POSITION")
          if ok then
            local select_max = math.max(select_start_time, select_end_time)
            local select_min = math.min(select_start_time, select_end_time)
            if prev_play_cursor and prev_play_cursor >= select_min and prev_play_cursor <= select_max then
              if pos >= select_max then
                StopPreview(cur_info)
                Wave.play_cursor = select_min
                wf_play_start_cursor = select_min
              end
            end
            prev_play_cursor = pos
          end
        end

        -- 选区拖拽到REAPER - 框选/拖拽释放是否在选区内
        if dragging_selection and reaper.ImGui_IsMouseReleased(ctx, 0) then -- 松开时仍在本窗口
          if reaper.ImGui_IsWindowHovered(ctx) then
            dragging_selection = nil
          end
        end

        -- 鼠标释放时，鼠标定位/清空选区
        if not selecting and reaper.ImGui_IsMouseReleased(ctx, 0) and reaper.ImGui_IsItemHovered(ctx) and not is_knob_dragging then
          if just_selected_range then
            just_selected_range = false  -- 跳过这次，防止和画选区的行为冲突
          else
            -- 重新计算mouse_time，确保为释放时的准确位置
            local mouse_x = select(1, reaper.ImGui_GetMousePos(ctx))
            local min_x = select(1, reaper.ImGui_GetItemRectMin(ctx))
            local max_x = select(1, reaper.ImGui_GetItemRectMax(ctx))
            local region_w = max_x - min_x
            local rel_x = mouse_x - min_x
            local frac = rel_x / region_w
            frac = math.max(0, math.min(1, frac))
            local visible_len = Wave.src_len / Wave.zoom
            local mouse_time_visual = Wave.scroll + frac * visible_len
            local mouse_time = mouse_time_visual / play_rate

            if select_start_time and select_end_time and math.abs(select_end_time - select_start_time) > 0.01 then
              local select_min = math.min(select_start_time, select_end_time)
              local select_max = math.max(select_start_time, select_end_time)
              if mouse_time >= select_min and mouse_time <= select_max then
                -- 选区内 - 定位
                Wave.play_cursor = mouse_time
                wf_play_start_cursor = mouse_time
                if playing_preview then
                  StopPreview()
                  PlayFromCursor(cur_info)
                end
              else
                -- 选区外 - 清空选区
                select_start_time = nil
                select_end_time = nil
                Wave.play_cursor = mouse_time
                wf_play_start_cursor = mouse_time
                if playing_preview then
                  StopPreview()
                  PlayFromCursor(cur_info)
                end
              end
            else
              -- 无选区 - 正常定位
              Wave.play_cursor = mouse_time
              wf_play_start_cursor = mouse_time
              if playing_preview then
                StopPreview()
                PlayFromCursor(cur_info)
              end
            end
          end
        end
      end

      -- 切换源时清除选区高亮和重置波形的缩放与滚动位置
      if selected_row ~= last_audio_idx then
        select_start_time = nil
        select_end_time = nil
        last_audio_idx = selected_row
          Wave.zoom = 1
          Wave.scroll = 0
          waveform_vertical_zoom = 1
      end

      -- 选区高亮 - 框选颜色
      if select_start_time and select_end_time and math.abs(select_end_time - select_start_time) > 0.01 then
        -- 速率变化时调整选区位置
        local visible_len = Wave.src_len / Wave.zoom
        local a = (select_start_time * play_rate - Wave.scroll) / visible_len * region_w + min_x
        local b = (select_end_time * play_rate - Wave.scroll) / visible_len * region_w + min_x
        local dl = reaper.ImGui_GetWindowDrawList(ctx)
        reaper.ImGui_DrawList_AddRectFilled(dl, a, min_y, b, max_y, 0x294A7A44 ) -- 0x192e4680 0x1844FF44
      end

      -- loop循环选区
      local has_selection = select_start_time and select_end_time and math.abs(select_end_time - select_start_time) > 0.01
      if playing_preview and loop_enabled and has_selection then
        local sel_min = math.min(select_start_time, select_end_time)
        local sel_max = math.max(select_start_time, select_end_time)
        if Wave.play_cursor >= sel_max then
          StopPreview()
          Wave.play_cursor = sel_min
          PlayFromCursor(cur_info)
        end
      end

      -- 绘制播放光标
      if Wave.play_cursor and Wave.src_len and Wave.zoom and Wave.zoom ~= 0 then
        -- 速率变化时调整光标位置
        local adjusted_play_cursor = Wave.play_cursor * play_rate
        local px = (adjusted_play_cursor - Wave.scroll) / (Wave.src_len / Wave.zoom) * region_w + min_x
        local dl = reaper.ImGui_GetWindowDrawList(ctx)
        reaper.ImGui_DrawList_AddLine(dl, px, min_y, px, max_y, 0x808080FF, 1) -- 0xFF2222FF
      end

      -- 波形预览自动滚屏
      if playing_preview and auto_scroll_enabled then
        -- 当前视野长度（秒）
        local view_len = Wave.src_len / Wave.zoom
        -- 如果光标超出可见区域，自动滚动窗口
        if Wave.play_cursor < Wave.scroll or Wave.play_cursor > (Wave.scroll + view_len) then
          Wave.scroll = math.max(0, math.min(Wave.src_len - view_len, Wave.play_cursor - view_len / 2))
        end
      end

      -- 选区循环播放支持
      if playing_preview and reaper.CF_Preview_GetValue then
        local ok, position = reaper.CF_Preview_GetValue(playing_preview, "D_POSITION")
        if ok then
          Wave.play_cursor = position
          prev_play_cursor = Wave.play_cursor
        end
      else
        prev_play_cursor = nil
      end

      local selection_exists = cur_info and has_selection and select_start_time and select_end_time and math.abs(select_end_time - select_start_time) > 0.01
      -- 鼠标样式切换
      if reaper.ImGui_IsItemHovered(ctx) and selection_exists then
        if selecting and reaper.ImGui_IsMouseDown(ctx, 0) and not is_knob_dragging then
          -- 正在框选区域
          reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_TextInput())
        -- elseif reaper.ImGui_IsMouseDown(ctx, 0) and not selecting then
        --   reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeAll())
        else
          -- 有选区且不在框选，允许拖拽到REAPER
          reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeAll())
        end
      end

      -- 选区拖拽到REAPER
      if selection_exists then
        if reaper.ImGui_BeginDragDropSource(ctx) then
          reaper.ImGui_Text(ctx, "Drag selection to REAPER to insert")
          -- 判断区段还是源音频
          local drag_path = cur_info.path
          local start_time = math.min(select_start_time, select_end_time) * play_rate
          local end_time = math.max(select_start_time, select_end_time) * play_rate
          -- 如果是SECTION，直接用区段路径和相对区段起点时间
          if cur_info.source and type(cur_info.source) == "userdata" then
            if reaper.GetMediaSourceType(cur_info.source, "") == "SECTION" then
              drag_path = cur_info.source
              start_time = start_time
              end_time = end_time
            end
          end

          dragging_selection = {
            path = drag_path,
            start_time = start_time,
            end_time = end_time,
            section_offset = cur_info.section_offset or 0
          }
          reaper.ImGui_EndDragDropSource(ctx)
        end

        -- 拖拽释放检测
        if dragging_selection then
          reaper.PreventUIRefresh(1)
          local window, _, _ = reaper.BR_GetMouseCursorContext()
          if not reaper.ImGui_IsMouseDown(ctx, 0) then
            if window == "arrange" then
              local old_cursor = reaper.GetCursorPosition()
              local insert_time = reaper.BR_GetMouseCursorContext_Position()
              reaper.SetEditCurPos(insert_time, false, false)
              local tr = reaper.BR_GetMouseCursorContext_Track()
              if tr then reaper.SetOnlyTrackSelected(tr) end
              path = GetPhysicalPath(cur_info and cur_info.path)
              InsertSelectedAudioSection(path, dragging_selection.start_time, dragging_selection.end_time, dragging_selection.section_offset, false)
              reaper.SetEditCurPos(old_cursor, false, false) -- 恢复光标到插入前
            end
            dragging_selection = nil -- 不管插入与否都要清除
          end
          reaper.PreventUIRefresh(-1)
        end
      end

      -- 绘制时间线
      local view_start = Wave.scroll
      local view_end = math.min(Wave.scroll + Wave.src_len / Wave.zoom, Wave.src_len)
      if Wave.src_len and Wave.src_len > 0 then
        DrawTimeLine(ctx, Wave, view_start, view_end)
      end
      -- reaper.ImGui_Dummy(ctx, 0, timeline_height) -- 此处由于在Child内可以不用加，加了也无效

      reaper.ImGui_EndChild(ctx)

      -- 放大缩小按钮和水平滚动条
      local view_len = Wave.src_len / Wave.zoom
      local max_scroll = math.max(0, Wave.src_len - view_len)
      local cursor_pos = Wave.play_cursor or 0
      local label_fmt

      local range_start, range_end
      if select_start_time and select_end_time and math.abs(select_end_time - select_start_time) > 0.01 then
        label_fmt = "Selection: %s ~ %s | %s / %s"
        range_start = math.min(select_start_time, select_end_time) * play_rate -- 速率变化时调整选区时间位置
        range_end = math.max(select_start_time, select_end_time) * play_rate -- 速率变化时调整选区时间位置
      else
        label_fmt = "View range: %s ~ %s | %s / %s"
        range_start = view_start * play_rate -- 速率变化时调整选区时间位置
        range_end = view_end
      end

      reaper.ImGui_SetNextItemWidth(ctx, -65)
        local label = string.format(label_fmt,
        reaper.format_timestr(range_start, ""),
        reaper.format_timestr(range_end, ""),
        reaper.format_timestr(cursor_pos, ""), -- 速率变化时调整光标时间位置
        reaper.format_timestr(Wave.src_len, "")
      )
      local changed, new_scroll = reaper.ImGui_SliderDouble(ctx, "##scrollbar", Wave.scroll, 0, max_scroll, label)

      if changed then
        Wave.scroll = new_scroll
      end
      if Wave.scroll < 0 then Wave.scroll = 0 end
      if Wave.scroll > max_scroll then Wave.scroll = max_scroll end

      -- + 按钮
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, "+", 20) then  -- Zoom In
        local prev_zoom = Wave.zoom
        Wave.zoom = math.min(Wave.zoom * 1.25, 16)
        if Wave.zoom ~= prev_zoom then
          local old_view_len = Wave.src_len / prev_zoom
          local center = Wave.scroll + old_view_len / 2
          local new_view_len = Wave.src_len / Wave.zoom
          Wave.scroll = center - new_view_len / 2
          if Wave.scroll < 0 then Wave.scroll = 0 end
          local max_scroll = math.max(0, Wave.src_len - new_view_len)
          if Wave.scroll > max_scroll then Wave.scroll = max_scroll end
        end
      end

      -- - 按钮
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, "-", 20) then -- Zoom Out
        local prev_zoom = Wave.zoom
        Wave.zoom = math.max(Wave.zoom / 1.25, 1)
        if Wave.zoom ~= prev_zoom then
          local old_view_len = Wave.src_len / prev_zoom
          local center = Wave.scroll + old_view_len / 2
          local new_view_len = Wave.src_len / Wave.zoom
          Wave.scroll = center - new_view_len / 2
          if Wave.scroll < 0 then Wave.scroll = 0 end
          local max_scroll = math.max(0, Wave.src_len - new_view_len)
          if Wave.scroll > max_scroll then Wave.scroll = max_scroll end
        end
      end
    end

    -- 状态栏行
    local info = files_idx_cache and selected_row and files_idx_cache[selected_row]
    reaper.ImGui_Text(ctx, ("%d audio files found."):format(#files_idx_cache))
    if playing_preview then
      local show_path = info and info.path or (last_playing_info and last_playing_info.path)
      if show_path then
        reaper.ImGui_SameLine(ctx, nil, 1)
        reaper.ImGui_Text(ctx, " Now playing: " .. show_path)
        -- 右键点击时打开弹出菜单
        if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
          reaper.ImGui_OpenPopup(ctx, "##now_playing")
        end
        if reaper.ImGui_BeginPopup(ctx, "##now_playing") then
          if reaper.ImGui_MenuItem(ctx, "Show in Explorer/Finder") then
            if show_path and show_path ~= "" then
              reaper.CF_LocateInExplorer(show_path)
            end
          end
          reaper.ImGui_EndPopup(ctx)
        end
        reaper.ImGui_SameLine(ctx)
        HelpMarker("Right-click the 'Now playing' text to open its containing folder and highlight the file.")
      end
    end

    -- 显示波形缩放百分比
    reaper.ImGui_SameLine(ctx)
    if show_vertical_zoom and (reaper.time_precise() - show_vertical_zoom_timer < 1.1) then -- 1.1秒内显示
      local window_width = reaper.ImGui_GetWindowWidth(ctx)
      local text = string.format("Vertical Zoom: %.0f%%", waveform_vertical_zoom * 100)
      local text_width = reaper.ImGui_CalcTextSize(ctx, text)
      reaper.ImGui_SetCursorPosX(ctx, window_width - text_width - 16)
      reaper.ImGui_Text(ctx, text)
    elseif show_vertical_zoom and (reaper.time_precise() - show_vertical_zoom_timer >= 1.2) then
      show_vertical_zoom = false
    end

    -- 自动停止非Loop播放，只要没勾选Loop且快播完就自动Stop
    if playing_preview and not loop_enabled and not auto_play_next  then
      local ok_pos, position = reaper.CF_Preview_GetValue(playing_preview, "D_POSITION")
      local ok_len, length   = reaper.CF_Preview_GetValue(playing_preview, "D_LENGTH")
      if ok_pos and ok_len and (length - position) < 0.01 then -- 距离结尾小于0.03秒
        StopPlay()
      end
    end

    -- 自动加载驱动器
    if need_load_drives then
      need_load_drives = false
      reaper.defer(function()
        get_drives()
        drives_loaded = true
      end)
    end

    -- 调整旋钮鼠标意外落到波形预览区时播放光标变成鼠标光标，防止状态卡住
    if not reaper.ImGui_IsAnyItemActive(ctx) then
      is_knob_dragging = false
    end

    reaper.ImGui_PopStyleVar(ctx, 6) -- ImGui_End 内 6 次圆角
    reaper.ImGui_End(ctx)
  end
  reaper.ImGui_PopStyleVar(ctx, 3)
  reaper.ImGui_PopFont(ctx)

  -- 检测 Ctrl+F4 快捷键
  if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl()) then
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F4()) then
      return -- 退出脚本
    end
  end

  -- ESC按键，清除选区内容
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
    if select_start_time or select_end_time then
      -- 有选区，清空
      select_start_time = nil
      select_end_time = nil
      pending_clear_selection = false
    else
      -- 无选区，退出脚本
      StopPreview()
      return
    end
  end

  if open then reaper.defer(loop) else StopPlay() end
end

reaper.defer(loop)
