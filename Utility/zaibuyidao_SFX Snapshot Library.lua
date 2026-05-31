-- @description SFX Snapshot Library
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/u/zaibuyidao
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about
--   Requires:
--   1. ReaImGui
--   2. js_ReaScriptAPI
--   3. SWS Extension
--   4. Soundmole Extension

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

----------------------------------------
-- Constants
----------------------------------------

local SCRIPT_NAME = "SFX Snapshot Library"
local SCRIPT_VERSION = "1.0"
local EXT_SECTION = "SOUNDFX_SNAPSHOT_LIBRARY_PRO"

local DEFAULT_LIBRARY_DIR = reaper.GetResourcePath() .. "/SFX Snapshot Library"
local SNAPSHOT_DIR_NAME = "snapshots"
local INDEX_FILE_NAME = "index.lua"
local PREVIEW_FILE_NAME = "preview.mp3"
local LEGACY_PREVIEW_FILE_NAME = "preview.wav"

local ctx = ImGui.CreateContext(SCRIPT_NAME)
local CHILD_FLAGS_BORDER = ImGui.ChildFlags_Borders or 1
local WINDOW_FLAGS_NONE = 0
local MOUSE_BUTTON_LEFT = ImGui.MouseButton_Left or 0
local MOUSE_BUTTON_RIGHT = ImGui.MouseButton_Right or 1
local KEY_SPACE = ImGui.Key_Space or 32
local KEY_ESCAPE = ImGui.Key_Escape or 27
local KEY_DELETE = ImGui.Key_Delete or 522
local KEY_F = ImGui.Key_F or 575
local KEY_LEFT_SHIFT = ImGui.Key_LeftShift or 656
local KEY_RIGHT_SHIFT = ImGui.Key_RightShift or 660
local MOD_SHIFT = ImGui.Mod_Shift or 1
local WAVEFORM_CACHE_PIXELS = 2048
local WAVEFORM_CACHE_MAX_CHANNELS = 6
local PREVIEW_VOLUME_MIN_DB = -60.0
local PREVIEW_VOLUME_MAX_DB = 12.0
local PREVIEW_VOLUME_ZERO_RATIO = 0.5
local PREVIEW_VOLUME_DRAG_SPEED = 0.006

function ImGuiValue(value, fallback)
  if type(value) == "function" then
    local ok, result = pcall(value)
    if ok and result ~= nil then return result end
  elseif value ~= nil then
    return value
  end

  return fallback
end

MOUSE_BUTTON_LEFT = ImGuiValue(ImGui.MouseButton_Left, MOUSE_BUTTON_LEFT)
MOUSE_BUTTON_RIGHT = ImGuiValue(ImGui.MouseButton_Right, MOUSE_BUTTON_RIGHT)
KEY_SPACE = ImGuiValue(ImGui.Key_Space, KEY_SPACE)
KEY_ESCAPE = ImGuiValue(ImGui.Key_Escape, KEY_ESCAPE)
KEY_DELETE = ImGuiValue(ImGui.Key_Delete, KEY_DELETE)
KEY_F = ImGuiValue(ImGui.Key_F, KEY_F)
KEY_LEFT_SHIFT = ImGuiValue(ImGui.Key_LeftShift, KEY_LEFT_SHIFT)
KEY_RIGHT_SHIFT = ImGuiValue(ImGui.Key_RightShift, KEY_RIGHT_SHIFT)
MOD_SHIFT = ImGuiValue(ImGui.Mod_Shift, MOD_SHIFT)

local WINDOW_FLAGS_NO_COLLAPSE = ImGuiValue(ImGui.WindowFlags_NoCollapse, 32)
local WINDOW_FLAGS_NO_TITLE_BAR = ImGuiValue(ImGui.WindowFlags_NoTitleBar, 1)
local WINDOW_FLAGS_MAIN = WINDOW_FLAGS_NO_COLLAPSE + WINDOW_FLAGS_NO_TITLE_BAR

local MOUSE_CURSOR_RESIZE_NS = ImGuiValue(ImGui.MouseCursor_ResizeNS, 3)
local MOUSE_CURSOR_RESIZE_EW = ImGuiValue(ImGui.MouseCursor_ResizeEW, 4)

----------------------------------------
-- Fonts
----------------------------------------

function CreateUIFont(size)
  local os_name = reaper.GetOS()
  local names

  if os_name:find("Win") then
    names = { "Microsoft YaHei UI", "Microsoft YaHei", "Arial" }
  elseif os_name:find("OSX") or os_name:find("macOS") then
    names = { "PingFang SC", "Hiragino Sans GB", "Arial" }
  else
    names = { "Noto Sans CJK SC", "WenQuanYi Micro Hei", "Arial" }
  end

  for _, name in ipairs(names) do
    local font = ImGui.CreateFont(name, size)
    if font then return font end
  end
end

local font_title = CreateUIFont(21)
local font_normal = CreateUIFont(14)
local font_small = CreateUIFont(12)
local font_tiny = CreateUIFont(11)

if font_title then ImGui.Attach(ctx, font_title) end
if font_normal then ImGui.Attach(ctx, font_normal) end
if font_small then ImGui.Attach(ctx, font_small) end
if font_tiny then ImGui.Attach(ctx, font_tiny) end

----------------------------------------
-- State
----------------------------------------

local state = {
  library_dir = "",
  snapshots = {},
  selected = 1,

  filter = "",
  category_filter = "All",
  show_favorites_only = false,

  load_to_new_tracks = false,
  restore_markers = true,
  restore_tempo = true,
  check_empty_space = true,
  auto_render_preview = true,
  skip_preview_leading_empty = true,
  info_panel_at_bottom = true,
  bottom_split_ratio = 0.72,
  side_split_ratio = 0.64,
  sort_order = "newest",

  status = "Ready.",
  error = "",

  show_save_popup = false,
  save_name = "",
  save_category = "Whoosh",
  save_tags = "",
  save_description = "",

  show_settings_popup = false,
  new_library_dir = "",

  preview_source = nil,
  preview_handle = nil,
  preview_path = "",
  preview_name = "",
  preview_position = 0,
  preview_length = 0,
  preview_is_playing = false,
  preview_loop = false,
  preview_volume_db = 0.0,
  preview_volume_db_text = "0.0",
  preview_volume_drag_start_y = nil,
  preview_volume_drag_start_ratio = nil,

  waveform_cache_key = "",
  waveform_cache_path = "",
  waveform_cache_job_key = "",
  waveform_cache_data = nil,
  waveform_cache_building = false,
  waveform_cache_status = "",

  snapshot_list_focused = false,
  space_key_consumed_frame = false,
  request_close = false,
}

----------------------------------------
-- Basic Helpers
----------------------------------------

function NormalizePath(path)
  path = tostring(path or "")
  path = path:gsub("\\", "/")
  path = path:gsub("/+$", "")
  return path
end

function JoinPath(a, b)
  a = NormalizePath(a)
  b = tostring(b or "")
  if a == "" then return b end
  return a .. "/" .. b
end

function EnsureDir(path)
  if path and path ~= "" then
    reaper.RecursiveCreateDirectory(path, 0)
  end
end

function FileExists(path)
  local f = io.open(path, "rb")
  if f then f:close() return true end
  return false
end

function WriteFile(path, data)
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(data or "")
  f:close()
  return true
end

function SanitizeFileName(name)
  name = tostring(name or "")
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  name = name:gsub("[\\/:*?\"<>|]", "_")
  name = name:gsub("%s+", " ")
  if name == "" then
    name = os.date("SFX Snapshot %Y-%m-%d %H-%M-%S")
  end
  return name
end

----------------------------------------
-- Snapshot Media Archive Helpers
----------------------------------------

local SNAPSHOT_MEDIA_TOKEN = "__SNAPSHOT_MEDIA__"

function GetFileName(path)
  path = tostring(path or ""):gsub("\\", "/")
  return path:match("([^/]+)$") or path
end

function GetFileDir(path)
  path = NormalizePath(path)
  return path:match("^(.*)/[^/]*$") or ""
end

function IsAbsolutePath(path)
  path = tostring(path or "")

  if path:match("^%a:[/\\]") then return true end
  if path:match("^[/\\][/\\]") then return true end
  if path:sub(1, 1) == "/" then return true end

  return false
end

function GetCurrentProjectDir()
  local _, project_file = reaper.EnumProjects(-1, "")

  if project_file and project_file ~= "" then
    return GetFileDir(project_file)
  end

  if reaper.GetProjectPath then
    local ok, project_path = pcall(reaper.GetProjectPath, "")
    if ok and project_path and project_path ~= "" then
      return NormalizePath(project_path)
    end
  end

  return ""
end

function ResolveOriginalMediaPath(path)
  path = tostring(path or "")
  if path == "" then return "" end
  if path:find("^" .. SNAPSHOT_MEDIA_TOKEN) then return path end

  local normalized = NormalizePath(path)

  if FileExists(normalized) then
    return normalized
  end

  if IsAbsolutePath(path) then
    return normalized
  end

  local project_dir = GetCurrentProjectDir()
  if project_dir ~= "" then
    local candidate = JoinPath(project_dir, normalized)
    if FileExists(candidate) then
      return candidate
    end
  end

  return normalized
end

function CopyFileBinary(src_path, dst_path)
  local src = io.open(src_path, "rb")
  if not src then return false, "Failed to open source media: " .. tostring(src_path) end

  local dst = io.open(dst_path, "wb")
  if not dst then
    src:close()
    return false, "Failed to write archived media: " .. tostring(dst_path)
  end

  while true do
    local block = src:read(1024 * 1024)
    if not block then break end
    dst:write(block)
  end

  src:close()
  dst:close()
  return true
end

function MakeUniqueArchivedMediaName(base_name, used_names)
  base_name = SanitizeFileName(GetFileName(base_name))
  if base_name == "" then base_name = "media" end

  local candidate = base_name
  local stem, ext = base_name:match("^(.*)(%.[^%.]*)$")
  if not stem then
    stem = base_name
    ext = ""
  end

  local index = 1
  while used_names[tostring(candidate):lower()] do
    candidate = string.format("%s_%03d%s", stem, index, ext)
    index = index + 1
  end

  used_names[tostring(candidate):lower()] = true
  return candidate
end

