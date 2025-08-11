-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"
require ('lib.core')
require ('lib.utils')

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
  ImGui = require 'imgui' '0.10'
end

local SCRIPT_NAME = 'Soundmole - Explore, Tag, and Organize Audio Resources'
local FLT_MIN, FLT_MAX = reaper.ImGui_NumericLimits_Float()
local ctx = reaper.ImGui_CreateContext(SCRIPT_NAME)
local set_font = 'Calibri' -- options: sans-serif, Calibri, Microsoft YaHei, SimSun, STSong, STFangsong, ...
local fonts = {
  sans_serif = reaper.ImGui_CreateFont(set_font, 14), -- 全局默认字体大小
  small = reaper.ImGui_CreateFont(set_font, 12),
  medium = reaper.ImGui_CreateFont(set_font, 14),
  large = reaper.ImGui_CreateFont(set_font, 20),
  title = reaper.ImGui_CreateFont(set_font, 25),
  simsun = reaper.ImGui_CreateFont(set_font, 25),
}
reaper.ImGui_Attach(ctx, fonts.sans_serif)
reaper.ImGui_Attach(ctx, fonts.small)
reaper.ImGui_Attach(ctx, fonts.medium)
reaper.ImGui_Attach(ctx, fonts.large)
reaper.ImGui_Attach(ctx, fonts.title)

need_refresh_font  = false
font_size          = 14 -- 内容字体大小
FONT_SIZE_MIN      = 12 -- 内容字体最小
FONT_SIZE_MAX      = 24 -- 内容字体最大
preview_font_sizes = { 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24 }
preview_fonts      = {}
for _, sz in ipairs(preview_font_sizes) do
  preview_fonts[sz] = reaper.ImGui_CreateFont(set_font, sz)
  reaper.ImGui_Attach(ctx, preview_fonts[sz])
end
local DEFAULT_ROW_HEIGHT = 24 -- 内容行高
local row_height         = DEFAULT_ROW_HEIGHT
reaper.ImGui_SetNextWindowSize(ctx, 1400, 857, reaper.ImGui_Cond_FirstUseEver())
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]

-- 状态变量
CACHE_PIXEL_WIDTH            = 2048
selected_row                 = selected_row or -1
ui_bottom_offset             = 240
local playing_preview        = nil
local playing_path           = nil
local playing_source         = nil
local loop_enabled           = false -- 是否自动循环
local preview_play_len       = 0     -- 当前预览音频长度
local peak_chans             = 6     -- 默认显示6路电平
local play_rate              = 1     -- 默认速率1.0
local pitch                  = 0     -- 音高调节
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
local recent_audio_files     = {}    -- 最近播放列表
local max_recent_files       = 20    -- 最近播放最多保留20条
local max_recent_search      = 20    -- 最近搜索最多保留20条
local selected_recent_row    = 0
local skip_silence_enabled   = false -- 跳过静音
local skip_silence_db        = -60   -- 静音阈值，超过此值即认为有声
local skip_silence_threshold = 10^(skip_silence_db / 20) -- 换算成振幅阈值 amp = 10^(dB/20)
local last_selected_info     = nil   -- 上次选中的音频信息
local last_playing_info      = nil   -- 上次播放的音频信息
local is_knob_dragging       = false
local prev_preview_pos       = 0
local waveform_task_queue    = {}    -- 表格列表波形预览
local filename_filter        = nil   -- 列表音效搜索过滤
local last_collect_mode
local adv_folder_nodes_inited = false -- 是否已初始化高级文件夹节点的展开
local expanded_ids            = {}    -- 已展开的高级文件夹ID列表
local shortcut_nodes_inited   = false -- 是否已初始化快捷方式节点的展开
local expanded_paths          = {}    -- 已展开的文件夹路径表
local file_select_start       = nil   -- 音频文件列多选起点
local file_select_end         = nil   -- 音频文件列多选结束

-- 表格排序常量，编号对应表格列
local TableColumns = {
  FILENAME    = 2,
  SIZE        = 3,
  TYPE        = 4,
  DATE        = 5,
  GENRE       = 6,
  COMMENT     = 7,
  DESCRIPTION = 8,
  CATEGORY    = 9,
  SUBCATEGORY = 10,
  CATID       = 11,
  LENGTH      = 12,
  CHANNELS    = 13,
  SAMPLERATE  = 14,
  BITS        = 15,
}
-- ExtState
local EXT_SECTION              = "Soundmole"
local EXT_KEY_PEAKS            = "peak_chans"
local EXT_KEY_FONT_SIZE        = "font_size"
local EXT_KEY_MAX_DB           = "max_db"
local EXT_KEY_PITCH_MIN        = "pitch_knob_min"
local EXT_KEY_PITCH_MAX        = "pitch_knob_max"
local EXT_KEY_RATE_MIN         = "rate_min"
local EXT_KEY_RATE_MAX         = "rate_max"
local EXT_KEY_VOLUME           = "volume"
local EXT_KEY_CACHE_DIR        = "cache_dir"
local EXT_KEY_AUTOSCROLL       = "auto_scroll"
local EXT_KEY_RECENT_PLAYED    = "recent_played_files"
local EXT_KEY_TABLE_ROW_HEIGHT = "table_row_height"

local previewed_files = {} -- 预览已读标记
function MarkPreviewed(path) previewed_files[path] = true end
function IsPreviewed(path) return previewed_files[path] == true end

-- 波形缓存路径
local sep = package.config:sub(1, 1)
local DEFAULT_CACHE_DIR = script_path .. "waveform_cache" .. sep
local cache_dir = reaper.GetExtState(EXT_SECTION, EXT_KEY_CACHE_DIR)
if not cache_dir or cache_dir == "" then
  cache_dir = DEFAULT_CACHE_DIR
end
cache_dir = normalize_path(cache_dir, true)
EnsureCacheDir(cache_dir)
-- SoundmoleDB 路径
local DEFAULT_MEDIADB_DIR = script_path .. "SoundmoleDB" .. sep
local mediadb_dir = reaper.GetExtState(EXT_SECTION, "soundmoledb_dir")
if not mediadb_dir or mediadb_dir == "" then
  mediadb_dir = DEFAULT_MEDIADB_DIR
end
mediadb_dir = normalize_path(mediadb_dir, true)
EnsureCacheDir(mediadb_dir)

-- 波形预览状态变量
local wf_step = 400                    -- 波形预览步长
local img_w, img_h = 1200, 120         -- 波形图像宽度和高度
local base_img_h = 120                 -- 波形基础高度
local img_h_offset = 0                 -- 偏移高度，用于实时调整
local timeline_height = 20             -- 时间线高度
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
local last_row_height = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_TABLE_ROW_HEIGHT))
if last_row_height then row_height = math.max(12, math.min(48, last_row_height)) end -- 内容行高限制范围

-- 默认收集模式（0=Items, 1=RPP, 2=Directory, 3=Media Items, 4=This Computer, 5=Shortcuts）
collect_mode                 = -1 -- -1 表示未设置
COLLECT_MODE_ITEMS           = 0
COLLECT_MODE_RPP             = 1
COLLECT_MODE_DIR             = 2
COLLECT_MODE_ALL_ITEMS       = 3
COLLECT_MODE_TREE            = 4
COLLECT_MODE_SHORTCUT        = 5
COLLECT_MODE_CUSTOMFOLDER    = 6 -- 自定义文件夹模式
COLLECT_MODE_RECENTLY_PLAYED = 9 -- 最近播放模式
COLLECT_MODE_MEDIADB         = 999  -- 数据库模式

-- 设置相关
local auto_play_selected  = true
local DOUBLECLICK_INSERT  = 0
local DOUBLECLICK_PREVIEW = 1
local DOUBLECLICK_NONE    = 2
local doubleclick_action  = DOUBLECLICK_NONE
local bg_alpha            = 1.0 -- 默认背景不透明

-- 保存设置
function SaveSettings()
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
  reaper.SetExtState(EXT_SECTION, "max_recent_play", tostring(max_recent_files), true)
  reaper.SetExtState(EXT_SECTION, "max_recent_search", tostring(max_recent_search), true)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_TABLE_ROW_HEIGHT, tostring(row_height), true)
end

-- 恢复设置
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

local last_img_h_offset = tonumber(reaper.GetExtState(EXT_SECTION, "img_h_offset"))
if last_img_h_offset then img_h_offset = last_img_h_offset end

local last_max_recent_play = tonumber(reaper.GetExtState(EXT_SECTION, "max_recent_play"))
if last_max_recent_play then max_recent_files = math.max(1, math.min(100, last_max_recent_play)) end

local last_max_recent_search = tonumber(reaper.GetExtState(EXT_SECTION, "max_recent_search"))
if last_max_recent_search then max_recent_search = math.max(1, math.min(100, last_max_recent_search)) end

--------------------------------------------- 颜色表 ---------------------------------------------

local colors = {
  transparent          = 0x00000000, -- 完全透明
  table_header_hovered = 0x294A7A60, -- 鼠标悬停时表头颜色
  table_header_active  = 0x294A7AFF, -- 鼠标点击时表头颜色
  normal_text          = 0xFFF0F0F0, -- 标准文本颜色
  previewed_text       = 0x888888FF, -- 已预览过的暗一些
  timeline_def_color   = 0xCFCFCFFF, -- 时间线默认颜色
  thesaurus_text       = 0xBCC694FF, -- 同义词文本颜色
}

--------------------------------------------- 搜索字段列表 ---------------------------------------------

local search_fields = {
  { label = "Filename",         key = "filename",      enabled = true  }, -- 文件名
  { label = "Description",      key = "description",   enabled = true  }, -- 描述
  { label = "Type",             key = "type",          enabled = false }, -- 类型
  { label = "Origination Date", key = "bwf_orig_date", enabled = false }, -- 原始日期
  { label = "Samplerate",       key = "samplerate",    enabled = false }, -- 采样率
  { label = "Channels",         key = "channels",      enabled = false }, -- 声道数
  { label = "Bits",             key = "bits",          enabled = false }, -- 位深度
  { label = "Length",           key = "length",        enabled = false }, -- 时长
  { label = "Genre",            key = "genre",         enabled = false }, -- 流派
  { label = "Comment",          key = "comment",       enabled = false }, -- 注释
  { label = "Path",             key = "path",          enabled = false }, -- 路径
  { label = "Category",         key = "ucs_category",    enabled = false }, -- UCS主分类
  { label = "Subcategory",      key = "ucs_subcategory", enabled = false }, -- UCS子分类
  { label = "CatID",            key = "ucs_catid",       enabled = false }, -- CatID
}

local EXT_KEY_SEARCH_FIELDS = "enabled_fields"
local stored = reaper.GetExtState(EXT_SECTION, EXT_KEY_SEARCH_FIELDS)
if stored and stored ~= "" then
  local set = {}
  for key in stored:gmatch('([^,]+)') do
    set[key] = true
  end
  for _, field in ipairs(search_fields) do
    field.enabled = set[field.key] or false
  end
end

function SaveSearchFields()
  local list = {}
  for _, f in ipairs(search_fields) do
    if f.enabled then table.insert(list, f.key) end
  end
  reaper.SetExtState(EXT_SECTION, EXT_KEY_SEARCH_FIELDS, table.concat(list, ","), true)
end

--------------------------------------------- 波形缓存相关函数 ---------------------------------------------

function GetFileSize(filepath)
  filepath = normalize_path(filepath, false)
  local f = io.open(filepath, "rb")
  if not f then return end
  f:seek("end")
  local sz = f:seek()
  f:close()
  return sz or 0
end

function SimpleHash(str)
  local hash = 0
  for i = 1, #str do
    hash = (hash * 31 + str:byte(i)) % 2^32
    -- hash = (hash * 31 + str:byte(i)) % 2^53
  end
  return ("%08x"):format(hash)
  -- return ("%013x"):format(hash)
end

function CacheFilename(filepath)
  filepath = normalize_path(filepath, false)
  -- 文件大小安全获取
  local fsize = GetFileSize(filepath)
  if not fsize then fsize = 0 end -- 文件不存在或无法访问时，避免崩溃
  local size = tostring(fsize)
  local hash = SimpleHash(filepath .. "@" .. size)
  local subdir = hash:sub(1, 2) -- 取前两位，16进制00~ff
  local dir = cache_dir .. subdir .. sep
  EnsureCacheDir(dir) -- 确保子文件夹存在
  return dir .. hash .. ".wfc"
end

-- 保存缓存
function SaveWaveformCache(filepath, data)
  filepath = normalize_path(filepath, false)
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
function LoadWaveformCache(filepath)
  filepath = normalize_path(filepath, false)
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

function RemapWaveformToWindow(cache, pixel_cnt, start_time, end_time)
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
  local path = normalize_path(info.path, false)
  local cache = LoadWaveformCache(path)
  if not cache then
    -- 第一次采样，直接全量采样最大宽度
    local peaks, _, src_len, channel_count = GetPeaksForInfo(info, wf_step, CACHE_PIXEL_WIDTH, start_time, end_time)
    if peaks and src_len and channel_count then
      SaveWaveformCache(path, {peaks=peaks, pixel_cnt=CACHE_PIXEL_WIDTH, channel_count=channel_count, src_len=src_len})
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

function GetItemSectionStartPos(item)
  local take = reaper.GetActiveTake(item)
  if not take then return end
  local src = reaper.GetMediaItemTake_Source(take)
  if not reaper.ValidatePtr(src, "MediaSource*") then return end
  local src_type = reaper.GetMediaSourceType(src, "")
  if src_type ~= "SECTION" then return end

  local track = reaper.GetMediaItem_Track(item)
  local rv, chunk = reaper.GetTrackStateChunk(track, "", false)
  if not rv then return end

  local item_count = reaper.CountTrackMediaItems(track)
  local item_idx = -1
  for j = 0, item_count - 1 do
    if reaper.GetTrackMediaItem(track, j) == item then
      item_idx = j + 1
      break
    end
  end

  if item_idx == -1 then return end
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

function GetRootSource(src)
  -- 过滤空对象／非 MediaSource*
  if not src or not reaper.ValidatePtr(src, "MediaSource*") then
    return nil
  end
  while reaper.GetMediaSourceType(src, "") == "SECTION" do
    local parent = reaper.GetMediaSourceParent(src)
    if not parent or not reaper.ValidatePtr(parent, "MediaSource*") then break end
    src = parent
  end
  return src
end

-- Items 收集工程中当前使用的音频文件
function CollectFromItems()
  local files, files_idx = {}, {}
  local item_cnt = reaper.CountMediaItems(0)
  for i = 0, item_cnt - 1 do
    local item = reaper.GetMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    if take then
      local source = reaper.GetMediaItemTake_Source(take)
      -- 过滤空对象／非 MediaSource*
      if not reaper.ValidatePtr(source, "MediaSource*") then goto continue end
      local path = reaper.GetMediaSourceFileName(source, "")
      path = normalize_path(path, false)
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
          source = source,
          ucs_category    = get_ucstag(source, "category"),
          ucs_catid       = get_ucstag(source, "catId"),
          ucs_subcategory = get_ucstag(source, "subCategory")
        }
        files_idx[#files_idx+1] = files[path]
      end
    end
    ::continue::
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
      -- 过滤空对象／非 MediaSource*
      if not reaper.ValidatePtr(src, "MediaSource*") then goto continue end
      local take_offset = GetItemSectionStartPos(item) or 0
      local take_length = reaper.GetMediaSourceLength(src) or 0
      path = reaper.GetMediaSourceFileName(src, "")
      path = normalize_path(path, false)
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
    local take_name = ""
    if take then
      local ok, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
      take_name = ok and name or ""
    end
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
      ucs_category    = get_ucstag(src, "category"),
      ucs_catid       = get_ucstag(src, "catId"),
      ucs_subcategory = get_ucstag(src, "subCategory"),
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
          path = normalize_path(path, false)
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
      local path = ""
      if reaper.ValidatePtr(root_src, "MediaSource*") then
        path = reaper.GetMediaSourceFileName(root_src, "")
      end
      path = normalize_path(path, false)
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
        local take_name = ""
        if take then
          local ok, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
          take_name = ok and name or ""
        end
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
          ucs_category    = get_ucstag(source, "category"),
          ucs_catid       = get_ucstag(source, "catId"),
          ucs_subcategory = get_ucstag(source, "subCategory"),
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
  proj_path = normalize_path(proj_path, true)
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
      fullpath = normalize_path(fullpath, false)
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
          info.ucs_category    = get_ucstag(src, "category")
          info.ucs_catid       = get_ucstag(src, "catId")
          info.ucs_subcategory = get_ucstag(src, "subCategory")
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
      path = normalize_path(path, false)
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
        ucs_category    = get_ucstag(src, "category"),
        ucs_catid       = get_ucstag(src, "catId"),
        ucs_subcategory = get_ucstag(src, "subCategory"),
      })
    end
    ::continue::
  end
  return files_idx
end

-- 按文件名排序
function SortFilesByFilenameAsc()
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
    local key = normalize_path(info.path or "", false)
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
    -- 过滤空对象／非 MediaSource*
    if not root_src or not reaper.ValidatePtr(root_src, "MediaSource*") then
      goto continue
    end
    local path = reaper.GetMediaSourceFileName(root_src, "")
    path = normalize_path(path, false)
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
    ::continue::
  end
  return merged
end

function CollectFiles()
-- 切模式时清空文件列表多选/主选中
  file_select_start = nil
  file_select_end   = nil
  selected_row      = nil

  if collect_mode ~= COLLECT_MODE_RECENTLY_PLAYED then
    current_recent_play_info = nil
    selected_recent_row = 0 -- 清空最近播放选中项
  end
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
  elseif collect_mode == COLLECT_MODE_MEDIADB then
    local db_dir = normalize_path(script_path .. "SoundmoleDB", true) -- true 表示文件夹
    local dbfile = tree_state.cur_mediadb or ""
    files_idx_cache = {}
    if dbfile ~= "" then
      files_idx_cache = ParseMediaDBFile(db_dir .. sep .. dbfile)
    end
    selected_row = nil
  else
    files_idx_cache = {} -- collect_mode全部清空
  end

  if files_idx_cache then
    for _, info in ipairs(files_idx_cache) do
      info.group = GetCustomGroupsForPath(info.path)
      -- 清空表格列表的波形缓存
      info._thumb_waveform = nil
      info._last_thumb_w = nil
    end
  end

  previewed_files = {}
  SortFilesByFilenameAsc()
  -- 切换模式后清空表格列表波形预览队列
  waveform_task_queue = {}
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

function StopPlay()
  if playing_preview then
    reaper.CF_Preview_Stop(playing_preview)
    playing_preview = nil
  else
    reaper.CF_Preview_StopAll()
  end
  is_paused = false
  paused_position = 0
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

function VAL2DB(x)
  if x < 0.0000000298023223876953125 then
    return -150
  else
    return math.max(-150, math.log(x) * 8.6858896380650365530225783783321)
  end
end

-- dB转线性增益
function dB_to_gain(db)
  return 10 ^ (db / 20)
end

function MarkFontDirty()
  need_refresh_font = true
end

function GetPhysicalPath(path_or_source)
  if type(path_or_source) == "string" then
    return normalize_path(path_or_source, false)
  elseif reaper.ValidatePtr(path_or_source, "MediaSource*") then
    local path = reaper.GetMediaSourceFileName(path_or_source, "")
    return normalize_path(path, false)
  else
    return nil
  end
end

function InsertSelectedAudioSection(path, sel_start, sel_end, section_offset, move_cursor_to_end)
  path = normalize_path(path, false)
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
  -- 交互热区
  local radius = size * 0.5
  local cx, cy = reaper.ImGui_GetCursorScreenPos(ctx)
  cx, cy = cx + radius, cy + radius

  reaper.ImGui_SetCursorScreenPos(ctx, cx - radius, cy - radius)
  reaper.ImGui_InvisibleButton(ctx, label, size, size)
  local active = reaper.ImGui_IsItemActive(ctx)
  local hovered = reaper.ImGui_IsItemHovered(ctx)
  local changed = false

  -- 计算旋钮角度
  local ANG_MIN, ANG_MAX = -3 * math.pi/4, 3 * math.pi / 4
  local t = (value - v_min) / (v_max - v_min)
  local angle = ANG_MIN + (ANG_MAX - ANG_MIN) * t - math.pi / 2

  -- 绘制
  local col = active and 0x316AADFF or (hovered and 0x23456DFF or 0x1D2F49FF) -- 未经过时 0x1D2F49FF, 悬停 0x23456DFF, 拖动 0x316AADFF
  local dl = reaper.ImGui_GetWindowDrawList(ctx)
  reaper.ImGui_DrawList_AddCircleFilled(dl, cx, cy, radius, col)
  local hx, hy = cx + math.cos(angle) * radius * 0.87, cy + math.sin(angle) * radius * 0.87
  reaper.ImGui_DrawList_AddLine(dl, cx, cy, hx, hy, 0x3D85E0FF, 2)
  reaper.ImGui_DrawList_AddCircle(dl, cx, cy, radius, 0x23456DFF, 32, 1)

  -- 文本
  if label:find("##")~=1 then
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, label:gsub("##.*",""))
  end

  -- 拖拽更新
  if reaper.ImGui_IsItemActivated(ctx) then
    ImGui_Knob_drag_y[label] = { y0 = select(2,reaper.ImGui_GetMousePos(ctx)), v0 = value }
  elseif active and ImGui_Knob_drag_y[label] then
    local cur_y = select(2, reaper.ImGui_GetMousePos(ctx))
    local delta = ImGui_Knob_drag_y[label].y0 - cur_y
    local step = (v_max - v_min) / ( reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) and 2000 or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftShift()) and 1000 or 100 )
    local nv = ImGui_Knob_drag_y[label].v0 + delta*step
    value = math.max(v_min, math.min(v_max, nv))
    if math.abs(value - ImGui_Knob_drag_y[label].v0) > 1e-6 then changed = true end
  elseif not active then
    ImGui_Knob_drag_y[label] = nil
  end

  -- 右键或双击复位
  if hovered and (reaper.ImGui_IsMouseClicked(ctx, 1) or reaper.ImGui_IsMouseDoubleClicked(ctx, 0)) then
    value = default_value or v_min
    changed = true
    ImGui_Knob_drag_y[label] = nil
  end

  return changed, value
end

--------------------------------------------- 波形预览相关函数 ---------------------------------------------

-- 波形峰值采样
function GetWavPeaks(filepath, step, pixel_cnt, start_time, end_time)
  filepath = normalize_path(filepath, false)
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
  local buf_size = math.max(1, math.floor(samples_per_pixel * channels))
  local buf = reaper.new_array(buf_size)

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
  local buf_size = math.max(1, math.floor(samples_per_pixel * channel_count))
  local buf = reaper.new_array(buf_size)

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
function StopPreview()
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
  is_paused = false
  paused_position = 0

  -- 强制复位
  -- if last_play_cursor_before_play then
  --   Wave.play_cursor = last_play_cursor_before_play
  -- end
end

-- 从头播放
function PlayFromStart(info)
  last_play_cursor_before_play = 0
  -- 重置峰值
  for i = 1, peak_chans do
    peak_hold[i] = 0
  end
  StopPreview()
  -- Wave.play_cursor = 0
  -- 跳过静音
  local start_pos = 0
  if skip_silence_enabled then
    start_pos = FindFirstNonSilentTime(info) or 0 -- 某些情况下需要为0，避免报错。有些文件没有波形。
  end

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
        reaper.CF_Preview_SetValue(playing_preview, "D_POSITION", start_pos)
      end
      reaper.CF_Preview_Play(playing_preview)
      wf_play_start_time = os.clock()
      wf_play_start_cursor = start_pos
    end
    MarkPreviewed(info.path)
    -- 添加最近播放
    if info and info.path and collect_mode ~= COLLECT_MODE_RECENTLY_PLAYED then
      AddToRecentPlayed(info)
    end
    -- 保存最后播放的信息
    last_playing_info = {}
    for k, v in pairs(info) do last_playing_info[k] = v end
    -- 顺序播放新增
    preview_play_len = reaper.GetMediaSourceLength(source) or 0
    playing_path = info.path or ""
  end
end

-- 从光标开始播放
function PlayFromCursor(info)
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
function DrawTimeLine(ctx, wave, view_start, view_end)
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
    reaper.ImGui_DrawList_AddLine(drawlist, x, y0, x, y0 + tick_long, colors.timeline_def_color, 1.0)
    -- 时间标签
    local text = reaper.format_timestr(t or 0, "")
    -- 计算文字高度
    local text = reaper.format_timestr(t or 0, "")
    local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, text)
    local text_y = y0 + tick_long - text_h + 0  -- 最后一个值是上下位置细调
    reaper.ImGui_DrawList_AddText(drawlist, x + 4, text_y, colors.timeline_def_color, text)
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
          reaper.ImGui_DrawList_AddLine(drawlist, x, y0, x, y0 + tick_middle, colors.timeline_def_color, 1.0)
        elseif sub_index == 5 or sub_index == 15 then
          -- 次中间刻度线
          reaper.ImGui_DrawList_AddLine(drawlist, x, y0, x, y0 + tick_secmid, colors.timeline_def_color, 1.0)
        else
          -- 次刻度
          reaper.ImGui_DrawList_AddLine(drawlist, x, y0, x, y0 + tick_short, colors.timeline_def_color, 1.0)
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
function has_selection()
  return select_start_time and select_end_time and math.abs(select_end_time - select_start_time) > 0.01
end
function mouse_in_selection()
  if not mouse_time then return false end
  if not select_start_time or not select_end_time then return false end
  local sel_min = math.min(select_start_time, select_end_time)
  local sel_max = math.max(select_start_time, select_end_time)
  return mouse_time >= sel_min and mouse_time <= sel_max
end

--------------------------------------------- 树状文件夹 ---------------------------------------------

local audio_types = { WAVE=true, MP3=true, FLAC=true, OGG=true, AIFF=true, APE=true }
tree_state = tree_state or { cur_path = '', sel_audio = '' }
local tree_open = {}
local dir_cache = {} -- path -> {dirs=..., audios=..., ok=...}
local drive_cache = nil
local drives_loaded = false
local audio_file_cache = {}
local drive_name_map = {} -- 盘符到卷标的映射
local need_load_drives = false

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
  dir_path = normalize_path(dir_path, true)
  if not audio_file_cache[dir_path] then
    local _, files_idx = CollectFromDirectory(dir_path)
    audio_file_cache[dir_path] = files_idx
  end
  return audio_file_cache[dir_path]
