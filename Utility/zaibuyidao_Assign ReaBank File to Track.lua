-- @description Assign ReaBank File to Track
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about
--   EN
--   Assigns a ReaBank file to the selected track.
--  
--   This script was extracted from zaibuyidao_Articulation Map.lua / lib/core.lua.
--  
--   Usage:
--   1. Select a track, or open the MIDI Editor so the script can automatically detect the track containing the active MIDI take.
--   2. Run the script and choose a .reabank file.
--   3. Normal run: writes MIDIBANKPROGFN only to the current track.
--   4. Shift-run: also writes the selected path to the mididefbankprog default entry in reaper.ini.
--  
--   CN
--   为选中的轨道指定 ReaBank 文件。
--  
--   本脚本提取自 zaibuyidao_Articulation Map.lua / lib/core.lua。
--  
--   使用方法：
--   1. 选中一个轨道，或打开 MIDI 编辑器，让脚本自动获取当前 MIDI take 所在轨道。
--   2. 运行脚本并选择 .reabank 文件。
--   3. 普通运行：仅将 MIDIBANKPROGFN 写入当前轨道。
--   4. 按住 Shift 运行：同时将所选路径写入 reaper.ini 的 mididefbankprog 默认项。

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

local TEXT = {
  ["简体中文"] = {
    title = "指定 ReaBank 文件分配给轨道",
    select_reabank = "选择要分配给轨道的 ReaBank 文件",
    no_target_track = "请先选中一个轨道，或打开一个 MIDI take 的 MIDI 编辑器。",
    cannot_locate_ini = "无法定位 reaper.ini。",
    cannot_read_ini = "无法读取 reaper.ini。",
    cannot_find_reaper_section = "无法在 reaper.ini 中找到 [REAPER] 区段。",
    cannot_write_ini = "无法写入 reaper.ini。",
    no_track = "没有目标轨道。",
    no_reabank_path = "没有 ReaBank 路径。",
    cannot_read_track_chunk = "无法读取轨道状态 chunk。",
    cannot_write_track_chunk = "无法写入轨道状态 chunk。",
    failed_suffix = " - 失败",
    write_track_failed = "写入轨道失败。",
    ini_written = "\n同时已写入 reaper.ini 的 mididefbankprog 默认项。",
    ini_failed = "\n轨道已写入，但 reaper.ini 写入失败：%s",
    success = "已将 ReaBank 分配给目标轨道：\n%s",
    undo = "指定 ReaBank 文件分配给轨道"
  },
  ["繁體中文"] = {
    title = "指定 ReaBank 檔案分配給軌道",
    select_reabank = "選擇要分配給軌道的 ReaBank 檔案",
    no_target_track = "請先選中一個軌道，或開啟一個 MIDI take 的 MIDI 編輯器。",
    cannot_locate_ini = "無法定位 reaper.ini。",
    cannot_read_ini = "無法讀取 reaper.ini。",
    cannot_find_reaper_section = "無法在 reaper.ini 中找到 [REAPER] 區段。",
    cannot_write_ini = "無法寫入 reaper.ini。",
    no_track = "沒有目標軌道。",
    no_reabank_path = "沒有 ReaBank 路徑。",
    cannot_read_track_chunk = "無法讀取軌道狀態 chunk。",
    cannot_write_track_chunk = "無法寫入軌道狀態 chunk。",
    failed_suffix = " - 失敗",
    write_track_failed = "寫入軌道失敗。",
    ini_written = "\n同時已寫入 reaper.ini 的 mididefbankprog 預設項。",
    ini_failed = "\n軌道已寫入，但 reaper.ini 寫入失敗：%s",
    success = "已將 ReaBank 分配給目標軌道：\n%s",
    undo = "指定 ReaBank 檔案分配給軌道"
  },
  English = {
    title = "Assign ReaBank File to Track",
    select_reabank = "Choose a ReaBank file to assign to the track",
    no_target_track = "Please select a track, or open the MIDI editor for a MIDI take.",
    cannot_locate_ini = "Cannot locate reaper.ini.",
    cannot_read_ini = "Cannot read reaper.ini.",
    cannot_find_reaper_section = "Cannot find the [REAPER] section in reaper.ini.",
    cannot_write_ini = "Cannot write reaper.ini.",
    no_track = "No target track.",
    no_reabank_path = "No ReaBank path.",
    cannot_read_track_chunk = "Cannot read track state chunk.",
    cannot_write_track_chunk = "Cannot write track state chunk.",
    failed_suffix = " - failed",
    write_track_failed = "Failed to write to track.",
    ini_written = "\nAlso wrote the path to reaper.ini mididefbankprog default entry.",
    ini_failed = "\nTrack was written, but reaper.ini write failed: %s",
    success = "Assigned ReaBank to target track:\n%s",
    undo = "Assign ReaBank File to Track"
  }
}