function ExtractQuotedFilePathsFromChunk(chunk)
  local paths = {}
  local seen = {}

  for path in tostring(chunk or ""):gmatch('FILE%s+"([^"]+)"') do
    if path ~= "" and not seen[path] then
      seen[path] = true
      paths[#paths + 1] = path
    end
  end

  return paths
end

function ArchiveSnapshotMedia(data, snapshot_folder)
  local media_dir = JoinPath(snapshot_folder, "media")
  EnsureDir(media_dir)

  local mapping = {}
  local used_names = {}
  local copied_count = 0
  local missing_count = 0
  local reference_count = 0
  local missing = {}

  local function ensure_archived(original_path)
    if mapping[original_path] then
      return mapping[original_path]
    end

    if tostring(original_path or ""):find("^" .. SNAPSHOT_MEDIA_TOKEN) then
      mapping[original_path] = original_path
      return original_path
    end

    reference_count = reference_count + 1

    local resolved = ResolveOriginalMediaPath(original_path)
    if resolved == "" or not FileExists(resolved) then
      missing_count = missing_count + 1
      missing[#missing + 1] = original_path
      mapping[original_path] = original_path
      return original_path
    end

    local archived_name = MakeUniqueArchivedMediaName(resolved, used_names)
    local archived_path = JoinPath(media_dir, archived_name)

    local ok = CopyFileBinary(resolved, archived_path)
    if ok then
      copied_count = copied_count + 1
      mapping[original_path] = SNAPSHOT_MEDIA_TOKEN .. "/" .. archived_name
    else
      missing_count = missing_count + 1
      missing[#missing + 1] = original_path
      mapping[original_path] = original_path
    end

    return mapping[original_path]
  end

  for _, tr in ipairs(data.tracks or {}) do
    for _, item_data in ipairs(tr.items or {}) do
      local chunk = tostring(item_data.chunk or "")
      local paths = ExtractQuotedFilePathsFromChunk(chunk)

      for _, original_path in ipairs(paths) do
        ensure_archived(original_path)
      end

      item_data.chunk = chunk:gsub('FILE%s+"([^"]+)"', function(original_path)
        local archived = ensure_archived(original_path)
        return 'FILE "' .. archived .. '"'
      end)
    end
  end

  data.media_archive = {
    version = 1,
    token = SNAPSHOT_MEDIA_TOKEN,
    media_dir = "media",
    reference_count = reference_count,
    copied_count = copied_count,
    missing_count = missing_count,
    missing = missing,
  }

  return data.media_archive
end

function ResolveSnapshotMediaPathsInChunk(chunk, snapshot_folder)
  local media_dir = JoinPath(snapshot_folder or "", "media")

  return tostring(chunk or ""):gsub('FILE%s+"([^"]+)"', function(path)
    path = tostring(path or "")

    local rel = path:match("^" .. SNAPSHOT_MEDIA_TOKEN .. "[/\\](.+)$")
    if rel and rel ~= "" then
      return 'FILE "' .. JoinPath(media_dir, rel) .. '"'
    end

    return 'FILE "' .. path .. '"'
  end)
end

function ToBase36(num, min_len)
  local chars = "0123456789abcdefghijklmnopqrstuvwxyz"
  num = math.floor(tonumber(num) or 0)

  local out = ""
  repeat
    local idx = (num % 36) + 1
    out = chars:sub(idx, idx) .. out
    num = math.floor(num / 36)
  until num <= 0

  min_len = tonumber(min_len) or 0
  while #out < min_len do
    out = "0" .. out
  end

  return out
end

function MakeID()
  local time_part = ToBase36(os.time())
  local random_part = ToBase36(math.random(0, 36 * 36 * 36 * 36 - 1), 4)

  return time_part .. random_part
end

-- function MakeID()
--   return os.date("%Y%m%d_%H%M%S") .. "_" .. tostring(math.random(100000, 999999))
-- end

function Lower(s)
  return tostring(s or ""):lower()
end

function Trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function ClampNumber(value, min_value, max_value)
  value = tonumber(value) or min_value

  if value < min_value then return min_value end
  if value > max_value then return max_value end

  return value
end

function SplitTags(s)
  local tags = {}
  s = tostring(s or "")
  s = s:gsub("，", ",")
  s = s:gsub("；", ",")

  for tag in s:gmatch("[^,]+") do
    tag = Trim(tag)
    if tag ~= "" then
      tags[#tags + 1] = tag
    end
  end

  return tags
end

function JoinTags(tags)
  if type(tags) ~= "table" then return "" end
  return table.concat(tags, ", ")
end

----------------------------------------
-- Lua Table Serialization
----------------------------------------

function SerializeValue(v, indent)
  indent = indent or 0
  local t = type(v)

  if t == "number" then
    return tostring(v)
  elseif t == "boolean" then
    return v and "true" or "false"
  elseif t == "string" then
    return string.format("%q", v)
  elseif t == "table" then
    local pad = string.rep(" ", indent)
    local child_pad = string.rep(" ", indent + 2)
    local out = { "{\n" }

    for k, val in pairs(v) do
      local key
      if type(k) == "number" then
        key = "[" .. tostring(k) .. "]"
      else
        key = "[" .. string.format("%q", tostring(k)) .. "]"
      end
      out[#out + 1] = child_pad .. key .. " = " .. SerializeValue(val, indent + 2) .. ",\n"
    end

    out[#out + 1] = pad .. "}"
    return table.concat(out)
  else
    return "nil"
  end
end

function SaveLuaTable(path, tbl)
  return WriteFile(path, "return " .. SerializeValue(tbl, 0))
end

function LoadLuaTable(path)
  if not FileExists(path) then return nil end

  local chunk, err = loadfile(path)
  if not chunk then
    return nil, err
  end

  local ok, result = pcall(chunk)
  if not ok then
    return nil, result
  end

  return result
end

----------------------------------------
-- Library Paths
----------------------------------------

function GetIndexPath()
  return JoinPath(state.library_dir, INDEX_FILE_NAME)
end

function GetSnapshotsRoot()
  return JoinPath(state.library_dir, SNAPSHOT_DIR_NAME)
end

function GetSnapshotFolder(snapshot)
  return JoinPath(GetSnapshotsRoot(), snapshot.folder or snapshot.id)
end

function GetSnapshotDataPath(snapshot)
  return JoinPath(GetSnapshotFolder(snapshot), "snapshot.lua")
end

function GetSnapshotPreviewPath(snapshot)
  local folder = GetSnapshotFolder(snapshot)
  local mp3_path = JoinPath(folder, PREVIEW_FILE_NAME)

  -- Prefer the new compact MP3 preview format, but keep preview.wav as a legacy fallback
  -- so older snapshots can still be auditioned before they are re-saved.
  if FileExists(mp3_path) then
    return mp3_path
  end

  if snapshot and snapshot.preview and snapshot.preview ~= "" then
    local meta_path = JoinPath(folder, snapshot.preview)
    if FileExists(meta_path) then
      return meta_path
    end
  end

  local legacy_path = JoinPath(folder, LEGACY_PREVIEW_FILE_NAME)
  if FileExists(legacy_path) then
    return legacy_path
  end

  return mp3_path
end

function OpenFolder(path)
  path = NormalizePath(path)
  if reaper.CF_ShellExecute then
    reaper.CF_ShellExecute(path)
    return
  end

  if reaper.GetOS():find("Win") then
    RunShellCommand('cmd.exe /C start "" ' .. ShellQuote(path))
  elseif reaper.GetOS():find("OSX") or reaper.GetOS():find("macOS") then
    RunShellCommand('open ' .. ShellQuote(path))
  else
    RunShellCommand('xdg-open ' .. ShellQuote(path))
  end
end

function PathExists(path)
  path = NormalizePath(path)
  if path == "" then return false end
  if FileExists(path) then return true end

  local native_path = path
  if reaper.GetOS():find("Win") then
    native_path = native_path:gsub("/", "\\")
  end

  local ok, _, code = os.rename(native_path, native_path)
  if ok then return true end

  if code == 13 or code == 5 then return true end

  local command
  if reaper.GetOS():find("Win") then
    local p = native_path:gsub('"', ''):gsub("\\+$", "")
    command = 'cmd.exe /C if exist "' .. p .. '\\NUL" (echo 1) else (echo 0)'

    if reaper.ExecProcess and RunProcessHidden then
      local exec_ok, output = RunProcessHidden(command, 10000)
      if exec_ok then
        output = tostring(output or "")
        if output:match("1") then return true end
        if output:match("0") then return false end
      end
    end
  else
    command = '[ -d ' .. ShellQuote(path) .. ' ]'
  end

  local a, b, c = os.execute(command)
  if a == true then
    return c == nil or c == 0
  elseif type(a) == "number" then
    return a == 0
  elseif type(c) == "number" then
    return c == 0
  end

  return false
end

function ShellQuote(path)
  path = tostring(path or "")

  if reaper.GetOS():find("Win") then
    path = path:gsub('/', '\\')
    path = path:gsub('"', '')
    return '"' .. path .. '"'
  end

  return "'" .. path:gsub("'", [['"'"']]) .. "'"
end

function IsSnapshotFolderSafeToDelete(path)
  local folder = NormalizePath(path)
  local root = NormalizePath(GetSnapshotsRoot())

  if folder == "" or root == "" or folder == root then
    return false
  end

  if reaper.GetOS():find("Win") then
    folder = Lower(folder)
    root = Lower(root)
  end

  return folder:sub(1, #root + 1) == root .. "/"
end

function DeleteDirectoryRecursive(path)
  path = NormalizePath(path)
  if path == "" or not PathExists(path) then
    return true
  end

  if not IsSnapshotFolderSafeToDelete(path) then
    return false, "Refusing to delete a folder outside the snapshots directory."
  end

  local command
  if reaper.GetOS():find("Win") then
    command = 'rmdir /S /Q ' .. ShellQuote(path)
  else
    command = 'rm -rf -- ' .. ShellQuote(path)
  end

  RunShellCommand(command)

  if PathExists(path) then
    return false, "Failed to delete snapshot folder: " .. path
  end

  return true
end

----------------------------------------
-- Snapshot ZIP Import / Export Helpers
----------------------------------------

function IsWindowsOS()
  return reaper.GetOS():find("Win") ~= nil
end

function IsMacOS()
  local os_name = reaper.GetOS()
  return os_name:find("OSX") ~= nil or os_name:find("macOS") ~= nil
end

function PowerShellQuote(text)
  text = tostring(text or ""):gsub("/", "\\")
  text = text:gsub("'", "''")
  return "'" .. text .. "'"
end

function CommandSucceeded(a, b, c)
  if a == true then
    return c == nil or c == 0
  end

  if type(a) == "number" then
    return a == 0
  end

  if type(c) == "number" then
    return c == 0
  end

  return false
end

function ParseExecProcessResult(raw_output)
  local text = tostring(raw_output or ""):gsub("\r\n", "\n")

  local code_text, body = text:match("^(%-?%d+)\n(.*)$")
  if not code_text then
    code_text = text:match("^(%-?%d+)%s*$")
    body = ""
  end

  local code = tonumber(code_text)
  if code ~= nil then
    return code == 0, tostring(body or "")
  end

  return true, text
end

function RunProcessHidden(command, timeout_ms)
  command = tostring(command or "")
  if command == "" then return false, "", nil end

  if reaper.ExecProcess then
    local ok, raw_output = pcall(reaper.ExecProcess, command, timeout_ms or 0)
    if ok and raw_output ~= nil then
      local succeeded, output = ParseExecProcessResult(raw_output)
      return succeeded, output, raw_output
    end
  end

  return false, "", nil
end

function RunShellCommand(command)
  if reaper.ExecProcess then
    local exec_ok, output, raw_output = RunProcessHidden(command, 0)
    if raw_output ~= nil then
      return exec_ok, output
    end
  end

  local a, b, c = os.execute(command)
  return CommandSucceeded(a, b, c), a, b, c
end

function WriteUtf8BomFile(path, text)
  return WriteFile(path, "\239\187\191" .. tostring(text or ""))
end

function GetSystemTempDir()
  local temp = os.getenv("TEMP") or os.getenv("TMP") or os.getenv("TMPDIR") or ""

  if temp == "" then
    temp = JoinPath(state.library_dir ~= "" and state.library_dir or DEFAULT_LIBRARY_DIR, "temp")
  end

  temp = NormalizePath(temp)
  EnsureDir(temp)
  return temp
end

function MakeTempFilePath(prefix, ext)
  prefix = SanitizeFileName(prefix or "sfx_snapshot")
  ext = tostring(ext or "tmp")
  if not ext:match("^%.") then ext = "." .. ext end

  local temp_dir = GetSystemTempDir()
  local name = string.format(
    "%s_%s_%06d%s",
    prefix,
    os.date("%Y%m%d_%H%M%S"),
    math.random(100000, 999999),
    ext
  )

  return JoinPath(temp_dir, name)
end

function RunPowerShellScript(script_body)
  local script_path = MakeTempFilePath("sfx_snapshot_zip", ".ps1")
  if not WriteUtf8BomFile(script_path, script_body) then
    return false
  end

  local command = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ' .. ShellQuote(script_path)
  local ok = RunShellCommand(command)
  os.remove(script_path)
  return ok
end

function GetPathBaseName(path)
  path = NormalizePath(path)
  return path:match("([^/]+)$") or path
end

function EnsureZipExtension(path)
  path = NormalizePath(path)
  if path == "" then return path end
  if not path:lower():match("%.zip$") then
    path = path .. ".zip"
  end
  return path
end

function BrowseForExportZipPath(snapshot)
  if not snapshot then return nil end

  local default_name = SanitizeFileName(snapshot.name or "SFX Snapshot") .. ".zip"

  if reaper.JS_Dialog_BrowseForSaveFile then
    local ok, rv, out = pcall(
      reaper.JS_Dialog_BrowseForSaveFile,
      "Export SFX Snapshot ZIP",
      state.library_dir,
      default_name,
      "ZIP files (*.zip)\0*.zip\0All files (*.*)\0*.*\0"
    )

    if ok and rv == 1 and out and out ~= "" then
      return EnsureZipExtension(out)
    end

    if ok then return nil end
  end

  if reaper.JS_Dialog_BrowseForFolder then
    local rv, out = reaper.JS_Dialog_BrowseForFolder("Select export folder:", state.library_dir)
    if rv == 1 and out and out ~= "" then
      return JoinPath(out, default_name)
    end
    return nil
  end

  return JoinPath(state.library_dir, default_name)
end

function ZipFolder(source_folder, zip_path)
  source_folder = NormalizePath(source_folder)
  zip_path = EnsureZipExtension(zip_path)

  if source_folder == "" or not FileExists(JoinPath(source_folder, "snapshot.lua")) then
    return false, "Snapshot folder not found."
  end

  local zip_dir = GetFileDir(zip_path)
  if zip_dir ~= "" then EnsureDir(zip_dir) end
  if FileExists(zip_path) then os.remove(zip_path) end

  if IsWindowsOS() then
    local ps = table.concat({
      "$ErrorActionPreference = 'Stop'",
      "Add-Type -AssemblyName System.IO.Compression.FileSystem",
      "$source = " .. PowerShellQuote(source_folder),
      "$zip = " .. PowerShellQuote(zip_path),
      "if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }",
      "[System.IO.Compression.ZipFile]::CreateFromDirectory($source, $zip, [System.IO.Compression.CompressionLevel]::Optimal, $false)",
    }, "\n")

    local ps_ok = RunPowerShellScript(ps)
    if ps_ok and FileExists(zip_path) then
      return true, zip_path
    end

    return false, "Failed to create ZIP with PowerShell .NET ZipFile. Please check whether the export folder is writable:\n\n" .. tostring(zip_dir ~= "" and zip_dir or zip_path)
  end

  local command
  if IsMacOS() then
    command = 'ditto -c -k --sequesterRsrc --keepParent ' .. ShellQuote(source_folder) .. ' ' .. ShellQuote(zip_path)
  else
    local parent = GetFileDir(source_folder)
    local base = GetPathBaseName(source_folder)
    command = 'cd ' .. ShellQuote(parent) .. ' && zip -qry ' .. ShellQuote(zip_path) .. ' ' .. ShellQuote(base)
  end

  local ok = RunShellCommand(command)
  if not ok or not FileExists(zip_path) then
    return false, "Failed to create ZIP. On macOS it uses ditto; on Linux it requires zip."
  end

  return true, zip_path
end

function UnzipFile(zip_path, dest_dir)
  zip_path = NormalizePath(zip_path)
  dest_dir = NormalizePath(dest_dir)

  if zip_path == "" or not FileExists(zip_path) then
    return false, "ZIP file not found."
  end

  EnsureDir(dest_dir)

  if IsWindowsOS() then
    local tar_command = 'cmd /C tar.exe -xf ' .. ShellQuote(zip_path) .. ' -C ' .. ShellQuote(dest_dir)
    local tar_ok = RunShellCommand(tar_command)
    if tar_ok and FindSnapshotDataFolder(dest_dir, 4) then
      return true
    end

    local ps_dest = JoinPath(dest_dir, "_ps_unzip")
    EnsureDir(ps_dest)

    local ps = table.concat({
      "$ErrorActionPreference = 'Stop'",
      "Add-Type -AssemblyName System.IO.Compression.FileSystem",
      "$zip = " .. PowerShellQuote(zip_path),
      "$dest = " .. PowerShellQuote(ps_dest),
      "if (!(Test-Path -LiteralPath $dest)) { New-Item -ItemType Directory -Force -Path $dest | Out-Null }",
      "[System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest)",
    }, "\n")

    local ps_ok = RunPowerShellScript(ps)
    if ps_ok and FindSnapshotDataFolder(dest_dir, 5) then
      return true
    end

    return false, "Failed to extract ZIP. Tried Windows tar.exe and PowerShell .NET ZipFile."
  end

  local command
  if IsMacOS() then
    command = 'ditto -x -k ' .. ShellQuote(zip_path) .. ' ' .. ShellQuote(dest_dir)
  else
    command = 'unzip -q -o ' .. ShellQuote(zip_path) .. ' -d ' .. ShellQuote(dest_dir)
  end

  local ok = RunShellCommand(command)
  if not ok then
    return false, "Failed to extract ZIP. On macOS it uses ditto; on Linux it requires unzip."
  end

  return true
end

function FindSnapshotDataFolder(root, depth)
  root = NormalizePath(root)
  depth = tonumber(depth) or 0

  if FileExists(JoinPath(root, "snapshot.lua")) then
    return root
  end

  if depth <= 0 or not reaper.EnumerateSubdirectories then
    return nil
  end

  local i = 0
  while true do
    local sub = reaper.EnumerateSubdirectories(root, i)
    if not sub then break end

    local found = FindSnapshotDataFolder(JoinPath(root, sub), depth - 1)
    if found then return found end

    i = i + 1
  end

  return nil
end

function SnapshotIdExists(id)
  id = tostring(id or "")
  if id == "" then return false end

  for _, snapshot in ipairs(state.snapshots or {}) do
    if tostring(snapshot.id or "") == id then
      return true
    end
  end

  return false
end

function SnapshotNameExists(name)
  name = tostring(name or "")

  for _, snapshot in ipairs(state.snapshots or {}) do
    if tostring(snapshot.name or "") == name then
      return true
    end
  end

  return false
end

function MakeUniqueSnapshotName(name)
  name = SanitizeFileName(name)
  if name == "" then name = "Imported Snapshot" end

  if not SnapshotNameExists(name) then
    return name
  end

  local index = 2
  local candidate = string.format("%s (%d)", name, index)

  while SnapshotNameExists(candidate) do
    index = index + 1
    candidate = string.format("%s (%d)", name, index)
  end

  return candidate
end

function MakeUniqueSnapshotFolderName(base_name)
  base_name = SanitizeFileName(base_name)
  if base_name == "" then base_name = "Imported_Snapshot" end

  local candidate = base_name
  local index = 2

  while PathExists(JoinPath(GetSnapshotsRoot(), candidate)) do
    candidate = string.format("%s_%02d", base_name, index)
    index = index + 1
  end

  return candidate
end

function CopyDirectoryRecursive(source_folder, dest_folder)
  source_folder = NormalizePath(source_folder)
  dest_folder = NormalizePath(dest_folder)

  if source_folder == "" or not FileExists(JoinPath(source_folder, "snapshot.lua")) then
    return false, "Imported snapshot data is missing."
  end

  EnsureDir(dest_folder)

  if not reaper.EnumerateFiles or not reaper.EnumerateSubdirectories then
    return false, "REAPER file enumeration API is unavailable."
  end

  local function copy_tree(src, dst)
    EnsureDir(dst)

    local i = 0
    while true do
      local file_name = reaper.EnumerateFiles(src, i)
      if not file_name then break end

      local src_file = JoinPath(src, file_name)
      local dst_file = JoinPath(dst, file_name)
      local ok, err = CopyFileBinary(src_file, dst_file)
      if not ok then
        return false, err
      end

      i = i + 1
    end

    local j = 0
    while true do
      local sub_name = reaper.EnumerateSubdirectories(src, j)
      if not sub_name then break end

      local ok, err = copy_tree(JoinPath(src, sub_name), JoinPath(dst, sub_name))
      if not ok then return false, err end

      j = j + 1
    end

    return true
  end

  local ok, err = copy_tree(source_folder, dest_folder)
  if not ok then
    return false, err or "Failed to copy imported snapshot folder."
  end

  if not FileExists(JoinPath(dest_folder, "snapshot.lua")) then
    return false, "Failed to copy imported snapshot folder."
  end

  return true
end
function MoveOrCopySnapshotFolder(source_folder, dest_folder)
  source_folder = NormalizePath(source_folder)
  dest_folder = NormalizePath(dest_folder)

  if os.rename(source_folder, dest_folder) then
    return true
  end

  return CopyDirectoryRecursive(source_folder, dest_folder)
end

----------------------------------------
-- Settings
----------------------------------------

function LoadSettings()
  local lib = reaper.GetExtState(EXT_SECTION, "library_dir")
  if lib == "" then lib = DEFAULT_LIBRARY_DIR end

  state.library_dir = NormalizePath(lib)
  state.new_library_dir = state.library_dir

  state.load_to_new_tracks = reaper.GetExtState(EXT_SECTION, "load_to_new_tracks") == "1"
  state.restore_markers = reaper.GetExtState(EXT_SECTION, "restore_markers") ~= "0"
  state.restore_tempo = reaper.GetExtState(EXT_SECTION, "restore_tempo") ~= "0"
  state.check_empty_space = reaper.GetExtState(EXT_SECTION, "check_empty_space") ~= "0"
  state.auto_render_preview = reaper.GetExtState(EXT_SECTION, "auto_render_preview") ~= "0"
  state.skip_preview_leading_empty = reaper.GetExtState(EXT_SECTION, "skip_preview_leading_empty") ~= "0"
  state.info_panel_at_bottom = reaper.GetExtState(EXT_SECTION, "info_panel_at_bottom") ~= "0"

  local sort_order = reaper.GetExtState(EXT_SECTION, "sort_order")
  if sort_order == "oldest" or sort_order == "alphabetical" or sort_order == "newest" then
    state.sort_order = sort_order
  else
    state.sort_order = "newest"
  end

  local bottom_ratio = tonumber(reaper.GetExtState(EXT_SECTION, "bottom_split_ratio"))
  if bottom_ratio then state.bottom_split_ratio = bottom_ratio end

  local side_ratio = tonumber(reaper.GetExtState(EXT_SECTION, "side_split_ratio"))
  if side_ratio then state.side_split_ratio = side_ratio end
end

function SaveSettings()
  reaper.SetExtState(EXT_SECTION, "library_dir", state.library_dir, true)
  reaper.SetExtState(EXT_SECTION, "load_to_new_tracks", state.load_to_new_tracks and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "restore_markers", state.restore_markers and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "restore_tempo", state.restore_tempo and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "check_empty_space", state.check_empty_space and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "auto_render_preview", state.auto_render_preview and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "skip_preview_leading_empty", state.skip_preview_leading_empty and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "info_panel_at_bottom", state.info_panel_at_bottom and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "sort_order", tostring(state.sort_order or "newest"), true)
  reaper.SetExtState(EXT_SECTION, "bottom_split_ratio", tostring(state.bottom_split_ratio or 0.72), true)
  reaper.SetExtState(EXT_SECTION, "side_split_ratio", tostring(state.side_split_ratio or 0.64), true)
end

----------------------------------------
-- Index
----------------------------------------

function GetSnapshotSortTime(snapshot)
  return tostring((snapshot and (snapshot.updated_at or snapshot.created_at)) or "")
end

function SortSnapshots()
  local selected_id = nil
  if state.snapshots[state.selected] then
    selected_id = state.snapshots[state.selected].id
  end

  local sort_order = state.sort_order or "newest"

  table.sort(state.snapshots, function(a, b)
    if sort_order == "oldest" then
      local at = GetSnapshotSortTime(a)
      local bt = GetSnapshotSortTime(b)
      if at == bt then return Lower(a.name or "") < Lower(b.name or "") end
      return at < bt
    elseif sort_order == "alphabetical" then
      local an = Lower(a.name or "")
      local bn = Lower(b.name or "")
      if an == bn then return GetSnapshotSortTime(a) > GetSnapshotSortTime(b) end
      return an < bn
    end

    local at = GetSnapshotSortTime(a)
    local bt = GetSnapshotSortTime(b)
    if at == bt then return Lower(a.name or "") < Lower(b.name or "") end
    return at > bt
  end)

  if selected_id then
    for i, snapshot in ipairs(state.snapshots) do
      if snapshot.id == selected_id then
        state.selected = i
        break
      end
    end
  end

  if state.selected > #state.snapshots then state.selected = #state.snapshots end
  if state.selected < 1 then state.selected = 1 end
end

function LoadIndex()
  EnsureDir(state.library_dir)
  EnsureDir(GetSnapshotsRoot())

  local index = LoadLuaTable(GetIndexPath())
  if type(index) ~= "table" then
    state.snapshots = {}
    return
  end

  state.snapshots = index.snapshots or {}
  SortSnapshots()
end

function SaveIndex()
  EnsureDir(state.library_dir)
  EnsureDir(GetSnapshotsRoot())

  local index = {
    version = SCRIPT_VERSION,
    updated_at = os.date("%Y-%m-%d %H:%M:%S"),
    snapshots = state.snapshots,
  }

  return SaveLuaTable(GetIndexPath(), index)
end

----------------------------------------
-- Razor Edit
----------------------------------------

function ParseRazorEditString(str, out)
  str = tostring(str or "")

  for start_text, end_text in str:gmatch('([%-%d%.]+)%s+([%-%d%.]+)%s+"[^"]*"') do
    local s = tonumber(start_text)
    local e = tonumber(end_text)
    if s and e and e > s then
      out[#out + 1] = { start_pos = s, end_pos = e }
    end
  end
end

function GetRazorContext()
  local track_count = reaper.CountTracks(0)

  local track_ranges = {}
  local all_ranges = {}

  local min_track = math.huge
  local max_track = -1

  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    local ok, razor = reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", "", false)

    if ok and razor ~= "" then
      local ranges = {}
      ParseRazorEditString(razor, ranges)

      if #ranges > 0 then
        track_ranges[#track_ranges + 1] = {
          track = track,
          track_index = i,
          ranges = ranges,
        }

        min_track = math.min(min_track, i)
        max_track = math.max(max_track, i)

        for _, r in ipairs(ranges) do
          all_ranges[#all_ranges + 1] = {
            start_pos = r.start_pos,
            end_pos = r.end_pos,
          }
        end
      end
    end
  end

  if #all_ranges == 0 then return nil end

  table.sort(all_ranges, function(a, b)
    if a.start_pos == b.start_pos then return a.end_pos < b.end_pos end
    return a.start_pos < b.start_pos
  end)

  local start_pos = all_ranges[1].start_pos
  local end_pos = all_ranges[1].end_pos

  for _, r in ipairs(all_ranges) do
    start_pos = math.min(start_pos, r.start_pos)
    end_pos = math.max(end_pos, r.end_pos)
  end

  return {
    mode = "razor",
    mode_label = "Razor Edit",
    track_ranges = track_ranges,
    all_ranges = all_ranges,
    start_pos = start_pos,
    end_pos = end_pos,
    duration = end_pos - start_pos,
    min_track = min_track,
    max_track = max_track,
    track_count = max_track - min_track + 1,
  }
end

function ItemOverlapsRangeByTime(item, start_pos, end_pos)
  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = item_pos + item_len
  return item_pos < end_pos and item_end > start_pos
end

function TrackHasItemsInRange(track, start_pos, end_pos)
  local item_count = reaper.CountTrackMediaItems(track)

  for i = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    if item and ItemOverlapsRangeByTime(item, start_pos, end_pos) then
      return true
    end
  end

  return false
end

function GetTimeSelectionContext()
  local start_pos, end_pos = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

  if not start_pos or not end_pos or end_pos <= start_pos then
    return nil
  end

  local track_count = reaper.CountTracks(0)
  local track_ranges = {}
  local min_track = math.huge
  local max_track = -1

  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)

    if track and TrackHasItemsInRange(track, start_pos, end_pos) then
      track_ranges[#track_ranges + 1] = {
        track = track,
        track_index = i,
        ranges = {
          {
            start_pos = start_pos,
            end_pos = end_pos,
          }
        },
      }

      min_track = math.min(min_track, i)
      max_track = math.max(max_track, i)
    end
  end

  -- Allow marker / region / tempo-only snapshots.
  -- If there are no media items in the time selection, use the selected track as a harmless anchor.
  if min_track == math.huge then
    local selected_track = reaper.GetSelectedTrack(0, 0)
    if selected_track then
      local n = reaper.GetMediaTrackInfo_Value(selected_track, "IP_TRACKNUMBER")
      min_track = math.max(0, math.floor(n - 1))
    else
      min_track = 0
    end
    max_track = min_track
  end

  return {
    mode = "time_selection",
    mode_label = "Time Selection",
    track_ranges = track_ranges,
    all_ranges = {
      {
        start_pos = start_pos,
        end_pos = end_pos,
      }
    },
    start_pos = start_pos,
    end_pos = end_pos,
    duration = end_pos - start_pos,
    min_track = min_track,
    max_track = max_track,
    track_count = math.max(1, max_track - min_track + 1),
  }
end

function GetSmartCaptureContext()
  local razor_context = GetRazorContext()
  if razor_context then return razor_context end

  local time_selection_context = GetTimeSelectionContext()
  if time_selection_context then return time_selection_context end

  return nil
end

function PositionInRanges(pos, ranges)
  for _, r in ipairs(ranges or {}) do
    if pos >= r.start_pos and pos <= r.end_pos then
      return true
    end
  end
  return false
end

function RangeOverlaps(a1, a2, b1, b2)
  return a1 < b2 and a2 > b1
end

function ItemOverlapsRanges(item, ranges)
  local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = pos + len

  for _, r in ipairs(ranges or {}) do
    if RangeOverlaps(pos, item_end, r.start_pos, r.end_pos) then
      return true
    end
  end

  return false
end

----------------------------------------
-- Chunk Helpers
----------------------------------------

function GetItemChunk(item)
  local ok, chunk = reaper.GetItemStateChunk(item, "", false)
  if ok then return chunk end
end

function SetItemChunk(item, chunk)
  return reaper.SetItemStateChunk(item, chunk, false)
end

function GetTrackChunk(track)
  local ok, chunk = reaper.GetTrackStateChunk(track, "", false)
  if ok then return chunk end
end

function SetTrackChunk(track, chunk)
  return reaper.SetTrackStateChunk(track, chunk, false)
end

function StripItemsFromTrackChunk(chunk)
  local lines = {}
  for line in tostring(chunk or ""):gmatch("[^\r\n]+") do
    lines[#lines + 1] = line
  end

  local out = {}
  local skipping_item = false
  local depth = 0

  for _, line in ipairs(lines) do
    local trimmed = line:match("^%s*(.-)%s*$")

    if not skipping_item and trimmed:find("^<ITEM") then
      skipping_item = true
      depth = 1
    elseif skipping_item then
      if trimmed:find("^<") then depth = depth + 1 end
      if trimmed == ">" then
        depth = depth - 1
        if depth <= 0 then
          skipping_item = false
        end
      end
    else
      out[#out + 1] = line
    end
  end

  return table.concat(out, "\n") .. "\n"
end

function AdjustItemChunkPosition(chunk, source_start, target_start)
  local offset = target_start - source_start

  chunk = tostring(chunk or ""):gsub("POSITION%s+([%-%d%.]+)", function(v)
    local n = tonumber(v) or 0
    return "POSITION " .. string.format("%.15f", n + offset)
  end)

  return chunk
end

----------------------------------------
-- Marker / Region / Tempo
----------------------------------------

function CollectMarkers(ctx_data)
  local markers = {}
  local total = select(1, reaper.CountProjectMarkers(0)) or 0

  for i = 0, total - 1 do
    local ok, is_region, pos, rgn_end, name, marker_index, color = reaper.EnumProjectMarkers3(0, i)

    if ok then
      local include = false

      if is_region then
        for _, r in ipairs(ctx_data.all_ranges) do
          if pos >= r.start_pos and rgn_end <= r.end_pos then
            include = true
            break
          end
        end
      else
        include = PositionInRanges(pos, ctx_data.all_ranges)
      end

      if include then
        markers[#markers + 1] = {
          is_region = is_region,
          pos = pos - ctx_data.start_pos,
          rgn_end = is_region and (rgn_end - ctx_data.start_pos) or 0,
          name = name or "",
          color = color or 0,
        }
      end
    end
  end

  return markers
end

function CollectTempo(ctx_data)
  local tempo = {}
  local count = reaper.CountTempoTimeSigMarkers(0)

  for i = 0, count - 1 do
    local ok, time_pos, measure_pos, beat_pos, bpm, ts_num, ts_denom, linear = reaper.GetTempoTimeSigMarker(0, i)

    if ok and PositionInRanges(time_pos, ctx_data.all_ranges) then
      tempo[#tempo + 1] = {
        pos = time_pos - ctx_data.start_pos,
        bpm = bpm,
        ts_num = ts_num,
        ts_denom = ts_denom,
        linear = linear,
      }
    end
  end

  return tempo
end

function RestoreMarkers(markers, target_pos)
  for _, m in ipairs(markers or {}) do
    local pos = target_pos + (tonumber(m.pos) or 0)
    local rgn_end = target_pos + (tonumber(m.rgn_end) or 0)
    reaper.AddProjectMarker2(0, m.is_region == true, pos, rgn_end, m.name or "", -1, tonumber(m.color) or 0)
  end
end

function RestoreTempo(tempo, target_pos)
  for _, t in ipairs(tempo or {}) do
    local pos = target_pos + (tonumber(t.pos) or 0)
    reaper.SetTempoTimeSigMarker(
      0,
      -1,
      pos,
      -1,
      -1,
      tonumber(t.bpm) or 120,
      tonumber(t.ts_num) or 4,
      tonumber(t.ts_denom) or 4,
      t.linear == true
    )
  end
end

----------------------------------------
-- Track / Item Capture
----------------------------------------

function CaptureSnapshotData(meta)
  local ctx_data = GetSmartCaptureContext()
  if not ctx_data then
    return nil, "No Razor Edit or time selection found. Please create a Razor Edit area or a time selection before saving."
  end

  local tracks = {}

  for _, tr in ipairs(ctx_data.track_ranges) do
    local track = tr.track
    local track_chunk = GetTrackChunk(track)

    local track_data = {
      source_track_index = tr.track_index,
      relative_track_index = tr.track_index - ctx_data.min_track,
      track_chunk = StripItemsFromTrackChunk(track_chunk or ""),
      items = {},
      ranges = {},
    }

    for _, r in ipairs(tr.ranges) do
      track_data.ranges[#track_data.ranges + 1] = {
        start_pos = r.start_pos - ctx_data.start_pos,
        end_pos = r.end_pos - ctx_data.start_pos,
      }
    end

    local item_count = reaper.CountTrackMediaItems(track)
    for i = 0, item_count - 1 do
      local item = reaper.GetTrackMediaItem(track, i)

      if item and ItemOverlapsRanges(item, tr.ranges) then
        local chunk = GetItemChunk(item)

        if chunk then
          local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
          local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

          track_data.items[#track_data.items + 1] = {
            position = pos - ctx_data.start_pos,
            length = len,
            chunk = chunk,
          }
        end
      end
    end

    tracks[#tracks + 1] = track_data
  end

  local data = {
    version = SCRIPT_VERSION,
    created_at = os.date("%Y-%m-%d %H:%M:%S"),

    meta = meta,

    capture = {
      mode = ctx_data.mode or "unknown",
      mode_label = ctx_data.mode_label or "",
      start_pos = ctx_data.start_pos,
      end_pos = ctx_data.end_pos,
      duration = ctx_data.duration,
      min_track = ctx_data.min_track,
      max_track = ctx_data.max_track,
      track_count = ctx_data.track_count,
    },

    tracks = tracks,
    markers = CollectMarkers(ctx_data),
    tempo = CollectTempo(ctx_data),
  }

  local captured_item_count = 0
  for _, tr in ipairs(tracks or {}) do
    captured_item_count = captured_item_count + #(tr.items or {})
  end

  if captured_item_count == 0 and #(data.markers or {}) == 0 and #(data.tempo or {}) == 0 then
    return nil, ctx_data.mode_label .. " contains no media items, markers, regions, or tempo/time signature markers."
  end

  return data
end

----------------------------------------
-- Restore Helpers
----------------------------------------

function GetSelectedTrackIndexOrZero()
  local track = reaper.GetSelectedTrack(0, 0)
  if not track then return 0 end

  local n = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
  return math.max(0, math.floor(n - 1))
end

function EnsureTrackCount(count)
  while reaper.CountTracks(0) < count do
    reaper.InsertTrackAtIndex(reaper.CountTracks(0), true)
  end
end

function InsertTracksAt(index, count)
  for i = 1, count do
    reaper.InsertTrackAtIndex(index + i - 1, true)
  end
end

function TrackAreaHasItems(start_track_index, track_count, start_pos, end_pos)
  local existing_tracks = reaper.CountTracks(0)

  for i = start_track_index, math.min(existing_tracks - 1, start_track_index + track_count - 1) do
    local track = reaper.GetTrack(0, i)
    if track then
      local item_count = reaper.CountTrackMediaItems(track)
      for j = 0, item_count - 1 do
        local item = reaper.GetTrackMediaItem(track, j)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        if RangeOverlaps(pos, pos + len, start_pos, end_pos) then
          return true, i + 1
        end
      end
    end
  end

  return false
end

function ClearAllRazorEdits()
  local track_count = reaper.CountTracks(0)

  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    if track then
      reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", "", true)
    end
  end
end

function RestoreTimeSelectionRange(target_pos, duration)
  duration = tonumber(duration) or 0
  if duration <= 0 then return end

  reaper.GetSet_LoopTimeRange(true, false, target_pos, target_pos + duration, false)
end

function RestoreRazorEditRange(data, start_track_index, target_pos)
  if type(data) ~= "table" then return end

  local capture = data.capture or {}
  local source_start = tonumber(capture.start_pos) or 0
  local tracks = data.tracks or {}

  ClearAllRazorEdits()

  for _, tr in ipairs(tracks) do
    local rel_index = tonumber(tr.relative_track_index) or 0
    local target_track_index = start_track_index + rel_index
    local track = reaper.GetTrack(0, target_track_index)

    if track then
      local parts = {}

      if type(tr.ranges) == "table" and #tr.ranges > 0 then
        for _, r in ipairs(tr.ranges) do
          local range_start = target_pos + (tonumber(r.start_pos) or 0)
          local range_end = target_pos + (tonumber(r.end_pos) or 0)

          if range_end > range_start then
            parts[#parts + 1] = string.format("%.15f %.15f \"\"", range_start, range_end)
          end
        end
      else
        local duration = tonumber(capture.duration) or 0
        if duration > 0 then
          parts[#parts + 1] = string.format("%.15f %.15f \"\"", target_pos, target_pos + duration)
        end
      end

      if #parts > 0 then
        reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", table.concat(parts, " "), true)
      end
    end
  end
end

function RestoreCapturedRangeState(data, start_track_index, target_pos)
  local capture = data.capture or {}
  local mode = capture.mode or "unknown"
  local duration = tonumber(capture.duration) or 0

  if mode == "time_selection" then
    ClearAllRazorEdits()
    RestoreTimeSelectionRange(target_pos, duration)
  elseif mode == "razor" then
    -- Keep the time selection unchanged for Razor snapshots and restore the Razor area itself.
    RestoreRazorEditRange(data, start_track_index, target_pos)
  end
end

function RestoreSnapshotData(data, snapshot_folder)
  if type(data) ~= "table" then
    return false, "Invalid snapshot data."
  end

  local target_pos = reaper.GetCursorPosition()
  local capture = data.capture or {}
  local duration = tonumber(capture.duration) or 0
  local track_count = tonumber(capture.track_count) or #(data.tracks or {})

  if track_count <= 0 then
    return false, "Snapshot has no tracks."
  end

  local start_track_index
  local original_track_count = reaper.CountTracks(0)
  local new_track_indices = {}

  if state.load_to_new_tracks then
    start_track_index = original_track_count
    InsertTracksAt(start_track_index, track_count)

    for i = start_track_index, start_track_index + track_count - 1 do
      new_track_indices[i] = true
    end
  else
    start_track_index = GetSelectedTrackIndexOrZero()
    EnsureTrackCount(start_track_index + track_count)

    local current_track_count = reaper.CountTracks(0)
    for i = original_track_count, current_track_count - 1 do
      new_track_indices[i] = true
    end
  end

  if state.check_empty_space and duration > 0 then
    local blocked, track_number = TrackAreaHasItems(start_track_index, track_count, target_pos, target_pos + duration)
    if blocked then
      return false, "Target area is not empty. Track " .. tostring(track_number) .. " already contains items in this range."
    end
  end

  for _, tr in ipairs(data.tracks or {}) do
    local rel_index = tonumber(tr.relative_track_index) or 0
    local target_track_index = start_track_index + rel_index
    EnsureTrackCount(target_track_index + 1)

    local track = reaper.GetTrack(0, target_track_index)
    if track then
      if new_track_indices[target_track_index] and tr.track_chunk and tr.track_chunk ~= "" then
        SetTrackChunk(track, tr.track_chunk)
      end

      for _, item_data in ipairs(tr.items or {}) do
        local item = reaper.AddMediaItemToTrack(track)
        local chunk = ResolveSnapshotMediaPathsInChunk(item_data.chunk or "", snapshot_folder)
        chunk = AdjustItemChunkPosition(chunk, capture.start_pos or 0, target_pos)
        SetItemChunk(item, chunk)
      end
    end
  end

  if state.restore_tempo then
    RestoreTempo(data.tempo, target_pos)
  end

  if state.restore_markers then
    RestoreMarkers(data.markers, target_pos)
  end

  RestoreCapturedRangeState(data, start_track_index, target_pos)

  reaper.UpdateArrange()
  return true
end

----------------------------------------
-- Preview Render
----------------------------------------

function SaveRenderSettings()
  local settings = {}

  settings.render_bounds = reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 0, false)
  settings.render_start = reaper.GetSetProjectInfo(0, "RENDER_STARTPOS", 0, false)
  settings.render_end = reaper.GetSetProjectInfo(0, "RENDER_ENDPOS", 0, false)
  settings.render_tail = reaper.GetSetProjectInfo(0, "RENDER_TAILFLAG", 0, false)

  settings.render_file_ok, settings.render_file = reaper.GetSetProjectInfo_String(0, "RENDER_FILE", "", false)
  settings.render_pattern_ok, settings.render_pattern = reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "", false)
  settings.render_format_ok, settings.render_format = reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", "", false)

  return settings
end

function RestoreRenderSettings(settings)
  if not settings then return end

  reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", settings.render_bounds or 0, true)
  reaper.GetSetProjectInfo(0, "RENDER_STARTPOS", settings.render_start or 0, true)
  reaper.GetSetProjectInfo(0, "RENDER_ENDPOS", settings.render_end or 0, true)
  reaper.GetSetProjectInfo(0, "RENDER_TAILFLAG", settings.render_tail or 0, true)

  if settings.render_file_ok then
    reaper.GetSetProjectInfo_String(0, "RENDER_FILE", settings.render_file or "", true)
  end

  if settings.render_pattern_ok then
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", settings.render_pattern or "", true)
  end

  if settings.render_format_ok then
    reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", settings.render_format or "", true)
  end
end

function SetRenderFormatMp3()
  reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", "l3pm", true)
end

function GetPreviewRenderStart(data)
  local capture = data and data.capture or {}
  local start_pos = tonumber(capture.start_pos) or 0
  local end_pos = tonumber(capture.end_pos) or start_pos

  if not state.skip_preview_leading_empty then
    return start_pos
  end

  local min_rel_pos = nil

  for _, tr in ipairs(data.tracks or {}) do
    for _, item_data in ipairs(tr.items or {}) do
      local rel_pos = tonumber(item_data.position)
      if rel_pos and (not min_rel_pos or rel_pos < min_rel_pos) then
        min_rel_pos = rel_pos
      end
    end
  end

  if not min_rel_pos then
    return start_pos
  end

  local preview_start = start_pos + math.max(0, min_rel_pos)

  if preview_start >= end_pos then
    return start_pos
  end

  return preview_start
end

function RenderPreviewMp3(snapshot_folder, start_pos, end_pos)
  if not snapshot_folder or snapshot_folder == "" then
    return false, "Invalid snapshot folder."
  end

  if not start_pos or not end_pos or end_pos <= start_pos then
    return false, "Invalid preview render range."
  end

  EnsureDir(snapshot_folder)

  local preview_path = JoinPath(snapshot_folder, PREVIEW_FILE_NAME)

  local old_settings = SaveRenderSettings()
  local old_time_sel_start, old_time_sel_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

  local ok, err = pcall(function()
    -- Always overwrite the preview file for same-name snapshot updates.
    -- Also remove the old WAV preview so updated snapshots do not keep large legacy files.
    if FileExists(preview_path) then
      os.remove(preview_path)
    end

    local legacy_preview_path = JoinPath(snapshot_folder, LEGACY_PREVIEW_FILE_NAME)
    if FileExists(legacy_preview_path) then
      os.remove(legacy_preview_path)
    end

    reaper.GetSet_LoopTimeRange(true, false, start_pos, end_pos, false)

    reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 0, true)
    reaper.GetSetProjectInfo(0, "RENDER_STARTPOS", start_pos, true)
    reaper.GetSetProjectInfo(0, "RENDER_ENDPOS", end_pos, true)
    reaper.GetSetProjectInfo(0, "RENDER_TAILFLAG", 0, true)

    -- Output: snapshot folder / preview.mp3
    reaper.GetSetProjectInfo_String(0, "RENDER_FILE", snapshot_folder, true)
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "preview", true)

    SetRenderFormatMp3()

    -- File: Render project, using the most recent render settings, auto-close render dialog
    reaper.Main_OnCommand(42230, 0)
  end)

  reaper.GetSet_LoopTimeRange(true, false, old_time_sel_start, old_time_sel_end, false)
  RestoreRenderSettings(old_settings)

  if not ok then
    return false, tostring(err)
  end

  if not FileExists(preview_path) then
    return false, "preview.mp3 was not created. Please check REAPER render action 42230 or render settings."
  end

  return true, preview_path
end

----------------------------------------
-- Save / Load Snapshot
----------------------------------------

function SaveSnapshotFromPopup()
  local name = SanitizeFileName(state.save_name)
  local category = Trim(state.save_category)
  local tags = SplitTags(state.save_tags)
  local desc = tostring(state.save_description or "")

  local existing_snapshot = nil
  local existing_index = nil

  -- Same-name save updates and overwrites the existing snapshot folder.
  for i, s in ipairs(state.snapshots) do
    if tostring(s.name or "") == name then
      existing_snapshot = s
      existing_index = i
      break
    end
  end

  local id
  local folder_name
  local created_at
  local favorite

  if existing_snapshot then
    id = existing_snapshot.id
    folder_name = existing_snapshot.folder
    created_at = existing_snapshot.created_at or os.date("%Y-%m-%d %H:%M:%S")
    favorite = existing_snapshot.favorite == true
  else
    id = MakeID()
    folder_name = SanitizeFileName(name) .. "_" .. id
    created_at = os.date("%Y-%m-%d %H:%M:%S")
    favorite = false
  end

  local meta = {
    id = id,
    name = name,
    category = category ~= "" and category or "Uncategorized",
    tags = tags,
    description = desc,
    favorite = favorite,
    folder = folder_name,
    created_at = created_at,
    updated_at = os.date("%Y-%m-%d %H:%M:%S"),
  }

  local data, err = CaptureSnapshotData(meta)
  if not data then
    state.status = err or "Capture failed."
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return
  end

  meta.capture_mode = (data.capture and data.capture.mode) or "unknown"
  meta.capture_mode_label = (data.capture and data.capture.mode_label) or ""

  local folder = JoinPath(GetSnapshotsRoot(), folder_name)
  EnsureDir(folder)

  local media_archive = ArchiveSnapshotMedia(data, folder)
  meta.media_reference_count = media_archive.reference_count or 0
  meta.media_copied_count = media_archive.copied_count or 0
  meta.media_missing_count = media_archive.missing_count or 0

  if state.auto_render_preview then
    local preview_start_pos = GetPreviewRenderStart(data)
    local preview_ok, preview_result = RenderPreviewMp3(folder, preview_start_pos, data.capture.end_pos)

    meta.preview_start_offset = math.max(0, preview_start_pos - (data.capture.start_pos or preview_start_pos))
    meta.preview_render_start = preview_start_pos
    meta.preview_render_end = data.capture.end_pos
    meta.skip_preview_leading_empty = state.skip_preview_leading_empty == true

    if preview_ok then
      meta.preview = PREVIEW_FILE_NAME
      meta.has_preview = true
      meta.preview_error = ""
    else
      meta.preview = ""
      meta.has_preview = false
      meta.preview_error = tostring(preview_result or "")
    end
  else
    meta.preview = FileExists(JoinPath(folder, PREVIEW_FILE_NAME)) and PREVIEW_FILE_NAME or (FileExists(JoinPath(folder, LEGACY_PREVIEW_FILE_NAME)) and LEGACY_PREVIEW_FILE_NAME or "")
    meta.has_preview = meta.preview ~= ""
    meta.preview_error = ""
  end

  meta.duration = data.capture.duration
  meta.track_count = data.capture.track_count
  meta.item_count = 0

  for _, tr in ipairs(data.tracks or {}) do
    meta.item_count = meta.item_count + #(tr.items or {})
  end

  data.meta = meta

  local data_path = JoinPath(folder, "snapshot.lua")
  local ok = SaveLuaTable(data_path, data)

  if not ok then
    state.status = "Failed to write snapshot file."
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return
  end

  if existing_index then
    state.snapshots[existing_index] = meta
  else
    state.snapshots[#state.snapshots + 1] = meta
  end

  SaveIndex()
  LoadIndex()

  local media_note = ""
  if meta.media_copied_count and meta.media_copied_count > 0 then
    media_note = string.format(" | Media archived: %d", meta.media_copied_count)
  end

  if meta.media_missing_count and meta.media_missing_count > 0 then
    media_note = media_note .. string.format(" | Missing media: %d", meta.media_missing_count)
  end

  if meta.has_preview then
    state.status = "Saved " .. tostring(meta.capture_mode_label or "snapshot") .. " snapshot and rendered preview: " .. name .. media_note
  else
    state.status = "Saved " .. tostring(meta.capture_mode_label or "snapshot") .. " snapshot, but preview render failed: " .. name .. media_note
  end
end

function LoadSelectedSnapshot()
  local snapshot = state.snapshots[state.selected]
  if not snapshot then
    state.status = "No snapshot selected."
    return
  end

  local data_path = GetSnapshotDataPath(snapshot)
  local data, err = LoadLuaTable(data_path)

  if not data then
    state.status = "Failed to load snapshot."
    reaper.MB("Failed to load snapshot:\n\n" .. tostring(err or data_path), SCRIPT_NAME, 0)
    return
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local ok, result_or_err = RestoreSnapshotData(data, GetSnapshotFolder(snapshot))

  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Load SFX Snapshot", -1)

  if not ok then
    state.status = result_or_err or "Load failed."
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return
  end

  state.status = "Loaded snapshot: " .. tostring(snapshot.name or "")
end

function ExportSelectedSnapshotZip()
  local snapshot = state.snapshots[state.selected]
  if not snapshot then
    state.status = "No snapshot selected."
    return
  end

  local snapshot_folder = GetSnapshotFolder(snapshot)
  if not FileExists(JoinPath(snapshot_folder, "snapshot.lua")) then
    reaper.MB("Snapshot data file not found:\n\n" .. tostring(snapshot_folder), SCRIPT_NAME, 0)
    state.status = "Export failed: snapshot data missing."
    return
  end

  local zip_path = BrowseForExportZipPath(snapshot)
  if not zip_path or zip_path == "" then
    state.status = "Export cancelled."
    return
  end

  local ok, result = ZipFolder(snapshot_folder, zip_path)
  if not ok then
    state.status = result or "Export failed."
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return
  end

  state.status = "Exported snapshot ZIP: " .. tostring(result)
  OpenFolder(GetFileDir(result))
end

function ImportSnapshotZip()
  local ok_read, zip_path = reaper.GetUserFileNameForRead("", "Import SFX Snapshot ZIP", ".zip")
  if not ok_read or not zip_path or zip_path == "" then
    state.status = "Import cancelled."
    return
  end

  zip_path = NormalizePath(zip_path)

  if not FileExists(zip_path) then
    reaper.MB("ZIP file not found:\n\n" .. tostring(zip_path), SCRIPT_NAME, 0)
    state.status = "Import failed: ZIP file missing."
    return
  end

  EnsureDir(GetSnapshotsRoot())

  local temp_dir = JoinPath(GetSnapshotsRoot(), "_import_temp_" .. MakeID())
  EnsureDir(temp_dir)

  local unzip_ok, unzip_err = UnzipFile(zip_path, temp_dir)
  if not unzip_ok then
    DeleteDirectoryRecursive(temp_dir)
    state.status = unzip_err or "Import failed."
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return
  end

  local source_folder = FindSnapshotDataFolder(temp_dir, 3)
  if not source_folder then
    DeleteDirectoryRecursive(temp_dir)
    state.status = "Import failed: snapshot.lua not found in ZIP."
    reaper.MB("This ZIP does not look like a SFX Snapshot package.\n\nsnapshot.lua was not found.", SCRIPT_NAME, 0)
    return
  end

  local data_path = JoinPath(source_folder, "snapshot.lua")
  local data, err = LoadLuaTable(data_path)
  if type(data) ~= "table" then
    DeleteDirectoryRecursive(temp_dir)
    state.status = "Import failed: invalid snapshot data."
    reaper.MB("Failed to read imported snapshot:\n\n" .. tostring(err or data_path), SCRIPT_NAME, 0)
    return
  end

  local meta = data.meta or {}
  if type(meta) ~= "table" then meta = {} end

  meta.name = MakeUniqueSnapshotName(meta.name or GetPathBaseName(source_folder) or "Imported Snapshot")

  local import_id = tostring(meta.id or "")
  if import_id == "" or SnapshotIdExists(import_id) then
    import_id = MakeID()
  end
  meta.id = import_id

  local base_folder = meta.folder or (SanitizeFileName(meta.name) .. "_" .. import_id)
  meta.folder = MakeUniqueSnapshotFolderName(base_folder)
  meta.imported_at = os.date("%Y-%m-%d %H:%M:%S")
  meta.updated_at = os.date("%Y-%m-%d %H:%M:%S")
  meta.has_preview = FileExists(JoinPath(source_folder, PREVIEW_FILE_NAME)) or FileExists(JoinPath(source_folder, LEGACY_PREVIEW_FILE_NAME))
  meta.preview = FileExists(JoinPath(source_folder, PREVIEW_FILE_NAME)) and PREVIEW_FILE_NAME or (meta.has_preview and LEGACY_PREVIEW_FILE_NAME or "")

  data.meta = meta

  local dest_folder = JoinPath(GetSnapshotsRoot(), meta.folder)
  local move_ok, move_err = MoveOrCopySnapshotFolder(source_folder, dest_folder)
  if not move_ok then
    DeleteDirectoryRecursive(temp_dir)
    state.status = move_err or "Import failed."
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return
  end

  SaveLuaTable(JoinPath(dest_folder, "snapshot.lua"), data)

  if NormalizePath(source_folder) ~= NormalizePath(temp_dir) then
    DeleteDirectoryRecursive(temp_dir)
  end

  state.snapshots[#state.snapshots + 1] = meta
  SaveIndex()
  LoadIndex()

  for i, snapshot in ipairs(state.snapshots or {}) do
    if tostring(snapshot.id or "") == import_id then
      state.selected = i
      break
    end
  end

  ResetWaveformCacheState()
  state.status = "Imported snapshot: " .. tostring(meta.name or "")
end

function SetFavorite(snapshot, favorite)
  if not snapshot then return end

  local target = favorite == true
  if snapshot.favorite == target then
    state.status = target and "Already in favorites." or "Already removed from favorites."
    return
  end

  snapshot.favorite = target
  snapshot.updated_at = os.date("%Y-%m-%d %H:%M:%S")
  -- 排序收藏夹
  -- SortSnapshots()
  -- SaveIndex()
  state.status = snapshot.favorite and "Added to favorites." or "Removed from favorites."
end

function ToggleFavorite(snapshot)
  if not snapshot then return end
  SetFavorite(snapshot, not snapshot.favorite)
end

function RemoveSelectedSnapshotFromIndex()
  local snapshot = state.snapshots[state.selected]
  if not snapshot then return end

  local folder = GetSnapshotFolder(snapshot)
  local ret = reaper.MB(
    "Remove this snapshot and delete its local folder?\n\n" ..
    tostring(snapshot.name or "") ..
    "\n\nFolder:\n" .. tostring(folder),
    SCRIPT_NAME,
    4
  )

  if ret ~= 6 then return end

  StopInternalPreview(true)

  local ok, err = DeleteDirectoryRecursive(folder)
  if not ok then
    reaper.MB(tostring(err or "Failed to delete snapshot folder."), SCRIPT_NAME, 0)
  end

  table.remove(state.snapshots, state.selected)
  if state.selected > #state.snapshots then state.selected = #state.snapshots end
  if state.selected < 1 then state.selected = 1 end
  SaveIndex()
  ResetWaveformCacheState()

  if ok then
    state.status = "Removed snapshot and deleted local folder."
  else
    state.status = "Removed from library index, but failed to delete local folder."
  end
end

----------------------------------------
-- Waveform Cache Preview
----------------------------------------

function HasWaveformCacheSupport()
  return reaper.SM_SetCacheBaseDir
    and reaper.SM_GetWaveformCachePath
    and (reaper.SM_WFC_Begin or reaper.SM_BuildWaveformCache)
end

function ResetWaveformCacheState()
  state.waveform_cache_key = ""
  state.waveform_cache_path = ""
  state.waveform_cache_job_key = ""
  state.waveform_cache_data = nil
  state.waveform_cache_building = false
  state.waveform_cache_status = ""
end

function ReadWaveformCacheFile(path)
  if not path or path == "" or not FileExists(path) then
    return nil, "Waveform cache file not found."
  end

  if not string.unpack then
    return nil, "This REAPER Lua build does not support string.unpack."
  end

  local f = io.open(path, "rb")
  if not f then
    return nil, "Failed to open waveform cache."
  end

  local header = f:read(64)
  if not header or #header < 64 then
    f:close()
    return nil, "Invalid waveform cache header."
  end

  if header:sub(1, 4) ~= "SMWF" then
    f:close()
    return nil, "Invalid waveform cache magic."
  end

  local ok, version, pixel_cnt, channels, win_len = pcall(function()
    local pos = 5
    local v; v, pos = string.unpack("<I4", header, pos)
    local px; px, pos = string.unpack("<I4", header, pos)
    local ch; ch, pos = string.unpack("<I4", header, pos)
    local wl; wl, pos = string.unpack("<d", header, pos)
    return v, px, ch, wl
  end)

  if not ok then
    f:close()
    return nil, "Failed to parse waveform cache header."
  end

  pixel_cnt = tonumber(pixel_cnt) or 0
  channels = tonumber(channels) or 0
  win_len = tonumber(win_len) or 0

  if version ~= 1 or pixel_cnt <= 0 or channels <= 0 or win_len <= 0 then
    f:close()
    return nil, "Unsupported waveform cache data."
  end

  local need = pixel_cnt * channels * 2 * 4
  local data = f:read(need)
  f:close()

  if not data or #data < need then
    return nil, "Incomplete waveform cache data."
  end

  local mins = {}
  local maxs = {}
  local max_abs = 0.0
  local pos = 1

  for i = 1, pixel_cnt do
    local row_min = 1.0
    local row_max = -1.0

    for _ = 1, channels do
      local vmin, vmax
      vmin, pos = string.unpack("<f", data, pos)
      vmax, pos = string.unpack("<f", data, pos)

      vmin = tonumber(vmin) or 0
      vmax = tonumber(vmax) or 0

      if vmin < row_min then row_min = vmin end
      if vmax > row_max then row_max = vmax end
    end

    if row_min > row_max then
      row_min, row_max = 0.0, 0.0
    end

    mins[i] = row_min
    maxs[i] = row_max
    max_abs = math.max(max_abs, math.abs(row_min), math.abs(row_max))
  end

  return {
    path = path,
    version = version,
    pixel_cnt = pixel_cnt,
    channels = channels,
    win_len = win_len,
    mins = mins,
    maxs = maxs,
    max_abs = max_abs,
  }
end

function GetSelectedSnapshotWaveformKey(snapshot, preview_path)
  if not snapshot or not preview_path then return "" end
  return table.concat({
    tostring(snapshot.id or ""),
    tostring(snapshot.folder or ""),
    tostring(snapshot.updated_at or ""),
    tostring(preview_path or ""),
  }, "|")
end

function StartOrPumpWaveformCache(snapshot)
  if not snapshot then
    ResetWaveformCacheState()
    return nil
  end

  local preview_path = GetSnapshotPreviewPath(snapshot)
  local snapshot_folder = GetSnapshotFolder(snapshot)
  local cache_key = GetSelectedSnapshotWaveformKey(snapshot, preview_path)

  if state.waveform_cache_key ~= cache_key then
    state.waveform_cache_key = cache_key
    state.waveform_cache_path = ""
    state.waveform_cache_job_key = ""
    state.waveform_cache_data = nil
    state.waveform_cache_building = false
    state.waveform_cache_status = ""
  end

  if state.waveform_cache_data then
    return state.waveform_cache_data
  end

  if not FileExists(preview_path) then
    state.waveform_cache_status = "No preview file found for waveform display."
    return nil
  end

  if not HasWaveformCacheSupport() then
    state.waveform_cache_status = "Waveform cache extension is not available."
    return nil
  end

  EnsureDir(snapshot_folder)
  pcall(reaper.SM_SetCacheBaseDir, snapshot_folder)

  local ok_existing, existing_path = pcall(
    reaper.SM_GetWaveformCachePath,
    preview_path,
    WAVEFORM_CACHE_PIXELS,
    0.0,
    0.0,
    WAVEFORM_CACHE_MAX_CHANNELS
  )

  if ok_existing and existing_path and existing_path ~= "" and FileExists(existing_path) then
    local data, err = ReadWaveformCacheFile(existing_path)
    if data then
      state.waveform_cache_path = existing_path
      state.waveform_cache_data = data
      state.waveform_cache_building = false
      state.waveform_cache_status = ""
      return data
    end

    state.waveform_cache_status = err or "Failed to read waveform cache."
  end

  if state.waveform_cache_job_key ~= "" and reaper.SM_WFC_Pump and reaper.SM_WFC_GetPathIfReady then
    pcall(reaper.SM_WFC_Pump, state.waveform_cache_job_key, 800, 1.5)

    local ok_ready, ready_path = pcall(reaper.SM_WFC_GetPathIfReady, state.waveform_cache_job_key)
    if ok_ready and ready_path and ready_path ~= "" and FileExists(ready_path) then
      local data, err = ReadWaveformCacheFile(ready_path)
      if data then
        state.waveform_cache_path = ready_path
        state.waveform_cache_data = data
        state.waveform_cache_building = false
        state.waveform_cache_status = ""
        return data
      end

      state.waveform_cache_status = err or "Failed to read waveform cache."
    else
      state.waveform_cache_building = true
      state.waveform_cache_status = "Building waveform cache..."
    end

    return nil
  end

  if reaper.SM_WFC_Begin and reaper.SM_WFC_Pump and reaper.SM_WFC_GetPathIfReady then
    local ok_begin, job_key = pcall(
      reaper.SM_WFC_Begin,
      preview_path,
      WAVEFORM_CACHE_PIXELS,
      0.0,
      0.0,
      WAVEFORM_CACHE_MAX_CHANNELS
    )

    if ok_begin and job_key and job_key ~= "" then
      state.waveform_cache_job_key = job_key
      state.waveform_cache_building = true
      state.waveform_cache_status = "Building waveform cache..."
      return nil
    end
  end

  if reaper.SM_BuildWaveformCache then
    local ok_build, built_path = pcall(
      reaper.SM_BuildWaveformCache,
      preview_path,
      WAVEFORM_CACHE_PIXELS,
      0.0,
      0.0,
      WAVEFORM_CACHE_MAX_CHANNELS,
      1
    )

    if ok_build and built_path and built_path ~= "" and FileExists(built_path) then
      local data, err = ReadWaveformCacheFile(built_path)
      if data then
        state.waveform_cache_path = built_path
        state.waveform_cache_data = data
        state.waveform_cache_building = false
        state.waveform_cache_status = ""
        return data
      end

      state.waveform_cache_status = err or "Failed to read waveform cache."
    else
      state.waveform_cache_status = "Failed to build waveform cache."
    end
  end

  return nil
end

function GetMediaSourceLengthSafe(source)
  if not source then return 0 end

  if reaper.GetMediaSourceLength then
    local ok, len, is_qn = pcall(reaper.GetMediaSourceLength, source)
    if ok and not is_qn and tonumber(len) and tonumber(len) > 0 then
      return tonumber(len) or 0
    end
  end

  if reaper.PCM_Source_GetLength then
    local ok, len = pcall(reaper.PCM_Source_GetLength, source)
    if ok and tonumber(len) and tonumber(len) > 0 then
      return tonumber(len) or 0
    end
  end

  return 0
end

function GetPreviewFileLength(path)
  if not path or path == "" or not FileExists(path) or not reaper.PCM_Source_CreateFromFile then
    return 0
  end

  local source = reaper.PCM_Source_CreateFromFile(path)
  if not source then return 0 end

  local len = GetMediaSourceLengthSafe(source)

  if reaper.PCM_Source_Destroy then
    pcall(reaper.PCM_Source_Destroy, source)
  end

  return len
end

----------------------------------------
-- Internal Preview Playback
----------------------------------------

function PreviewDbToVolume(db)
  db = ClampNumber(db, PREVIEW_VOLUME_MIN_DB, PREVIEW_VOLUME_MAX_DB)
  return 10 ^ (db / 20.0)
end

function GetPreviewVolumeCurve()
  local range = PREVIEW_VOLUME_MAX_DB - PREVIEW_VOLUME_MIN_DB
  if range <= 0 then return 1.0 end

  local zero_u = (0.0 - PREVIEW_VOLUME_MIN_DB) / range
  local zero_ratio = PREVIEW_VOLUME_ZERO_RATIO or 0.5

  if zero_u > 0.0 and zero_u < 1.0 and zero_ratio > 0.0 and zero_ratio < 1.0 then
    local curve = math.log(zero_ratio) / math.log(zero_u)
    if curve and curve > 0.0 then
      return curve
    end
  end

  return 1.0
end

function PreviewVolumeDbToKnobRatio(db)
  local range = PREVIEW_VOLUME_MAX_DB - PREVIEW_VOLUME_MIN_DB
  if range <= 0 then return 0.0 end

  local u = (ClampNumber(db, PREVIEW_VOLUME_MIN_DB, PREVIEW_VOLUME_MAX_DB) - PREVIEW_VOLUME_MIN_DB) / range
  u = ClampNumber(u, 0.0, 1.0)

  return ClampNumber(u ^ GetPreviewVolumeCurve(), 0.0, 1.0)
end

function PreviewVolumeKnobRatioToDb(ratio)
  ratio = ClampNumber(ratio, 0.0, 1.0)

  local curve = GetPreviewVolumeCurve()
  local u = ratio ^ (1.0 / curve)
  return PREVIEW_VOLUME_MIN_DB + u * (PREVIEW_VOLUME_MAX_DB - PREVIEW_VOLUME_MIN_DB)
end

function PreviewVolumeDbToKnobAngle(db, angle_start, angle_end)
  local ratio = PreviewVolumeDbToKnobRatio(db)
  return angle_start + (angle_end - angle_start) * ratio
end

function SetPreviewVolumeDb(db, update_text)
  db = ClampNumber(db, PREVIEW_VOLUME_MIN_DB, PREVIEW_VOLUME_MAX_DB)
  state.preview_volume_db = db

  if update_text ~= false then
    state.preview_volume_db_text = string.format("%.1f", db)
  end

  if state.preview_handle and reaper.CF_Preview_SetValue then
    pcall(reaper.CF_Preview_SetValue, state.preview_handle, "D_VOLUME", PreviewDbToVolume(db))
  end
end

function ParsePreviewVolumeDbText(text)
  text = tostring(text or "")
  text = text:gsub("，", ".")
  text = text:gsub(",", ".")
  text = text:gsub("[dD][bB]", "")
  text = text:gsub("%s+", "")

  return tonumber(text)
end

function HasInternalPreviewSupport()
  return reaper.CF_CreatePreview
    and reaper.CF_Preview_Play
    and reaper.CF_Preview_Stop
    and reaper.CF_Preview_GetValue
    and reaper.PCM_Source_CreateFromFile
end

function ResetPreviewState()
  state.preview_source = nil
  state.preview_handle = nil
  state.preview_path = ""
  state.preview_name = ""
  state.preview_position = 0
  state.preview_length = 0
  state.preview_is_playing = false
end

function StopInternalPreview(stop_preview)
  if state.preview_handle and stop_preview ~= false and reaper.CF_Preview_Stop then
    pcall(reaper.CF_Preview_Stop, state.preview_handle)
  end

  if state.preview_source and reaper.PCM_Source_Destroy then
    pcall(reaper.PCM_Source_Destroy, state.preview_source)
  end

  ResetPreviewState()
end

function GetPreviewValue(name)
  if not state.preview_handle or not reaper.CF_Preview_GetValue then
    return false, 0
  end

  local ok, retval, value = pcall(reaper.CF_Preview_GetValue, state.preview_handle, name)

  if not ok then
    return false, 0
  end

  if type(retval) == "boolean" then
    return retval, tonumber(value) or 0
  end

  if type(retval) == "number" then
    return true, retval
  end

  return false, 0
end

local PlayPreviewFile

function UpdatePreviewState()
  if not state.preview_is_playing or not state.preview_handle then
    return
  end

  local ok_pos, pos = GetPreviewValue("D_POSITION")
  local ok_len, len = GetPreviewValue("D_LENGTH")

  if ok_len and len and len > 0 then
    state.preview_length = len
  end

  local loop_enabled = state.preview_loop == true
  local loop_path = state.preview_path
  local loop_name = state.preview_name

  if ok_pos then
    state.preview_position = math.max(0, pos or 0)
  else
    StopInternalPreview(false)
    if loop_enabled and loop_path ~= "" and FileExists(loop_path) and PlayPreviewFile then
      PlayPreviewFile(loop_path, loop_name, 0)
      state.status = "Looping preview: " .. tostring(loop_name or "")
    else
      state.status = "Preview finished."
    end
    return
  end

  if state.preview_length > 0 and state.preview_position >= state.preview_length then
    StopInternalPreview(true)
    if loop_enabled and loop_path ~= "" and FileExists(loop_path) and PlayPreviewFile then
      PlayPreviewFile(loop_path, loop_name, 0)
      state.status = "Looping preview: " .. tostring(loop_name or "")
    else
      state.status = "Preview finished."
    end
  end
end

function PlayPreviewFile(path, name, start_pos)
  if not HasInternalPreviewSupport() then
    reaper.MB(
      "Internal preview playback requires the SWS extension.\\n\\n" ..
      "Please install/update SWS, then restart REAPER.",
      SCRIPT_NAME,
      0
    )
    state.status = "Internal preview requires SWS extension."
    return false
  end

  if not path or path == "" or not FileExists(path) then
    reaper.MB("Preview file not found:\\n\\n" .. tostring(path or ""), SCRIPT_NAME, 0)
    state.status = "Preview file missing."
    return false
  end

  StopInternalPreview(true)

  local source = reaper.PCM_Source_CreateFromFile(path)
  if not source then
    reaper.MB("Failed to create preview source:\\n\\n" .. tostring(path), SCRIPT_NAME, 0)
    state.status = "Failed to create preview source."
    return false
  end

  local source_len = GetMediaSourceLengthSafe(source)
  start_pos = math.max(0, tonumber(start_pos) or 0)
  if source_len > 0 then
    start_pos = math.min(start_pos, math.max(0, source_len - 0.001))
  end

  local preview = reaper.CF_CreatePreview(source)
  if not preview then
    pcall(reaper.PCM_Source_Destroy, source)
    reaper.MB("Failed to create internal preview object.", SCRIPT_NAME, 0)
    state.status = "Failed to create preview object."
    return false
  end

  if reaper.CF_Preview_SetValue then
    pcall(reaper.CF_Preview_SetValue, preview, "D_VOLUME", PreviewDbToVolume(state.preview_volume_db))
    pcall(reaper.CF_Preview_SetValue, preview, "D_FADEINLEN", 0.003)
    pcall(reaper.CF_Preview_SetValue, preview, "D_FADEOUTLEN", 0.003)
    pcall(reaper.CF_Preview_SetValue, preview, "D_POSITION", start_pos)
  end

  local played = reaper.CF_Preview_Play(preview)
  if not played then
    pcall(reaper.CF_Preview_Stop, preview)
    pcall(reaper.PCM_Source_Destroy, source)
    reaper.MB("Failed to start internal preview playback.", SCRIPT_NAME, 0)
    state.status = "Failed to start preview."
    return false
  end

  if reaper.CF_Preview_SetValue and start_pos > 0 then
    pcall(reaper.CF_Preview_SetValue, preview, "D_POSITION", start_pos)
  end

  state.preview_source = source
  state.preview_handle = preview
  state.preview_path = path
  state.preview_name = name or ""
  state.preview_position = start_pos
  state.preview_length = source_len
  state.preview_is_playing = true

  local ok_len, len = GetPreviewValue("D_LENGTH")
  if ok_len and len and len > 0 then
    state.preview_length = len
  elseif state.preview_length <= 0 then
    state.preview_length = source_len
  end

  if start_pos > 0 then
    state.status = string.format("Playing preview from %.2fs: %s", start_pos, tostring(name or ""))
  else
    state.status = "Playing preview: " .. tostring(name or "")
  end

  return true
end

function AuditionSelectedSnapshot()
  local snapshot = state.snapshots[state.selected]
  if not snapshot then return end

  local preview = GetSnapshotPreviewPath(snapshot)

  if not FileExists(preview) then
    reaper.MB(
      "No preview file found for this snapshot.\\n\\n" ..
      "You can re-save the snapshot to auto-render preview.mp3, or manually place preview.mp3 here:\\n\\n" ..
      GetSnapshotFolder(snapshot),
      SCRIPT_NAME,
      0
    )
    return
  end

  PlayPreviewFile(preview, tostring(snapshot.name or ""))
end

function SeekSelectedPreviewToRatio(ratio)
  local snapshot = state.snapshots[state.selected]
  if not snapshot then return false end

  local preview = GetSnapshotPreviewPath(snapshot)
  if not FileExists(preview) then
    state.status = "Preview file missing."
    return false
  end

  ratio = math.max(0, math.min(1, tonumber(ratio) or 0))

  local len = 0
  if state.waveform_cache_data and state.waveform_cache_data.win_len and state.waveform_cache_data.win_len > 0 then
    len = state.waveform_cache_data.win_len
  elseif state.preview_path == preview and state.preview_length and state.preview_length > 0 then
    len = state.preview_length
  else
    len = GetPreviewFileLength(preview)
  end

  if len <= 0 then
    len = tonumber(snapshot.duration) or 0
  end

  local target_pos = (len > 0) and (ratio * len) or 0
  return PlayPreviewFile(preview, tostring(snapshot.name or ""), target_pos)
end

function TogglePreviewPlayback()
  if state.preview_is_playing then
    StopInternalPreview(true)
    state.status = "Preview stopped."
  else
    AuditionSelectedSnapshot()
  end
end

----------------------------------------
-- Filters
----------------------------------------

function GetCategories()
  local set = { ["All"] = true }
  local list = { "All" }

  for _, s in ipairs(state.snapshots) do
    local c = s.category or "Uncategorized"
    if not set[c] then
      set[c] = true
      list[#list + 1] = c
    end
  end

  table.sort(list, function(a, b)
    if a == "All" then return true end
    if b == "All" then return false end
    return a < b
  end)

  return list
end

function GetAllTags()
  local set = {}
  local list = {}

  for _, s in ipairs(state.snapshots or {}) do
    if type(s.tags) == "table" then
      for _, tag in ipairs(s.tags) do
        tag = Trim(tag)
        if tag ~= "" and not set[tag] then
          set[tag] = true
          list[#list + 1] = tag
        end
      end
    end
  end

  table.sort(list, function(a, b)
    return Lower(a) < Lower(b)
  end)

  return list
end

function TagsTextContains(tag_text, tag)
  tag = Trim(tag)
  if tag == "" then return true end

  for _, existing in ipairs(SplitTags(tag_text)) do
    if Lower(existing) == Lower(tag) then
      return true
    end
  end

  return false
end

function AppendTagText(tag_text, tag)
  tag_text = Trim(tag_text or "")
  tag = Trim(tag or "")

  if tag == "" or TagsTextContains(tag_text, tag) then
    return tag_text
  end

  if tag_text == "" then
    return tag
  end

  return tag_text .. ", " .. tag
end

function DrawSelectablePopupList(popup_id, items, on_select, empty_text)
  if ImGui.BeginPopup(ctx, popup_id) then
    if #items == 0 then
      ImGui.TextDisabled(ctx, empty_text or "No existing items.")
    else
      for _, item in ipairs(items) do
        if ImGui.Selectable(ctx, tostring(item), false) then
          on_select(item)
        end
      end
    end

    ImGui.EndPopup(ctx)
  end
end

function SnapshotMatchesFilter(s)
  if state.show_favorites_only and not s.favorite then
    return false
  end

  if state.category_filter ~= "All" and tostring(s.category or "Uncategorized") ~= state.category_filter then
    return false
  end

  local f = Lower(state.filter)
  if f == "" then return true end

  local haystack = table.concat({
    s.name or "",
    s.category or "",
    JoinTags(s.tags),
    s.description or "",
  }, " "):lower()

  return haystack:find(f, 1, true) ~= nil
end

----------------------------------------
-- UI Style
----------------------------------------

function PushStyle()
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 10)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, 6)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding, 8)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabRounding, 6)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 8, 7)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding, 4)

  ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, 0x15171CFF)
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, 0x1D2027FF)
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, 0x272B34FF)
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, 0x323846FF)
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, 0x3D4658FF)

  ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x1E4F7650) -- 0x483D8B50)--0x1E4F76FF)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0x29648EFF)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0x163B59FF)

  ImGui.PushStyleColor(ctx, ImGui.Col_Header, 0x2A5C84CC)
  ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, 0x346F9FCC)
  ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive, 0x3D7FB7FF)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xE8EDF5FF)
  ImGui.PushStyleColor(ctx, ImGui.Col_TextDisabled, 0x8A93A2FF)
  ImGui.PushStyleColor(ctx, ImGui.Col_CheckMark, 0x78C7FFFF)