end

-- 获取指定目录下所有有效音频文件
function CollectFromDirectory(dir_path)
  dir_path = normalize_path(dir_path, true)
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
      fullpath = normalize_path(fullpath, false)
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
          info.ucs_category    = get_ucstag(src, "category")
          info.ucs_catid       = get_ucstag(src, "catId")
          info.ucs_subcategory = get_ucstag(src, "subCategory")
        end
        files[fullpath] = info
        files_idx[#files_idx+1] = info
      end
    end
    i = i + 1
  end

  return files, files_idx
end

-- 获取本机所有盘符及其卷标
function get_drives()
  if drive_cache and drives_loaded then return drive_cache end
  local drives = {}
  drive_name_map = {} -- 重置映射

  if reaper.GetOS():find('Win') then
    -- PowerShell: 强制 UTF-8 输出 '盘符|卷标' 列表
    local ps = '[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; ' ..
               'Get-WmiObject Win32_LogicalDisk | ' ..
               'Where-Object { $_.DriveType -eq 3 } | ' ..
               'ForEach-Object{ $_.DeviceID + \'|\' + $_.VolumeName }'
    local cmd = 'powershell -NoProfile -ExecutionPolicy Bypass -Command "' .. ps .. '"'
    local handle = io.popen(cmd)
    if handle then
      for line in handle:lines() do
        local drv, vol = line:match('^([A-Z]:)%|(.*)$')
        if drv then
          local path = drv .. '\\'
          table.insert(drives, path)
          drive_name_map[path] = vol or ''
        end
      end
      handle:close()
    end
  else
    table.insert(drives, '/')
    drive_name_map['/'] = ''
  end

  table.sort(drives)
  drive_cache = drives
  drives_loaded = true
  return drives
end

-- 获取目录下所有子文件夹和支持类型的音频文件
function list_dir(path)
  path = normalize_path(path, true)
  local dirs, audios = {}, {}
  local ok = true
  local i = 0
  while true do
    local file = reaper.EnumerateFiles(path, i)
    if not file then break end
    local full = path .. ((path:sub(-1)==sep) and '' or sep) .. file
    full = normalize_path(full, false)
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
function draw_tree(name, path)
  path = normalize_path(path, true)
  local show_name = name
  if drive_name_map and drive_name_map[path] and drive_name_map[path] ~= "" then
    show_name = name .. " [" .. drive_name_map[path] .. "]"
  end

  local flags = reaper.ImGui_TreeNodeFlags_SpanAvailWidth()
  local highlight = (tree_state.cur_path == path) and reaper.ImGui_TreeNodeFlags_Selected() or 0
  local node_open = reaper.ImGui_TreeNode(ctx, show_name .. "##" .. path, flags | highlight)
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
      local sub_path = normalize_path(path .. sep .. sub, true)
      draw_tree(sub, sub_path)
    end
    reaper.ImGui_TreePop(ctx)
    tree_open[path] = true
  else
    tree_open[path] = false
  end
end

--------------------------------------------- 文件夹快捷键方式节点 ---------------------------------------------

local EXT_KEY_SHORTCUTS = "folder_shortcuts"
folder_shortcuts = folder_shortcuts or {} -- 选择文件夹快捷方式

-- 提取最后一级文件夹名称
function GetFolderName(path)
  return path:match("([^\\/]+)[\\/]?$")
end

function SaveFolderShortcuts()
  local t = {}
  for _, sc in ipairs(folder_shortcuts) do
    local name = (sc.name or ""):gsub(";", "%%3B"):gsub("%|%|", "%%7C%%7C")
    local path = normalize_path(sc.path or "", true):gsub(";", "%%3B"):gsub("%|%|", "%%7C%%7C")
    table.insert(t, name .. ";;" .. path)
  end
  local str = table.concat(t, "||")
  reaper.SetExtState(EXT_SECTION, EXT_KEY_SHORTCUTS, str, true)
end

function LoadFolderShortcuts()
  local str = reaper.GetExtState(EXT_SECTION, EXT_KEY_SHORTCUTS)
  local shortcuts = {}
  if not str or str == "" then
    return shortcuts
  end
  -- 没有 "||"时，当作单条处理；否则拆分多条
  local parts = {}
  if not str:find("||", 1, true) then
    parts = { str }
  else
    local last = 1
    repeat
      local s, e = str:find("||", last, true)
      if s then
        table.insert(parts, str:sub(last, s-1))
        last = e + 1
      else
        table.insert(parts, str:sub(last))
      end
    until not s
  end
  -- 逐条解析 name;;path
  for _, pair in ipairs(parts) do
    local name_enc, path_enc = pair:match("^(.-);;(.*)$")
    if name_enc and path_enc then
      local name = name_enc:gsub("%%3B", ";"):gsub("%%7C%%7C", "||")
      local path = normalize_path(path_enc:gsub("%%3B", ";"):gsub("%%7C%%7C", "||"),true)
      table.insert(shortcuts, { name = name, path = path })
    end
  end

  return shortcuts
end

folder_shortcuts = LoadFolderShortcuts()

-- 绘制快捷方式
function draw_shortcut_tree(sc, base_path)
  if type(sc)~="table" or not sc.path then return end
  local show_name = (sc.name and sc.name ~= "") and sc.name or GetFolderName(sc.path)
  local path = normalize_path(sc.path, true)
  local flags = reaper.ImGui_TreeNodeFlags_SpanAvailWidth()
  local highlight = (collect_mode == COLLECT_MODE_SHORTCUT and tree_state.cur_path == path) and reaper.ImGui_TreeNodeFlags_Selected() or 0 -- 去掉 collect_mode == COLLECT_MODE_SHORTCUT 则保持高亮

  -- 路径折叠展开状态，确保二级以上路径下次打开时可以展开
  local cmpath = path:gsub("[/\\]+$", "")
  if expanded_paths[cmpath] then
    flags = flags | reaper.ImGui_TreeNodeFlags_DefaultOpen()
  end

  local node_open = reaper.ImGui_TreeNode(ctx, show_name .. "##shortcut_" .. path, flags | highlight)
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
      if normalize_path(v.path, true) == path then
        is_root_shortcut = true
        break
      end
    end
    if is_root_shortcut then
      if reaper.ImGui_MenuItem(ctx, "Rename") then
        local ret, newname = reaper.GetUserInputs("Rename Shortcut", 1, "New Name:,extrawidth=200", (sc.name and sc.name~="") and sc.name or GetFolderName(sc.path))
        if ret and newname and newname ~= "" then
          sc.name = newname
          SaveFolderShortcuts()
        end
      end
    end
    if reaper.ImGui_MenuItem(ctx, "Show in Explorer/Finder") then
      if path and path ~= "" then
        reaper.CF_ShellExecute(normalize_path(path)) -- 规范分隔符
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
      local sub_path = normalize_path(path .. sep .. sub, true)
      draw_shortcut_tree({name=sub, path=sub_path}, path)
    end
    reaper.ImGui_TreePop(ctx)
    tree_open[path] = true
  else
    tree_open[path] = false
  end

  if remove_this then
    -- 反向遍历，避免索引错位
    for i = #folder_shortcuts, 1, -1 do
      if normalize_path(folder_shortcuts[i].path, true) == path then
        table.remove(folder_shortcuts, i)
      end
    end
    SaveFolderShortcuts()
    remove_this = false
  end
end

--------------------------------------------- 自定义文件夹节点 ---------------------------------------------

EXT_KEY_CUSTOM_CONTENT = "group_content"
custom_folders = custom_folders or {}
custom_folders_content = custom_folders_content or {}
group_select_start = nil

function SaveCustomFolders()
  local segments = {}
  for _, folder in ipairs(custom_folders) do
    local exist = {}
    local paths = {}
    for _, v in ipairs(custom_folders_content[folder] or {}) do
      local norm_path = normalize_path(v, false)
      if type(norm_path) == "string" and norm_path ~= "" and not exist[norm_path] then
        table.insert(paths, norm_path)
        exist[norm_path] = true
      end
    end
    if #paths > 0 then
      -- 有内容时 GroupName|path1;path2
      table.insert(segments, folder .. "|" .. table.concat(paths, ";"))
    else
      -- 空组只写 GroupName
      table.insert(segments, folder)
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
      -- local folder, items = segment:match("^([^|]+)|(.+)$") -- 启用后，不加入空组。
      local folder, items = segment:match("^([^|]+)%|?(.*)$") -- 确保空组可加载
      if folder then
        table.insert(folders, folder)
        local exist = {}
        local paths = {}
        for path in items:gmatch("[^;]+") do
          path = normalize_path(path, false)
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
  path = normalize_path(path, false)
  local groups = {}
  for folder, paths in pairs(custom_folders_content or {}) do
    for _, p in ipairs(paths) do
      if normalize_path(p, false) == path then
        table.insert(groups, folder)
        break
      end
    end
  end
  return table.concat(groups, ", ")
end

function ShowGroupMenu(infos)
  -- 对每个已有分组，统计在选中列表中有多少条已属于此组
  for _, group_name in ipairs(custom_folders) do
    local count_in = 0
    for _, info in ipairs(infos) do
      for _, p in ipairs(custom_folders_content[group_name] or {}) do
        if normalize_path(p,false)==normalize_path(info.path, false) then
          count_in = count_in + 1
          break
        end
      end
    end

    -- 判断全选、部分、未选
    local all_in  = (count_in == #infos)
    local some_in = (count_in > 0 and count_in < #infos)
    local checked = all_in

    -- 部分选中时加后缀提示
    local label = group_name
    if some_in then label = label .. " (partial)" end

    if reaper.ImGui_MenuItem(ctx, label, nil, checked) then
      if all_in then
        -- 全部移除
        for _, info in ipairs(infos) do
          local path = normalize_path(info.path,false)
          for idx,p in ipairs(custom_folders_content[group_name]) do
            if p == path then
              table.remove(custom_folders_content[group_name], idx)
              break
            end
          end
        end
      else
        -- 未全选时添加所有未在组内的
        for _, info in ipairs(infos) do
          local path = normalize_path(info.path, false)
          local exists = false
          for _, p in ipairs(custom_folders_content[group_name]) do
            if p == path then exists = true break end
          end
          if not exists then
            table.insert(custom_folders_content[group_name], path)
          end
        end
      end
      SaveCustomFolders()
    end
  end

  reaper.ImGui_Separator(ctx)

  -- 创建新组
  if reaper.ImGui_MenuItem(ctx, "Create Group...") then
    local ret, name = reaper.GetUserInputs("Create Group", 1, "Group Name:,extrawidth=200", "")
    if ret and name and name ~= "" then
      -- 新增分组并一次性插入所有选中路径
      table.insert(custom_folders, name)
      custom_folders_content[name] = {}
      for _, info in ipairs(infos) do
        table.insert(custom_folders_content[name], normalize_path(info.path, false))
      end
      SaveCustomFolders()
    end
  end
end

function handle_group_click(idx, folder)
  local shift = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftShift()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightShift())
  if shift then
    if not group_select_start then group_select_start = idx end
    local a, b = math.min(group_select_start, idx), math.max(group_select_start, idx)
    -- 强制刷新列表并显示第一个被选中的组
    tree_state.cur_custom_folder = custom_folders[a]
    collect_mode = COLLECT_MODE_CUSTOMFOLDER
    files_idx_cache = nil
    CollectFiles()
  else
    group_select_start = idx
    tree_state.cur_custom_folder = folder
    collect_mode = COLLECT_MODE_CUSTOMFOLDER
    files_idx_cache = nil
    CollectFiles()
  end
end

-- 文件件列表多选/选中状态，Shift+点击多选 & 单击选中
function handle_file_click(idx)
  local shift = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftShift()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightShift())
  if shift then
    if not file_select_start then file_select_start = idx end
    file_select_end = idx
  else
    file_select_start = idx
    file_select_end = idx
    selected_row = idx -- 单选时重置主选中
    current_recent_play_info = nil
    if collect_mode == COLLECT_MODE_RECENTLY_PLAYED then
      collect_mode = last_collect_mode
    end
    -- 解除最近播放锁定 & 切回之前模式
    current_recent_play_info = nil
    if collect_mode == COLLECT_MODE_RECENTLY_PLAYED then
      collect_mode = last_collect_mode
    end
  end
end

-- 启动时加载自定义文件夹
LoadCustomFolders()

--------------------------------------------- 高级文件夹节点 ---------------------------------------------

local EXT_KEY_ADVANCED_FOLDERS = "collections_content"
local EXT_KEY_ADVANCED_ROOT = "collections_root"
advanced_folders = advanced_folders or {}
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

function norm_files(files)
  local t = {}
  for _, path in ipairs(files or {}) do
    table.insert(t, normalize_path(path, false))
  end
  return t
end

function SaveAdvancedFolders()
  local lines = {}
  for id, node in pairs(advanced_folders) do
    local cs = table.concat(node.children or {}, ",")
    local fs = table.concat(norm_files(node.files), ",")
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
      for f   in fs:gmatch("[^,]+") do table.insert(node.files,    normalize_path(f, false))   end
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
  local flags = reaper.ImGui_TreeNodeFlags_SpanAvailWidth() -- reaper.ImGui_TreeNodeFlags_OpenOnArrow() -- 使用OpenOnArrow()将只能点击箭头有效。
  if collect_mode == COLLECT_MODE_ADVANCEDFOLDER and selected_id == id then -- 去掉 collect_mode == COLLECT_MODE_ADVANCEDFOLDER 则保持高亮
    flags = flags | reaper.ImGui_TreeNodeFlags_Selected()
  end
  -- 路径折叠展开状态，确保二级以上路径下次打开时可以展开。如果节点在 expanded_ids 中，首次渲染时默认展开它
  if expanded_ids[id] then
    flags = flags | reaper.ImGui_TreeNodeFlags_DefaultOpen()
  end

  local node_open = reaper.ImGui_TreeNode(ctx, node.name .. "##" .. id, flags)
  -- 切换当前高级文件夹目录选中状态
  if reaper.ImGui_IsItemClicked(ctx, 0) then
    tree_state.cur_advanced_folder = id
    collect_mode = COLLECT_MODE_ADVANCEDFOLDER
    files_idx_cache = nil
    CollectFiles()

    -- 清空多选状态
    file_select_start = nil
    file_select_end   = nil
    selected_row      = -1
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

  -- 拖动文件到高级文件夹中
  if reaper.ImGui_BeginDragDropTarget(ctx) then
    if reaper.ImGui_AcceptDragDropPayload(ctx, "AUDIO_PATHS") then
      local ok, dtype, payload = reaper.ImGui_GetDragDropPayload(ctx)
      if ok and dtype == "AUDIO_PATHS" and type(payload) == "string" and payload ~= "" then
        node.files = node.files or {}
        local changed = false
        -- 按分隔符拆分每条路径
        for raw in payload:gmatch("([^|;|]+)") do
          local drag_path = normalize_path(raw, false)
          local exists = false
          for _, p in ipairs(node.files) do
            if p == drag_path then exists = true break end
          end
          if not exists then
            table.insert(node.files, drag_path)
            changed = true
          end
        end
        if changed then
          SaveAdvancedFolders()
          if collect_mode == COLLECT_MODE_ADVANCEDFOLDER and tree_state.cur_advanced_folder == id then
            files_idx_cache = nil
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

---------------------------------------------  最近播放节点 ---------------------------------------------

function LoadRecentPlayed()
  recent_audio_files = {}
  local str = reaper.GetExtState(EXT_SECTION, EXT_KEY_RECENT_PLAYED)
  if not str or str == "" then return end
  local list = split(str, "|;|")
  for _, item in ipairs(list) do
    local path, filename = item:match("^(.-)%|%|(.*)$")
    if path and path ~= "" then
      local info = BuildFileInfoFromPath(path, filename)
      table.insert(recent_audio_files, info)
    end
  end
end

function SaveRecentPlayed()
  local t = {}
  for _, info in ipairs(recent_audio_files) do
    table.insert(t, (info.path or "") .. "||" .. (info.filename or ""))
  end
  local str = table.concat(t, "|;|") -- 用 |;| 分隔每一条
  reaper.SetExtState(EXT_SECTION, EXT_KEY_RECENT_PLAYED, str, true)
end

function BuildFileInfoFromPath(path, filename)
  path = normalize_path(path) -- 强制路径标准化
  local info = {
    path = path,
    filename = filename or (path:match("[^/\\]+$") or path),
    position = 0,
    section_offset = 0,
    section_length = 0
  }

  if not IsValidAudioFile(path) then return info end

  local typ, size, bits, samplerate, channels, length = "", 0, "-", "-", "-", "-"
  local genre, description, comment, orig_date = "", "", "", ""

  -- 文件属性
  if reaper.file_exists and reaper.file_exists(path) then
    local src = reaper.PCM_Source_CreateFromFile(path)
    if src then
      typ = reaper.GetMediaSourceType(src, "")
      bits = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(src) or "-"
      samplerate = reaper.GetMediaSourceSampleRate(src)
      channels = reaper.GetMediaSourceNumChannels(src)
      length = reaper.GetMediaSourceLength(src)
      local _, _genre = reaper.GetMediaFileMetadata(src, "XMP:dm/genre")
      local _, _comment = reaper.GetMediaFileMetadata(src, "XMP:dm/logComment")
      local _, _description = reaper.GetMediaFileMetadata(src, "BWF:Description")
      local _, _orig_date  = reaper.GetMediaFileMetadata(src, "BWF:OriginationDate")
      genre = _genre or ""
      comment = _comment or ""
      description = _description or ""
      orig_date = _orig_date or ""
      local ucs_category    = get_ucstag(src, "category")
      local ucs_catid       = get_ucstag(src, "catId")
      local ucs_subcategory = get_ucstag(src, "subCategory")
      reaper.PCM_Source_Destroy(src)
    end
  end

  -- 音频格式校验
  if not (typ == "WAVE" or typ == "MP3" or typ == "FLAC" or typ == "OGG" or typ == "AIFF" or typ == "APE" or typ == "WV") then
    return info
  end

  -- 文件大小
  local f = io.open(path, "rb")
  if f then
    f:seek("end")
    size = f:seek()
    f:close()
  end

  info.type = typ
  info.samplerate = samplerate
  info.channels = channels
  info.length = length
  info.bits = bits
  info.size = size
  info.genre = genre
  info.description = description
  info.comment = comment
  info.bwf_orig_date = orig_date
  info.section_length = length
  info.ucs_category    = ucs_category
  info.ucs_catid       = ucs_catid
  info.ucs_subcategory = ucs_subcategory

  return info
end

function RemoveDuplicateRecentFiles()
  local path_set = {}
  local new_list = {}
  for _, info in ipairs(recent_audio_files) do
    local path = normalize_path(info.path)
    if not path_set[path] then
      path_set[path] = true
      table.insert(new_list, info)
    end
  end
  recent_audio_files = new_list
end

function AddToRecentPlayed(file_info)
  if not file_info or not file_info.path then return end
  -- 规范分隔符
  file_info.path = normalize_path(file_info.path)
  if recent_audio_files[1] and recent_audio_files[1].path == file_info.path then
    return
  end
  -- 移除已有的同路径项（避免重复）
  for i = #recent_audio_files, 1, -1 do
    if normalize_path(recent_audio_files[i].path) == file_info.path then
      table.remove(recent_audio_files, i)
    end
  end
  -- table.insert(recent_audio_files, 1, file_info) -- 插入新的副本而不是file_info本身
  local info_copy = {}
  for k, v in pairs(file_info) do info_copy[k] = v end
  table.insert(recent_audio_files, 1, info_copy)
  -- 裁剪超出最大数量
  while #recent_audio_files > max_recent_files do
    table.remove(recent_audio_files)
  end
  -- RemoveDuplicateRecentFiles() -- 强制去重
  SaveRecentPlayed()
end

-- 读取最近播放
LoadRecentPlayed()

---------------------------------------------  表格列表波形预览节点 ---------------------------------------------

-- 每帧限制最多处理多少个任务
local MAX_WAVEFORM_PER_FRAME = 2

function EnqueueWaveformTask(info, thumb_w)
  for _, task in ipairs(waveform_task_queue) do
    if task.info == info and task.width == thumb_w then
      return
    end
  end
  table.insert(waveform_task_queue, {info=info, width=thumb_w})
end

function ProcessWaveformTasks()
  local n = 0
  while n < MAX_WAVEFORM_PER_FRAME and #waveform_task_queue > 0 do
    local task = table.remove(waveform_task_queue, 1)
    -- 只在未缓存时采样
    if not task.info._thumb_waveform then task.info._thumb_waveform = {} end
    if not task.info._thumb_waveform[task.width] then
      local peaks, pixel_cnt, src_len, channel_count = GetPeaksWithCache(task.info, wf_step, task.width) -- 统一采样步长 wf_step=400
      if peaks and channel_count then
        task.info._thumb_waveform[task.width] = {peaks=peaks, pixel_cnt=pixel_cnt, src_len=src_len, channel_count=channel_count}
      end
    end
    n = n + 1
  end
end

--------------------------------------------- 专辑封面 ---------------------------------------------

local last_window_visible = true
local cover_cache = {}
local cover_path_cache = {}
local last_cover_img = nil
local last_cover_path = nil
local last_img_w = nil
local img_cache_dir = script_path .. "cover_cache" .. sep
img_cache_dir = normalize_path(img_cache_dir, true)
if reaper.file_exists(img_cache_dir) == false then
  reaper.RecursiveCreateDirectory(img_cache_dir, 0)
end

-- ID3v2 同步安全整数 & 大端整数解析
function syncsafe_to_int(bs)
  local b1,b2,b3,b4 = bs:byte(1,4)
  return b1 * 2^21 + b2 * 2^14 + b3 * 2^7 + b4
end
function be_to_int(bs)
  local b1,b2,b3,b4 = bs:byte(1,4)
  return b1 * 2^24 + b2 * 2^16 + b3 * 2^8 + b4
end

-- 解析 ID3v2 APIC 帧（封面）
function parse_id3_apic(tag_data, ver)
  local pos = 1
  while pos + 10 <= #tag_data do
    local id      = tag_data:sub(pos, pos + 3)
    local size_bs = tag_data:sub(pos + 4, pos + 7)
    local sz      = (ver==4) and syncsafe_to_int(size_bs) or be_to_int(size_bs)
    if id == "APIC" then
      local frame = tag_data:sub(pos + 10, pos + 10 + sz - 1)
      local encoding      = frame:sub(1, 1) -- 文本编码
      local rest1         = frame:sub(2) -- 跳过encoding
      local mime_end      = rest1:find("\0", 1, true)
      local mime          = rest1:sub(1, mime_end - 1)
      local after_mime    = rest1:sub(mime_end + 1)
      local pictype       = after_mime:sub(1, 1) -- pictureType
      local desc_and_data = after_mime:sub(2)
      local desc_end      = desc_and_data:find("\0", 1, true)
      local description   = desc_and_data:sub(1, desc_end - 1)
      local imgData       = desc_and_data:sub(desc_end + 1) -- 图像二进制
      return mime, imgData
    end
    pos = pos + 10 + sz
  end
end

-- MP3 / WAV（内嵌 ID3v2）提取，WAV 如果在结尾有 ID3 chunk，也能被识别
function ExtractID3Cover(file_path)
  if not file_path or type(file_path) ~= "string" or file_path == "" then 
    return 
  end
  local path = normalize_path(file_path, false)
  local f = io.open(path, "rb")
  if not f then 
    return 
  end

  local header = f:read(10)
  local ver, tag_size, tag_data

  if header and header:sub(1,3) == "ID3" then
    -- MP3 文件开头
    ver      = header:byte(4)
    tag_size = syncsafe_to_int(header:sub(7, 10))
    tag_data = f:read(tag_size)
  else
    -- 可能是 WAV 文件末尾的 ID3 chunk
    local content = header .. f:read("*all")
    local pos = content:find("ID3", 1, true)
    if not pos then f:close() return end
    local hdr2 = content:sub(pos, pos + 9)
    if hdr2:sub(1, 3) ~= "ID3" then f:close() return end
    ver      = hdr2:byte(4)
    tag_size = syncsafe_to_int(hdr2:sub(7, 10))
    tag_data = content:sub(pos + 10, pos + 10 + tag_size - 1)
  end

  f:close()
  return parse_id3_apic(tag_data, ver)
end

-- FLAC 原生 METADATA_BLOCK_PICTURE 提取
function ExtractFlacCover(file_path)
  if not file_path or type(file_path) ~= "string" or file_path == "" then
    return
  end
  local path = normalize_path(file_path, false)
  local f = io.open(path, "rb")
  if not f then
    return
  end
  if f:read(4) ~= "fLaC" then f:close() return end

  while true do
    local hdr = f:read(4)
    if not hdr then break end
    local b1         = hdr:byte(1)
    local is_last    = b1 >= 128
    local block_type = b1 % 128
    local size       = hdr:byte(2) * 2^16 + hdr:byte(3) * 2^8 + hdr:byte(4)
    local data       = f:read(size) or ""

    if block_type == 6 then -- Picture block
      local pos = 1
      pos = pos + 4 -- 跳过 picture type
      local mime_len = be_to_int(data:sub(pos, pos + 3))
      pos = pos + 4
      local mime = data:sub(pos, pos+mime_len - 1)
      pos = pos + mime_len
      local desc_len = be_to_int(data:sub(pos, pos + 3))
      pos = pos + 4 + desc_len
      pos = pos + 16 -- 跳过 width/height/depth/colors（各 4 字节）
      local pic_len = be_to_int(data:sub(pos, pos + 3))
      pos = pos + 4
      local imgData = data:sub(pos, pos+pic_len - 1)
      f:close()
      return mime, imgData
    end

    if is_last then break end
  end

  f:close()
end

-- 提取并缓存封面二进制
function GetCoverImageData(raw_path)
  local audio_path = normalize_path(raw_path, false)
  -- 已缓存则直接返回，避免重复 I/O
  if cover_cache[audio_path] then
    return cover_cache[audio_path].mime, cover_cache[audio_path].data
  end
  -- 尝试 MP3/WAV ID3
  local mime, data = ExtractID3Cover(audio_path)
  if data then
    cover_cache[audio_path] = { mime = mime, data = data }
    return mime, data
  end
  -- 尝试 FLAC Picture
  mime, data = ExtractFlacCover(audio_path)
  if data then
    cover_cache[audio_path] = { mime = mime, data = data }
    return mime, data
  end
  -- 回退到同目录图片文件
  local dir  = audio_path:match("^(.*[\\/])") or ""
  local base = audio_path:match("([^\\/]+)%.%w+$") or ""
  for _, name in ipairs({ "cover.jpg", "cover.png", "folder.jpg", "folder.png", base .. ".jpg", base .. ".png" }) do
    local p = dir .. name
    local f = io.open(p, "rb")
    if f then
      local img = f:read("*all")
      f:close()
      local m = name:find("%.png$") and "image/png" or "image/jpeg"
      cover_cache[audio_path] = { mime = m, data = img }
      return m, img
    end
  end
  -- 全部查找完成，还没找到封面
  cover_cache[audio_path] = { mime = nil, data = nil }

  return nil, nil
end

-- 提取封面并写到 cache_dir，返回完整文件路径
function SaveCoverToTemp(file_path)
  file_path = normalize_path(file_path, false)
  -- 提取二进制
  local mime, data = ExtractID3Cover(file_path)
  if not data then mime, data = ExtractFlacCover(file_path) end
  if not data then return nil end
  local header = data:sub(1, 2)
  -- 生成唯一文件路径
  local hash = SimpleHash(file_path)
  local ext  = mime:find("png") and ".png" or ".jpg"
  local out  = img_cache_dir .. hash .. ext
  -- 文件不存在就写入
  local f2 = io.open(out, "rb")
  if not f2 then
    -- 写文件
    local f = io.open(out, "wb")
    if not f then
      return nil
    end
    f:write(data)
    f:close()
  else
    f2:close()
  end
  -- 缓存data
  cover_cache[file_path] = { mime = mime, data = data }

  return out
end

-- 先调用 SaveCoverToTemp 获取内嵌封面临时文件路径，如果没有，再退回到同目录查找图片文件
function GetCoverImagePath(audio_path)
  audio_path = normalize_path(audio_path, false)
  -- 已缓存则直接返回
  if cover_path_cache[audio_path] ~= nil then
    return cover_path_cache[audio_path] or nil
  end
  -- 内嵌封面
  local tmp = SaveCoverToTemp(audio_path)
  if tmp then
    cover_path_cache[audio_path] = tmp
    return tmp
  end
  -- 同目录图片文件
  local dir  = audio_path:match("^(.*[\\/])") or ""
  local base = audio_path:match("([^\\/]+)%.")  or ""
  for _, name in ipairs({ "cover.jpg", "cover.png", "folder.jpg", "folder.png", base .. ".jpg", base .. ".png" }) do
    local p = dir .. name
    local f = io.open(p, "rb")
    if f then
      f:close()
      cover_path_cache[audio_path] = p
      return p
    end
  end
  -- 缓存查不到的情况，避免反复查找
  cover_path_cache[audio_path] = false
  return nil
end

-- 判断 info 是否存在有效专辑封面
function HasCoverImage(img_info)
  if not img_info then return false end
  local mime, data = GetCoverImageData(img_info.path)
  return data ~= nil
end

function ReleaseAllCoverImages()
  if cover_cache then
    for k, img in pairs(cover_cache) do
      if img and reaper.ImGui_DestroyImage then
        reaper.ImGui_DestroyImage(img)
      end
      cover_cache[k] = nil
    end
  end
end

function DeleteCoverCacheFiles()
  local path = img_cache_dir
  local i = 0
  while true do
    local fname = reaper.EnumerateFiles(path, i)
    if not fname then break end
    local fpath = path .. fname
    os.remove(fpath)
    i = i + 1
  end
  
  -- os.remove(path) -- 删除空目录
end

--------------------------------------------- 地址栏音频文件地址点击文件夹目录段节点 ---------------------------------------------

function RefreshFolderFiles(dir)
  if collect_mode ~= COLLECT_MODE_RECENTLY_PLAYED then
    collect_mode = COLLECT_MODE_TREE -- 如果不是最近播放则使用树形目录
    current_recent_play_info = nil
    selected_recent_row = 0 -- 清空最近播放选中项
  end

  files_idx_cache = GetAudioFilesFromDirCached(dir)
  selected_row = nil

  if files_idx_cache then
    for _, info in ipairs(files_idx_cache) do
      info.group = GetCustomGroupsForPath(info.path)
      -- 清空表格列表的波形缓存
      info._thumb_waveform = nil
      info._last_thumb_w = nil
    end
  end

  previewed_files = {}
  SortFilesByFilenameAsc()
  -- 切换模式后清空表格列表波形预览队列
  waveform_task_queue = {}

  -- 图片资源释放
  -- if last_cover_img and reaper.ImGui_DestroyImage then
  --   reaper.ImGui_DestroyImage(last_cover_img)
  -- end
  -- last_cover_img, last_cover_path = nil, nil
  -- last_img_w = nil
end

--------------------------------------------- UCS节点 ---------------------------------------------

-- 强制英文搜索，当点击UCS主分类/子分类时，提交英文关键词
UCS_FORCE_EN = UCS_FORCE_EN == nil and true or UCS_FORCE_EN
CURRENT_LANG = CURRENT_LANG or (reaper.GetExtState(EXT_SECTION, "ucs_lang") ~= "" and reaper.GetExtState(EXT_SECTION, "ucs_lang") or "en")
local UCS_LANG_OPTS = {
  { key = "en", label = "English" },
  { key = "zh", label = "简体中文" },
  { key = "tw", label = "正體中文" },
}

-- 展开状态
cat_open_state       = cat_open_state       or {}
ucs_open_en          = ucs_open_en          or {}
ucs_last_filter_text = ucs_last_filter_text or ""
usc_filter           = usc_filter           or nil

local categories, cat_names, ucs_maps

function parse_csv_line(line)
  line = (line or ""):gsub("\r$", "")
  local fields, buf, in_quotes = {}, {}, false
  local i, n = 1, #line
  while i <= n do
    local ch = line:sub(i, i)
    if ch == '"' then
      if in_quotes and line:sub(i+1, i+1) == '"' then
        table.insert(buf, '"'); i = i + 1
      else
        in_quotes = not in_quotes
      end
    elseif ch == ',' and not in_quotes then
      local field = table.concat(buf)
      field = field:gsub('^%s*"(.*)"%s*$', '%1')
      field = field:match('^%s*(.-)%s*$') or field
      table.insert(fields, field)
      buf = {}
    else
      table.insert(buf, ch)
    end
    i = i + 1
  end
  local last = table.concat(buf)
  last = last:gsub('^%s*"(.*)"%s*$', '%1')
  last = last:match('^%s*(.-)%s*$') or last
  table.insert(fields, last)
  return fields
end

function LoadUCS_NoSort_WithENMap(lang)
  local COL_MAP = { en = {1, 2}, zh = {6, 7}, tw = {9, 10} } -- 表格列映射
  local map = COL_MAP[lang] or COL_MAP.en

  local ucs_path = normalize_path(script_path .. "data/ucs.csv", false)
  local f = io.open(ucs_path, "r")
  if not f then
    reaper.ShowMessageBox("File not found:\n" .. tostring(ucs_path), "Error", 0)
    return {}, {}, { cat_to_en = {}, sub_to_en = {} }
  end

  local lines = {}
  for line in f:lines() do lines[#lines+1] = line end
  f:close()
  if lines[1] then lines[1] = lines[1]:gsub("^\239\187\191", "") end -- strip BOM

  -- 列固定 EN(1,2), CatID(3)
  local EN_CAT_COL, EN_SUB_COL, CATID_COL = 1, 2, 3

  local categories = {}
  local cat_names  = {}
  local seen_cat   = {}
  local seen_sub   = {}

  local ucs_maps = {
    cat_to_en = {}, -- 显示语言主类-英文主分类
    sub_to_en = {}  -- 显示语言子类-英文子分类（按主类分组）
  }

  for i = 2, #lines do
    local fields = parse_csv_line(lines[i])

    local cat_disp = (fields[ map[1] ] or ""):match("^%s*(.-)%s*$")
    local sub_disp = (fields[ map[2] ] or ""):match("^%s*(.-)%s*$")
    local id       = fields[ CATID_COL ] or ""

    local cat_en   = (fields[ EN_CAT_COL ] or ""):match("^%s*(.-)%s*$")
    local sub_en   = (fields[ EN_SUB_COL ] or ""):match("^%s*(.-)%s*$")

    if cat_disp ~= "" and sub_disp ~= "" and cat_en ~= "" and sub_en ~= "" then
      if not seen_cat[cat_disp] then
        seen_cat[cat_disp] = true
        categories[cat_disp] = {}
        seen_sub[cat_disp] = {}
        cat_names[#cat_names+1] = cat_disp

        ucs_maps.cat_to_en[cat_disp] = cat_en
        ucs_maps.sub_to_en[cat_disp] = {}
      end
      if not seen_sub[cat_disp][sub_disp] then
        seen_sub[cat_disp][sub_disp] = true
        categories[cat_disp][#categories[cat_disp]+1] = { name = sub_disp, id = id }
        ucs_maps.sub_to_en[cat_disp][sub_disp] = sub_en
      end
    end
  end

  return categories, cat_names, ucs_maps
end

-- 将当前折叠展开状态显示语言key映射到英文key
function SnapshotOpenStateToEN()
  if not (cat_open_state and ucs_maps and ucs_maps.cat_to_en) then return end
  for cat_disp, is_open in pairs(cat_open_state) do
    local en = ucs_maps.cat_to_en[cat_disp] or cat_disp
    if is_open then ucs_open_en[en] = true else ucs_open_en[en] = nil end
  end
end

-- 从英文key的展开状态恢复到显示语言
function RestoreOpenStateFromEN()
  cat_open_state = {}
  if not (ucs_maps and ucs_maps.cat_to_en and cat_names) then return end
  for _, cat_disp in ipairs(cat_names) do
    local en = ucs_maps.cat_to_en[cat_disp] or cat_disp
    if ucs_open_en[en] then
      cat_open_state[cat_disp] = true
    end
  end
end

-- 切换/重载UCS数据+清理与搜索相关的临时状态
function ReloadUCSData(new_lang)
  SnapshotOpenStateToEN()

  CURRENT_LANG = new_lang
  reaper.SetExtState(EXT_SECTION, "ucs_lang", CURRENT_LANG, true)
  categories, cat_names, ucs_maps = LoadUCS_NoSort_WithENMap(CURRENT_LANG)
  RestoreOpenStateFromEN()

  if usc_filter then
    reaper.ImGui_TextFilter_Set(usc_filter, "")
  end

  ucs_last_filter_text = ""
  temp_ucs_cat_keyword, temp_ucs_sub_keyword = nil, nil
  temp_search_field, temp_search_keyword = nil, nil
  active_saved_search = nil
  selected_row = nil

  local static = _G._soundmole_static or {}
  _G._soundmole_static = static
  static.filtered_list_map, static.last_filter_text_map = {}, {}
end

-- 语言下拉菜单
function DrawUcsLanguageSelector(ctx)
  local cur_label = "English"
  for _, opt in ipairs(UCS_LANG_OPTS) do
    if opt.key == CURRENT_LANG then cur_label = opt.label break end
  end

  reaper.ImGui_Text(ctx, "Language:")
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_SetNextItemWidth(ctx, -65)
  if reaper.ImGui_BeginCombo(ctx, "##ucs_lang_combo", cur_label) then
    for _, opt in ipairs(UCS_LANG_OPTS) do
      local selected = (opt.key == CURRENT_LANG)
      if reaper.ImGui_Selectable(ctx, opt.label .. "##" .. opt.key, selected) then
        if opt.key ~= CURRENT_LANG then
          ReloadUCSData(opt.key)
        end
      end
      if selected then reaper.ImGui_SetItemDefaultFocus(ctx) end
    end
    reaper.ImGui_EndCombo(ctx)
  end
end

ReloadUCSData(CURRENT_LANG or "en")

--------------------------------------------- 跳过静音节点 ---------------------------------------------

skip_silence_enabled = (tonumber(reaper.GetExtState(EXT_SECTION, "skip_silence")) or 1) == 1

--- 从缓存中寻找首个有声位置 ms
function FindFirstNonSilentTime(info)
  local path = normalize_path(info.path, false)
  local cache = LoadWaveformCache(path)
  if not cache then return end

  -- for i = 1, math.min(10, cache.pixel_cnt) do
  --   local p = cache.peaks[1][i] or {0,0}
  --   reaper.ShowConsoleMsg(string.format("px=%d → min=%.6f max=%.6f\n", i, p[1], p[2]))
  -- end
  -- 只检查第1通道
  -- local pixel_cnt, src_len = cache.pixel_cnt, cache.src_len
  -- for px = 1, pixel_cnt do
  --   local p = cache.peaks[1][px] or {0,0}
  --   if math.abs(p[1]) > skip_silence_threshold or math.abs(p[2]) > skip_silence_threshold then
  --     -- 映射到实际时间
  --     return (px-1) / (pixel_cnt-1) * src_len
  --   end
  -- end

  local pixel_cnt     = cache.pixel_cnt
  local src_len       = cache.src_len
  local channel_count = cache.channel_count
  for px = 1, pixel_cnt do
    for ch = 1, channel_count do
      local peak = cache.peaks[ch][px] or {0,0}
      if math.abs(peak[1]) > skip_silence_threshold or math.abs(peak[2]) > skip_silence_threshold then
        -- 映射到实际时间
        return (px-1) / (pixel_cnt-1) * src_len
      end
    end
  end

  return
end

--------------------------------------------- 退出时保存各个模式列表状态 ---------------------------------------------

function LoadExitSettings()
  collect_mode = tonumber(reaper.GetExtState(EXT_SECTION, "collect_mode") or "")

  -- 恢复 工程文件资源 四个模式
  if collect_mode == COLLECT_MODE_ITEMS or collect_mode == COLLECT_MODE_RPP or collect_mode == COLLECT_MODE_DIR or collect_mode == COLLECT_MODE_ALL_ITEMS then
    local ext = reaper.GetExtState(EXT_SECTION, "project_header_open")
    if ext == "true" then
      project_open = true
    elseif ext == "false" then
      project_open = false
    else
      project_open = false
    end
  end

  -- 恢复 Shortcuts 模式
  if collect_mode == COLLECT_MODE_SHORTCUT then -- collect_mode == COLLECT_MODE_TREE or
    local ext = reaper.GetExtState(EXT_SECTION, "shortcut_header_open")
    if ext == "true" then
      shortcut_open = true
    elseif ext == "false" then
      shortcut_open = false
    else
      shortcut_open = false
    end

    tree_state.cur_path = reaper.GetExtState(EXT_SECTION, "cur_tree_path") or ""
  end

  -- 恢复 Group 模式
  if collect_mode == COLLECT_MODE_CUSTOMFOLDER then
    local ext = reaper.GetExtState(EXT_SECTION, "group_header_open")
    if ext == "true" then
      group_open = true
    elseif ext == "false" then
      group_open = false
    else
      group_open = false
    end

    tree_state.cur_custom_folder = reaper.GetExtState(EXT_SECTION, "cur_custom_folder") or ""
  end

  -- 恢复数据库模式
  if collect_mode == COLLECT_MODE_MEDIADB then
    local ext = reaper.GetExtState(EXT_SECTION, "soundmoledb_header_open")
    if ext == "true" then
      mediadb_open = true
    else
      mediadb_open = false
    end
    tree_state.cur_mediadb = reaper.GetExtState(EXT_SECTION, "cur_soundmoledb") or ""
  end

  -- 恢复 Collections 模式
  if collect_mode == COLLECT_MODE_ADVANCEDFOLDER then
    -- 折叠状态
    local ext = reaper.GetExtState(EXT_SECTION, "collections_header_open")
    if ext == "true" then
      collection_open = true
    elseif ext == "false" then
      collection_open = false
    else
      collection_open = false -- 默认关
    end

    -- 选中状态
    local last = reaper.GetExtState(EXT_SECTION, "last_collections")
    if last and last ~= "" and advanced_folders[last] then
      tree_state.cur_advanced_folder = last
    end
  end

  -- 恢复 最近播放 模式
  if collect_mode == COLLECT_MODE_RECENTLY_PLAYED then
    local ext = reaper.GetExtState(EXT_SECTION, "recent_header_open")
    if ext == "true" then
      recent_open = true
    elseif ext == "false" then
      recent_open = false
    else
      recent_open = false
    end

    selected_recent_row = tonumber(reaper.GetExtState(EXT_SECTION, "cur_recent_row") or "") or 0
  end
end

-- 保存当前模式列表折叠状态
function SaveExitSettings()
  reaper.SetExtState(EXT_SECTION, "collect_mode", tostring(collect_mode), true)

  if collect_mode == COLLECT_MODE_ITEMS or collect_mode == COLLECT_MODE_RPP or collect_mode == COLLECT_MODE_DIR or collect_mode == COLLECT_MODE_ALL_ITEMS then
    reaper.SetExtState(EXT_SECTION, "project_header_open", tostring(project_open), true)

  elseif collect_mode == COLLECT_MODE_SHORTCUT then -- collect_mode == COLLECT_MODE_TREE or
    reaper.SetExtState(EXT_SECTION, "shortcut_header_open", tostring(shortcut_open), true)
    reaper.SetExtState(EXT_SECTION, "cur_tree_path", tree_state.cur_path or "", true)

  elseif collect_mode == COLLECT_MODE_CUSTOMFOLDER then
    reaper.SetExtState(EXT_SECTION, "group_header_open", tostring(group_open), true)
    reaper.SetExtState(EXT_SECTION, "cur_custom_folder", tree_state.cur_custom_folder or "", true)

  elseif collect_mode == COLLECT_MODE_MEDIADB then
    reaper.SetExtState(EXT_SECTION, "soundmoledb_header_open", tostring(mediadb_open), true)
    reaper.SetExtState(EXT_SECTION, "cur_soundmoledb", tree_state.cur_mediadb or "", true)

  elseif collect_mode == COLLECT_MODE_ADVANCEDFOLDER then
    reaper.SetExtState(EXT_SECTION, "collections_header_open", tostring(collection_open), true)
    reaper.SetExtState(EXT_SECTION, "last_collections", tree_state.cur_advanced_folder or "", true)

  elseif collect_mode == COLLECT_MODE_RECENTLY_PLAYED then
    reaper.SetExtState(EXT_SECTION, "recent_header_open", tostring(recent_open), true)
    reaper.SetExtState(EXT_SECTION, "cur_recent_row", tostring(selected_recent_row or 0), true)
  end
end

LoadExitSettings()

--------------------------------------------- 保存搜索功能 ---------------------------------------------

local active_saved_search = nil
show_add_popup = false
new_search_name = ""
remove_search_idx = nil
rename_name = rename_name or ""
rename_idx = rename_idx or nil
show_rename_popup = show_rename_popup or false
saved_search_list = LoadSavedSearch(EXT_SECTION, saved_search_list)

--------------------------------------------- 最近搜索节点 ---------------------------------------------

local recent_search_keywords = {}
local search_input_timer = 0
local last_search_input = ""
local save_search_keyword = nil -- 保存最近搜索

function LoadRecentSearched()
  recent_search_keywords = {}
  local str = reaper.GetExtState(EXT_SECTION, "recently_searched")
  if not str or str == "" then return end
  local list = split(str, "|;|")
  for _, keyword in ipairs(list) do
    if keyword and keyword ~= "" then
      table.insert(recent_search_keywords, keyword)
    end
  end
end

function SaveRecentSearched()
  local t = {}
  for _, keyword in ipairs(recent_search_keywords) do
    table.insert(t, keyword)
  end
  local str = table.concat(t, "|;|")
  reaper.SetExtState(EXT_SECTION, "recently_searched", str, true)
end

function AddToRecentSearched(keyword)
  keyword = keyword or ""
  keyword = keyword:gsub("^%s+", ""):gsub("%s+$", "")
  if keyword == "" then return end
  -- 已存在则移到最前
  for i = #recent_search_keywords, 1, -1 do
    if recent_search_keywords[i] == keyword then
      table.remove(recent_search_keywords, i)
    end
  end
  table.insert(recent_search_keywords, 1, keyword)
  while #recent_search_keywords > max_recent_search do
    table.remove(recent_search_keywords)
  end
  SaveRecentSearched()
end

LoadRecentSearched()

--------------------------------------------- 同义词搜索 ---------------------------------------------

use_synonyms = use_synonyms or false
local thesaurus_csv_path = normalize_path(script_path .. "data/thesaurus.csv", false)
local thesaurus_map = {}

local thesaurus_f = io.open(thesaurus_csv_path, "r")
if thesaurus_f then
  thesaurus_f:read() -- 跳过首行
  for line in thesaurus_f:lines() do
    local key, thesaurus = line:match('^([^,]+),"(.-)"')
    if key and thesaurus then
      local synonyms = {}
      for word in thesaurus:gmatch("([^,]+)") do
        synonyms[#synonyms+1] = word:lower()
      end
      -- 将每个同义词都映射到完整的同义词数组
      for _, word in ipairs(synonyms) do
        thesaurus_map[word] = synonyms
      end
    end
  end
  thesaurus_f:close()
end

--------------------------------------------- 数据库 ---------------------------------------------

db_build_task = nil
mediadb_alias = LoadMediaDBAlias(EXT_SECTION) -- 加载数据库别名
tree_state.remove_path_dbfile = tree_state.remove_path_dbfile or nil
tree_state.remove_path_to_remove = tree_state.remove_path_to_remove or nil
tree_state.remove_path_confirm = tree_state.remove_path_confirm or false
-- clipper = clipper or reaper.ImGui_CreateListClipper(ctx)
build_waveform_cache = (reaper.GetExtState(EXT_SECTION, "build_waveform_cache") == "1")

--------------------------------------------- 右侧表格列表优化 ---------------------------------------------

-- Enter模式搜索过滤
local search_enter_ext = reaper.GetExtState(EXT_SECTION, "search_enter_mode")
if search_enter_ext == "" then
  search_enter_mode = false else search_enter_mode = (search_enter_ext == "1")
end
_G.commit_filter_text = _G.commit_filter_text or ""

-- 只在过滤/排序状态变化时重建 filtered_list，普通渲染时只用缓存，用于解决滚动卡死问题
local static = _G._soundmole_static or {}
_G._soundmole_static = static
static.wf_delay_cached = static.wf_delay_cached or 0.5 -- 表格列表波形已缓存延迟0.5秒
static.wf_delay_miss   = static.wf_delay_miss   or 2.0 -- 表格列表波形未缓存延迟2秒
static.filtered_list_map = static.filtered_list_map or {}  -- 用于存放所有列表缓存
static.last_filter_text_map = static.last_filter_text_map or {}
static.last_sort_specs_map  = static.last_sort_specs_map or {}

-- 模式+选中项唯一key，用来切换音频列表
function GetCurrentListKey()
  -- 不同模式下用不同字段拼接唯一key
  if collect_mode == COLLECT_MODE_MEDIADB then
    return "MEDIADB:" .. tostring(tree_state.cur_mediadb or "default")
  elseif collect_mode == COLLECT_MODE_ADVANCEDFOLDER then
    return "ADVANCEDFOLDER:" .. tostring(tree_state.cur_advanced_folder or "default")
  elseif collect_mode == COLLECT_MODE_CUSTOMFOLDER then
    return "CUSTOMFOLDER:" .. tostring(tree_state.cur_custom_folder or "default")
  elseif collect_mode == COLLECT_MODE_TREE or collect_mode == COLLECT_MODE_SHORTCUT then
    return "DIR:" .. tostring(tree_state.cur_path or "default")
  elseif collect_mode == COLLECT_MODE_ITEMS then
    return "ITEMS"
  elseif collect_mode == COLLECT_MODE_DIR then
    return "DIR"
  elseif collect_mode == COLLECT_MODE_RPP then
    return "RPP"
  elseif collect_mode == COLLECT_MODE_ALL_ITEMS then
    return "ALL_ITEMS"
  elseif collect_mode == COLLECT_MODE_RECENTLY_PLAYED then
    return "RECENTLY_PLAYED"
  else
    return "UNKNOWN"
  end
end

-- -- 根据文本框, 同义词, UCS, Saved Search 等规则，从原始files_idx_cache中构建过滤后列表。
-- function BuildFilteredList(list)
--   local filtered = {}

--   -- UCS主分类-子分类组合过滤的临时键词
--   local pair_cat = (type(temp_ucs_cat_keyword) == "string" and temp_ucs_cat_keyword ~= "" ) and temp_ucs_cat_keyword or nil
--   local pair_sub = (type(temp_ucs_sub_keyword) == "string" and temp_ucs_sub_keyword ~= "" ) and temp_ucs_sub_keyword or nil

--   for _, info in ipairs(list) do
--     -- 过滤关键词 - 与保存搜索关键词深度绑定
--     local filter_text = _G.commit_filter_text or ""

--     -- 自动保存最近搜索关键词
--     if filter_text ~= last_search_input then
--       last_search_input = filter_text
--       search_input_timer = reaper.time_precise()
--     end

--     -- 临时关键词 & UCS 分类 (& Saved Search暂不参与) 参与搜索，替代空输入。关键词不发送到搜索框
--     local search_keyword = filter_text
--     -- 隐式搜索相关代码。优先使用UCS主分类/子分类关键词，否则使用保存搜索关键词
--     if temp_search_keyword then
--       search_keyword = temp_search_keyword
--     -- 保存搜索关键词（如果启用隐式发送保存搜索关键词则应整段注释2,共两处）
--     -- elseif search_keyword == "" and active_saved_search and saved_search_list[active_saved_search] then
--     --   search_keyword = saved_search_list[active_saved_search].keyword or ""
--     end

--     -- 拆分用户输入为小写关键词数组
--     local input_keywords = {}
--     for keyword in tostring(search_keyword):gmatch("%S+") do
--       table.insert(input_keywords, keyword:lower())
--     end

--     -- 启用同义词时，将关键词分为两类。有同义词的关键词 和 无同义词的额外关键词
--     -- 同义词逻辑: synonym_keywords 为 OR，extra_keywords 为 AND
--     local synonym_keywords = {}
--     local extra_keywords = {}
--     local seen_groups = {} -- 去重同义词组

--     if use_synonyms then
--       for _, kw in ipairs(input_keywords) do
--         local synonyms = thesaurus_map[kw]
--         if synonyms then
--           local temp = {table.unpack(synonyms)}
--           table.sort(temp)
--           local group_key = table.concat(temp, ",")
--           if not seen_groups[group_key] then
--             seen_groups[group_key] = true
--             for _, synonym in ipairs(synonyms) do
--               synonym_keywords[synonym] = true
--             end
--           end
--         else
--           extra_keywords[#extra_keywords + 1] = kw
--         end
--       end
--     else
--       -- 未启用同义词时，所有关键词都是额外关键词
--       for _, kw in ipairs(input_keywords) do
--         extra_keywords[#extra_keywords + 1] = kw
--       end
--     end

--     -- 合并所有要检索的内容，全部转小写
--     local target = ""
--     if temp_search_field then
--       -- 临时指定UCS主分类/子分类字段隐式搜索
--       target = (tostring(info[temp_search_field] or "")):lower()
--     else
--       -- 多字段关键词搜索
--       for _, field in ipairs(search_fields) do
--         if field.enabled then
--           target = target .. " " .. (tostring(info[field.key] or ""))
--         end
--       end
--       target = target:lower()
--     end

--     -- 基础文本匹配
--     local match = false
--     if use_synonyms and next(synonym_keywords) then
--       -- 同义词之间为 OR 逻辑，每个同义词与额外关键词为 AND 逻辑
--       for synonym in pairs(synonym_keywords) do
--         local synonym_match = target:find(synonym, 1, true) ~= nil
--         if synonym_match then
--           local extra_match = true
--           for _, extra_kw in ipairs(extra_keywords) do
--             if not target:find(extra_kw, 1, true) then
--               extra_match = false
--               break
--             end
--           end
--           if extra_match then
--             match = true -- 找到有效组合 (synonym AND 所有额外词)，即可跳出
--             break
--           end
--         end
--       end
--     else
--       -- 未启用同义词时或无同义词时，全部关键词用 AND 逻辑
--       match = true
--       for _, kw in ipairs(extra_keywords) do
--         if not target:find(kw, 1, true) then
--           match = false
--           break
--         end
--       end
--     end

--     -- UCS主分类+子分类组合过滤
--     local pair_ok = true
--     if pair_cat and pair_sub then
--       local cat_l = tostring(info.ucs_category or ""):lower()
--       local sub_l = tostring(info.ucs_subcategory or ""):lower()
--       pair_ok = (cat_l == pair_cat) and (sub_l == pair_sub)
--     elseif pair_cat and not pair_sub then
--       local cat_l = tostring(info.ucs_category or ""):lower()
--       pair_ok = (cat_l == pair_cat)
--     end

--     -- 收集符合的info
--     if match and pair_ok then
--       table.insert(filtered, info)
--     end
--   end

--   return filtered
-- end

-- 根据文本框、同义词、UCS、Saved Search 等规则，从原始 files_idx_cache 中构建过滤后列表
function BuildFilteredList(list)
  local filtered = {}

  -- 读取一次输入框文本 & 记录输入时间，避免在循环中重复
  local filter_text = _G.commit_filter_text or ""
  if filter_text ~= last_search_input then
    last_search_input = filter_text
    search_input_timer = reaper.time_precise()
  end

  -- 计算本次有效搜索串（优先级：临时关键词 > 手动输入）
  local search_keyword = filter_text
  if temp_search_keyword then
    search_keyword = temp_search_keyword
  -- 保存搜索关键词（如果启用隐式发送保存搜索关键词则应整段注释2,共两处）
  -- elseif search_keyword == "" and active_saved_search and saved_search_list[active_saved_search] then
  --   search_keyword = saved_search_list[active_saved_search].keyword or ""
  end

  -- 拆分输入关键词为小写
  local input_keywords = {}
  for kw in tostring(search_keyword):gmatch("%S+") do
    input_keywords[#input_keywords + 1] = kw:lower()
  end

  -- 启用同义词时，将关键词分为两类。有同义词的关键词 和 无同义词的额外关键词
  -- 同义词逻辑: synonym_keywords 用 OR，extra_keywords 用 AND
  local synonym_keywords = {}
  local extra_keywords   = {}
  local seen_groups      = {} -- 去重同义词组
  local unpack_ = table.unpack or unpack
  if use_synonyms then
    for _, kw in ipairs(input_keywords) do
      local synonyms = thesaurus_map and thesaurus_map[kw] or nil
      if synonyms and #synonyms > 0 then
        -- 复制+小写+排序，生成稳定组key
        local temp = {unpack_(synonyms)}
        for i = 1, #temp do temp[i] = tostring(temp[i]):lower() end
        table.sort(temp)
        local group_key = table.concat(temp, ",")
        if not seen_groups[group_key] then
          seen_groups[group_key] = true
          for i = 1, #temp do
            synonym_keywords[temp[i]] = true
          end
        end
      else
        extra_keywords[#extra_keywords + 1] = kw
      end
    end
  else
    -- 未启用同义词时，所有关键词都是额外关键词
    for _, kw in ipairs(input_keywords) do
      extra_keywords[#extra_keywords + 1] = kw
    end
  end

  -- UCS主分类-子分类组合过滤的临时键词
  local pair_cat = (type(temp_ucs_cat_keyword) == "string" and temp_ucs_cat_keyword ~= "") and temp_ucs_cat_keyword:lower() or nil
  local pair_sub = (type(temp_ucs_sub_keyword) == "string" and temp_ucs_sub_keyword ~= "") and temp_ucs_sub_keyword:lower() or nil

  for _, info in ipairs(list) do
    -- 组装目标文本（多字段），最后一次性lower
    local tb = {}
    if temp_search_field then
      tb[1] = tostring(info[temp_search_field] or "")
    else
      local n = 0
      for _, field in ipairs(search_fields) do
        if field.enabled then
          n = n + 1
          tb[n] = tostring(info[field.key] or "")
        end
      end
      if n == 0 then tb[1] = "" end
    end
    local target = table.concat(tb, " "):lower()

    -- 文本匹配（synonym OR + extra AND；否则全 AND）
    local match = false
    if use_synonyms and next(synonym_keywords) then
      for synonym in pairs(synonym_keywords) do
        if target:find(synonym, 1, true) then
          local extra_ok = true
          for _, extra_kw in ipairs(extra_keywords) do
            if not target:find(extra_kw, 1, true) then
              extra_ok = false
              break
            end
          end
          if extra_ok then
            match = true
            break
          end
        end
      end
    else
      match = true
      for _, kw in ipairs(extra_keywords) do
        if not target:find(kw, 1, true) then
          match = false
          break
        end
      end
    end

    -- UCS 主/子类等值过滤
    local pair_ok = true
    if pair_cat and pair_sub then
      local cat_l = tostring(info.ucs_category or ""):lower()
      local sub_l = tostring(info.ucs_subcategory or ""):lower()
      pair_ok = (cat_l == pair_cat) and (sub_l == pair_sub)
    elseif pair_cat then
      local cat_l = tostring(info.ucs_category or ""):lower()
      pair_ok = (cat_l == pair_cat)
    end

    if match and pair_ok then
      filtered[#filtered + 1] = info
    end
  end

  return filtered
end

-- 右键菜单支持RS5K
function RowContextFallbackFromCell(ctx, i, info, allow_open_popup, popup_id, is_item_mode)
  if not reaper.ImGui_IsItemHovered(ctx) then return end

  if allow_open_popup and reaper.ImGui_IsMouseClicked(ctx, 1) then
    reaper.ImGui_OpenPopup(ctx, popup_id)
  end
  -- Q: 只在filename模式生效，避免和item模式的Q冲突
  if (not is_item_mode) and info.path and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Q()) then
    local tr = reaper.GetSelectedTrack(0, 0) or reaper.GetLastTouchedTrack()
    if tr then LoadAudioToRS5k(tr, info.path) end
  end
  -- Shift+Q: 只在filename模式生效，避免和item模式的Shift+Q冲突
  if (not is_item_mode) and info.path and reaper.ImGui_GetKeyMods(ctx) == reaper.ImGui_Mod_Shift() and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Q()) then
    local tr = reaper.GetSelectedTrack(0, 0) or reaper.GetLastTouchedTrack()
    if tr then LoadOnlySelectedToRS5k(tr, info.path) end
  end
end

-- 键盘快捷键
function HandleRowKeybinds(ctx, i, info, collect_mode)
  if selected_row ~= i then return end
  -- 只在窗口聚焦时响应
  if not reaper.ImGui_IsWindowFocused(ctx, reaper.ImGui_FocusedFlags_RootAndChildWindows()) then return end
  -- Q: 定位并选中usage/item
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Q()) then
    local shift = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftShift()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightShift())
    if info.usages and #info.usages > 0 then
      -- 当前索引
      info.__usage_sel_index = (info.__usage_sel_index or 1) + (shift and -1 or 1)
      local n = #info.usages
      if info.__usage_sel_index < 1 then info.__usage_sel_index = n end
      if info.__usage_sel_index > n then info.__usage_sel_index = 1 end

      local target = info.usages[info.__usage_sel_index]
      reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
      if target and target.item then
        reaper.SetMediaItemSelected(target.item, true)
        reaper.UpdateArrange()
        local pos = reaper.GetMediaItemInfo_Value(target.item, "D_POSITION")
        reaper.SetEditCurPos(pos or 0, true, false)
      end
    else
      -- 只有一个item的情况
      reaper.Main_OnCommand(40289, 0)
      if info.item then
        reaper.SetMediaItemSelected(info.item, true)
        reaper.UpdateArrange()
        local pos = reaper.GetMediaItemInfo_Value(info.item, "D_POSITION")
        reaper.SetEditCurPos(pos or 0, true, false)
      end
    end
  end

  -- F2: 重命名
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F2()) then
    if collect_mode == COLLECT_MODE_RPP then
      local old_path = normalize_path(info.path or "", false)
      local dir = old_path:match("^(.*)[/\\][^/\\]+$") or ""
      local old_filename = old_path:match("[^/\\]+$") or ""
      local ext = old_filename:match("%.[^%.]+$") or "" -- 提取原始后缀

      local ok, new_filename = reaper.GetUserInputs("Rename File", 1, "New Name:,extrawidth=200", old_filename)
      if ok and new_filename and new_filename ~= "" and new_filename ~= old_filename then
      -- 如果新文件名没有后缀，自动补全原后缀
        if not new_filename:lower():match("%.[a-z0-9]+$") and ext ~= "" then
          new_filename = new_filename .. ext
        end
        local new_path = dir .. "/" .. new_filename
        new_path = normalize_path(new_path, false)

        -- 拷贝物理文件
        local srcfile = (old_path ~= "" and io.open(old_path, "rb")) or nil
        local dstfile = (new_path ~= "" and io.open(new_path, "wb")) or nil
        if srcfile and dstfile then
          dstfile:write(srcfile:read("*a"))
          srcfile:close()
          dstfile:close()
          -- 替换所有usages的source
          for _, usage in ipairs(info.usages or {}) do
            if usage.take then
              reaper.BR_SetTakeSourceFromFile(usage.take, new_path, true)
            end
          end
          CollectFiles()
          reaper.ShowMessageBox("File copied and relinked!", "OK", 0)
        else
          reaper.ShowMessageBox("Copy failed!", "Error", 0)
        end
      end
    elseif collect_mode == COLLECT_MODE_ALL_ITEMS then
      local ok, new_name = reaper.GetUserInputs("Rename Active Take", 1, "New Name:,extrawidth=200", info.filename or "")
      if ok and new_name and new_name ~= "" then
        -- 遍历所有usages
        if info.usages and #info.usages > 0 then
          for _, usage in ipairs(info.usages) do
            if usage.take then
              reaper.GetSetMediaItemTakeInfo_String(usage.take, "P_NAME", new_name, true)
            end
          end
        elseif info.take then
          reaper.GetSetMediaItemTakeInfo_String(info.take, "P_NAME", new_name, true)
        end
        CollectFiles()
      end
    end
  end

  -- M: 静音 item 或整组 usages
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_M()) then
    if info.usages and #info.usages > 0 and info.usages[1].item then
      -- 按第一个item的当前状态决定全组mute还是unmute
      local first_mute = reaper.GetMediaItemInfo_Value(info.usages[1].item, "B_MUTE")
      local new_mute = (first_mute == 1) and 0 or 1
      for _, u in ipairs(info.usages) do
        if u.item then
          reaper.SetMediaItemInfo_Value(u.item, "B_MUTE", new_mute)
        end
      end
      reaper.UpdateArrange()
    elseif info.item then
      -- 单个
      local mute = reaper.GetMediaItemInfo_Value(info.item, "B_MUTE")
      reaper.SetMediaItemInfo_Value(info.item, "B_MUTE", mute == 1 and 0 or 1)
      reaper.UpdateArrange()
    end
  end

  -- Ctrl+D: 删除
  local ctrl = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl())
  if ctrl and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_D()) then
    if info.usages and #info.usages > 0 then
      for _, u in ipairs(info.usages) do
        if u.track and u.item then
          reaper.DeleteTrackMediaItem(u.track, u.item)
        end
      end
    elseif info.track and info.item then
      -- 单个
      reaper.DeleteTrackMediaItem(info.track, info.item)
    end
    CollectFiles()
    reaper.UpdateArrange()
  end
end

-- 统一的行右键菜单
function DrawRowPopup(ctx, i, info, collect_mode)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), colors.normal_text)

  local is_item_mode = (collect_mode == COLLECT_MODE_ALL_ITEMS or collect_mode == COLLECT_MODE_RPP)

  if is_item_mode then
    -- Media Items / RPP，item 菜单
    local is_muted = false
    if info.usages and #info.usages > 0 and info.usages[1].item then
      is_muted = (reaper.GetMediaItemInfo_Value(info.usages[1].item, "B_MUTE") == 1)
    elseif info.item then
      is_muted = (reaper.GetMediaItemInfo_Value(info.item, "B_MUTE") == 1)
    end

    if reaper.ImGui_MenuItem(ctx, "Mute", nil, is_muted) then
      local new_mute = is_muted and 0 or 1
      if info.usages and #info.usages > 0 then
        for _, usage in ipairs(info.usages) do
          if usage.item then
            reaper.SetMediaItemInfo_Value(usage.item, "B_MUTE", new_mute)
          end
        end
      elseif info.item then
        reaper.SetMediaItemInfo_Value(info.item, "B_MUTE", new_mute)
      end
      reaper.UpdateArrange()
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
          if usage.item then
            reaper.SetMediaItemSelected(usage.item, true)
          end
          reaper.UpdateArrange()
          reaper.SetEditCurPos(usage.position or 0, true, false)
          reaper.ImGui_CloseCurrentPopup(ctx)
        end
      end
      reaper.ImGui_EndMenu(ctx)
    end

    if collect_mode == COLLECT_MODE_RPP then
      if reaper.ImGui_MenuItem(ctx, "Rename file...") then
        local old_path = info.path
        local dir = old_path and old_path:match("^(.*)[/\\][^/\\]+$")
        local old_filename = old_path and old_path:match("[^/\\]+$")
        local ext = old_filename and (old_filename:match("%.[^%.]+$") or "") or "" -- 提取原始后缀

        local ok, new_filename = reaper.GetUserInputs("Rename File", 1, "New Name:,extrawidth=200", old_filename or "")
        if ok and new_filename and new_filename ~= "" and new_filename ~= old_filename then
          -- 如果新文件名没有后缀，自动补全原后缀
          if not new_filename:lower():match("%.[a-z0-9]+$") and ext ~= "" then
            new_filename = new_filename .. ext
          end
          local new_path = dir .. "/" .. new_filename
          new_path = normalize_path(new_path, false)

          -- 拷贝物理文件
          local srcfile = old_path and io.open(old_path, "rb")
          local dstfile = new_path and io.open(new_path, "wb")
          if srcfile and dstfile then
            dstfile:write(srcfile:read("*a"))
            srcfile:close()
            dstfile:close()
            -- 替换所有usages的source
            for _, usage in ipairs(info.usages or {}) do
              if usage.take then
                reaper.BR_SetTakeSourceFromFile(usage.take, new_path, true)
              end
            end
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
        local ok, new_name = reaper.GetUserInputs("Rename Active Take", 1, "New Name:,extrawidth=200", info.filename or "")
        if ok and new_name and new_name ~= "" then
          if info.usages and #info.usages > 0 then
            for _, usage in ipairs(info.usages) do
              if usage.take then
                reaper.GetSetMediaItemTakeInfo_String(usage.take, "P_NAME", new_name, true)
              end
            end
          elseif info.take then
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
        reaper.PreventUIRefresh(1)
        reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
        if info.path and info.path ~= "" then
          local insert_path = normalize_path(info.path, false)
          reaper.InsertMedia(insert_path, 0)
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

  else
    -- 右键打开文件所在目录
    if reaper.ImGui_MenuItem(ctx, "Show in Explorer/Finder") then
      local path = info.path
      if path and path ~= "" then
        reaper.CF_LocateInExplorer(normalize_path(path, false)) -- 规范分隔符
      end
    end

    -- 右键加载到RS5k，单选处理备用
    -- if reaper.ImGui_MenuItem(ctx, "Load Sample to New RS5K Track (Q)") then
    --   local tr = reaper.GetSelectedTrack(0, 0) or reaper.GetLastTouchedTrack()
    --   LoadAudioToRS5k(tr, info.path)
    -- end

    -- 右键批量加载到RS5k
    if reaper.ImGui_MenuItem(ctx, "Load Sample(s) to New RS5K Track (Q)") then
      if file_select_start and file_select_end and file_select_start ~= file_select_end then
        -- 批量: 按多选范围加载
        local a = math.min(file_select_start, file_select_end)
        local b = math.max(file_select_start, file_select_end)
        for j = a, b do
          local sel_info = _G.current_display_list[j]
          if sel_info and sel_info.path then
            -- 新建轨道
            LoadAudioToRS5k(nil, sel_info.path)
          end
        end
      else
        -- 单选: 只加载当前info
        local tr = reaper.GetSelectedTrack(0, 0) or reaper.GetLastTouchedTrack()
        LoadAudioToRS5k(tr, info.path)
      end
    end

    if reaper.ImGui_MenuItem(ctx, "Set as Active RS5K Sample (Shift+Q)") then
      local tr = reaper.GetSelectedTrack(0, 0) or reaper.GetLastTouchedTrack()
      LoadOnlySelectedToRS5k(tr, info.path)
    end
  end

  -- 批量高级文件夹音频文件移除
  if collect_mode == COLLECT_MODE_ADVANCEDFOLDER and tree_state.cur_advanced_folder then
    reaper.ImGui_Separator(ctx)
    if reaper.ImGui_MenuItem(ctx, "Remove from Collections") then
      local node = advanced_folders[tree_state.cur_advanced_folder]
      if node and node.files then
        -- 收集所有需要移除的路径
        local remove_paths = {}
        if file_select_start and file_select_end and file_select_start ~= file_select_end then
          local a = math.min(file_select_start, file_select_end)
          local b = math.max(file_select_start, file_select_end)
          for j = a, b do
            local sel_info = _G.current_display_list[j]
            if sel_info and sel_info.path then
              remove_paths[normalize_path(sel_info.path, false)] = true
            end
          end
        else
          -- 单选只移除当前info
          remove_paths[normalize_path(info.path, false)] = true
        end

        -- 倒序遍历批量移除
        for k = #node.files, 1, -1 do
          if remove_paths[normalize_path(node.files[k], false)] then
            table.remove(node.files, k)
          end
        end
        SaveAdvancedFolders()
        files_idx_cache = nil
        CollectFiles()
        -- 清空多选状态
        file_select_start, file_select_end, selected_row = nil, nil, -1
      end
    end
  end

  -- 批量数据库列表文件移除
  if collect_mode == COLLECT_MODE_MEDIADB then
    reaper.ImGui_Separator(ctx)
    if reaper.ImGui_MenuItem(ctx, "Remove from Database") then
      -- 用当前选中数据库文件
      local db_dir = script_path .. "SoundmoleDB"
      local dbfile = tree_state.cur_mediadb
      local dbpath = db_dir .. sep .. dbfile
      -- 收集要移除的路径
      local remove_paths = {}
      if file_select_start and file_select_end and file_select_start ~= file_select_end then
        local a, b = math.min(file_select_start, file_select_end), math.max(file_select_start, file_select_end)
        for j = a, b do
          local sel = _G.current_display_list[j]
          if sel and sel.path then
            remove_paths[normalize_path(sel.path, false)] = true
          end
        end
      else
        remove_paths[normalize_path(info.path, false)] = true
      end
      -- 移除选中项
      for path in pairs(remove_paths) do
        RemoveFromMediaDB(path, dbpath)
        for k = #files_idx_cache, 1, -1 do
          if normalize_path(files_idx_cache[k].path, false) == path then
            table.remove(files_idx_cache, k)
            break
          end
        end
      end

      -- 强制重建列表，失效当前数据库的过滤缓存
      local current_db_key = GetCurrentListKey()
      static.filtered_list_map[current_db_key]    = nil
      static.last_filter_text_map[current_db_key] = nil
      static.last_sort_specs_map[current_db_key]  = nil

      files_idx_cache = nil
      CollectFiles()
      -- 清空多选状态
      file_select_start, file_select_end, selected_row = nil, nil, -1
    end
  end

  reaper.ImGui_PopStyleColor(ctx, 1)
end

-- 用双延迟渲染波形
-- 已缓存波形 - 停止滚动满 wf_delay_cached 0.5秒 后，按本帧上限 fast_wf_load_limit 2从磁盘缓存批量直读并显示。
-- 未缓存波形 - 停止滚动满 wf_delay_miss 2秒 后，进入创建队列，沿用已有的 load_limit/loaded_count 限流。
function RenderWaveformCell(ctx, i, info, row_height, collect_mode, idle_time)
  local thumb_w = math.floor(reaper.ImGui_GetContentRegionAvail(ctx)) -- 自适应宽度
  local thumb_h = math.max(row_height - 2, 8) -- 自适应高度，预留 2px padding

  -- 检查宽度变化，清空内存缓存并复位标记
  if info._last_thumb_w ~= thumb_w then
    info._thumb_waveform   = {}      -- 清掉旧波形缓存
    info._last_thumb_w     = thumb_w
    info._loading_waveform = false   -- 重置标记，让 Clip­per 在空闲2秒后再次入队
  end

  -- 表格列表波形预览支持鼠标点击切换播放光标
  info._thumb_waveform = info._thumb_waveform or {}
  local wf = info._thumb_waveform[thumb_w]

  -- 已缓存时，尝试磁盘缓存直读+重映射
  if not wf and idle_time >= (static.wf_delay_cached or 0.5) and (static.fast_wf_load_count or 0) < (static.fast_wf_load_limit or 2) then
    -- 只读磁盘缓存
    local cache = LoadWaveformCache(info.path)
    if cache and cache.peaks and cache.pixel_cnt and cache.channel_count and cache.src_len then
      -- 按当前列宽重采样
      local peaks_new, pixel_cnt_new, _, chs = RemapWaveformToWindow(cache, thumb_w, 0, cache.src_len)
      if peaks_new and pixel_cnt_new and chs then
        info._thumb_waveform[thumb_w] = {
          peaks = peaks_new,
          pixel_cnt = pixel_cnt_new,
          src_len = cache.src_len,
          channel_count = chs
        }
        wf = info._thumb_waveform[thumb_w]
        info._loading_waveform = false
        static.fast_wf_load_count = (static.fast_wf_load_count or 0) + 1
      end
    end
  end

  if wf and wf.peaks and wf.peaks[1] then
    -- 绘制波形
    local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
    reaper.ImGui_PushID(ctx, i)
    DrawWaveformInImGui(ctx, {wf.peaks[1]}, thumb_w, thumb_h, wf.src_len, 1)
    reaper.ImGui_PopID(ctx)

    -- 绘制播放光标，排除最近播放影响
    if collect_mode ~= COLLECT_MODE_RECENTLY_PLAYED and playing_path == info.path and Wave and Wave.play_cursor then
      local play_px = (Wave.play_cursor / wf.src_len) * thumb_w
      local dl = reaper.ImGui_GetWindowDrawList(ctx)
      reaper.ImGui_DrawList_AddLine(dl, x + play_px, y, x + play_px, y + thumb_h, 0x808080FF, 1.5)
    end

    -- 鼠标检测 - 点击跳播，切换播放光标
    local mx, my = reaper.ImGui_GetMousePos(ctx)
    if mx >= x and mx <= x + thumb_w and my >= y and my <= y + thumb_h then
      if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsItemClicked(ctx, 0) then
        local rel_x   = mx - x
        local new_pos = (rel_x / thumb_w) * wf.src_len
        current_recent_play_info = nil -- 解除最近播放锁定
        if collect_mode == COLLECT_MODE_RECENTLY_PLAYED then
          collect_mode = last_collect_mode -- or COLLECT_MODE_SHORTCUT
        end
        if playing_path == info.path then
          RestartPreviewWithParams(new_pos)
        else
          selected_row = i
          PlayFromStart(info)
          RestartPreviewWithParams(new_pos)
        end
      end
    end
  else
    -- 未缓存时兜底入队
    if idle_time >= (static.wf_delay_miss or 2) and not info._loading_waveform then
      info._loading_waveform = true
      EnqueueWaveformTask(info, thumb_w)
    end

    -- 画灰色占位条
    -- local dl = reaper.ImGui_GetWindowDrawList(ctx)
    -- local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
    -- reaper.ImGui_DrawList_AddRectFilled(dl, x, y, x + thumb_w, y + thumb_h, 0x444444FF)
    -- reaper.ImGui_Dummy(ctx, thumb_w, thumb_h)
  end
end

function RenderFileRowByColumns(ctx, i, info, row_height, collect_mode, idle_time)
  -- 表格标题文字颜色 -- 文字颜色
  if IsPreviewed(info.path) then
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), colors.previewed_text)
  else
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), colors.normal_text)
  end
  -- 表格标题悬停及激活时颜色 -- 表格颜色 悬停颜色 激活颜色
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), colors.table_header_hovered)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), colors.table_header_active)

  -- mark 原mark相关代码备留
  -- reaper.ImGui_TableSetColumnIndex(ctx, 0)
  -- if IsPreviewed(info.path) then
  --   local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
  --   local cx, cy = reaper.ImGui_GetCursorScreenPos(ctx)
  --   local radius = 1.5
  --   local color = 0xFFF0F0F0 -- 0x00FFFFFF -- 0x22ff22ff
  --   reaper.ImGui_DrawList_AddCircleFilled(draw_list, cx + radius + 10, cy + radius + 5, radius, color)
  --   reaper.ImGui_Dummy(ctx, radius*2+4, radius*2+4)
  -- else
  --   reaper.ImGui_Dummy(ctx, 10, 10)
  -- end

  local col_count = reaper.ImGui_TableGetColumnCount(ctx)
  for c = 0, col_count - 1 do
    reaper.ImGui_TableSetColumnIndex(ctx, c)
    local col_name = reaper.ImGui_TableGetColumnName(ctx, c) or ""

    -- 名称别名，避免模式差异
    local is_name_col   = (col_name == "Take Name" or col_name == "File Name")
    local is_date_track = (col_name == "Date" or col_name == "Track")
    local is_genre_pos  = (col_name == "Genre" or col_name == "Position")

    -- Waveform
    if col_name == "Waveform" then
      RenderWaveformCell(ctx, i, info, row_height, collect_mode, idle_time)
    -- File & Teak name
    elseif is_name_col then
      local row_label = (info.filename or "-") .. "##RowContext__" .. tostring(i)
      local is_sel = false
      if file_select_start and file_select_end then
        local a = math.min(file_select_start, file_select_end)
        local b = math.max(file_select_start, file_select_end)
        is_sel = (i >= a and i <= b)
      end
      if selected_row == i then is_sel = true end
      if reaper.ImGui_Selectable(ctx, row_label, is_sel, reaper.ImGui_SelectableFlags_SpanAllColumns(), nil, row_height) then
        handle_file_click(i)
        selected_row = i
      end

      -- 双击播放
      if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
        if doubleclick_action == DOUBLECLICK_INSERT then
          WithAutoCrossfadeDisabled(function()
            reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_SAVEVIEW"), 0)
            local old_cursor = reaper.GetCursorPosition()
            reaper.PreventUIRefresh(1) -- 防止UI刷新
            reaper.InsertMedia(normalize_path(info.path, false), 0)
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
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), colors.normal_text) -- 菜单文字颜色
        reaper.ImGui_Text(ctx, "Drag to insert or collect")
        dragging_audio = {
          path = info and info.path,
          start_time = 0,
          end_time = info and info.section_length or 0,
          section_offset = info and info.section_offset or 0
        }
        -- 收集范围内所有路径
        local paths = {}
        local a = math.min(file_select_start or i, file_select_end or i)
        local b = math.max(file_select_start or i, file_select_end or i)
        for j = a, b do table.insert(paths, normalize_path(_G.current_display_list[j].path, false)) end
        reaper.ImGui_SetDragDropPayload(ctx, "AUDIO_PATHS", table.concat(paths, "|;|"))
        reaper.ImGui_PopStyleColor(ctx, 1)
        reaper.ImGui_EndDragDropSource(ctx)
      end

      -- Ctrl+左键 或 Ctrl+S 插入文件到工程
      local ctrl = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl())
      local is_ctrl_click = reaper.ImGui_IsItemClicked(ctx, 0) and ctrl
      local is_ctrl_S = ctrl and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_S())
      if (is_ctrl_click or (selected_row == i and is_ctrl_S)) then
        WithAutoCrossfadeDisabled(function()
          reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_SAVEVIEW"), 0)
          local old_cursor = reaper.GetCursorPosition()
          reaper.PreventUIRefresh(1) -- 防止UI刷新
          reaper.InsertMedia(normalize_path(info.path, false), 0)
          reaper.SetEditCurPos(old_cursor, false, false) -- 恢复光标到插入前
          reaper.PreventUIRefresh(-1)
          reaper.UpdateArrange()
          reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_RESTOREVIEW"), 0)
        end)
      end

      local popup_id = "row_popup_" .. tostring(i)
      if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
        reaper.ImGui_OpenPopup(ctx, popup_id)
      end
      if reaper.ImGui_BeginPopup(ctx, popup_id) then
        DrawRowPopup(ctx, i, info, collect_mode) -- 根据 collect_mode 自动分流菜单
        reaper.ImGui_EndPopup(ctx)
      end

      -- 键盘快捷键
      HandleRowKeybinds(ctx, i, info, collect_mode)
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Size
    elseif col_name == "Size" then
      local size_str
      if info.size >= 1024*1024 then
        size_str = string.format("%.2f MB", info.size / 1024 / 1024)
      elseif info.size >= 1024 then
        size_str = string.format("%.2f KB", info.size / 1024)
      else
        size_str = string.format("%d B", info.size)
      end
      reaper.ImGui_Text(ctx, size_str)
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Type
    elseif col_name == "Type" then
      reaper.ImGui_Text(ctx, info.type)
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Date & Track name
    elseif is_date_track then
      if collect_mode == COLLECT_MODE_ALL_ITEMS or collect_mode == COLLECT_MODE_RPP then -- Media items or RPP
        if info.usages and #info.usages > 1 then
          reaper.ImGui_Text(ctx, ("%d instances"):format(#info.usages))
        else
          reaper.ImGui_Text(ctx, info.track_name or "-")
        end
        -- 右键 usage 跳转
        local popup_id2 = "item_context_menu__" .. tostring(i)
        if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
          reaper.ImGui_OpenPopup(ctx, popup_id2)
        end
        if reaper.ImGui_BeginPopup(ctx, popup_id2) then
          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), colors.normal_text) -- 菜单文字颜色
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
        reaper.ImGui_Text(ctx, info.bwf_orig_date or "-")
      end

      RowContextFallbackFromCell(ctx, i, info, false, popup_id, is_item_mode)  -- 只给 Q，不打开主菜单

    -- Genre & Position
    elseif is_genre_pos then
      if collect_mode == COLLECT_MODE_ALL_ITEMS or collect_mode == COLLECT_MODE_RPP then -- Media items or RPP
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
          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), colors.normal_text) -- 菜单文字颜色
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
        reaper.ImGui_Text(ctx, info.genre or "-")
      end
      RowContextFallbackFromCell(ctx, i, info, false, popup_id, is_item_mode) -- 只给 Q，不打开主菜单

    -- Comment
    elseif col_name == "Comment" then
      reaper.ImGui_Text(ctx, info.comment or "-")
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Description
    elseif col_name == "Description" then
      reaper.ImGui_Text(ctx, info.description or "-")
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Category/SubCategory/CatID (UCS)
    elseif col_name == "Category" then
      reaper.ImGui_Text(ctx, info.ucs_category or "")
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)
    elseif col_name == "SubCategory" then
      reaper.ImGui_Text(ctx, info.ucs_subcategory or "")
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)
    elseif col_name == "CatID" then
      reaper.ImGui_Text(ctx, info.ucs_catid or "")
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Length
    elseif col_name == "Length" then
      local len_str = (info.length and info.length > 0) and reaper.format_timestr(info.length, "") or "-"
      reaper.ImGui_Text(ctx, len_str)
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Channels
    elseif col_name == "Channels" then
      reaper.ImGui_Text(ctx, info.channels)
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Samplerate
    elseif col_name == "Samplerate" then
      reaper.ImGui_Text(ctx, info.samplerate or "-")
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Bits
    elseif col_name == "Bits" then
      reaper.ImGui_Text(ctx, info.bits or "-")
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Group
    elseif col_name == "Group" then
      local group_names = GetCustomGroupsForPath(normalize_path(info.path, false))
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
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), colors.normal_text) -- 菜单文字颜色
        -- 收集当前高亮范围内的所有 info
        local list = _G.current_display_list or {}
        local infos = {}
        if file_select_start and file_select_end then
          local a = math.min(file_select_start, file_select_end)
          local b = math.max(file_select_start, file_select_end)
          for j = a, b do
            table.insert(infos, list[j])
          end
        else
          -- 无多选时，单条传入
          table.insert(infos, list[i])
        end
        ShowGroupMenu(infos)
        reaper.ImGui_PopStyleColor(ctx, 1)
        reaper.ImGui_EndPopup(ctx)
      end

    -- Path
    elseif col_name == "Path" then
      reaper.ImGui_Text(ctx, normalize_path(info.path or "", false))
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)
    end
  end

  reaper.ImGui_PopStyleColor(ctx, 3)