local T = TEXT[language] or TEXT.English
local TITLE = T.title

function read_file(path)
  local file = io.open(path, "r")
  if not file then return nil, "failed to open file for read" end
  local content = file:read("*a")
  file:close()
  return content
end

function write_file(path, content)
  local file = io.open(path, "w")
  if not file then return "failed to open file for write" end
  file:write(content)
  file:close()
end

function get_active_midi_track()
  local midi_editor = reaper.MIDIEditor_GetActive()
  if not midi_editor then return nil end

  local take = reaper.MIDIEditor_GetTake(midi_editor)
  if not take or not reaper.TakeIsMIDI(take) then return nil end

  return reaper.GetMediaItemTake_Track(take)
end

function get_target_track()
  local selected_track = reaper.GetSelectedTrack(0, 0)
  if selected_track then return selected_track end
  return get_active_midi_track()
end

function set_default_reabank_file(reabank_path)
  local ini_file = reaper.get_ini_file()
  if not ini_file then return false, T.cannot_locate_ini end

  local ini, read_err = read_file(ini_file)
  if read_err or not ini then return false, T.cannot_read_ini end

  if ini:find("mididefbankprog=") then
    ini = ini:gsub("mididefbankprog=[^\r\n]*", function()
      return "mididefbankprog=" .. reabank_path
    end, 1)
  else
    local pos, line_end = ini:find("%[REAPER%][^\n]*\n")
    if not pos then
      pos, line_end = ini:find("%[reaper%][^\n]*\n")
    end
    if not line_end then return false, T.cannot_find_reaper_section end
    ini = ini:sub(1, line_end) .. "mididefbankprog=" .. reabank_path .. "\n" .. ini:sub(line_end + 1)
  end

  local write_err = write_file(ini_file, ini)
  if write_err then return false, T.cannot_write_ini end
  return true
end

function apply_reabank_to_track(track, reabank_path)
  if not track then return false, T.no_track end
  if type(reabank_path) ~= "string" or reabank_path == "" then
    return false, T.no_reabank_path
  end

  local ret, track_state_chunk = reaper.GetTrackStateChunk(track, "", false)
  if not ret or not track_state_chunk then
    return false, T.cannot_read_track_chunk
  end

  local bank_line = 'MIDIBANKPROGFN "' .. reabank_path .. '"\n'
  if track_state_chunk:find("MIDIBANKPROGFN") then
    if track_state_chunk:find('MIDIBANKPROGFN "[^"]*"[^\n]*\n') then
      track_state_chunk = track_state_chunk:gsub('MIDIBANKPROGFN "[^"]*"[^\n]*\n', function()
      return bank_line
      end, 1)
    else
      track_state_chunk = track_state_chunk:gsub('MIDIBANKPROGFN "[^"]*"', function()
        return bank_line:gsub("\n$", "")
      end, 1)
    end
  else
    track_state_chunk = track_state_chunk:gsub("<TRACK%s*\n", function()
      return "<TRACK\n" .. bank_line
    end, 1)
  end

  local ok = reaper.SetTrackStateChunk(track, track_state_chunk, false)
  if not ok then return false, T.cannot_write_track_chunk end
  return true
end

function refresh_midi_bank_support_data()
  local editor = reaper.MIDIEditor_GetActive()
  if editor then
    reaper.MIDIEditor_OnCommand(editor, 42102) -- MIDI editor: Reload track support data
  end

  reaper.Main_OnCommand(42465, 0) -- MIDI: Reload track support data for selected tracks
end

function main()
  local track = get_target_track()
  if not track then
    reaper.ShowMessageBox(T.no_target_track, TITLE, 0)
    return
  end

  local ok, reabank_path = reaper.GetUserFileNameForRead("", T.select_reabank, ".reabank")
  if not ok or not reabank_path or reabank_path == "" then return end

  reaper.Undo_BeginBlock()

  local apply_ok, apply_err = apply_reabank_to_track(track, reabank_path)
  if not apply_ok then
    reaper.Undo_EndBlock(TITLE .. T.failed_suffix, -1)
    reaper.ShowMessageBox(apply_err or T.write_track_failed, TITLE, 0)
    return
  end

  local shift_down = (reaper.JS_Mouse_GetState and (reaper.JS_Mouse_GetState(8) & 8) == 8) or false
  local ini_message = ""
  if shift_down then
    local ini_ok, ini_err = set_default_reabank_file(reabank_path)
    ini_message = ini_ok and T.ini_written or T.ini_failed:format(tostring(ini_err))
  end

  refresh_midi_bank_support_data()
  reaper.Undo_EndBlock(T.undo, -1)
  reaper.ShowMessageBox(T.success:format(reabank_path) .. ini_message, TITLE, 0)
end

main()