end

function PopStyle()
  ImGui.PopStyleColor(ctx, 14)
  ImGui.PopStyleVar(ctx, 6)
end

----------------------------------------
-- UI Drawing
----------------------------------------

function GetPreviewVolumeKnobSize()
  local knob_size = 36
  local input_w = 40
  local db_label_w = 16
  local frame_height = reaper.ImGui_GetFrameHeight(ctx) or 22
  local total_w = math.max(knob_size, input_w + db_label_w + 4)
  local total_h = knob_size + frame_height - 5 -- 音量旋钮与分割线的距离

  return total_w, total_h, knob_size, input_w
end

local preview_volume_knob_ratio_at_click = {}

function PreviewVolumeKnobRatioToAngle(ratio)
  ratio = ClampNumber(ratio, 0.0, 1.0)

  local angle_start = (2.0 / 3.0) * math.pi   -- 7 o'clock
  local angle_end   = (7.0 / 3.0) * math.pi   -- 5 o'clock

  return angle_start + (angle_end - angle_start) * ratio
end

function DrawPreviewVolumeKnobArcFallback(draw_list, cx, cy, radius, angle_start, angle_end, color, thickness)
  if not draw_list or not ImGui.DrawList_AddLine then return end

  local segments = 48
  local last_x, last_y

  for i = 0, segments do
    local t = i / segments
    local a = angle_start + (angle_end - angle_start) * t
    local x = cx + radius * math.cos(a)
    local y = cy + radius * math.sin(a)

    if last_x then
      ImGui.DrawList_AddLine(draw_list, last_x, last_y, x, y, color, thickness)
    end

    last_x, last_y = x, y
  end