end

function loop()
  -- 首次使用时收集音频文件
  if not files_idx_cache then
    CollectFiles()
  end
  -- 表格列表波形预览，每帧先处理任务队列
  ProcessWaveformTasks()
  if need_refresh_font then -- mark相关代码
    fonts.sans_serif = reaper.ImGui_CreateFont(set_font, 14)
    reaper.ImGui_Attach(ctx, fonts.sans_serif)
    need_refresh_font = false
  end
  reaper.ImGui_PushFont(ctx, fonts.sans_serif, 14)
  reaper.ImGui_SetNextWindowBgAlpha(ctx, bg_alpha) -- 背景不透明度

  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 6.0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(),  4.0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowTitleAlign(), 0.5, 0.5)

  local visible, open = reaper.ImGui_Begin(ctx, SCRIPT_NAME, true)

  -- 脚本折叠时清理旧专辑封面，避免折叠展开时报错。
  if not visible and last_window_visible then
    if last_cover_img and reaper.ImGui_DestroyImage then
      reaper.ImGui_DestroyImage(last_cover_img)
    end
    last_cover_img, last_cover_path = nil, nil
    static.clipper = nil -- 防止ImGui_ListClipper报错
  end
  last_window_visible = visible

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
    local filter_w = 430 -- 输入框宽度

    -- 标题栏
    reaper.ImGui_BeginGroup(ctx)
    -- 计算按钮高度，让文字垂直居中
    reaper.ImGui_Dummy(ctx, 0, 0)
    reaper.ImGui_PushFont(ctx, fonts.title, 25)
    reaper.ImGui_Text(ctx, ' Soundmole')
    reaper.ImGui_PopFont(ctx)
    reaper.ImGui_EndGroup(ctx)

    -- 搜索字段下拉菜单
    reaper.ImGui_SameLine(ctx, nil, 15)
    reaper.ImGui_BeginGroup(ctx)

    reaper.ImGui_SetNextItemWidth(ctx, 150)
    local selected_labels = {}
    for _, field in ipairs(search_fields) do
      if field.enabled then
        table.insert(selected_labels, field.label)
      end
    end
    -- 下拉菜单列表若无选中则显示默认，否则用+号连接
    local combo_label = (#selected_labels > 0) and table.concat(selected_labels, "+") or "Select Fields"
    if reaper.ImGui_BeginCombo(ctx, "##search_fields", combo_label, reaper.ImGui_WindowFlags_NoScrollbar()) then -- reaper.ImGui_ComboFlags_NoArrowButton()
      for i, field in ipairs(search_fields) do
        local changed, enabled = reaper.ImGui_Checkbox(ctx, field.label, field.enabled)
        if changed then
          field.enabled = enabled
          SaveSearchFields()
        end
      end
      reaper.ImGui_EndCombo(ctx)
    end
    -- 悬停提示已勾选列表
    if #selected_labels > 0 and reaper.ImGui_IsItemHovered(ctx) then
      reaper.ImGui_SetTooltip(ctx, table.concat(selected_labels, "+"))
    end

    reaper.ImGui_SameLine(ctx, nil, 10)
    if not filename_filter then
      filename_filter = reaper.ImGui_CreateTextFilter()
      reaper.ImGui_Attach(ctx, filename_filter)
    end
    reaper.ImGui_SetNextItemWidth(ctx, filter_w)
    reaper.ImGui_TextFilter_Draw(filename_filter, ctx, "##FilterQWERT")

    _G.just_committed_filter = false
    -- 按enter搜索
    if search_enter_mode then
      if (reaper.ImGui_IsItemActive(ctx) or reaper.ImGui_IsItemFocused(ctx)) and
        (reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) or
          reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_KeypadEnter())) then
        local txt = reaper.ImGui_TextFilter_Get(filename_filter) or ""
        _G.commit_filter_text = txt
        _G.just_committed_filter = true

        -- Enter模式: 立刻保存到最近搜索
        if txt ~= "" then
          if txt ~= last_search_input then
            AddToRecentSearched(txt)
            last_search_input = txt
          end
          search_input_timer = math.huge -- 防重复保存
        end
      end
    else
      -- 实时模式: 0.5秒防抖(实时搜索模式停顿0.5秒再执行)+停顿2秒自动保存
      local live = reaper.ImGui_TextFilter_Get(filename_filter) or ""
      local now = reaper.time_precise()
      _G._live_prev, _G._live_t = _G._live_prev or "", _G._live_t or now
      if live ~= _G._live_prev then
        _G._live_prev = live
        _G._live_t = now
      end
      if now - _G._live_t >= 0.5 then _G.commit_filter_text = live end

      local cur = _G.commit_filter_text
      if cur ~= last_search_input then
        last_search_input = cur
        search_input_timer = now
      end
      if cur ~= "" and now - (search_input_timer or 0) > 2 then
        AddToRecentSearched(cur)
        search_input_timer = math.huge
      end
    end

    reaper.ImGui_Text(ctx, '') -- 换行占位符
    reaper.ImGui_SameLine(ctx, nil, 60)
    reaper.ImGui_Text(ctx, 'Thesaurus:')
    reaper.ImGui_SameLine(ctx, nil, 10)
    local changed_synonyms, new_use_synonyms = reaper.ImGui_Checkbox(ctx, "##Synonyms", use_synonyms)
    if changed_synonyms then
      use_synonyms = new_use_synonyms
      -- 同义词勾选时强制重建，否则不工作
      static.filtered_list_map    = {}
      static.last_filter_text_map = {}
    end

    -- 同义词显示输入框
    reaper.ImGui_BeginDisabled(ctx, not use_synonyms) -- 输入框置灰
    local filter_text = reaper.ImGui_TextFilter_Get(filename_filter) or ""
    local synonym_display_parts = {}
    local shown_synonym_groups = {} -- 同义词去重

    if filter_text ~= "" then
      for keyword in filter_text:gmatch("%S+") do
        local synonyms = thesaurus_map[keyword:lower()]
        if synonyms then
          local sorted = {table.unpack(synonyms)} -- 将同义词排序后拼接为唯一标识
          -- table.sort(sorted) -- 对同义词排序
          local key = table.concat(sorted, ",")
          if not shown_synonym_groups[key] then
            shown_synonym_groups[key] = true
            local display = table.concat(sorted, "||")
            table.insert(synonym_display_parts, "(" .. display .. ")")
          end
        else
          table.insert(synonym_display_parts, "(" .. keyword .. ")")
        end
      end
    end

    local synonym_display_text = #synonym_display_parts > 0 and table.concat(synonym_display_parts, " ") or ""

    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_SetNextItemWidth(ctx, filter_w)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), colors.thesaurus_text)
    reaper.ImGui_InputText(ctx, "##SynonymDisplay", synonym_display_text, reaper.ImGui_InputTextFlags_ReadOnly())
    reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_EndDisabled(ctx)
    reaper.ImGui_EndGroup(ctx)

    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_BeginGroup(ctx)
    -- 清空过滤器内容
    reaper.ImGui_SameLine(ctx, nil, 10)
    if reaper.ImGui_Button(ctx, "Clear", 80, 46) then
      reaper.ImGui_TextFilter_Set(filename_filter, "")

      _G.commit_filter_text = "" -- 立即清空生效查询（Enter模式）
      -- 清除临时搜索字段，UCS隐式搜索临时关键词
      active_saved_search = nil
      temp_search_field, temp_search_keyword = nil
      temp_ucs_cat_keyword, temp_ucs_sub_keyword = nil, nil

      static.filtered_list_map    = {}
      static.last_filter_text_map = {}
      selected_row = nil
    end
    if reaper.ImGui_IsItemHovered(ctx) then
      reaper.ImGui_BeginTooltip(ctx)
      reaper.ImGui_Text(ctx, 'Clear the search box.')
      reaper.ImGui_EndTooltip(ctx)
    end
    -- if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F4()) then
    --   reaper.ImGui_TextFilter_Set(filename_filter, "")
    -- end

    -- 刷新按钮
    reaper.ImGui_SameLine(ctx, nil, 10)
    if reaper.ImGui_Button(ctx, "Rescan", 80, 46) then
      CollectFiles()
    end
    if reaper.ImGui_IsItemHovered(ctx) then
      reaper.ImGui_BeginTooltip(ctx)
      reaper.ImGui_Text(ctx, "F5: Rescan and refresh the audio file list.")
      reaper.ImGui_EndTooltip(ctx)
    end
    -- F5
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F5()) then
      CollectFiles()
    end

    -- 恢复（撤销所有过滤/搜索）
    reaper.ImGui_SameLine(ctx, nil, 10)
    if reaper.ImGui_Button(ctx, "Restore All", 80, 46) then
      reaper.ImGui_TextFilter_Set(filename_filter, "")

      _G.commit_filter_text = "" -- 立即清空生效查询（Enter模式）
      -- 清除临时搜索字段，UCS隐式搜索临时关键词
      active_saved_search = nil
      temp_search_field, temp_search_keyword = nil
      temp_ucs_cat_keyword, temp_ucs_sub_keyword = nil, nil

      static.filtered_list_map    = {}
      static.last_filter_text_map = {}
      selected_row = nil  
    end
    if reaper.ImGui_IsItemHovered(ctx) then
      reaper.ImGui_BeginTooltip(ctx)
      reaper.ImGui_Text(ctx, 'Restore all (undo all filters/search).')
      reaper.ImGui_EndTooltip(ctx)
    end
    -- if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F6()) then
    --   reaper.ImGui_TextFilter_Set(filename_filter, "")
    --   active_saved_search = nil
    -- end

    -- 当前播放文件的路径
    local file_info
    if collect_mode == COLLECT_MODE_RECENTLY_PLAYED and current_recent_play_info then -- 最近播放模式时使用播放列表项
      file_info = current_recent_play_info
    elseif _G.current_display_list and selected_row and _G.current_display_list[selected_row] then
      file_info = _G.current_display_list[selected_row] -- 其他模式用右侧表格选中项
      selected_recent_row = 0 -- 清空最近播放选中项
    else
      file_info = last_playing_info
    end

    local show_cur_path = file_info and file_info.path or ""
    show_cur_path = normalize_path(show_cur_path, false)
    local same_folder = show_cur_path:match("^(.*)[/\\][^/\\]-$")
    reaper.ImGui_SameLine(ctx, nil, 10)
    if reaper.ImGui_Button(ctx, "Same Folder", 80, 46) then
      tree_state.cur_path = normalize_path(same_folder, true)
      RefreshFolderFiles(same_folder)
    end
    if reaper.ImGui_IsItemHovered(ctx) then
      reaper.ImGui_BeginTooltip(ctx)
      reaper.ImGui_Text(ctx, "Click to jump to this folder and list its audio files.")
      reaper.ImGui_EndTooltip(ctx)
    end

    -- 创建数据库按钮
    reaper.ImGui_SameLine(ctx, nil, 10)
    if reaper.ImGui_Button(ctx, "Database##scan_folder_top", 80, 46) then -- Select Folder and Scan Audio
      local rv, folder = reaper.JS_Dialog_BrowseForFolder("Choose folder to scan audio files:", "")
      if rv == 1 and folder and folder ~= "" then
        folder = normalize_path(folder, true)
        local filelist = ScanAllAudioFiles(folder)
        local db_dir = script_path .. "SoundmoleDB"
        EnsureCacheDir(db_dir)
        -- 获取下一个可用编号
        local db_index = GetNextMediaDBIndex(db_dir) -- 00~FF
        local dbfile = string.format("%s.MoleFileList", db_index) -- 只有文件名
        local dbpath = normalize_path(db_dir, true) .. dbfile     -- 全路径
        local f = io.open(dbpath, "wb") if f then f:close() end
        AddPathToDBFile(dbpath, folder)
        db_build_task = {
          filelist = filelist,
          dbfile = dbpath,
          idx = 1,
          total = #filelist,
          finished = false,
          root_path  = folder,
        }
      end
    end

    reaper.ImGui_EndGroup(ctx)
    reaper.ImGui_Dummy(ctx, 1, 1) -- 控件下方 + 1px 间距

    -- 自动缩放音频表格
    local line_h = reaper.ImGui_GetTextLineHeight(ctx)
    local avail_x, avail_y = reaper.ImGui_GetContentRegionAvail(ctx)
    -- 减去标题栏高度和底部间距。减去播放控件+波形预览+时间线9+进度条+地址栏的高度=228 +加分割条的厚度3=240
    local child_h = math.max(10, avail_y - line_h - ui_bottom_offset - img_h_offset)
    if child_h < 10 then child_h = 10 end -- 最小高度保护(需要使用 if reaper.ImGui_BeginChild 才有效)
    
    local splitter_w = 3 -- 分割条宽度
    local min_left = math.floor(avail_x * 0.005) -- 最小左侧宽度占比
    local max_left = math.floor(avail_x * 0.5) -- 最大左侧宽度占比

    -- 用 left_ratio 实时计算宽度
    local left_w = math.floor(avail_x * left_ratio)
    local right_w = avail_x - left_w - splitter_w

    -- 左侧树状目录(此处需要使用 if 才有效，否则报错)
    if reaper.ImGui_BeginChild(ctx, "##left", left_w, child_h, 0, reaper.ImGui_WindowFlags_HorizontalScrollbar()) then
      if reaper.ImGui_BeginTabBar(ctx, 'PeekTreeUcsTabBar', reaper.ImGui_TabBarFlags_None()) then
        -- PeekTree列表
        if reaper.ImGui_BeginTabItem(ctx, 'PeekTree') then
          -- 内容字体自由缩放
          local wheel = reaper.ImGui_GetMouseWheel(ctx)
          local ctrl  = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
          if preview_fonts[font_size] then
            reaper.ImGui_PushFont(ctx, preview_fonts[font_size], 14)
          end
          if wheel ~= 0 and ctrl and reaper.ImGui_IsWindowHovered(ctx) then
            -- 找到当前字号在列表中的索引
            local cur_idx = 1
            for i, v in ipairs(preview_font_sizes) do
              if v == font_size then
                cur_idx = i
                break
              end
            end
            cur_idx = cur_idx + wheel
            cur_idx = math.max(1, math.min(#preview_font_sizes, cur_idx))
            font_size = preview_font_sizes[cur_idx]
            wheel = 0
          end

          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), colors.normal_text) -- 文本颜色
          
          -- 渲染单选列表
          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), colors.transparent)

          local hdr_flags = project_open and reaper.ImGui_TreeNodeFlags_DefaultOpen() or 0
          local is_project_open = reaper.ImGui_CollapsingHeader(ctx, "Project Collection", nil, hdr_flags)
          project_open = is_project_open

          reaper.ImGui_PopStyleColor(ctx)
          if is_project_open then
            reaper.ImGui_Indent(ctx, 7) -- 手动缩进16像素
            for i, v in ipairs(collect_mode_labels) do
              local selected = (collect_mode == v.value)
              -- reaper.ImGui_AlignTextToFramePadding(ctx)
              if reaper.ImGui_Selectable(ctx, v.label, selected) then
                collect_mode = v.value
                selected_index = i
                tree_open = {} -- 切到非tree时收起tree
                files_idx_cache = nil
                CollectFiles()
              end
            end
            reaper.ImGui_Unindent(ctx, 7)
          end

          -- Tree模式特殊处理（折叠节点）
          local flag = (collect_mode == COLLECT_MODE_TREE) and reaper.ImGui_TreeNodeFlags_DefaultOpen() or 0
          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), colors.transparent)
          local tree_expanded = reaper.ImGui_CollapsingHeader(ctx, "This Computer") -- , nil, flag)
          reaper.ImGui_PopStyleColor(ctx)
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
          end

          -- 文件夹快捷方式节点
          if not shortcut_nodes_inited then
            expanded_paths = {}
            -- 递归将选中路径及其父目录都加入 expanded_paths
            if tree_state.cur_path and tree_state.cur_path ~= "" then
              local p = tree_state.cur_path:gsub("[/\\]+$", "")
              while p and p ~= "" do
                expanded_paths[p] = true
                local parent = p:match("^(.*)[/\\][^/\\]+$") -- 只去掉最后一级
                p = parent
              end
            end
            shortcut_nodes_inited = true
          end

          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), colors.transparent)

          local hdr_flags = shortcut_open and reaper.ImGui_TreeNodeFlags_DefaultOpen() or 0
          local is_shortcut_open = reaper.ImGui_CollapsingHeader(ctx, "Folder Shortcuts", nil, hdr_flags)
          shortcut_open = is_shortcut_open

          reaper.ImGui_PopStyleColor(ctx)
          if is_shortcut_open then
            reaper.ImGui_Indent(ctx, 7) -- 手动缩进16像素
            for i = 1, #folder_shortcuts do
              draw_shortcut_tree(folder_shortcuts[i])
            end
            -- 添加新快捷方式按钮
            if reaper.ImGui_Button(ctx, "Create Shortcut##add_folder_shortcut", 140, 40) then
              local rv, folder = reaper.JS_Dialog_BrowseForFolder("Choose folder to add shortcut:", "")
              if rv == 1 and folder and folder ~= "" then
                folder = normalize_path(folder, true)
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
          end

          -- 高级文件夹节点 Collections
          if not adv_folder_nodes_inited then
            expanded_ids = {}
            local p = tree_state.cur_advanced_folder
            while p and advanced_folders[p] and advanced_folders[p].parent do
              local par = advanced_folders[p].parent
              expanded_ids[par] = true
              p = par
            end
            adv_folder_nodes_inited = true
          end

          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), colors.transparent)

          local hdr_flags = collection_open and reaper.ImGui_TreeNodeFlags_DefaultOpen() or 0
          local is_collection_open = reaper.ImGui_CollapsingHeader(ctx, "Collections", nil, hdr_flags)
          collection_open = is_collection_open

          reaper.ImGui_PopStyleColor(ctx)
          if is_collection_open then
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
            if reaper.ImGui_Button(ctx, "Create Collection##add_adv_folder", 140, 40) then
              local ret, name = reaper.GetUserInputs("Create Collection", 1, "Collection Name:,extrawidth=200", "")
              if ret and name and name ~= "" then
                local new_id = new_guid()
                advanced_folders[new_id] = { id = new_id, name = name, parent = nil, children = {}, files = {} } -- 写入 advanced_folders 表
                table.insert(root_advanced_folders, new_id)
                SaveAdvancedFolders()
              end
            end
            reaper.ImGui_Unindent(ctx, 7)
          end

          -- 自定义文件夹节点 Group
          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), colors.transparent)

          local hdr_flags = group_open and reaper.ImGui_TreeNodeFlags_DefaultOpen() or 0
          local is_group_open = reaper.ImGui_CollapsingHeader(ctx, "Group##group", nil, hdr_flags)
          group_open = is_group_open

          reaper.ImGui_PopStyleColor(ctx)
          if is_group_open then
            reaper.ImGui_Indent(ctx, 7) -- 手动缩进16像素
            for i, folder in ipairs(custom_folders) do
              local is_selected = (collect_mode == COLLECT_MODE_CUSTOMFOLDER and tree_state.cur_custom_folder == folder)
              if reaper.ImGui_Selectable(ctx, folder, is_selected) then
                -- 切换自定义文件夹目录选中状态，清空文件列表多选/主选中
                file_select_start = nil
                file_select_end   = nil
                selected_row      = -1
                handle_group_click(i, folder)
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

              -- 拖动目标文件到分组
              if reaper.ImGui_BeginDragDropTarget(ctx) then
                -- 接收批量路径
                if reaper.ImGui_AcceptDragDropPayload(ctx, "AUDIO_PATHS") then
                  local retval, dtype, payload = reaper.ImGui_GetDragDropPayload(ctx)
                  if retval and dtype == "AUDIO_PATHS" and type(payload) == "string" and payload ~= "" then
                    -- 确保表存在
                    custom_folders_content[folder] = custom_folders_content[folder] or {}
                    -- 按分隔符拆分每条路径
                    for path in payload:gmatch("([^|;|]+)") do
                      local drag_path = normalize_path(path, false)
                      -- 去重检查
                      local exists = false
                      for _, p in ipairs(custom_folders_content[folder]) do
                        if p == drag_path then
                          exists = true
                          break
                        end
                      end
                      if not exists then
                        table.insert(custom_folders_content[folder], drag_path)
                      end
                    end
                    -- 存储并刷新
                    SaveCustomFolders()
                    if collect_mode == COLLECT_MODE_CUSTOMFOLDER and tree_state.cur_custom_folder == folder then
                      CollectFiles()
                    end
                  end
                end
                reaper.ImGui_EndDragDropTarget(ctx)
              end
            end
            -- 新建自定义文件夹按钮
            if reaper.ImGui_Button(ctx, "Create Group##add_custom_folder", 140, 40) then
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
          end

          -- 数据库节点
          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), colors.transparent)

          local hdr_flags = mediadb_open and reaper.ImGui_TreeNodeFlags_DefaultOpen() or 0
          local is_mediadb_open = reaper.ImGui_CollapsingHeader(ctx, "Database##dbfilelist", nil, hdr_flags)
          mediadb_open = is_mediadb_open

          reaper.ImGui_PopStyleColor(ctx)
          if is_mediadb_open then
            reaper.ImGui_Indent(ctx, 7)
            local mediadb_files = {}
            local db_dir = script_path .. "SoundmoleDB"
            local i = 0
            while true do
              local dbfile = reaper.EnumerateFiles(db_dir, i)
              if not dbfile then break end
              if dbfile:match("%.MoleFileList$") then
                table.insert(mediadb_files, dbfile)
              end
              i = i + 1
            end

            for _, dbfile in ipairs(mediadb_files) do
              local alias = mediadb_alias[dbfile] or dbfile -- 优先显示别名
              local is_selected = (collect_mode == COLLECT_MODE_MEDIADB and tree_state.cur_mediadb == dbfile)
              if reaper.ImGui_Selectable(ctx, alias, is_selected) then
                collect_mode = COLLECT_MODE_MEDIADB
                tree_state.cur_mediadb = dbfile
                -- 清除选中状态
                file_select_start = nil
                file_select_end   = nil
                selected_row      = -1

                files_idx_cache = nil
                CollectFiles()
              end
              
              -- 右键菜单
              if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
                reaper.ImGui_OpenPopup(ctx, "SoundmoleDBMenu_" .. dbfile)
              end
              if reaper.ImGui_BeginPopup(ctx, "SoundmoleDBMenu_" .. dbfile) then

                -- 重命名数据库
                if reaper.ImGui_MenuItem(ctx, "Rename Database") then
                  local ret, newname = reaper.GetUserInputs("Rename DB", 1, "New Name:,extrawidth=180", mediadb_alias[dbfile] or dbfile)
                  if ret and newname and newname ~= "" and newname ~= dbfile then
                    mediadb_alias[dbfile] = newname
                    SaveMediaDBAlias(EXT_SECTION, mediadb_alias)
                  end
                end
                -- 删除数据库
                if reaper.ImGui_MenuItem(ctx, "Delete Database") then
                  local filename = dbfile:match("[^/\\]+$")
                  local alias = mediadb_alias[filename] or filename
                  local res = reaper.ShowMessageBox(
                    ("Are you sure you want to delete the database:\n%s (%s)\n\nThis action cannot be undone."):format(alias, dbfile),
                    "Confirm Delete",
                    4 -- 4 = Yes/No
                  )
                  if res == 6 then -- 6 = Yes
                    -- 删除数据库文件本身
                    local db_path = normalize_path(db_dir, true) .. dbfile
                    os.remove(db_path)
                    mediadb_alias[dbfile] = nil
                    SaveMediaDBAlias(EXT_SECTION, mediadb_alias)
                    if tree_state.cur_mediadb == dbfile then
                      tree_state.cur_mediadb = ""
                      files_idx_cache = {}
                    end
                  end
                end
                reaper.ImGui_Separator(ctx)
                -- 添加路径到数据库
                if reaper.ImGui_MenuItem(ctx, "Add Path to Database...") then
                  tree_state.add_path_dbfile = dbfile -- 记录当前要添加路径的数据库
                  tree_state.add_path_popup = true -- 标记弹窗
                end
                -- 从数据库移除路径
                if reaper.ImGui_BeginMenu(ctx, "Remove Path from Database") then
                  local db_dir = script_path .. "SoundmoleDB"
                  local dbpath = normalize_path(db_dir, true) .. dbfile
                  local path_list = GetPathListFromDB(dbpath)
                  for _, p in ipairs(path_list) do
                    if reaper.ImGui_MenuItem(ctx, p) then
                      -- 记录要删除的信息
                      tree_state.remove_path_dbfile = dbfile
                      tree_state.remove_path_to_remove = p
                      tree_state.remove_path_confirm = true
                    end
                  end
                  reaper.ImGui_EndMenu(ctx)
                end

                -- 增量更新数据库
                if reaper.ImGui_MenuItem(ctx, "Scan Database for New Files") then -- Incremental Database Update
                  -- 读取PATH行拿到根目录
                  local dbpath = normalize_path(db_dir, true) .. dbfile
                  local root
                  for line in io.lines(dbpath) do
                    root = line:match('^PATH%s+"(.-)"')
                    if root then break end
                  end
                  if not root or root == "" then
                    reaper.ShowMessageBox("No PATH in DB file", "Error", 0)
                  else
                    -- 扫描所有音频，筛选出未入库的新文件
                    local newfiles = ScanAllAudioFiles(root)
                    local existing = {}
                    for _, info in ipairs(files_idx_cache or {}) do
                      existing[normalize_path(info.path, false)] = true
                    end
                    -- 仅保留新增的文件
                    local to_add = {}
                    for _, fpath in ipairs(newfiles) do
                      local key = normalize_path(fpath, false)
                      if not existing[key] then
                        table.insert(to_add, fpath)
                      end
                    end
                    -- 如果没有新文件直接提示
                    if #to_add == 0 then
                      reaper.ShowMessageBox("No new files to add.", "Update Complete", 0)
                    else
                      -- 异步任务，由主循环进度条处理
                      local filename = dbfile:match("[^/\\]+$")
                      db_build_task = {
                        filelist = to_add,
                        dbfile = dbpath,
                        idx = 1,
                        total = #to_add,
                        finished = false,
                        alias = mediadb_alias[filename] or filename, -- mediadb_alias[dbfile] or "Unnamed",
                        root_path = root,
                        is_incremental = true
                      }
                    end
                  end
                end

                -- 全量重建数据库
                if reaper.ImGui_MenuItem(ctx, "Rebuild Database") then
                  -- 读取 PATH 行，拿到根目录
                  local dbpath, root_dir
                  dbpath = normalize_path(db_dir, true) .. dbfile
                  for line in io.lines(dbpath) do
                    root_dir = line:match('^PATH%s+"(.-)"')
                    if root_dir then break end
                  end
                  if not root_dir or root_dir == "" then
                    reaper.ShowMessageBox("No PATH found in DB file", "Error", 0)
                  else
                    -- 清空旧库并写入PATH
                    local f = io.open(dbpath, "wb")
                    f:write(('PATH "%s"\n'):format(root_dir))
                    f:close()
                    -- 异步任务，由主循环进度条处理
                    local filename = dbfile:match("[^/\\]+$")
                    local all = ScanAllAudioFiles(root_dir)
                    db_build_task = {
                      filelist = all,
                      dbfile = dbpath,
                      idx = 1,
                      total = #all,
                      finished = false,
                      alias = mediadb_alias[filename] or filename, -- mediadb_alias[dbfile] or "Unnamed",
                      root_path = root_dir,
                      is_rebuild = true -- 标记为重建
                    }
                  end
                end

                reaper.ImGui_EndPopup(ctx)
              end

              -- 拖动列表的音频文件到数据库中
              if reaper.ImGui_BeginDragDropTarget(ctx) then
                if reaper.ImGui_AcceptDragDropPayload(ctx, "AUDIO_PATHS") then
                  local ok, dtype, payload = reaper.ImGui_GetDragDropPayload(ctx)
                  if ok and dtype == "AUDIO_PATHS" and type(payload) == "string" and payload ~= "" then
                    -- 目标数据库文件绝对路径 .MoleFileList
                    local dbpath = normalize_path(db_dir, true) .. dbfile
                    local root_dir = tree_state.cur_scan_folder or ""
                    for path in payload:gmatch("([^|;|]+)") do
                      local p = normalize_path(path, false)
                      local info = CollectFileInfo(p)
                      WriteToMediaDB(info, dbpath)
                    end
                    -- 刷新文件列表
                    if collect_mode == COLLECT_MODE_MEDIADB and tree_state.cur_mediadb == dbfile then
                      CollectFiles()
                    end
                  end
                end
                reaper.ImGui_EndDragDropTarget(ctx)
              end
            end

            -- 数据库按钮
            if reaper.ImGui_Button(ctx, "Create Database", 140, 40) then
              local db_dir = script_path .. "SoundmoleDB"
              EnsureCacheDir(db_dir)
              local db_index = GetNextMediaDBIndex(db_dir) -- 00~FF
              local dbfile = string.format("%s/%s.MoleFileList", db_dir, db_index)
              local f = io.open(dbfile, "wb") f:close()
            end

            reaper.ImGui_Unindent(ctx, 7)
          end

          -- 最近搜索节点
          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), colors.transparent)

          local hdr_flags_search = recent_search_open and reaper.ImGui_TreeNodeFlags_DefaultOpen() or 0
          local is_search_open = reaper.ImGui_CollapsingHeader(ctx, "Recently Searched##recent_search", nil, hdr_flags_search)
          recent_search_open = is_search_open

          reaper.ImGui_PopStyleColor(ctx)
          if is_search_open then
            reaper.ImGui_Indent(ctx, 7)
            for i, keyword in ipairs(recent_search_keywords) do
              local selected = false
              if reaper.ImGui_Selectable(ctx, keyword, selected) then
                -- 点击发送到搜索框
                reaper.ImGui_TextFilter_Set(filename_filter, keyword)
                -- 点击关键词时，同时回填到过滤框并更新_G.commit_filter_text
                local kw = keyword or ""
                _G.commit_filter_text    = kw
                _G.just_committed_filter = true -- 如果外部有提交后写入最近搜索的一次性逻辑可用
                last_search_input        = kw
                search_input_timer       = reaper.time_precise()
              end
              -- 右键菜单
              if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
                reaper.ImGui_OpenPopup(ctx, "recent_search_menu_" .. i)
              end
              if reaper.ImGui_BeginPopup(ctx, "recent_search_menu_" .. i) then
                if reaper.ImGui_MenuItem(ctx, "Save as Saved Search") then
                  show_add_popup = true
                  new_search_name = keyword
                  save_search_keyword = keyword
                  reaper.ImGui_CloseCurrentPopup(ctx)
                end
                if reaper.ImGui_MenuItem(ctx, "Delete this record") then
                  table.remove(recent_search_keywords, i)
                  SaveRecentSearched()
                  reaper.ImGui_CloseCurrentPopup(ctx)
                end
                reaper.ImGui_EndPopup(ctx)
              end
            end
            -- 保存搜索关键词弹窗
            if show_add_popup then
              reaper.ImGui_OpenPopup(ctx, "Add Search")
              show_add_popup = false
            end

            local add_visible = reaper.ImGui_BeginPopupModal(ctx, "Add Search", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize())
            if add_visible then
              reaper.ImGui_Text(ctx, "Name:")
              reaper.ImGui_SameLine(ctx)
              local input_changed, input_val = reaper.ImGui_InputText(ctx, "##new_name", new_search_name or "", 256)
              if input_changed then new_search_name = input_val end
              reaper.ImGui_Text(ctx, "Keyword: " .. (save_search_keyword or ""))
              reaper.ImGui_Separator(ctx)

              local win_w = reaper.ImGui_GetWindowWidth(ctx)
              local btn_w = 64
              local spacing = 8 -- 两个按钮间距
              -- 光标移到右侧对齐
              local padding_x = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding())
              reaper.ImGui_SetCursorPosX(ctx, win_w - (btn_w * 2 + spacing + padding_x * 2))

              if reaper.ImGui_Button(ctx, "OK", btn_w) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_KeypadEnter()) then
                if (new_search_name or "") ~= "" and (save_search_keyword or "") ~= "" then
                  -- 避免重名
                  local exists = false
                  for _, s in ipairs(saved_search_list) do
                    if s.name == new_search_name then exists = true break end
                  end
                  if not exists then
                    table.insert(saved_search_list, {name = new_search_name, keyword = save_search_keyword})
                    SaveSavedSearch(EXT_SECTION, saved_search_list)
                  end
                end
                reaper.ImGui_CloseCurrentPopup(ctx)
                new_search_name = ""
                save_search_keyword = ""
              end
              reaper.ImGui_SameLine(ctx)
              if reaper.ImGui_Button(ctx, "Cancel", btn_w) then
                reaper.ImGui_CloseCurrentPopup(ctx)
                new_search_name = ""
                save_search_keyword = ""
              end
              reaper.ImGui_EndPopup(ctx)
            end

            reaper.ImGui_Unindent(ctx, 7)
          end

          -- 最近播放节点
          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), colors.transparent)

          local hdr_flags = recent_open and reaper.ImGui_TreeNodeFlags_DefaultOpen() or 0
          local is_recent_open = reaper.ImGui_CollapsingHeader(ctx, "Recently Played##recent", nil, hdr_flags)
          recent_open = is_recent_open

          reaper.ImGui_PopStyleColor(ctx)
          if is_recent_open then
            reaper.ImGui_Indent(ctx, 7) -- 手动缩进16像素
            for i, info in ipairs(recent_audio_files) do
              if i > max_recent_files then break end
              local selected = (selected_recent_row == i)
              if reaper.ImGui_Selectable(ctx, info.filename, selected) then
                selected_recent_row = i
                -- 进入最近播放前先保存当前模式
                if collect_mode ~= COLLECT_MODE_RECENTLY_PLAYED then
                  last_collect_mode = collect_mode
                end
                collect_mode = COLLECT_MODE_RECENTLY_PLAYED -- 切换到最近播放模式
                local full_info = BuildFileInfoFromPath(normalize_path(info.path, false), info.filename) -- 重新补全文件信息
                PlayFromStart(full_info) -- 播放文件并加载波形
                current_recent_play_info = full_info
              end

              -- 右键弹出菜单
              if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
                reaper.ImGui_OpenPopup(ctx, "recent_file_menu_" .. i)
              end
              if reaper.ImGui_BeginPopup(ctx, "recent_file_menu_" .. i) then
                if reaper.ImGui_MenuItem(ctx, "Show in Explorer/Finder") then
                  if info.path and info.path ~= "" then
                    reaper.CF_LocateInExplorer(normalize_path(info.path)) -- 规范分隔符
                  end
                end
                reaper.ImGui_EndPopup(ctx)
              end
            end
            reaper.ImGui_Unindent(ctx, 7)
          end

          reaper.ImGui_PopStyleColor(ctx, 1) -- 恢复文本
          reaper.ImGui_PopFont(ctx)          -- 内容字体自由缩放
          reaper.ImGui_EndTabItem(ctx)
        end
        -- UCS列表
        if reaper.ImGui_BeginTabItem(ctx, 'UCS') then
          reaper.ImGui_Text(ctx, "Filter:")
          reaper.ImGui_SameLine(ctx)
          if not usc_filter then
            usc_filter = reaper.ImGui_CreateTextFilter()
            reaper.ImGui_Attach(ctx, usc_filter)
          end
          reaper.ImGui_SetNextItemWidth(ctx, -65)
          reaper.ImGui_TextFilter_Draw(usc_filter, ctx, "##FilterUCS")
          reaper.ImGui_SameLine(ctx)
          if reaper.ImGui_Button(ctx, "Clear", 40) then
            reaper.ImGui_TextFilter_Set(usc_filter, "")
            temp_search_keyword, temp_search_field = nil, nil -- 清除UCS隐式搜索
          end
          reaper.ImGui_Separator(ctx)

          local filter_text = ""
          if usc_filter then
            filter_text = reaper.ImGui_TextFilter_Get(usc_filter)
          end
          -- 过滤时，自动展开子分类匹配但主分类不匹配的主分类
          if filter_text ~= ucs_last_filter_text then
            ucs_last_filter_text = filter_text
            -- 清空所有折叠
            if filter_text == "" then
              cat_open_state = {}
            else
              -- 只重设需要自动展开的分类
              for _, cat in ipairs(cat_names) do
                local subs = categories[cat]
                local filtered = {}
                local cat_matched = false
                if filter_text ~= "" then
                  cat_matched = reaper.ImGui_TextFilter_PassFilter(usc_filter, cat)
                  if cat_matched then
                    filtered = subs
                  else
                    for _, entry in ipairs(subs) do
                      if reaper.ImGui_TextFilter_PassFilter(usc_filter, entry.name) then
                        table.insert(filtered, entry)
                      end
                    end
                  end
                else
                  filtered = subs
                end
                -- 只自动展开主分类不匹配但有子分类匹配的分类
                if not cat_matched and #filtered > 0 then
                  cat_open_state[cat] = true
                elseif filter_text ~= "" and cat_matched then
                  cat_open_state[cat] = false
                end
              end
            end
          end

          for _, cat in ipairs(cat_names) do
            local subs = categories[cat]
            local filtered = {}
            local cat_matched = false
            if filter_text ~= "" then
              cat_matched = reaper.ImGui_TextFilter_PassFilter(usc_filter, cat)
              if cat_matched then
                filtered = subs
              else
                for _, entry in ipairs(subs) do
                  if reaper.ImGui_TextFilter_PassFilter(usc_filter, entry.name) then
                    table.insert(filtered, entry)
                  end
                end
              end
            else
              filtered = subs
            end

            if #filtered > 0 then
              reaper.ImGui_PushID(ctx, cat)
              local is_open = cat_open_state[cat] and true or false
              local arrow_label = is_open and "-" or "+"
              if reaper.ImGui_Button(ctx, arrow_label .. "##toggle", 20, 20) then
                cat_open_state[cat] = not is_open
                local en = (ucs_maps and ucs_maps.cat_to_en and ucs_maps.cat_to_en[cat]) or cat
                ucs_open_en = ucs_open_en or {}
                if cat_open_state[cat] then ucs_open_en[en] = true else ucs_open_en[en] = nil end
              end
              reaper.ImGui_SameLine(ctx)
              -- 点击主分类提交隐式搜索
              if reaper.ImGui_Selectable(ctx, cat .. "##cat", false, reaper.ImGui_SelectableFlags_SpanAllColumns()) then
                local send_cat = cat
                if UCS_FORCE_EN and ucs_maps and ucs_maps.cat_to_en[cat] then
                  send_cat = ucs_maps.cat_to_en[cat] -- force EN
                end
                temp_ucs_cat_keyword = tostring(send_cat):lower()
                temp_ucs_sub_keyword = nil
                temp_search_field, temp_search_keyword = nil, nil
                active_saved_search = nil

                local static = _G._soundmole_static or {}
                _G._soundmole_static = static
                static.filtered_list_map    = {}
                static.last_filter_text_map = {}
              end

              -- 点击子分类发送主+子分类关键词隐式搜索
              if is_open then
                for _, entry in ipairs(filtered) do
                  reaper.ImGui_PushID(ctx, entry.name)
                  reaper.ImGui_Indent(ctx, 28)
                  if reaper.ImGui_Selectable(ctx, entry.name .. "##sub") then
                    local send_cat = cat
                    local send_sub = entry.name
                    if UCS_FORCE_EN and ucs_maps then
                      send_cat = (ucs_maps.cat_to_en[cat] or send_cat)
                      local sub_map = ucs_maps.sub_to_en[cat] or {}
                      send_sub = (sub_map[entry.name] or send_sub)
                    end

                    temp_ucs_cat_keyword = tostring(send_cat):lower()
                    temp_ucs_sub_keyword = tostring(send_sub):lower()
                    temp_search_field, temp_search_keyword = nil, nil
                    active_saved_search = nil

                    local static = _G._soundmole_static or {}
                    _G._soundmole_static = static
                    static.filtered_list_map    = {}
                    static.last_filter_text_map = {}
                  end
                  reaper.ImGui_Unindent(ctx, 28)
                  reaper.ImGui_PopID(ctx)
                end
              end
              reaper.ImGui_PopID(ctx)
            end
          end
          reaper.ImGui_EndTabItem(ctx)
        end

        -- TAB 标签页 Saved Search
        if reaper.ImGui_BeginTabItem(ctx, 'Saved Search') then
          prev_filter_text = prev_filter_text or ""
          local filter_text = reaper.ImGui_TextFilter_Get(filename_filter) or ""
          if prev_filter_text ~= filter_text then
            active_saved_search = nil
            temp_search_keyword, temp_search_field = nil, nil -- 清除 UCS 隐式搜索
          end
          prev_filter_text = filter_text

          -- 添加搜索词按钮
          if reaper.ImGui_Button(ctx, "Save Current Search") then
            new_search_name = filter_text
            show_add_popup = true
          end

          -- 添加搜索词弹窗
          if show_add_popup then
            reaper.ImGui_OpenPopup(ctx, "Add Search")
            show_add_popup = false
          end
          local add_visible = reaper.ImGui_BeginPopupModal(ctx, "Add Search", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize())
          if add_visible then
            reaper.ImGui_Text(ctx, "Name:")
            reaper.ImGui_SameLine(ctx)
            local input_changed, input_val = reaper.ImGui_InputText(ctx, "##new_name", new_search_name or "", 256)
            if input_changed then new_search_name = input_val end
            reaper.ImGui_Text(ctx, "Keyword: " .. (filter_text or ""))
            reaper.ImGui_Separator(ctx)

            local win_w = reaper.ImGui_GetWindowWidth(ctx)
            local btn_w = 64
            local spacing = 8 -- 两个按钮间距
            -- 光标移到右侧对齐
            local padding_x = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding())
            reaper.ImGui_SetCursorPosX(ctx, win_w - (btn_w * 2 + spacing + padding_x * 2))

            if reaper.ImGui_Button(ctx, "OK", btn_w) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_KeypadEnter()) then
              if (new_search_name or "") ~= "" and (filter_text or "") ~= "" then
                -- 避免重名
                local exists = false
                for _, s in ipairs(saved_search_list) do
                  if s.name == new_search_name then exists = true break end
                end
                if not exists then
                  table.insert(saved_search_list, {name = new_search_name, keyword = filter_text})
                  SaveSavedSearch(EXT_SECTION, saved_search_list)
                end
              end
              reaper.ImGui_CloseCurrentPopup(ctx)
              new_search_name = ""
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Cancel", btn_w) then
              reaper.ImGui_CloseCurrentPopup(ctx)
              new_search_name = ""
            end
            reaper.ImGui_EndPopup(ctx)
          end
          reaper.ImGui_Separator(ctx)

          for idx, s in ipairs(saved_search_list) do
            reaper.ImGui_PushID(ctx, "saved_search_" .. idx)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(),        0x00000000)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), 0x00000000)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(),  0x00000000)

            local text_w = math.floor(reaper.ImGui_GetContentRegionAvail(ctx))
            local pos_x, pos_y = reaper.ImGui_GetCursorScreenPos(ctx)

            -- 组合显示文本: Name (keyword)
            local label = (s.name or "")
            if (s.keyword or "") ~= "" then
              label = string.format("%s (%s)", s.name or "", s.keyword or "")
            end

            -- 用不可见标签创建可点击/可悬浮的区域
            local clicked = reaper.ImGui_Selectable(ctx, "##saved_sel_" .. idx, false, 0, text_w - 56, 0)
            local hovered = reaper.ImGui_IsItemHovered(ctx)

            -- 按悬浮状态切换文字颜色，手动在同一位置绘制一次文本
            reaper.ImGui_SetCursorScreenPos(ctx, pos_x, pos_y)
            if hovered then
              reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), colors.table_header_active)
              reaper.ImGui_Text(ctx, label)
              reaper.ImGui_PopStyleColor(ctx)
            else
              reaper.ImGui_Text(ctx, label)
            end

            -- 将保存搜索关键词发送过滤框（隐式搜索，如果启用隐式发送保存搜索关键词则应整段注释1,共两处）
            if clicked then
              active_saved_search = idx
              local kw = s.keyword or ""
              if filename_filter then
                reaper.ImGui_TextFilter_Set(filename_filter, kw)    -- 回填到输入框
              end   
              _G.commit_filter_text    = kw                         -- 列表过滤使用
              _G.just_committed_filter = true                       -- 如外部有一次性提交逻辑可用
              last_search_input        = kw                         -- 同步输入状态
              search_input_timer       = reaper.time_precise()      -- 重置计时，避免重复写入
              temp_ucs_cat_keyword, temp_ucs_sub_keyword = nil, nil -- 清除主-子组合过滤残留
            end

            -- 恢复关键词文字样式颜色
            reaper.ImGui_PopStyleColor(ctx, 3)

            -- 名称区域右键菜单
            if reaper.ImGui_BeginPopupContextItem(ctx, "##context_saved_search_name", 1) then
              if reaper.ImGui_MenuItem(ctx, "Rename") then
                show_rename_popup = true
                rename_idx = idx
                rename_name = s.name
              end
              if reaper.ImGui_MenuItem(ctx, "Remove") then
                remove_search_idx = idx
              end
              reaper.ImGui_EndPopup(ctx)
            end
            -- 上下移动按钮靠右对齐
            reaper.ImGui_SameLine(ctx)
            local btn_w = 20
            local total_btn_w = btn_w * 2 + 8 -- 两个按钮+间距
            local avail = reaper.ImGui_GetContentRegionAvail(ctx)
            if avail > total_btn_w then
              reaper.ImGui_Dummy(ctx, avail - total_btn_w - 8, 0)
              reaper.ImGui_SameLine(ctx)
            end
            -- 上移
            if idx > 1 then
              if reaper.ImGui_ArrowButton(ctx, "##up", reaper.ImGui_Dir_Up()) then
                local temp = saved_search_list[idx - 1]
                saved_search_list[idx - 1] = saved_search_list[idx]
                saved_search_list[idx] = temp
                SaveSavedSearch(EXT_SECTION, saved_search_list)
              end
            else
              reaper.ImGui_Dummy(ctx, btn_w, 20)
            end
            reaper.ImGui_SameLine(ctx, nil, 4)
            -- 下移
            if idx < #saved_search_list then
              if reaper.ImGui_ArrowButton(ctx, "##down", reaper.ImGui_Dir_Down()) then
                local temp = saved_search_list[idx + 1]
                saved_search_list[idx + 1] = saved_search_list[idx]
                saved_search_list[idx] = temp
                SaveSavedSearch(EXT_SECTION, saved_search_list)
              end
            else
              reaper.ImGui_Dummy(ctx, btn_w, 20)
            end

            reaper.ImGui_PopID(ctx)
          end

          -- 用户输入重命名的弹窗
          if show_rename_popup and rename_idx then
            reaper.ImGui_OpenPopup(ctx, "Rename Search")
            show_rename_popup = false
          end

          local rename_visible = reaper.ImGui_BeginPopupModal(ctx, "Rename Search", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize())
          if rename_visible and rename_idx then
            reaper.ImGui_Text(ctx, "Rename to: ")
            reaper.ImGui_SameLine(ctx)
            local input_changed, input_val = reaper.ImGui_InputText(ctx, "##rename_input", rename_name or "", 256)
            if input_changed then rename_name = input_val end
            reaper.ImGui_Separator(ctx)
            if reaper.ImGui_Button(ctx, "OK") or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_KeypadEnter()) then
              if (rename_name or "") ~= "" then
                -- 检查重名
                local exists = false
                for i, s in ipairs(saved_search_list) do
                  if s.name == rename_name and i ~= rename_idx then
                    exists = true
                    break
                  end
                end
                if not exists then
                  saved_search_list[rename_idx].name = rename_name
                  SaveSavedSearch(EXT_SECTION, saved_search_list)
                end
              end
              reaper.ImGui_CloseCurrentPopup(ctx)
              rename_idx = nil
              rename_name = ""
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Cancel") then
              reaper.ImGui_CloseCurrentPopup(ctx)
              rename_idx = nil
              rename_name = ""
            end
            reaper.ImGui_EndPopup(ctx)
          end
          
          if remove_search_idx then
            table.remove(saved_search_list, remove_search_idx)
            SaveSavedSearch(EXT_SECTION, saved_search_list)
            remove_search_idx = nil
          end
          reaper.ImGui_EndTabItem(ctx)
        end

        reaper.ImGui_EndTabBar(ctx)
      end
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
      if reaper.ImGui_BeginTable(ctx, "filelist", 17,
        -- reaper.ImGui_TableFlags_RowBg() -- 表格背景交替颜色
        reaper.ImGui_TableFlags_Borders() -- 表格分隔线
        | reaper.ImGui_TableFlags_BordersOuter() -- 表格边界线
        | reaper.ImGui_TableFlags_Resizable()
        | reaper.ImGui_TableFlags_ScrollY()
        | reaper.ImGui_TableFlags_ScrollX()
        | reaper.ImGui_TableFlags_Sortable()
        | reaper.ImGui_TableFlags_Hideable()
        | reaper.ImGui_TableFlags_Reorderable() -- 拖拽列
      ) then
        reaper.ImGui_TableSetupScrollFreeze(ctx, 0, 1) -- 只冻结表头
        if collect_mode == COLLECT_MODE_ALL_ITEMS then -- Media Items
          reaper.ImGui_TableSetupColumn(ctx, "Waveform",        reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort() | reaper.ImGui_TableColumnFlags_NoReorder(), 100) -- 锁定列不允许拖动
          reaper.ImGui_TableSetupColumn(ctx, "Take Name",   reaper.ImGui_TableColumnFlags_WidthFixed(), 200, TableColumns.FILENAME)
          reaper.ImGui_TableSetupColumn(ctx, "Size",        reaper.ImGui_TableColumnFlags_WidthFixed(), 55, TableColumns.SIZE)
          reaper.ImGui_TableSetupColumn(ctx, "Type",        reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.TYPE)
          reaper.ImGui_TableSetupColumn(ctx, "Track",       reaper.ImGui_TableColumnFlags_WidthFixed(), 100, TableColumns.DATE)
          reaper.ImGui_TableSetupColumn(ctx, "Position",    reaper.ImGui_TableColumnFlags_WidthFixed(), 80, TableColumns.GENRE)
          reaper.ImGui_TableSetupColumn(ctx, "Comment",     reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.COMMENT)
          reaper.ImGui_TableSetupColumn(ctx, "Description", reaper.ImGui_TableColumnFlags_WidthFixed(), 200, TableColumns.DESCRIPTION)
          reaper.ImGui_TableSetupColumn(ctx, "Category",    reaper.ImGui_TableColumnFlags_WidthFixed(), 80, TableColumns.CATEGORY)
          reaper.ImGui_TableSetupColumn(ctx, "SubCategory", reaper.ImGui_TableColumnFlags_WidthFixed(), 80, TableColumns.SUBCATEGORY)
          reaper.ImGui_TableSetupColumn(ctx, "CatID",       reaper.ImGui_TableColumnFlags_WidthFixed(), 80, TableColumns.CATID)
          reaper.ImGui_TableSetupColumn(ctx, "Length",      reaper.ImGui_TableColumnFlags_WidthFixed(), 60, TableColumns.LENGTH)
          reaper.ImGui_TableSetupColumn(ctx, "Channels",    reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.CHANNELS)
          reaper.ImGui_TableSetupColumn(ctx, "Samplerate",  reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.SAMPLERATE)
          reaper.ImGui_TableSetupColumn(ctx, "Bits",        reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.BITS)
          reaper.ImGui_TableSetupColumn(ctx, "Group",       reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 40)
          reaper.ImGui_TableSetupColumn(ctx, "Path",        reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 300)
        elseif collect_mode == COLLECT_MODE_RPP then -- RPP
          reaper.ImGui_TableSetupColumn(ctx, "Waveform",        reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 100)
          reaper.ImGui_TableSetupColumn(ctx, "File Name",   reaper.ImGui_TableColumnFlags_WidthFixed(), 200, TableColumns.FILENAME)
          reaper.ImGui_TableSetupColumn(ctx, "Size",        reaper.ImGui_TableColumnFlags_WidthFixed(), 55, TableColumns.SIZE)
          reaper.ImGui_TableSetupColumn(ctx, "Type",        reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.TYPE)
          reaper.ImGui_TableSetupColumn(ctx, "Track",       reaper.ImGui_TableColumnFlags_WidthFixed(), 100, TableColumns.DATE)
          reaper.ImGui_TableSetupColumn(ctx, "Position",    reaper.ImGui_TableColumnFlags_WidthFixed(), 80, TableColumns.GENRE)
          reaper.ImGui_TableSetupColumn(ctx, "Comment",     reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.COMMENT)
          reaper.ImGui_TableSetupColumn(ctx, "Description", reaper.ImGui_TableColumnFlags_WidthFixed(), 200, TableColumns.DESCRIPTION)
          reaper.ImGui_TableSetupColumn(ctx, "Category",    reaper.ImGui_TableColumnFlags_WidthFixed(), 80, TableColumns.CATEGORY)
          reaper.ImGui_TableSetupColumn(ctx, "SubCategory", reaper.ImGui_TableColumnFlags_WidthFixed(), 80, TableColumns.SUBCATEGORY)
          reaper.ImGui_TableSetupColumn(ctx, "CatID",       reaper.ImGui_TableColumnFlags_WidthFixed(), 80, TableColumns.CATID)
          reaper.ImGui_TableSetupColumn(ctx, "Length",      reaper.ImGui_TableColumnFlags_WidthFixed(), 60, TableColumns.LENGTH)
          reaper.ImGui_TableSetupColumn(ctx, "Channels",    reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.CHANNELS)
          reaper.ImGui_TableSetupColumn(ctx, "Samplerate",  reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.SAMPLERATE)
          reaper.ImGui_TableSetupColumn(ctx, "Bits",        reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.BITS)
          reaper.ImGui_TableSetupColumn(ctx, "Group",       reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 40)
          reaper.ImGui_TableSetupColumn(ctx, "Path",        reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 300)
        else
          reaper.ImGui_TableSetupColumn(ctx, "Waveform",        reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 100)
          reaper.ImGui_TableSetupColumn(ctx, "File Name",        reaper.ImGui_TableColumnFlags_WidthFixed(), 250, TableColumns.FILENAME)
          reaper.ImGui_TableSetupColumn(ctx, "Size",        reaper.ImGui_TableColumnFlags_WidthFixed(), 55, TableColumns.SIZE)
          reaper.ImGui_TableSetupColumn(ctx, "Type",        reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.TYPE)
          reaper.ImGui_TableSetupColumn(ctx, "Date",        reaper.ImGui_TableColumnFlags_WidthFixed(), 55, TableColumns.DATE)
          reaper.ImGui_TableSetupColumn(ctx, "Genre",       reaper.ImGui_TableColumnFlags_WidthFixed(), 55, TableColumns.GENRE)
          reaper.ImGui_TableSetupColumn(ctx, "Comment",     reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.COMMENT)
          reaper.ImGui_TableSetupColumn(ctx, "Description", reaper.ImGui_TableColumnFlags_WidthFixed(), 200, TableColumns.DESCRIPTION)
          reaper.ImGui_TableSetupColumn(ctx, "Category",    reaper.ImGui_TableColumnFlags_WidthFixed(), 80, TableColumns.CATEGORY)
          reaper.ImGui_TableSetupColumn(ctx, "SubCategory", reaper.ImGui_TableColumnFlags_WidthFixed(), 80, TableColumns.SUBCATEGORY)
          reaper.ImGui_TableSetupColumn(ctx, "CatID",       reaper.ImGui_TableColumnFlags_WidthFixed(), 80, TableColumns.CATID)
          reaper.ImGui_TableSetupColumn(ctx, "Length",      reaper.ImGui_TableColumnFlags_WidthFixed(), 60, TableColumns.LENGTH)
          reaper.ImGui_TableSetupColumn(ctx, "Channels",    reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.CHANNELS)
          reaper.ImGui_TableSetupColumn(ctx, "Samplerate",  reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.SAMPLERATE)
          reaper.ImGui_TableSetupColumn(ctx, "Bits",        reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.BITS)
          reaper.ImGui_TableSetupColumn(ctx, "Group",       reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 40)
          reaper.ImGui_TableSetupColumn(ctx, "Path",        reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 300)
        end
        -- 此处新增时，记得累加 filelist 的列表数量。测试元数据内容 - CollectFromProjectDirectory()
        reaper.ImGui_TableHeadersRow(ctx)
        
        -- 获取当前激活数据库的唯一key
        local current_db_key = GetCurrentListKey() -- tostring(tree_state.cur_mediadb)

        -- 检测数据库切换，清空静态缓存（解决数据库创建时列表为空问题）
        static.last_db_key = static.last_db_key or ""
        if current_db_key ~= static.last_db_key then
          -- 新数据库，清空所有缓存
          static.filtered_list_map    = {}
          static.last_filter_text_map = {}
          static.last_sort_specs_map  = {}
          static.last_db_key          = current_db_key
        end

        -- 获取排序状态
        local need_sort, has_specs = reaper.ImGui_TableNeedSort(ctx)
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

        -- 判断是否有过滤/排序变化
        local sort_specs_str = tostring(sort_specs[1] and sort_specs[1].user_id or "") .. (sort_specs[1] and sort_specs[1].sort_dir or "")

        local eff_text = _G.commit_filter_text or ""
        local ucs_sig  = tostring(temp_search_field or "") .. "|" .. tostring(temp_search_keyword or "")
        local eff      = eff_text .. "||" .. ucs_sig

        local last_filter_text = static.last_filter_text_map[current_db_key] or ""
        local last_sort_specs  = static.last_sort_specs_map[current_db_key] or ""
        local filtered_list    = static.filtered_list_map[current_db_key]

        -- 判断过滤/排序是否变更
        local filter_changed   = (eff ~= last_filter_text)
        local sort_changed = (sort_specs_str ~= last_sort_specs)

        if filter_changed or sort_changed or not filtered_list then
          filtered_list = BuildFilteredList(files_idx_cache)
          if #sort_specs > 0 and filtered_list then
            table.sort(filtered_list, function(a, b)
              for _, spec in ipairs(sort_specs) do
                if spec.user_id == TableColumns.FILENAME then
                  if a.filename ~= b.filename then -- File 列排序
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return a.filename > b.filename
                    else
                      return a.filename < b.filename
                    end
                  end
                elseif spec.user_id == TableColumns.SIZE then -- Size 列排序
                  local asize = tonumber(a.size) or 0
                  local bsize = tonumber(b.size) or 0
                  if asize ~= bsize then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return asize > bsize
                    else
                      return asize < bsize
                    end
                  end
                elseif spec.user_id == TableColumns.TYPE then -- Type 列排序
                  if a.type ~= b.type then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return a.type > b.type
                    else
                      return a.type < b.type
                    end
                  end
                elseif spec.user_id == TableColumns.DATE then -- Date 列排序
                  if (a.bwf_orig_date or "") ~= (b.bwf_orig_date or "") then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return (a.bwf_orig_date or "") > (b.bwf_orig_date or "")
                    else
                      return (a.bwf_orig_date or "") < (b.bwf_orig_date or "")
                    end
                  end
                elseif spec.user_id == TableColumns.GENRE then -- Genre & Position 列排序
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
                elseif spec.user_id == TableColumns.COMMENT then -- Comment 列排序
                  if (a.comment or "") ~= (b.comment or "") then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return (a.comment or "") > (b.comment or "")
                    else
                      return (a.comment or "") < (b.comment or "")
                    end
                  end
                elseif spec.user_id == TableColumns.DESCRIPTION then -- Description 列排序
                  if (a.description or "") ~= (b.description or "") then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return (a.description or "") > (b.description or "")
                    else
                      return (a.description or "") < (b.description or "")
                    end
                  end
                elseif spec.user_id == TableColumns.LENGTH then -- Length 列排序
                  local alen = tonumber(a.length) or 0
                  local blen = tonumber(b.length) or 0
                  if alen ~= blen then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return alen > blen
                    else
                      return alen < blen
                    end
                  end
                elseif spec.user_id == TableColumns.CHANNELS then -- Channels 列排序
                  local achan = tonumber(a.channels) or 0
                  local bchan = tonumber(b.channels) or 0
                  if achan ~= bchan then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return achan > bchan
                    else
                      return achan < bchan
                    end
                  end
                elseif spec.user_id == TableColumns.SAMPLERATE then -- Samplerate 列排序
                  local asr = tonumber(a.samplerate) or 0
                  local bsr = tonumber(b.samplerate) or 0
                  if asr ~= bsr then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return asr > bsr
                    else
                      return asr < bsr
                    end
                  end
                elseif spec.user_id == TableColumns.BITS then -- Bits 列排序
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
          static.filtered_list_map[current_db_key] = filtered_list
          static.last_filter_text_map[current_db_key] = eff
          static.last_sort_specs_map[current_db_key]  = sort_specs_str
        end

        _G.current_display_list = filtered_list

        -- 内容字体自由缩放
        local wheel = reaper.ImGui_GetMouseWheel(ctx)
        local ctrl  = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
        if preview_fonts[font_size] then
          reaper.ImGui_PushFont(ctx, preview_fonts[font_size], 14)
        end
        if wheel ~= 0 and ctrl and reaper.ImGui_IsWindowHovered(ctx) then
          -- 找到当前字号在列表中的索引
          local cur_idx = 1
          for i, v in ipairs(preview_font_sizes) do
            if v == font_size then
              cur_idx = i
              break
            end
          end
          cur_idx = cur_idx + wheel
          cur_idx = math.max(1, math.min(#preview_font_sizes, cur_idx))
          font_size = preview_font_sizes[cur_idx]
          wheel = 0
        end

        -- 上下方向键选中文件
        local num_files = filtered_list and #filtered_list or 0
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
          if auto_play_selected and played and selected_row and filtered_list[selected_row] then
            local info = filtered_list[selected_row]
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

        local wave_col = -1
        local col_count = reaper.ImGui_TableGetColumnCount(ctx)
        for c = 0, col_count - 1 do
          if (reaper.ImGui_TableGetColumnName(ctx, c) or "") == "Waveform" then
            wave_col = c
            break
          end
        end

        local wave_w
        if wave_col >= 0 then
          reaper.ImGui_TableSetColumnIndex(ctx, wave_col)
          wave_w = math.floor(reaper.ImGui_GetContentRegionAvail(ctx))
        else
          wave_w = 120 -- 没有 Waveform 列时的兜底宽度
        end

        local tw = math.floor(reaper.ImGui_GetContentRegionAvail(ctx))
        local load_limit   = 2 -- 每帧最多2个波形加载任务，波形加载限制2个
        local loaded_count = 0
        -- 限制本帧已缓存直读次数，避免IO抖动
        static.fast_wf_load_count = 0
        static.fast_wf_load_limit = static.fast_wf_load_limit or 2

        -- 限制加载波形，指定列表无滚动时多少秒之后才开始加载。用于解决脚本卡顿问题。
        local now_time = reaper.time_precise()
        static.last_scroll_time = static.last_scroll_time or now_time
        static.last_scroll_y    = static.last_scroll_y or reaper.ImGui_GetScrollY(ctx)
        local cur_scroll_y      = reaper.ImGui_GetScrollY(ctx)
        local wheel             = reaper.ImGui_GetMouseWheel(ctx)
        if cur_scroll_y ~= static.last_scroll_y or wheel ~= 0 then
          static.last_scroll_y    = cur_scroll_y
          static.last_scroll_time = now_time
        end
        local idle_time = now_time - static.last_scroll_time -- 停止滚动多久

        -- 确保 clipper 存在，避免列表不可见时 ImGui_ListClipper_Begin 报错修复
        if not static.clipper then
          static.clipper = reaper.ImGui_CreateListClipper(ctx)
        end
        local clipper = static.clipper

        reaper.ImGui_ListClipper_Begin(clipper, #filtered_list)
        while reaper.ImGui_ListClipper_Step(clipper) do
          local display_start, display_end = reaper.ImGui_ListClipper_GetDisplayRange(clipper)
          if idle_time >= (static.wf_delay_miss or 2) then -- 未缓存，停顿2秒再入队
            -- clipper+限流+防止重复加入
            for idx = display_start + 1, display_end do
              if loaded_count >= load_limit then break end -- 波形加载，限制本帧最大加载数2个

              local inf = filtered_list[idx]
              inf._thumb_waveform = inf._thumb_waveform or {}
              if not inf._thumb_waveform[tw] and not inf._loading_waveform then
                inf._loading_waveform = true -- 设置加载标记，防止重复加入
                EnqueueWaveformTask(inf, tw)
                loaded_count = loaded_count + 1
              end
            end
          end

          -- 每行渲染，按当前列名
          for i = display_start + 1, display_end do
            local info = filtered_list[i]
            reaper.ImGui_TableNextRow(ctx, reaper.ImGui_TableRowFlags_None(), row_height)
            RenderFileRowByColumns(ctx, i, info, row_height, collect_mode, idle_time)

            -- 上下按键自动滚动到可见行并且高亮
            if selected_row == i and _G.scroll_target then
              reaper.ImGui_SetScrollHereY(ctx, _G.scroll_target)
              _G.scroll_target = nil
            end

            -- 自动播放切换表格中的音频文件
            if auto_play_next_pending and type(auto_play_next_pending) == "table" then
              local next_idx = -1
              local target_path = normalize_path(auto_play_next_pending.path, false) -- 规范化目标路径
              for ii, inf2 in ipairs(filtered_list or {}) do
                if normalize_path(inf2.path, false) == target_path then
                  next_idx = ii
                  break
                end
              end
              if next_idx > 0 then
                selected_row = next_idx
                _G.scroll_target = 0.5 -- 下一帧表格自动滚动到中间
              end
              PlayFromStart(auto_play_next_pending)
              auto_play_next_pending = nil
            end
          end
        end
        reaper.ImGui_ListClipper_End(clipper)
        reaper.ImGui_PopFont(ctx) -- 内容字体自由缩放
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
              local path = normalize_path(dragging_audio.path, false)
              if dragging_audio.start_time and dragging_audio.end_time and math.abs(dragging_audio.end_time - dragging_audio.start_time) > 0.01 then
                InsertSelectedAudioSection(
                  path,
                  dragging_audio.start_time,
                  dragging_audio.end_time,
                  dragging_audio.section_offset or 0,
                  false
                )
              else
                -- 只插入全长源音频
                reaper.InsertMedia(path, 0)
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
    else
      static.clipper = nil
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
      elseif selected_row > 0 and _G.current_display_list[selected_row] then
        -- 非暂停时，从头开始或当前位置
        -- if Wave and Wave.play_cursor and Wave.play_cursor > 0 then
        --   PlayFromCursor(_G.current_display_list[selected_row])
        -- else
        --   PlayFromStart(_G.current_display_list[selected_row])
        -- end
        PlayFromCursor(_G.current_display_list[selected_row])
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
      local list = _G.current_display_list or {}
      local count = #list
      if count > 0 then
        -- math.randomseed 可根据实际需要加上 os.time() 进行初始化
        local rand_idx = math.random(1, count)
        selected_row = rand_idx -- 高亮选中行
        PlayFromCursor(list[rand_idx])
        is_paused = false
        paused_position = 0
        -- 滚动到可见中间
        _G.scroll_target = 0.5 -- 0.0=顶部 -- 不在clipper循环内，无效
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
          playing_path = normalize_path(playing_path, false)
          local list = _G.current_display_list or {}
          for i, info in ipairs(list) do
            local info_path = normalize_path(info.path, false)
            if info_path == playing_path then cur_idx = i break end
          end
          if cur_idx > 0 and cur_idx < #list then
            auto_play_next_pending = list[cur_idx + 1]
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
    reaper.ImGui_PushID(ctx, i)
    local pitch_knob_changed, pitch_knob_value = ImGui_Knob(ctx, "##pitch_knob", pitch, pitch_knob_min, pitch_knob_max, pitch_knob_size, 0)
    reaper.ImGui_PopID(ctx)
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
    reaper.ImGui_PushID(ctx, i)
    local knob_changed, knob_value = ImGui_Knob(ctx, "##rate_knob", play_rate, rate_min, rate_max, knob_size, 1)
    reaper.ImGui_PopID(ctx)
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
    if reaper.ImGui_Button(ctx, "Settings##Popup", 80) then
      reaper.ImGui_OpenPopup(ctx, "Settings##Popup")
    end
    -- 支持 Ctrl+P 快捷键打开设置
    if (reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl()))
      and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_P()) then
      reaper.ImGui_OpenPopup(ctx, "Settings##Popup")
    end
    if reaper.ImGui_BeginPopupModal(ctx, "Settings##Popup", nil) then
      -- 内容字体大小
      reaper.ImGui_Text(ctx, "Content Font Size:")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_PushItemWidth(ctx, -65)
      local changed_font, new_font_size = reaper.ImGui_SliderInt(ctx, "##font_size_slider", font_size, FONT_SIZE_MIN, FONT_SIZE_MAX, "%d px")
      reaper.ImGui_PopItemWidth(ctx)
      if changed_font then
        font_size = new_font_size
        reaper.SetExtState(EXT_SECTION, EXT_KEY_FONT_SIZE, tostring(font_size), true)
        MarkFontDirty()
      end
      -- reaper.ImGui_SameLine(ctx)
      -- HelpMarker("Adjust the content font size for the interface. Range: 12-24 px.")

      -- 内容表格行高
      reaper.ImGui_Text(ctx, "Content Row Height:")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_PushItemWidth(ctx, -65)
      local changed_row_height, new_row_height = reaper.ImGui_SliderInt(ctx, "##row_height_slider", row_height, 12, 48, "%d px")
      reaper.ImGui_PopItemWidth(ctx)
      if changed_row_height then
        row_height = new_row_height
        reaper.SetExtState(EXT_SECTION, EXT_KEY_TABLE_ROW_HEIGHT, tostring(row_height), true)
      end

      -- 停止或应用程序不活跃时关闭音频设备
      reaper.ImGui_Separator(ctx)
      local aci = reaper.SNM_GetIntConfigVar("audiocloseinactive", 1)
      local close_inactive = (aci == 1)
      local changed_inactive
      changed_inactive, close_inactive = reaper.ImGui_Checkbox(ctx, "Stop audio device when inactive", close_inactive)
      if changed_inactive then
        reaper.SNM_SetIntConfigVar("audiocloseinactive", close_inactive and 1 or 0)
      end

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

      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, "Datebase Settings:")
      local chg_wf, v_wf = reaper.ImGui_Checkbox(ctx, "Build waveform cache during DB creation##wf_cache", build_waveform_cache)
      if chg_wf then
        build_waveform_cache = v_wf
        reaper.SetExtState(EXT_SECTION, "build_waveform_cache", v_wf and "1" or "0", true)
      end
      if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx,
          "When enabled, the database builder precomputes and saves waveform cache for each file.\nPros: faster preview later.\nCons: longer build time and extra disk usage."
        )
      end

      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, "Search Settings:")
      local sea_enter_changed, search_enter_v = reaper.ImGui_Checkbox(ctx, "Update search only when enter key pressed##enter_mode", search_enter_mode) -- Press Enter to search
      if sea_enter_changed then
        search_enter_mode = search_enter_v
        reaper.SetExtState(EXT_SECTION, "search_enter_mode", search_enter_v and "1" or "0", true)
      end

      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, "UCS Settings:")
      DrawUcsLanguageSelector(ctx)

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

      -- 最近搜索设置
      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, "Max Recent Searched:")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_PushItemWidth(ctx, -65)
      local chg_rs, v_rs = reaper.ImGui_InputInt(ctx, "##max_recent_search_input", max_recent_search, 1, 5)
      reaper.ImGui_PopItemWidth(ctx)
      if chg_rs then
        max_recent_search = math.max(1, math.min(100, v_rs or 20))
        reaper.SetExtState(EXT_SECTION, "max_recent_search", tostring(max_recent_search), true)
        while #recent_search_keywords > max_recent_search do table.remove(recent_search_keywords) end -- saved_search_list
        SaveRecentSearched()
      end

      -- 最近播放设置
      -- reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, "Max Recent Played:")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_PushItemWidth(ctx, -65)
      local chg_rp, v_rp = reaper.ImGui_InputInt(ctx, "##max_recent_play_input", max_recent_files, 1, 5)
      reaper.ImGui_PopItemWidth(ctx)
      if chg_rp then
        max_recent_files = math.max(1, math.min(100, v_rp or 20))
        reaper.SetExtState(EXT_SECTION, "max_recent_play", tostring(max_recent_files), true)
        while #recent_audio_files > max_recent_files do table.remove(recent_audio_files) end
        SaveRecentPlayed()
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
        cache_dir = normalize_path(new_cache_dir, true) -- 规范分隔符 文件夹路径传入true
        reaper.SetExtState(EXT_SECTION, EXT_KEY_CACHE_DIR, cache_dir, true)
      end
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, "Browse##SelectCacheDir") then
        local rv, out = reaper.JS_Dialog_BrowseForFolder("Select a directory:", cache_dir)
        if rv == 1 and out and out ~= "" then
          cache_dir = normalize_path(out, true) -- 规范分隔符 文件夹路径传入true
          -- if not cache_dir:match("[/\\]$") then cache_dir = cache_dir .. "/" end
          reaper.SetExtState(EXT_SECTION, EXT_KEY_CACHE_DIR, cache_dir, true)
        end
      end

      reaper.ImGui_Separator(ctx)
      -- 按钮右对齐
      local win_set_w = reaper.ImGui_GetWindowWidth(ctx)
      local btn_set_w = 96
      local spacing_set = 110
      local padding_set_x = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding())
      reaper.ImGui_SetCursorPosX(ctx, win_set_w - (btn_set_w * 2 + spacing_set + padding_set_x * 2))

      if reaper.ImGui_Button(ctx, "Apply##Settings_save", btn_set_w, 20) then
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
        build_waveform_cache = false,
        search_enter_mode = false,
        bg_alpha = 1.0,
        peak_chans = 6,
        font_size = 14,
        max_db = 12,         -- 音量最大值
        pitch_knob_min = -6, -- 音高旋钮最低
        pitch_knob_max = 6,  -- 音高旋钮最高
        rate_min = 0.25,     -- 速率旋钮最低
        rate_max = 4.0,      -- 速率旋钮最高
        cache_dir = DEFAULT_CACHE_DIR,
        max_recent_files = 20, -- 最近播放文件最大数量
        max_recent_search = 20, -- 最近搜索最大数量
        row_height = DEFAULT_ROW_HEIGHT, -- 内容表格行高
      }

      -- Cancel 按钮
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, "Cancel##Settings_cancel", btn_set_w, 20) then
        reaper.ImGui_CloseCurrentPopup(ctx)
      end
      
      reaper.ImGui_SameLine(ctx)

      if reaper.ImGui_Button(ctx, "Reset##Settings_reset", btn_set_w, 20) then
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
        max_recent_files = DEFAULTS.max_recent_files
        max_recent_search = DEFAULTS.max_recent_search
        row_height = DEFAULTS.row_height
        build_waveform_cache = DEFAULTS.build_waveform_cache
        search_enter_mode = DEFAULTS.search_enter_mode
        -- 保存设置到ExtState
        reaper.SetExtState(EXT_SECTION, EXT_KEY_PEAKS, tostring(peak_chans), true)
        reaper.SetExtState(EXT_SECTION, EXT_KEY_FONT_SIZE, tostring(font_size), true)
        reaper.SetExtState(EXT_SECTION, EXT_KEY_CACHE_DIR, tostring(cache_dir), true)
        reaper.SetExtState(EXT_SECTION, EXT_KEY_AUTOSCROLL, tostring(auto_scroll_enabled and 1 or 0), true)
        reaper.SetExtState(EXT_SECTION, "search_enter_mode", tostring(search_enter_mode), true)
        reaper.SetExtState(EXT_SECTION, "build_waveform_cache", tostring(search_enter_mode), true)
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

    -- 插入选区音频到REAPER
    reaper.ImGui_SameLine(ctx, nil, 10)
    if select_start_time and select_end_time and math.abs(select_end_time - select_start_time) > 0.01 then
      local list = _G.current_display_list or {}
      local cur_info = list[selected_row]
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
        local path = normalize_path(cur_info.path, false)
        InsertSelectedAudioSection(path, select_start_time * play_rate, select_end_time * play_rate, cur_info.section_offset or 0, true)
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

    -- 跳过静音的勾选项
    reaper.ImGui_SameLine(ctx, nil, 0)
    local avail = reaper.ImGui_GetContentRegionAvail(ctx) -- 计算可用宽度
    local txt_w, txt_h = reaper.ImGui_CalcTextSize(ctx, "Skip Silence") -- 文字尺寸
    local cb_w = txt_w + txt_h + 16 -- 文字宽度+勾选框大小+间距

    -- 如果可用宽度足够，把光标推到右侧
    if avail > cb_w then
      reaper.ImGui_Dummy(ctx, avail - cb_w, 0)
      reaper.ImGui_SameLine(ctx, nil, 0)
    end

    local silence_changed
    silence_changed, skip_silence_enabled = reaper.ImGui_Checkbox(ctx, "Skip Silence", skip_silence_enabled)
    if silence_changed then
      reaper.SetExtState(EXT_SECTION, "skip_silence", skip_silence_enabled and "1" or "0", true)
    end
    if reaper.ImGui_IsItemHovered(ctx) then
      reaper.ImGui_SetTooltip(ctx, "Automatically skip initial silence when playing")
    end

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
      reaper.SetExtState(EXT_SECTION, "img_h_offset", tostring(img_h_offset), true)
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

    -- 专辑封面与波形预览 Child 高度补偿
    img_h = base_img_h + img_h_offset -- 补偿高度
    -- reaper.ImGui_Separator(ctx)
    local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
    local img_info
    if collect_mode == COLLECT_MODE_RECENTLY_PLAYED and current_recent_play_info then
      img_info = current_recent_play_info
    elseif _G.current_display_list and selected_row and _G.current_display_list[selected_row] then
      img_info = _G.current_display_list[selected_row]
    else
      img_info = last_selected_info
    end
    local has_cover = img_info and HasCoverImage(img_info)
    local left_img_w = has_cover and 120 or 1 -- 无图片时显示为1的宽度，后续使用reaper.ImGui_Dummy(ctx, -11, 0)补偿回正常宽度
    local gap = has_cover and 6 or 0
    local right_img_w = avail_w - left_img_w - gap

    -- 专辑图片显示
    if reaper.ImGui_BeginChild(ctx, "cover_art", left_img_w, img_h + timeline_height + 9) then
      local audio_path = img_info and img_info.path
      -- 计算封面临时文件路径（优先内嵌元数据，再同目录查找）
      local cover_path = audio_path and GetCoverImagePath(audio_path)
      if cover_path then
        -- 水平/垂直居中
        local img_w, img_h = 120, 120
        local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx) -- 可用宽度和高度
        local pad_x = (avail_w - img_w) * 0.5
        if pad_x > 0 then
          reaper.ImGui_Dummy(ctx, pad_x, 0)
          reaper.ImGui_SameLine(ctx)
        end
        local pad_y = (avail_h - img_h) * 0.5
        if pad_y > 0 then
          reaper.ImGui_Dummy(ctx, 0, pad_y-15)
        end

        -- 缓存并创建纹理
        if last_cover_path ~= cover_path or last_img_w ~= img_w then
          last_cover_img  = reaper.ImGui_CreateImage(cover_path)
          last_cover_path = cover_path
          last_img_w = img_w
        end

        if last_cover_img then
          reaper.ImGui_Image(ctx, last_cover_img, img_w, img_h)
        end
      else
        -- 无封面时重置
        last_cover_img  = nil
        last_cover_path = nil
        last_img_w      = nil
      end
      reaper.ImGui_EndChild(ctx)
    else
      -- 无封面时重置
      last_cover_img  = nil
      last_cover_path = nil
      last_img_w      = nil
    end
    reaper.ImGui_SameLine(ctx, nil, gap)

    -- 无专辑封面时右侧内容的偏移补偿
    if not has_cover then
      reaper.ImGui_Dummy(ctx, -11, 0)
      reaper.ImGui_SameLine(ctx)
    end
    -- 波形预览
    if reaper.ImGui_BeginChild(ctx, "waveform", right_img_w, img_h + timeline_height + 9) then -- 微调波形宽度（计划预留右侧空间-75用于放置专辑图片）和高度（补偿时间线高度+时间线间隔9）
      local pw_min_x, pw_min_y = reaper.ImGui_GetItemRectMin(ctx)
      local pw_max_x, max_y = reaper.ImGui_GetItemRectMax(ctx)
      local pw_region_w = math.max(64, math.floor(pw_max_x - pw_min_x))

      local view_len = Wave.src_len / Wave.zoom
      local window_start = Wave.scroll
      local window_end = Wave.scroll + view_len

      -- 获取峰值
      -- local cur_info = files_idx_cache and files_idx_cache[selected_row] -- 因添加最近播放分支注释
      local cur_info = nil
      if collect_mode == COLLECT_MODE_RECENTLY_PLAYED and current_recent_play_info then -- 最近播放模式时使用播放列表项
        cur_info = current_recent_play_info
        selected_row = 0 -- 清空右侧表格选中项
      elseif _G.current_display_list and selected_row and _G.current_display_list[selected_row] then
        cur_info = _G.current_display_list[selected_row] -- 其他模式用右侧表格选中项
        selected_recent_row = 0 -- 清空最近播放选中项
      end
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
        local root_src = GetRootSource(cur_info.source)
        local root_path
        if reaper.ValidatePtr(root_src, "MediaSource*") then
          root_path = reaper.GetMediaSourceFileName(root_src, "")
        else
          root_path = cur_info.path or ""
        end
        root_path = normalize_path(root_path, false)
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
        if not reaper.ImGui_IsAnyItemActive(ctx) then -- 避免输入框等被激活后空格冲突
          if playing_preview then
            StopPreview()
            -- 强制播放光标复位旧版本，不包括光标复位
            if last_play_cursor_before_play then
              Wave.play_cursor = last_play_cursor_before_play
            end
            -- 跳过静音，强制播放光标复位
            -- if skip_silence_enabled and last_playing_info then
            --   last_play_cursor_before_play = FindFirstNonSilentTime(last_playing_info)
            -- end
            -- Wave.play_cursor = last_play_cursor_before_play
            -- wf_play_start_cursor = last_play_cursor_before_play
          else
            PlayFromCursor(cur_info)
          end
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
      if auto_play_selected and selected_row and selected_row > 0 and _G.current_display_list then
        if last_selected_row ~= selected_row then
          local cur_info = _G.current_display_list[selected_row]
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
          if reaper.ValidatePtr(cur_info.source, "MediaSource*") and reaper.GetMediaSourceType(cur_info.source, "") == "SECTION" then
            drag_path = cur_info.source
          end

          dragging_selection = {
            path = drag_path,
            start_time = start_time,
            end_time = end_time,
            section_offset = cur_info.section_offset or 0,
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
              path = normalize_path(path or "", false)
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

      -- +按钮
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

      -- -按钮
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
    local file_info
    if collect_mode == COLLECT_MODE_RECENTLY_PLAYED and current_recent_play_info then -- 最近播放模式时使用播放列表项
      file_info = current_recent_play_info
    elseif _G.current_display_list and selected_row and _G.current_display_list[selected_row] then
      file_info = _G.current_display_list[selected_row] -- 其他模式用右侧表格选中项
      selected_recent_row = 0 -- 清空最近播放选中项
    else
      file_info = last_playing_info
    end

    reaper.ImGui_Text(ctx, ("%7d audio files found."):format(#_G.current_display_list)) -- 数字部分始终占用7位
    reaper.ImGui_SameLine(ctx)

    -- 路径始终跟随 file_info
    local show_path = file_info and file_info.path or ""
    show_path = normalize_path(show_path, false)
    if show_path ~= "" then
      reaper.ImGui_Text(ctx, "Now browsing:")
      reaper.ImGui_SameLine(ctx)
      local sep = package.config:sub(1,1)
      local path_parts = {}
      local cur = 1
      local is_win = (sep == "\\")
      local prefix = ""

      -- 处理Windows盘符
      if is_win then
        local drive = show_path:match("^%a:\\")
        if drive then
          table.insert(path_parts, drive)
          cur = #drive + 1
        end
      end

      -- 其它部分分割
      local remain = show_path:sub(cur)
      for part in string.gmatch(remain, "([^"..sep.."]+)") do
        table.insert(path_parts, part)
      end

      -- 预计算每个目录段的起止坐标
      local pos_x_list = {}
      local pos_w_list = {}
      local cursor_x, cursor_y = reaper.ImGui_GetCursorScreenPos(ctx)
      local tmp_x = cursor_x
      local font_size = reaper.ImGui_GetFontSize(ctx)

      for i = 1, #path_parts - 1 do
        local text = path_parts[i] .. sep
        local text_w, _ = reaper.ImGui_CalcTextSize(ctx, text)
        pos_x_list[i] = tmp_x
        pos_w_list[i] = text_w
        tmp_x = tmp_x + text_w
      end
      -- 文件名段也要跟上，但不用高亮/可点
      local filename = path_parts[#path_parts]
      local text_w, _ = reaper.ImGui_CalcTextSize(ctx, filename)
      pos_x_list[#path_parts] = tmp_x
      pos_w_list[#path_parts] = text_w
      -- 计算鼠标悬停在哪一段
      local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)
      local hover_idx = nil
      for i = 1, #path_parts - 1 do
        if mouse_x >= pos_x_list[i] and mouse_x <= pos_x_list[i]+pos_w_list[i] and
          mouse_y >= cursor_y and mouse_y <= cursor_y+font_size then
          hover_idx = i
          break
        end
      end
      -- 渲染所有段
      local full_path = is_win and path_parts[1] or ""
      local open_folder_popup = false

      for i = 1, #path_parts do
        if i > 1 then
          full_path = full_path .. sep .. path_parts[i]
          reaper.ImGui_SameLine(ctx, nil, 0)
        end

        local is_file = (i == #path_parts)
        local text = is_file and path_parts[i] or (path_parts[i] .. sep)
        local col = (not is_file and hover_idx and i <= hover_idx) and colors.table_header_active or colors.normal_text -- 鼠标经过时纯白，其他保持默认文字颜色
        reaper.ImGui_TextColored(ctx, col, text)

        -- 点击目录段
        if not is_file and hover_idx and i == hover_idx and reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsItemClicked(ctx, 0) then
          local path = normalize_path(full_path, true)
          tree_state.cur_path = path -- 当前文件夹
          RefreshFolderFiles(path) -- 刷新文件
        end

        -- 右键目录段弹出菜单
        if not is_file and reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
          open_folder_popup = true
        end
      end

      -- 右键弹出菜单
      if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
        open_folder_popup = true
      end

      if open_folder_popup then
        reaper.ImGui_OpenPopup(ctx, "##now_browsing")
      end

      if reaper.ImGui_BeginPopup(ctx, "##now_browsing") then
        if reaper.ImGui_MenuItem(ctx, "Show in Explorer/Finder") then
          if show_path and show_path ~= "" then
            reaper.CF_LocateInExplorer(normalize_path(show_path))
          end
        end
        reaper.ImGui_EndPopup(ctx)
      end
      reaper.ImGui_SameLine(ctx)
      HelpMarker("Hovering over a folder segment highlights it. Click to navigate into that folder.\nRight-click the path to show and highlight the file in Explorer/Finder.")
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
        StopPreview()
        -- 光标复位旧版本，不包括跳过静音
        if last_play_cursor_before_play then
          Wave.play_cursor = last_play_cursor_before_play
          wf_play_start_cursor = last_play_cursor_before_play
        end
        -- 跳过静音，光标复位
        -- if skip_silence_enabled and last_playing_info then
        --   last_play_cursor_before_play = FindFirstNonSilentTime(last_playing_info)
        -- end
        -- Wave.play_cursor = last_play_cursor_before_play
        -- wf_play_start_cursor = last_play_cursor_before_play
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

    -- 添加路径到数据库
    if tree_state.add_path_popup then
      tree_state.add_path_popup = false
      local rv, folder = reaper.JS_Dialog_BrowseForFolder("Choose folder to scan audio files:", "")
      if rv == 1 and folder and folder ~= "" then
        folder = normalize_path(folder, true)
        local filelist = ScanAllAudioFiles(folder)
        local db_dir = script_path .. "SoundmoleDB"
        EnsureCacheDir(db_dir)
        local dbfile = tree_state.add_path_dbfile
        local dbpath = normalize_path(db_dir, true) .. dbfile
        -- local alias_name = folder:match("([^/\\]+)[/\\]?$") or "Unnamed"
        -- 先写PATH行
        AddPathToDBFile(dbpath, folder)
        db_build_task = {
          filelist = filelist,
          dbfile = dbpath,
          idx = 1,
          total = #filelist,
          finished = false,
          -- alias = alias_name, 不重命名数据库命名
          root_path = folder,
        }
      end
      tree_state.add_path_dbfile = nil
    end

    -- 移除数据库的文件夹路径
    if tree_state.remove_path_confirm then
      local popup_open = true
      reaper.ImGui_OpenPopup(ctx, "Remove Folder Path Confirm")
      if reaper.ImGui_BeginPopupModal(ctx, "Remove Folder Path Confirm", popup_open, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        reaper.ImGui_Text(ctx, "Are you sure you want to remove this folder path and all its audio files from the database?")
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, tree_state.remove_path_to_remove)
        if reaper.ImGui_Button(ctx, "OK") then
          local db_dir = script_path .. "SoundmoleDB"
          local dbpath = normalize_path(db_dir, true) .. tree_state.remove_path_dbfile
          local lines = {}
          local skip_data = false
          local remove_prefix = normalize_path(tree_state.remove_path_to_remove, true)
          for line in io.lines(dbpath) do
            -- 跳过对应的PATH行
            if line:match('^PATH%s+"(.-)"') == tree_state.remove_path_to_remove then
            -- 判断是否是需要移除路径下的FILE行
            elseif line:match('^FILE%s+"(.-)"') then
              local filepath = line:match('^FILE%s+"(.-)"')
              filepath = normalize_path(filepath, false)
              if filepath:sub(1, #remove_prefix) == remove_prefix then
                skip_data = true -- 该文件及其所有DATA都要跳过
              else
                skip_data = false
                table.insert(lines, line)
              end
            elseif skip_data and line:find("^DATA") then
            else
              skip_data = false
              table.insert(lines, line)
            end
          end
          -- 写回
          local f = io.open(dbpath, "wb")
          for _, l in ipairs(lines) do f:write(l, "\n") end
          f:close()
          files_idx_cache = nil
          CollectFiles()

          tree_state.remove_path_confirm = false
          tree_state.remove_path_dbfile = nil
          tree_state.remove_path_to_remove = nil
          reaper.ImGui_CloseCurrentPopup(ctx)
        end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Cancel") then
          tree_state.remove_path_confirm = false
          tree_state.remove_path_dbfile = nil
          tree_state.remove_path_to_remove = nil
          reaper.ImGui_CloseCurrentPopup(ctx)
        end
        reaper.ImGui_EndPopup(ctx)
      end
    end

    -- 显示数据库构建进度
    if db_build_task and not db_build_task.finished then
      reaper.ImGui_OpenPopup(ctx, "Database Build Progress")
    end
    if reaper.ImGui_BeginPopupModal(ctx, "Database Build Progress", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
      local idx = db_build_task.idx
      local total = db_build_task.total
      local percent = (idx - 1) / math.max(1, total)

      if db_build_task.aborted then
        -- 被中断时弹窗内容
        reaper.ImGui_Text(ctx, "Database build aborted!")
        reaper.ImGui_Text(ctx, string.format("Processed: %d / %d", idx - 1, total))
        if reaper.ImGui_Button(ctx, "OK") then
          local filename = db_build_task.dbfile:match("[^/\\]+$")
          local alias = db_build_task.alias
          if not alias or alias == "" then
            -- 自动用文件夹名
            alias = db_build_task.root_path and db_build_task.root_path:match("([^/\\]+)[/\\]?$") or filename
          end
          mediadb_alias[filename] = filename -- alias -- 中断时不使用别名
          SaveMediaDBAlias(EXT_SECTION, mediadb_alias)

          db_build_task = nil
          reaper.ImGui_CloseCurrentPopup(ctx)
        end

      elseif db_build_task.finished then
        -- 正常完成时弹窗内容
        reaper.ImGui_Text(ctx, "Database build complete!")
        reaper.ImGui_Text(ctx, string.format("Total files: %d", total))
        reaper.ImGui_Text(ctx, string.format("Processed: %d", idx - 1))
        if reaper.ImGui_Button(ctx, "OK") then
          -- 刷新相关信息
          -- if db_build_task.is_rebuild then
            -- 清除过滤/排序缓存，确保 BuildFilteredList 再次执行。否则创建数据库后的列表为空
            static.filtered_list_map    = {}
            static.last_filter_text_map = {}
            static.last_sort_specs_map  = {}

            files_idx_cache = nil
            CollectFiles()
            file_select_start = nil
            file_select_end   = nil
            selected_row      = -1
          -- end
          local filename = db_build_task.dbfile:match("[^/\\]+$")
          mediadb_alias[filename] = filename -- db_build_task.alias or "Unnamed" -- 完成时不使用别名
          SaveMediaDBAlias(EXT_SECTION, mediadb_alias)
          
          db_build_task = nil
          reaper.ImGui_CloseCurrentPopup(ctx)
        end

      else
        -- 构建中弹窗内容
        reaper.ImGui_Text(ctx, "Collecting audio metadata and updating database...") -- "Generating waveform cache and collecting metadata..."
        reaper.ImGui_ProgressBar(ctx, percent, -1, 20, string.format("%d / %d", idx-1, total))
        if reaper.ImGui_Button(ctx, "Abort") then
          db_build_task.aborted = true
        end

        if idx <= total then
          local path = db_build_task.filelist[idx]
          local info = CollectFileInfo(path)
          WriteToMediaDB(info, db_build_task.dbfile)
          -- 使用build_waveform_cache开启或关闭构建波形缓存
          if build_waveform_cache then
            local pixel_cnt = 2048
            --local wf_step = 512 -- 直接读取全局值
            local start_time, end_time = 0, tonumber(info.length) or 0
            local peaks, _, src_len, channel_count = GetPeaksForInfo(info, wf_step, pixel_cnt, start_time, end_time)
            if peaks and src_len and channel_count then
              SaveWaveformCache(path, {peaks=peaks, pixel_cnt=pixel_cnt, channel_count=channel_count, src_len=src_len})
            end
          end
          db_build_task.idx = db_build_task.idx + 1
        else
          db_build_task.finished = true
          -- 刷新
          files_idx_cache = nil
          CollectFiles()
        end
      end

      reaper.ImGui_EndPopup(ctx)
    end

    reaper.ImGui_PopStyleVar(ctx, 6) -- ImGui_End 内 6 次圆角
    reaper.ImGui_End(ctx)
  end
  reaper.ImGui_PopStyleVar(ctx, 3)
  reaper.ImGui_PopFont(ctx)

  -- 检测 Ctrl+F4 快捷键
  if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl()) then
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F4()) then
      StopPreview()
      ReleaseAllCoverImages() -- 释放封面纹理
      DeleteCoverCacheFiles() -- 删除缓存图片
      SaveExitSettings()      -- 保存状态
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
      ReleaseAllCoverImages() -- 释放封面纹理
      DeleteCoverCacheFiles() -- 删除缓存图片
      SaveExitSettings()      -- 保存状态
      return
    end
  end

  if open then
    reaper.defer(loop)
  else
    StopPreview()
    ReleaseAllCoverImages() -- 释放封面纹理
    DeleteCoverCacheFiles() -- 删除缓存图片
    SaveExitSettings()      -- 退出时保存最后使用的模式状态
  end
end
-- 退出时保存模式列表状态
reaper.atexit(SaveExitSettings)
reaper.defer(loop)
