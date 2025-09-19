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
local set_font = 'sans-serif' -- options: Arial, sans-serif, Calibri, Segoe UI, Microsoft YaHei, SimSun, STSong, STFangsong, ...
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
-- 图标字体
local icon_font_path = normalize_path(script_path .. "data/icons.otf", false)
fonts.icon = reaper.ImGui_CreateFontFromFile(icon_font_path, 0)
reaper.ImGui_Attach(ctx, fonts.icon)
-- 数字字体
local odrf_font_path = normalize_path(script_path .. "data/odrf_upr_regular.otf", false)
fonts.odrf = reaper.ImGui_CreateFontFromFile(odrf_font_path, 0)
reaper.ImGui_Attach(ctx, fonts.odrf)

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
function SnapFontSize(px)
  local best = preview_font_sizes[1]
  local bestd = math.huge
  for _, s in ipairs(preview_font_sizes) do
    local d = math.abs(s - px)
    if d < bestd then best, bestd = s, d end
  end
  return best
end
function FindFontIndex(px)
  for i, s in ipairs(preview_font_sizes) do
    if s == px then return i end
  end
  local snap = SnapFontSize(px)
  for i, s in ipairs(preview_font_sizes) do
    if s == snap then return i end
  end
  return 1
end
local DEFAULT_ROW_HEIGHT = 24 -- 内容行高
local row_height         = DEFAULT_ROW_HEIGHT
reaper.ImGui_SetNextWindowSize(ctx, 1400, 857, reaper.ImGui_Cond_FirstUseEver())
-- local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]

-- 状态变量
CACHE_PIXEL_WIDTH            = 2048
selected_row                 = selected_row or -1
ui_bottom_offset             = 265   -- 底部预览区高度
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
local keep_preview_rate_pitch_on_insert = false -- 保持预听速率与音高用于插入的总开关

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
  KEY         = 16,
  BPM         = 17,
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
local img_w, img_h = 1200, 130         -- 波形图像宽度和高度
local base_img_h = 130                 -- 波形基础高度
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
COLLECT_MODE_CUSTOMFOLDER    = 6  -- 自定义文件夹模式
COLLECT_MODE_RECENTLY_PLAYED = 9  -- 最近播放模式
COLLECT_MODE_MEDIADB         = 10 -- 数据库模式
COLLECT_MODE_REAPERDB        = 11 -- REAPER数据库
COLLECT_MODE_SHORTCUT_MIRROR = 12
COLLECT_MODE_FREESOUND       = 13
COLLECT_MODE_SAMEFOLDER      = 14
COLLECT_MODE_PLAY_HISTORY    = 15 -- 播放历史表格模式

--------------------------------------------- 设置弹窗相关 ---------------------------------------------

local settings_window_open      = false
local settings_window_prev_open = false
local auto_play_selected        = true
local DOUBLECLICK_INSERT        = 0
local DOUBLECLICK_PREVIEW       = 1
local DOUBLECLICK_NONE          = 2
local doubleclick_action        = DOUBLECLICK_NONE
local bg_alpha                  = 1.0   -- 默认背景不透明
local mirror_folder_shortcuts   = false -- 默认关闭 Folder Shortcuts (Mirror)
local mirror_database           = false -- 默认关闭 Database (Mirror)
local show_peektree_recent      = true  -- 默认开启 播放历史

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
  reaper.SetExtState(EXT_SECTION, "mirror_folder_shortcuts", mirror_folder_shortcuts and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "mirror_database", mirror_database and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "insert_keep_rate_pitch", keep_preview_rate_pitch_on_insert and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "show_peektree_recent", show_peektree_recent and "1" or "0", true)
end

-- 恢复设置
do
  local v = tonumber(reaper.GetExtState(EXT_SECTION, "doubleclick_action"))
  if v then doubleclick_action = v end
end

do
  local v = reaper.GetExtState(EXT_SECTION, "auto_play_selected")
  if v == "1" then auto_play_selected = true
  elseif v == "0" then auto_play_selected = false end
end

do
  local v = reaper.GetExtState(EXT_SECTION, "preserve_pitch")
  if v == "1" then preserve_pitch = true
  elseif v == "0" then preserve_pitch = false end
end

do
  local v = tonumber(reaper.GetExtState(EXT_SECTION, "bg_alpha"))
  if v then bg_alpha = v end
end

do
  local v = tonumber(reaper.GetExtState(EXT_SECTION, "img_h_offset"))
  if v then img_h_offset = v end
end

do
  local v = tonumber(reaper.GetExtState(EXT_SECTION, "max_recent_play"))
  if v then max_recent_files = math.max(1, math.min(100, v)) end
end

do
  local v = tonumber(reaper.GetExtState(EXT_SECTION, "max_recent_search"))
  if v then max_recent_search = math.max(1, math.min(100, v)) end
end

do
  local v = reaper.GetExtState(EXT_SECTION, "mirror_folder_shortcuts")
  if v == "1" then mirror_folder_shortcuts = true
  elseif v == "0" then mirror_folder_shortcuts = false end
end

do
  local v = reaper.GetExtState(EXT_SECTION, "mirror_database")
  if v == "1" then mirror_database = true
  elseif v == "0" then mirror_database = false end
end

do
  local v = reaper.GetExtState(EXT_SECTION, "insert_keep_rate_pitch")
  if v == "1" then keep_preview_rate_pitch_on_insert = true
  elseif v == "0" then keep_preview_rate_pitch_on_insert = false end
end

do
  local v = reaper.GetExtState(EXT_SECTION, "show_peektree_recent")
  if v == "1" or v == "" then show_peektree_recent = true
  elseif v == "0" then show_peektree_recent = false
  else show_peektree_recent = true end
end

--------------------------------------------- 颜色表 ---------------------------------------------

local colors = {
  transparent          = 0x00000000, -- 完全透明
  table_header_hovered = 0x294A7A60, -- 鼠标悬停时表头颜色
  table_header_active  = 0x294A7AFF, -- 鼠标点击时表头颜色
  normal_text          = 0xFFF0F0F0, -- 标准文本颜色
  previewed_text       = 0x888888FF, -- 已预览过的暗一些
  timeline_def_color   = 0xCFCFCFFF, -- 时间线默认颜色
  timeline_bg_color    = 0x18181AFF, -- 时间线背景颜色
  thesaurus_text       = 0xBCC694FF, -- 同义词文本颜色
  text                 = 0x909090FF, -- 文字颜色
  accent               = 0xFFCC66FF, -- 强调色
  accent_active        = 0xFFDD88FF, -- 强调色激活
  gary                 = 0x909090FF, -- 灰色
  light_gary           = 0xC0C0C020, -- 浅灰
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
  { label = "Key",              key = "key",           enabled = false }, -- 调号
  { label = "BPM",              key = "bpm",           enabled = false }, -- 速度
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

-- 波形缓存规范化
function _normalize_waveform_data(data)
  if type(data) ~= "table" then return nil, "data not table" end

  local peaks = data.peaks
  if type(peaks) ~= "table" or #peaks == 0 then
    return nil, "peaks empty"
  end

  local channels = tonumber(data.channel_count) or #peaks
  if not channels or channels <= 0 then return nil, "channel_count invalid" end
  if channels > #peaks then channels = #peaks end

  local px_cnt = tonumber(data.pixel_cnt) or tonumber(data.pixel_count)
  if not px_cnt then
    local ch1 = peaks[1]
    if type(ch1) == "table" then px_cnt = #ch1 end
  end
  if not px_cnt or px_cnt <= 0 then return nil, "pixel_cnt invalid" end

  local src_len = tonumber(data.src_len) or tonumber(data.length) or 0
  if src_len <= 0 then return nil, "src_len invalid" end

  for ch = 1, channels do
    local row = peaks[ch]
    if type(row) ~= "table" then return nil, "peaks row invalid" end
    if #row < px_cnt then px_cnt = #row end
  end
  if px_cnt <= 0 then return nil, "pixel_cnt <= 0" end

  return {
    peaks         = peaks,
    channel_count = channels,
    pixel_cnt     = px_cnt,
    src_len       = src_len
  }
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

-- 保存缓存。如果行是 MIDI/无效文件，直接不入队
function SaveWaveformCache(filepath, data)
  filepath = normalize_path(filepath, false)

  local norm = _normalize_waveform_data(data)
  if not norm then return end
  if not (norm.pixel_cnt and norm.channel_count and norm.src_len) then return end
  if norm.pixel_cnt <= 0 or norm.channel_count <= 0 or norm.src_len <= 0 then return end

  local f = io.open(CacheFilename(filepath), "w+b")
  if not f then return end

  -- 像素数,声道数,源时长
  f:write(string.format("%d,%d,%f\n", norm.pixel_cnt, norm.channel_count, norm.src_len))
  for px = 1, norm.pixel_cnt do
    local cols = {}
    for ch = 1, norm.channel_count do
      local p = norm.peaks[ch][px]
      local minv = tonumber(p and p[1]) or 0.0
      local maxv = tonumber(p and p[2]) or 0.0
      cols[#cols+1] = string.format("%f,%f", minv, maxv)
    end
    f:write(table.concat(cols, ","))
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

function get_meta_first(src, ids)
  for _, id in ipairs(ids) do
    local ok, val = GetMediaFileMetadataSafe(src, id)
    if ok and val and val ~= "" then
      return val
    end
  end
  return nil
end

-- 标准化调式
function normalize_key(s)
  if not s or s == "" then return "" end
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  s = s:gsub("%s+", ""):gsub("♯", "#"):gsub("♭", "b")
  s = s:gsub("[Mm][Ii]?[Nn]?[Oo]?[Rr]$", "m")
  local root, accidental, minor = s:match("^([A-Ga-g])([#b]?)(m?)$")
  if root then return string.upper(root) .. accidental .. minor end
  return string.upper(s)
end

-- Items Assets 收集工程中当前使用的音频文件
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
      if path and path ~= "" and not files[path] and (typ == "WAVE" or typ == "MP3" or typ == "FLAC" or typ == "OGG" or typ == "AIFF" or typ == "APE" or typ == "WV" or typ == "M4A" or typ == "AAC" or typ == "MP4") then
        -- 获取文件大小并格式化
        local size = 0
        local f = io.open(path, "rb")
        if f then
          f:seek("end")
          size = f:seek()
          f:close()
        end

        local bits        = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(source) or ""
        local genre       = get_meta_first(source, { "XMP:dm/genre", "ID3:TCON", "VORBIS:GENRE", "RIFF:IGNR" })
        local comment     = get_meta_first(source, { "XMP:dm/logComment", "ID3:COMM", "VORBIS:COMMENT", "RIFF:ICMT" })
        local description = get_meta_first(source, { "BWF:Description", "RIFF:IDESC", "RIFF:ICMT" })
        local orig_date   = get_meta_first(source, { "BWF:OriginationDate", "XMP:xmp/CreateDate", "ID3:TDRC", "VORBIS:DATE", "RIFF:ICRD" })

        local bpm_str = get_meta_first(source, { "XMP:dm/tempo", "ID3:TBPM", "VORBIS:BPM", "RIFF:ACID:tempo" })
        local bpm = bpm_str and tonumber(bpm_str) or nil
        if not bpm then
          local fn = path:match("[^/\\]+$") or path
          local m = fn:match("(%d+)%s*[bB][pP][mM]") or fn:match("[_-](%d+)[_-]?BPM")
          bpm = m and tonumber(m) or nil
        end

        local key_str = get_meta_first(source, { "XMP:dm/key", "ID3:TKEY", "RIFF:IKEY", "VORBIS:KEY", "RIFF:ACID:key" })
        if not key_str or key_str == "" then
          local fn = path:match("([^/\\]+)$") or path
          key_str = fn:match("%f[%a]([A-Ga-g][#b♯♭]?%s*[Mm][Ii]?[Nn]?[Oo]?[Rr]?)%f[^%a]") or fn:match("%f[%a]([A-Ga-g][#b♯♭]?m)%f[^%a]") or fn:match("%f[%a]([A-Ga-g][#b♯♭]?)%f[^%a]")
        end
        local key = normalize_key(key_str)

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
          ucs_subcategory = get_ucstag(source, "subCategory"),
          bpm = bpm or "",
          key = key or "",
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

    local take_offset, take_length, samplerate, channels, length = 0, 0, 0, 0, 0
    local src, path, typ = nil, "", ""
    local size, bits = 0, ""
    local genre, description, comment, bwf_orig_date, ucs_category, ucs_catid, ucs_subcategory, bpm, key = "", "", "", "", "", "", "", "", ""

    if take then
      src = reaper.GetMediaItemTake_Source(take)
      -- 过滤空对象／非 MediaSource*
      if not reaper.ValidatePtr(src, "MediaSource*") then goto continue end
      take_offset = GetItemSectionStartPos(item) or 0
      take_length = reaper.GetMediaSourceLength(src) or 0
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
      if not (typ == "WAVE" or typ == "MP3" or typ == "FLAC" or typ == "OGG" or typ == "AIFF" or typ == "APE" or typ == "WV" or typ == "M4A" or typ == "AAC" or typ == "MP4") then
        goto continue
      end
      -- typ = reaper.GetMediaSourceType(src, "") -- 通过take获取type，无法保证类型准确。会混入SECTION 等非音频类型
      bits = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(src) or ""
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
      genre         = get_meta_first(src, { "XMP:dm/genre", "ID3:TCON", "VORBIS:GENRE", "RIFF:IGNR" })
      comment       = get_meta_first(src, { "XMP:dm/logComment", "ID3:COMM", "VORBIS:COMMENT", "RIFF:ICMT" })
      description   = get_meta_first(src, { "BWF:Description", "RIFF:IDESC", "RIFF:ICMT" })
      bwf_orig_date = get_meta_first(src, { "BWF:OriginationDate", "XMP:xmp/CreateDate", "ID3:TDRC", "VORBIS:DATE", "RIFF:ICRD" })
    end

    local bpm_str = get_meta_first(src, { "XMP:dm/tempo", "ID3:TBPM", "VORBIS:BPM", "RIFF:ACID:tempo" })
    bpm = bpm_str and tonumber(bpm_str) or nil
    if not bpm then
      local fn = path:match("[^/\\]+$") or path
      local m = fn:match("(%d+)%s*[bB][pP][mM]") or fn:match("[_-](%d+)[_-]?BPM")
      bpm = m and tonumber(m) or nil
    end

    local key_str = get_meta_first(src, { "XMP:dm/key", "ID3:TKEY", "RIFF:IKEY", "VORBIS:KEY", "RIFF:ACID:key" })
    if not key_str or key_str == "" then
      local fn = path:match("([^/\\]+)$") or path
      key_str = fn:match("%f[%a]([A-Ga-g][#b♯♭]?%s*[Mm][Ii]?[Nn]?[Oo]?[Rr]?)%f[^%a]") or fn:match("%f[%a]([A-Ga-g][#b♯♭]?m)%f[^%a]") or fn:match("%f[%a]([A-Ga-g][#b♯♭]?)%f[^%a]")
    end
    key = normalize_key(key_str)

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
      genre = genre,
      description = description,
      comment = comment,
      bwf_orig_date = bwf_orig_date,
      track = track,
      track_name = track_name,
      position = pos,
      section_offset = take_offset,
      section_length = take_length,
      ucs_category    = get_ucstag(src, "category"),
      ucs_catid       = get_ucstag(src, "catId"),
      ucs_subcategory = get_ucstag(src, "subCategory"),
      bpm = bpm or "",
      key = key or "",
    })
    ::continue::
  end
  return files_idx
end

-- Source Media - RPP 收集所有引用的音频文件
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

    local typ, bits, samplerate, channels, length, size = "", "", "", "", "", 0
    local genre, description, comment, bwf_orig_date = "", "", "", ""
    local real_src
    if take then
      local src = reaper.GetMediaItemTake_Source(take)
      local root_src = GetRootSource(src) -- 统一获取音频源
      local path = ""
      if reaper.ValidatePtr(root_src, "MediaSource*") then
        path = reaper.GetMediaSourceFileName(root_src, "")
      end
      path = normalize_path(path, false)
      if path and path_set[path] then
        -- 获取元数据
        real_src = reaper.PCM_Source_CreateFromFile(path)
        if real_src then
          typ = reaper.GetMediaSourceType(real_src, "")
          samplerate = reaper.GetMediaSourceSampleRate(real_src)
          channels = reaper.GetMediaSourceNumChannels(real_src)
          length = reaper.GetMediaSourceLength(real_src)
          bits = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(real_src) or ""
          local f = io.open(path, "rb")
          if f then
            f:seek("end")
            size = f:seek()
            f:close()
          end
          genre         = get_meta_first(real_src, { "XMP:dm/genre", "ID3:TCON", "VORBIS:GENRE", "RIFF:IGNR" })
          comment       = get_meta_first(real_src, { "XMP:dm/logComment", "ID3:COMM", "VORBIS:COMMENT", "RIFF:ICMT" })
          description   = get_meta_first(real_src, { "BWF:Description", "RIFF:IDESC", "RIFF:ICMT" })
          bwf_orig_date = get_meta_first(real_src, { "BWF:OriginationDate", "XMP:xmp/CreateDate", "ID3:TDRC", "VORBIS:DATE", "RIFF:ICRD" })

          local bpm_str = get_meta_first(real_src, { "XMP:dm/tempo", "ID3:TBPM", "VORBIS:BPM", "RIFF:ACID:tempo" })
          bpm = bpm_str and tonumber(bpm_str) or nil
          if not bpm then
            local fn = path:match("[^/\\]+$") or path
            local m = fn:match("(%d+)%s*[bB][pP][mM]") or fn:match("[_-](%d+)[_-]?BPM")
            bpm = m and tonumber(m) or nil
          end

          local key_str = get_meta_first(real_src, { "XMP:dm/key", "ID3:TKEY", "RIFF:IKEY", "VORBIS:KEY", "RIFF:ACID:key" })
          if not key_str or key_str == "" then
            local fn = path:match("([^/\\]+)$") or path
            key_str = fn:match("%f[%a]([A-Ga-g][#b♯♭]?%s*[Mm][Ii]?[Nn]?[Oo]?[Rr]?)%f[^%a]") or fn:match("%f[%a]([A-Ga-g][#b♯♭]?m)%f[^%a]") or fn:match("%f[%a]([A-Ga-g][#b♯♭]?)%f[^%a]")
          end
          key = normalize_key(key_str)

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
          genre = genre,
          description = description,
          comment = comment,
          bwf_orig_date = bwf_orig_date,
          track = track,
          track_name = track_name,
          position = pos,
          ucs_category    = get_ucstag(source, "category"),
          ucs_catid       = get_ucstag(source, "catId"),
          ucs_subcategory = get_ucstag(source, "subCategory"),
          bpm = bpm or "",
          key = key or "",
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
  local valid_exts = {wav=true, mp3=true, flac=true, ogg=true, aiff=true, ape=true, wv=true, m4a=true, aac=true, mp4=true}

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
          info.bits = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(src) or ""
          local genre       = get_meta_first(src, { "XMP:dm/genre", "ID3:TCON", "VORBIS:GENRE", "RIFF:IGNR" })
          local comment     = get_meta_first(src, { "XMP:dm/logComment", "ID3:COMM", "VORBIS:COMMENT", "RIFF:ICMT" })
          local description = get_meta_first(src, { "BWF:Description", "RIFF:IDESC", "RIFF:ICMT" })
          local orig_date   = get_meta_first(src, { "BWF:OriginationDate", "XMP:xmp/CreateDate", "ID3:TDRC", "VORBIS:DATE", "RIFF:ICRD" })
          info.genre = genre or ""
          info.comment = comment or ""
          info.description = description or ""
          info.bwf_orig_date = orig_date or ""
          info.ucs_category    = get_ucstag(src, "category")
          info.ucs_catid       = get_ucstag(src, "catId")
          info.ucs_subcategory = get_ucstag(src, "subCategory")

          local bpm_str = get_meta_first(src, { "XMP:dm/tempo", "ID3:TBPM", "VORBIS:BPM", "RIFF:ACID:tempo" })
          local bpm = bpm_str and tonumber(bpm_str) or nil
          if not bpm then
            local fn = file
            local m = fn:match("(%d+)%s*[bB][pP][mM]") or fn:match("[_-](%d+)[_-]?BPM")
            bpm = m and tonumber(m) or nil
          end
          info.bpm = bpm or ""

          local key_str = get_meta_first(src, { "XMP:dm/key", "ID3:TKEY", "RIFF:IKEY", "VORBIS:KEY", "RIFF:ACID:key" })
          if not key_str or key_str == "" then
            local fn = file
            key_str = fn:match("%f[%a]([A-Ga-g][#b♯♭]?%s*[Mm][Ii]?[Nn]?[Oo]?[Rr]?)%f[^%a]") or fn:match("%f[%a]([A-Ga-g][#b♯♭]?m)%f[^%a]") or fn:match("%f[%a]([A-Ga-g][#b♯♭]?)%f[^%a]")
          end
          info.key = normalize_key(key_str)
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

      local typ, size, bits, samplerate, channels, length = "", 0, "", "", "", ""
      local genre, description, comment, orig_date = "", "", "", ""

      -- 通过PCM_Source采集属性
      if reaper.file_exists and reaper.file_exists(path) then
        local src = reaper.PCM_Source_CreateFromFile(path)
        if src then
          typ = reaper.GetMediaSourceType(src, "")
          bits = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(src) or ""
          samplerate = reaper.GetMediaSourceSampleRate(src)
          channels = reaper.GetMediaSourceNumChannels(src)
          length = reaper.GetMediaSourceLength(src)
          -- 直接赋值到外部变量
          local _genre       = get_meta_first(src, { "XMP:dm/genre", "ID3:TCON", "VORBIS:GENRE", "RIFF:IGNR" })
          local _comment     = get_meta_first(src, { "XMP:dm/logComment", "ID3:COMM", "VORBIS:COMMENT", "RIFF:ICMT" })
          local _description = get_meta_first(src, { "BWF:Description", "RIFF:IDESC", "RIFF:ICMT" })
          local _orig_date   = get_meta_first(src, { "BWF:OriginationDate", "XMP:xmp/CreateDate", "ID3:TDRC", "VORBIS:DATE", "RIFF:ICRD" })
          genre = _genre or ""
          comment = _comment or ""
          description = _description or ""
          orig_date = _orig_date or ""

          local bpm_str = get_meta_first(src, { "XMP:dm/tempo", "ID3:TBPM", "VORBIS:BPM", "RIFF:ACID:tempo" })
          local bpm = bpm_str and tonumber(bpm_str) or nil
          if not bpm then
            local fn = path:match("[^/\\]+$") or path
            local m = fn:match("(%d+)%s*[bB][pP][mM]") or fn:match("[_-](%d+)[_-]?BPM")
            bpm = m and tonumber(m) or nil
          end

          local key_str = get_meta_first(src, { "XMP:dm/key", "ID3:TKEY", "RIFF:IKEY", "VORBIS:KEY", "RIFF:ACID:key" })
          if not key_str or key_str == "" then
            local fn = path:match("([^/\\]+)$") or path
            key_str = fn:match("%f[%a]([A-Ga-g][#b♯♭]?%s*[Mm][Ii]?[Nn]?[Oo]?[Rr]?)%f[^%a]") or fn:match("%f[%a]([A-Ga-g][#b♯♭]?m)%f[^%a]") or fn:match("%f[%a]([A-Ga-g][#b♯♭]?)%f[^%a]")
          end
          key = normalize_key(key_str)

          reaper.PCM_Source_Destroy(src)
        end
      end

      -- 音频格式
      if not (typ == "WAVE" or typ == "MP3" or typ == "FLAC" or typ == "OGG" or typ == "AIFF" or typ == "APE" or typ == "WV" or typ == "M4A" or typ == "AAC" or typ == "MP4") then
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
        key = key,
        bpm = bpm,
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

  -- 数据库加载，旧版备份
  -- elseif collect_mode == COLLECT_MODE_MEDIADB then
  --   local db_dir = normalize_path(script_path .. "SoundmoleDB", true) -- true 表示文件夹
  --   local dbfile = tree_state.cur_mediadb or ""
  --   files_idx_cache = {}
  --   if dbfile ~= "" then
  --     files_idx_cache = ParseMediaDBFile(db_dir .. sep .. dbfile)
  --   end
  --   selected_row = nil
  -- elseif collect_mode == COLLECT_MODE_REAPERDB then
  --   local db_dir = reaper.GetResourcePath() .. sep .. "MediaDB"
  --   local dbfile = tree_state.cur_reaper_db or ""
  --   files_idx_cache = {}
  --   if dbfile ~= "" then
  --     local fullpath = db_dir .. sep .. dbfile
  --     files_idx_cache = ParseMediaDBFile(fullpath)
  --   end
  --   selected_row = nil

  elseif collect_mode == COLLECT_MODE_MEDIADB then
    StartDBFirstPage(normalize_path(script_path .. "SoundmoleDB", true), tree_state.cur_mediadb, 2000)

  elseif collect_mode == COLLECT_MODE_REAPERDB then
    StartDBFirstPage(normalize_path(reaper.GetResourcePath() .. sep .. "MediaDB", true), tree_state.cur_reaper_db, 2000)

  elseif collect_mode == COLLECT_MODE_SHORTCUT_MIRROR then
    local dir = tree_state.cur_path or ""
    files_idx_cache = GetAudioFilesFromDirCached(dir)
    selected_row = nil

  elseif collect_mode == COLLECT_MODE_FREESOUND then
    if FS and type(FS_show_search_or_cache)=="function" then
      FS_show_search_or_cache()
    else
      files_idx_cache = {}
    end

  elseif collect_mode == COLLECT_MODE_SAMEFOLDER then
    local dir = tree_state.cur_path or ""
    files_idx_cache = GetAudioFilesFromDirCached(dir)
    selected_row = nil

  elseif collect_mode == COLLECT_MODE_PLAY_HISTORY then
    LoadRecentPlayed()
    files_idx_cache = {}
    for i = 1, #recent_audio_files do
      local info = recent_audio_files[i]
      info._recent_idx = i
      files_idx_cache[#files_idx_cache + 1] = info
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
  -- 按文件名排序。其中播放历史按钮模式不执行按文件名排序，保持最近播放顺序
  if not (_G._mediadb_stream and not _G._mediadb_stream.eof) and collect_mode ~= COLLECT_MODE_PLAY_HISTORY then -- 加入播放历史模式，避免被排序
    SortFilesByFilenameAsc()
  end
  
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
    ApplyPreviewOutputTrack(playing_preview)
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

function InsertMediaWithKeepParams(path)
  path = normalize_path(path, false)
  local before = {}
  for i = 0, reaper.CountMediaItems(0) - 1 do
    before[reaper.GetMediaItem(0, i)] = true
  end

  reaper.InsertMedia(path, 0)

  local new_item = nil
  for i = 0, reaper.CountMediaItems(0) - 1 do
    local item = reaper.GetMediaItem(0, i)
    if not before[item] then new_item = item break end
  end
  if not new_item then return end

  local take = reaper.GetActiveTake(new_item)
  if take and keep_preview_rate_pitch_on_insert then
    reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", tonumber(play_rate) or 1.0)
    reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH",    tonumber(pitch) or 0.0)
    reaper.SetMediaItemTakeInfo_Value(take, "B_PPITCH",   preserve_pitch and 1 or 0)

    local src = reaper.GetMediaItemTake_Source(take)
    if src then
      local src_len = select(1, reaper.GetMediaSourceLength(src)) or 0
      if src_len > 0 then
        reaper.SetMediaItemInfo_Value(new_item, "D_LENGTH", src_len / play_rate)
      end
    end
    reaper.UpdateItemInProject(new_item)
  end

  return new_item
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
  -- reaper.SetMediaItemInfo_Value(new_item, "D_LENGTH", sel_len)

  -- 按需应用预听速率与音高
  if keep_preview_rate_pitch_on_insert then
    reaper.SetMediaItemInfo_Value(new_item, "D_LENGTH", sel_len / play_rate)
    reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", play_rate or 1.0)
    reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH",    pitch     or 0.0)
    reaper.SetMediaItemTakeInfo_Value(take, "B_PPITCH",   preserve_pitch and 1 or 0)
    reaper.UpdateItemInProject(new_item)
  else
    -- 长度等于源选区时长
    reaper.SetMediaItemInfo_Value(new_item, "D_LENGTH", sel_len)
  end

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
  SM_PreviewStop()
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
    SM_PreviewBegin(playing_source)
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
      ApplyPreviewOutputTrack(playing_preview)
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
    SM_PreviewBegin(playing_source)
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
      ApplyPreviewOutputTrack(playing_preview)
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
  local y_offset    = 0   -- 距离波形底部-9像素
  local tick_long   = 22  -- 主刻度高度
  local tick_middle = 10  -- 中间刻度高度
  local tick_secmid = 7   -- 次中间刻度高度
  local tick_short  = 3   -- 次刻度高度
  local min_tick_px = 150 -- 两个主刻度最小像素距离

  -- 绘制时间线基础线
  local min_x, min_y = reaper.ImGui_GetItemRectMin(ctx)
  local max_x, max_y = reaper.ImGui_GetItemRectMax(ctx)
  local x0, y0 = min_x, max_y - y_offset
  local x1 = max_x
  local drawlist = reaper.ImGui_GetWindowDrawList(ctx)

  -- 时间线背景
  local timeline_h = tick_long + 1 -- 背景高度为主刻度高度+余量
  local bg_col = (colors.timeline_bg_color or 0x18181AFF)
  reaper.ImGui_DrawList_AddRectFilled(drawlist, x0, y0, x1, y0 + timeline_h, bg_col)

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
    reaper.ImGui_PushFont(ctx, fonts.sans_serif, 13)
    local text = reaper.format_timestr(t or 0, "")
    -- 计算文字高度
    local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, text)
    local text_y = y0 + tick_long - text_h + 2 -- 最后一个值用于上下偏移文字位置细调的
    reaper.ImGui_DrawList_AddText(drawlist, x + 4, text_y, colors.timeline_def_color, text)
    reaper.ImGui_PopFont(ctx)
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