end

function DrawPreviewVolumeKnobArc(draw_list, cx, cy, radius, angle_start, angle_end, color, thickness)
  if not draw_list then return end

  if ImGui.DrawList_PathArcTo and ImGui.DrawList_PathStroke then
    ImGui.DrawList_PathArcTo(draw_list, cx, cy, radius, angle_start, angle_end)
    ImGui.DrawList_PathStroke(draw_list, color, 0, thickness)
  else
    DrawPreviewVolumeKnobArcFallback(draw_list, cx, cy, radius, angle_start, angle_end, color, thickness)
  end
end

function ImGuiPreviewVolumeKnob(ctx, id, min_db, ref_db, max_db, value_db, radius, x_margin, y_margin, gutter_width)
  local changed = false
  local new_value_db = ClampNumber(value_db, min_db, max_db)

  radius = tonumber(radius) or 22
  x_margin = tonumber(x_margin) or 3
  y_margin = tonumber(y_margin) or 3
  gutter_width = tonumber(gutter_width) or 8

  local ratio = PreviewVolumeDbToKnobRatio(new_value_db)
  local angle_start = PreviewVolumeKnobRatioToAngle(0.0)
  local angle = PreviewVolumeKnobRatioToAngle(ratio)

  local item_w = 2 * (radius + x_margin)
  local item_h = 2 * (radius + y_margin)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local cx = x0 + radius + x_margin
  local cy = y0 + radius + y_margin

  ImGui.BeginGroup(ctx)

  if draw_list then
    local col_arc = 0x78C7FFFF
    local col_center = 0x78C7FF22
    local arc_thickness = math.max(1.0, gutter_width * 0.45)
    local arc_radius = math.max(1.0, radius - arc_thickness * 0.5)
    local center_radius = math.max(8, arc_thickness * 0.75)

    if ratio > 0.001 then
      DrawPreviewVolumeKnobArc(draw_list, cx, cy, arc_radius, angle_start, angle, col_arc, arc_thickness)
    end

    if ImGui.DrawList_AddCircleFilled then
      ImGui.DrawList_AddCircleFilled(draw_list, cx, cy, center_radius, col_center)
    end
  end

  ImGui.InvisibleButton(ctx, "##" .. tostring(id) .. "_invisible_button", item_w, item_h)
  local hovered = ImGui.IsItemHovered(ctx)

  if ImGui.IsItemClicked and ImGui.IsItemClicked(ctx, MOUSE_BUTTON_LEFT) then
    preview_volume_knob_ratio_at_click[id] = ratio
  end

  if hovered and ImGui.IsMouseDoubleClicked and ImGui.IsMouseDoubleClicked(ctx, MOUSE_BUTTON_LEFT) then
    new_value_db = ref_db
    changed = true
    preview_volume_knob_ratio_at_click[id] = nil
  elseif ImGui.IsMouseDragging and ImGui.IsMouseDragging(ctx, MOUSE_BUTTON_LEFT, 10) and preview_volume_knob_ratio_at_click[id] then
    local _, dy = ImGui.GetMouseDragDelta(ctx)
    local new_ratio = ClampNumber(preview_volume_knob_ratio_at_click[id] - (tonumber(dy) or 0) / 100.0, 0.0, 1.0)
    new_value_db = PreviewVolumeKnobRatioToDb(new_ratio)
    changed = true
  end

  if not (ImGui.IsMouseDown and ImGui.IsMouseDown(ctx, MOUSE_BUTTON_LEFT)) then
    preview_volume_knob_ratio_at_click[id] = nil
  end

  if hovered then
    ImGui.SetTooltip(ctx, "Preview volume: drag up/down to adjust, double-click to reset to 0 dB.")
  end

  ImGui.EndGroup(ctx)

  return changed, new_value_db
end

-- 音量旋钮
function DrawPreviewVolumeKnob()
  local total_w, total_h, knob_size, input_w = GetPreviewVolumeKnobSize()
  local start_x = ImGui.GetCursorPosX and ImGui.GetCursorPosX(ctx) or 0
  local start_y = ImGui.GetCursorPosY and ImGui.GetCursorPosY(ctx) or 0

  local radius = knob_size * 0.5 - 3
  local x_margin = 3
  local y_margin = 3
  local gutter_width = 9
  local knob_w = 2 * (radius + x_margin)
  local knob_x = start_x + math.max(0, (total_w - knob_w) * 0.5)

  if ImGui.SetCursorPosX then
    ImGui.SetCursorPosX(ctx, knob_x)
  end

  local changed, new_db = ImGuiPreviewVolumeKnob(
    ctx,
    "preview_volume",
    PREVIEW_VOLUME_MIN_DB,
    0.0,
    PREVIEW_VOLUME_MAX_DB,
    state.preview_volume_db,
    radius,
    x_margin,
    y_margin,
    gutter_width
  )

  if changed then
    SetPreviewVolumeDb(new_db, true)
  end

  -- 音量旋钮和音量输入框的间距
  local knob_input_gap = 0

  if ImGui.SetCursorPos then
    ImGui.SetCursorPos(ctx, start_x, start_y + knob_size + knob_input_gap)
  else
    if ImGui.SetCursorPosX then ImGui.SetCursorPosX(ctx, start_x) end
    if ImGui.SetCursorPosY then ImGui.SetCursorPosY(ctx, start_y + knob_size + knob_input_gap) end
  end

  local volume_input_font = font_tiny or font_small
  if volume_input_font then ImGui.PushFont(ctx, volume_input_font, 10) end -- 音量输入框字体大小

  ImGui.SetNextItemWidth(ctx, input_w)
  local text_changed, text = ImGui.InputText(ctx, "##preview_volume_db", state.preview_volume_db_text or "0.0")
  if text_changed then
    state.preview_volume_db_text = text
    local db = ParsePreviewVolumeDbText(text)
    if db then
      SetPreviewVolumeDb(db, false)
    end
  end

  local input_deactivated = ImGui.IsItemDeactivatedAfterEdit and ImGui.IsItemDeactivatedAfterEdit(ctx)

  ImGui.SameLine(ctx, nil, 3)
  ImGui.TextDisabled(ctx, "dB")

  if volume_input_font then ImGui.PopFont(ctx) end

  if input_deactivated then
    SetPreviewVolumeDb(state.preview_volume_db, true)
  end

  if ImGui.SetCursorPos then
    ImGui.SetCursorPos(ctx, start_x + total_w, start_y)
  end