--------------------------------------------- 文件夹虚线 ---------------------------------------------

-- 虚线样式
local GUIDE_DASHED    = true
local GUIDE_THICKNESS = 1 -- 更细
local GUIDE_DASH_LEN  = 1 -- 更短
local GUIDE_GAP_LEN   = 1 -- 更紧凑
local GUIDE_LABEL_PAD = 0 -- 子级左侧留白

local _guide = { base_x=nil, indent=nil, stack={} }
function ResetCollectionGuide()
  _guide.base_x = nil
  _guide.indent = nil
  _guide.stack  = {}
end

-- 捕获当前节点行矩形
function CaptureNodeRectAndInit(ctx, depth)
  local minx, miny = reaper.ImGui_GetItemRectMin(ctx)
  local maxx, maxy = reaper.ImGui_GetItemRectMax(ctx)
  if not _guide.base_x then _guide.base_x = minx end
  if depth == 1 and (not _guide.indent or _guide.indent <= 0) then
    _guide.indent = math.max(8, minx - _guide.base_x)
  end
  return minx, miny, maxx, maxy
end

-- 父级竖干
function TrunkX(parent_depth)
  local indent = _guide.indent or 14
  return (_guide.base_x or 0) + (parent_depth + 1) * indent - indent * 0.5
end

-- 画虚线
function DrawLine(dl, x1, y1, x2, y2, col, th, dashed)
  if not dashed then
    reaper.ImGui_DrawList_AddLine(dl, x1, y1, x2, y2, col, th); return
  end
  local hx = math.abs(x2 - x1) >= math.abs(y2 - y1)
  if hx then
    local total = x2 - x1; local dir = total >= 0 and 1 or -1
    local len = math.abs(total); local s = 0
    while s < len do
      local e = math.min(s + GUIDE_DASH_LEN, len)
      reaper.ImGui_DrawList_AddLine(dl, x1 + dir*s, y1, x1 + dir*e, y1, col, th)
      s = e + GUIDE_GAP_LEN
    end
  else
    local total = y2 - y1; local dir = total >= 0 and 1 or -1
    local len = math.abs(total); local s = 0
    while s < len do
      local e = math.min(s + GUIDE_DASH_LEN, len)
      reaper.ImGui_DrawList_AddLine(dl, x1, y1 + dir*s, x1, y1 + dir*e, col, th)
      s = e + GUIDE_GAP_LEN
    end
  end
end

function DrawChildTeeFromParent(ctx, child_minx, child_cy)
  local top = _guide.stack[#_guide.stack]
  if not top then return end -- 根节点无父
  local px = TrunkX(top.depth)
  local dl  = reaper.ImGui_GetWindowDrawList(ctx)
  DrawLine(dl, px, child_cy, child_minx - GUIDE_LABEL_PAD, child_cy, colors.previewed_text, GUIDE_THICKNESS, GUIDE_DASHED)
  top.ymin = top.ymin and math.min(top.ymin, child_cy) or child_cy
  top.ymax = top.ymax and math.max(top.ymax, child_cy) or child_cy
end

function DrawParentTrunk(ctx, parent_depth, parent_cy, ymin, ymax)
  if not ymin or not ymax then return end
  local px  = TrunkX(parent_depth)
  local y1  = math.min(parent_cy, ymin)
  local y2  = math.max(parent_cy, ymax)
  local dl  = reaper.ImGui_GetWindowDrawList(ctx)
  DrawLine(dl, px, y1, px, y2, colors.previewed_text, GUIDE_THICKNESS, GUIDE_DASHED)
end

--------------------------------------------- 树状文件夹 ---------------------------------------------

local audio_types = { WAVE=true, MP3=true, FLAC=true, OGG=true, AIFF=true, APE=true, M4A=true, AAC=true, MP4=true }
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
  local valid_exts = {wav=true, mp3=true, flac=true, ogg=true, aiff=true, ape=true, wv=true, m4a=true, aac=true, mp4=true}
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
          info.bits = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(src) or ""
          local genre       = get_meta_first(src, { "XMP:dm/genre", "ID3:TCON", "VORBIS:GENRE", "RIFF:IGNR" })
          local comment     = get_meta_first(src, { "XMP:dm/logComment", "ID3:COMM", "VORBIS:COMMENT", "RIFF:ICMT" })
          local description = get_meta_first(src, { "BWF:Description", "RIFF:IDESC", "RIFF:ICMT" })
          local orig_date   = get_meta_first(src, { "BWF:OriginationDate", "XMP:xmp/CreateDate", "ID3:TDRC", "VORBIS:DATE", "RIFF:ICRD" })
          info.genre = genre or ""
          info.comment = comment or ""
          info.description = description or ""
          info.bwf_orig_date = orig_date or ""
          info.ucs_category    = get_ucstag(src, "category")
          info.ucs_catid       = get_ucstag(src, "catId")
          info.ucs_subcategory = get_ucstag(src, "subCategory")

          local bpm_str = get_meta_first(src, { "XMP:dm/tempo", "ID3:TBPM", "VORBIS:BPM", "RIFF:ACID:tempo" })
          local bpm = bpm_str and tonumber(bpm_str) or nil
          if not bpm then
            local fn = file
            local m = fn:match("(%d+)%s*[bB][pP][mM]") or fn:match("[_-](%d+)[_-]?BPM")
            bpm = m and tonumber(m) or nil
          end
          info.bpm = bpm or ""

          local key_str = get_meta_first(src, { "XMP:dm/key", "ID3:TKEY", "RIFF:IKEY", "VORBIS:KEY", "RIFF:ACID:key" })
          if not key_str or key_str == "" then
            local fn = file
            key_str = fn:match("%f[%a]([A-Ga-g][#b♯♭]?%s*[Mm][Ii]?[Nn]?[Oo]?[Rr]?)%f[^%a]") or fn:match("%f[%a]([A-Ga-g][#b♯♭]?m)%f[^%a]") or fn:match("%f[%a]([A-Ga-g][#b♯♭]?)%f[^%a]")
          end
          info.key = normalize_key(key_str)
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
  drive_name_map = {}

  if reaper.GetOS():find('Win') then
    local sep = package.config:sub(1,1)
    local base = reaper.GetResourcePath() .. sep
    local tmp_out = base .. ("drives_%d_%d.txt"):format(os.time(), math.random(1,1e6))
    local tmp_ps1 = base .. ("drives_%d_%d.ps1"):format(os.time(), math.random(1,1e6))

    do
      local ps = ([[
[Console]::OutputEncoding=[System.Text.Encoding]::UTF8
$h=@{}

try {
  [System.IO.DriveInfo]::GetDrives() | ForEach-Object {
    $id=$_.Name.Substring(0,2).ToUpper()
    $label=""
    try { if ($_.IsReady) { $label=$_.VolumeLabel } } catch {}
    $h[$id]=$label
  }
} catch {}

try {
  Get-WmiObject Win32_LogicalDisk | ForEach-Object {
    $id=$_.DeviceID.ToUpper()
    if (-not $h.ContainsKey($id)) { $h[$id]=$_.VolumeName }
  }
} catch {}

try {
  Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $id=($_.Name + ":").ToUpper()
    if (-not $h.ContainsKey($id)) { $h[$id]="" }
  }
} catch {}

$h.Keys | Sort-Object | ForEach-Object {
  "{0}|{1}" -f $_, $h[$_]
} | Out-File -FilePath "]] .. tmp_out:gsub("\\","/") .. [[" -Encoding utf8
]])
      local f = io.open(tmp_ps1, "wb")
      if f then f:write(ps); f:close() end
    end

    -- 隐藏执行，避免CMD弹窗
    local cmd = ('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%s"'):format(tmp_ps1)
    if reaper.ExecProcess then
      reaper.ExecProcess(cmd, 15000)
    else
      os.execute(cmd)
    end

    -- 读取结果，去除首行 UTF-8 BOM
    local f = io.open(tmp_out, "rb")
    if f then
      local first = true
      for line in f:lines() do
        if first then
          first = false
          if line:sub(1,3) == string.char(0xEF,0xBB,0xBF) then
            line = line:sub(4)
          end
        end
        local drv, vol = line:match('^([A-Z]:)%|(.*)$')
        if drv then
          local path = drv .. '\\'
          table.insert(drives, path)
          drive_name_map[path] = vol or ''
        end
      end
      f:close()
    end
    os.remove(tmp_out)
    os.remove(tmp_ps1)

    -- 兜底
    if #drives == 0 then
      local tmp2 = base .. ("drives_%d_%d.txt"):format(os.time(), math.random(1,1e6))
      local cmd2 = ('cmd /d /s /c fsutil fsinfo drives > "%s"'):format(tmp2)
      if reaper.ExecProcess then
        reaper.ExecProcess(cmd2, 8000)
      else
        os.execute(cmd2)
      end
      local f2 = io.open(tmp2, "rb")
      if f2 then
        local data = f2:read("*a")
        f2:close()
        os.remove(tmp2)
        for letter in data:gmatch('([A-Z]:\\)') do
          table.insert(drives, letter)
          drive_name_map[letter] = drive_name_map[letter] or ''
        end
      end
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
function draw_tree(name, path, depth)
  path = normalize_path(path, true)
  depth = depth or 0
  local show_name = name
  if drive_name_map and drive_name_map[path] and drive_name_map[path] ~= "" then
    show_name = name .. " [" .. drive_name_map[path] .. "]"
  end

  local flags = reaper.ImGui_TreeNodeFlags_SpanAvailWidth()
  local highlight = (tree_state.cur_path == path) and reaper.ImGui_TreeNodeFlags_Selected() or 0
  local node_open = reaper.ImGui_TreeNode(ctx, show_name .. "##" .. path, flags | highlight)
  -- 捕获本行矩形与中心y
  local minx, miny, maxx, maxy = CaptureNodeRectAndInit(ctx, depth)
  local cy = (miny + maxy) * 0.5
  if #_guide.stack > 0 then
    DrawChildTeeFromParent(ctx, minx, cy)
  end
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

    -- 支持绘制虚线
    local pushed = false
    if #cache.dirs > 0 then
      table.insert(_guide.stack, { depth = depth, parent_cy = cy, ymin = nil, ymax = nil })
      pushed = true
    end

    for _, sub in ipairs(cache.dirs) do
      local sub_path = normalize_path(path .. sep .. sub, true)
      draw_tree(sub, sub_path, depth + 1)
    end

    if pushed then
      local top = table.remove(_guide.stack)
      if top then
        DrawParentTrunk(ctx, top.depth, top.parent_cy, top.ymin, top.ymax)
      end
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
function draw_shortcut_tree(sc, base_path, depth)
  if type(sc)~="table" or not sc.path then return end
  local show_name = (sc.name and sc.name ~= "") and sc.name or GetFolderName(sc.path)
  local path = normalize_path(sc.path, true)
  depth = depth or 0
  local flags = reaper.ImGui_TreeNodeFlags_SpanAvailWidth()
  local highlight = (collect_mode == COLLECT_MODE_SHORTCUT and tree_state.cur_path == path) and reaper.ImGui_TreeNodeFlags_Selected() or 0 -- 去掉 collect_mode == COLLECT_MODE_SHORTCUT 则保持高亮

  -- 路径折叠展开状态，确保二级以上路径下次打开时可以展开
  local cmpath = path:gsub("[/\\]+$", "")
  if expanded_paths[cmpath] then
    flags = flags | reaper.ImGui_TreeNodeFlags_DefaultOpen()
  end

  local node_open = reaper.ImGui_TreeNode(ctx, show_name .. "##shortcut_" .. path, flags | highlight)
  -- 捕获本行矩形与中心y
  local minx, miny, maxx, maxy = CaptureNodeRectAndInit(ctx, depth)
  local cy = (miny + maxy) * 0.5
  if #_guide.stack > 0 then
    DrawChildTeeFromParent(ctx, minx, cy)
  end
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

    -- 支持绘制虚线
    local pushed = false
    if #cache.dirs > 0 then
      table.insert(_guide.stack, { depth = depth, parent_cy = cy, ymin = nil, ymax = nil })
      pushed = true
    end

    for _, sub in ipairs(cache.dirs) do
      local sub_path = normalize_path(path .. sep .. sub, true)
      draw_shortcut_tree({ name = sub, path = sub_path }, path, depth + 1)
    end

    if pushed then
      local top = table.remove(_guide.stack)
      if top then
        DrawParentTrunk(ctx, top.depth, top.parent_cy, top.ymin, top.ymax)
      end
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