end

function DrawHeader()
  local title_text = SCRIPT_NAME
  local version_text = "v" .. SCRIPT_VERSION
  local subtitle_text = "Professional modular SFX archive / restore system"
  local title_x = ImGui.GetCursorPosX and ImGui.GetCursorPosX(ctx) or 0
  local title_y = ImGui.GetCursorPosY and ImGui.GetCursorPosY(ctx) or 0
  local title_w, title_h = 0, 24

  if font_title then ImGui.PushFont(ctx, font_title, 21) end
  if reaper.ImGui_CalcTextSize then
    title_w, title_h = reaper.ImGui_CalcTextSize(ctx, title_text)
  end
  ImGui.Text(ctx, title_text)
  if font_title then ImGui.PopFont(ctx) end

  ImGui.SameLine(ctx, nil, 5)

  if font_small then ImGui.PushFont(ctx, font_small, 12) end
  local version_w, version_h = 0, 12
  if reaper.ImGui_CalcTextSize then
    version_w, version_h = reaper.ImGui_CalcTextSize(ctx, version_text)
  end

  if ImGui.SetCursorPosY then
    ImGui.SetCursorPosY(ctx, title_y + math.max(0, (title_h - version_h) * 0.5))
  end

  ImGui.TextDisabled(ctx, version_text)
  if font_small then ImGui.PopFont(ctx) end

  local knob_w, knob_h = GetPreviewVolumeKnobSize()
  ImGui.SameLine(ctx, nil, 0)

  local avail = select(1, ImGui.GetContentRegionAvail(ctx)) or 0
  if avail > knob_w then
    ImGui.Dummy(ctx, avail - knob_w, 0)
    ImGui.SameLine(ctx, nil, 0)
  end

  if ImGui.SetCursorPosY then
    ImGui.SetCursorPosY(ctx, title_y)
  end
  DrawPreviewVolumeKnob()

  local subtitle_w, subtitle_h = 0, 12
  if reaper.ImGui_CalcTextSize then
    subtitle_w, subtitle_h = reaper.ImGui_CalcTextSize(ctx, subtitle_text)
  end

  if ImGui.SetCursorPos then
    ImGui.SetCursorPos(ctx, title_x, title_y + title_h + 2)
  else
    if ImGui.SetCursorPosX then ImGui.SetCursorPosX(ctx, title_x) end
    if ImGui.SetCursorPosY then ImGui.SetCursorPosY(ctx, title_y + title_h + 2) end
  end

  if font_small then ImGui.PushFont(ctx, font_small, 12) end
  ImGui.TextDisabled(ctx, subtitle_text)
  if font_small then ImGui.PopFont(ctx) end

  local header_h = math.max(knob_h, title_h + 2 + subtitle_h)
  if ImGui.SetCursorPos then
    ImGui.SetCursorPos(ctx, title_x, title_y + header_h + 5)
  else
    if ImGui.SetCursorPosX then ImGui.SetCursorPosX(ctx, title_x) end
    if ImGui.SetCursorPosY then ImGui.SetCursorPosY(ctx, title_y + header_h + 4) end
  end

  ImGui.Separator(ctx)
end

function DrawTopBar()
  local avail_w = select(1, ImGui.GetContentRegionAvail(ctx))
  local spacing = 5

  local save_w = reaper.ImGui_CalcTextSize(ctx, " Save ")
  local load_w = reaper.ImGui_CalcTextSize(ctx, " Load ")
  local import_w = reaper.ImGui_CalcTextSize(ctx, " Import ")
  --local export_w = reaper.ImGui_CalcTextSize(ctx, "Export")
  local settings_w = reaper.ImGui_CalcTextSize(ctx, " Settings ")
  local frame_height = reaper.ImGui_GetFrameHeight(ctx)
  local button_total_w = save_w + load_w + import_w + settings_w + spacing * 5

  local search_w = avail_w - button_total_w

  if search_w >= 180 then
    ImGui.SetNextItemWidth(ctx, search_w)
    local changed, v = ImGui.InputTextWithHint(ctx, "##search", "Search name / category / tags / description...", state.filter)
    if changed then state.filter = v end

    ImGui.SameLine(ctx)

    if ImGui.Button(ctx, "Save", save_w, frame_height) then -- "Smart Save"
      state.save_name = os.date("SFX Snapshot %Y-%m-%d %H-%M-%S")
      state.save_category = "Whoosh"
      state.save_tags = ""
      state.save_description = ""
      state.show_save_popup = true
      ImGui.OpenPopup(ctx, "Save Snapshot")
    end

    ImGui.SameLine(ctx, nil, spacing)

    if ImGui.Button(ctx, "Load", load_w, frame_height) then -- "Load at Cursor"
      LoadSelectedSnapshot()
    end

    ImGui.SameLine(ctx, nil, spacing)

    if ImGui.Button(ctx, "Import", import_w, frame_height) then
      ImportSnapshotZip()
    end

    -- ImGui.SameLine(ctx, nil, spacing)

    -- if ImGui.Button(ctx, "Export", export_w, frame_height) then
    --   ExportSelectedSnapshotZip()
    -- end

    ImGui.SameLine(ctx, nil, spacing)

    if ImGui.Button(ctx, "Settings", settings_w, frame_height) then
      state.new_library_dir = state.library_dir
      state.show_settings_popup = true
      ImGui.OpenPopup(ctx, "Settings")
    end
  else
    ImGui.SetNextItemWidth(ctx, -1)
    local changed, v = ImGui.InputTextWithHint(ctx, "##search", "Search name / category / tags / description...", state.filter)
    if changed then state.filter = v end

    if ImGui.Button(ctx, "Save", save_w, frame_height) then
      state.save_name = os.date("SFX Snapshot %Y-%m-%d %H-%M-%S")
      state.save_category = "Whoosh"
      state.save_tags = ""
      state.save_description = ""
      state.show_save_popup = true
      ImGui.OpenPopup(ctx, "Save Snapshot")
    end

    ImGui.SameLine(ctx)

    if ImGui.Button(ctx, "Load", load_w, frame_height) then
      LoadSelectedSnapshot()
    end

    ImGui.SameLine(ctx)

    if ImGui.Button(ctx, "Import", import_w, frame_height) then
      ImportSnapshotZip()
    end

    ImGui.SameLine(ctx)

    if ImGui.Button(ctx, "Export", export_w, frame_height) then
      ExportSelectedSnapshotZip()
    end

    ImGui.SameLine(ctx)

    if ImGui.Button(ctx, "Settings", settings_w, frame_height) then
      state.new_library_dir = state.library_dir
      state.show_settings_popup = true
      ImGui.OpenPopup(ctx, "Settings")
    end
  end
end

function DrawFilters()
  local categories = GetCategories()

  ImGui.SetNextItemWidth(ctx, 120)
  if ImGui.BeginCombo(ctx, "Category##category", state.category_filter) then
    for _, c in ipairs(categories) do
      if ImGui.Selectable(ctx, c, state.category_filter == c) then
        state.category_filter = c
      end
    end
    ImGui.EndCombo(ctx)
  end

  ImGui.SameLine(ctx)

  local changed, fav = ImGui.Checkbox(ctx, "Favorites", state.show_favorites_only)
  if changed then state.show_favorites_only = fav end

  ImGui.SameLine(ctx)

  local changed2, v2 = ImGui.Checkbox(ctx, "New tracks", state.load_to_new_tracks)
  if changed2 then
    state.load_to_new_tracks = v2
    SaveSettings()
  end
end

function DrawWaveformCachePreviewBar()
  local snapshot = state.snapshots[state.selected]

  if not snapshot then
    ImGui.TextDisabled(ctx, "No snapshot selected.")
    return
  end

  local preview_path = GetSnapshotPreviewPath(snapshot)
  local waveform_data = StartOrPumpWaveformCache(snapshot)
  local is_selected_preview_playing = state.preview_is_playing and NormalizePath(state.preview_path) == NormalizePath(preview_path)

  local pos = is_selected_preview_playing and (tonumber(state.preview_position) or 0) or 0
  local len = 0
  if waveform_data and waveform_data.win_len and waveform_data.win_len > 0 then
    len = waveform_data.win_len
  elseif is_selected_preview_playing and state.preview_length and state.preview_length > 0 then
    len = state.preview_length
  else
    len = tonumber(snapshot.duration) or 0
  end

  local wave_w = select(1, ImGui.GetContentRegionAvail(ctx))
  wave_w = math.max(80, tonumber(wave_w) or 80)
  local wave_h = 56
  local x, y = ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(ctx, "##selected_snapshot_waveform", wave_w, wave_h)
  local hovered = ImGui.IsItemHovered(ctx)
  local clicked = ImGui.IsItemClicked and ImGui.IsItemClicked(ctx, MOUSE_BUTTON_LEFT)

  local draw_list = ImGui.GetWindowDrawList(ctx)
  if draw_list and ImGui.DrawList_AddRectFilled then
    ImGui.DrawList_AddRectFilled(draw_list, x, y, x + wave_w, y + wave_h, 0x111318FF)
  end

  if waveform_data and waveform_data.mins and waveform_data.maxs and ImGui.DrawList_AddLine then
    local px = waveform_data.pixel_cnt or #waveform_data.mins
    local columns = math.max(1, math.min(px, math.floor(wave_w)))
    local center_y = y + wave_h * 0.5
    local amp_h = math.max(1, wave_h * 0.42)
    local norm = math.max(0.000001, tonumber(waveform_data.max_abs) or 0.000001)

    for c = 0, columns - 1 do
      local first = math.floor((c * px) / columns) + 1
      local last = math.floor(((c + 1) * px) / columns)
      if last < first then last = first end

      local mn = 1.0
      local mx = -1.0
      for i = first, last do
        local a = waveform_data.mins[i] or 0
        local b = waveform_data.maxs[i] or 0
        if a < mn then mn = a end
        if b > mx then mx = b end
      end

      if mn > mx then mn, mx = 0.0, 0.0 end

      local lx = x + (c + 0.5) * wave_w / columns
      local y1 = center_y - (mx / norm) * amp_h
      local y2 = center_y - (mn / norm) * amp_h
      if y2 - y1 < 1 then
        y1 = center_y - 0.5
        y2 = center_y + 0.5
      end

      ImGui.DrawList_AddLine(draw_list, lx, y1, lx, y2, 0x78C7FFFF, 1.0)
    end
  else
    local msg = state.waveform_cache_status ~= "" and state.waveform_cache_status or "Waveform preview unavailable."
    if draw_list and ImGui.DrawList_AddText then
      ImGui.DrawList_AddText(draw_list, x + 10, y + 20, 0x8A93A2FF, msg)
    else
      ImGui.TextDisabled(ctx, msg)
    end
  end

  if draw_list and ImGui.DrawList_AddLine then
    local center_y = y + wave_h * 0.5
    ImGui.DrawList_AddLine(draw_list, x, center_y, x + wave_w, center_y, 0xFFFFFF22, 1.0)
  end

  local cursor_ratio = 0
  if is_selected_preview_playing and len > 0 then
    cursor_ratio = math.max(0, math.min(1, pos / len))
  end

  if draw_list and ImGui.DrawList_AddLine then
    local cursor_x = x + cursor_ratio * wave_w
    ImGui.DrawList_AddLine(draw_list, cursor_x, y, cursor_x, y + wave_h, 0xFFFFFFFF, 2.0)
  end

  if draw_list and ImGui.DrawList_AddText then
    ImGui.DrawList_AddText(draw_list, x + 8, y + 6, 0xD7DEE9FF, string.format("%.2f / %.2f s", pos, len))
  end

  if clicked then
    local mx = select(1, ImGui.GetMousePos(ctx))
    local ratio = (tonumber(mx) or x) - x
    ratio = ratio / math.max(1, wave_w)
    SeekSelectedPreviewToRatio(ratio)
  end

  if hovered then
    ImGui.SetTooltip(ctx, "Click the waveform to play from that position.")
  end

  local play_w = reaper.ImGui_CalcTextSize(ctx, " Play ")
  local loop_w = reaper.ImGui_CalcTextSize(ctx, " Loop Off ")
  local frame_height = reaper.ImGui_GetFrameHeight(ctx)
  local spacing = 5
  local cursor_x = ImGui.GetCursorPosX and ImGui.GetCursorPosX(ctx) or 0
  local controls_w = play_w + spacing + loop_w
  local controls_x = cursor_x + math.max(0, (wave_w - controls_w) * 0.5)

  if ImGui.SetCursorPosX then
    ImGui.SetCursorPosX(ctx, controls_x)
  end

  local btn_label = is_selected_preview_playing and "Stop" or "Play"
  if ImGui.Button(ctx, btn_label, play_w, frame_height) then
    if is_selected_preview_playing then
      StopInternalPreview(true)
      state.status = "Preview stopped."
    else
      PlayPreviewFile(preview_path, tostring(snapshot.name or ""), 0)
    end
  end

  ImGui.SameLine(ctx, nil, spacing)

  local loop_label = state.preview_loop and "Loop On" or "Loop Off"
  if ImGui.Button(ctx, loop_label, loop_w, frame_height) then
    state.preview_loop = not state.preview_loop
    state.status = state.preview_loop and "Preview loop enabled." or "Preview loop disabled."
  end
end

function DrawSnapshotList(width, height)
  width = width or 0
  height = height or -165
  local child_visible = ImGui.BeginChild(ctx, "SnapshotList", width, height, CHILD_FLAGS_BORDER)

  state.snapshot_list_focused = false

  if child_visible then
    if ImGui.IsWindowFocused and ImGui.IsWindowFocused(ctx) then
      state.snapshot_list_focused = true
    end

    local visible_count = 0
    local list_changed = false

    for i, s in ipairs(state.snapshots) do
      if SnapshotMatchesFilter(s) then
        visible_count = visible_count + 1

        local fav = s.favorite and "★ " or "☆ "
        local source = s.capture_mode == "time_selection" and " [TS]" or ""
        local name = fav .. tostring(s.name or "Unnamed") .. source
        local label = name .. "##snapshot_" .. tostring(i)

        local selected = state.selected == i
        if ImGui.Selectable(ctx, label, selected) then
          state.selected = i
          state.snapshot_list_focused = true
        end

        if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked and ImGui.IsMouseDoubleClicked(ctx, MOUSE_BUTTON_LEFT) then
          state.selected = i
          AuditionSelectedSnapshot()
        end

        if ImGui.IsItemClicked and ImGui.IsItemClicked(ctx, MOUSE_BUTTON_RIGHT) then
          state.selected = i
          state.snapshot_list_focused = true
        end

        if ImGui.BeginPopupContextItem and ImGui.BeginPopupContextItem(ctx, "snapshot_context_" .. tostring(i)) then
          state.selected = i

          if ImGui.MenuItem(ctx, s.favorite and "Remove Favorite" or "Add Favorite") then
            ToggleFavorite(s)
            list_changed = true
          end

          if ImGui.MenuItem(ctx, "Open Folder") then
            OpenFolder(GetSnapshotFolder(s))
          end

          if ImGui.MenuItem(ctx, "Export ZIP") then
            ExportSelectedSnapshotZip()
          end

          ImGui.Separator(ctx)

          if ImGui.MenuItem(ctx, "Remove") then
            RemoveSelectedSnapshotFromIndex()
            list_changed = true
          end

          ImGui.EndPopup(ctx)
        end

        if list_changed then
          break
        end

        if ImGui.IsItemHovered(ctx) then
          ImGui.BeginTooltip(ctx)
          ImGui.Text(ctx, tostring(s.name or ""))
          ImGui.Separator(ctx)
          ImGui.Text(ctx, "Category: " .. tostring(s.category or "Uncategorized"))
          ImGui.Text(ctx, "Source: " .. tostring(s.capture_mode_label or s.capture_mode or ""))
          ImGui.Text(ctx, "Tags: " .. JoinTags(s.tags))
          ImGui.Text(ctx, string.format("Duration: %.3f s", tonumber(s.duration) or 0))
          ImGui.Text(ctx, "Tracks: " .. tostring(s.track_count or 0))
          ImGui.Text(ctx, "Items: " .. tostring(s.item_count or 0))
          ImGui.Text(ctx, "Media archived: " .. tostring(s.media_copied_count or 0))
          if tonumber(s.media_missing_count or 0) and tonumber(s.media_missing_count or 0) > 0 then
            ImGui.Text(ctx, "Missing media: " .. tostring(s.media_missing_count or 0))
          end
          ImGui.Text(ctx, "Created: " .. tostring(s.created_at or ""))

          if s.has_preview then
            ImGui.Text(ctx, "Preview: " .. tostring(s.preview or PREVIEW_FILE_NAME))
            if tonumber(s.preview_start_offset or 0) and tonumber(s.preview_start_offset or 0) > 0 then
              ImGui.Text(ctx, string.format("Preview skip: %.3f s", tonumber(s.preview_start_offset) or 0))
            end
          else
            ImGui.TextDisabled(ctx, "Preview: missing")
            if s.preview_error and s.preview_error ~= "" then
              ImGui.TextWrapped(ctx, "Preview error: " .. tostring(s.preview_error))
            end
          end

          if s.description and s.description ~= "" then
            ImGui.Separator(ctx)
            ImGui.TextWrapped(ctx, s.description)
          end
          ImGui.EndTooltip(ctx)
        end
      end
    end

    if visible_count == 0 then
      ImGui.TextDisabled(ctx, "No snapshots found.")
    end
    ImGui.EndChild(ctx)
  end
end