function draw_advanced_folder_node(id, selected_id, depth)
  local node = advanced_folders[id]
  if not node then return end
  depth = depth or 0
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
  -- 捕获本行矩形与中心y
  local minx, miny, maxx, maxy = CaptureNodeRectAndInit(ctx, depth)
  local cy = (miny + maxy) * 0.5
  if #_guide.stack > 0 then
    DrawChildTeeFromParent(ctx, minx, cy)
  end

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

  -- 拖动文件到高级文件夹中，媒体资源管理器文件+内部 AUDIO_PATHS (左侧选中项)
  if reaper.ImGui_BeginDragDropTarget(ctx) then
    node.files = node.files or {}
    local changed = false

    local function add_path(p)
      if not p or p == "" then return end
      local np = normalize_path(p, false)
      for _, old in ipairs(node.files) do
        if old == np then return end
      end
      table.insert(node.files, np)
      changed = true
    end

    -- 接收媒体资源管理器文件型负载
    local ok_files, count = reaper.ImGui_AcceptDragDropPayloadFiles(ctx, 1024)
    if ok_files and count and count > 0 then
      for i = 0, count - 1 do
        local ok1, filepath = reaper.ImGui_GetDragDropPayloadFile(ctx, i)
        if ok1 and filepath and filepath ~= "" then
          add_path(filepath)
        end
      end
    end

    -- 接收脚本内部自定义负载
    if reaper.ImGui_AcceptDragDropPayload(ctx, "AUDIO_PATHS") then
      local ok2, dtype, payload = reaper.ImGui_GetDragDropPayload(ctx)
      if ok2 and dtype == "AUDIO_PATHS" and type(payload) == "string" and payload ~= "" then
        for raw in payload:gmatch("([^|;|]+)") do
          add_path(raw)
        end
      end
    end

    if changed then
      SaveAdvancedFolders()
      if collect_mode == COLLECT_MODE_ADVANCEDFOLDER and tree_state.cur_advanced_folder == id then
        files_idx_cache = nil
        CollectFiles()

        -- 清空多选状态
        file_select_start = nil
        file_select_end   = nil
        selected_row      = -1

        local static = _G._soundmole_static or {}
        _G._soundmole_static = static
        static.filtered_list_map, static.last_filter_text_map = {}, {}
      end
    end

    reaper.ImGui_EndDragDropTarget(ctx)
  end

  -- 递归子节点，画虚线
  if node_open then
    local has_children = (node.children and #node.children > 0)

    -- 支持绘制虚线
    local pushed = false
    if has_children then
      table.insert(_guide.stack, { depth = depth, parent_cy = cy, ymin = nil, ymax = nil })
      pushed = true
    end

    if has_children then
      for _, cid in ipairs(node.children) do
        draw_advanced_folder_node(cid, selected_id, depth + 1)
      end
    end

    if pushed then
      local top = table.remove(_guide.stack)
      if top then
        DrawParentTrunk(ctx, top.depth, top.parent_cy, top.ymin, top.ymax)
      end
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

  local typ, size, bits, samplerate, channels, length = "", 0, "", "", "", ""
  local genre, description, comment, orig_date = "", "", "", ""
  local key, bpm = "", ""
  local ucs_category, ucs_catid, ucs_subcategory = "", "", ""
  
  -- 文件属性
  if reaper.file_exists and reaper.file_exists(path) then
    local src = reaper.PCM_Source_CreateFromFile(path)
    if src then
      typ = reaper.GetMediaSourceType(src, "")
      bits = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(src) or ""
      samplerate = reaper.GetMediaSourceSampleRate(src)
      channels = reaper.GetMediaSourceNumChannels(src)
      length = reaper.GetMediaSourceLength(src)

      local genre       = get_meta_first(src, { "XMP:dm/genre", "ID3:TCON", "VORBIS:GENRE", "RIFF:IGNR" })
      local comment     = get_meta_first(src, { "XMP:dm/logComment", "ID3:COMM", "VORBIS:COMMENT", "RIFF:ICMT" })
      local description = get_meta_first(src, { "BWF:Description", "RIFF:IDESC", "RIFF:ICMT" })
      local orig_date   = get_meta_first(src, { "BWF:OriginationDate", "XMP:xmp/CreateDate", "ID3:TDRC", "VORBIS:DATE", "RIFF:ICRD" })

      if get_ucstag then
        ucs_category    = get_ucstag(src, "category")
        ucs_catid       = get_ucstag(src, "catId")
        ucs_subcategory = get_ucstag(src, "subCategory")
      end

      local bpm_str = get_meta_first(src, { "XMP:dm/tempo", "ID3:TBPM", "VORBIS:BPM", "RIFF:ACID:tempo" })
      bpm = bpm_str and tonumber(bpm_str) or nil
      if not bpm then
        local fn = info.filename
        local m = fn:match("(%d+)%s*[bB][pP][mM]") or fn:match("[_-](%d+)[_-]?BPM")
        bpm = m and tonumber(m) or nil
      end
      bpm = bpm or ""

      local key_str = get_meta_first(src, { "XMP:dm/key", "ID3:TKEY", "RIFF:IKEY", "VORBIS:KEY", "RIFF:ACID:key" })
      if not key_str or key_str == "" then
        local fn = info.filename
        key_str = fn:match("%f[%a]([A-Ga-g][#b♯♭]?%s*[Mm][Ii]?[Nn]?[Oo]?[Rr]?)%f[^%a]") or fn:match("%f[%a]([A-Ga-g][#b♯♭]?m)%f[^%a]") or fn:match("%f[%a]([A-Ga-g][#b♯♭]?)%f[^%a]")
      end
      key = normalize_key(key_str)
      reaper.PCM_Source_Destroy(src)
    end
  end

  -- 音频格式校验
  if not (typ == "WAVE" or typ == "MP3" or typ == "FLAC" or typ == "OGG" or typ == "AIFF" or typ == "APE" or typ == "WV" or typ == "M4A" or typ == "AAC" or typ == "MP4") then
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
  info.key = key
  info.bpm = bpm

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
  if not file_path or type(file_path) ~= "string" or file_path == "" then return end
  local path = normalize_path(file_path, false)

  local f = io.open(path, "rb")
  if not f then return end

  local header = f:read(10) or ""
  local ver, tag_size, tag_data

  if #header >= 10 and header:sub(1, 3) == "ID3" then
    -- MP3 文件开头
    ver      = header:byte(4)
    tag_size = syncsafe_to_int(header:sub(7, 10))
    if tag_size and tag_size > 0 then
      tag_data = f:read(tag_size) or ""
    end
  else
    -- 可能是 WAV 文件末尾的 ID3 chunk
    local content = header .. (f:read("*all") or "")
    local pos = content:find("ID3", 1, true)
    if not pos then f:close() return end
    if (pos + 9) > #content then f:close() return end

    local hdr2 = content:sub(pos, pos + 9)
    if hdr2:sub(1, 3) ~= "ID3" then f:close() return end

    ver      = hdr2:byte(4)
    tag_size = syncsafe_to_int(hdr2:sub(7, 10))
    if not tag_size or tag_size <= 0 then f:close() return end

    local data_start = pos + 10
    local data_end   = data_start + tag_size - 1
    if data_end > #content then f:close() return end

    tag_data = content:sub(data_start, data_end)
  end

  f:close()
  if not tag_data or #tag_data == 0 then return end
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
  if collect_mode ~= COLLECT_MODE_RECENTLY_PLAYED and collect_mode ~= COLLECT_MODE_SAMEFOLDER then
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

--------------------------------------------- 快速预览文件夹节点 ---------------------------------------------

preview_folder_input = preview_folder_input or ""
reopen_preview_popup = reopen_preview_popup or false
preview_popup_pos_x  = preview_popup_pos_x -- 记住上次弹窗位置
preview_popup_pos_y  = preview_popup_pos_y

-- 快速预览文件夹
function BrowseForFolder(init_dir)
  if reaper.JS_Dialog_BrowseForFolder then
    local ok, path = reaper.JS_Dialog_BrowseForFolder("Select a folder", init_dir or "")
    if ok and path and path ~= "" then
      return path
    end
  end
  return nil
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

  -- 恢复REAPER自带数据库模式
  if collect_mode == COLLECT_MODE_REAPERDB then
    local ext = reaper.GetExtState(EXT_SECTION, "reaperdb_header_open")
    if ext == "true" then
      reaper_db_open = true
    else
      reaper_db_open = false
    end
    tree_state.cur_reaper_db = reaper.GetExtState(EXT_SECTION, "cur_reaperdb") or ""
  end

  -- 恢复REAPER自带快捷方式模式
  if collect_mode == COLLECT_MODE_SHORTCUT_MIRROR then
    local ext = reaper.GetExtState(EXT_SECTION, "shortcut_mirror_header_open")
    if ext == "true" then
      shortcut_mirror_open = true
    else
      shortcut_mirror_open = false
    end
    tree_state.cur_path = reaper.GetExtState(EXT_SECTION, "cur_sc_mirror") or ""
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

  -- 恢复 相同目录 模式
  if collect_mode == COLLECT_MODE_SAMEFOLDER then
    local saved = reaper.GetExtState(EXT_SECTION, "cur_samefolder_path") or ""
    if saved ~= "" then
      tree_state.cur_path = normalize_path(saved, true)
      RefreshFolderFiles(tree_state.cur_path)
    end
  end

  if collect_mode == COLLECT_MODE_PLAY_HISTORY then
    local ext = reaper.GetExtState(EXT_SECTION, "play_history_header_open")
    if ext == "true" then
      play_history_open = true
    elseif ext == "false" then
      play_history_open = false
    else
      play_history_open = false
    end
    selected_play_history_row = tonumber(reaper.GetExtState(EXT_SECTION, "cur_play_history_row") or "") or 0
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

  elseif collect_mode == COLLECT_MODE_REAPERDB then
    reaper.SetExtState(EXT_SECTION, "reaperdb_header_open", tostring(reaper_db_open), true)
    reaper.SetExtState(EXT_SECTION, "cur_reaperdb", tree_state.cur_reaper_db or "", true)

  elseif collect_mode == COLLECT_MODE_SHORTCUT_MIRROR then
    reaper.SetExtState(EXT_SECTION, "shortcut_mirror_header_open", tostring(shortcut_mirror_open), true)
    reaper.SetExtState(EXT_SECTION, "cur_sc_mirror", tree_state.cur_path or "", true)

  elseif collect_mode == COLLECT_MODE_ADVANCEDFOLDER then
    reaper.SetExtState(EXT_SECTION, "collections_header_open", tostring(collection_open), true)
    reaper.SetExtState(EXT_SECTION, "last_collections", tree_state.cur_advanced_folder or "", true)

  elseif collect_mode == COLLECT_MODE_RECENTLY_PLAYED then
    reaper.SetExtState(EXT_SECTION, "recent_header_open", tostring(recent_open), true)
    reaper.SetExtState(EXT_SECTION, "cur_recent_row", tostring(selected_recent_row or 0), true)

  elseif collect_mode == COLLECT_MODE_SAMEFOLDER then
    reaper.SetExtState(EXT_SECTION, "cur_samefolder_path", tree_state.cur_path or "", true)

  elseif collect_mode == COLLECT_MODE_PLAY_HISTORY then
    reaper.SetExtState(EXT_SECTION, "play_history_header_open", tostring(play_history_open), true)
    reaper.SetExtState(EXT_SECTION, "cur_play_history_row", tostring(selected_play_history_row or 0), true)

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
  elseif collect_mode == COLLECT_MODE_REAPERDB then -- 官方 .ReaperFileList
    return "REAPERDB:" .. tostring(tree_state.cur_reaper_db or "default")
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
          usage.track_name or "",
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
          if keep_preview_rate_pitch_on_insert then
            InsertMediaWithKeepParams(insert_path)
          else
            reaper.InsertMedia(insert_path, 0)
          end
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

        -- local static = _G._soundmole_static or {}
        -- _G._soundmole_static = static
        static.filtered_list_map, static.last_filter_text_map = {}, {}
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
  EnsureEntryParsed(info) -- 右侧文件列表首次可见时解析 DATA 元数据
  if not info.group then  -- 分组延迟到可见时再计算
    info.group = GetCustomGroupsForPath(info.path)
  end

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
    local is_item_mode = (collect_mode == COLLECT_MODE_ALL_ITEMS or collect_mode == COLLECT_MODE_RPP)
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
      local row_label = (info.filename or "") .. "##RowContext__" .. tostring(i)
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
            if keep_preview_rate_pitch_on_insert then
              InsertMediaWithKeepParams(normalize_path(info.path, false))
            else
              reaper.InsertMedia(normalize_path(info.path, false), 0)
            end
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
          if keep_preview_rate_pitch_on_insert then
            InsertMediaWithKeepParams(normalize_path(info.path, false))
          else
            reaper.InsertMedia(normalize_path(info.path, false), 0)
          end
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
      local size = tonumber(info.size or 0)
      local size_str
      if size >= 1024 * 1024 then
        size_str = string.format("%.2f MB", size / 1024 / 1024)
      elseif size >= 1024 then
        size_str = string.format("%.2f KB", size / 1024)
      else
        size_str = string.format("%d B", size)
      end
      reaper.ImGui_Text(ctx, size_str)
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Type
    elseif col_name == "Type" then
      -- reaper.ImGui_Text(ctx, info.type)
      local fn  = info.filename or ""
      local ext = fn:match("%.([^.]+)$")
      ext = ext and ext:lower() or "-"
      reaper.ImGui_Text(ctx, ext)
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Date & Track name
    elseif is_date_track then
      if collect_mode == COLLECT_MODE_ALL_ITEMS or collect_mode == COLLECT_MODE_RPP then -- Media items or RPP
        if info.usages and #info.usages > 1 then
          reaper.ImGui_Text(ctx, ("%d instances"):format(#info.usages))
        else
          reaper.ImGui_Text(ctx, info.track_name or "")
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
              usage.track_name or "",
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
        reaper.ImGui_Text(ctx, info.bwf_orig_date or "")
      end

      RowContextFallbackFromCell(ctx, i, info, false, popup_id, is_item_mode)  -- 只给 Q，不打开主菜单

    -- Genre & Position
    elseif is_genre_pos then
      if collect_mode == COLLECT_MODE_ALL_ITEMS or collect_mode == COLLECT_MODE_RPP then -- Media items or RPP
        if info.usages and #info.usages > 1 then
          reaper.ImGui_Text(ctx, ("%d instances"):format(#info.usages))
        else
          local pos_str = reaper.format_timestr(info.position or 0, "") or ""
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
              usage.track_name or "",
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
        reaper.ImGui_Text(ctx, info.genre or "")
      end
      RowContextFallbackFromCell(ctx, i, info, false, popup_id, is_item_mode) -- 只给 Q，不打开主菜单

    -- Comment
    elseif col_name == "Comment" then
      reaper.ImGui_Text(ctx, info.comment or "")
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Description
    elseif col_name == "Description" then
      reaper.ImGui_Text(ctx, info.description or "")
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
      local len_str = (info.length and info.length > 0) and reaper.format_timestr(info.length, "") or ""
      reaper.ImGui_Text(ctx, len_str)
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Channels
    elseif col_name == "Channels" then
      reaper.ImGui_Text(ctx, info.channels)
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Samplerate
    elseif col_name == "Samplerate" then
      reaper.ImGui_Text(ctx, info.samplerate or "")
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Bits
    elseif col_name == "Bits" then
      reaper.ImGui_Text(ctx, info.bits or "")
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- Key
    elseif col_name == "Key" then
      local key = (info.key and info.key ~= "" and info.key) or ""
      reaper.ImGui_Text(ctx, key)
      RowContextFallbackFromCell(ctx, i, info, true, popup_id, is_item_mode)

    -- BPM
    elseif col_name == "BPM" then
      local bpm = info.bpm
      local bpm_str = ""
      if bpm ~= nil and bpm ~= "" then
        if type(bpm) == "number" then
          -- 显示为整数，如果是小数则保留一位
          bpm_str = (bpm % 1 == 0) and string.format("%d", bpm) or string.format("%.1f", bpm)
        else
          bpm_str = tostring(bpm)
        end
        if bpm_str == "" or bpm_str == "0" then bpm_str = "" end
      end
      reaper.ImGui_Text(ctx, bpm_str)
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

--------------------------------------------- 镜像REAPER自带数据库和快捷键方式 ---------------------------------------------

-- 读取reaper.ini的[reaper_explorer]段，建立文件名 / 别名映射
function build_reaper_db_alias_map()
  local map = {}
  local ini = reaper.GetResourcePath() .. sep .. "reaper.ini"
  local f = io.open(ini, "rb"); if not f then return map end
  local content = f:read("*a") or ""; f:close()

  local chunk = content:match("%[reaper_explorer%](.-)\n%[") or content:match("%[reaper_explorer%](.+)") or ""
  local idx = 0
  while true do
    local target = chunk:match("Shortcut"..idx.."=(.-)[\r\n]")
    if not target then break end
    local title  = chunk:match("ShortcutT"..idx.."=(.-)[\r\n]")
    -- 数据库，target不含路径时为MediaDB的.ReaperFileList
    local has_path = target:match("[/\\]")
    if not has_path and target:match("%.ReaperFileList$") then
      map[target] = title or target -- 如果没有标题，回退文件名
    end
    idx = idx + 1
  end
  return map
end

-- 枚举%ResourcePath%/MediaDB/xx.ReaperFileList
function list_reaper_databases()
  local out = {}
  local db_dir = reaper.GetResourcePath() .. sep .. "MediaDB"
  local alias_map = build_reaper_db_alias_map()
  local i = 0
  while true do
    local fn = reaper.EnumerateFiles(db_dir, i)
    if not fn then break end
    if fn:match("%.ReaperFileList$") then
      local alias = alias_map[fn] or fn
      out[#out+1] = { alias = alias, filename = fn }
    end
    i = i + 1
  end
  table.sort(out, function(a,b) return (a.alias or a.filename) < (b.alias or b.filename) end)
  return out
end

-- 获取路径的文件夹名称，无论(/, \)
function path_basename(p)
  if not p or p == "" then return "" end
  local s = tostring(p):gsub("[/\\]+$", "")
  if s:match("^%a:$") then return s end
  return s:match("([^/\\]+)$") or s
end

function list_reaper_shortcut_folders()
  local out = {}
  local sep = package.config:sub(1,1)
  local ini = reaper.GetResourcePath() .. sep .. "reaper.ini"
  local f = io.open(ini, "rb"); if not f then return out end
  local content = f:read("*a") or ""; f:close()

  local chunk = content:match("%[reaper_explorer%](.-)\n%[") or content:match("%[reaper_explorer%](.+)") or ""
  local idx = 0
  while true do
    local target = chunk:match("Shortcut"..idx.."=(.-)[\r\n]")
    if not target then break end
    local title  = chunk:match("ShortcutT"..idx.."=(.-)[\r\n]")
    -- 镜像文件夹型快捷方式
    if target:match("[/\\]") then
      local path = normalize_path(target, true)
      local name = title or (path_basename(path) or path)
      out[#out+1] = { name = name, path = path }
    end
    idx = idx + 1
  end

  table.sort(out, function(a,b) return (a.name or a.path) < (b.name or b.path) end)
  return out
end

function draw_shortcut_tree_mirror(sc, base_path, depth)
  if type(sc) ~= "table" or not sc.path then return end

  local path = normalize_path(sc.path, true)
  local show_name = (sc.name and sc.name ~= "") and sc.name or (path:gsub("[/\\]+$", "")):match("([^/\\]+)$") or path
  depth = depth or 0

  local flags = reaper.ImGui_TreeNodeFlags_SpanAvailWidth()
  local cmpath = path:gsub("[/\\]+$", "")
  if expanded_paths and expanded_paths[cmpath] then
    flags = flags | reaper.ImGui_TreeNodeFlags_DefaultOpen()
  end

  local is_selected = (collect_mode == COLLECT_MODE_SHORTCUT_MIRROR) and ((tree_state.cur_path or "") == path)
  if is_selected then
    flags = flags | reaper.ImGui_TreeNodeFlags_Selected()
  end

  local label = show_name .. "##shortcut_mirror_" .. path

  local node_open = reaper.ImGui_TreeNode(ctx, label, flags)
  -- 捕获本行矩形与中心y
  local minx, miny, maxx, maxy = CaptureNodeRectAndInit(ctx, depth)
  local cy = (miny + maxy) * 0.5
  if #_guide.stack > 0 then
    DrawChildTeeFromParent(ctx, minx, cy)
  end
  if reaper.ImGui_IsItemClicked(ctx, 0) then
    tree_state.cur_path = path
    if collect_mode ~= COLLECT_MODE_SHORTCUT_MIRROR then
      collect_mode = COLLECT_MODE_SHORTCUT_MIRROR
    end
    file_select_start, file_select_end, selected_row = nil, nil, nil
    files_idx_cache = nil
    CollectFiles()

    local static = _G._soundmole_static or {}
    _G._soundmole_static = static
    static.filtered_list_map, static.last_filter_text_map = {}, {}
  end

  if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
    reaper.ImGui_OpenPopup(ctx, "ShortcutMirrorMenu_" .. path)
  end
  if reaper.ImGui_BeginPopup(ctx, "ShortcutMirrorMenu_" .. path) then
    if reaper.ImGui_MenuItem(ctx, "Show in Explorer/Finder") then
      if path and path ~= "" then
        reaper.CF_ShellExecute(normalize_path(path))
      end
    end
    reaper.ImGui_EndPopup(ctx)
  end

  if node_open then
    if not dir_cache[path] then
      local dirs, audios, ok = list_dir(path)
      dir_cache[path] = { dirs = dirs, audios = audios, ok = ok }
    end
    local cache = dir_cache[path] or { dirs = {}, audios = {}, ok = true }

    -- 支持绘制虚线
    local pushed = false
    if #cache.dirs > 0 then
      table.insert(_guide.stack, { depth = depth, parent_cy = cy, ymin = nil, ymax = nil })
      pushed = true
    end

    for _, sub in ipairs(cache.dirs) do
      local sub_path = normalize_path(path .. sep .. sub, true)
      draw_shortcut_tree_mirror({ name = sub, path = sub_path }, path, depth + 1)
    end

    if pushed then
      local top = table.remove(_guide.stack)
      if top then
        DrawParentTrunk(ctx, top.depth, top.parent_cy, top.ymin, top.ymax)
      end
    end

    reaper.ImGui_TreePop(ctx)
    if tree_open then tree_open[path] = true end
  else
    if tree_open then tree_open[path] = false end
  end
end

--------------------------------------------- 数据库模式加载优化 ---------------------------------------------

function SM_PreviewBegin()
  _G._previewing_active = true
  _G._preview_block_until = nil

  local len -- 只有>0才使用
  if playing_source and reaper.GetMediaSourceLength then
    local ok, l = pcall(reaper.GetMediaSourceLength, playing_source)
    if ok and l and l > 0 then len = l end
  end

  if len then
    _G._preview_expected_end = reaper.time_precise() + len
  else
    _G._preview_expected_end = nil -- 未知长度不自动结束，等待 StopPreview() 结束
  end
end

function SM_PreviewStop()
  _G._previewing_active = false
  _G._preview_expected_end = nil
  _G._preview_block_until = reaper.time_precise() + 0.5 -- 预览结束后2秒再恢复加载列表，此处改为0.5秒
end

function SM_PreviewTick()
  -- 若到达预计结束时间，自动进入静默期
  if _G._previewing_active and _G._preview_expected_end then
    if reaper.time_precise() >= _G._preview_expected_end then
      SM_PreviewStop()
    end
  end
end

function ShouldPauseStreamingForPreview()
  local now = reaper.time_precise()
  local transport_active = (reaper.GetPlayState() ~= 0)
  if _G._previewing_active then return true end
  if transport_active then return true end
  if _G._preview_block_until and now < _G._preview_block_until then return true end
  return false
end

function ShouldPauseStreamingForTyping()
  local now = reaper.time_precise()
  -- 正在输入时让位
  if _G._typing_active then return true end
  -- 停止输入后的短暂尾巴期内继续让位
  if _G._typing_block_until and now < _G._typing_block_until then return true end
  return false
end

-- 暂时去掉钩子，将不使用2秒暂停加载
-- function ShouldPauseStreamingForPreview() return false end
-- function ShouldPauseStreamingForTyping() return false end

-- 按帧限时分批加载数据库条目（自适应批量）
function AppendMediaDBWhenIdle(budget_sec, batch)
  local s = _G._mediadb_stream
  if not s or s.eof then return end

  -- 打字/预览让位。存在对应函数且判定为需要让位时，本帧不加载
  if type(ShouldPauseStreamingForPreview) == "function" and ShouldPauseStreamingForPreview() then return end
  if type(ShouldPauseStreamingForTyping)  == "function" and ShouldPauseStreamingForTyping()  then return end

  _G._append_adapt = _G._append_adapt or {
    step   = 600,   -- 当前批量
    min    = 200,   -- 批量下限
    max    = 3000,  -- 批量上限
    target = 0.006, -- 目标帧预算，默认每帧约 6ms
    ema    = nil,   -- 最近帧耗时的指数滑动平均
  }
  local A = _G._append_adapt

  -- 本帧时间预算与初始批量（若传入则使用传入值，否则用自适应当前值）
  local budget = tonumber(budget_sec) or A.target
  local step   = tonumber(batch) or A.step

  -- 计时起点
  local t0 = reaper.time_precise()
  local added_total = 0

  -- 去重表。避免同一路径重复加入
  _G._stream_seen = _G._stream_seen or {}

  -- 在预算用尽前分批读取并追加
  while (reaper.time_precise() - t0) < budget do
    local chunk = MediaDBStreamRead(s, step) -- 从流中读取最多step条FILE记录（DATA 懒处理）
    local n = #chunk
    if n == 0 then break end

    -- 仅做追加索引。不解析 DATA，不做分组
    for i = 1, n do
      local e = chunk[i]
      local p = e and e.path
      if p and not _G._stream_seen[p] then
        _G._stream_seen[p] = true
        FS_MaybeSwapEntryPathToLocal(e) -- Freesound 补丁，如果本地缓存已存在，先把条目切换为本地路径，再加入缓存。
        files_idx_cache[#files_idx_cache + 1] = e
        added_total = added_total + 1
      end
    end

    if n < step then
      -- 继续在下次读取时检测 EOF
    end
  end

  -- 计算本帧实际耗时，并更新EMA（用于平滑自适应）
  local elapsed = reaper.time_precise() - t0
  local alpha = 0.3 -- EMA 平滑系数，数值越大越灵敏
  A.ema = A.ema and (A.ema + alpha * (elapsed - A.ema)) or elapsed

  -- 自适应批量调节
  -- 若实际耗时 > 预算（含 5% 容差）则收缩批量
  -- 若实际耗时 < 预算（留 20% 空头）则放大批量
  -- 始终限制在 min..max 范围内
  if A.ema > budget * 1.05 then
    step = math.max(A.min, math.floor(step * 0.75))
  elseif A.ema < budget * 0.80 then
    step = math.min(A.max, math.floor(step * 1.25))
  end
  A.step = step

  -- 文件流读尽后仅做一次排序（避免频繁排序造成卡顿）
  if s.eof then
    if type(SortFilesByFilenameAsc) == "function" then
      SortFilesByFilenameAsc()
    end
  end
end

function StartDBFirstPage(db_dir, dbfile, first_n)
  files_idx_cache = {}
  selected_row = nil

  -- 关闭旧流
  if _G._mediadb_stream then
    MediaDBStreamClose(_G._mediadb_stream)
    _G._mediadb_stream = nil
  end

  if not dbfile or dbfile == "" then return false end
  local fullpath = db_dir .. sep .. dbfile

  -- 把搜索面板里已勾选的列映射为 DATA 行中的键，作为优先解析集合
  local function build_eager_tags()
    local m = {}
    -- File Name/Path/Size/Type 不在 DATA 内，不用设置
    if type(search_fields) == "table" then
      for _, f in ipairs(search_fields) do
        if f.enabled then
          if f.key == "description"    then m.d = true end      -- d:
          if f.key == "comment"        then m.c = true end      -- c:
          if f.key == "genre"          then m.g = true end      -- g:
          if f.key == "key"            then m.k = true end      -- k:
          if f.key == "bpm"            then m.p = true end      -- p:
          if f.key == "ucs_category"   then m.category = true end     -- category:
          if f.key == "ucs_subcategory"then m.subcategory = true end  -- subcategory:
          if f.key == "ucs_catid"      then m.catid = true end        -- catid:
          if f.key == "bwf_orig_date"  then m.y = true end      -- y:
          if f.key == "length"         then m.l = true end      -- l:
          if f.key == "channels"       then m.n = true end      -- n:
          if f.key == "samplerate"     then m.s = true end      -- s:
          if f.key == "bits"           then m.i = true end      -- i:
        end
      end
    end
    return m
  end

  -- 懒解析流。DATA 行先不解析，仅缓存原文 + 按勾选列优先解析
  _G._mediadb_stream = MediaDBStreamStart(fullpath, {lazy_data  = true, eager_tags = build_eager_tags()})
  if not _G._mediadb_stream then return false end

  _G._stream_seen = {}

  -- 首批2000条
  local first = MediaDBStreamRead(_G._mediadb_stream, first_n or 2000)
  for _, e in ipairs(first) do
    FS_MaybeSwapEntryPathToLocal(e) -- Freesound 补丁，首屏条目立刻切换为本地路径（如果已下载）
    files_idx_cache[#files_idx_cache+1] = e
  end

  return true
end

--------------------------------------------- Freesound 模式 ---------------------------------------------

function __z(items) return table.concat(items, "\0") .. "\0" end

function FS_LoadSearchDB(basename)
  collect_mode = COLLECT_MODE_FREESOUND

  local db_dir = FS_DB_DIR()
  file_select_start, file_select_end, selected_row = nil, nil, nil
  previewed_files = {}
  waveform_task_queue = {}
  files_idx_cache = nil

  StartDBFirstPage(db_dir, basename, FS.FIRST_PAGE_COUNT or 2000)

  if _G._mediadb_stream and not _G._mediadb_stream.eof then
    local oldPrev, oldType = ShouldPauseStreamingForPreview, ShouldPauseStreamingForTyping
    _G.ShouldPauseStreamingForPreview = function() return false end
    _G.ShouldPauseStreamingForTyping  = function() return false end

    local t0 = reaper.time_precise()
    while _G._mediadb_stream and not _G._mediadb_stream.eof do
      AppendMediaDBWhenIdle(0.03, 1000)
      if files_idx_cache and #files_idx_cache > 0 then break end
      if reaper.time_precise() - t0 > 0.6 then break end
    end

    _G.ShouldPauseStreamingForPreview = oldPrev
    _G.ShouldPauseStreamingForTyping  = oldType
  end

  -- 初始化去重。新库起始时清零计数，并做一次首屏去重
  _G.__fs_seen_keys, _G.__fs_scanned_len = {}, 0
  FS_DedupIncremental()
end

function FS_bool_from_es(key, default)
  local v = reaper.GetExtState(EXT_SECTION, key)
  if v == "1" or v == "true" or v == "TRUE" then return true end
  if v == "0" or v == "false" or v == "FALSE" then return false end
  return default
end

-- 如果本地缓存已存在，立即把条目path切换为本地路径。以用于右侧列表即时显示
function FS_MaybeSwapEntryPathToLocal(e)
  if not e or collect_mode ~= COLLECT_MODE_FREESOUND then return end
  -- 需要拿到 comment 中的 sug@xxx 用于还原缓存文件名。懒解析一次 DATA 行
  if not e.comment then
    if type(EnsureEntryParsed) == "function" then EnsureEntryParsed(e) end
  end
  local cmt = tostring(e.comment or "")
  local enc = cmt:match("sug@([^%s]+)")
  if not enc or enc == "" then return end

  -- 复用 Freesound 的缓存命名逻辑，得到期望缓存路径
  local dst = FS_local_cache_path_for({ suggest_name = FS_urldecode(enc), comment = cmt })
  if dst and reaper.file_exists(dst) then
    e.path = dst
    e.filename = dst:match("([^/\\]+)$") or dst
  end
end

function FS_join(a,b)
  local sep = package.config:sub(1,1)
  return (a:sub(-1)=="/" or a:sub(-1)=="\\") and (a..b) or (a..sep..b)
end

function FS_ensure_dir(p)
  if not p or p=="" then return end
  if reaper.RecursiveCreateDirectory then
    reaper.RecursiveCreateDirectory(p, 0)
  else
    if package.config:sub(1,1) == "\\" then
      os.execute(('mkdir "%s" >NUL 2>NUL'):format(p))
    else
      os.execute(('mkdir -p "%s" >/dev/null 2>&1'):format(p))
    end
  end
end

function FS_urlencode(s)
  s = tostring(s or "")
  return (s:gsub("\n"," "):gsub("\r"," "):gsub("([^%w%-_%.~ ])", function(c) return string.format("%%%02X", string.byte(c)) end):gsub(" ", "%%20"))
end

function FS_urldecode(s)
  s = tostring(s or "")
  return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h,16) or 0) end))
end

-- 从 comment 解析 src@URL
function FS_extract_src_from_comment(cmt)
  local s = tostring(cmt or "")
  local u = s:match("src@([^%s]+)")
  if u and u ~= "" then return u end
  return nil
end

-- JSON 解码
local FS_json = {}
do
  local pos,str
  local function skip() while true do local c=str:sub(pos,pos); if c=="" then return else if c==" " or c=="\t" or c=="\n" or c=="\r" then pos=pos+1 else return end end end end
  local function parse_string()
    local i=pos+1; local out={}
    while i<=#str do
      local c=str:sub(i,i)
      if c=='"' then local s=table.concat(out); pos=i+1; return s
      elseif c=='\\' then
        local n=str:sub(i+1,i+1)
        if n=='"' or n=='\\' or n=='/' then out[#out+1]=n; i=i+2
        elseif n=='b' then out[#out+1]="\b"; i=i+2
        elseif n=='f' then out[#out+1]="\f"; i=i+2
        elseif n=='n' then out[#out+1]="\n"; i=i+2
        elseif n=='r' then out[#out+1]="\r"; i=i+2
        elseif n=='t' then out[#out+1]="\t"; i=i+2
        elseif n=='u' then local hex=str:sub(i+2,i+5); local cp=tonumber(hex,16) or 32; out[#out+1]=utf8.char(cp); i=i+6
        else i=i+2 end
      else out[#out+1]=c; i=i+1 end
    end
    return ""
  end
  local function parse_value()
    skip(); local c=str:sub(pos,pos)
    if c=="{" then
      pos=pos+1; local obj={}; skip()
      if str:sub(pos,pos)=="}" then pos=pos+1 return obj end
      while true do
        skip(); if str:sub(pos,pos)~='"' then return nil end
        local k=parse_string(); skip(); if str:sub(pos,pos)~=":" then return nil end; pos=pos+1
        local v=parse_value(); obj[k]=v; skip(); local ch=str:sub(pos,pos)
        if ch=="}" then pos=pos+1 break end
        if ch~="," then return nil end
        pos=pos+1
      end
      return obj
    elseif c=="[" then
      pos=pos+1; local arr={}; skip()
      if str:sub(pos,pos)=="]" then pos=pos+1 return arr end
      local i=1
      while true do
        local v=parse_value(); arr[i]=v; i=i+1; skip(); local ch=str:sub(pos,pos)
        if ch=="]" then pos=pos+1 break end
        if ch~="," then return nil end
        pos=pos+1
      end
      return arr
    elseif c=='"' then
      return parse_string()
    elseif c=="-" or c:match("%d") then
      local s0,e0=str:find("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", pos); local n=tonumber(str:sub(s0,e0)); pos=e0+1; return n
    elseif str:sub(pos,pos+3)=="null" then pos=pos+4 return nil
    elseif str:sub(pos,pos+3)=="true" then pos=pos+4 return true
    elseif str:sub(pos,pos+4)=="false" then pos=pos+5 return false
    end
    return nil
  end
  function FS_json.decode(s) str=tostring(s or ""); pos=1; return parse_value() end
end

function FS_http_get(url)
  url = tostring(url or "")

  local need_bearer = (FS and (FS.TOKEN or "") == "" and (FS.OAUTH_BEARER or "") ~= "")
  local hdr = need_bearer and (' -H "Authorization: Bearer ' .. (FS.OAUTH_BEARER:gsub('"','\\"')) .. '"') or ""

  -- 优先走 ExecProcess，避免CMD弹窗
  if reaper.ExecProcess then
    local tmp = FS_join(FS_DB_DIR(), (".fs_http_%d.tmp"):format(math.floor(reaper.time_precise()*1e6)))
    local cmd = ('curl -L -s%s "%s" -o "%s"'):format(hdr, url:gsub('"','\\"'), tmp:gsub('"','\\"'))
    local code = tonumber(reaper.ExecProcess(cmd, 120000)) or -1

    local body = ""
    local f = io.open(tmp, "rb")
    if f then body = f:read("*a") or ""; f:close() end
    os.remove(tmp)
    return (code == 0) and body or ""
  end

  -- 回退 popen
  local p = io.popen('curl -L -s' .. hdr .. ' "' .. url .. '"', "r")
  local body = p and p:read("*a") or ""
  if p then p:close() end
  return body
end

-- 配置与状态
FS = FS or {
  ENABLED           = false, -- 勾选激活
  TOKEN             = reaper.GetExtState(EXT_SECTION, "fs_api_token") or "", -- reaper.GetExtState(EXT_SECTION, "fs_oauth_client_secret") or "",
  DB_DIR            = nil, -- 脚本目录下 FreesoundDB/
  CACHE_DB_FILE     = "FreesoundDB.MoleFileList",
  SEARCH_DB_FILE    = "FreesoundSearch.MoleFileList",
  SAVE_PER_QUERY_DB = false, -- 如果为true，为每个关键词保存独立 DB
  API_PAGE_SIZE     = 150,   -- Freesound 上限 150
  FIRST_PAGE_COUNT  = 5000,  -- 首屏加载数
  last_query        = "",
  USE_ORIGINAL      = FS_bool_from_es("fs_use_original", false),        -- 勾选后使用原始文件
  OAUTH_BEARER      = reaper.GetExtState(EXT_SECTION,"fs_oauth") or "", -- OAuth2 Access Token
  DOWNLOAD_METHOD   = "curl",                                           -- nil=自动选择 "curl"=强制用curl "ps_iwr"=PowerShell Invoke-WebRequest "ps_bits"=PowerShell BITS
  ui = {
    query       = "",
    sort_idx    = 1,   -- 1 Relevance / 2 Rating / 3 Duration / 4 Downloads / 5 Created_new / 6 Created_old
    arrange_idx = 1,   -- 1 Timbre / 2 Tonality
    num_results = 200, -- 1..450
    max_minutes = 7.5  -- 0.5..30
  }
}

FS.DEBUG = FS.DEBUG == nil and true or FS.DEBUG
function FS_dbg(...)
  if not FS.DEBUG then return end
  local t = {}; for i=1,select('#', ...) do t[#t+1] = tostring(select(i, ...)) end
  reaper.ShowConsoleMsg(table.concat(t, "") .. "\n")
end

function FS_get_query()
  local q = tostring(FS and FS.ui and FS.ui.query or "")
  if q ~= "" then return q end
  local qx = reaper.GetExtState(EXT_SECTION, "fs_query") or ""
  return qx
end

function FS_set_query(q)
  q = tostring(q or "")
  if FS and FS.ui then FS.ui.query = q end
  reaper.SetExtState(EXT_SECTION, "fs_query", q, false)
end

function FS_DB_DIR()
  if FS.DB_DIR then return FS.DB_DIR end
  FS.DB_DIR = FS_join(script_path, "FreesoundDB")
  FS_ensure_dir(FS.DB_DIR)
  return FS.DB_DIR
end

function FS_path_DB_cache()
  return FS_join(FS_DB_DIR(), FS.CACHE_DB_FILE)
end

function FS_sanitize_filename(s)
  s = tostring(s or ""):gsub("[^%w%._%-]+", "_")
  if s == "" then s = "EMPTY" end
  return s:sub(1,64)
end

function FS_path_DB_search(for_query)
  if FS.SAVE_PER_QUERY_DB and for_query and for_query~="" then
    return FS_join(FS_DB_DIR(), FS_sanitize_filename(for_query) .. ".MoleFileList")
  end
  return FS_join(FS_DB_DIR(), FS.SEARCH_DB_FILE)
end

-- API 请求
function FS_sort_code(idx)
  if idx == 1 then return "score"
  elseif idx == 2 then return "rating_desc"
  elseif idx == 3 then return "duration_desc"
  elseif idx == 4 then return "downloads_desc"
  elseif idx == 5 then return "created_desc"
  elseif idx == 6 then return "created_asc"
  else return "score" end
end

function FS_build_url(q, page, page_size, sort, max_seconds)
  local base = "https://freesound.org/apiv2/search/text/"
  local fields = table.concat({
    "id","name","original_filename","tags",
    "description","license","type","previews",
    "filesize","bitdepth","samplerate","channels","duration",
    "category","category_code","created","url",
    "ac_analysis","avg_rating","num_downloads","score",
    "pack","pack_tokenized"
  }, ",")

  local filter = ""
  if max_seconds and max_seconds > 0 then
    filter = "&filter=" .. FS_urlencode(("duration:[* TO %d]"):format(math.floor(max_seconds)))
  end

  local auth_q = (FS and FS.TOKEN and FS.TOKEN ~= "") and ("&token=" .. FS_urlencode(FS.TOKEN)) or ""

  local url = ("%s?query=%s&page=%d&page_size=%d&sort=%s&group_by_pack=0&fields=%s%s%s")
    :format(base, FS_urlencode(q or ""), page or 1, page_size or 150, sort or "score",
    fields, filter, auth_q)
  return url
end

-- 去重与键构建工具
function FS_is_cache_db_path(p)
  local a = tostring(p or ""):gsub("\\","/"):lower()
  local b = tostring(FS_path_DB_cache() or ""):gsub("\\","/"):lower()
  return a == b
end
function FS_len_to_ms(sec)
  local s = tonumber(sec) or 0
  if s < 0 then s = 0 end
  return math.floor(s * 1000 + 0.5)
end
-- 文件名(不含路径，大小写不敏感) + 长度(毫秒) + size(字节)
function FS_cache_dedup_key(filename, length_sec, size_bytes)
  local name = tostring(filename or ""):lower()
  local ms   = FS_len_to_ms(length_sec)
  local sz   = tonumber(size_bytes) or 0
  return table.concat({name, ms, sz}, "|")
end
function FS_build_cache_keyset(dbpath)
  local seen = {}
  local s = MediaDBStreamStart(dbpath, { lazy_data = true })  -- 懒解析DATA【核心流式接口】
  if not s then return seen end
  while not s.eof do
    local batch = MediaDBStreamRead(s, 1500)
    for _, e in ipairs(batch) do
      -- 需要解析 DATA 才能拿到 length 等字段【EnsureEntryParsed】
      EnsureEntryParsed(e)
      local fn = e.filename or (e.path and e.path:match("([^/\\]+)$")) or e.path or ""
      seen[FS_cache_dedup_key(fn, e.length or 0, e.size or 0)] = true
    end
  end
  MediaDBStreamClose(s)
  return seen
end

function FS_s(s) s = tostring(s or ""):gsub("\r"," "):gsub("\n"," "):gsub('"',"'") return s end

-- 写入DB
function FS_write_batch_to_db(results, dbpath)
  local wrote  = 0
  local cur_q  = tostring(FS._cur_query or "")

  -- 仅写入 FreesoundDB.MoleFileList 时启用去重
  local is_cache_db = FS_is_cache_db_path(dbpath)
  local existed = is_cache_db and FS_build_cache_keyset(dbpath) or nil
  local added_in_this_run = {} -- 避免本批次自身重复

  -- 提取扩展名/去扩展/猜测扩展
  local function ext_from_name(name) name=tostring(name or ""); return name:match("%.[%w]+$") end
  local function guess_ext_from_url(url) local u=tostring(url or ""):lower(); local e=u:match("%.([%w]+)$"); return e and ("."..e) or nil end
  local function strip_ext(name) return tostring(name or ""):gsub("%.[%w]+$","") end
  local function sanitize_filename(s)
    s = tostring(s or ""):gsub('[\\/:*?"<>|]', "_"):gsub("^%s+",""):gsub("%s+$","")
    if s == "" then s = "untitled" end
    return s:sub(1,128)
  end

  -- 生成建议缓存文件名，带唯一后缀。优先fid，否则用长度毫秒 + size
  local function make_unique_suggest(base_noext, ext, fid, length_sec, size_bytes)
    local suffix
    if fid and tostring(fid) ~= "" then
      suffix = "fs" .. tostring(fid)
    else
      suffix = string.format("L%d_S%d", FS_len_to_ms(length_sec), tonumber(size_bytes) or 0)
    end
    return sanitize_filename(string.format("%s__%s%s", base_noext, suffix, ext))
  end

  for _, s in ipairs(results or {}) do
    -- 预览源
    local pv_mp3, pv_ogg = "", ""
    if s and s.previews then
      pv_mp3 = s.previews["preview-hq-mp3"] or s.previews["preview-lq-mp3"] or ""
      pv_ogg = s.previews["preview-hq-ogg"] or s.previews["preview-lq-ogg"] or ""
    end

    -- 是否使用原始文件，需 OAuth 2.0
    local want_original = (FS.USE_ORIGINAL and (FS.OAUTH_BEARER or "") ~= "" and s and s.id ~= nil)

    -- 实际下载/预览的 URL，写到 comment 的 src@
    local src_url, src_kind
    if want_original then
      src_url  = ("https://freesound.org/apiv2/sounds/%d/download/"):format(tonumber(s.id))
      src_kind = "original"
    else
      src_url  = (pv_mp3 ~= "" and pv_mp3) or (pv_ogg ~= "" and pv_ogg) or (s and s.url or "")
      src_kind = "preview"
    end

    -- 计算展示名（path 字段仅用于列表展示/检索）
    local base_name   = (s and s.original_filename and s.original_filename ~= "" and s.original_filename)
                        or (s and s.name and s.name ~= "" and s.name)
                        or ("freesound_"..tostring(s and s.id or ""))
    local base_noext  = strip_ext(base_name)
    local ext_from_ty = (s and s.type and tostring(s.type) ~= "" and ("."..tostring(s.type):gsub("^%.",""))) or nil

    local ext
    if want_original then
      ext = ext_from_ty
        or ext_from_name(s and s.original_filename)
        or ext_from_name(s and s.name)
        or guess_ext_from_url(src_url)
        or ".wav"
    else
      if pv_mp3 ~= "" then
        ext = ".mp3"
      elseif pv_ogg ~= "" then
        ext = ".ogg"
      else
        ext = guess_ext_from_url(src_url) or ".mp3"
      end
    end

    local display = sanitize_filename(base_noext .. ext)

    -- 分类/标签/描述
    local category, subcat = "", ""
    if s and type(s.category)=="table" then
      category = tostring(s.category[1] or "")
      subcat = tostring(s.category[2] or "")
    elseif s and type(s.category)=="string" then
      category = s.category
    end

    local tags = ""
    if s and type(s.tags)=="table" then
      local t = {}; local n = math.min(#s.tags, 10)
      for i = 1,n do t[#t+1] = tostring(s.tags[i] or "") end
      tags = table.concat(t, ",")
    end

    local desc_prefix = {}
    if s and tonumber(s.avg_rating)    then desc_prefix[#desc_prefix+1] = ("⭐%02.1f"):format(tonumber(s.avg_rating)) end
    if s and tonumber(s.num_downloads) then desc_prefix[#desc_prefix+1] = (function(n) local t=tostring(n); return "⬇"..t..string.rep(" ", math.max(0, 5-#t)) end)(tonumber(s.num_downloads)) end

    local head = {}
    -- if cur_q ~= "" then head[#head+1] = ("[q:%s]"):format(FS_s(cur_q)) end
    -- if s and s.name and s.name~="" then head[#head+1] = ("[%s]"):format(FS_s(s.name)) end
    -- if s and s.original_filename and s.original_filename~="" then head[#head+1] = ("(%s)"):format(FS_s(s.original_filename)) end
    if tags ~= "" then head[#head+1] = ("#%s"):format(FS_s(tags)) end
    local desc, tail = "", FS_s(s and s.description or "")
    if tail ~= "" then desc = desc .. " " .. tail end

    -- comment：src@ / src_kind@ / sug@ / fid@
    local fid = s and s.id or nil
    local comment = table.concat(desc_prefix, " ")
    if src_url ~= "" then
      comment = (comment ~= "" and (comment.."  ") or "") .. ("src@%s"):format(FS_s(src_url))
      comment = comment .. ("  src_kind@%s"):format(src_kind)
      -- 改为包含唯一后缀的建议缓存名，避免同名不同文件共用缓存
      local sug = make_unique_suggest(base_noext, ext, fid, s and s.duration or 0, s and s.filesize or 0)
      comment = comment .. ("  sug@%s"):format(FS_urlencode(sug))
    end
    if fid then
      comment = (comment ~= "" and (comment.."  ") or "") .. ("fid@%s"):format(tostring(fid))
    end
    -- if cur_q ~= "" then
    --   comment = (comment ~= "" and (comment.."  ") or "") .. ("[q:%s]"):format(FS_s(cur_q))
    -- end

    -- UCS / 音乐属性
    local aa = (s and s.ac_analysis) or {}
    local key_name = aa and (aa.ac_tonality or "") or ""
    local bpm_val  = aa and tonumber(aa.ac_tempo) or nil
    local genre = (s and s.pack ~= nil) and table.concat(head, " ") or ""

    local info = {
      path        = display,
      size        = tonumber(s and s.filesize) or 0,
      length      = tonumber(s and s.duration) or 0,
      channels    = tonumber(s and s.channels) or 0,
      samplerate  = tonumber(s and s.samplerate) or 0,
      bits        = tonumber(s and s.bitdepth) or 0,
      description = desc,
      comment     = comment,
      ucs_category    = FS_s(category),
      ucs_subcategory = FS_s(subcat),
      ucs_catid       = FS_s(s and s.category_code or ""),
      bwf_orig_date   = FS_s(s and s.created or ""),
      key             = (key_name ~= "" and key_name or nil),
      bpm             = bpm_val,
      genre           = FS_s(genre),
    }

    -- 去重，文件名 + 长度(毫秒) + size
    if is_cache_db then
      local key = FS_cache_dedup_key(display, info.length or 0, info.size or 0)
      if existed[key] or added_in_this_run[key] then
        -- 已存在，跳过写入
        goto continue
      else
        added_in_this_run[key] = true
      end
    end

    WriteToMediaDB(info, dbpath)
    wrote = wrote + 1
    ::continue::
  end

  return wrote
end

-- 统一的内存层去重键
function FS_mem_dedup_key(e)
  if not e then return nil end
  -- 确保拿到 length/size/filename（懒解析 DATA）
  if type(EnsureEntryParsed) == "function" then EnsureEntryParsed(e) end

  local fn = e.filename or (e.path and e.path:match("([^/\\]+)$")) or ""
  if fn == "" then return nil end

  local ms = math.floor((tonumber(e.length) or 0) * 1000 + 0.5)
  local sz = tonumber(e.size or 0) or 0
  return (fn:lower() .. "|" .. tostring(ms) .. "|" .. tostring(sz))
end

-- 对 files_idx_cache 做显示层的增量去重（文件名+长度ms+size）
function FS_DedupIncremental()
  if collect_mode ~= COLLECT_MODE_FREESOUND then return end
  if not files_idx_cache then return end

  _G.__fs_seen_keys   = _G.__fs_seen_keys   or {}
  _G.__fs_scanned_len = _G.__fs_scanned_len or 0

  local start_i = _G.__fs_scanned_len + 1
  local N = #files_idx_cache
  if start_i > N then return end

  local sel_obj = (selected_row and files_idx_cache[selected_row]) or nil

  -- 标记重复
  for i = start_i, N do
    local e = files_idx_cache[i]
    local k = FS_mem_dedup_key(e)
    if k then
      if _G.__fs_seen_keys[k] then
        files_idx_cache[i] = false -- 标记删除
      else
        _G.__fs_seen_keys[k] = true
      end
    end
  end

  -- 压缩 false
  local out = {}
  for i = 1, #files_idx_cache do
    local e = files_idx_cache[i]
    if e then out[#out+1] = e end
  end
  files_idx_cache = out

  -- 恢复选中行
  if sel_obj then
    local found
    for i = 1, #files_idx_cache do
      if files_idx_cache[i] == sel_obj then found = i; break end
    end
    selected_row = found
  end

  _G.__fs_scanned_len = #files_idx_cache
end

-- Arrange by 的客户端排序
function FS_arrange_sort(results, arrange_idx)
  if arrange_idx == 1 then
    -- Timbre: 以 brightness -> warmth -> hardness -> roughness 进行稳定排序
    table.sort(results, function(a,b)
      local aa, bb = a.ac_analysis or {}, b.ac_analysis or {}
      local k1 = tonumber(aa.ac_brightness or -1) or -1
      local k2 = tonumber(bb.ac_brightness or -1) or -1
      if k1 ~= k2 then return k1 > k2 end
      local w1 = tonumber(aa.ac_warmth or -1) or -1
      local w2 = tonumber(bb.ac_warmth or -1) or -1
      if w1 ~= w2 then return w1 > w2 end
      local h1 = tonumber(aa.ac_hardness or -1) or -1
      local h2 = tonumber(bb.ac_hardness or -1) or -1
      if h1 ~= h2 then return h1 > h2 end
      local r1 = tonumber(aa.ac_roughness or -1) or -1
      local r2 = tonumber(bb.ac_roughness or -1) or -1
      if r1 ~= r2 then return r1 > r2 end
      return (a.id or 0) < (b.id or 0)
    end)
  elseif arrange_idx == 2 then
    -- Tonality: ac_tonality 字符串分组 + 次级按排行/下载数做细排
    table.sort(results, function(a,b)
      local aa, bb = a.ac_analysis or {}, b.ac_analysis or {}
      local t1 = tostring(aa.ac_tonality or "~")
      local t2 = tostring(bb.ac_tonality or "~")
      if t1 ~= t2 then return t1 < t2 end
      local r1 = tonumber(a.avg_rating or -1) or -1
      local r2 = tonumber(b.avg_rating or -1) or -1
      if r1 ~= r2 then return r1 > r2 end
      local d1 = tonumber(a.num_downloads or -1) or -1
      local d2 = tonumber(b.num_downloads or -1) or -1
      if d1 ~= d2 then return d1 > d2 end
      return (a.id or 0) < (b.id or 0)
    end)
  end
end

-- 搜索与加载
function FS_rebuild_cache_if_empty()
  local cache_db = FS_path_DB_cache()
  local f = io.open(cache_db, "rb")
  if f then f:close(); return end
  local f2 = io.open(cache_db, "wb") if f2 then f2:close() end
end

function FS_search_basename(for_query)
  if FS.SAVE_PER_QUERY_DB and for_query and for_query ~= "" then
    return (tostring(for_query):gsub("[^%w%._%-]+","_"):sub(1,64)) .. ".MoleFileList"
  end
  return FS.SEARCH_DB_FILE
end

-- 全局 Arrange 跨页汇总后一次性按 Timbre/Tonality 排序，再写库
function FS_fetch_and_build_db(q, sort_idx, max_minutes, total_needed)
  q = tostring(q or "")
  local basename  = FS_search_basename(q)
  local search_db = FS_join(FS_DB_DIR(), basename)
  local cache_db  = FS_join(FS_DB_DIR(), FS.CACHE_DB_FILE)

  local f = io.open(search_db, "wb"); if f then f:close() end
  local f2 = io.open(cache_db,  "ab"); if f2 then f2:close() end

  local PAGE_MAX     = math.min(FS.API_PAGE_SIZE or 150, 150) -- 固定每页 150 API上限
  local want_total   = math.max(1, tonumber(total_needed) or 200)
  local sort         = FS_sort_code(sort_idx or 1)
  local max_seconds  = math.floor((tonumber(max_minutes) or 7.5) + 0.5)

  local seen, last_err = {}, nil
  local pool_all = {}
  local page = 1
  FS._cur_query = q

  while #pool_all < want_total do
    local url = FS_build_url(q, page, PAGE_MAX, sort, max_seconds)
    local body = FS_http_get(url)
    if not body or body == "" then last_err = "Empty HTTP body."; break end

    local obj = FS_json.decode(body)
    if not (obj and obj.results and type(obj.results)=="table") then
      last_err = tostring(body):gsub("[\r\n]+"," "):sub(1,180)
      break
    end

    for _, s in ipairs(obj.results) do
      if s and s.id and not seen[s.id] then
        seen[s.id] = true
        pool_all[#pool_all+1] = s
      end
    end

    if not obj.next or obj.next == "" or #obj.results < PAGE_MAX then break end
    page = page + 1
  end

  FS_arrange_sort(pool_all, FS.ui.arrange_idx or 1)

  local take = math.min(want_total, #pool_all)
  local batch = {}
  for i = 1, take do batch[i] = pool_all[i] end

  local wrote_total = FS_write_batch_to_db(batch, search_db)
  FS_write_batch_to_db(batch, cache_db)

  FS._cur_query = nil
  return basename, wrote_total, last_err
end

function FS_show_search_or_cache(force_basename)
  local db_dir = FS_DB_DIR()
  local basename = force_basename
  if not basename or basename == "" then
    local q = FS_get_query()
    if q ~= "" then
      basename = FS_search_basename(q)
    else
      basename = FS.CACHE_DB_FILE
    end
  end

  local full = FS_join(db_dir, basename)
  local f = io.open(full, "rb")
  local sz = 0
  if f then sz = f:seek("end") or 0; f:close() end
  if not f or sz == 0 then
    basename = FS.CACHE_DB_FILE
  end

  StartDBFirstPage(db_dir, basename, FS.FIRST_PAGE_COUNT or 2000)
end

-- 下载与播放 Hook
function FS_is_http(p) p = tostring(p or ""):lower(); return p:match("^https?://")~=nil end
function FS_norm_http(p)
  p = tostring(p or "")
  if p:match("^https?[:\\/]") then
    p = p:gsub("\\","/"):gsub("^https:/([^/])","https://%1"):gsub("^http:/([^/])","http://%1")
  end
  return p
end

function FS_cache_dir()
  local d = FS_join(script_path, "freesound_cache")
  FS_ensure_dir(d)
  return d
end

function FS_basename_from_url(url)
  url = tostring(url or "")
  local base = url:gsub("[?#].*$",""):match("([^/]+)$") or ("fs_preview_"..tostring(math.random(1,1e9)))
  if not base:match("%.[%w]+$") then
    local ext = (url:match("%.ogg") and ".ogg") or ".mp3"
    base = base .. ext
  end
  return base:gsub("[^%w%._%-]+","_"):sub(1,80)
end

function FS_sanitize_cache_name(s)
  s = tostring(s or ""):gsub('[\\/:*?"<>|]', "_")
  s = s:gsub("^%s+",""):gsub("%s+$","")
  if s == "" then s = "cachefile" end
  return s:sub(1,128)
end

function FS_local_cache_path_for(info)
  local cache_dir = FS_cache_dir()

  local suggest = info and info.suggest_name
  if (not suggest or suggest == "") then
    local cmt = tostring(info and info.comment or "")
    local enc = cmt:match("sug@([^%s]+)")
    if enc and enc ~= "" then
      suggest = FS_urldecode(enc)
    end
  end

  if suggest and suggest ~= "" then
    return FS_join(cache_dir, FS_sanitize_cache_name(suggest))
  end

  local url = FS_norm_http(info and (info.src or info.path) or "")
  local base = url:gsub("[?#].*$",""):match("([^/]+)$") or ("fs_"..tostring(math.random(1,1e9)))
  if not base:match("%.[%w]+$") then base = base .. ".dat" end
  return FS_join(cache_dir, base:gsub("[^%w%._%-]+","_"):sub(1,80))
end

-- 占位波形
function FS_EnsureEmptyWaveform(info, thumb_w)
  if not info or not thumb_w or thumb_w <= 0 then return end
  info._thumb_waveform = info._thumb_waveform or {}
  if info._thumb_waveform[thumb_w] then return end

  local chs = math.max(1, tonumber(info.channels or 1) or 1) -- 强制 1 声道以省CPU
  local peaks = {}
  for ch = 1, chs do
    peaks[ch] = {}
    for i = 1, thumb_w do
      peaks[ch][i] = {0, 0}  -- 零值峰，画出一条居中的细线
    end
  end
  local src_len = tonumber(info.length or 0) or 0
  info._thumb_waveform[thumb_w] = {
    peaks       = peaks,
    pixel_cnt   = thumb_w,
    src_len     = src_len,
    channel_count = chs
  }
end

function FS_run(cmd)
  local p = io.popen(cmd .. " 2>&1", "r")
  if not p then return "", -1 end
  local out = p:read("*a") or ""
  local ok, _, code = p:close()
  local ec = (type(code)=="number" and code) or (ok and 0 or -1)
  return out, ec
end

function FS_has_curl()
  local p = io.popen((package.config:sub(1,1)=="\\" and "where curl 2>nul" or "which curl 2>/dev/null"), "r")
  local out = p and p:read("*a") or ""; if p then p:close() end
  return out ~= nil and out ~= ""
end

function FS_download_to(url, dst, auth_header)
  FS_ensure_dir(dst:match("^(.*)[/\\]") or FS_cache_dir())
  url = FS_norm_http(url)

  local is_win = (package.config:sub(1,1) == "\\")
  local method = FS.DOWNLOAD_METHOD
  if not method or method=="" then
    if is_win then
      method = (FS_has_curl() and "curl") or "ps_iwr"
    else
      method = "curl"
    end
  end

  local auth_val = nil
  if auth_header and auth_header:match("^%s*Authorization:%s*") then
    auth_val = auth_header:gsub("^%s*Authorization:%s*", "")
  end

  local function try_curl()
    local header = ""
    if auth_header and auth_header ~= "" then
      header = string.format(' -H "%s"', auth_header:gsub('"','\\"'))
    end
    local ua = ' -A "Soundmole/1.0"'
    local cmd = string.format(
      'curl --fail -L --retry 3 --retry-delay 1 --connect-timeout 10 --max-time 120 --no-progress-meter -C -%s%s "%s" -o "%s"',
      ua, header, url, dst
    )

    local code
    if reaper.ExecProcess then
      code = tonumber(reaper.ExecProcess(cmd, 120000)) or -1
    else
      local _, c = FS_run(cmd)
      code = c
    end
    return code == 0, code, "curl"
  end

  local function try_ps_iwr()
    local headers_ps
    if auth_val and auth_val ~= "" then
      headers_ps = ([[ -Headers @{ Authorization = '%s'; "User-Agent" = 'Soundmole/1.0' } ]]):format(auth_val:gsub("'","''"))
    else
      headers_ps = [[ -Headers @{ "User-Agent" = 'Soundmole/1.0' } ]]
    end
    local ps = ([[ $ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { $r=Invoke-WebRequest -UseBasicParsing -TimeoutSec 120 -Uri '%s' -OutFile '%s' %s -PassThru; if (Test-Path -LiteralPath '%s') { exit 0 } else { exit 3 } } catch { $code=1; if ($_.Exception.Response){ try { $code=[int]$_.Exception.Response.StatusCode.value__ } catch {} }; exit $code } ]])
              :format(url:gsub("'","''"), dst:gsub("'","''"), headers_ps, dst:gsub("'","''"))
    local cmd = string.format('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "%s"', ps)
    local _, c = FS_run(cmd)
    return c == 0, c, "ps_iwr"
  end

  local ok, code, used = false, -1, method
  if method == "curl" then
    ok, code, used = try_curl()
  elseif method == "ps_iwr" and is_win then
    ok, code, used = try_ps_iwr()
  elseif method == "ps_bits" and is_win then
    ok, code, used = try_ps_iwr()
  else
    ok, code, used = try_curl()
  end

  local f = ok and io.open(dst, "rb") or nil
  if f then
    local sz = f:seek("end") or 0; f:close()
    if sz > 0 then return true end
    --FS_dbg(string.format("[FS] download size=0 for %s", tostring(dst)))
  else
    --FS_dbg("[FS] download failed or no file created: ", tostring(dst))
  end
  return false
end

function FS_ensure_local_before_play(info)
  if not info then return end
  if collect_mode ~= COLLECT_MODE_FREESOUND then return end

  local p = tostring(info.path or "")
  local src, src_kind = nil, "preview"
  local cmt = tostring(info.comment or "")

  if FS_is_http(p) then
    src = FS_norm_http(p)
  else
    src = cmt:match("src@([^%s]+)")
    if src then src = FS_norm_http(src) end
    local k = cmt:match("src_kind@([%w_]+)")
    if k and k ~= "" then src_kind = k end
  end
  if not (src and FS_is_http(src)) then return end

  -- 解析建议文件名，来自 comment 的 sug@
  local suggest
  do
    local enc = cmt:match("sug@([^%s]+)")
    if enc and enc ~= "" then suggest = FS_urldecode(enc) end
  end

  local dst = FS_local_cache_path_for({ src = src, suggest_name = suggest, comment = cmt })

  local auth_header = nil
  if src_kind == "original" and (FS.OAUTH_BEARER or "") ~= "" then
    auth_header = "Authorization: Bearer " .. FS.OAUTH_BEARER
  end

  local ok = reaper.file_exists(dst) or FS_download_to(src, dst, auth_header)

  -- 原始下载失败，尝试刷新后重试一次
  if (not ok) and src_kind == "original" and (reaper.GetExtState(EXT_SECTION, "fs_oauth_refresh") or "") ~= "" then
    if FS_OAuth_Refresh(true) then -- 静默刷新，避免弹窗
      auth_header = "Authorization: Bearer " .. (FS.OAUTH_BEARER or "")
      ok = FS_download_to(src, dst, auth_header)
    end
  end

  if not ok then return end

  -- 下载成功把该行的路径直接替换为本地路径，列表即时显示
  info.path = dst
  info._thumb_waveform = nil
  info._loading_waveform = false

  local w = (info._last_thumb_w and tonumber(info._last_thumb_w)) or 400
  if type(EnqueueWaveformTask) == "function" then
    waveform_task_queue = waveform_task_queue or {}
    EnqueueWaveformTask(info, w)
  end
end

function FS_InitHooks()
  if _G.__FS_HOOKS_INSTALLED then return end
  _G.__FS_HOOKS_INSTALLED = true

  -- 播放钩子
  if type(PlayFromStart)=="function" then
    local __orig = PlayFromStart
    PlayFromStart = function(info) FS_ensure_local_before_play(info); return __orig(info) end
  end
  if type(PlayFromCursor)=="function" then
    local __orig = PlayFromCursor
    PlayFromCursor = function(info) FS_ensure_local_before_play(info); return __orig(info) end
  end

  -- 插入钩子
  if type(InsertSelectedToProject)=="function" then
    local __orig = InsertSelectedToProject
    InsertSelectedToProject = function(...)
      if selected_row and files_idx_cache and files_idx_cache[selected_row] then
        FS_ensure_local_before_play(files_idx_cache[selected_row])
      end
      return __orig(...)
    end
  end

  -- 流式加载时做增量去重
  if type(AppendMediaDBWhenIdle)=="function" and not _G.__FS_WRAP_APPEND then
    _G.__FS_WRAP_APPEND = true
    local __orig_append = AppendMediaDBWhenIdle
    AppendMediaDBWhenIdle = function(budget_sec, batch)
      local ret = __orig_append(budget_sec, batch)
      if collect_mode == COLLECT_MODE_FREESOUND then
        FS_DedupIncremental()
      end
      return ret
    end
  end

  -- 波形单元渲染本地未落地时，先放空波形占位
  if type(RenderWaveformCell)=="function" and not _G.__FS_WRAP_RENDER_CELL then
    _G.__FS_WRAP_RENDER_CELL = true
    local __orig_render = RenderWaveformCell
    RenderWaveformCell = function(ctx, i, info, row_height, cmode, idle_time)
      if cmode == COLLECT_MODE_FREESOUND and info and info.path then
        -- 本地文件不存在给占位波形，避免首次加载 FLAC/OGG 不显示
        local p = normalize_path(info.path, false)
        if not reaper.file_exists(p) then
          local thumb_w = math.floor(reaper.ImGui_GetContentRegionAvail(ctx))
          FS_EnsureEmptyWaveform(info, thumb_w)
        end
      end
      return __orig_render(ctx, i, info, row_height, cmode, idle_time)
    end
  end

  -- 确保有本地缓存库文件
  FS_rebuild_cache_if_empty()
end

-- OAuth2 支持
local FS_K = {
  cid   = "fs_oauth_client_id",
  csec  = "fs_oauth_client_secret",
  redir = "fs_oauth_redirect_uri",
  acc   = "fs_oauth",
  ref   = "fs_oauth_refresh"
}
function FS_set_es(k, v)
  reaper.SetExtState(EXT_SECTION, k, tostring(v or ""), true)
end
function FS_get_es(k)
  return reaper.GetExtState(EXT_SECTION, k) or ""
end

-- 打开授权页
function FS_OAuth_OpenAuthorize()
  local client_id = FS_get_es(FS_K.cid)
  local redirect  = FS_get_es(FS_K.redir)
  if client_id == "" then
    reaper.MB("Please enter your Client ID first.", "Freesound OAuth 2.0", 0)
    --  reaper.MB("请先填写 Client ID。", "Freesound OAuth 2.0", 0)
    return
  end
  local state = tostring(math.random(1, 1e9))
  local url = ("https://freesound.org/apiv2/oauth2/authorize/?client_id=%s&response_type=code&state=%s%s")
    :format(FS_urlencode(client_id), FS_urlencode(state),
    (redirect ~= "" and ("&redirect_uri="..FS_urlencode(redirect)) or ""))
  if reaper.CF_ShellExecute then reaper.CF_ShellExecute(url)
  elseif package.config:sub(1,1) == "\\" then os.execute('start "" "'..url..'"')
  else os.execute('open "'..url..'"') end
end

function FS_http_post_form(url, kvpairs)
  url = tostring(url or "")

  -- 组装 x-www-form-urlencoded 数据
  local parts = {}
  for k, v in pairs(kvpairs or {}) do
    parts[#parts+1] = ("%s=%s"):format(FS_urlencode(k), FS_urlencode(tostring(v or "")))
  end
  local data = table.concat(parts, "&")

  -- 优先 ExecProcess 避免CMD弹窗
  if reaper.ExecProcess then
    local tmp = FS_join(FS_DB_DIR(), (".fs_http_%d.tmp"):format(math.floor(reaper.time_precise()*1e6)))
    local cmd = ('curl -s -L -X POST -H "Content-Type: application/x-www-form-urlencoded" --data "%s" "%s" -o "%s"')
      :format(data:gsub('"','\\"'), url:gsub('"','\\"'), tmp:gsub('"','\\"'))
    local code = tonumber(reaper.ExecProcess(cmd, 120000)) or -1

    local body = ""
    local f = io.open(tmp, "rb")
    if f then body = f:read("*a") or ""; f:close() end
    os.remove(tmp)
    return (code == 0) and body or ""
  end

  -- 回退到 popen
  local cmd = ('curl -s -L -X POST -H "Content-Type: application/x-www-form-urlencoded" --data "%s" "%s"')
    :format(data, url)
  local p = io.popen(cmd, "r")
  local body = p and p:read("*a") or ""
  if p then p:close() end
  return body
end

-- 用授权码换取 Access/Refresh Token
function FS_OAuth_ExchangeCode(auth_code)
  auth_code = tostring(auth_code or "")
  local client_id     = FS_get_es(FS_K.cid)
  local client_secret = FS_get_es(FS_K.csec)
  -- local redirect_uri  = FS_get_es(FS_K.redir)

  if client_id=="" or client_secret=="" then
    -- reaper.MB("请先填写 Client ID / Client Secret。", "Freesound OAuth 2.0", 0)
    reaper.MB("Please enter both Client ID and Client Secret first.", "Freesound OAuth 2.0", 0)
    return false
  end
  if auth_code=="" then
    -- reaper.MB("请粘贴授权回调地址中的 code 参数。", "Freesound OAuth 2.0", 0)
    reaper.MB("Please paste the 'code' parameter from the authorization callback URL.", "Freesound OAuth 2.0", 0)
    return false
  end

  local token_url = "https://freesound.org/apiv2/oauth2/access_token/"
  local form = {
    grant_type    = "authorization_code",
    client_id     = client_id,
    client_secret = client_secret,
    code          = auth_code,
  }
  -- 只有填写了 redirect_uri 才附带
  -- if (redirect_uri or "") ~= "" then
  --   form.redirect_uri = redirect_uri
  -- end

  local body = FS_http_post_form(token_url, form)
  local obj  = FS_json.decode(body or "")

  if not (obj and obj.access_token) then
    local reason = (obj and (obj.error_description or obj.error)) or tostring(body):sub(1,400)
    -- reaper.MB("换取令牌失败：\n"..reason, "Freesound OAuth2", 0)
    reaper.MB(("Token exchange failed:\n%s"):format(tostring(reason or "")), "Freesound OAuth2", 0)
    return false
  end

  -- 保存 token
  FS_set_es(FS_K.acc, obj.access_token or "")
  FS_set_es(FS_K.ref, obj.refresh_token or "")

  FS.OAUTH_BEARER = obj.access_token or ""
  FS.ui = FS.ui or {}
  FS.ui.oauth_code = ""
  FS.ui._oauth_just_saved = true

  -- reaper.MB("OAuth 2.0 Access Token 已保存。", "Freesound OAuth 2.0", 0)
  reaper.MB("OAuth 2.0 access token saved.", "Freesound OAuth 2.0", 0)
  return true
end

-- 刷新 Access Token
function FS_OAuth_Refresh(silent)
  local client_id     = FS_get_es(FS_K.cid)
  local client_secret = FS_get_es(FS_K.csec)
  local refresh_token = FS_get_es(FS_K.ref)
  if client_id=="" or client_secret=="" or refresh_token=="" then
    -- if not silent then reaper.MB("请先保存 Client ID/Secret，并确保已有 Refresh Token。", "Freesound OAuth2", 0) end
    if not silent then reaper.MB("Please save Client ID/Secret and ensure a Refresh Token is available.", "Freesound OAuth2", 0) end
    return false
  end
  local token_url = "https://freesound.org/apiv2/oauth2/access_token/"
  local body = FS_http_post_form(token_url, {
    grant_type    = "refresh_token",
    client_id     = client_id,
    client_secret = client_secret,
    refresh_token = refresh_token
  })
  local obj = FS_json.decode(body or "")
  if not (obj and obj.access_token) then
    -- if not silent then reaper.MB("刷新失败：\n"..tostring(body):sub(1,400), "Freesound OAuth2", 0) end
    if not silent then reaper.MB(("Refresh failed:\n%s"):format(tostring(body):sub(1,400)), "Freesound OAuth2", 0) end
    return false
  end
  FS_set_es(FS_K.acc, obj.access_token or "")
  if obj.refresh_token and obj.refresh_token ~= "" then
    FS_set_es(FS_K.ref, obj.refresh_token) -- 如果返回了新的 refresh_token，则一并保存
  end
  FS.OAUTH_BEARER = obj.access_token or ""
  -- if not silent then reaper.MB("Access Token 已刷新。", "Freesound OAuth2", 0) end
  if not silent then reaper.MB("Access token refreshed.", "Freesound OAuth2", 0) end
  return true
end

function FS_DrawApiTokenField(ctx)
  reaper.ImGui_Text(ctx, "API key (token)")
  reaper.ImGui_SetNextItemWidth(ctx, 320)
  FS.ui = FS.ui or {}
  local show_secret = FS.ui._show_secrets == true
  local flags = show_secret and 0 or reaper.ImGui_InputTextFlags_Password()
  local cur = reaper.GetExtState(EXT_SECTION, "fs_api_token") or ""
  local changed, v = reaper.ImGui_InputText(ctx, "##fs_api_token", cur, flags)
  if changed and v ~= nil then
    reaper.SetExtState(EXT_SECTION, "fs_api_token", v, true)
    FS.TOKEN = v or ""
  end
  reaper.ImGui_SameLine(ctx)
  -- HelpMarker("Freesound API v2 key，用于调用 /search/text/ 等只读接口。未启用 OAuth 也必须提供此值才能拿到预览URL。")
  HelpMarker("Paste your Freesound API key (token). Used for /search/text etc. If OAuth is disabled, this is still required to fetch preview URLs.")
end

-- Freesound 标签页 UI
function FS_DrawSidebar(ctx)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), 0x00000000)
  reaper.ImGui_PopStyleColor(ctx)
  reaper.ImGui_Indent(ctx, 8)

  -- 激活 Freesound 模式
  do
    local is_fs_mode = (collect_mode == COLLECT_MODE_FREESOUND)
    local changed_enabled, want_enable = reaper.ImGui_Checkbox(ctx, "Activate Freesound mode", is_fs_mode)

    if changed_enabled then
      if want_enable then
        -- 记住上一个模式以便回退
        FS._last_collect_mode = collect_mode
        collect_mode = COLLECT_MODE_FREESOUND
        -- 进入 FS 模式后的初始化
        FS_show_search_or_cache()
        file_select_start, file_select_end, selected_row = nil, nil, nil
        files_idx_cache = nil
        CollectFiles()
        local static = _G._soundmole_static or {}
        _G._soundmole_static = static
        static.filtered_list_map, static.last_filter_text_map = {}, {}
      else
        -- 取消勾选则从 Freesound 退回之前的模式（如果记录）
        if FS._last_collect_mode and FS._last_collect_mode ~= COLLECT_MODE_FREESOUND then
          collect_mode = FS._last_collect_mode
        end
      end
    end

    -- 只有当前模式为 Freesound 时才保持勾选，否则自动取消勾选
    FS.ENABLED = (collect_mode == COLLECT_MODE_FREESOUND)
    reaper.ImGui_BeginDisabled(ctx, not FS.ENABLED)
  end

  reaper.ImGui_SeparatorText(ctx, "Search Sounds")

  -- 搜索框
  reaper.ImGui_Text(ctx, "Search")
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_SetNextItemWidth(ctx, 274)

  local _, q_val = reaper.ImGui_InputText(ctx, "##fs_query", FS_get_query())
  if q_val ~= nil then FS_set_query(q_val) end

  -- Arrange by
  reaper.ImGui_Text(ctx, "Arrange by")
  reaper.ImGui_SameLine(ctx)
  local arr = { "Timbre", "Tonality" }
  reaper.ImGui_SetNextItemWidth(ctx, 250)
  local arr_changed, arr_idx0 = reaper.ImGui_Combo(ctx, "##fs_arrange", (FS.ui.arrange_idx or 1)-1, __z(arr))
  if arr_changed then FS.ui.arrange_idx = (arr_idx0 or 0) + 1 end

  -- Sort by
  reaper.ImGui_Text(ctx, "Sort by")
  reaper.ImGui_SameLine(ctx)
  local sorts = {
    "Relevance","Rating","Duration","Downloads",
    "Creation Date (newest first)","Creation Date (oldest first)"
  }
  reaper.ImGui_SetNextItemWidth(ctx, 273)
  local s_changed, s_idx0 = reaper.ImGui_Combo(ctx, "##fs_sort", (FS.ui.sort_idx or 1)-1, __z(sorts))
  if s_changed then FS.ui.sort_idx = (s_idx0 or 0) + 1 end

  -- Number of results
  reaper.ImGui_Text(ctx, "Number of results")
  reaper.ImGui_SetNextItemWidth(ctx, 320)
  local nr_changed, nr = reaper.ImGui_SliderInt(ctx, "##fs_num", FS.ui.num_results or 200, 1, 450)
  if nr_changed then FS.ui.num_results = nr end

  -- Maximum duration
  reaper.ImGui_Text(ctx, "Maximum duration")
  reaper.ImGui_SetNextItemWidth(ctx, 320)
  local md_changed, md = reaper.ImGui_SliderDouble(ctx, "##fs_maxdur", FS.ui.max_minutes or 7.5, 0.5, 30.0, "%.1f")
  if md_changed then FS.ui.max_minutes = md end

  -- API Token 输入框
  FS_DrawApiTokenField(ctx)

  -- 清空回到本地增量库
  if reaper.ImGui_Button(ctx, "Clear search (show local cache)", 200, 32) then
    FS_set_query("") -- 清空缓存
    collect_mode = COLLECT_MODE_FREESOUND
    FS_LoadSearchDB(FS.CACHE_DB_FILE)

    -- 刷新
    file_select_start, file_select_end, selected_row = nil, nil, nil
    files_idx_cache = nil
    CollectFiles()

    local static = _G._soundmole_static or {}
    _G._soundmole_static = static
    static.filtered_list_map, static.last_filter_text_map = {}, {}
  end

  reaper.ImGui_SameLine(ctx)

  if reaper.ImGui_Button(ctx, "Search", 112, 32) then
    local q = FS_get_query():match("^%s*(.-)%s*$")

    if q == "" then
      collect_mode = COLLECT_MODE_FREESOUND
      FS_LoadSearchDB(FS.CACHE_DB_FILE)
    else
      collect_mode = COLLECT_MODE_FREESOUND
      FS.last_query = q
      FS_set_query(q)  -- 回写，保证输入框不丢词

      local basename, wrote_total, err_excerpt = FS_fetch_and_build_db(
        q, FS.ui.sort_idx, FS.ui.max_minutes, FS.ui.num_results
      )

      FS_LoadSearchDB(basename)

      file_select_start, file_select_end, selected_row = nil, nil, nil
      files_idx_cache = nil
      CollectFiles()

      local static = _G._soundmole_static or {}
      _G._soundmole_static = static
      static.filtered_list_map, static.last_filter_text_map = {}, {}

      if (wrote_total or 0) == 0 and (err_excerpt or "") ~= "" then
        -- reaper.ShowMessageBox("Freesound：未获得结果或 API 响应异常。\n"..tostring(err_excerpt), "Soundmole", 0)
        reaper.ShowMessageBox("Freesound: No results or an unexpected API response.\n" .. tostring(err_excerpt), "Soundmole", 0)
      end
    end
  end
  
  -- OAuth 2.0 设置
  -- if reaper.ImGui_CollapsingHeader(ctx, "Original download (OAuth2 settings)") then
  reaper.ImGui_SeparatorText(ctx, "Original download (OAuth 2.0 settings)")
  local changed_uo, val_uo = reaper.ImGui_Checkbox(ctx, "Use original files (OAuth 2.0)", FS.USE_ORIGINAL)
  if changed_uo then
    FS.USE_ORIGINAL = val_uo
    reaper.SetExtState(EXT_SECTION, "fs_use_original", (val_uo and "1" or "0"), true)
  end
  reaper.ImGui_SameLine(ctx)
  HelpMarker("Download/preview the original audio via OAuth 2.0 (requires a valid access token). Uses the original file instead of the MP3/OGG preview. \n")

  local cid   = FS_get_es("fs_oauth_client_id")
  local csec  = FS_get_es("fs_oauth_client_secret")
  local redir = FS_get_es("fs_oauth_redirect_uri")
  local acc   = FS_get_es("fs_oauth")
  local ref   = FS_get_es("fs_oauth_refresh")

  -- 显示明文
  FS.ui = FS.ui or {}
  local show_secret = FS.ui._show_secrets == true
  local pwd_flags = show_secret and 0 or reaper.ImGui_InputTextFlags_Password()

  reaper.ImGui_Text(ctx, "Client ID")
  reaper.ImGui_SetNextItemWidth(ctx, 320)
  local _, v1 = reaper.ImGui_InputText(ctx, "##cid", cid, pwd_flags)
  if v1 ~= nil then FS_set_es("fs_oauth_client_id", v1) end

  reaper.ImGui_Text(ctx, "Client Secret")
  reaper.ImGui_SetNextItemWidth(ctx, 320)
  local _, v2 = reaper.ImGui_InputText(ctx, "##csec", csec, pwd_flags)
  if v2 ~= nil then FS_set_es("fs_oauth_client_secret", v2) end

  -- 切换明/暗文
  local changed_show, sv = reaper.ImGui_Checkbox(ctx, "Show values", show_secret)
  if changed_show then FS.ui._show_secrets = sv end

  if reaper.ImGui_Button(ctx, "Open authorization page", 200, 32) then FS_OAuth_OpenAuthorize() end
  reaper.ImGui_Text(ctx, "Paste authorization code:")

  FS.ui = FS.ui or {}
  reaper.ImGui_SetNextItemWidth(ctx, 320)
  local _, code_in = reaper.ImGui_InputText(ctx, "##auth_code", FS.ui.oauth_code or "")
  if code_in ~= nil then FS.ui.oauth_code = code_in end

  if reaper.ImGui_Button(ctx, "Exchange authorization code", 200, 32) and (FS.ui.oauth_code or "") ~= "" then
    FS_OAuth_ExchangeCode(FS.ui.oauth_code or "")
  end

  local skip_this_frame = false
  if FS.ui and FS.ui._oauth_just_saved then
    skip_this_frame = true
    FS.ui._oauth_just_saved = nil
  end

  local acc_now = FS_get_es(FS_K.acc)
  reaper.ImGui_Text(ctx, "Access token (Bearer)")
  reaper.ImGui_SetNextItemWidth(ctx, 320)
  local acc_changed, acc_val = reaper.ImGui_InputText(ctx, "##acc", acc_now)
  if acc_changed and not skip_this_frame then
    FS_set_es(FS_K.acc, acc_val)
    FS.OAUTH_BEARER = acc_val
  end

  local ref_now = FS_get_es(FS_K.ref)
  reaper.ImGui_Text(ctx, "Refresh token")
  reaper.ImGui_SetNextItemWidth(ctx, 320)
  local ref_changed, ref_val = reaper.ImGui_InputText(ctx, "##ref", ref_now)
  if ref_changed and not skip_this_frame then
    FS_set_es(FS_K.ref, ref_val)
  end

  if reaper.ImGui_Button(ctx, "Refresh access token", 200, 32) then FS_OAuth_Refresh(false) end
  reaper.ImGui_SameLine(ctx)
  HelpMarker("Refresh the OAuth 2.0 access token when original-file downloads start failing (e.g., 401/403) or when the token is about to expire. Some providers rotate the refresh token on refresh. If a new one is returned, it will be saved automatically.\n")

  reaper.ImGui_EndDisabled(ctx)
  reaper.ImGui_Unindent(ctx, 8)
end

--------------------------------------------- 预览输出路由到轨道 ---------------------------------------------

local preview_route_enable = reaper.GetExtState(EXT_SECTION, "preview_route_enable") == "1"
local preview_route_name   = reaper.GetExtState(EXT_SECTION, "preview_route_name")
if not preview_route_name or preview_route_name == "" then preview_route_name = "Soundmole Preview" end
local preview_route_mode   = reaper.GetExtState(EXT_SECTION, "preview_route_mode")
if preview_route_mode ~= "auto" and preview_route_mode ~= "named" and preview_route_mode ~= "selected" then
  preview_route_mode = "auto"
end
local preview_out_to_track = reaper.GetExtState(EXT_SECTION, "preview_out_to_track") ~= "0" -- 默认经轨道，1=经轨道 0=硬件输出
local preview_output_chan  = tonumber(reaper.GetExtState(EXT_SECTION, "preview_output_chan")) or 0 -- 默认1/2 (I_OUTCHAN: 低10位=物理输出起始通道，1024位(1<<10)为Mono标志)

-- 找到最上方的同名轨道
function FindTopmostTrackByName(name)
  if not name or name == "" then return nil end
  local cnt = reaper.CountTracks(0)
  for i = 0, cnt - 1 do
    local tr = reaper.GetTrack(0, i)
    local _, tr_name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
    if tr_name == name then return tr end
  end
  return nil
end

function FindFirstSelectedTrack()
  local cnt = reaper.CountTracks(0)
  for i = 0, cnt - 1 do
    local tr = reaper.GetTrack(0, i)
    if reaper.IsTrackSelected(tr) then return tr end
  end
  return nil
end

-- 显示标签, 通道/Mono
function FormatChanLabel(chan)
  local n = chan & 1023
  if (chan & 1024) == 0 then
    return string.format("Channel %d/%d", n + 1, n + 2)
  else
    return string.format("Channel %d", n + 1)
  end
end

function ApplyPreviewOutputTrack(preview)
  if not preview or not preview_route_enable then return end

  if preview_out_to_track then
    if not reaper.CF_Preview_SetOutputTrack then return end
    local target = nil
    if preview_route_mode == "selected" then
      target = FindFirstSelectedTrack()
    elseif preview_route_mode == "named" then
      target = FindTopmostTrackByName(preview_route_name)
    else
      target = FindFirstSelectedTrack() or FindTopmostTrackByName(preview_route_name)
    end
    if target then
      local proj = reaper.EnumProjects(-1, "")
      reaper.CF_Preview_SetOutputTrack(preview, proj, target)
    end
  else
    -- 硬件输出
    if reaper.CF_Preview_SetValue then
      reaper.CF_Preview_SetValue(preview, "I_OUTCHAN", preview_output_chan)
    end
  end
end

--- 设置面板UI
function RenderPreviewRouteSettingsUI(ctx)
  -- reaper.ImGui_SeparatorText(ctx, "Preview Routing")
  -- 预览路由开关
  local changed_enable, new_enable = reaper.ImGui_Checkbox(ctx, "Enable preview routing", preview_route_enable)
  if changed_enable then
    preview_route_enable = new_enable
    reaper.SetExtState(EXT_SECTION, "preview_route_enable", new_enable and "1" or "0", true)
  end

  -- 输出目标，硬件 / 经轨道
  reaper.ImGui_Text(ctx, "Output target:")
  local changed_hw = reaper.ImGui_RadioButton(ctx, "Hardware output", not preview_out_to_track)
  if changed_hw then
    preview_out_to_track = false
    reaper.SetExtState(EXT_SECTION, "preview_out_to_track", "0", true)
  end
  reaper.ImGui_SameLine(ctx)
  local changed_tr = reaper.ImGui_RadioButton(ctx, "Through track", preview_out_to_track)
  if changed_tr then
    preview_out_to_track = true
    reaper.SetExtState(EXT_SECTION, "preview_out_to_track", "1", true)
  end

  -- 硬件输出设置
  reaper.ImGui_BeginDisabled(ctx, preview_out_to_track)
  reaper.ImGui_Text(ctx, "Hardware channels:")
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_SetNextItemWidth(ctx, 130)
  if reaper.ImGui_BeginCombo(ctx, "##preview_hw_chan", FormatChanLabel(preview_output_chan)) then
    -- Mono 开关，切换 bit 10
    local is_mono = (preview_output_chan & 1024) ~= 0
    local mono_changed, mono_val = reaper.ImGui_Checkbox(ctx, "Mono", is_mono)
    if mono_changed then
      if mono_val then
        preview_output_chan = (preview_output_chan | 1024)
      else
        preview_output_chan = (preview_output_chan & ~1024)
      end
      reaper.SetExtState(EXT_SECTION, "preview_output_chan", tostring(preview_output_chan), true)
    end

    reaper.ImGui_Separator(ctx)
    local chan_base   = preview_output_chan & 1023
    local mono_flag   = (preview_output_chan & 1024)
    local skip        = (mono_flag == 0) and 2 or 1
    local num_out     = reaper.GetNumAudioOutputs() or 2
    for i = 0, num_out - 1, skip do
      local sel = (chan_base == i)
      if reaper.ImGui_Selectable(ctx, FormatChanLabel(i | mono_flag), sel) then
        preview_output_chan = (i | mono_flag)
        reaper.SetExtState(EXT_SECTION, "preview_output_chan", tostring(preview_output_chan), true)
      end
    end
    reaper.ImGui_EndCombo(ctx)
  end
  reaper.ImGui_EndDisabled(ctx)

  -- 经轨道
  reaper.ImGui_BeginDisabled(ctx, not preview_out_to_track)
  reaper.ImGui_Text(ctx, "Routing mode:")
  local modes = { "Auto: first selected, else named", "Named track only", "First selected track only" }
  local map   = { "auto", "named", "selected" }
  local cur_i = (preview_route_mode == "named") and 2 or (preview_route_mode == "selected") and 3 or 1

  for i = 1, 3 do
    if i > 1 then reaper.ImGui_SameLine(ctx) end
    local changed = reaper.ImGui_RadioButton(ctx, modes[i], cur_i == i)
    if changed then
      cur_i = i
      preview_route_mode = map[i]
      reaper.SetExtState(EXT_SECTION, "preview_route_mode", preview_route_mode, true)
    end
  end

  reaper.ImGui_Text(ctx, "Named track:")
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_SetNextItemWidth(ctx, -65)
  local changed_name, new_name = reaper.ImGui_InputText(ctx, "##preview_route_name", preview_route_name or "")
  if changed_name and new_name ~= nil then
    preview_route_name = new_name
    reaper.SetExtState(EXT_SECTION, "preview_route_name", preview_route_name or "", true)
  end
  reaper.ImGui_SameLine(ctx)
  HelpMarker("If multiple tracks share the same name, the topmost one is used.")
  reaper.ImGui_EndDisabled(ctx)
end

--------------------------------------------- 播放控制按钮 ---------------------------------------------

-- 文本上下偏移或文本居中
function DrawTextVOffset(ctx, text, col, dy)
  dy = dy or 0
  local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
  local x, y      = reaper.ImGui_GetCursorScreenPos(ctx)
  local line_h    = reaper.ImGui_GetTextLineHeight(ctx)
  local font_sz   = reaper.ImGui_GetFontSize(ctx)
  local tw, _     = reaper.ImGui_CalcTextSize(ctx, text)

  reaper.ImGui_DrawList_AddText(
    draw_list, x, y + (line_h - font_sz) * 0.5 + dy,
    col or reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Text()), text
  )

  reaper.ImGui_Dummy(ctx, tw, line_h)
end

function UI_PlayIconTrigger_Play(ctx)
  reaper.ImGui_PushFont(ctx, fonts.icon, 16)
  local play_label = '\u{0033}'
  local px, py = reaper.ImGui_GetCursorScreenPos(ctx)
  local tw, th = reaper.ImGui_CalcTextSize(ctx, play_label)

  local hovered = reaper.ImGui_IsMouseHoveringRect(ctx, px, py, px + tw, py + th, true)
  local active  = hovered and reaper.ImGui_IsMouseDown(ctx, 0)
  local clicked = hovered and reaper.ImGui_IsMouseClicked(ctx, 0)

  local col_normal  = (colors and colors.text) or 0xFFFFFFFF
  local col_hovered = (colors and colors.accent) or 0xFFCC66FF
  local col_active  = (colors and colors.accent_active) or col_hovered
  local col = hovered and (active and col_active or col_hovered) or col_normal

  -- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), col)
  -- reaper.ImGui_Text(ctx, play_label)
  -- reaper.ImGui_PopStyleColor(ctx)
  DrawTextVOffset(ctx, play_label, col, 4)

  if hovered then
    reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
  end
  reaper.ImGui_PopFont(ctx)

  if clicked then
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
        ApplyPreviewOutputTrack(playing_preview)
        reaper.CF_Preview_Play(playing_preview)
        is_paused = false
        paused_position = 0
        wf_play_start_time = os.clock()
        wf_play_start_cursor = Wave.play_cursor or 0
      end

    elseif type(selected_row) == "number" and selected_row > 0 and type(_G.current_display_list) == "table" and _G.current_display_list[selected_row] then
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
end

function UI_PlayIconTrigger_Pause(ctx)
  reaper.ImGui_SameLine(ctx, nil, 10)
  local highlight_resume = (is_paused and playing_source) and true or false
  reaper.ImGui_PushFont(ctx, fonts.icon, 16)
  local pause_label = '\u{0034}'

  local px, py = reaper.ImGui_GetCursorScreenPos(ctx)
  local tw, th = reaper.ImGui_CalcTextSize(ctx, pause_label)

  local hovered = reaper.ImGui_IsMouseHoveringRect(ctx, px, py, px + tw, py + th, true)
  local active  = hovered and reaper.ImGui_IsMouseDown(ctx, 0)
  local clicked = hovered and reaper.ImGui_IsMouseClicked(ctx, 0)

  local col_resume  = 0x2ee72eff
  local col_normal  = highlight_resume and col_resume or ((colors and colors.text) or 0xFFFFFFFF)
  local col_hovered = highlight_resume and col_resume or ((colors and colors.accent) or 0xFFCC66FF)
  local col_active  = highlight_resume and col_resume or (colors and colors.accent_active) or col_hovered
  local col = hovered and (active and col_active or col_hovered) or col_normal

  -- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), col)
  -- reaper.ImGui_Text(ctx, pause_label)
  -- reaper.ImGui_PopStyleColor(ctx)
  DrawTextVOffset(ctx, pause_label, col, 4)

  if hovered then
    reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
  end
  reaper.ImGui_PopFont(ctx)

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
        ApplyPreviewOutputTrack(playing_preview)
        reaper.CF_Preview_Play(playing_preview)
        wf_play_start_time = os.clock()
        wf_play_start_cursor = paused_position
        is_paused = false
      end
    end
  end
end

function UI_PlayIconTrigger_Stop(ctx)
  reaper.ImGui_SameLine(ctx, nil, 10)
  reaper.ImGui_PushFont(ctx, fonts.icon, 16)
  local play_label = '\u{0035}'
  local px, py = reaper.ImGui_GetCursorScreenPos(ctx)
  local tw, th = reaper.ImGui_CalcTextSize(ctx, play_label)

  local hovered = reaper.ImGui_IsMouseHoveringRect(ctx, px, py, px + tw, py + th, true)
  local active  = hovered and reaper.ImGui_IsMouseDown(ctx, 0)
  local clicked = hovered and reaper.ImGui_IsMouseClicked(ctx, 0)

  local col_normal  = (colors and colors.text) or 0xFFFFFFFF
  local col_hovered = (colors and colors.accent) or 0xFFCC66FF
  local col_active  = (colors and colors.accent_active) or col_hovered
  local col = hovered and (active and col_active or col_hovered) or col_normal

  -- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), col)
  -- reaper.ImGui_Text(ctx, play_label)
  -- reaper.ImGui_PopStyleColor(ctx)
  DrawTextVOffset(ctx, play_label, col, 4)

  if hovered then
    reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
  end
  reaper.ImGui_PopFont(ctx)

  if clicked then
    StopPreview()
    is_paused = false
    paused_position = 0

    -- 强制播放光标复位
    if last_play_cursor_before_play then
      Wave.play_cursor = last_play_cursor_before_play
    end
  end
end

function UI_PlayIconTrigger_Prev(ctx)
  reaper.ImGui_SameLine(ctx, nil, 10)
  reaper.ImGui_PushFont(ctx, fonts.icon, 16)
  local play_label = '\u{0030}'
  local px, py = reaper.ImGui_GetCursorScreenPos(ctx)
  local tw, th = reaper.ImGui_CalcTextSize(ctx, play_label)

  local hovered = reaper.ImGui_IsMouseHoveringRect(ctx, px, py, px + tw, py + th, true)
  local active  = hovered and reaper.ImGui_IsMouseDown(ctx, 0)
  local clicked = hovered and reaper.ImGui_IsMouseClicked(ctx, 0)

  local col_normal  = (colors and colors.text) or 0xFFFFFFFF
  local col_hovered = (colors and colors.accent) or 0xFFCC66FF
  local col_active  = (colors and colors.accent_active) or col_hovered
  local col = hovered and (active and col_active or col_hovered) or col_normal

  -- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), col)
  -- reaper.ImGui_Text(ctx, play_label)
  -- reaper.ImGui_PopStyleColor(ctx)
  DrawTextVOffset(ctx, play_label, col, 4)

  if hovered then
    reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
  end
  reaper.ImGui_PopFont(ctx)

  if clicked then
    local list = filtered_list or _G.current_display_list or {}
    local count = #list
    if count == 0 then return end

    local cur = (selected_row and selected_row >= 1 and selected_row <= count) and selected_row or (count + 1)
    local prev_idx = (cur > 1) and (cur - 1) or count
    local info = list[prev_idx]
    if not info then return end

    auto_play_next_pending    = info
    _G.auto_play_next_pending = info

    selected_row = prev_idx
    _G.scroll_target = 0.5
    is_paused = false
    paused_position = 0
  end
end

function UI_PlayIconTrigger_Next(ctx)
  reaper.ImGui_SameLine(ctx, nil, 10)
  reaper.ImGui_PushFont(ctx, fonts.icon, 16)
  local play_label = '\u{0038}'
  local px, py = reaper.ImGui_GetCursorScreenPos(ctx)
  local tw, th = reaper.ImGui_CalcTextSize(ctx, play_label)

  local hovered = reaper.ImGui_IsMouseHoveringRect(ctx, px, py, px + tw, py + th, true)
  local active  = hovered and reaper.ImGui_IsMouseDown(ctx, 0)
  local clicked = hovered and reaper.ImGui_IsMouseClicked(ctx, 0)

  local col_normal  = (colors and colors.text) or 0xFFFFFFFF
  local col_hovered = (colors and colors.accent) or 0xFFCC66FF
  local col_active  = (colors and colors.accent_active) or col_hovered
  local col = hovered and (active and col_active or col_hovered) or col_normal

  -- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), col)
  -- reaper.ImGui_Text(ctx, play_label)
  -- reaper.ImGui_PopStyleColor(ctx)
  DrawTextVOffset(ctx, play_label, col, 4)

  if hovered then
    reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
  end
  reaper.ImGui_PopFont(ctx)

  if clicked then
    local list = filtered_list or _G.current_display_list or {}
    local count = #list
    if count == 0 then return end

    local cur = (selected_row and selected_row >= 1 and selected_row <= count) and selected_row or 0
    local next_idx = (cur < count) and (cur + 1) or 1
    local info = list[next_idx]
    if not info then return end

    auto_play_next_pending    = info
    _G.auto_play_next_pending = info

    selected_row = next_idx
    _G.scroll_target = 0.5
    is_paused = false
    paused_position = 0
  end
end

function UI_PlayIconTrigger_Rand(ctx)
  reaper.ImGui_SameLine(ctx, nil, 10)
  reaper.ImGui_PushFont(ctx, fonts.icon, 16)
  local play_label = '\u{004F}'
  local px, py = reaper.ImGui_GetCursorScreenPos(ctx)
  local tw, th = reaper.ImGui_CalcTextSize(ctx, play_label)

  local hovered = reaper.ImGui_IsMouseHoveringRect(ctx, px, py, px + tw, py + th, true)
  local active  = hovered and reaper.ImGui_IsMouseDown(ctx, 0)
  local clicked = hovered and reaper.ImGui_IsMouseClicked(ctx, 0)

  local col_normal  = (colors and colors.text) or 0xFFFFFFFF
  local col_hovered = (colors and colors.accent) or 0xFFCC66FF
  local col_active  = (colors and colors.accent_active) or col_hovered
  local col = hovered and (active and col_active or col_hovered) or col_normal

  -- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), col)
  -- reaper.ImGui_Text(ctx, play_label)
  -- reaper.ImGui_PopStyleColor(ctx)
  DrawTextVOffset(ctx, play_label, col, 4)

  if hovered then
    reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
  end
  reaper.ImGui_PopFont(ctx)

  if clicked then
    local list = filtered_list or _G.current_display_list or {}
    local count = #list
    if count == 0 then
      return
    end

    local rand_idx = math.random(1, count)
    selected_row = rand_idx

    local info = list[rand_idx]
    if info then
      PlayFromCursor(info)
      is_paused, paused_position = false, 0
    end

    _G.scroll_request_index = rand_idx -- 目标索引
    _G.scroll_request_align = 0.5      -- 居中
  end
end

function UI_PlayIconTrigger_Loop(ctx)
  reaper.ImGui_SameLine(ctx, nil, 10)

  local highlight_loop = loop_enabled and true or false

  reaper.ImGui_PushFont(ctx, fonts.icon, 16)
  local loop_label = '\u{003C}'

  local px, py = reaper.ImGui_GetCursorScreenPos(ctx)
  local tw, th = reaper.ImGui_CalcTextSize(ctx, loop_label)
  local hovered = reaper.ImGui_IsMouseHoveringRect(ctx, px, py, px + tw, py + th, true)
  local active  = hovered and reaper.ImGui_IsMouseDown(ctx, 0)
  local clicked = hovered and reaper.ImGui_IsMouseClicked(ctx, 0)

  local col_on      = 0x2ee72eff
  local col_normal  = highlight_loop and col_on or ((colors and colors.text) or 0xFFFFFFFF)
  local col_hovered = highlight_loop and col_on or ((colors and colors.accent) or 0xFFCC66FF)
  local col_active  = highlight_loop and col_on or (colors and colors.accent_active) or col_hovered
  local col         = hovered and (active and col_active or col_hovered) or col_normal

  DrawTextVOffset(ctx, loop_label, col, 4)

  if hovered then
    reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
  end
  reaper.ImGui_PopFont(ctx)

  if clicked then
    loop_enabled = not loop_enabled

    if playing_preview then
      if type(RestartPreviewWithParams) == "function" then
        RestartPreviewWithParams()
      elseif reaper.CF_Preview_SetValue then
        reaper.CF_Preview_SetValue(playing_preview, "B_LOOP", loop_enabled and 1 or 0)
      end
    end
  end
end

-- 路由按钮与下拉菜单
function DrawPreviewRouteMenu(ctx)
  reaper.ImGui_SameLine(ctx, nil, 10)
  reaper.ImGui_PushFont(ctx, fonts.icon, 16)
  local play_label = '\u{0048}'
  local px, py = reaper.ImGui_GetCursorScreenPos(ctx)
  local tw, th = reaper.ImGui_CalcTextSize(ctx, play_label)

  local hovered = reaper.ImGui_IsMouseHoveringRect(ctx, px, py, px + tw, py + th, true)
  local active  = hovered and reaper.ImGui_IsMouseDown(ctx, 0)
  local clicked = hovered and reaper.ImGui_IsMouseClicked(ctx, 0)

  local col_normal  = (colors and colors.text) or 0xFFFFFFFF
  local col_hovered = (colors and colors.accent) or 0xFFCC66FF
  local col_active  = (colors and colors.accent_active) or col_hovered
  local col = hovered and (active and col_active or col_hovered) or col_normal

  DrawTextVOffset(ctx, play_label, col, 4)

  if hovered then
    reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
  end
  reaper.ImGui_PopFont(ctx)

  -- 触发按钮
  -- if reaper.ImGui_Button(ctx, "Routing") then
  --   reaper.ImGui_OpenPopup(ctx, "##preview_route_menu")
  -- end

  if clicked then
    reaper.ImGui_OpenPopup(ctx, "##preview_route_menu")
  end

  if reaper.ImGui_BeginPopup(ctx, "##preview_route_menu") then
    if preview_out_to_track == nil then
      preview_out_to_track = reaper.GetExtState(EXT_SECTION, "preview_out_to_track") ~= "0" -- 默认走轨道
    end
    if preview_output_chan == nil then
      preview_output_chan = tonumber(reaper.GetExtState(EXT_SECTION, "preview_output_chan")) or 0 -- 低10位起始通道，1024位为Mono
    end

    -- 激活勾选
    local changed_enable, new_enable = reaper.ImGui_Checkbox(ctx, "Enable preview routing", preview_route_enable)
    if changed_enable then
      preview_route_enable = new_enable
      reaper.SetExtState(EXT_SECTION, "preview_route_enable", new_enable and "1" or "0", true)
    end

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, "Output target:")
    local changed_hw = reaper.ImGui_RadioButton(ctx, "Hardware output", not preview_out_to_track)
    if changed_hw then
      preview_out_to_track = false
      reaper.SetExtState(EXT_SECTION, "preview_out_to_track", "0", true)
    end
    reaper.ImGui_SameLine(ctx)
    local changed_tr = reaper.ImGui_RadioButton(ctx, "Through track", preview_out_to_track)
    if changed_tr then
      preview_out_to_track = true
      reaper.SetExtState(EXT_SECTION, "preview_out_to_track", "1", true)
    end

    -- 硬件输出
    reaper.ImGui_BeginDisabled(ctx, preview_out_to_track)
    reaper.ImGui_Text(ctx, "Hardware channels:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 130)
    if reaper.ImGui_BeginCombo(ctx, "##preview_hw_chan", FormatChanLabel(preview_output_chan)) then
      local is_mono = (preview_output_chan & 1024) ~= 0
      local mono_changed, mono_val = reaper.ImGui_Checkbox(ctx, "Mono", is_mono)
      if mono_changed then
        if mono_val then
          preview_output_chan = preview_output_chan | 1024
        else
          preview_output_chan = preview_output_chan & 1023
        end
        reaper.SetExtState(EXT_SECTION, "preview_output_chan", tostring(preview_output_chan), true)
      end

      reaper.ImGui_Separator(ctx)
      local mono_flag = preview_output_chan & 1024
      local skip      = (mono_flag == 0) and 2 or 1
      local num_out   = reaper.GetNumAudioOutputs() or 2
      local cur_base  = preview_output_chan & 1023

      for i = 0, num_out - 1, skip do
        local sel = (cur_base == i)
        if reaper.ImGui_Selectable(ctx, FormatChanLabel(i | mono_flag), sel) then
          preview_output_chan = (i | mono_flag)
          reaper.SetExtState(EXT_SECTION, "preview_output_chan", tostring(preview_output_chan), true)
        end
      end
      reaper.ImGui_EndCombo(ctx)
    end
    reaper.ImGui_EndDisabled(ctx)

    -- 路由模式
    reaper.ImGui_BeginDisabled(ctx, not preview_out_to_track)
    reaper.ImGui_Text(ctx, "Routing mode:")
    local modes = { "Auto: first selected, else named", "Named track only", "First selected track only" }
    local map   = { "auto", "named", "selected" }
    local cur_i = (preview_route_mode == "named") and 2 or (preview_route_mode == "selected") and 3 or 1

    for i = 1, 3 do
      if reaper.ImGui_RadioButton(ctx, modes[i], cur_i == i) then
        cur_i = i
        preview_route_mode = map[i]
        reaper.SetExtState(EXT_SECTION, "preview_route_mode", preview_route_mode, true)
      end
    end

    -- 仅在 Named track only 时显示命名轨道输入框
    if preview_route_mode == "named" then
      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, "Named track:")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_SetNextItemWidth(ctx, 150)
      local changed_name, new_name = reaper.ImGui_InputText(ctx, "##preview_route_name", preview_route_name or "")
      if changed_name and new_name ~= nil then
        preview_route_name = new_name
        reaper.SetExtState(EXT_SECTION, "preview_route_name", preview_route_name or "", true)
      end
    end
    reaper.ImGui_EndDisabled(ctx)

    reaper.ImGui_EndPopup(ctx)
  end
end

-- 列表文件居中备用函数，将任意行 idx 请求滚动到可视区并对齐
function SM_RequestCenterRow(idx, align)
  _G.scroll_request_index = idx
  _G.scroll_request_align = align or 0.5 -- 0 顶部, 0.5 居中, 1 底部
end

-- 跳到搜索命中的第一个结果并居中
-- selected_row = hit_index
-- SM_RequestCenterRow(hit_index, 0.5)

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
    local filter_w = 400 -- 输入框宽度

    -- 标题栏
    reaper.ImGui_BeginGroup(ctx)
    -- reaper.ImGui_PushFont(ctx, fonts.title, 26)
    reaper.ImGui_PushFont(ctx, fonts.odrf, 24)
    reaper.ImGui_SameLine(ctx, nil, 10)
    -- reaper.ImGui_Text(ctx, 'Soundmole')
    DrawTextVOffset(ctx, 'Soundmole', nil, 15) -- 文字居中，偏移设置
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

    reaper.ImGui_Text(ctx, '') -- 换行占位符
    reaper.ImGui_SameLine(ctx, nil, 0)
    reaper.ImGui_Text(ctx, 'Thesaurus:')
    reaper.ImGui_SameLine(ctx, nil, 60)
    local changed_synonyms, new_use_synonyms = reaper.ImGui_Checkbox(ctx, "##Synonyms", use_synonyms)
    if changed_synonyms then
      use_synonyms = new_use_synonyms
      -- 同义词勾选时强制重建，否则不工作
      static.filtered_list_map    = {}
      static.last_filter_text_map = {}
    end
    reaper.ImGui_EndGroup(ctx)

    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_BeginGroup(ctx)
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
    if reaper.ImGui_Button(ctx, "Clear", 90, 56) then
      reaper.ImGui_TextFilter_Set(filename_filter, "")

      _G.commit_filter_text = "" -- 立即清空生效查询（Enter模式）
      -- 清除临时搜索字段，UCS隐式搜索临时关键词
      -- active_saved_search = nil
      -- temp_search_field, temp_search_keyword = nil
      -- temp_ucs_cat_keyword, temp_ucs_sub_keyword = nil, nil

      -- static.filtered_list_map    = {}
      -- static.last_filter_text_map = {}
      -- selected_row = nil
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
    if reaper.ImGui_Button(ctx, "Rescan", 90, 56) then
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
    if reaper.ImGui_Button(ctx, "Restore All", 90, 56) then
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
    if reaper.ImGui_Button(ctx, "Same Folder", 90, 56) then
      collect_mode = COLLECT_MODE_SAMEFOLDER
      tree_state.cur_path = normalize_path(same_folder, true)
      RefreshFolderFiles(same_folder)
      reaper.SetExtState(EXT_SECTION, "collect_mode", tostring(COLLECT_MODE_SAMEFOLDER), true)
      reaper.SetExtState(EXT_SECTION, "cur_samefolder_path", tree_state.cur_path or "", true)
    end

    if reaper.ImGui_IsItemHovered(ctx) then
      reaper.ImGui_BeginTooltip(ctx)
      reaper.ImGui_Text(ctx, "Click to jump to this folder and list its audio files.")
      reaper.ImGui_EndTooltip(ctx)
    end

    -- 快速预览文件夹
    reaper.ImGui_SameLine(ctx, nil, 10)
    if reaper.ImGui_Button(ctx, "Pick Folder", 90, 56) then
      local init = preview_folder_input
      if not init or init == "" then
        if same_folder and same_folder ~= "" then
          init = same_folder
        elseif tree_state and tree_state.cur_path and tree_state.cur_path ~= "" then
          init = tree_state.cur_path
        else
          init = reaper.GetResourcePath() -- 默认给个 REAPER 资源目录
        end
      end
      preview_folder_input = normalize_path(init, true)
      reaper.ImGui_OpenPopup(ctx, "##preview_folder_popup")
    end

    -- Play History 最近播放按钮
    if not show_peektree_recent then
      reaper.ImGui_SameLine(ctx, nil, 10)
      if reaper.ImGui_Button(ctx, "Play History", 90, 56) then
        LoadRecentPlayed()
        collect_mode= COLLECT_MODE_PLAY_HISTORY

        -- 清空跨模式残留
        file_select_start, file_select_end, selected_row = nil, nil, nil
        files_idx_cache = nil
        CollectFiles()

        local static = _G._soundmole_static or {}
        _G._soundmole_static = static
        static.filtered_list_map, static.last_filter_text_map = {}, {}
      end
      if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Show Recently Played list in the table")
      end
    end

    if reopen_preview_popup then
      if preview_popup_pos_x and preview_popup_pos_y then
        reaper.ImGui_SetNextWindowPos(ctx, preview_popup_pos_x, preview_popup_pos_y, reaper.ImGui_Cond_Appearing(), 0, 0)
      end
      reaper.ImGui_OpenPopup(ctx, "##preview_folder_popup")
      reopen_preview_popup = false
    end

    if reaper.ImGui_BeginPopup(ctx, "##preview_folder_popup") then
      if reaper.ImGui_IsWindowAppearing(ctx) then
        preview_popup_pos_x, preview_popup_pos_y = reaper.ImGui_GetWindowPos(ctx)
      end
      reaper.ImGui_Text(ctx, "Type or pick a folder to preview:")
      reaper.ImGui_PushItemWidth(ctx, 480)

      local changed, new_str = reaper.ImGui_InputText(ctx, "##preview_folder_input", preview_folder_input or "")
      if changed then
        preview_folder_input = new_str
      end
      reaper.ImGui_PopItemWidth(ctx)

      reaper.ImGui_SameLine(ctx, nil, 10)
      if reaper.ImGui_Button(ctx, "Select...", 80, 26) then
        local picked = BrowseForFolder(preview_folder_input)
        if picked and picked ~= "" then
          preview_folder_input = normalize_path(picked, true)
        end
        reopen_preview_popup = true
      end

      reaper.ImGui_Separator(ctx)
      if reaper.ImGui_Button(ctx, "OK", 80, 26) then
        local path = (preview_folder_input or ""):gsub("%s+$", "")
        if path ~= "" then
          collect_mode        = COLLECT_MODE_SAMEFOLDER
          tree_state.cur_path = normalize_path(path, true)
          RefreshFolderFiles(tree_state.cur_path)
          reaper.SetExtState(EXT_SECTION, "collect_mode", tostring(COLLECT_MODE_SAMEFOLDER), true)
          reaper.SetExtState(EXT_SECTION, "cur_samefolder_path", tree_state.cur_path or "", true)

          file_select_start, file_select_end, selected_row = nil, nil, nil
          files_idx_cache = nil
          CollectFiles()

          local static = _G._soundmole_static or {}
          _G._soundmole_static = static
          static.filtered_list_map, static.last_filter_text_map = {}, {}
          reaper.ImGui_CloseCurrentPopup(ctx)
        end
      end
      reaper.ImGui_SameLine(ctx, nil, 10)
      if reaper.ImGui_Button(ctx, "Cancel", 80, 26) then
        reaper.ImGui_CloseCurrentPopup(ctx)
      end

      reaper.ImGui_EndPopup(ctx)
    end

    -- 创建数据库按钮
    -- reaper.ImGui_SameLine(ctx, nil, 10)
    -- if reaper.ImGui_Button(ctx, "Database##scan_folder_top", 80, 46) then -- Select Folder and Scan Audio
    --   local rv, folder = reaper.JS_Dialog_BrowseForFolder("Choose folder to scan audio files:", "")
    --   if rv == 1 and folder and folder ~= "" then
    --     folder = normalize_path(folder, true)
    --     local filelist = ScanAllAudioFiles(folder)
    --     local db_dir = script_path .. "SoundmoleDB"
    --     EnsureCacheDir(db_dir)
    --     -- 获取下一个可用编号
    --     local db_index = GetNextMediaDBIndex(db_dir) -- 00~FF
    --     local dbfile = string.format("%s.MoleFileList", db_index) -- 只有文件名
    --     local dbpath = normalize_path(db_dir, true) .. dbfile     -- 全路径
    --     local f = io.open(dbpath, "wb") if f then f:close() end
    --     AddPathToDBFile(dbpath, folder)
    --     db_build_task = {
    --       filelist = filelist,
    --       dbfile = dbpath,
    --       idx = 1,
    --       total = #filelist,
    --       finished = false,
    --       root_path  = folder,
    --     }
    --   end
    -- end

    reaper.ImGui_EndGroup(ctx)

    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_BeginGroup(ctx)

    -- 创建数据库图标
    reaper.ImGui_SameLine(ctx, nil, 0)
    local avail = reaper.ImGui_GetContentRegionAvail(ctx) -- 计算可用宽度
    local txt_w, txt_h = reaper.ImGui_CalcTextSize(ctx, "00") -- 文字尺寸
    local cb_w = txt_w + txt_h + 16 -- 文字宽度+勾选框大小+间距

    -- 如果可用宽度足够，把光标推到右侧
    if avail > cb_w then
      reaper.ImGui_Dummy(ctx, avail - cb_w, 0)
      reaper.ImGui_SameLine(ctx, nil, 0)
    end

    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_PushFont(ctx, fonts.icon, 16)
    local gear_label = '\u{0059}'
    local px, py = reaper.ImGui_GetCursorScreenPos(ctx)
    local tw, th = reaper.ImGui_CalcTextSize(ctx, gear_label)

    local hovered = reaper.ImGui_IsMouseHoveringRect(ctx, px, py, px + tw, py + th, true)
    local active  = hovered and reaper.ImGui_IsMouseDown(ctx, 0)
    local clicked = hovered and reaper.ImGui_IsMouseClicked(ctx, 0)

    local col_normal  = (colors and colors.text) or 0xFFFFFFFF
    local col_hovered = (colors and colors.accent) or 0xFFCC66FF
    local col_active  = (colors and colors.accent_active) or col_hovered
    local col = hovered and (active and col_active or col_hovered) or col_normal

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), col)
    reaper.ImGui_Text(ctx, gear_label)
    reaper.ImGui_PopStyleColor(ctx)

    if hovered then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
    end
    if clicked then
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
    reaper.ImGui_PopFont(ctx)
    -- 鼠标停靠提示
    if reaper.ImGui_IsItemHovered(ctx) then
      reaper.ImGui_BeginTooltip(ctx)
      reaper.ImGui_Text(ctx, 'Creating a database. Please browse and select a folder containing audio files.')
      reaper.ImGui_EndTooltip(ctx)
    end

    -- 设置弹窗图标
    reaper.ImGui_SameLine(ctx, nil, 0)
    local avail = reaper.ImGui_GetContentRegionAvail(ctx) -- 计算可用宽度
    local txt_w, txt_h = reaper.ImGui_CalcTextSize(ctx, "0000") -- 文字尺寸
    local cb_w = txt_w + txt_h + 16 -- 文字宽度+勾选框大小+间距

    -- 如果可用宽度足够，把光标推到右侧
    if avail > cb_w then
      reaper.ImGui_Dummy(ctx, avail - cb_w, 0)
      reaper.ImGui_SameLine(ctx, nil, 0)
    end

    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_PushFont(ctx, fonts.icon, 16)
    local gear_label = '\u{0047}'
    local px, py = reaper.ImGui_GetCursorScreenPos(ctx)
    local tw, th = reaper.ImGui_CalcTextSize(ctx, gear_label)

    local hovered = reaper.ImGui_IsMouseHoveringRect(ctx, px, py, px + tw, py + th, true)
    local active  = hovered and reaper.ImGui_IsMouseDown(ctx, 0)
    local clicked = hovered and reaper.ImGui_IsMouseClicked(ctx, 0)

    local col_normal  = (colors and colors.text) or 0xFFFFFFFF
    local col_hovered = (colors and colors.accent) or 0xFFCC66FF
    local col_active  = (colors and colors.accent_active) or col_hovered
    local col = hovered and (active and col_active or col_hovered) or col_normal

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), col)
    reaper.ImGui_Text(ctx, gear_label)
    reaper.ImGui_PopStyleColor(ctx)

    if hovered then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
    end
    if clicked then
      settings_window_open = true
      reaper.SetExtState(EXT_SECTION, "popup_settings_open", tostring(settings_window_open), true)
    end
    reaper.ImGui_PopFont(ctx)
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
          font_size = SnapFontSize(font_size)
          if preview_fonts[font_size] then
            reaper.ImGui_PushFont(ctx, fonts.sans_serif, font_size)
          end
          if wheel ~= 0 and ctrl and reaper.ImGui_IsWindowHovered(ctx) then
            local idx = FindFontIndex(font_size)
            idx = idx + (wheel > 0 and 1 or -1)
            idx = math.max(1, math.min(#preview_font_sizes, idx))
            font_size = preview_font_sizes[idx]
            reaper.SetExtState(EXT_SECTION, EXT_KEY_FONT_SIZE, tostring(font_size), true)
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
              ResetCollectionGuide() -- 重置导线度量
              for _, drv in ipairs(drive_cache or {}) do
                draw_tree(drv, drv, 0)
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
            ResetCollectionGuide() -- 重置导线度量
            for _, sc in ipairs(folder_shortcuts or {}) do
              draw_shortcut_tree(sc, nil, 0)
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

          -- 镜像官方快捷键方式
          if mirror_folder_shortcuts then
            local sc_folders = list_reaper_shortcut_folders()
            if #sc_folders == 0 then
              -- 什么都不做
            else
              if not shortcut_mirror_nodes_inited then
                expanded_paths = expanded_paths or {}
                if tree_state.cur_path and tree_state.cur_path ~= "" then
                  local p = tree_state.cur_path:gsub("[/\\]+$", "")
                  while p and p ~= "" do
                    expanded_paths[p] = true
                    local parent = p:match("^(.*)[/\\][^/\\]+$")
                    p = parent
                  end
                end
                shortcut_mirror_nodes_inited = true
              end

              reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), colors.transparent)
              local hdr_flags_sc_mirror = shortcut_mirror_open and reaper.ImGui_TreeNodeFlags_DefaultOpen() or 0
              local is_sc_mirror_open = reaper.ImGui_CollapsingHeader(ctx, "Folder Shortcuts (Mirror)##shortcut_mirror", nil, hdr_flags_sc_mirror)
              shortcut_mirror_open = is_sc_mirror_open
              reaper.ImGui_PopStyleColor(ctx)
              
              if is_sc_mirror_open then
                reaper.ImGui_Indent(ctx, 7)
                ResetCollectionGuide() -- 重置导线度量
                for _, sc in ipairs(sc_folders or {}) do
                  draw_shortcut_tree_mirror(sc, nil, 0)
                end
                reaper.ImGui_Unindent(ctx, 7)
              end
            end
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
            ResetCollectionGuide() -- 重置导线度量
            for i, id in ipairs(root_advanced_folders) do
              local node = advanced_folders[id]
              if node then
                draw_advanced_folder_node(id, tree_state.cur_advanced_folder, 0)
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
                  -- 保护操作，如果正在重建这个 DB，先禁止删除
                  if db_build_task and not db_build_task.finished and db_build_task.dbfile == dbfile then
                    reaper.ShowMessageBox("This database is currently rebuilding.\nPlease stop the task before deleting.", "Cannot Delete", 0)
                  else
                    local filename = dbfile:match("[^/\\]+$")
                    local alias = mediadb_alias[filename] or filename
                    local res = reaper.ShowMessageBox(
                      ("Are you sure you want to delete the database?\nAlias: %s\nFile: %s\n\nThis action cannot be undone."):format(alias, dbfile),
                      "Confirm Delete",
                      4 -- Yes/No
                    )
                    if res == 6 then -- 6 = Yes
                      -- 释放文件占用，Windows 必须先关流
                      if _G._mediadb_stream then
                        MediaDBStreamClose(_G._mediadb_stream)
                        _G._mediadb_stream = nil
                      end

                      -- 真实文件路径
                      local db_dir  = script_path .. "SoundmoleDB"
                      local db_path = normalize_path(db_dir, true) .. dbfile

                      -- 执行删除并检查结果
                      local ok, err = os.remove(db_path)
                      if not ok then
                        reaper.ShowMessageBox(
                          "Failed to delete:\n" .. tostring(db_path) .. "\n\n" .. tostring(err or ""),
                          "Error",
                          0
                        )
                      else
                        -- 清理别名
                        mediadb_alias[filename] = nil
                        SaveMediaDBAlias(EXT_SECTION, mediadb_alias)

                        -- 清理当前选择与缓存并刷新
                        if tree_state.cur_mediadb == dbfile then
                          tree_state.cur_mediadb = ""
                          selected_row = nil
                          files_idx_cache = {}
                        end
                      end
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

          -- REAPER Database
          if mirror_database then
            local reaper_db_list = list_reaper_databases()
            if #reaper_db_list == 0 then
              -- 什么都不做
            else
              reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), colors.transparent)
              local hdr_flags_readb = reaper_db_open and reaper.ImGui_TreeNodeFlags_DefaultOpen() or 0
              local is_readb_open = reaper.ImGui_CollapsingHeader(ctx, "Database (Mirror)##reaperdb", nil, hdr_flags_readb)
              reaper_db_open = is_readb_open
              reaper.ImGui_PopStyleColor(ctx)

              if is_readb_open then
                reaper.ImGui_Indent(ctx, 7)
                for _, it in ipairs(reaper_db_list) do
                  local alias = it.alias
                  local fn    = it.filename
                  local is_sel = (collect_mode == COLLECT_MODE_REAPERDB and tree_state.cur_reaper_db == fn)

                  if reaper.ImGui_Selectable(ctx, alias, is_sel) then
                    collect_mode = COLLECT_MODE_REAPERDB
                    tree_state.cur_reaper_db = fn

                    file_select_start, file_select_end, selected_row = nil, nil, -1
                    files_idx_cache = nil
                    CollectFiles()
                  end
                end

                reaper.ImGui_Unindent(ctx, 7)
              end
            end
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
          if show_peektree_recent then
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
            local btn_w = 24
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

        -- TAB 标签页 Freesound 节点
        if reaper.ImGui_BeginTabItem(ctx, 'Freesound') then
          if FS and type(FS_DrawSidebar)=="function" then
            FS_DrawSidebar(ctx)
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
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableBorderLight(),  0x18539830) -- 列表线/分割线，深灰0xFF404040 透明0x00000000
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableRowBg(),        0xFF0F0F0F) -- 表格行背景色 0xFF0F0F0F
    -- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableRowBgAlt(),     0xFF0F0F0F)
    -- 右侧表格列表, 支持表格排序和冻结首行
    if reaper.ImGui_BeginChild(ctx, "##file_table_child", right_w, child_h, 0) then
      if reaper.ImGui_BeginTable(ctx, "filelist", 19,
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
          reaper.ImGui_TableSetupColumn(ctx, "Key",         reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.KEY)
          reaper.ImGui_TableSetupColumn(ctx, "BPM",         reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.BPM)
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
          reaper.ImGui_TableSetupColumn(ctx, "Key",         reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.KEY)
          reaper.ImGui_TableSetupColumn(ctx, "BPM",         reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.BPM)
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
          reaper.ImGui_TableSetupColumn(ctx, "Key",         reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.KEY)
          reaper.ImGui_TableSetupColumn(ctx, "BPM",         reaper.ImGui_TableColumnFlags_WidthFixed(), 40, TableColumns.BPM)
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
          if #sort_specs > 0 and filtered_list and collect_mode ~= COLLECT_MODE_PLAY_HISTORY then -- 加入播放历史模式，避免被排序
            table.sort(filtered_list, function(a, b)
              for _, spec in ipairs(sort_specs) do
                if spec.user_id == TableColumns.FILENAME then
                  if a.filename ~= b.filename then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return a.filename > b.filename
                    else
                      return a.filename < b.filename
                    end
                  end

                elseif spec.user_id == TableColumns.SIZE then
                  local asize = tonumber(a.size) or 0
                  local bsize = tonumber(b.size) or 0
                  if asize ~= bsize then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return asize > bsize
                    else
                      return asize < bsize
                    end
                  end

                elseif spec.user_id == TableColumns.TYPE then
                  if a.type ~= b.type then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return a.type > b.type
                    else
                      return a.type < b.type
                    end
                  end

                elseif spec.user_id == TableColumns.DATE then -- BWF Origination Date
                  local ad = a.bwf_orig_date or ""
                  local bd = b.bwf_orig_date or ""
                  if ad ~= bd then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return ad > bd
                    else
                      return ad < bd
                    end
                  end

                elseif spec.user_id == TableColumns.GENRE then -- Genre (Items/RPP 模式下按 position)
                  if collect_mode == COLLECT_MODE_ALL_ITEMS or collect_mode == COLLECT_MODE_RPP then
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
                    local ag = a.genre or ""
                    local bg = b.genre or ""
                    if ag ~= bg then
                      if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                        return ag > bg
                      else
                        return ag < bg
                      end
                    end
                  end

                elseif spec.user_id == TableColumns.COMMENT then
                  local ac = a.comment or ""
                  local bc = b.comment or ""
                  if ac ~= bc then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return ac > bc
                    else
                      return ac < bc
                    end
                  end

                elseif spec.user_id == TableColumns.DESCRIPTION then
                  local adesc = a.description or ""
                  local bdesc = b.description or ""
                  if adesc ~= bdesc then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return adesc > bdesc
                    else
                      return adesc < bdesc
                    end
                  end

                elseif spec.user_id == TableColumns.LENGTH then
                  local alen = tonumber(a.length) or 0
                  local blen = tonumber(b.length) or 0
                  if alen ~= blen then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return alen > blen
                    else
                      return alen < blen
                    end
                  end

                elseif spec.user_id == TableColumns.CHANNELS then
                  local ach = tonumber(a.channels) or 0
                  local bch = tonumber(b.channels) or 0
                  if ach ~= bch then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return ach > bch
                    else
                      return ach < bch
                    end
                  end

                elseif spec.user_id == TableColumns.SAMPLERATE then
                  local asr = tonumber(a.samplerate) or 0
                  local bsr = tonumber(b.samplerate) or 0
                  if asr ~= bsr then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return asr > bsr
                    else
                      return asr < bsr
                    end
                  end

                elseif spec.user_id == TableColumns.BITS then
                  local abits = tonumber(a.bits) or 0
                  local bbits = tonumber(b.bits) or 0
                  if abits ~= bbits then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return abits > bbits
                    else
                      return abits < bbits
                    end
                  end

                elseif spec.user_id == TableColumns.KEY then
                  local ak = a.key or ""
                  local bk = b.key or ""
                  if ak ~= bk then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return ak > bk
                    else
                      return ak < bk
                    end
                  end

                elseif spec.user_id == TableColumns.BPM then
                  local abpm = tonumber(a.bpm) or 0
                  local bbpm = tonumber(b.bpm) or 0
                  if abpm ~= bbpm then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return abpm > bbpm
                    else
                      return abpm < bbpm
                    end
                  end

                elseif spec.user_id == TableColumns.CATEGORY then
                  local acat = a.ucs_category or a.category or ""
                  local bcat = b.ucs_category or b.category or ""
                  if acat ~= bcat then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return acat > bcat
                    else
                      return acat < bcat
                    end
                  end

                elseif spec.user_id == TableColumns.SUBCATEGORY then
                  local asub = a.ucs_subcategory or a.subcategory or ""
                  local bsub = b.ucs_subcategory or b.subcategory or ""
                  if asub ~= bsub then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return asub > bsub
                    else
                      return asub < bsub
                    end
                  end

                elseif spec.user_id == TableColumns.CATID then
                  local acid = a.ucs_catid or a.catid or a.cat_id or ""
                  local bcid = b.ucs_catid or b.catid or b.cat_id or ""
                  if acid ~= bcid then
                    if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                      return acid > bcid
                    else
                      return acid < bcid
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
        font_size = SnapFontSize(font_size)
        if preview_fonts[font_size] then
          reaper.ImGui_PushFont(ctx, fonts.sans_serif, font_size)
        end
        if wheel ~= 0 and ctrl and reaper.ImGui_IsWindowHovered(ctx) then
          local idx = FindFontIndex(font_size)
          idx = idx + (wheel > 0 and 1 or -1)
          idx = math.max(1, math.min(#preview_font_sizes, idx))
          font_size = preview_font_sizes[idx]
          reaper.SetExtState(EXT_SECTION, EXT_KEY_FONT_SIZE, tostring(font_size), true)
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

        -- 新增随机播放预滚动，强制把目标行拉入可视区并居中
        do
          if _G.scroll_request_index and #filtered_list > 0 then
            local total = #filtered_list
            local idx   = math.max(1, math.min(total, _G.scroll_request_index))
            local align = _G.scroll_request_align or 0.5

            local max_y = reaper.ImGui_GetScrollMaxY(ctx)   -- 当前窗口的最大可滚动距离
            local win_h = reaper.ImGui_GetWindowHeight(ctx) -- 可视高度
            local total_h = max_y + win_h                   -- 估算内容总高度

            local center_ratio = (idx - 0.5) / total
            local target_top = center_ratio * total_h - align * win_h
            target_top = math.max(0, math.min(target_top, max_y))

            local y0 = reaper.ImGui_GetScrollY(ctx)
            reaper.ImGui_SetScrollY(ctx, target_top)
            local y1 = reaper.ImGui_GetScrollY(ctx)

            _G.scroll_request_index_exact = idx
            _G.scroll_request_align_exact = align
            _G.scroll_request_index = nil
            _G.scroll_request_align = nil
          end
        end

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

            -- 新增随机播放精确置中，当目标行提交到可视区时做最终对齐
            if _G.scroll_request_index_exact and i == _G.scroll_request_index_exact then
              local y0 = reaper.ImGui_GetScrollY(ctx)
              reaper.ImGui_SetScrollHereY(ctx, _G.scroll_request_align_exact or 0.5)
              local y1 = reaper.ImGui_GetScrollY(ctx)
              _G.scroll_request_index_exact, _G.scroll_request_align_exact = nil, nil
            end

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

        -- 流式后台加载。在每帧的空闲时间里分批把数据库条目灌入列表，避免一次性解析卡UI
        AppendMediaDBWhenIdle(0.010, 2000) -- 本帧最多用10ms，每批最多2000条，或者也可以不带参数全程自动
        SM_PreviewTick()
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
                if keep_preview_rate_pitch_on_insert then
                  InsertMediaWithKeepParams(path)
                else
                  reaper.InsertMedia(path, 0)
                end
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

      -- 拖动文件到高级文件夹中，媒体资源管理器文件+内部 AUDIO_PATHS (右侧列表)
      if collect_mode == COLLECT_MODE_ADVANCEDFOLDER and tree_state.cur_advanced_folder then
        local cur_id = tree_state.cur_advanced_folder
        local node = advanced_folders[cur_id]

        if node and reaper.ImGui_BeginDragDropTarget(ctx) then
          node.files = node.files or {}
          local changed = false

          local function add_path(p)
            if not p or p == "" then return end
            local np = normalize_path(p, false)
            for _, old in ipairs(node.files) do
              if old == np then return end
            end
            table.insert(node.files, np)
            changed = true
          end

          -- 接收媒体资源管理器文件型负载
          local ok_files, count = reaper.ImGui_AcceptDragDropPayloadFiles(ctx, 1024)
          if ok_files and count and count > 0 then
            for i = 0, count - 1 do
              local ok1, filepath = reaper.ImGui_GetDragDropPayloadFile(ctx, i)
              if ok1 and filepath and filepath ~= "" then
                add_path(filepath)
              end
            end
          end

          -- 接收脚本内部自定义负载
          if reaper.ImGui_AcceptDragDropPayload(ctx, "AUDIO_PATHS") then
            local ok2, dtype, payload = reaper.ImGui_GetDragDropPayload(ctx)
            if ok2 and dtype == "AUDIO_PATHS" and type(payload) == "string" and payload ~= "" then
              for raw in payload:gmatch("([^|;|]+)") do
                add_path(raw)
              end
            end
          end

          if changed then
            SaveAdvancedFolders()
            files_idx_cache = nil
            CollectFiles()

            -- 清空多选状态
            file_select_start = nil
            file_select_end   = nil
            selected_row      = -1

            local static = _G._soundmole_static or {}
            _G._soundmole_static = static
            static.filtered_list_map, static.last_filter_text_map = {}, {}
          end

          reaper.ImGui_EndDragDropTarget(ctx)
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
    UI_PlayIconTrigger_Play(ctx)
    
    -- Pause 按钮
    UI_PlayIconTrigger_Pause(ctx)

    -- 播放上一个
    UI_PlayIconTrigger_Prev(ctx)

    -- Stop 按钮
    UI_PlayIconTrigger_Stop(ctx)

    -- 播放下一个
    UI_PlayIconTrigger_Next(ctx)

    -- 循环开关
    -- reaper.ImGui_SameLine(ctx, nil, 20)
    -- reaper.ImGui_Text(ctx, "Loop:")
    -- reaper.ImGui_SameLine(ctx)
    -- local rv
    -- rv, loop_enabled = reaper.ImGui_Checkbox(ctx, "##loop_checkbox", loop_enabled)
    -- if rv then
    --   -- 只要Loop勾选状态变化就立即重启播放，确保loop生效
    --   if playing_preview then
    --     RestartPreviewWithParams()
    --   end
    -- end
    UI_PlayIconTrigger_Loop(ctx)

    -- 随机播放按钮
    UI_PlayIconTrigger_Rand(ctx)

    -- 预览路由
    reaper.ImGui_SameLine(ctx, nil, 10)
    DrawPreviewRouteMenu(ctx)

    -- 自动播放切换按钮
    reaper.ImGui_SameLine(ctx, nil, 20)
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
    local pitch_knob_size = 22
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
    local knob_size = 22
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

    --------------------------------------------- 设置弹窗 ---------------------------------------------

    do
      settings_active_page = settings_active_page or "Appearance"

      -- 说明条配色
      local PAGE_HEADER_BG   = 0x5B5B5E50
      local PAGE_HEADER_TEXT = colors.normal_text

      local PAGE_ALIASES = {
        -- 兼容旧中文键
        ["界面"] = "Appearance",
        ["窗口"] = "Appearance",
        ["峰值表"] = "Appearance",
        ["外观"] = "Appearance",

        ["双击与预览"] = "Playback & Preview",
        ["播放"] = "Playback & Preview",
        ["播放控制"] = "Playback & Preview",
        ["波形预览"] = "Playback & Preview",
        ["播放与预览"] = "Playback & Preview",

        ["数据库"] = "Database & Cache",
        ["缓存目录"] = "Database & Cache",
        ["数据库与缓存"] = "Database & Cache",

        ["搜索"] = "Search & History",
        ["最近"] = "Search & History",
        ["搜索与历史"] = "Search & History",

        ["路由"] = "Routing",
        ["UCS"] = "UCS",

        ["重置默认值"] = "Reset Defaults",
        ["恢复默认"]   = "Reset Defaults",

        -- 子级到父级
        ["UI"]                              = "Appearance",
        ["Window"]                          = "Appearance",
        ["Peak Meter"]                      = "Appearance",
        ["Double-Click & Preview"]          = "Playback & Preview",
        ["Playback"]                        = "Playback & Preview",
        ["Playback Control"]                = "Playback & Preview",
        ["Waveform Preview"]                = "Playback & Preview",
        ["Database"]                        = "Database & Cache",
        ["Cache Directory"]                 = "Database & Cache",
        ["Search"]                          = "Search & History",
        ["Recent"]                          = "Search & History",
        ["Preview Output Track & Channels"] = "Routing",
        ["UCS Language Selection"]          = "UCS",
        ["Restore Defaults"]                = "Reset Defaults",
      }
      if PAGE_ALIASES[settings_active_page] then
        settings_active_page = PAGE_ALIASES[settings_active_page]
      end

      -- 分页说明条
      local function DrawPageHeader(desc_text, bg_col, text_col)
        local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
        local win_x, win_y = reaper.ImGui_GetWindowPos(ctx)
        local win_w, _     = reaper.ImGui_GetWindowSize(ctx)
        local pad_x, pad_y = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding())
        local x0 = win_x + (pad_x or 0)
        local x1 = win_x + (win_w or 0) - (pad_x or 0)
        local _, cur_y = reaper.ImGui_GetCursorScreenPos(ctx)

        local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, desc_text)
        local pad_inner_y = 6
        local header_h = (text_h or 16) + pad_inner_y * 2

        reaper.ImGui_DrawList_AddRectFilled(draw_list, x0, cur_y, x1, cur_y + header_h, bg_col or PAGE_HEADER_BG, 4)

        local content_w = (x1 - x0)
        local text_x = x0 + math.max(0, (content_w - (text_w or 0)) * 0.5)
        local text_y = cur_y + math.max(0, (header_h - (text_h or 0)) * 0.5)
        reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_col or PAGE_HEADER_TEXT, desc_text)
        reaper.ImGui_Dummy(ctx, 1, header_h)
      end

      -- 子区块标题
      local function DrawSubTitle(title)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), colors.normal_text)
        reaper.ImGui_SeparatorText(ctx, title)
        reaper.ImGui_PopStyleColor(ctx)
        -- reaper.ImGui_Dummy(ctx, 1, 10)
      end

      ----------------------------------------------------------------
      -- 顶部文字按钮
      ----------------------------------------------------------------
      local function DrawUnderlineIfHoveredOrActive(color)
        if reaper.ImGui_IsItemHovered(ctx) or reaper.ImGui_IsItemActive(ctx) then
          local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
          local minx, miny = reaper.ImGui_GetItemRectMin(ctx)
          local maxx, maxy = reaper.ImGui_GetItemRectMax(ctx)
          reaper.ImGui_DrawList_AddLine(draw_list, minx, maxy - 1, maxx, maxy - 1, color or colors.normal_text, 1.0)
        end
      end

      local function NavTextButton(label, id)
        local active = (settings_active_page == id)
        reaper.ImGui_PushID(ctx, "nav_" .. id)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), active and colors.normal_text or 0xFFB0B0B0)
        reaper.ImGui_Text(ctx, label)
        DrawUnderlineIfHoveredOrActive(colors.normal_text)
        if reaper.ImGui_IsItemHovered(ctx) then
          reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
        end
        if reaper.ImGui_IsItemClicked(ctx) then
          settings_active_page = id
        end
        reaper.ImGui_PopStyleColor(ctx)
        reaper.ImGui_PopID(ctx)
      end

      ----------------------------------------------------------------
      -- 重置默认值
      ----------------------------------------------------------------
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
        max_db = 12,
        pitch_knob_min = -6,
        pitch_knob_max = 6,
        rate_min = 0.25,
        rate_max = 4.0,
        cache_dir = DEFAULT_CACHE_DIR,
        max_recent_files = 20,
        max_recent_search = 20,
        row_height = DEFAULT_ROW_HEIGHT,
      }

      ----------------------------------------------------------------
      -- 各子区块内容
      ----------------------------------------------------------------
      local function Section_UI()
        reaper.ImGui_Text(ctx, "Content Font Size:")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_PushItemWidth(ctx, -65)
        local changed_font, new_font_size = reaper.ImGui_SliderInt(ctx, "##font_size_slider", font_size, FONT_SIZE_MIN, FONT_SIZE_MAX, "%d px")
        reaper.ImGui_PopItemWidth(ctx)
        if changed_font then
          font_size = SnapFontSize(new_font_size)
          reaper.SetExtState(EXT_SECTION, EXT_KEY_FONT_SIZE, tostring(font_size), true)
          MarkFontDirty()
        end

        reaper.ImGui_Text(ctx, "Content Row Height:")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_PushItemWidth(ctx, -65)
        local changed_row_height, new_row_height = reaper.ImGui_SliderInt(ctx, "##row_height_slider", row_height, 12, 48, "%d px")
        reaper.ImGui_PopItemWidth(ctx)
        if changed_row_height then
          row_height = new_row_height
          reaper.SetExtState(EXT_SECTION, EXT_KEY_TABLE_ROW_HEIGHT, tostring(row_height), true)
        end
      end

      local function Section_Window()
        reaper.ImGui_Text(ctx, "Window background alpha:")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_PushItemWidth(ctx, -65)
        local changed_bg, new_bg_alpha = reaper.ImGui_InputDouble(ctx, "##bg_alpha", bg_alpha, 0.05, 0.1, "%.2f")
        reaper.ImGui_PopItemWidth(ctx)
        if changed_bg then
          bg_alpha = math.max(0, math.min(1, new_bg_alpha or 1))
          reaper.SetExtState(EXT_SECTION, "bg_alpha", tostring(bg_alpha), true)
        end
      end

      local function Section_Peaks()
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
        if HelpMarker then HelpMarker("Number of peak meter channels to show. Range: 2~128.") end
      end

      local function Section_MirrorToggles()
        -- reaper.ImGui_Text(ctx, "Mirror")
        -- reaper.ImGui_Spacing(ctx)

        -- Folder Shortcuts (Mirror)
        local chg_fs
        chg_fs, mirror_folder_shortcuts = reaper.ImGui_Checkbox(ctx, "Mirror REAPER Folder Shortcuts", mirror_folder_shortcuts)
        if chg_fs then
          reaper.SetExtState(EXT_SECTION, "mirror_folder_shortcuts", mirror_folder_shortcuts and "1" or "0", true)
        end
        if reaper.ImGui_IsItemHovered(ctx) then
          reaper.ImGui_SetTooltip(ctx,
            "Mirror the Media Explorer's \"Folder Shortcuts\" here.\n" ..
            "Read-only: toggling this does NOT add/remove shortcuts in REAPER.\n" ..
            "Turn off to hide this section and skip enumerating shortcuts for faster UI."
          )
        end
        -- reaper.ImGui_TextColored(ctx, colors.gary, 
        --   "Mirror Media Explorer's \"Folder Shortcuts\" here. Read-only display. \n" ..
        --   "Disable to hide this section and skip shortcut enumeration for faster UI."
        -- )

        -- Database (Mirror)
        local chg_db
        chg_db, mirror_database = reaper.ImGui_Checkbox(ctx, "Mirror Media Explorer Databases", mirror_database)
        if chg_db then
          reaper.SetExtState(EXT_SECTION, "mirror_database", mirror_database and "1" or "0", true)
        end
        if reaper.ImGui_IsItemHovered(ctx) then
          reaper.ImGui_SetTooltip(ctx,
            "Mirror the Media Explorer \"Database\" list and entries.\n" ..
            "Read-only: create/scan/refresh databases in Media Explorer itself.\n" ..
            "Turn off to hide this section and skip querying databases on startup."
          )
        end
        -- reaper.ImGui_TextColored(ctx, colors.gary, 
        --   "Mirror the Media Explorer \"Database\" list and entries. Read-only display. \n" ..
        --   "Create or rescan databases in Media Explorer. Disable to hide this section and skip queries on startup."
        -- )
      end

      local function Section_PeekTreeRecentToggle()
        if show_peektree_recent == nil then
          local ext = reaper.GetExtState(EXT_SECTION, "show_peektree_recent")
          show_peektree_recent = (ext == nil or ext == "" or ext == "1")
        end

        local changed, v = reaper.ImGui_Checkbox(ctx, 'Show "Recently Played" in PeekTree (hides the "Play History" button)', show_peektree_recent)
        if changed then
          show_peektree_recent = v
          reaper.SetExtState(EXT_SECTION, "show_peektree_recent", v and "1" or "0", true)
        end
        -- if reaper.ImGui_IsItemHovered(ctx) then
        --   reaper.ImGui_SetTooltip(ctx, 'When enabled, the "Play History" button is hidden. Disable this to show the button.')
        -- end
      end

      local function Section_System_StopAudioDevice()
        local aci = reaper.SNM_GetIntConfigVar("audiocloseinactive", 1)
        local close_inactive = (aci == 1)
        local changed_inactive
        changed_inactive, close_inactive = reaper.ImGui_Checkbox(ctx, "Stop audio device when inactive", close_inactive)
        if changed_inactive then
          reaper.SNM_SetIntConfigVar("audiocloseinactive", close_inactive and 1 or 0)
        end
        reaper.ImGui_TextColored(ctx, colors.gary, "Release the audio device when this window is inactive. Read-only behavior toggle.")
      end

      local function Section_DblClick_Preview()
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
        local chg_auto
        chg_auto, auto_play_selected = reaper.ImGui_Checkbox(ctx, "Auto-play selected media", auto_play_selected)
      end

      local function Section_Playback()
        reaper.ImGui_Text(ctx, "Playback Settings:")
        local changed_pp
        changed_pp, preserve_pitch = reaper.ImGui_Checkbox(ctx, "Preserve pitch when changing rate", preserve_pitch)
        if changed_pp and playing_preview and reaper.CF_Preview_SetValue then
          reaper.CF_Preview_SetValue(playing_preview, "B_PPITCH", preserve_pitch and 1 or 0)
        end
      end

      local function Section_PlaybackCtrl()
        reaper.ImGui_Text(ctx, "Playback Control Settings:")

        reaper.ImGui_Text(ctx, "Max Volume (dB):")
        reaper.ImGui_PushItemWidth(ctx, -65)
        reaper.ImGui_SameLine(ctx)
        local changed_maxdb, new_max_db = reaper.ImGui_InputDouble(ctx, "##Max Volume (dB)", max_db, 1, 5, "%.2f")
        reaper.ImGui_PopItemWidth(ctx)
        if changed_maxdb then
          if new_max_db < 0 then new_max_db = 0 end
          if new_max_db > 24 then new_max_db = 24 end
          max_db = new_max_db
          reaper.SetExtState(EXT_SECTION, EXT_KEY_MAX_DB, tostring(max_db), true)
        end
        reaper.ImGui_SameLine(ctx)
        if HelpMarker then HelpMarker("Set the maximum output volume, in dB. Default: 12.") end

        reaper.ImGui_Text(ctx, "Pitch Knob Min:")
        reaper.ImGui_PushItemWidth(ctx, -65)
        reaper.ImGui_SameLine(ctx)
        local changed_pmin, new_pmin = reaper.ImGui_InputDouble(ctx, "##Pitch Knob Min", pitch_knob_min, 1, 2, "%.2f")
        reaper.ImGui_PopItemWidth(ctx)
        if changed_pmin then
          if new_pmin > pitch_knob_max then new_pmin = pitch_knob_max end
          pitch_knob_min = new_pmin
          reaper.SetExtState(EXT_SECTION, EXT_KEY_PITCH_MIN, tostring(pitch_knob_min), true)
        end

        reaper.ImGui_Text(ctx, "Pitch Knob Max:")
        reaper.ImGui_PushItemWidth(ctx, -65)
        reaper.ImGui_SameLine(ctx)
        local changed_pmax, new_pmax = reaper.ImGui_InputDouble(ctx, "##Pitch Knob Max", pitch_knob_max, 1, 2, "%.2f")
        reaper.ImGui_PopItemWidth(ctx)
        if changed_pmax then
          if new_pmax < pitch_knob_min then new_pmax = pitch_knob_min end
          pitch_knob_max = new_pmax
          reaper.SetExtState(EXT_SECTION, EXT_KEY_PITCH_MAX, tostring(pitch_knob_max), true)
        end

        reaper.ImGui_Text(ctx, "Rate Min:")
        reaper.ImGui_PushItemWidth(ctx, -65)
        reaper.ImGui_SameLine(ctx)
        local changed_rmin, new_rmin = reaper.ImGui_InputDouble(ctx, "##Rate Min", rate_min, 0.01, 0.1, "%.2f")
        reaper.ImGui_PopItemWidth(ctx)
        if changed_rmin then
          if new_rmin < 0.01 then new_rmin = 0.01 end
          if new_rmin > rate_max then new_rmin = rate_max end
          rate_min = new_rmin
          reaper.SetExtState(EXT_SECTION, EXT_KEY_RATE_MIN, tostring(rate_min), true)
        end

        reaper.ImGui_Text(ctx, "Rate Max:")
        reaper.ImGui_PushItemWidth(ctx, -65)
        reaper.ImGui_SameLine(ctx)
        local changed_rmax, new_rmax = reaper.ImGui_InputDouble(ctx, "##Rate Max", rate_max, 0.01, 0.1, "%.2f")
        reaper.ImGui_PopItemWidth(ctx)
        if changed_rmax then
          if new_rmax < rate_min then new_rmax = rate_min end
          rate_max = new_rmax
          reaper.SetExtState(EXT_SECTION, EXT_KEY_RATE_MAX, tostring(rate_max), true)
        end
      end

      local function Section_WaveformPreview()
        reaper.ImGui_Text(ctx, "Waveform Preview Settings:")
        local changed_scroll, new_scroll = reaper.ImGui_Checkbox(ctx, "Auto scroll waveform during playback", auto_scroll_enabled)
        if changed_scroll then
          auto_scroll_enabled = new_scroll
          reaper.SetExtState(EXT_SECTION, EXT_KEY_AUTOSCROLL, tostring(auto_scroll_enabled and 1 or 0), true)
        end
      end

      local function Section_InsertOptions()
        reaper.ImGui_Text(ctx, "Insert and drag:")
        local chg_keep, v_keep = reaper.ImGui_Checkbox(ctx, "Keep preview rate & pitch when inserting to arrange", keep_preview_rate_pitch_on_insert)
        if chg_keep then
          keep_preview_rate_pitch_on_insert = v_keep
          reaper.SetExtState(EXT_SECTION, "insert_keep_rate_pitch", v_keep and "1" or "0", true)
        end
      end

      local function Section_Database()
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
      end

      local function Section_CacheDir()
        reaper.ImGui_Text(ctx, "Waveform Cache Folder:")
        reaper.ImGui_PushItemWidth(ctx, -65)
        local changed_cache_dir, new_cache_dir = reaper.ImGui_InputText(ctx, "##cache_dir", cache_dir, 512)
        reaper.ImGui_PopItemWidth(ctx)
        if changed_cache_dir then
          cache_dir = normalize_path(new_cache_dir, true)
          reaper.SetExtState(EXT_SECTION, EXT_KEY_CACHE_DIR, cache_dir, true)
        end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Browse##SelectCacheDir") then
          local rv, out = reaper.JS_Dialog_BrowseForFolder("Select a directory:", cache_dir)
          if rv == 1 and out and out ~= "" then
            cache_dir = normalize_path(out, true)
            reaper.SetExtState(EXT_SECTION, EXT_KEY_CACHE_DIR, cache_dir, true)
          end
        end
      end

      local function Section_Search()
        reaper.ImGui_Text(ctx, "Search Settings:")
        local sea_enter_changed, search_enter_v = reaper.ImGui_Checkbox(ctx, "Update search only when enter key pressed##enter_mode", search_enter_mode)
        if sea_enter_changed then
          search_enter_mode = search_enter_v
          reaper.SetExtState(EXT_SECTION, "search_enter_mode", search_enter_v and "1" or "0", true)
        end
      end

      local function Section_Recent()
        reaper.ImGui_Text(ctx, "Max Recent Searched:")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_PushItemWidth(ctx, -65)
        local chg_rs, v_rs = reaper.ImGui_InputInt(ctx, "##max_recent_search_input", max_recent_search, 1, 5)
        reaper.ImGui_PopItemWidth(ctx)
        if chg_rs then
          max_recent_search = math.max(1, math.min(100, v_rs or 20))
          reaper.SetExtState(EXT_SECTION, "max_recent_search", tostring(max_recent_search), true)
          while #recent_search_keywords > max_recent_search do table.remove(recent_search_keywords) end
          SaveRecentSearched()
        end

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
      end

      local function Section_Route()
        RenderPreviewRouteSettingsUI(ctx)
      end

      local function Section_UCS()
        reaper.ImGui_Text(ctx, "UCS Settings:")
        DrawUcsLanguageSelector(ctx)
      end

      local function Section_ResetToDefaults()
        reaper.ImGui_Text(ctx, "This action will restore all settings to their default values.")
        -- reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Button(ctx, "Reset To Defaults##Settings_reset", 120, 32) then
          -- 恢复各项设置为默认值
          collect_mode         = DEFAULTS.collect_mode
          doubleclick_action   = DEFAULTS.doubleclick_action
          auto_play_selected   = DEFAULTS.auto_play_selected
          preserve_pitch       = DEFAULTS.preserve_pitch
          bg_alpha             = DEFAULTS.bg_alpha
          peak_chans           = DEFAULTS.peak_chans
          font_size            = DEFAULTS.font_size
          max_db               = DEFAULTS.max_db
          pitch_knob_min       = DEFAULTS.pitch_knob_min
          pitch_knob_max       = DEFAULTS.pitch_knob_max
          rate_min             = DEFAULTS.rate_min
          rate_max             = DEFAULTS.rate_max
          cache_dir            = DEFAULTS.cache_dir
          auto_scroll_enabled  = DEFAULTS.auto_scroll_enabled
          max_recent_files     = DEFAULTS.max_recent_files
          max_recent_search    = DEFAULTS.max_recent_search
          row_height           = DEFAULTS.row_height
          build_waveform_cache = DEFAULTS.build_waveform_cache
          search_enter_mode    = DEFAULTS.search_enter_mode

          reaper.SetExtState(EXT_SECTION, EXT_KEY_PEAKS, tostring(peak_chans), true)
          reaper.SetExtState(EXT_SECTION, EXT_KEY_FONT_SIZE, tostring(font_size), true)
          reaper.SetExtState(EXT_SECTION, EXT_KEY_CACHE_DIR, tostring(cache_dir), true)
          reaper.SetExtState(EXT_SECTION, EXT_KEY_AUTOSCROLL, tostring(auto_scroll_enabled and 1 or 0), true)
          reaper.SetExtState(EXT_SECTION, "search_enter_mode", search_enter_mode and "1" or "0", true)
          reaper.SetExtState(EXT_SECTION, "build_waveform_cache", build_waveform_cache and "1" or "0", true)
          reaper.SetExtState(EXT_SECTION, "mirror_folder_shortcuts", mirror_folder_shortcuts and "1" or "0", true)
          reaper.SetExtState(EXT_SECTION, "mirror_database", mirror_database and "1" or "0", true)
          reaper.SetExtState(EXT_SECTION, "show_peektree_recent", show_peektree_recent and "1" or "0", true)

          MarkFontDirty()
          CollectFiles()
        end
        if reaper.ImGui_IsItemHovered(ctx) then
          reaper.ImGui_SetTooltip(ctx, "Reset all settings to default values")
        end
      end

      ----------------------------------------------------------------
      -- 顶层分页
      ----------------------------------------------------------------
      local pages = {
        -- 外观
        { id = "Appearance", fn = function()
            DrawPageHeader("Adjust UI appearance and display details", PAGE_HEADER_BG, PAGE_HEADER_TEXT)
            DrawSubTitle("UI") Section_UI()
            DrawSubTitle("Window")
            Section_Window()
            DrawSubTitle("Peak Meter")
            Section_Peaks()
            DrawSubTitle("PeekTree")
            Section_MirrorToggles() -- Media Explorer Mirrors - Folder Shortcuts & Database
            Section_PeekTreeRecentToggle() -- Recently Played
          end
        },

        -- 系统
        { id = "System", fn = function()
            DrawPageHeader("Adjust system preferences", PAGE_HEADER_BG, PAGE_HEADER_TEXT)
            DrawSubTitle("Stop audio device settings"); Section_System_StopAudioDevice()
          end
        },

        -- 双击与预览
        { id = "Playback & Preview", fn = function()
            DrawPageHeader("Configure preview and playback behavior", PAGE_HEADER_BG, PAGE_HEADER_TEXT)
            DrawSubTitle("Double-Click & Preview")
            Section_DblClick_Preview()
            DrawSubTitle("Insert Options")
            Section_InsertOptions()
            DrawSubTitle("Playback")
            Section_Playback()
            DrawSubTitle("Playback Control")
            Section_PlaybackCtrl()
            DrawSubTitle("Waveform Preview")
            Section_WaveformPreview()
          end
        },

        -- 数据库与缓存
        { id = "Database & Cache", fn = function()
            DrawPageHeader("Manage database and cache", PAGE_HEADER_BG, PAGE_HEADER_TEXT)
            DrawSubTitle("Database")
            Section_Database()
            DrawSubTitle("Cache Directory")
            Section_CacheDir()
          end
        },

        -- 搜索与历史
        { id = "Search & History", fn = function()
            DrawPageHeader("Configure search and history", PAGE_HEADER_BG, PAGE_HEADER_TEXT)
            DrawSubTitle("Search")
            Section_Search()
            DrawSubTitle("Recent")
            Section_Recent()
          end
        },

        -- 预览路由
        { id = "Routing", fn = function()
            DrawPageHeader("Configure preview output tracks and channels", PAGE_HEADER_BG, PAGE_HEADER_TEXT)
            DrawSubTitle("Preview Output Track & Channels")
            Section_Route()
          end
        },

        -- UCS
        { id = "UCS", fn = function()
            DrawPageHeader("Configure UCS language and tags", PAGE_HEADER_BG, PAGE_HEADER_TEXT)
            DrawSubTitle("UCS Language Selection")
            Section_UCS()
          end
        },

        -- 重置默认值
        { id = "Reset Defaults", fn = function()
            DrawPageHeader("Restore defaults", PAGE_HEADER_BG, PAGE_HEADER_TEXT)
            DrawSubTitle("Restore Defaults")
            Section_ResetToDefaults()
          end
        },
      }

      -- Ctrl+P 打开设置弹窗
      if (reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl())) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_P()) then
        settings_window_open = true
        reaper.SetExtState(EXT_SECTION, "popup_settings_open", "true", true)
      end

      function DrawSettingsWindow()
        if not settings_window_open then return end

        reaper.ImGui_SetNextWindowSize(ctx, 600, 400, reaper.ImGui_Cond_FirstUseEver())
        local visible, open = reaper.ImGui_Begin(ctx, "Settings", true, reaper.ImGui_WindowFlags_AlwaysAutoResize())
        if visible then
          -- 顶部导航
          local ix, iy = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())
          reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 10, iy)
          for i, p in ipairs(pages) do
            NavTextButton(p.id, p.id)
            reaper.ImGui_SameLine(ctx)
          end
          reaper.ImGui_NewLine(ctx)
          reaper.ImGui_PopStyleVar(ctx)

          -- 当前页内容
          for _, p in ipairs(pages) do
            if p.id == settings_active_page then
              p.fn()
              break
            end
          end

          -- 底部留白
          reaper.ImGui_Dummy(ctx, 800, 14)
          reaper.ImGui_End(ctx)
        end

        -- 只在本帧从开到关的瞬间保存一次
        if settings_window_prev_open and not open then
          SaveSettings()
        end
        settings_window_prev_open = open

        if settings_window_open ~= open then
          settings_window_open = open
          reaper.SetExtState(EXT_SECTION, "popup_settings_open", tostring(open), true)
        end
      end

      DrawSettingsWindow()
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

    -- 播放器控件
    reaper.ImGui_SameLine(ctx)
    do
      local src_len    = Wave.src_len or 0
      local rate       = play_rate or 1
      local cursor_pos = (Wave.play_cursor or 0) * rate

      -- 是否存在有效选区
      local has_sel = (select_start_time and select_end_time) and (math.abs(select_end_time - select_start_time) > 0.01)

      local time_val_str = reaper.format_timestr(cursor_pos or 0, "")
      local duration_val_str
      if has_sel then
        local selection_len = math.abs(select_end_time - select_start_time) * rate
        duration_val_str = reaper.format_timestr(selection_len or 0, "")
      else
        duration_val_str = reaper.format_timestr(src_len or 0, "")
      end

      local tlabel, dlabel = "Time: ", "Duration: "

      -- 计算右侧对齐所需总宽
      local tl_w, th = reaper.ImGui_CalcTextSize(ctx, tlabel.."000") -- 占位
      local dl_w, _  = reaper.ImGui_CalcTextSize(ctx, dlabel)

      reaper.ImGui_PushFont(ctx, fonts.odrf, 16)  -- 数值字体（仅用于测宽与绘制数值）
      local tv_w, _  = reaper.ImGui_CalcTextSize(ctx, time_val_str)
      local dv_w, _  = reaper.ImGui_CalcTextSize(ctx, duration_val_str)
      reaper.ImGui_PopFont(ctx)

      local spacing = 8
      local total_w = tl_w + tv_w + spacing + dl_w + dv_w

      -- 推到右侧
      local avail = reaper.ImGui_GetContentRegionAvail(ctx)
      if avail > total_w then
        reaper.ImGui_Dummy(ctx, avail - total_w, 0)
        reaper.ImGui_SameLine(ctx, nil, 0)
      end

      reaper.ImGui_Text(ctx, tlabel)
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_PushFont(ctx, fonts.odrf, 16)
      reaper.ImGui_Text(ctx, time_val_str)
      reaper.ImGui_PopFont(ctx)

      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_Text(ctx, dlabel)
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_PushFont(ctx, fonts.odrf, 16)
      reaper.ImGui_Text(ctx, duration_val_str)
      reaper.ImGui_PopFont(ctx)
    end

    -- 跳过静音的勾选项，放置右侧代码。
    -- reaper.ImGui_SameLine(ctx, nil, 0)
    -- local avail = reaper.ImGui_GetContentRegionAvail(ctx) -- 计算可用宽度
    -- local txt_w, txt_h = reaper.ImGui_CalcTextSize(ctx, "Skip Silence") -- 文字尺寸
    -- local cb_w = txt_w + txt_h + 16 -- 文字宽度+勾选框大小+间距

    -- -- 如果可用宽度足够，把光标推到右侧
    -- if avail > cb_w then
    --   reaper.ImGui_Dummy(ctx, avail - cb_w, 0)
    --   reaper.ImGui_SameLine(ctx, nil, 0)
    -- end

    -- 跳过静音
    local silence_changed
    reaper.ImGui_Text(ctx, "Skip Silence:")
    reaper.ImGui_SameLine(ctx, nil, 10)
    silence_changed, skip_silence_enabled = reaper.ImGui_Checkbox(ctx, "##Skip Silence", skip_silence_enabled)
    if silence_changed then
      reaper.SetExtState(EXT_SECTION, "skip_silence", skip_silence_enabled and "1" or "0", true)
    end
    if reaper.ImGui_IsItemHovered(ctx) then
      reaper.ImGui_SetTooltip(ctx, "Automatically skip initial silence when playing")
    end

    -- 文件路径，始终跟随 file_info
    local show_path = file_info and file_info.path or ""
    show_path = normalize_path(show_path, false)
    if show_path ~= "" then
      reaper.ImGui_SameLine(ctx)
      local avail = reaper.ImGui_GetContentRegionAvail(ctx) -- 计算可用宽度
      local txt_w, txt_h = reaper.ImGui_CalcTextSize(ctx, file_info.path) -- 文字尺寸
      local cb_w = txt_w + txt_h + 16 -- 文字宽度+勾选框大小+间距

      -- 如果可用宽度足够，把光标推到右侧
      if avail > cb_w then
        reaper.ImGui_Dummy(ctx, avail - cb_w, 0)
        reaper.ImGui_SameLine(ctx, nil, 0)
      end

      -- reaper.ImGui_Text(ctx, "Now browsing:")
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
          collect_mode = COLLECT_MODE_SAMEFOLDER -- 切换到同目录模式
          tree_state.cur_path = path -- 当前文件夹
          RefreshFolderFiles(path) -- 刷新文件
          reaper.SetExtState(EXT_SECTION, "collect_mode", tostring(COLLECT_MODE_SAMEFOLDER), true)
          reaper.SetExtState(EXT_SECTION, "cur_samefolder_path", tree_state.cur_path or "", true)
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
      img_h_offset = math.max(0, math.min(300, new_off)) -- 专辑封面高度限制
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
    local left_img_w = has_cover and 130 or 1 -- 无图片时显示为1的宽度，后续使用reaper.ImGui_Dummy(ctx, -11, 0)补偿回正常宽度
    local gap = has_cover and 6 or 0
    local right_img_w = avail_w - left_img_w - gap

    -- 专辑图片显示
    if reaper.ImGui_BeginChild(ctx, "cover_art", left_img_w, img_h) then
      local audio_path = img_info and img_info.path
      -- 计算封面临时文件路径（优先内嵌元数据，再同目录查找）
      local cover_path = audio_path and GetCoverImagePath(audio_path)
      if cover_path then
        -- 水平/垂直居中
        local img_w, img_h = 130, 130
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
    if reaper.ImGui_BeginChild(ctx, "waveform", right_img_w, img_h) then -- 微调波形宽度（计划预留右侧空间-75用于放置专辑图片）和高度（补偿时间线高度+时间线间隔9）
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

          local ok_for_remap = false
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
            ok_for_remap = true
          else
            -- 全音频
            local audio_len = tonumber(cache and cache.src_len) or 0
            if audio_len > 0 then
              local zoom = Wave.zoom or 1
              local visible_len = math.max(audio_len / zoom, 0.01)
              if visible_len > audio_len then visible_len = audio_len end

              local max_scroll = math.max(0, audio_len - visible_len)
              local scroll = math.max(0, math.min(Wave.scroll or 0, max_scroll))

              window_start = scroll
              window_end = window_start + visible_len
              Wave.src_len = audio_len -- 始终用源音频长度
              ok_for_remap = true
            else
              peaks, pixel_cnt, channel_count = nil, nil, nil
            end
          end

          if ok_for_remap then
            peaks, pixel_cnt, _, channel_count = RemapWaveformToWindow(cache, pw_region_w, window_start, window_end)
            last_wave_info = cur_key
            last_pixel_cnt = pw_region_w
            last_view_len = view_len
            last_scroll = Wave.scroll
          end
        end
        -- end
      end

      -- 绘制时间线
      local view_start = Wave.scroll
      local view_end = math.min(Wave.scroll + Wave.src_len / Wave.zoom, Wave.src_len)
      if Wave.src_len and Wave.src_len > 0 then
        DrawTimeLine(ctx, Wave, view_start, view_end)
      end
      -- reaper.ImGui_Dummy(ctx, 0, timeline_height) -- 占位时间线高度，本应是配套绘制时间线的，但ImGui_Dummy在这里无效

      reaper.ImGui_NewLine(ctx) -- 改用换行，因为ImGui_Dummy在这里无效
      DrawWaveformInImGui(ctx, peaks, pw_region_w, img_h - 30, src_len, channel_count) -- -30用于补偿波形预览上方的时间线区域和间隔，否则应为0
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
      reaper.ImGui_EndChild(ctx)

      -- 放大缩小按钮和水平滚动条
      local view_len = Wave.src_len / Wave.zoom
      local max_scroll = math.max(0, Wave.src_len - view_len)
      local cursor_pos = Wave.play_cursor or 0
      local label_fmt

      local range_start, range_end
      if select_start_time and select_end_time and math.abs(select_end_time - select_start_time) > 0.01 then
        label_fmt = "Selection: %s ~ %s" -- "Selection: %s ~ %s | %s / %s"
        range_start = math.min(select_start_time, select_end_time) * play_rate -- 速率变化时调整选区时间位置
        range_end = math.max(select_start_time, select_end_time) * play_rate -- 速率变化时调整选区时间位置
      else
        label_fmt = "View range: %s ~ %s" -- "View range: %s ~ %s | %s / %s"
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

      -- 控件颜色
      local col_frame_bg      = (colors and colors.scroll_bg)          or 0x1D2F4950 -- 背景
      local col_frame_bg_hov  = (colors and colors.scroll_bg_hover)    or 0x23456D50 -- Hover
      local col_frame_bg_act  = (colors and colors.scroll_bg_active)   or 0x316AAD50 -- Active
      local col_grab          = (colors and colors.scroll_grab)        or 0xFFB0B0B0 -- 拖块
      local col_grab_active   = (colors and colors.scroll_grab_active) or 0xFFFFFFFF -- 拖块按下

      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(),         col_frame_bg)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(),  col_frame_bg_hov)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(),   col_frame_bg_act)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(),      col_grab)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(),col_grab_active)

      local changed, new_scroll = reaper.ImGui_SliderDouble(ctx, "##scrollbar", Wave.scroll, 0, max_scroll, label)
      -- 恢复样式
      reaper.ImGui_PopStyleColor(ctx, 5)

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
    local display_list = _G.current_display_list or {}
    -- 选中行越界保护
    local sr = selected_row
    if sr and (sr < 1 or sr > #display_list) then
      sr = nil
    end

    local file_info
    if collect_mode == COLLECT_MODE_RECENTLY_PLAYED and current_recent_play_info then -- 最近播放模式时使用播放列表项
      file_info = current_recent_play_info
    elseif sr and display_list[sr] then
      file_info = display_list[sr] -- 其他模式用右侧表格选中项
      selected_recent_row = 0 -- 清空最近播放选中项
    else
      file_info = last_playing_info
    end

    do
      local is_db = (collect_mode == COLLECT_MODE_MEDIADB or collect_mode == COLLECT_MODE_REAPERDB)
      local streaming = is_db and (_G._mediadb_stream ~= nil) and (not _G._mediadb_stream.eof)
      local loaded_total = (type(files_idx_cache) == "table") and #files_idx_cache or 0
      local shown_count  = (type(_G.current_display_list) == "table") and #_G.current_display_list or 0

      if streaming then
        -- 流式进行中，显示已加载数量
        reaper.ImGui_Text(ctx, string.format("%d loaded ...", loaded_total)) -- fixed width 7
      else
        if is_db then
          -- 是否存在任意过滤
          local has_filter = false
          do
            local t = _G.commit_filter_text
            if type(t) == "string" and t ~= "" then has_filter = true end
            if _G.temp_search_keyword then has_filter = true end
            if _G.active_saved_search then has_filter = true end
            if _G.temp_ucs_cat_keyword or _G.temp_ucs_sub_keyword then has_filter = true end
          end

          if has_filter then
            -- 已完成+有过滤，只显示过滤后的数量和总数
            reaper.ImGui_Text(ctx, string.format("%d shown / %d total.", shown_count, loaded_total))
          else
            -- 已完成+无过滤，显示总数
            reaper.ImGui_Text(ctx, string.format("%d shown / %d total.", loaded_total, loaded_total))
          end
        else
          -- 非MediaDB模式按原逻辑
          reaper.ImGui_Text(ctx, (function()
            local function _len(v)
              if type(v) == "table" then
                return #v
              elseif type(v) == "number" then
                return v
              end
            end
            local function _first_len(...)
              for i = 1,select('#',...) do
                local n = _len(select(i,...))
                if n and n >= 0 then return n end
              end
            end
            local total = _first_len(files_idx_cache, all_files, file_list, files_all, files) or (shown_count or 0)
            local shown = _first_len(filtered_list, visible_rows, visible_list, display_list, view_list, table_list, rows_list, files_idx_cache_view, files_view, current_rows, current_list, render_list, current_display) or total

            return string.format("%d shown / %d total.", shown, total)
          end)())
        end
      end
    end
    
    reaper.ImGui_SameLine(ctx)

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

  -- FreeSurround 初始化钩子
  if FS and type(FS_InitHooks)=="function" then
    FS_InitHooks()
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