function DrawInfoPanel(width, height)
  width = width or 0
  height = height or 150
  local child_visible = ImGui.BeginChild(ctx, "InfoPanel", width, height, CHILD_FLAGS_BORDER)

  if child_visible then
    local s = state.snapshots[state.selected]

    if not s then
      ImGui.TextDisabled(ctx, "No snapshot selected.")
    else
      local frame_height = reaper.ImGui_GetFrameHeight(ctx)
      ImGui.Text(ctx, tostring(s.name or "Unnamed"))

      ImGui.SameLine(ctx, nil, 5)
      if ImGui.SmallButton(ctx, s.favorite and "★ Favorite " or " ☆ Favorite") then
        ToggleFavorite(s)
      end

      ImGui.SameLine(ctx, nil, 5)
      if ImGui.SmallButton(ctx, "Open Folder") then
        OpenFolder(GetSnapshotFolder(s))
      end

      ImGui.SameLine(ctx, nil, 5)
      if ImGui.SmallButton(ctx, "Export ZIP") then
        ExportSelectedSnapshotZip()
      end

      -- ImGui.SameLine(ctx, nil, 5)
      -- if ImGui.SmallButton(ctx, "Remove") then
      --   RemoveSelectedSnapshotFromIndex()
      -- end

      ImGui.TextDisabled(ctx, "Category: " .. tostring(s.category or "Uncategorized"))
      ImGui.TextDisabled(ctx, "Source: " .. tostring(s.capture_mode_label or s.capture_mode or ""))
      ImGui.TextDisabled(ctx, "Tags: " .. JoinTags(s.tags))
      ImGui.TextDisabled(ctx, string.format(
        "Duration %.3fs    Tracks %d    Items %d    Media %d",
        tonumber(s.duration) or 0,
        tonumber(s.track_count) or 0,
        tonumber(s.item_count) or 0,
        tonumber(s.media_copied_count) or 0
      ))

      if tonumber(s.media_missing_count or 0) and tonumber(s.media_missing_count or 0) > 0 then
        ImGui.TextDisabled(ctx, "Missing media: " .. tostring(s.media_missing_count or 0))
      end
      if s.description and s.description ~= "" then
        ImGui.TextWrapped(ctx, s.description)
      end
    end

    ImGui.Dummy(ctx, 0, 5) -- 5 像素间隔
    ImGui.Separator(ctx)
    ImGui.Dummy(ctx, 0, 5)
    ImGui.TextDisabled(ctx, state.status or "")
    ImGui.EndChild(ctx)
  end
end

function DrawSavePopup()
  if ImGui.BeginPopupModal(ctx, "Save Snapshot", nil, ImGui.WindowFlags_AlwaysAutoResize) then
    ImGui.Text(ctx, "Smart save: Razor Edit has priority. If no Razor Edit exists, the current time selection will be captured.")
    ImGui.Separator(ctx)

    ImGui.SetNextItemWidth(ctx, 420)
    local changed, v = ImGui.InputText(ctx, "Name", state.save_name)
    if changed then state.save_name = v end

    ImGui.SetNextItemWidth(ctx, 420)
    local changed2, v2 = ImGui.InputText(ctx, "##CategoryInput", state.save_category)
    if changed2 then state.save_category = v2 end

    ImGui.SameLine(ctx, nil, 3)

    if ImGui.SmallButton(ctx, "Category ▼##category_presets") then
      ImGui.OpenPopup(ctx, "CategoryPresetPopup")
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Choose from existing categories")
    end

    DrawSelectablePopupList("CategoryPresetPopup", GetCategories(), function(item)
      if item ~= "All" then
        state.save_category = item
      end
    end, "No existing categories.")

    ImGui.SetNextItemWidth(ctx, 420)
    local changed3, v3 = ImGui.InputText(ctx, "##TagsInput", state.save_tags)
    if changed3 then state.save_tags = v3 end

    ImGui.SameLine(ctx, nil, 3)

    if ImGui.SmallButton(ctx, "Tags ▼##tag_presets") then
      ImGui.OpenPopup(ctx, "TagPresetPopup")
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Append from existing tags")
    end

    DrawSelectablePopupList("TagPresetPopup", GetAllTags(), function(item)
      state.save_tags = AppendTagText(state.save_tags, item)
    end, "No existing tags.")

    ImGui.SetNextItemWidth(ctx, 420)
    local changed4, v4 = ImGui.InputTextMultiline(ctx, "Description", state.save_description, 420, 90)
    if changed4 then state.save_description = v4 end

    ImGui.TextDisabled(ctx, "Same-name snapshots will be updated and preview.mp3 will be overwritten.")
    ImGui.TextDisabled(ctx, "Tip: click Category or Tags to reuse existing names.")

    ImGui.Separator(ctx)

    if ImGui.Button(ctx, "Save", 100, 30) then
      SaveSnapshotFromPopup()
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.SameLine(ctx)

    if ImGui.Button(ctx, "Cancel", 100, 30) then
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end
end

function DrawSettingsPopup()
  if ImGui.BeginPopupModal(ctx, "Settings", nil, ImGui.WindowFlags_AlwaysAutoResize) then
    ImGui.Text(ctx, "Library Location")
    ImGui.TextDisabled(ctx, "Choose where snapshots, metadata and preview files are stored.")
    ImGui.Separator(ctx)

    ImGui.SetNextItemWidth(ctx, 450)
    local changed, v = ImGui.InputText(ctx, "##library_dir", state.new_library_dir)
    if changed then state.new_library_dir = v end

    ImGui.SameLine(ctx, nil, 10)
    local frame_height = reaper.ImGui_GetFrameHeight(ctx)

    if ImGui.Button(ctx, "Browse##SelectLibraryDir", nil, frame_height) then
      if reaper.JS_Dialog_BrowseForFolder then
        local start_dir = state.new_library_dir ~= "" and state.new_library_dir or state.library_dir
        local rv, out = reaper.JS_Dialog_BrowseForFolder("Select library directory:", start_dir)
        if rv == 1 and out and out ~= "" then
          state.new_library_dir = NormalizePath(out)
        end
      else
        reaper.MB("Folder browser requires the js_ReaScriptAPI extension.", SCRIPT_NAME, 0)
      end
    end

    if ImGui.SmallButton(ctx, "Use REAPER Resource Path") then
      state.new_library_dir = DEFAULT_LIBRARY_DIR
    end
    -- if ImGui.Button(ctx, "Use REAPER Resource Path", nil, frame_height) then
    --   state.new_library_dir = DEFAULT_LIBRARY_DIR
    -- end
    ImGui.SameLine(ctx, nil, 5)
    if ImGui.SmallButton(ctx, "Open Current Library") then
      OpenFolder(state.library_dir)
    end
    -- if ImGui.Button(ctx, "Open Current Library", nil, frame_height) then
    --   OpenFolder(state.library_dir)
    -- end

    ImGui.Separator(ctx)

    local c1, v1 = ImGui.Checkbox(ctx, "Restore markers and regions", state.restore_markers)
    if c1 then state.restore_markers = v1 end

    local c2, v2 = ImGui.Checkbox(ctx, "Restore tempo and time signatures", state.restore_tempo)
    if c2 then state.restore_tempo = v2 end

    local c3, v3 = ImGui.Checkbox(ctx, "Check empty target area before loading", state.check_empty_space)
    if c3 then state.check_empty_space = v3 end

    local c4, v4 = ImGui.Checkbox(ctx, "Auto render preview.mp3 when saving", state.auto_render_preview)
    if c4 then state.auto_render_preview = v4 end

    local c5, v5 = ImGui.Checkbox(ctx, "Skip leading empty content when rendering preview", state.skip_preview_leading_empty)
    if c5 then state.skip_preview_leading_empty = v5 end

    local c6, v6 = ImGui.Checkbox(ctx, "Place info panel at bottom", state.info_panel_at_bottom)
    if c6 then state.info_panel_at_bottom = v6 end

    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Snapshot List Sort")

    local sort_labels = {
      newest = "Newest first",
      oldest = "Oldest first",
      alphabetical = "Alphabetical",
    }

    local current_sort_label = sort_labels[state.sort_order or "newest"] or sort_labels.newest
    ImGui.SetNextItemWidth(ctx, 200)
    if ImGui.BeginCombo(ctx, "##snapshot_sort_order", current_sort_label) then
      local sort_items = {
        { key = "newest", label = "Newest first" },
        { key = "oldest", label = "Oldest first" },
        { key = "alphabetical", label = "Alphabetical" },
      }

      for _, item in ipairs(sort_items) do
        if ImGui.Selectable(ctx, item.label, state.sort_order == item.key) then
          state.sort_order = item.key
          SaveSettings()
          SortSnapshots()
          state.status = "Snapshot list sort changed: " .. item.label
        end
      end

      ImGui.EndCombo(ctx)
    end

    ImGui.Separator(ctx)

    if ImGui.Button(ctx, "Apply", 100, 30) then
      state.library_dir = NormalizePath(state.new_library_dir)
      EnsureDir(state.library_dir)
      EnsureDir(GetSnapshotsRoot())
      SaveSettings()
      LoadIndex()
      ResetWaveformCacheState()
      state.status = "Library path changed."
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.SameLine(ctx, nil, 10)

    if ImGui.Button(ctx, "Cancel", 100, 30) then
      state.new_library_dir = state.library_dir
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end
end

----------------------------------------
-- Keyboard Shortcuts
----------------------------------------

function IsTextInputActive()
  if ImGui.IsAnyItemActive and ImGui.IsAnyItemActive(ctx) then
    return true
  end

  return false
end

function HandleExitShortcut()
  if ImGui.IsKeyPressed and ImGui.IsKeyPressed(ctx, KEY_ESCAPE) then
    state.request_close = true
  end
end

function IsShiftDown()
  if ImGui.GetKeyMods then
    local ok, mods = pcall(ImGui.GetKeyMods, ctx)
    if ok and tonumber(mods) and tonumber(MOD_SHIFT) then
      local shift = tonumber(MOD_SHIFT) or 0
      if shift > 0 then
        return math.floor((tonumber(mods) or 0) / shift) % 2 == 1
      end
    end
  end

  local left_down = false
  local right_down = false

  if ImGui.IsKeyDown then
    local ok_left, result_left = pcall(ImGui.IsKeyDown, ctx, KEY_LEFT_SHIFT)
    if ok_left then left_down = result_left == true end

    local ok_right, result_right = pcall(ImGui.IsKeyDown, ctx, KEY_RIGHT_SHIFT)
    if ok_right then right_down = result_right == true end
  end

  return left_down or right_down
end

function HandleSnapshotListShortcuts()
  if not state.snapshot_list_focused then return end
  if IsTextInputActive() then return end
  if not ImGui.IsKeyPressed then return end

  local snapshot = state.snapshots[state.selected]
  if not snapshot then return end

  local shift_down = IsShiftDown()

  if ImGui.IsKeyPressed(ctx, KEY_SPACE) then
    TogglePreviewPlayback()
  end

  if ImGui.IsKeyPressed(ctx, KEY_DELETE) and shift_down then
    RemoveSelectedSnapshotFromIndex()
    return
  end

  if ImGui.IsKeyPressed(ctx, KEY_F) then
    ToggleFavorite(snapshot)
  end
end

----------------------------------------
-- Splitter Layout
----------------------------------------

function Clamp(value, min_value, max_value)
  value = tonumber(value) or min_value

  if value < min_value then return min_value end
  if value > max_value then return max_value end

  return value
end

function ClampSplitRatio(ratio, usable_size, min_first, min_second)
  ratio = tonumber(ratio) or 0.5
  usable_size = tonumber(usable_size) or 0

  if usable_size <= 0 then
    return Clamp(ratio, 0.15, 0.85)
  end

  local min_ratio = min_first / usable_size
  local max_ratio = 1.0 - (min_second / usable_size)

  if min_ratio > max_ratio then
    return 0.5
  end

  return Clamp(ratio, min_ratio, max_ratio)
end

function DrawSplitter(id, orientation, size_cross, container_primary_start, usable_primary_size, ratio_name, primary_offset)
  local splitter_size = 5
  primary_offset = tonumber(primary_offset) or 0

  local w, h
  if orientation == "vertical" then
    w = splitter_size
    h = size_cross
  else
    w = size_cross
    h = splitter_size
  end

  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, id, w, h)

  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)

  if (hovered or active) and ImGui.SetMouseCursor then
    if orientation == "vertical" then
      ImGui.SetMouseCursor(ctx, MOUSE_CURSOR_RESIZE_EW)
    else
      ImGui.SetMouseCursor(ctx, MOUSE_CURSOR_RESIZE_NS)
    end
  end

  local draw_list = ImGui.GetWindowDrawList(ctx)

  local col_idle = 0x6F788855
  local col_hot = 0x78C7FF33

  if draw_list and ImGui.DrawList_AddRectFilled and ImGui.DrawList_AddCircleFilled then
    if hovered or active then
      if orientation == "vertical" then
        ImGui.DrawList_AddRectFilled(draw_list, x, y, x + splitter_size, y + h, col_hot)
      else
        ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + splitter_size, col_hot)
      end
    else
      local cx = x + w * 0.5
      local cy = y + h * 0.5
      ImGui.DrawList_AddCircleFilled(draw_list, cx, cy, 2.5, col_idle)
    end
  end

  if active then
    local mx, my = ImGui.GetMousePos(ctx)
    local mouse_primary = orientation == "vertical" and mx or my
    local new_ratio = (mouse_primary - container_primary_start - primary_offset) / usable_primary_size
    state[ratio_name] = Clamp(new_ratio, 0.05, 0.95)
    state.splitter_dirty = true
  end

  if state.splitter_dirty and ImGui.IsMouseReleased and ImGui.IsMouseReleased(ctx, MOUSE_BUTTON_LEFT) then
    state.splitter_dirty = false
    SaveSettings()
  end
end

function DrawMainContentLayout()
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  avail_w = math.max(1, math.floor(tonumber(avail_w) or 900))
  avail_h = math.max(1, math.floor(tonumber(avail_h) or 420))

  local gap_size = 5
  local splitter_size = 5
  local middle_size = gap_size + splitter_size + gap_size

  local min_list = 150
  local min_info = 150

  local safe_w = math.max(1, avail_w - 1)
  local safe_h = math.max(1, avail_h - 1)

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 0)

  if state.info_panel_at_bottom then
    local start_x, start_y = ImGui.GetCursorScreenPos(ctx)
    local usable_h = math.max(1, safe_h - middle_size)

    state.bottom_split_ratio = ClampSplitRatio(state.bottom_split_ratio, usable_h, min_list, min_info)

    local list_h = math.floor(usable_h * state.bottom_split_ratio)
    local info_h = math.max(1, usable_h - list_h)

    DrawSnapshotList(0, list_h)

    -- 5px 像素间隔
    ImGui.Dummy(ctx, 0, gap_size)

    -- 5px 像素分隔条
    DrawSplitter("##splitter_bottom", "horizontal", safe_w, start_y, usable_h, "bottom_split_ratio", gap_size)

    -- 5px 像素间隔
    ImGui.Dummy(ctx, 0, gap_size)

    DrawInfoPanel(0, info_h)
  else
    local start_x, start_y = ImGui.GetCursorScreenPos(ctx)
    local usable_w = math.max(1, safe_w - middle_size)

    state.side_split_ratio = ClampSplitRatio(state.side_split_ratio, usable_w, min_list, 260)

    local list_w = math.floor(usable_w * state.side_split_ratio)

    DrawSnapshotList(list_w, 0)

    -- 5px 像素间隔
    ImGui.SameLine(ctx, nil, gap_size)

    -- 5px 像素分隔条
    DrawSplitter("##splitter_side", "vertical", safe_h, start_x, usable_w, "side_split_ratio", gap_size)

    -- 5px 像素间隔
    ImGui.SameLine(ctx, nil, gap_size)

    DrawInfoPanel(0, 0)
  end

  ImGui.PopStyleVar(ctx)
end

----------------------------------------
-- Main Loop
----------------------------------------

function MainLoop()
  UpdatePreviewState()
  ImGui.SetNextWindowSize(ctx, 430, 670, ImGui.Cond_FirstUseEver)

  PushStyle()

  local visible, open = ImGui.Begin(ctx, SCRIPT_NAME, true, WINDOW_FLAGS_MAIN)
  if visible then
    if font_normal then ImGui.PushFont(ctx, font_normal, 14) end

    DrawHeader()
    DrawTopBar()
    DrawFilters()
    DrawWaveformCachePreviewBar()
    -- ImGui.Separator(ctx)
    DrawMainContentLayout()

    DrawSavePopup()
    DrawSettingsPopup()
    HandleExitShortcut()
    HandleSnapshotListShortcuts()

    if font_normal then ImGui.PopFont(ctx) end
    ImGui.End(ctx)
  end

  PopStyle()

  if state.request_close then
    open = false
  end

  if open then
    reaper.defer(MainLoop)
  else
    StopInternalPreview(true)
  end
end

----------------------------------------
-- Init
----------------------------------------

math.randomseed(os.time())

LoadSettings()
EnsureDir(state.library_dir)
EnsureDir(GetSnapshotsRoot())
LoadIndex()

reaper.defer(MainLoop)
