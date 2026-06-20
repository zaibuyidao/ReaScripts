-- @description SFX Snapshot Library
-- @version 1.0.21
-- @author zaibuyidao
-- @changelog
--   Added 'Edit Snapshot' to the right-click menu for editing the snapshot name, category, tags, and description.
--   Fixed an issue where items in the snapshot list could not be dragged properly on macOS.
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

local RESOURCE_PATH = tostring(reaper.GetResourcePath() or ""):gsub("\\", "/"):gsub("/+$", "")
local SCRIPT_NAME = "SFX Snapshot Library"
local SCRIPT_VERSION = "1.0.21"
local EXT_SECTION = "SFX_SNAPSHOT_LIBRARY"

local LANGUAGE_DEFAULT = "en"
local LANGUAGE_OPTIONS = {
  { id = "en",    label_key = "language_english" },
  { id = "zh_CN", label_key = "language_simplified_chinese" },
  { id = "zh_TW", label_key = "language_traditional_chinese" },
}
local LANGUAGE_ALIASES = {
  English = "en",
  ["简体中文"] = "zh_CN",
  ["繁體中文"] = "zh_TW",
}

local TEXT = {
  en = {
    language_english = "English",
    language_simplified_chinese = "简体中文",
    language_traditional_chinese = "繁體中文",

    title = "SFX Snapshot Library",
    subtitle = "Professional modular SFX archive / restore system",
    error = "Error",
    ok = "OK",
    cancel = "Cancel",
    apply = "Apply",
    save = "Save",
    load = "Load",
    update_snapshot = "Update Snapshot",
    edit_snapshot = "Edit Snapshot",
    play = "Play",
    stop = "Stop",
    options = "Options",
    settings = "Settings",
    browse = "Browse",
    remove = "Remove",
    rename = "Rename",
    open_folder = "Open Folder",
    export_zip = "Export ZIP",
    import_zip = "Import ZIP",
    view_shortcuts = "Shortcuts",
    add_favorite = "Add Favorite",
    remove_favorite = "Remove Favorite",
    favorite = "Favorite",

    category_all = "All",
    category_uncategorized = "Uncategorized",
    unnamed = "Unnamed",
    snapshot = "snapshot",
    default_snapshot_name_format = "SFX Snapshot %Y-%m-%d %H-%M-%S",
    imported_snapshot = "Imported Snapshot",

    capture_razor = "Razor Edit",
    capture_time_selection = "Time Selection",
    capture_time_selection_selected_items = "Time Selection (Selected Items)",
    capture_unknown = "Unknown",

    popup_save_snapshot = "Save Snapshot",
    popup_edit_snapshot = "Edit Snapshot",
    popup_load_snapshot = "Load Snapshot",
    popup_rename_snapshot = "Rename Snapshot",
    popup_settings = "Settings",

    search_hint = "Search name / category / tags / description...",
    category_label = "Category:",
    favorites_only = "Favorites only",
    no_snapshot_selected = "No snapshot selected.",
    no_snapshots_found = "No snapshots found.",
    no_existing_items = "No existing items.",
    no_existing_categories = "No existing categories.",
    no_existing_tags = "No existing tags.",

    waveform_preview_unavailable = "Waveform preview unavailable.",
    back_to_start = "Back to Start",
    loop_on = "Loop On",
    loop_off = "Loop Off",
    tooltip_waveform_seek = "Click the waveform to set the cursor and play from that position.",
    tooltip_preview_start = "Return preview cursor to the start.",
    tooltip_preview_volume = "Preview volume: drag up/down to adjust, double-click to reset to 0 dB.",

    meta_category = "Category: {value}",
    meta_source = "Source: {value}",
    meta_tags = "Tags: {value}",
    meta_duration = "Duration: {value} s",
    meta_tracks = "Tracks: {value}",
    meta_items = "Items: {value}",
    meta_media_archived = "Media archived: {value}",
    meta_missing_media = "Missing media: {value}",
    meta_created = "Created: {value}",
    meta_preview_skip = "Preview skip: {value} s",
    meta_preview_missing = "Preview: missing",
    meta_preview_error = "Preview error: {value}",
    meta_detail_summary = "Duration {duration}s    Tracks {tracks}    Items {items}    Media {media}",

    smart_save_info = "Smart save: Razor Edit has priority. If no Razor Edit exists, the current time selection will be captured.",
    edit_snapshot_info = "Edit the selected snapshot's name, category, tags, and description.",
    field_name = "Name",
    field_new_name = "New name:",
    field_description = "Description",
    category_dropdown = "Category ▼",
    tags_dropdown = "Tags ▼",
    tooltip_choose_categories = "Choose from existing categories",
    tooltip_append_tags = "Append from existing tags",
    confirm_overwrite_snapshot = "A snapshot named \"{name}\" already exists.\n\nOK will overwrite it. Cancel returns to the save window so you can rename it.",
    confirm_update_snapshot = "Replace snapshot \"{name}\" with the current Razor Edit or time selection?\n\nThe old snapshot content will be permanently replaced. Its name, category, tags, and description will be preserved.",
    tip_reuse_names = "Tip: click Category or Tags to reuse existing names.",

    load_snapshot_name = "Load: {name}",
    load_to_new_tracks = "Load to new tracks",
    check_empty_target = "Check empty target area before loading",
    restore_markers = "Restore markers",
    restore_regions = "Restore regions",
    restore_tempo = "Restore tempo and time signatures",
    restore_track_info = "Restore track names and FX",
    restore_empty_tracks = "Restore empty tracks",
    tooltip_restore_track_info_load = "Track names and FX are applied only to tracks created during this load.",
    tooltip_restore_track_info_settings = "Track names and FX are applied only to tracks created during load.",
    tooltip_restore_empty_tracks = "When disabled, captured tracks with no media items are skipped and remaining tracks are compacted.",

    interface = "Interface",
    settings_language = "Language:",
    settings_library_location = "Library Location",
    settings_library_description = "Choose where snapshots, metadata and preview files are stored.",
    select_library_directory = "Select library directory:",
    use_reaper_resource_path = "Use REAPER Resource Path",
    open_current_library = "Open Current Library",
    settings_load_options = "Load Options",
    settings_save_options = "Save Options",
    settings_snapshot_options = "Snapshot Options",
    settings_snapshot_sort = "List Sort:",
    settings_display_options = "Display Options",
    show_load_popup = "Show load confirmation popup",
    auto_render_preview = "Auto render preview.mp3 when saving",
    skip_preview_leading_empty = "Skip leading empty content when rendering preview",
    show_capture_abbreviations = "Show [TS]/[RE] capture labels",
    show_tips = "Show tips",
    place_info_panel_bottom = "Place info panel at bottom",
    sort_newest = "Newest first",
    sort_oldest = "Oldest first",
    sort_alphabetical = "Alphabetical",

    dialog_export_zip_title = "Export SFX Snapshot ZIP",
    dialog_export_folder_title = "Select export folder:",
    dialog_import_zip_title = "Import SFX Snapshot ZIP",
    dialog_zip_filter = "ZIP files (*.zip)\0*.zip\0All files (*.*)\0*.*\0",
    shortcut_help_title = "Keyboard Shortcuts",
    shortcut_help_text = "Ctrl+S: Save snapshot\nCtrl+L: Load selected snapshot\nAlt+Enter: Load selected snapshot\nMiddle mouse button on a list item: Load that snapshot\nSpace: Play / stop selected snapshot preview\nF: Add / remove selected snapshot from favorites\nShift+Delete: Remove selected snapshot(s)\nCtrl+,: Open Settings\nEnter: Confirm current dialog\nEsc: Close script",
    undo_load_snapshot = "Load SFX Snapshot",

    confirm_remove_snapshot = "Remove this snapshot and delete its local folder?\n\n{name}\n\nFolder:\n{folder}",
    confirm_remove_snapshots = "Remove these {count} snapshots and delete their local folders?\n\n{names}",

    error_failed_open_source_media = "Failed to open source media: {path}",
    error_failed_write_archived_media = "Failed to write archived media: {path}",
    error_refuse_delete_outside = "Refusing to delete a folder outside the snapshots directory.",
    error_failed_delete_snapshot_folder = "Failed to delete snapshot folder: {path}",
    error_failed_offline_snapshot_media = "Failed to set loaded snapshot media offline: {name}",
    error_snapshot_folder_not_found = "Snapshot folder not found.",
    error_snapshot_name_exists = "A snapshot named \"{name}\" already exists.",
    error_snapshot_folder_exists = "A snapshot folder named \"{folder}\" already exists.",
    error_failed_rename_snapshot_folder = "Failed to rename snapshot folder:\n\n{source}\n\n->\n\n{dest}",
    error_failed_update_snapshot_data = "Failed to update snapshot data file.",
    error_zip_create_windows = "Failed to create ZIP with PowerShell .NET ZipFile. Please check whether the export folder is writable:\n\n{path}",
    error_zip_create_unix = "Failed to create ZIP. On macOS it uses ditto; on Linux it requires zip.",
    error_zip_not_found = "ZIP file not found.",
    error_zip_extract_windows = "Failed to extract ZIP. Tried Windows tar.exe and PowerShell .NET ZipFile.",
    error_zip_extract_unix = "Failed to extract ZIP. On macOS it uses ditto; on Linux it requires unzip.",
    error_imported_data_missing = "Imported snapshot data is missing.",
    error_reaper_enum_unavailable = "REAPER file enumeration API is unavailable.",
    error_failed_copy_imported_snapshot_folder = "Failed to copy imported snapshot folder.",
    error_no_capture_context = "No Razor Edit or time selection found. Please create a Razor Edit area or a time selection before saving.",
    error_capture_empty = "{mode} contains no media items, markers, regions, or tempo/time signature markers.",
    error_invalid_snapshot_data = "Invalid snapshot data.",
    error_snapshot_has_no_tracks = "Snapshot has no tracks.",
    error_target_area_not_empty = "Target area is not empty. Track {track} already contains items in this range.",
    error_invalid_snapshot_folder = "Invalid snapshot folder.",
    error_invalid_preview_range = "Invalid preview render range.",
    error_preview_mp3_not_created = "preview.mp3 was not created. Please check REAPER render settings.",
    error_load_snapshot_detail = "Failed to load snapshot:\n\n{detail}",
    error_snapshot_data_missing_detail = "Snapshot data file not found:\n\n{path}",
    error_zip_missing_detail = "ZIP file not found:\n\n{path}",
    error_zip_invalid_package_detail = "This ZIP does not look like a SFX Snapshot package.\n\nsnapshot.lua was not found.",
    error_import_read_detail = "Failed to read imported snapshot:\n\n{detail}",
    error_waveform_cache_file_not_found = "Waveform cache file not found.",
    error_lua_no_string_unpack = "This REAPER Lua build does not support string.unpack.",
    error_waveform_cache_open = "Failed to open waveform cache.",
    error_waveform_cache_header = "Invalid waveform cache header.",
    error_waveform_cache_magic = "Invalid waveform cache magic.",
    error_waveform_cache_parse = "Failed to parse waveform cache header.",
    error_waveform_cache_unsupported = "Unsupported waveform cache data.",
    error_waveform_cache_incomplete = "Incomplete waveform cache data.",
    error_internal_preview_requires_sws = "Internal preview playback requires the SWS extension.\n\nPlease install/update SWS, then restart REAPER.",
    error_preview_file_not_found = "Preview file not found:\n\n{path}",
    error_preview_source_failed = "Failed to create preview source:\n\n{path}",
    error_preview_object_failed = "Failed to create internal preview object.",
    error_preview_start_failed = "Failed to start internal preview playback.",
    error_no_preview_for_snapshot = "No preview file found for this snapshot.\n\nYou can re-save the snapshot to auto-render preview.mp3, or manually place preview.mp3 here:\n\n{folder}",
    error_folder_browser_requires_js = "Folder browser requires the js_ReaScriptAPI extension.",

    status_ready = "Snapshot Library Ready.",
    status_capture_failed = "Capture failed.",
    status_save_cancelled_same_name = "Save cancelled: same-name snapshot was not overwritten.",
    status_snapshot_write_failed = "Failed to write snapshot file.",
    status_saved_preview_ok = "Saved {mode} snapshot and rendered preview: {name}{media_note}",
    status_saved_preview_failed = "Saved {mode} snapshot, but preview render failed: {name}{media_note}",
    status_media_archived_note = " | Media archived: {count}",
    status_missing_media_note = " | Missing media: {count}",
    status_no_snapshot_selected = "No snapshot selected.",
    status_load_failed = "Load failed.",
    status_loaded_snapshot = "Loaded snapshot: {name}",
    status_export_data_missing = "Export failed: snapshot data missing.",
    status_export_cancelled = "Export cancelled.",
    status_export_failed = "Export failed.",
    status_exported_zip = "Exported snapshot ZIP: {path}",
    status_exported_zip_count = "Exported {count} snapshots to ZIP: {path}",
    status_import_cancelled = "Import cancelled.",
    status_import_zip_missing = "Import failed: ZIP file missing.",
    status_import_failed = "Import failed.",
    status_import_snapshot_missing = "Import failed: snapshot.lua not found in ZIP.",
    status_import_invalid_data = "Import failed: invalid snapshot data.",
    status_imported_snapshot = "Imported snapshot: {name}",
    status_imported_snapshot_count = "Imported {count} snapshots.",
    status_already_favorite = "Already in favorites.",
    status_already_not_favorite = "Already removed from favorites.",
    status_added_favorite = "Added to favorites.",
    status_removed_favorite = "Removed from favorites.",
    status_removed_deleted = "Removed snapshot and deleted local folder.",
    status_removed_deleted_count = "Removed {count} snapshots and deleted local folders.",
    status_remove_delete_failed = "Delete failed. Snapshot was kept in the library.",
    status_removed_index_delete_failed = "Delete failed. Snapshot was kept in the library.",
    status_renamed_snapshot = "Renamed snapshot: {name}",
    status_edited_snapshot = "Edited snapshot: {name}",
    status_rename_cancelled = "Rename cancelled.",
    status_no_preview_waveform = "No preview file found for waveform display.",
    status_waveform_extension_missing = "Waveform cache extension is not available.",
    status_waveform_read_failed = "Failed to read waveform cache.",
    status_waveform_building = "Building waveform cache...",
    status_waveform_build_failed = "Failed to build waveform cache.",
    status_looping_preview = "Looping preview: {name}",
    status_preview_finished = "Preview finished.",
    status_internal_preview_requires_sws = "Internal preview requires SWS extension.",
    status_preview_file_missing = "Preview file missing.",
    status_preview_source_failed = "Failed to create preview source.",
    status_preview_object_failed = "Failed to create preview object.",
    status_preview_start_failed = "Failed to start preview.",
    status_playing_preview_from = "Playing preview from {seconds}s: {name}",
    status_playing_preview = "Playing preview: {name}",
    status_preview_cursor_start = "Preview cursor returned to start.",
    status_preview_stopped = "Preview stopped.",
    status_preview_loop_enabled = "Preview loop enabled.",
    status_preview_loop_disabled = "Preview loop disabled.",
    status_sort_changed = "Snapshot list sort changed: {label}",
    status_settings_applied = "Settings applied.",
  },

  zh_CN = {
    language_english = "English",
    language_simplified_chinese = "简体中文",
    language_traditional_chinese = "繁體中文",

    title = "SFX Snapshot Library",
    subtitle = "专业模块化音效快照归档 / 还原系统",
    error = "错误",
    ok = "确定",
    cancel = "取消",
    apply = "应用",
    save = "保存",
    load = "载入",
    update_snapshot = "更新快照",
    edit_snapshot = "编辑快照",
    play = "播放",
    stop = "停止",
    options = "选项",
    settings = "设置",
    browse = "浏览",
    remove = "移除",
    rename = "重命名",
    open_folder = "打开文件夹",
    export_zip = "导出 ZIP",
    import_zip = "导入 ZIP",
    view_shortcuts = "快捷键",
    add_favorite = "添加收藏",
    remove_favorite = "取消收藏",
    favorite = "收藏",

    category_all = "全部",
    category_uncategorized = "未分类",
    unnamed = "未命名",
    snapshot = "快照",
    default_snapshot_name_format = "音效快照 %Y-%m-%d %H-%M-%S",
    imported_snapshot = "导入的快照",

    capture_razor = "剃刀编辑",
    capture_time_selection = "时间选区",
    capture_time_selection_selected_items = "时间选区（选中对象）",
    capture_unknown = "未知",

    popup_save_snapshot = "保存快照",
    popup_edit_snapshot = "编辑快照",
    popup_load_snapshot = "载入快照",
    popup_rename_snapshot = "重命名快照",
    popup_settings = "设置",

    search_hint = "搜索名称 / 分类 / 标签 / 描述...",
    category_label = "分类:",
    favorites_only = "仅显示收藏",
    no_snapshot_selected = "未选择快照。",
    no_snapshots_found = "未找到快照。",
    no_existing_items = "没有现有项目。",
    no_existing_categories = "没有现有分类。",
    no_existing_tags = "没有现有标签。",

    waveform_preview_unavailable = "波形预览不可用。",
    back_to_start = "回到开头",
    loop_on = "循环开",
    loop_off = "循环关",
    tooltip_waveform_seek = "点击波形可设置光标，并从该位置播放。",
    tooltip_preview_start = "将预览光标返回到开头。",
    tooltip_preview_volume = "预览音量: 上下拖动调整，双击重置为 0 dB。",

    meta_category = "分类: {value}",
    meta_source = "来源: {value}",
    meta_tags = "标签: {value}",
    meta_duration = "时长: {value} 秒",
    meta_tracks = "轨道: {value}",
    meta_items = "媒体对象: {value}",
    meta_media_archived = "已归档媒体: {value}",
    meta_missing_media = "缺失媒体: {value}",
    meta_created = "创建时间: {value}",
    meta_preview_skip = "预览跳过: {value} 秒",
    meta_preview_missing = "预览: 缺失",
    meta_preview_error = "预览错误: {value}",
    meta_detail_summary = "时长 {duration}秒    轨道 {tracks}    对象 {items}    媒体 {media}",

    smart_save_info = "智能保存: 剃刀编辑优先。如果没有剃刀编辑，则捕获当前时间选区。",
    edit_snapshot_info = "编辑当前快照的名称、分类、标签和描述。",
    field_name = "名称",
    field_new_name = "新名称:",
    field_description = "描述",
    category_dropdown = "分类 ▼",
    tags_dropdown = "标签 ▼",
    tooltip_choose_categories = "从现有分类中选择",
    tooltip_append_tags = "从现有标签中追加",
    confirm_overwrite_snapshot = "已存在同名快照: {name}\n\n点击[确定]将覆盖，点击[取消]返回保存窗口以便改名。",
    confirm_update_snapshot = "是否使用当前剃刀编辑或时间选区替换快照“{name}”？\n\n旧快照内容将被永久替换，并保留其名称、分类、标签和描述。",
    tip_reuse_names = "提示: 点击分类或标签可复用现有名称。",

    load_snapshot_name = "载入: {name}",
    load_to_new_tracks = "载入到新轨道",
    check_empty_target = "载入前检查目标区域是否为空",
    restore_markers = "还原标记",
    restore_regions = "还原区域",
    restore_tempo = "还原速度和拍号",
    restore_track_info = "还原轨道名称和 FX",
    restore_empty_tracks = "还原空轨道",
    tooltip_restore_track_info_load = "轨道名称和 FX 只会应用到本次载入时创建的轨道。",
    tooltip_restore_track_info_settings = "轨道名称和 FX 只会应用到载入时创建的轨道。",
    tooltip_restore_empty_tracks = "关闭时，会跳过没有媒体对象的已捕获轨道，并压缩剩余轨道。",

    interface = "界面",
    settings_language = "语言:",
    settings_library_location = "资源库位置",
    settings_library_description = "选择快照、元数据和预览文件的存储位置。",
    select_library_directory = "选择资源库文件夹:",
    use_reaper_resource_path = "使用 REAPER 资源路径",
    open_current_library = "打开当前资源库",
    settings_load_options = "载入选项",
    settings_save_options = "保存选项",
    settings_snapshot_options = "快照选项",
    settings_snapshot_sort = "列表排序:",
    settings_display_options = "显示选项",
    show_load_popup = "显示载入确认弹窗",
    auto_render_preview = "保存时自动渲染 preview.mp3",
    skip_preview_leading_empty = "渲染预览时跳过开头空白内容",
    show_capture_abbreviations = "显示 [TS]/[RE] 捕获标签",
    show_tips = "显示提示",
    place_info_panel_bottom = "将信息面板放在底部",
    sort_newest = "最新优先",
    sort_oldest = "最旧优先",
    sort_alphabetical = "按字母排序",

    dialog_export_zip_title = "导出 SFX 快照 ZIP",
    dialog_export_folder_title = "选择导出文件夹: ",
    dialog_import_zip_title = "导入 SFX 快照 ZIP",
    dialog_zip_filter = "ZIP 文件 (*.zip)\0*.zip\0所有文件 (*.*)\0*.*\0",
    shortcut_help_title = "快捷键",
    shortcut_help_text = "Ctrl+S：保存快照\nCtrl+L：载入当前选中的快照\nAlt+Enter：载入当前选中的快照\n鼠标中键点击列表条目：载入该快照\nSpace：播放 / 停止当前快照预览\nF：添加 / 取消收藏当前快照\nShift+Delete：移除选中的快照\nCtrl+,：打开设置\nEnter：确认当前弹窗\nEsc：关闭脚本",
    undo_load_snapshot = "载入 SFX 快照",

    confirm_remove_snapshot = "要移除此快照并删除本地文件夹吗？\n\n{name}\n\n文件夹: \n{folder}",
    confirm_remove_snapshots = "要移除这 {count} 个快照并删除其本地文件夹吗？\n\n{names}",

    error_failed_open_source_media = "无法打开源媒体: {path}",
    error_failed_write_archived_media = "无法写入归档媒体: {path}",
    error_refuse_delete_outside = "拒绝删除快照目录之外的文件夹。",
    error_failed_delete_snapshot_folder = "无法删除快照文件夹: {path}",
    error_failed_offline_snapshot_media = "无法让已载入的快照媒体离线: {name}",
    error_snapshot_folder_not_found = "未找到快照文件夹。",
    error_snapshot_name_exists = "已存在同名快照: {name}",
    error_snapshot_folder_exists = "已存在同名快照文件夹: {folder}",
    error_failed_rename_snapshot_folder = "无法重命名快照文件夹: \n\n{source}\n\n->\n\n{dest}",
    error_failed_update_snapshot_data = "无法更新快照数据文件。",
    error_zip_create_windows = "无法通过 PowerShell .NET ZipFile 创建 ZIP。请检查导出文件夹是否可写: \n\n{path}",
    error_zip_create_unix = "无法创建 ZIP。macOS 使用 ditto，Linux 需要 zip。",
    error_zip_not_found = "未找到 ZIP 文件。",
    error_zip_extract_windows = "无法解压 ZIP。已尝试 Windows tar.exe 和 PowerShell .NET ZipFile。",
    error_zip_extract_unix = "无法解压 ZIP。macOS 使用 ditto，Linux 需要 unzip。",
    error_imported_data_missing = "导入的快照数据缺失。",
    error_reaper_enum_unavailable = "REAPER 文件枚举 API 不可用。",
    error_failed_copy_imported_snapshot_folder = "无法复制导入的快照文件夹。",
    error_no_capture_context = "未找到剃刀编辑或时间选区。保存前请创建剃刀编辑区域或时间选区。",
    error_capture_empty = "{mode} 中没有媒体对象、标记、区域或速度/拍号标记。",
    error_invalid_snapshot_data = "无效的快照数据。",
    error_snapshot_has_no_tracks = "快照没有轨道。",
    error_target_area_not_empty = "目标区域不是空的。轨道 {track} 在此范围内已有对象。",
    error_invalid_snapshot_folder = "无效的快照文件夹。",
    error_invalid_preview_range = "无效的预览渲染范围。",
    error_preview_mp3_not_created = "未创建 preview.mp3。请检查 REAPER 渲染设置。",
    error_load_snapshot_detail = "无法载入快照: \n\n{detail}",
    error_snapshot_data_missing_detail = "未找到快照数据文件: \n\n{path}",
    error_zip_missing_detail = "未找到 ZIP 文件: \n\n{path}",
    error_zip_invalid_package_detail = "此 ZIP 看起来不是 SFX Snapshot 包。\n\n未找到 snapshot.lua。",
    error_import_read_detail = "无法读取导入的快照: \n\n{detail}",
    error_waveform_cache_file_not_found = "未找到波形缓存文件。",
    error_lua_no_string_unpack = "此 REAPER Lua 版本不支持 string.unpack。",
    error_waveform_cache_open = "无法打开波形缓存。",
    error_waveform_cache_header = "无效的波形缓存头。",
    error_waveform_cache_magic = "无效的波形缓存标识。",
    error_waveform_cache_parse = "无法解析波形缓存头。",
    error_waveform_cache_unsupported = "不支持的波形缓存数据。",
    error_waveform_cache_incomplete = "波形缓存数据不完整。",
    error_internal_preview_requires_sws = "内部预览播放需要 SWS 扩展。\n\n请安装/更新 SWS，然后重启 REAPER。",
    error_preview_file_not_found = "未找到预览文件: \n\n{path}",
    error_preview_source_failed = "无法创建预览源: \n\n{path}",
    error_preview_object_failed = "无法创建内部预览对象。",
    error_preview_start_failed = "无法启动内部预览播放。",
    error_no_preview_for_snapshot = "此快照没有预览文件。\n\n可以重新保存快照以自动渲染 preview.mp3，或手动将 preview.mp3 放到这里: \n\n{folder}",
    error_folder_browser_requires_js = "文件夹浏览器需要 js_ReaScriptAPI 扩展。",

    status_ready = "快照库已就绪。",
    status_capture_failed = "捕获失败。",
    status_save_cancelled_same_name = "已取消保存: 未覆盖同名快照。",
    status_snapshot_write_failed = "无法写入快照文件。",
    status_saved_preview_ok = "已保存 {mode} 快照并渲染预览: {name}{media_note}",
    status_saved_preview_failed = "已保存 {mode} 快照，但预览渲染失败: {name}{media_note}",
    status_media_archived_note = " | 已归档媒体: {count}",
    status_missing_media_note = " | 缺失媒体: {count}",
    status_no_snapshot_selected = "未选择快照。",
    status_load_failed = "载入失败。",
    status_loaded_snapshot = "已载入快照: {name}",
    status_export_data_missing = "导出失败: 快照数据缺失。",
    status_export_cancelled = "已取消导出。",
    status_export_failed = "导出失败。",
    status_exported_zip = "已导出快照 ZIP: {path}",
    status_exported_zip_count = "已导出 {count} 个快照到 ZIP: {path}",
    status_import_cancelled = "已取消导入。",
    status_import_zip_missing = "导入失败: ZIP 文件缺失。",
    status_import_failed = "导入失败。",
    status_import_snapshot_missing = "导入失败: ZIP 中未找到 snapshot.lua。",
    status_import_invalid_data = "导入失败: 快照数据无效。",
    status_imported_snapshot = "已导入快照: {name}",
    status_imported_snapshot_count = "已导入 {count} 个快照。",
    status_already_favorite = "已经在收藏中。",
    status_already_not_favorite = "已经取消收藏。",
    status_added_favorite = "已添加到收藏。",
    status_removed_favorite = "已取消收藏。",
    status_removed_deleted = "已移除快照并删除本地文件夹。",
    status_removed_deleted_count = "已移除 {count} 个快照并删除本地文件夹。",
    status_remove_delete_failed = "删除失败，快照已保留在资源库中。",
    status_removed_index_delete_failed = "删除失败，快照已保留在资源库中。",
    status_renamed_snapshot = "已重命名快照: {name}",
    status_edited_snapshot = "已编辑快照: {name}",
    status_rename_cancelled = "已取消重命名。",
    status_no_preview_waveform = "没有可用于波形显示的预览文件。",
    status_waveform_extension_missing = "波形缓存扩展不可用。",
    status_waveform_read_failed = "无法读取波形缓存。",
    status_waveform_building = "正在构建波形缓存...",
    status_waveform_build_failed = "波形缓存构建失败。",
    status_looping_preview = "循环预览: {name}",
    status_preview_finished = "预览结束。",
    status_internal_preview_requires_sws = "内部预览需要 SWS 扩展。",
    status_preview_file_missing = "预览文件缺失。",
    status_preview_source_failed = "无法创建预览源。",
    status_preview_object_failed = "无法创建预览对象。",
    status_preview_start_failed = "无法开始预览。",
    status_playing_preview_from = "从 {seconds} 秒播放预览: {name}",
    status_playing_preview = "正在播放预览: {name}",
    status_preview_cursor_start = "预览光标已返回开头。",
    status_preview_stopped = "预览已停止。",
    status_preview_loop_enabled = "已启用预览循环。",
    status_preview_loop_disabled = "已关闭预览循环。",
    status_sort_changed = "快照列表排序已更改: {label}",
    status_settings_applied = "设置已应用。",
  },

  zh_TW = {
    language_english = "English",
    language_simplified_chinese = "简体中文",
    language_traditional_chinese = "繁體中文",

    title = "SFX Snapshot Library",
    subtitle = "專業模組化音效快照封存 / 還原系統",
    error = "錯誤",
    ok = "確定",
    cancel = "取消",
    apply = "套用",
    save = "儲存",
    load = "載入",
    update_snapshot = "更新快照",
    edit_snapshot = "編輯快照",
    play = "播放",
    stop = "停止",
    options = "選項",
    settings = "設定",
    browse = "瀏覽",
    remove = "移除",
    rename = "重新命名",
    open_folder = "開啟資料夾",
    export_zip = "匯出 ZIP",
    import_zip = "匯入 ZIP",
    view_shortcuts = "快捷鍵",
    add_favorite = "加入收藏",
    remove_favorite = "取消收藏",
    favorite = "收藏",

    category_all = "全部",
    category_uncategorized = "未分類",
    unnamed = "未命名",
    snapshot = "快照",
    default_snapshot_name_format = "音效快照 %Y-%m-%d %H-%M-%S",
    imported_snapshot = "匯入的快照",

    capture_razor = "剃刀編輯",
    capture_time_selection = "時間選區",
    capture_time_selection_selected_items = "時間選區（選取物件）",
    capture_unknown = "未知",

    popup_save_snapshot = "儲存快照",
    popup_edit_snapshot = "編輯快照",
    popup_load_snapshot = "載入快照",
    popup_rename_snapshot = "重新命名快照",
    popup_settings = "設定",

    search_hint = "搜尋名稱 / 分類 / 標籤 / 描述...",
    category_label = "分類: ",
    favorites_only = "僅顯示收藏",
    no_snapshot_selected = "尚未選取快照。",
    no_snapshots_found = "找不到快照。",
    no_existing_items = "沒有現有項目。",
    no_existing_categories = "沒有現有分類。",
    no_existing_tags = "沒有現有標籤。",

    waveform_preview_unavailable = "波形預覽不可用。",
    back_to_start = "回到開頭",
    loop_on = "循環開",
    loop_off = "循環關",
    tooltip_waveform_seek = "點擊波形可設定游標，並從該位置播放。",
    tooltip_preview_start = "將預覽游標回到開頭。",
    tooltip_preview_volume = "預覽音量: 上下拖曳調整，雙擊重設為 0 dB。",

    meta_category = "分類: {value}",
    meta_source = "來源: {value}",
    meta_tags = "標籤: {value}",
    meta_duration = "長度: {value} 秒",
    meta_tracks = "軌道: {value}",
    meta_items = "媒體物件: {value}",
    meta_media_archived = "已封存媒體: {value}",
    meta_missing_media = "缺少媒體: {value}",
    meta_created = "建立時間: {value}",
    meta_preview_skip = "預覽跳過: {value} 秒",
    meta_preview_missing = "預覽: 缺少",
    meta_preview_error = "預覽錯誤: {value}",
    meta_detail_summary = "長度 {duration}秒    軌道 {tracks}    物件 {items}    媒體 {media}",

    smart_save_info = "智慧儲存: 剃刀編輯優先。如果沒有剃刀編輯，則擷取目前時間選區。",
    edit_snapshot_info = "編輯目前快照的名稱、分類、標籤和描述。",
    field_name = "名稱",
    field_new_name = "新名稱:",
    field_description = "描述",
    category_dropdown = "分類 ▼",
    tags_dropdown = "標籤 ▼",
    tooltip_choose_categories = "從現有分類中選擇",
    tooltip_append_tags = "從現有標籤中追加",
    confirm_overwrite_snapshot = "已存在同名快照: {name}\n\n點擊[確定]將覆寫，點擊[取消]返回儲存視窗以便改名。",
    confirm_update_snapshot = "是否使用目前剃刀編輯或時間選區取代快照「{name}」？\n\n舊快照內容將被永久取代，並保留其名稱、分類、標籤和描述。",
    tip_reuse_names = "提示: 點擊分類或標籤可重用現有名稱。",

    load_snapshot_name = "載入: {name}",
    load_to_new_tracks = "載入到新軌道",
    check_empty_target = "載入前檢查目標區域是否為空",
    restore_markers = "還原標記",
    restore_regions = "還原區域",
    restore_tempo = "還原速度和拍號",
    restore_track_info = "還原軌道名稱和 FX",
    restore_empty_tracks = "還原空軌道",
    tooltip_restore_track_info_load = "軌道名稱和 FX 只會套用到本次載入時建立的軌道。",
    tooltip_restore_track_info_settings = "軌道名稱和 FX 只會套用到載入時建立的軌道。",
    tooltip_restore_empty_tracks = "關閉時，會跳過沒有媒體物件的已擷取軌道，並壓縮剩餘軌道。",

    interface = "介面",
    settings_language = "語言:",
    settings_library_location = "資源庫位置",
    settings_library_description = "選擇快照、元資料和預覽檔案的儲存位置。",
    select_library_directory = "選擇資源庫資料夾: ",
    use_reaper_resource_path = "使用 REAPER 資源路徑",
    open_current_library = "開啟目前資源庫",
    settings_load_options = "載入選項",
    settings_save_options = "儲存選項",
    settings_snapshot_options = "快照選項",
    settings_snapshot_sort = "列表排序: ",
    settings_display_options = "顯示選項",
    show_load_popup = "顯示載入確認視窗",
    auto_render_preview = "儲存時自動算繪 preview.mp3",
    skip_preview_leading_empty = "算繪預覽時跳過開頭空白內容",
    show_capture_abbreviations = "顯示 [TS]/[RE] 擷取標籤",
    show_tips = "顯示提示",
    place_info_panel_bottom = "將資訊面板放在底部",
    sort_newest = "最新優先",
    sort_oldest = "最舊優先",
    sort_alphabetical = "依字母排序",

    dialog_export_zip_title = "匯出 SFX 快照 ZIP",
    dialog_export_folder_title = "選擇匯出資料夾: ",
    dialog_import_zip_title = "匯入 SFX 快照 ZIP",
    dialog_zip_filter = "ZIP 檔案 (*.zip)\0*.zip\0所有檔案 (*.*)\0*.*\0",
    shortcut_help_title = "快捷鍵",
    shortcut_help_text = "Ctrl+S：儲存快照\nCtrl+L：載入目前選取的快照\nAlt+Enter：載入目前選取的快照\n滑鼠中鍵點擊清單項目：載入該快照\nSpace：播放 / 停止目前快照預覽\nF：加入 / 取消收藏目前快照\nShift+Delete：移除選取的快照\nCtrl+,：開啟設定\nEnter：確認目前彈窗\nEsc：關閉腳本",
    undo_load_snapshot = "載入 SFX 快照",

    confirm_remove_snapshot = "要移除此快照並刪除本機資料夾嗎？\n\n{name}\n\n資料夾: \n{folder}",
    confirm_remove_snapshots = "要移除這 {count} 個快照並刪除其本機資料夾嗎？\n\n{names}",

    error_failed_open_source_media = "無法開啟來源媒體: {path}",
    error_failed_write_archived_media = "無法寫入封存媒體: {path}",
    error_refuse_delete_outside = "拒絕刪除快照目錄之外的資料夾。",
    error_failed_delete_snapshot_folder = "無法刪除快照資料夾: {path}",
    error_failed_offline_snapshot_media = "無法讓已載入的快照媒體離線: {name}",
    error_snapshot_folder_not_found = "找不到快照資料夾。",
    error_snapshot_name_exists = "已存在同名快照: {name}",
    error_snapshot_folder_exists = "已存在同名快照資料夾: {folder}",
    error_failed_rename_snapshot_folder = "無法重新命名快照資料夾: \n\n{source}\n\n->\n\n{dest}",
    error_failed_update_snapshot_data = "無法更新快照資料檔案。",
    error_zip_create_windows = "無法透過 PowerShell .NET ZipFile 建立 ZIP。請檢查匯出資料夾是否可寫入: \n\n{path}",
    error_zip_create_unix = "無法建立 ZIP。macOS 使用 ditto，Linux 需要 zip。",
    error_zip_not_found = "找不到 ZIP 檔案。",
    error_zip_extract_windows = "無法解壓 ZIP。已嘗試 Windows tar.exe 和 PowerShell .NET ZipFile。",
    error_zip_extract_unix = "無法解壓 ZIP。macOS 使用 ditto，Linux 需要 unzip。",
    error_imported_data_missing = "匯入的快照資料缺失。",
    error_reaper_enum_unavailable = "REAPER 檔案列舉 API 不可用。",
    error_failed_copy_imported_snapshot_folder = "無法複製匯入的快照資料夾。",
    error_no_capture_context = "找不到剃刀編輯或時間選區。儲存前請建立剃刀編輯區域或時間選區。",
    error_capture_empty = "{mode} 中沒有媒體物件、標記、區域或速度/拍號標記。",
    error_invalid_snapshot_data = "無效的快照資料。",
    error_snapshot_has_no_tracks = "快照沒有軌道。",
    error_target_area_not_empty = "目標區域不是空的。軌道 {track} 在此範圍內已有物件。",
    error_invalid_snapshot_folder = "無效的快照資料夾。",
    error_invalid_preview_range = "無效的預覽算繪範圍。",
    error_preview_mp3_not_created = "未建立 preview.mp3。請檢查 REAPER 算繪設定。",
    error_load_snapshot_detail = "無法載入快照: \n\n{detail}",
    error_snapshot_data_missing_detail = "找不到快照資料檔案: \n\n{path}",
    error_zip_missing_detail = "找不到 ZIP 檔案: \n\n{path}",
    error_zip_invalid_package_detail = "此 ZIP 看起來不是 SFX Snapshot 套件。\n\n找不到 snapshot.lua。",
    error_import_read_detail = "無法讀取匯入的快照: \n\n{detail}",
    error_waveform_cache_file_not_found = "找不到波形快取檔案。",
    error_lua_no_string_unpack = "此 REAPER Lua 版本不支援 string.unpack。",
    error_waveform_cache_open = "無法開啟波形快取。",
    error_waveform_cache_header = "無效的波形快取標頭。",
    error_waveform_cache_magic = "無效的波形快取識別。",
    error_waveform_cache_parse = "無法解析波形快取標頭。",
    error_waveform_cache_unsupported = "不支援的波形快取資料。",
    error_waveform_cache_incomplete = "波形快取資料不完整。",
    error_internal_preview_requires_sws = "內部預覽播放需要 SWS 擴充。\n\n請安裝/更新 SWS，然後重新啟動 REAPER。",
    error_preview_file_not_found = "找不到預覽檔案: \n\n{path}",
    error_preview_source_failed = "無法建立預覽來源: \n\n{path}",
    error_preview_object_failed = "無法建立內部預覽物件。",
    error_preview_start_failed = "無法啟動內部預覽播放。",
    error_no_preview_for_snapshot = "此快照沒有預覽檔案。\n\n可以重新儲存快照以自動算繪 preview.mp3，或手動將 preview.mp3 放到這裡: \n\n{folder}",
    error_folder_browser_requires_js = "資料夾瀏覽器需要 js_ReaScriptAPI 擴充。",

    status_ready = "快照庫已就绪。",
    status_capture_failed = "擷取失敗。",
    status_save_cancelled_same_name = "已取消儲存: 未覆寫同名快照。",
    status_snapshot_write_failed = "無法寫入快照檔案。",
    status_saved_preview_ok = "已儲存 {mode} 快照並算繪預覽: {name}{media_note}",
    status_saved_preview_failed = "已儲存 {mode} 快照，但預覽算繪失敗: {name}{media_note}",
    status_media_archived_note = " | 已封存媒體: {count}",
    status_missing_media_note = " | 缺少媒體: {count}",
    status_no_snapshot_selected = "尚未選取快照。",
    status_load_failed = "載入失敗。",
    status_loaded_snapshot = "已載入快照: {name}",
    status_export_data_missing = "匯出失敗: 快照資料缺失。",
    status_export_cancelled = "已取消匯出。",
    status_export_failed = "匯出失敗。",
    status_exported_zip = "已匯出快照 ZIP: {path}",
    status_exported_zip_count = "已匯出 {count} 個快照到 ZIP: {path}",
    status_import_cancelled = "已取消匯入。",
    status_import_zip_missing = "匯入失敗: ZIP 檔案缺失。",
    status_import_failed = "匯入失敗。",
    status_import_snapshot_missing = "匯入失敗: ZIP 中找不到 snapshot.lua。",
    status_import_invalid_data = "匯入失敗: 快照資料無效。",
    status_imported_snapshot = "已匯入快照: {name}",
    status_imported_snapshot_count = "已匯入 {count} 個快照。",
    status_already_favorite = "已經在收藏中。",
    status_already_not_favorite = "已經取消收藏。",
    status_added_favorite = "已加入收藏。",
    status_removed_favorite = "已取消收藏。",
    status_removed_deleted = "已移除快照並刪除本機資料夾。",
    status_removed_deleted_count = "已移除 {count} 個快照並刪除本機資料夾。",
    status_remove_delete_failed = "刪除失敗，快照已保留在資源庫中。",
    status_removed_index_delete_failed = "刪除失敗，快照已保留在資源庫中。",
    status_renamed_snapshot = "已重新命名快照: {name}",
    status_edited_snapshot = "已編輯快照: {name}",
    status_rename_cancelled = "已取消重新命名。",
    status_no_preview_waveform = "沒有可用於波形顯示的預覽檔案。",
    status_waveform_extension_missing = "波形快取擴充不可用。",
    status_waveform_read_failed = "無法讀取波形快取。",
    status_waveform_building = "正在建立波形快取...",
    status_waveform_build_failed = "波形快取建立失敗。",
    status_looping_preview = "循環預覽: {name}",
    status_preview_finished = "預覽結束。",
    status_internal_preview_requires_sws = "內部預覽需要 SWS 擴充。",
    status_preview_file_missing = "預覽檔案缺失。",
    status_preview_source_failed = "無法建立預覽來源。",
    status_preview_object_failed = "無法建立預覽物件。",
    status_preview_start_failed = "無法開始預覽。",
    status_playing_preview_from = "從 {seconds} 秒播放預覽: {name}",
    status_playing_preview = "正在播放預覽: {name}",
    status_preview_cursor_start = "預覽游標已回到開頭。",
    status_preview_stopped = "預覽已停止。",
    status_preview_loop_enabled = "已啟用預覽循環。",
    status_preview_loop_disabled = "已關閉預覽循環。",
    status_sort_changed = "快照列表排序已變更: {label}",
    status_settings_applied = "設定已套用。",
  },
}

local language = LANGUAGE_DEFAULT
local T = TEXT[LANGUAGE_DEFAULT]

function NormalizeLanguageId(id)
  id = tostring(id or "")
  id = LANGUAGE_ALIASES[id] or id
  if TEXT[id] then return id end
  return LANGUAGE_DEFAULT
end

function SetLanguage(id)
  language = NormalizeLanguageId(id)
  T = TEXT[language] or TEXT[LANGUAGE_DEFAULT]
end

function LoadLanguageSetting()
  local saved = ""
  if reaper.GetExtState then
    saved = reaper.GetExtState(EXT_SECTION, "language")
  end
  SetLanguage(saved)
end

function Tr(key, vars)
  local text = (T and T[key]) or (TEXT[LANGUAGE_DEFAULT] and TEXT[LANGUAGE_DEFAULT][key]) or tostring(key)

  if type(vars) == "table" then
    text = text:gsub("{([%w_]+)}", function(name)
      local value = vars[name]
      if value == nil then return "{" .. name .. "}" end
      return tostring(value)
    end)
  end

  return text
end

function UiLabel(key, id, vars)
  local label = Tr(key, vars)
  if id and id ~= "" then
    return label .. "##" .. tostring(id)
  end
  return label
end

function GetLanguageDisplayName(id)
  local lang_id = NormalizeLanguageId(id)
  for _, option in ipairs(LANGUAGE_OPTIONS) do
    if option.id == lang_id then
      return GetLanguageOptionLabel(option)
    end
  end
  return lang_id
end

function GetLanguageOptionLabel(option)
  option = option or LANGUAGE_OPTIONS[1]
  local text = TEXT[option.id] or TEXT[LANGUAGE_DEFAULT]
  return (text and text[option.label_key]) or option.id
end

function DisplayCategory(category)
  local c = tostring(category or "")
  if c == "" or c == "Uncategorized" then
    return Tr("category_uncategorized")
  end
  return c
end

function DisplayCategoryFilter(category)
  if tostring(category or "") == "All" then
    return Tr("category_all")
  end
  return DisplayCategory(category)
end

function GetCaptureModeDisplay(mode, fallback_label)
  mode = tostring(mode or "")
  if mode == "razor" then
    return Tr("capture_razor")
  elseif mode == "time_selection_selected_items" then
    return Tr("capture_time_selection_selected_items")
  elseif mode == "time_selection" then
    return Tr("capture_time_selection")
  end

  local fallback = tostring(fallback_label or "")
  if fallback == "Razor Edit" then return Tr("capture_razor") end
  if fallback == "Time Selection" then return Tr("capture_time_selection") end
  if fallback == "Time Selection (Selected Items)" then return Tr("capture_time_selection_selected_items") end
  if fallback ~= "" then return fallback end
  return Tr("capture_unknown")
end

function GetSortLabel(key)
  if key == "oldest" then return Tr("sort_oldest") end
  if key == "alphabetical" then return Tr("sort_alphabetical") end
  return Tr("sort_newest")
end

LoadLanguageSetting()

----------------------------------------
-- Constants
----------------------------------------

local DEFAULT_LIBRARY_DIR = RESOURCE_PATH .. "/SFX Snapshot Library"
local SNAPSHOT_DIR_NAME = "snapshots"
local INDEX_FILE_NAME = "index.lua"
local PREVIEW_FILE_NAME = "preview.mp3"
local LEGACY_PREVIEW_FILE_NAME = "preview.wav"
local WAVEFORM_CACHE_EXTENSION = ".smwf"

local ctx = ImGui.CreateContext(SCRIPT_NAME)
local CHILD_FLAGS_BORDER = ImGui.ChildFlags_Borders or 1
local WINDOW_FLAGS_NONE = 0
local MOUSE_BUTTON_LEFT = ImGui.MouseButton_Left or 0
local MOUSE_BUTTON_RIGHT = ImGui.MouseButton_Right or 1
local MOUSE_BUTTON_MIDDLE = ImGui.MouseButton_Middle or 2
local KEY_SPACE = ImGui.Key_Space or 32
local KEY_ESCAPE = ImGui.Key_Escape or 27
local KEY_DELETE = ImGui.Key_Delete or 522
local KEY_ENTER = ImGui.Key_Enter or (reaper.ImGui_Key_Enter and reaper.ImGui_Key_Enter())
local KEY_KEYPAD_ENTER = ImGui.Key_KeypadEnter or (reaper.ImGui_Key_KeypadEnter and reaper.ImGui_Key_KeypadEnter())
local KEY_F = ImGui.Key_F or 575
local KEY_S = ImGui.Key_S or (reaper.ImGui_Key_S and reaper.ImGui_Key_S())
local KEY_L = ImGui.Key_L or (reaper.ImGui_Key_L and reaper.ImGui_Key_L())
local KEY_COMMA = ImGui.Key_Comma or (reaper.ImGui_Key_Comma and reaper.ImGui_Key_Comma())
local KEY_LEFT_CTRL = ImGui.Key_LeftCtrl
local KEY_RIGHT_CTRL = ImGui.Key_RightCtrl
local KEY_LEFT_SHIFT = ImGui.Key_LeftShift or 656
local KEY_RIGHT_SHIFT = ImGui.Key_RightShift or 660
local KEY_LEFT_ALT = ImGui.Key_LeftAlt or (reaper.ImGui_Key_LeftAlt and reaper.ImGui_Key_LeftAlt())
local KEY_RIGHT_ALT = ImGui.Key_RightAlt or (reaper.ImGui_Key_RightAlt and reaper.ImGui_Key_RightAlt())
local MOD_CTRL = ImGui.Mod_Ctrl or 2
local MOD_SHIFT = ImGui.Mod_Shift or 1
local MOD_ALT = ImGui.Mod_Alt or 4
local WAVEFORM_CACHE_PIXELS = 2048
local WAVEFORM_CACHE_MAX_CHANNELS = 6
local SNAPSHOT_DISK_SYNC_INTERVAL = 3.0
local PREVIEW_VOLUME_MIN_DB = -60.0
local PREVIEW_VOLUME_MAX_DB = 12.0
local PREVIEW_VOLUME_ZERO_RATIO = 0.5
local PREVIEW_VOLUME_DRAG_SPEED = 0.006
local HEADER_CLOSE_SLOT_W = 18
local HEADER_CLOSE_HIT_H = 16
local HEADER_CLOSE_X_SIZE = 7

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
MOUSE_BUTTON_MIDDLE = ImGuiValue(ImGui.MouseButton_Middle, MOUSE_BUTTON_MIDDLE)
KEY_SPACE = ImGuiValue(ImGui.Key_Space, KEY_SPACE)
KEY_ESCAPE = ImGuiValue(ImGui.Key_Escape, KEY_ESCAPE)
KEY_DELETE = ImGuiValue(ImGui.Key_Delete, KEY_DELETE)
KEY_ENTER = ImGuiValue(ImGui.Key_Enter, KEY_ENTER)
KEY_KEYPAD_ENTER = ImGuiValue(ImGui.Key_KeypadEnter, KEY_KEYPAD_ENTER)
KEY_F = ImGuiValue(ImGui.Key_F, KEY_F)
KEY_S = ImGuiValue(ImGui.Key_S, KEY_S)
KEY_L = ImGuiValue(ImGui.Key_L, KEY_L)
KEY_COMMA = ImGuiValue(ImGui.Key_Comma, KEY_COMMA)
KEY_LEFT_CTRL = ImGuiValue(ImGui.Key_LeftCtrl, KEY_LEFT_CTRL)
KEY_RIGHT_CTRL = ImGuiValue(ImGui.Key_RightCtrl, KEY_RIGHT_CTRL)
KEY_LEFT_SHIFT = ImGuiValue(ImGui.Key_LeftShift, KEY_LEFT_SHIFT)
KEY_RIGHT_SHIFT = ImGuiValue(ImGui.Key_RightShift, KEY_RIGHT_SHIFT)
KEY_LEFT_ALT = ImGuiValue(ImGui.Key_LeftAlt, KEY_LEFT_ALT)
KEY_RIGHT_ALT = ImGuiValue(ImGui.Key_RightAlt, KEY_RIGHT_ALT)
MOD_CTRL = ImGuiValue(ImGui.Mod_Ctrl, MOD_CTRL)
MOD_SHIFT = ImGuiValue(ImGui.Mod_Shift, MOD_SHIFT)
MOD_ALT = ImGuiValue(ImGui.Mod_Alt, MOD_ALT)

local WINDOW_FLAGS_NO_COLLAPSE = ImGuiValue(ImGui.WindowFlags_NoCollapse, 32)
local WINDOW_FLAGS_NO_TITLE_BAR = ImGuiValue(ImGui.WindowFlags_NoTitleBar, 1)
local WINDOW_FLAGS_MAIN = WINDOW_FLAGS_NO_COLLAPSE + WINDOW_FLAGS_NO_TITLE_BAR
local SNAPSHOT_ARRANGE_DND_PAYLOAD_TYPE = "SFXSnapshotDrag"
local SNAPSHOT_ARRANGE_DRAG_CARRIER_DIR = "_native_drag_carriers"
local SNAPSHOT_ARRANGE_NATIVE_DROP_TIMEOUT = 30.0
local SNAPSHOT_ARRANGE_NATIVE_DROP_RELEASE_GRACE = 3.0
local COND_ALWAYS = ImGuiValue(ImGui.Cond_Always, 1)
local DRAGDROP_FLAGS_SOURCE_NO_PREVIEW_TOOLTIP = ImGuiValue(ImGui.DragDropFlags_SourceNoPreviewTooltip, 1)
local SNAPSHOT_ARRANGE_DND_SOURCE_FLAGS = DRAGDROP_FLAGS_SOURCE_NO_PREVIEW_TOOLTIP

local MOUSE_CURSOR_RESIZE_NS = ImGuiValue(ImGui.MouseCursor_ResizeNS, 3)
local MOUSE_CURSOR_RESIZE_EW = ImGuiValue(ImGui.MouseCursor_ResizeEW, 4)
local FOCUSED_FLAGS_ROOT_AND_CHILDREN = ImGuiValue(ImGui.FocusedFlags_RootAndChildWindows, 3)

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

local STATUS_BAR_FONT_SIZE = 12
local STATUS_BAR_PADDING_Y = 4
local STATUS_BAR_HEIGHT = STATUS_BAR_FONT_SIZE + STATUS_BAR_PADDING_Y * 2

----------------------------------------
-- State
----------------------------------------

local state = {
  library_dir = "",
  snapshots = {},
  selected = 1,
  selected_snapshot_ids = {},
  selection_anchor_index = 1,

  filter = "",
  category_filter = "All",
  show_favorites_only = false,

  load_to_new_tracks = false,
  restore_markers = true,
  restore_regions = true,
  restore_tempo = true,
  restore_track_info = false,
  restore_empty_tracks = false,
  check_empty_space = true,
  show_load_popup = true,
  auto_render_preview = true,
  skip_preview_leading_empty = true,
  show_capture_abbreviations = false,
  show_tips = true,
  info_panel_at_bottom = true,
  bottom_split_ratio = 0.72,
  side_split_ratio = 0.64,
  sort_order = "newest",
  language = language,

  status = Tr("status_ready"),
  error = "",

  show_save_popup = false,
  request_open_save_popup = false,
  request_open_edit_popup = false,
  request_open_rename_popup = false,
  request_open_load_confirm_popup = false,
  request_execute_load = false,
  load_popup_load_to_new_tracks = false,
  load_popup_restore_markers = true,
  load_popup_restore_regions = true,
  load_popup_restore_tempo = true,
  load_popup_restore_track_info = false,
  load_popup_restore_empty_tracks = false,
  load_popup_check_empty_space = true,
  save_name = "",
  save_category = "",
  save_tags = "",
  save_description = "",
  save_in_progress = false,
  save_submitted = false,
  edit_snapshot_id = "",
  rename_snapshot_id = "",
  rename_name = "",

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
  preview_locate_path = "",
  preview_locate_position = 0,
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
  peak_build_queue = {},

  snapshot_list_focused = false,
  snapshot_disk_sync_at = 0,
  main_window_focused = false,
  modal_popup_active = false,
  request_open_settings_popup = false,
  space_key_consumed_frame = false,
  request_close = false,
  snapshot_arrange_drag = nil,
  snapshot_arrange_drag_counter = 0,
  snapshot_arrange_consumed_payload = "",
  snapshot_arrange_consumed_until = 0,
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
    name = os.date(Tr("default_snapshot_name_format"))
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
  if NormalizePathForCompare and NormalizePathForCompare(src_path) == NormalizePathForCompare(dst_path) then
    return true
  end

  local src = io.open(src_path, "rb")
  if not src then return false, Tr("error_failed_open_source_media", { path = tostring(src_path) }) end

  local dst = io.open(dst_path, "wb")
  if not dst then
    src:close()
    return false, Tr("error_failed_write_archived_media", { path = tostring(dst_path) })
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

function RemoveUnreferencedSnapshotMedia(data, snapshot_folder)
  local media_dir = JoinPath(snapshot_folder, "media")
  if not SnapshotDirectoryExists(media_dir) or not reaper.EnumerateFiles or not reaper.EnumerateSubdirectories then
    return
  end

  local referenced = {}
  for _, tr in ipairs(data.tracks or {}) do
    for _, item_data in ipairs(tr.items or {}) do
      for _, path in ipairs(ExtractQuotedFilePathsFromChunk(item_data.chunk or "")) do
        local relative_path = tostring(path):match("^" .. SNAPSHOT_MEDIA_TOKEN .. "[/\\](.+)$")
        if relative_path and relative_path ~= "" then
          referenced[NormalizePathForCompare(relative_path)] = true
        end
      end
    end
  end

  if next(referenced) == nil then
    DeleteDirectoryRecursive(media_dir)
    return
  end

  local function has_reference_under(relative_dir)
    local prefix = NormalizePathForCompare(relative_dir) .. "/"
    for relative_path in pairs(referenced) do
      if relative_path:sub(1, #prefix) == prefix then
        return true
      end
    end
    return false
  end

  local function cleanup_folder(folder, relative_dir)
    local files = {}
    local file_index = 0
    while true do
      local file_name = reaper.EnumerateFiles(folder, file_index)
      if not file_name then break end
      files[#files + 1] = file_name
      file_index = file_index + 1
    end

    for _, file_name in ipairs(files) do
      local relative_path = relative_dir == "" and file_name or JoinPath(relative_dir, file_name)
      if not referenced[NormalizePathForCompare(relative_path)] then
        pcall(os.remove, JoinPath(folder, file_name))
      end
    end

    local subdirectories = {}
    local directory_index = 0
    while true do
      local directory_name = reaper.EnumerateSubdirectories(folder, directory_index)
      if not directory_name then break end
      subdirectories[#subdirectories + 1] = directory_name
      directory_index = directory_index + 1
    end

    for _, directory_name in ipairs(subdirectories) do
      local relative_path = relative_dir == "" and directory_name or JoinPath(relative_dir, directory_name)
      local subdirectory = JoinPath(folder, directory_name)
      if has_reference_under(relative_path) then
        cleanup_folder(subdirectory, relative_path)
      else
        DeleteDirectoryRecursive(subdirectory)
      end
    end
  end

  cleanup_folder(media_dir, "")
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
  return JoinPath(GetSnapshotFolderForFileOperation(snapshot), "snapshot.lua")
end

function GetSnapshotPreviewPath(snapshot)
  local folder = GetSnapshotFolderForFileOperation(snapshot)
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

function GetPreviewWaveformCachePath(preview_path)
  preview_path = tostring(preview_path or "")
  if preview_path == "" then return "" end

  local dir = GetFileDir(preview_path)
  local name = GetFileName(preview_path)
  local stem = name:match("^(.*)%.[^%.]*$") or name

  return JoinPath(dir, stem .. WAVEFORM_CACHE_EXTENSION)
end

function SnapshotMetaMatches(snapshot, meta, folder_name)
  if type(snapshot) ~= "table" or type(meta) ~= "table" then return false end

  local snapshot_id = tostring(snapshot.id or "")
  local meta_id = tostring(meta.id or "")
  if snapshot_id ~= "" and meta_id ~= "" and snapshot_id == meta_id then
    return true
  end

  local snapshot_name = tostring(snapshot.name or "")
  local meta_name = tostring(meta.name or "")
  if snapshot_name ~= "" and meta_name ~= "" and snapshot_name == meta_name then
    return true
  end

  local snapshot_folder = tostring(snapshot.folder or "")
  local meta_folder = tostring(meta.folder or "")
  folder_name = tostring(folder_name or "")
  if snapshot_folder ~= "" and meta_folder ~= "" and snapshot_folder == meta_folder then
    return true
  end

  if snapshot_folder ~= "" and folder_name ~= "" and snapshot_folder == folder_name then
    return true
  end

  return false
end

function SnapshotFolderMatches(snapshot, folder, folder_name)
  local data = LoadLuaTable(JoinPath(folder, "snapshot.lua"))
  if type(data) ~= "table" then return false end

  return SnapshotMetaMatches(snapshot, data.meta or {}, folder_name)
end

function ResolveSnapshotFolder(snapshot)
  if type(snapshot) ~= "table" then return "" end

  local root = GetSnapshotsRoot()
  local tried = {}
  local candidates = {}

  local function add_candidate(folder_name)
    folder_name = tostring(folder_name or "")
    if folder_name == "" then return end

    local path = JoinPath(root, folder_name)
    local key = NormalizePath(path)
    if not tried[key] then
      tried[key] = true
      candidates[#candidates + 1] = { path = path, name = folder_name }
    end
  end

  add_candidate(snapshot.folder)
  add_candidate(snapshot.id)
  add_candidate(SanitizeFileName(snapshot.name))

  for _, candidate in ipairs(candidates) do
    if FileExists(JoinPath(candidate.path, "snapshot.lua")) then
      return candidate.path, candidate.name
    end
  end

  if reaper.EnumerateSubdirectories then
    local i = 0
    while true do
      local folder_name = reaper.EnumerateSubdirectories(root, i)
      if not folder_name then break end

      local folder = JoinPath(root, folder_name)
      if SnapshotFolderMatches(snapshot, folder, folder_name) then
        return folder, folder_name
      end

      i = i + 1
    end
  end

  return "", ""
end

function GetSnapshotFolderForFileOperation(snapshot)
  local folder = ResolveSnapshotFolder(snapshot)
  if folder and folder ~= "" then return folder end
  return GetSnapshotFolder(snapshot)
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

function IsSnapshotPathInsideRoot(path)
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

function ReleaseSnapshotFileLocks()
  if StopInternalPreview then
    pcall(StopInternalPreview, true)
  end

  if CancelAllWaveformCacheJobs then
    CancelAllWaveformCacheJobs()
  elseif reaper.SM_WFC_Cancel then
    pcall(reaper.SM_WFC_Cancel, "")
  end

  if ResetWaveformCacheState then
    ResetWaveformCacheState(false)
  end

  if reaper.UpdateArrange then
    pcall(reaper.UpdateArrange)
  end
end

function NormalizePathForCompare(path)
  local normalized = NormalizePath(path)
  if reaper.GetOS():find("Win") then
    normalized = Lower(normalized)
  end
  return normalized
end

function GetRelativePathUnderFolder(path, folder)
  local normalized_path = NormalizePath(path)
  local normalized_folder = NormalizePath(folder)

  if normalized_path == "" or normalized_folder == "" then
    return nil
  end

  local compare_path = NormalizePathForCompare(normalized_path)
  local compare_folder = NormalizePathForCompare(normalized_folder)
  local prefix = compare_folder .. "/"

  if compare_path:sub(1, #prefix) ~= prefix then
    return nil
  end

  return normalized_path:sub(#normalized_folder + 2)
end

function MakeOfflineSnapshotMediaPath(original_path, rename_id, index)
  local ext = tostring(original_path or ""):match("(%.[^%.\\/]+)$") or ".offline"
  local temp_dir = GetSystemTempDir()
  local candidate

  repeat
    candidate = JoinPath(
      temp_dir,
      string.format("sfx_snapshot_rename_offline_%s_%03d%s", tostring(rename_id or MakeID()), index, ext)
    )
    index = index + 1
  until not FileExists(candidate)

  return candidate
end

function RewriteSnapshotMediaPathsInChunk(chunk, old_folder, replacement_for_path)
  local changed = false

  local rewritten = tostring(chunk or ""):gsub('(FILE%s+")([^"]+)(")', function(prefix, path, suffix)
    local rel = GetRelativePathUnderFolder(path, old_folder)
    if not rel then
      return prefix .. path .. suffix
    end

    local replacement = replacement_for_path(path, rel)
    if not replacement or replacement == "" then
      return prefix .. path .. suffix
    end

    changed = true
    return prefix .. replacement .. suffix
  end)

  return rewritten, changed
end

function CollectProjectSnapshotMediaReferences(old_folder, new_folder)
  local refs = {
    items = {},
    media_count = 0,
  }
  local offline_paths = {}
  local rename_id = MakeID()
  local offline_index = 1

  local function offline_path_for(path)
    local key = NormalizePathForCompare(path)
    if not offline_paths[key] then
      offline_paths[key] = MakeOfflineSnapshotMediaPath(path, rename_id, offline_index)
      offline_index = offline_index + 1
      refs.media_count = refs.media_count + 1
    end
    return offline_paths[key]
  end

  local track_count = reaper.CountTracks(0)
  for track_index = 0, track_count - 1 do
    local track = reaper.GetTrack(0, track_index)
    if track then
      local item_count = reaper.CountTrackMediaItems(track)
      for item_index = 0, item_count - 1 do
        local item = reaper.GetTrackMediaItem(track, item_index)
        local chunk = item and GetItemChunk(item)
        if chunk and chunk ~= "" then
          local offline_chunk, changed = RewriteSnapshotMediaPathsInChunk(chunk, old_folder, function(path)
            return offline_path_for(path)
          end)

          if changed then
            local new_chunk = RewriteSnapshotMediaPathsInChunk(chunk, old_folder, function(_, rel)
              return JoinPath(new_folder, rel)
            end)

            refs.items[#refs.items + 1] = {
              item = item,
              original_chunk = chunk,
              offline_chunk = offline_chunk,
              new_chunk = new_chunk,
            }
          end
        end
      end
    end
  end

  return refs
end

function IsMediaItemValid(item)
  if not item then return false end
  if reaper.ValidatePtr2 then
    return reaper.ValidatePtr2(0, item, "MediaItem*")
  end
  return true
end

function ApplyProjectSnapshotMediaReferenceChunks(refs, chunk_key, refresh_peaks)
  if type(refs) ~= "table" or type(refs.items) ~= "table" or #refs.items == 0 then
    return true, 0, 0
  end

  local changed = 0
  local failed = 0

  for _, entry in ipairs(refs.items) do
    local item = entry.item
    local chunk = entry[chunk_key]

    if item and chunk and IsMediaItemValid(item) then
      local ok, result = pcall(SetItemChunk, item, chunk)
      if ok and result ~= false then
        changed = changed + 1

        if refresh_peaks then
          if reaper.UpdateItemInProject then
            pcall(reaper.UpdateItemInProject, item)
          end
          if QueueItemPeakBuild then
            QueueItemPeakBuild(item)
          end
        end
      else
        failed = failed + 1
      end
    end
  end

  if refresh_peaks and changed > 0 and PumpPeakBuildQueue then
    PumpPeakBuildQueue(0.25)
  end

  if changed > 0 and reaper.UpdateArrange then
    pcall(reaper.UpdateArrange)
  end

  return failed == 0, changed, failed
end

function RunWindowsPowerShellScript(script)
  if not reaper.GetOS():find("Win") then return false, "" end

  local command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ' .. ShellQuote(script)
  return RunShellCommand(command)
end

function WindowsDirectoryExists(path)
  if not reaper.GetOS():find("Win") then return nil end

  local ps = "$ErrorActionPreference = 'Stop'; " ..
    "if (Test-Path -LiteralPath " .. PowerShellQuote(path) .. " -PathType Container) { Write-Output '1' } else { Write-Output '0' }"
  local command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ' .. ShellQuote(ps)

  if reaper.ExecProcess and RunProcessHidden then
    local ok, output = RunProcessHidden(command, 10000)
    if ok then
      output = tostring(output or "")
      if output:match("1") then return true end
      if output:match("0") then return false end
    end
  end

  local ps_exit = "$ErrorActionPreference = 'Stop'; " ..
    "if (Test-Path -LiteralPath " .. PowerShellQuote(path) .. " -PathType Container) { exit 0 } else { exit 1 }"
  local ok = RunWindowsPowerShellScript(ps_exit)
  return ok == true
end

function SnapshotDirectoryExists(path)
  path = NormalizePath(path)
  if path == "" then return false end

  local win_exists = WindowsDirectoryExists(path)
  if win_exists ~= nil then return win_exists end

  return PathExists(path)
end

function WaitForSnapshotDirectoryDeleted(path, timeout_seconds)
  if not SnapshotDirectoryExists(path) then return true end

  if reaper.GetOS():find("Win") then
    RemoveDirectoryWithPowerShell(path)
  end

  return not SnapshotDirectoryExists(path)
end

function RemoveDirectoryWithPowerShell(path)
  local ps = "$ErrorActionPreference = 'Stop'; " ..
    "if (Test-Path -LiteralPath " .. PowerShellQuote(path) .. ") { " ..
    "Remove-Item -LiteralPath " .. PowerShellQuote(path) .. " -Recurse -Force }"

  return RunWindowsPowerShellScript(ps)
end

function MoveDirectoryWithPowerShell(source_folder, dest_folder)
  local ps = "$ErrorActionPreference = 'Stop'; " ..
    "Move-Item -LiteralPath " .. PowerShellQuote(source_folder) ..
    " -Destination " .. PowerShellQuote(dest_folder) .. " -Force"

  return RunWindowsPowerShellScript(ps)
end

function DeleteDirectoryRecursive(path)
  path = NormalizePath(path)
  if path == "" or not SnapshotDirectoryExists(path) then
    return true
  end

  if not IsSnapshotFolderSafeToDelete(path) then
    return false, Tr("error_refuse_delete_outside")
  end

  ReleaseSnapshotFileLocks()

  local command
  if reaper.GetOS():find("Win") then
    RemoveDirectoryWithPowerShell(path)
    if SnapshotDirectoryExists(path) then
      command = 'rmdir /S /Q ' .. ShellQuote(path)
      RunShellCommand(command)
    end
  else
    command = 'rm -rf -- ' .. ShellQuote(path)
    RunShellCommand(command)
  end

  if not WaitForSnapshotDirectoryDeleted(path, 2.0) then
    return false, Tr("error_failed_delete_snapshot_folder", { path = path })
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

  local default_name = SanitizeFileName(snapshot.name or Tr("title")) .. ".zip"

  if reaper.JS_Dialog_BrowseForSaveFile then
    local ok, rv, out = pcall(
      reaper.JS_Dialog_BrowseForSaveFile,
      Tr("dialog_export_zip_title"),
      state.library_dir,
      default_name,
      Tr("dialog_zip_filter")
    )

    if ok and rv == 1 and out and out ~= "" then
      return EnsureZipExtension(out)
    end

    if ok then return nil end
  end

  if reaper.JS_Dialog_BrowseForFolder then
    local rv, out = reaper.JS_Dialog_BrowseForFolder(Tr("dialog_export_folder_title"), state.library_dir)
    if rv == 1 and out and out ~= "" then
      return JoinPath(out, default_name)
    end
    return nil
  end

  return JoinPath(state.library_dir, default_name)
end

function ZipFolder(source_folder, zip_path, require_snapshot)
  source_folder = NormalizePath(source_folder)
  zip_path = EnsureZipExtension(zip_path)

  if source_folder == "" or (require_snapshot ~= false and not FileExists(JoinPath(source_folder, "snapshot.lua"))) then
    return false, Tr("error_snapshot_folder_not_found")
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

    return false, Tr("error_zip_create_windows", { path = tostring(zip_dir ~= "" and zip_dir or zip_path) })
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
    return false, Tr("error_zip_create_unix")
  end

  return true, zip_path
end

function UnzipFile(zip_path, dest_dir)
  zip_path = NormalizePath(zip_path)
  dest_dir = NormalizePath(dest_dir)

  if zip_path == "" or not FileExists(zip_path) then
    return false, Tr("error_zip_not_found")
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

    return false, Tr("error_zip_extract_windows")
  end

  local command
  if IsMacOS() then
    command = 'ditto -x -k ' .. ShellQuote(zip_path) .. ' ' .. ShellQuote(dest_dir)
  else
    command = 'unzip -q -o ' .. ShellQuote(zip_path) .. ' -d ' .. ShellQuote(dest_dir)
  end

  local ok = RunShellCommand(command)
  if not ok then
    return false, Tr("error_zip_extract_unix")
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

function FindSnapshotDataFolders(root, depth, out, seen)
  root = NormalizePath(root)
  depth = tonumber(depth) or 0
  out = out or {}
  seen = seen or {}

  if root == "" or seen[root] then return out end
  seen[root] = true

  if FileExists(JoinPath(root, "snapshot.lua")) then
    out[#out + 1] = root
    return out
  end

  if depth <= 0 or not reaper.EnumerateSubdirectories then
    return out
  end

  local i = 0
  while true do
    local sub = reaper.EnumerateSubdirectories(root, i)
    if not sub then break end

    FindSnapshotDataFolders(JoinPath(root, sub), depth - 1, out, seen)
    i = i + 1
  end

  return out
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
  if name == "" then name = Tr("imported_snapshot") end

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
    return false, Tr("error_imported_data_missing")
  end

  EnsureDir(dest_folder)

  if not reaper.EnumerateFiles or not reaper.EnumerateSubdirectories then
    return false, Tr("error_reaper_enum_unavailable")
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
    return false, err or Tr("error_failed_copy_imported_snapshot_folder")
  end

  if not FileExists(JoinPath(dest_folder, "snapshot.lua")) then
    return false, Tr("error_failed_copy_imported_snapshot_folder")
  end

  return true
end
function MoveOrCopySnapshotFolder(source_folder, dest_folder)
  source_folder = NormalizePath(source_folder)
  dest_folder = NormalizePath(dest_folder)

  ReleaseSnapshotFileLocks()

  if os.rename(source_folder, dest_folder) then
    return true
  end

  if reaper.GetOS():find("Win") then
    MoveDirectoryWithPowerShell(source_folder, dest_folder)
    if PathExists(dest_folder) then
      return true
    end
  end

  return CopyDirectoryRecursive(source_folder, dest_folder)
end

function MoveSnapshotFolderStrict(source_folder, dest_folder)
  source_folder = NormalizePath(source_folder)
  dest_folder = NormalizePath(dest_folder)

  if source_folder == "" or not PathExists(source_folder) then
    return false, Tr("error_snapshot_folder_not_found")
  end

  if NormalizePath(source_folder) == NormalizePath(dest_folder) then
    return true
  end

  if not IsSnapshotPathInsideRoot(source_folder) or not IsSnapshotPathInsideRoot(dest_folder) then
    return false, Tr("error_refuse_delete_outside")
  end

  if PathExists(dest_folder) then
    return false, Tr("error_snapshot_folder_exists", { folder = GetFileName(dest_folder) })
  end

  EnsureDir(GetFileDir(dest_folder))
  ReleaseSnapshotFileLocks()

  if os.rename(source_folder, dest_folder) then
    if PathExists(dest_folder) and not PathExists(source_folder) then
      return true
    end
  end

  if reaper.GetOS():find("Win") then
    MoveDirectoryWithPowerShell(source_folder, dest_folder)
    if PathExists(dest_folder) and not PathExists(source_folder) then
      return true
    end
  end

  return false, Tr("error_failed_rename_snapshot_folder", {
    source = source_folder,
    dest = dest_folder,
  })
end

----------------------------------------
-- Settings
----------------------------------------

function LoadSettings()
  local lib = reaper.GetExtState(EXT_SECTION, "library_dir")
  if lib == "" then lib = DEFAULT_LIBRARY_DIR end

  local saved_language = reaper.GetExtState(EXT_SECTION, "language")
  SetLanguage(saved_language)
  state.language = language
  state.status = Tr("status_ready")

  state.library_dir = NormalizePath(lib)
  state.new_library_dir = state.library_dir

  state.load_to_new_tracks = reaper.GetExtState(EXT_SECTION, "load_to_new_tracks") == "1"
  state.restore_markers = reaper.GetExtState(EXT_SECTION, "restore_markers") ~= "0"
  state.restore_regions = reaper.GetExtState(EXT_SECTION, "restore_regions") ~= "0"
  state.restore_tempo = reaper.GetExtState(EXT_SECTION, "restore_tempo") ~= "0"
  state.restore_track_info = reaper.GetExtState(EXT_SECTION, "restore_track_info") == "1"
  state.restore_empty_tracks = reaper.GetExtState(EXT_SECTION, "restore_empty_tracks") == "1"
  state.check_empty_space = reaper.GetExtState(EXT_SECTION, "check_empty_space") ~= "0"
  state.show_load_popup = reaper.GetExtState(EXT_SECTION, "show_load_popup") ~= "0"
  state.auto_render_preview = reaper.GetExtState(EXT_SECTION, "auto_render_preview") ~= "0"
  state.skip_preview_leading_empty = reaper.GetExtState(EXT_SECTION, "skip_preview_leading_empty") ~= "0"
  state.show_capture_abbreviations = reaper.GetExtState(EXT_SECTION, "show_capture_abbreviations") == "1"
  state.show_tips = reaper.GetExtState(EXT_SECTION, "show_tips") ~= "0"
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
  reaper.SetExtState(EXT_SECTION, "language", NormalizeLanguageId(state.language or language), true)
  reaper.SetExtState(EXT_SECTION, "load_to_new_tracks", state.load_to_new_tracks and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "restore_markers", state.restore_markers and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "restore_regions", state.restore_regions and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "restore_tempo", state.restore_tempo and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "restore_track_info", state.restore_track_info and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "restore_empty_tracks", state.restore_empty_tracks and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "check_empty_space", state.check_empty_space and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "show_load_popup", state.show_load_popup and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "auto_render_preview", state.auto_render_preview and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "skip_preview_leading_empty", state.skip_preview_leading_empty and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "show_capture_abbreviations", state.show_capture_abbreviations and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "show_tips", state.show_tips and "1" or "0", true)
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

function SelectSnapshotById(id)
  id = tostring(id or "")
  if id == "" then return false end

  for i, snapshot in ipairs(state.snapshots or {}) do
    if tostring(snapshot.id or "") == id then
      state.selected = i
      return true
    end
  end

  return false
end

function EnsureSnapshotVisibleById(id)
  if not SelectSnapshotById(id) then return false end

  local snapshot = state.snapshots[state.selected]
  if snapshot and not SnapshotMatchesFilter(snapshot) then
    state.filter = ""
    state.category_filter = "All"
    state.show_favorites_only = false
    SelectSnapshotById(id)
  end

  return true
end

function SnapshotFieldMatches(a, b)
  a = tostring(a or "")
  b = tostring(b or "")
  if a == "" or b == "" then return false end

  if reaper.GetOS():find("Win") then
    return Lower(a) == Lower(b)
  end

  return a == b
end

function CopySnapshotMeta(meta)
  local out = {}
  if type(meta) == "table" then
    for key, value in pairs(meta) do
      out[key] = value
    end
  end
  return out
end

function NormalizeDiskSnapshotMeta(meta, folder_name)
  local out = CopySnapshotMeta(meta)
  folder_name = tostring(folder_name or "")

  out.folder = folder_name

  if tostring(out.id or "") == "" then
    out.id = folder_name
  end

  if tostring(out.name or "") == "" then
    out.name = folder_name
  end

  if tostring(out.created_at or "") == "" then
    out.created_at = tostring(out.updated_at or "")
  end

  if tostring(out.updated_at or "") == "" then
    out.updated_at = tostring(out.created_at or "")
  end

  return out
end

function CollectDiskSnapshots()
  if not reaper.EnumerateSubdirectories then return nil end

  local root = GetSnapshotsRoot()
  local snapshots = {}
  local i = 0

  while true do
    local folder_name = reaper.EnumerateSubdirectories(root, i)
    if not folder_name then break end

    local folder = JoinPath(root, folder_name)
    local data_path = JoinPath(folder, "snapshot.lua")

    if FileExists(data_path) then
      local data = LoadLuaTable(data_path)
      if type(data) == "table" then
        local meta = data.meta
        if type(meta) ~= "table" then meta = {} end

        snapshots[#snapshots + 1] = {
          folder = folder,
          folder_name = folder_name,
          meta = NormalizeDiskSnapshotMeta(meta, folder_name),
        }
      end
    end

    i = i + 1
  end

  return snapshots
end

function SnapshotMatchesDiskSnapshot(snapshot, disk_snapshot, match_kind)
  if type(snapshot) ~= "table" or type(disk_snapshot) ~= "table" then return false end

  local meta = disk_snapshot.meta or {}

  if match_kind == "id" then
    return SnapshotFieldMatches(snapshot.id, meta.id)
  end

  if match_kind == "folder" then
    if SnapshotFieldMatches(snapshot.folder, disk_snapshot.folder_name) then return true end
    if SnapshotFieldMatches(snapshot.folder, meta.folder) then return true end
    if SnapshotFieldMatches(snapshot.id, disk_snapshot.folder_name) then return true end

    local name = tostring(snapshot.name or "")
    if name ~= "" and SnapshotFieldMatches(SanitizeFileName(name), disk_snapshot.folder_name) then
      return true
    end

    return false
  end

  if match_kind == "name" then
    return SnapshotFieldMatches(snapshot.name, meta.name)
  end

  return false
end

function FindDiskSnapshotForIndexSnapshot(snapshot, disk_snapshots, used_disk_snapshots)
  local match_order = { "id", "folder", "name" }

  for _, match_kind in ipairs(match_order) do
    for i, disk_snapshot in ipairs(disk_snapshots or {}) do
      if not used_disk_snapshots[i] and SnapshotMatchesDiskSnapshot(snapshot, disk_snapshot, match_kind) then
        return i, disk_snapshot
      end
    end
  end

  return nil, nil
end

function SynchronizeSnapshotsWithDisk()
  local disk_snapshots = CollectDiskSnapshots()
  if not disk_snapshots then return false end

  local used_disk_snapshots = {}
  local synced = {}
  local changed = false

  for _, snapshot in ipairs(state.snapshots or {}) do
    if type(snapshot) == "table" then
      local disk_index, disk_snapshot = FindDiskSnapshotForIndexSnapshot(snapshot, disk_snapshots, used_disk_snapshots)

      if disk_snapshot then
        used_disk_snapshots[disk_index] = true

        local disk_folder = tostring(disk_snapshot.folder_name or "")
        if disk_folder ~= "" and not SnapshotFieldMatches(snapshot.folder, disk_folder) then
          snapshot.folder = disk_folder
          changed = true
        end

        if tostring(snapshot.id or "") == "" then
          snapshot.id = disk_snapshot.meta.id
          changed = true
        end

        if tostring(snapshot.name or "") == "" then
          snapshot.name = disk_snapshot.meta.name
          changed = true
        end

        synced[#synced + 1] = snapshot
      else
        changed = true
      end
    else
      changed = true
    end
  end

  for i, disk_snapshot in ipairs(disk_snapshots) do
    if not used_disk_snapshots[i] then
      synced[#synced + 1] = disk_snapshot.meta
      changed = true
    end
  end

  state.snapshots = synced
  return changed
end

function LoadIndex()
  EnsureDir(state.library_dir)
  EnsureDir(GetSnapshotsRoot())

  local selected_id = nil
  if state.snapshots[state.selected] then
    selected_id = state.snapshots[state.selected].id
  end

  local index = LoadLuaTable(GetIndexPath())
  if type(index) ~= "table" then
    state.snapshots = {}
  elseif type(index.snapshots) == "table" then
    state.snapshots = index.snapshots
  else
    state.snapshots = {}
  end

  local changed = SynchronizeSnapshotsWithDisk()
  SortSnapshots()
  if selected_id then SelectSnapshotById(selected_id) end

  if changed then
    SaveIndex()
  end
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

function MaybeSynchronizeSnapshotsWithDisk(force)
  if state.save_in_progress then return false end

  local now = reaper.time_precise and reaper.time_precise() or os.time()
  if not force and (now - (tonumber(state.snapshot_disk_sync_at) or 0)) < SNAPSHOT_DISK_SYNC_INTERVAL then
    return false
  end

  state.snapshot_disk_sync_at = now

  local selected_id = nil
  if state.snapshots[state.selected] then
    selected_id = state.snapshots[state.selected].id
  end

  local changed = SynchronizeSnapshotsWithDisk()
  if not changed then return false end

  SortSnapshots()
  if selected_id then SelectSnapshotById(selected_id) end
  SaveIndex()
  ResetWaveformCacheState()

  return true
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

function GetTrackIndex(track)
  if not track then return nil end

  local n = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
  if not n then return nil end

  return math.max(0, math.floor(n - 1))
end

function GetItemStableKey(item)
  if not item then return "" end

  if reaper.BR_GetMediaItemGUID then
    local ok, guid = pcall(reaper.BR_GetMediaItemGUID, item)
    if ok and guid and guid ~= "" then return tostring(guid) end
  end

  if reaper.GetSetMediaItemInfo_String then
    local ok, retval, guid = pcall(reaper.GetSetMediaItemInfo_String, item, "GUID", "", false)
    if ok and retval and guid and guid ~= "" then return tostring(guid) end
  end

  return tostring(item)
end

function CollectSelectedItemsInRange(start_pos, end_pos)
  local selected_item_set = {}
  local track_map = {}
  local track_ranges = {}
  local selected_count = reaper.CountSelectedMediaItems(0)

  for i = 0, selected_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)

    if item and ItemOverlapsRangeByTime(item, start_pos, end_pos) then
      local track = reaper.GetMediaItem_Track(item)
      local track_index = GetTrackIndex(track)

      if track and track_index then
        selected_item_set[GetItemStableKey(item)] = true

        if not track_map[track_index] then
          local tr = {
            track = track,
            track_index = track_index,
            ranges = {
              {
                start_pos = start_pos,
                end_pos = end_pos,
              }
            },
          }

          track_map[track_index] = tr
          track_ranges[#track_ranges + 1] = tr
        end
      end
    end
  end

  table.sort(track_ranges, function(a, b)
    return (tonumber(a.track_index) or 0) < (tonumber(b.track_index) or 0)
  end)

  return selected_item_set, track_ranges
end

function MakeCaptureTrackRange(track, track_index, start_pos, end_pos)
  return {
    track = track,
    track_index = track_index,
    ranges = {
      {
        start_pos = start_pos,
        end_pos = end_pos,
      }
    },
  }
end

function BuildContiguousTimeSelectionTrackRanges(min_track, max_track, start_pos, end_pos)
  local ranges = {}
  local track_count = reaper.CountTracks(0)

  if min_track == math.huge or max_track < min_track then
    return ranges
  end

  for i = min_track, math.min(max_track, track_count - 1) do
    local track = reaper.GetTrack(0, i)
    if track then
      ranges[#ranges + 1] = MakeCaptureTrackRange(track, i, start_pos, end_pos)
    end
  end

  return ranges
end

function GetTimeSelectionContext()
  local start_pos, end_pos = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

  if not start_pos or not end_pos or end_pos <= start_pos then
    return nil
  end

  local selected_item_set, selected_track_ranges = CollectSelectedItemsInRange(start_pos, end_pos)
  local selected_items_only = #selected_track_ranges > 0
  local track_count = reaper.CountTracks(0)
  local track_ranges = {}
  local min_track = math.huge
  local max_track = -1

  if selected_items_only then
    for _, tr in ipairs(selected_track_ranges) do
      min_track = math.min(min_track, tr.track_index)
      max_track = math.max(max_track, tr.track_index)
    end
  else
    for i = 0, track_count - 1 do
      local track = reaper.GetTrack(0, i)

      if track and TrackHasItemsInRange(track, start_pos, end_pos) then
        min_track = math.min(min_track, i)
        max_track = math.max(max_track, i)
      end
    end
  end

  -- Allow marker / region / tempo-only snapshots.
  -- If there are no media items in the time selection, use selected tracks as harmless anchors.
  if min_track == math.huge then
    local selected_track_count = reaper.CountSelectedTracks and reaper.CountSelectedTracks(0) or 0

    if selected_track_count > 0 then
      for i = 0, selected_track_count - 1 do
        local selected_track = reaper.GetSelectedTrack(0, i)
        local selected_index = GetTrackIndex(selected_track)
        if selected_index then
          min_track = math.min(min_track, selected_index)
          max_track = math.max(max_track, selected_index)
        end
      end
    else
      min_track = 0
      max_track = min_track
    end

    if min_track == math.huge then
      min_track = 0
      max_track = min_track
    end
  end

  track_ranges = BuildContiguousTimeSelectionTrackRanges(min_track, max_track, start_pos, end_pos)

  return {
    mode = "time_selection",
    mode_label = selected_items_only and "Time Selection (Selected Items)" or "Time Selection",
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
    track_count = math.max(1, #track_ranges),
    compact_tracks = true,
    selected_items_only = selected_items_only,
    selected_item_set = selected_item_set,
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

function CollectMarkers(ctx_data, include_markers, include_regions)
  include_markers = include_markers ~= false
  include_regions = include_regions ~= false

  local markers = {}
  local total = select(1, reaper.CountProjectMarkers(0)) or 0

  for i = 0, total - 1 do
    local ok, is_region, pos, rgn_end, name, marker_index, color = reaper.EnumProjectMarkers3(0, i)

    if ok then
      local include = false

      if is_region and include_regions then
        for _, r in ipairs(ctx_data.all_ranges) do
          if pos >= r.start_pos and rgn_end <= r.end_pos then
            include = true
            break
          end
        end
      elseif not is_region and include_markers then
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

function RestoreMarkers(markers, target_pos, include_markers, include_regions)
  if include_markers == nil then include_markers = true end
  if include_regions == nil then include_regions = true end

  for _, m in ipairs(markers or {}) do
    local is_region = m.is_region == true
    if (is_region and include_regions) or ((not is_region) and include_markers) then
      local pos = target_pos + (tonumber(m.pos) or 0)
      local rgn_end = target_pos + (tonumber(m.rgn_end) or 0)
      reaper.AddProjectMarker2(0, is_region, pos, rgn_end, m.name or "", -1, tonumber(m.color) or 0)
    end
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
    return nil, Tr("error_no_capture_context")
  end

  local tracks = {}
  local save_markers = true
  local save_regions = true
  local save_tempo = true
  local save_track_info = true

  for track_order, tr in ipairs(ctx_data.track_ranges) do
    local track = tr.track
    local track_chunk = ""

    if save_track_info then
      track_chunk = GetTrackChunk(track) or ""
    end

    local track_data = {
      source_track_index = tr.track_index,
      relative_track_index = ctx_data.compact_tracks and (track_order - 1) or (tr.track_index - ctx_data.min_track),
      track_chunk = save_track_info and StripItemsFromTrackChunk(track_chunk) or "",
      track_info_saved = save_track_info,
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
      local include_item = item and ItemOverlapsRanges(item, tr.ranges)

      if include_item and ctx_data.selected_items_only then
        include_item = ctx_data.selected_item_set and ctx_data.selected_item_set[GetItemStableKey(item)] == true
      end

      if include_item then
        local chunk = GetItemChunk(item)

        if chunk then
          local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
          local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

          track_data.items[#track_data.items + 1] = {
            position = pos - ctx_data.start_pos,
            length = len,
            stable_key = GetItemStableKey(item),
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
      track_count = ctx_data.compact_tracks and math.max(1, #tracks) or ctx_data.track_count,
      compact_tracks = ctx_data.compact_tracks == true,
      selected_items_only = ctx_data.selected_items_only == true,
      markers_saved = save_markers,
      regions_saved = save_regions,
      tempo_saved = save_tempo,
      track_info_saved = save_track_info,
    },

    tracks = tracks,
    markers = (save_markers or save_regions) and CollectMarkers(ctx_data, save_markers, save_regions) or {},
    tempo = save_tempo and CollectTempo(ctx_data) or {},
  }

  local captured_item_count = 0
  for _, tr in ipairs(tracks or {}) do
    captured_item_count = captured_item_count + #(tr.items or {})
  end

  if captured_item_count == 0 and #(data.markers or {}) == 0 and #(data.tempo or {}) == 0 then
    return nil, Tr("error_capture_empty", {
      mode = GetCaptureModeDisplay(ctx_data.mode, ctx_data.mode_label)
    })
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

function QueueSourcePeakBuild(source, item)
  if not source or not reaper.PCM_Source_BuildPeaks then return end

  state.peak_build_queue[#state.peak_build_queue + 1] = {
    source = source,
    item = item,
    started = false,
  }
end

function QueueItemPeakBuild(item)
  if not item then return end

  if reaper.UpdateItemInProject then
    pcall(reaper.UpdateItemInProject, item)
  end

  if not reaper.PCM_Source_BuildPeaks or not reaper.GetMediaItemTake_Source then
    return
  end

  local seen = {}
  local take_count = reaper.CountTakes and reaper.CountTakes(item) or 0

  if take_count > 0 and reaper.GetTake then
    for i = 0, take_count - 1 do
      local take = reaper.GetTake(item, i)
      local source = take and reaper.GetMediaItemTake_Source(take)
      local key = tostring(source)

      if source and not seen[key] then
        seen[key] = true
        QueueSourcePeakBuild(source, item)
      end
    end
  elseif reaper.GetActiveTake then
    local take = reaper.GetActiveTake(item)
    local source = take and reaper.GetMediaItemTake_Source(take)

    if source then
      QueueSourcePeakBuild(source, item)
    end
  end
end

function PumpPeakBuildQueue(max_seconds)
  local queue = state.peak_build_queue
  if not queue or #queue == 0 or not reaper.PCM_Source_BuildPeaks then return end

  local start_time = reaper.time_precise and reaper.time_precise() or 0
  local budget = tonumber(max_seconds) or 0.02
  local i = 1

  while i <= #queue do
    local job = queue[i]
    local mode = job.started and 1 or 0
    local ok, remaining = pcall(reaper.PCM_Source_BuildPeaks, job.source, mode)

    job.started = true

    if not ok then
      table.remove(queue, i)
    else
      remaining = tonumber(remaining) or 0

      if remaining <= 0 then
        pcall(reaper.PCM_Source_BuildPeaks, job.source, 2)

        if job.item and reaper.UpdateItemInProject then
          pcall(reaper.UpdateItemInProject, job.item)
        end

        table.remove(queue, i)
      else
        i = i + 1
      end
    end

    if budget > 0 and reaper.time_precise and (reaper.time_precise() - start_time) >= budget then
      break
    end
  end

  if #queue == 0 then
    reaper.UpdateArrange()
  end
end

function TrackAreaHasItems(start_track_index, track_count, start_pos, end_pos, ignored_items)
  local existing_tracks = reaper.CountTracks(0)
  ignored_items = type(ignored_items) == "table" and ignored_items or nil

  for i = start_track_index, math.min(existing_tracks - 1, start_track_index + track_count - 1) do
    local track = reaper.GetTrack(0, i)
    if track then
      local item_count = reaper.CountTrackMediaItems(track)
      for j = 0, item_count - 1 do
        local item = reaper.GetTrackMediaItem(track, j)
        local ignore_item = ignored_items and ignored_items[item] == true
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        if not ignore_item and RangeOverlaps(pos, pos + len, start_pos, end_pos) then
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

function RestoreRazorEditRange(data, start_track_index, target_pos, track_plan)
  if type(data) ~= "table" then return end

  local capture = data.capture or {}
  local tracks = track_plan or {}

  ClearAllRazorEdits()

  for _, entry in ipairs(tracks) do
    local tr = entry.track_data or entry
    local rel_index = tonumber(entry.target_relative_index)
    if rel_index == nil then rel_index = tonumber(tr.relative_track_index) or 0 end
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

function RestoreCapturedRangeState(data, start_track_index, target_pos, track_plan)
  local capture = data.capture or {}
  local mode = capture.mode or "unknown"
  local duration = tonumber(capture.duration) or 0

  if mode == "time_selection" then
    ClearAllRazorEdits()
    RestoreTimeSelectionRange(target_pos, duration)
  elseif mode == "razor" then
    -- Keep the time selection unchanged for Razor snapshots and restore the Razor area itself.
    RestoreRazorEditRange(data, start_track_index, target_pos, track_plan)
  end
end

function TrackDataHasCapturedItems(track_data)
  return type(track_data) == "table" and type(track_data.items) == "table" and #track_data.items > 0
end

function GetTrackDataRelativeIndex(track_data)
  local rel_index = tonumber(track_data and track_data.relative_track_index) or 0
  return math.max(0, math.floor(rel_index))
end

function GetSortedSnapshotTracks(data)
  local sorted = {}

  for _, tr in ipairs((data and data.tracks) or {}) do
    sorted[#sorted + 1] = tr
  end

  table.sort(sorted, function(a, b)
    local ar = GetTrackDataRelativeIndex(a)
    local br = GetTrackDataRelativeIndex(b)
    if ar == br then
      return (tonumber(a and a.source_track_index) or 0) < (tonumber(b and b.source_track_index) or 0)
    end
    return ar < br
  end)

  return sorted
end

function BuildRestoreTrackPlan(data)
  local capture = data and data.capture or {}
  local sorted_tracks = GetSortedSnapshotTracks(data)
  local plan = {}

  if state.restore_empty_tracks then
    local track_count = math.max(0, math.floor(tonumber(capture.track_count) or 0))

    for _, tr in ipairs(sorted_tracks) do
      local rel_index = GetTrackDataRelativeIndex(tr)
      plan[#plan + 1] = {
        track_data = tr,
        target_relative_index = rel_index,
      }
      track_count = math.max(track_count, rel_index + 1)
    end

    return plan, track_count
  end

  for _, tr in ipairs(sorted_tracks) do
    if TrackDataHasCapturedItems(tr) then
      plan[#plan + 1] = {
        track_data = tr,
        target_relative_index = #plan,
      }
    end
  end

  return plan, #plan
end

function SnapshotHasRestorableGlobalData(data)
  if type(data) ~= "table" then return false end

  if state.restore_tempo and type(data.tempo) == "table" and #data.tempo > 0 then
    return true
  end

  if (state.restore_markers or state.restore_regions) and type(data.markers) == "table" then
    for _, marker in ipairs(data.markers) do
      if marker and ((marker.is_region and state.restore_regions) or ((not marker.is_region) and state.restore_markers)) then
        return true
      end
    end
  end

  return false
end

function RestoreSnapshotData(data, snapshot_folder, options)
  if type(data) ~= "table" then
    return false, Tr("error_invalid_snapshot_data")
  end

  options = type(options) == "table" and options or {}

  local target_pos = tonumber(options.target_pos)
  if target_pos == nil then
    target_pos = reaper.GetCursorPosition()
  end
  target_pos = math.max(0, target_pos)

  local capture = data.capture or {}
  local duration = tonumber(capture.duration) or 0
  local track_plan, track_count = BuildRestoreTrackPlan(data)

  if track_count <= 0 and not SnapshotHasRestorableGlobalData(data) and (capture.mode or "unknown") ~= "time_selection" then
    return false, Tr("error_snapshot_has_no_tracks")
  end

  local start_track_index
  local original_track_count = reaper.CountTracks(0)
  local new_track_indices = {}

  if tonumber(options.start_track_index) ~= nil then
    start_track_index = math.max(0, math.floor(tonumber(options.start_track_index) or 0))
  elseif state.load_to_new_tracks then
    start_track_index = original_track_count
  else
    start_track_index = GetSelectedTrackIndexOrZero()
  end

  if state.check_empty_space and duration > 0 and track_count > 0 then
    local blocked, track_number = TrackAreaHasItems(start_track_index, track_count, target_pos, target_pos + duration, options.ignore_empty_check_items)
    if blocked then
      return false, Tr("error_target_area_not_empty", { track = tostring(track_number) })
    end
  end

  if state.load_to_new_tracks and tonumber(options.start_track_index) == nil then
    InsertTracksAt(start_track_index, track_count)

    for i = start_track_index, start_track_index + track_count - 1 do
      new_track_indices[i] = true
    end
  else
    EnsureTrackCount(start_track_index + track_count)

    local current_track_count = reaper.CountTracks(0)
    for i = original_track_count, current_track_count - 1 do
      new_track_indices[i] = true
    end
  end

  for _, entry in ipairs(track_plan) do
    local tr = entry.track_data
    local rel_index = tonumber(entry.target_relative_index) or 0
    local target_track_index = start_track_index + rel_index
    EnsureTrackCount(target_track_index + 1)

    local track = reaper.GetTrack(0, target_track_index)
    if track then
      if state.restore_track_info and new_track_indices[target_track_index] and tr.track_chunk and tr.track_chunk ~= "" then
        SetTrackChunk(track, tr.track_chunk)
      end

      for _, item_data in ipairs(tr.items or {}) do
        local item = reaper.AddMediaItemToTrack(track)
        local chunk = ResolveSnapshotMediaPathsInChunk(item_data.chunk or "", snapshot_folder)
        chunk = AdjustItemChunkPosition(chunk, capture.start_pos or 0, target_pos)
        SetItemChunk(item, chunk)
        QueueItemPeakBuild(item)
      end
    end
  end

  if state.restore_tempo then
    RestoreTempo(data.tempo, target_pos)
  end

  if state.restore_markers or state.restore_regions then
    RestoreMarkers(data.markers, target_pos, state.restore_markers, state.restore_regions)
  end

  RestoreCapturedRangeState(data, start_track_index, target_pos, track_plan)

  PumpPeakBuildQueue(0.25)
  reaper.UpdateArrange()
  return true
end

----------------------------------------
-- Preview Render
----------------------------------------

function SaveRenderSettings()
  local settings = {}

  settings.render_settings = reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 0, false)
  settings.render_bounds = reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 0, false)
  settings.render_channels = reaper.GetSetProjectInfo(0, "RENDER_CHANNELS", 0, false)
  settings.render_srate = reaper.GetSetProjectInfo(0, "RENDER_SRATE", 0, false)
  settings.render_start = reaper.GetSetProjectInfo(0, "RENDER_STARTPOS", 0, false)
  settings.render_end = reaper.GetSetProjectInfo(0, "RENDER_ENDPOS", 0, false)
  settings.render_tail = reaper.GetSetProjectInfo(0, "RENDER_TAILFLAG", 0, false)
  settings.render_addtoproj = reaper.GetSetProjectInfo(0, "RENDER_ADDTOPROJ", 0, false)
  settings.render_dither = reaper.GetSetProjectInfo(0, "RENDER_DITHER", 0, false)
  settings.render_normalize = reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE", 0, false)

  settings.render_file_ok, settings.render_file = reaper.GetSetProjectInfo_String(0, "RENDER_FILE", "", false)
  settings.render_pattern_ok, settings.render_pattern = reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "", false)
  settings.render_format_ok, settings.render_format = reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", "", false)
  settings.render_format2_ok, settings.render_format2 = reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT2", "", false)

  return settings
end

function RestoreRenderSettings(settings)
  if not settings then return end

  reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", settings.render_settings or 0, true)
  reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", settings.render_bounds or 0, true)
  reaper.GetSetProjectInfo(0, "RENDER_CHANNELS", settings.render_channels or 0, true)
  reaper.GetSetProjectInfo(0, "RENDER_SRATE", settings.render_srate or 0, true)
  reaper.GetSetProjectInfo(0, "RENDER_STARTPOS", settings.render_start or 0, true)
  reaper.GetSetProjectInfo(0, "RENDER_ENDPOS", settings.render_end or 0, true)
  reaper.GetSetProjectInfo(0, "RENDER_TAILFLAG", settings.render_tail or 0, true)
  reaper.GetSetProjectInfo(0, "RENDER_ADDTOPROJ", settings.render_addtoproj or 0, true)
  reaper.GetSetProjectInfo(0, "RENDER_DITHER", settings.render_dither or 0, true)
  reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE", settings.render_normalize or 0, true)

  if settings.render_file_ok then
    reaper.GetSetProjectInfo_String(0, "RENDER_FILE", settings.render_file or "", true)
  end

  if settings.render_pattern_ok then
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", settings.render_pattern or "", true)
  end

  if settings.render_format_ok then
    reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", settings.render_format or "", true)
  end

  if settings.render_format2_ok then
    reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT2", settings.render_format2 or "", true)
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

function MakePreviewItemFallbackKey(track_index, position, length)
  return string.format(
    "%d:%.12f:%.12f",
    math.floor(tonumber(track_index) or -1),
    tonumber(position) or 0,
    tonumber(length) or 0
  )
end

function BuildPreviewCapturedItemSet(data)
  local captured = {}
  if type(data) ~= "table" then return captured end

  local capture_start = tonumber(data.capture and data.capture.start_pos) or 0

  for _, tr in ipairs(data.tracks or {}) do
    local source_track_index = tonumber(tr.source_track_index)

    for _, item_data in ipairs(tr.items or {}) do
      local stable_key = tostring(item_data.stable_key or "")
      if stable_key ~= "" then
        captured[stable_key] = true
      end

      local rel_pos = tonumber(item_data.position)
      local len = tonumber(item_data.length)
      if source_track_index and rel_pos and len then
        captured[MakePreviewItemFallbackKey(source_track_index, capture_start + rel_pos, len)] = true
      end
    end
  end

  return captured
end

function IsPreviewCapturedItem(item, track_index, captured_item_set)
  if not item or type(captured_item_set) ~= "table" then return false end

  local stable_key = GetItemStableKey(item)
  if stable_key ~= "" and captured_item_set[stable_key] then
    return true
  end

  local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  return captured_item_set[MakePreviewItemFallbackKey(track_index, pos, len)] == true
end

function CreatePreviewRenderMuteGuard(data, start_pos, end_pos)
  if type(data) ~= "table" then return nil end

  local guard = { items = {} }
  local captured_item_set = BuildPreviewCapturedItemSet(data)
  local track_count = reaper.CountTracks(0)

  for track_index = 0, track_count - 1 do
    local track = reaper.GetTrack(0, track_index)
    if track then
      local item_count = reaper.CountTrackMediaItems(track)

      for item_index = 0, item_count - 1 do
        local item = reaper.GetTrackMediaItem(track, item_index)

        if item and ItemOverlapsRangeByTime(item, start_pos, end_pos) and not IsPreviewCapturedItem(item, track_index, captured_item_set) then
          local ok_get, old_mute = pcall(reaper.GetMediaItemInfo_Value, item, "B_MUTE")
          old_mute = ok_get and (tonumber(old_mute) or 0) or 0

          if old_mute < 0.5 then
            local ok_set = pcall(reaper.SetMediaItemInfo_Value, item, "B_MUTE", 1)
            if ok_set then
              guard.items[#guard.items + 1] = {
                item = item,
                mute = old_mute,
              }
            end
          end
        end
      end
    end
  end

  if #guard.items > 0 then
    reaper.UpdateArrange()
  end

  return guard
end

function RestorePreviewRenderMuteGuard(guard)
  if type(guard) ~= "table" or type(guard.items) ~= "table" then return end

  for i = #guard.items, 1, -1 do
    local entry = guard.items[i]
    local item = entry and entry.item
    local valid = item ~= nil

    if valid and reaper.ValidatePtr2 then
      valid = reaper.ValidatePtr2(0, item, "MediaItem*")
    end

    if valid then
      pcall(reaper.SetMediaItemInfo_Value, item, "B_MUTE", tonumber(entry.mute) or 0)
    end
  end

  if #guard.items > 0 then
    reaper.UpdateArrange()
  end
end

function RenderPreviewMp3(snapshot_folder, start_pos, end_pos, render_data)
  if not snapshot_folder or snapshot_folder == "" then
    return false, Tr("error_invalid_snapshot_folder")
  end

  if not start_pos or not end_pos or end_pos <= start_pos then
    return false, Tr("error_invalid_preview_range")
  end

  EnsureDir(snapshot_folder)

  local preview_path = JoinPath(snapshot_folder, PREVIEW_FILE_NAME)

  local old_settings = SaveRenderSettings()
  local old_time_sel_start, old_time_sel_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  local mute_guard = nil

  local ok, err = pcall(function()
    -- Always overwrite the preview file for same-name snapshot updates.
    -- Also remove the old WAV preview so updated snapshots do not keep large legacy files.
    RemovePreviewWaveformCache(preview_path, snapshot_folder)

    if FileExists(preview_path) then
      os.remove(preview_path)
    end

    local legacy_preview_path = JoinPath(snapshot_folder, LEGACY_PREVIEW_FILE_NAME)
    if FileExists(legacy_preview_path) then
      os.remove(legacy_preview_path)
    end

    reaper.GetSet_LoopTimeRange(true, false, start_pos, end_pos, false)

    -- Use a stable master-mix MP3 configuration instead of inheriting project render settings.
    reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 0, true)
    reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 0, true)
    reaper.GetSetProjectInfo(0, "RENDER_CHANNELS", 2, true)
    reaper.GetSetProjectInfo(0, "RENDER_SRATE", 44100, true)
    reaper.GetSetProjectInfo(0, "RENDER_STARTPOS", start_pos, true)
    reaper.GetSetProjectInfo(0, "RENDER_ENDPOS", end_pos, true)
    reaper.GetSetProjectInfo(0, "RENDER_TAILFLAG", 0, true)
    reaper.GetSetProjectInfo(0, "RENDER_ADDTOPROJ", 0, true)
    reaper.GetSetProjectInfo(0, "RENDER_DITHER", 16, true)
    reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE", 262144, true)

    -- Output: snapshot folder / preview.mp3
    reaper.GetSetProjectInfo_String(0, "RENDER_FILE", snapshot_folder, true)
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "preview", true)
    reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT2", "", true)

    SetRenderFormatMp3()

    mute_guard = CreatePreviewRenderMuteGuard(render_data, start_pos, end_pos)

    -- File: Render project, using the most recent render settings, auto-close render dialog
    reaper.Main_OnCommand(42230, 0)
  end)

  RestorePreviewRenderMuteGuard(mute_guard)
  reaper.GetSet_LoopTimeRange(true, false, old_time_sel_start, old_time_sel_end, false)
  RestoreRenderSettings(old_settings)

  if not ok then
    return false, tostring(err)
  end

  if not FileExists(preview_path) then
    return false, Tr("error_preview_mp3_not_created")
  end

  return true, preview_path
end

----------------------------------------
-- Save / Load Snapshot
----------------------------------------

function FindSnapshotForSaveName(name, folder_name)
  local name_match = nil
  local name_index = nil
  local folder_match = nil
  local folder_index = nil

  for i, s in ipairs(state.snapshots or {}) do
    if not name_match and tostring(s.name or "") == name then
      name_match = s
      name_index = i
    end

    if not folder_match and folder_name ~= "" and tostring(s.folder or s.id or "") == folder_name then
      folder_match = s
      folder_index = i
    end
  end

  if name_match then
    return name_match, name_index
  end

  return folder_match, folder_index
end

function ConfirmOverwriteSnapshot(name)
  local result = reaper.MB(
    Tr("confirm_overwrite_snapshot", { name = tostring(name or "") }),
    SCRIPT_NAME,
    1
  )

  return result == 1
end

function ConfirmUpdateSnapshot(name)
  local result = reaper.MB(
    Tr("confirm_update_snapshot", { name = tostring(name or "") }),
    SCRIPT_NAME,
    1
  )

  return result == 1
end

function PrepareSnapshotFolderForSave(existing_snapshot, folder_name)
  local folder = JoinPath(GetSnapshotsRoot(), folder_name)

  if existing_snapshot then
    local old_folder_name = tostring(existing_snapshot.folder or existing_snapshot.id or "")
    local old_folder = JoinPath(GetSnapshotsRoot(), old_folder_name)

    if old_folder_name ~= "" and NormalizePath(old_folder) ~= NormalizePath(folder) and SnapshotDirectoryExists(old_folder) then
      if SnapshotDirectoryExists(folder) then
        return nil, Tr("error_snapshot_folder_exists", { folder = folder_name })
      end

      local move_ok, move_err = MoveSnapshotFolderStrict(old_folder, folder)
      if not move_ok then
        return nil, move_err
      end
    end
  end

  EnsureDir(folder)
  return folder
end

function RemoveLegacySnapshotFolderAfterSave(existing_snapshot, folder_name)
  if not existing_snapshot then return end

  local old_folder_name = tostring(existing_snapshot.folder or existing_snapshot.id or "")
  if old_folder_name == "" or old_folder_name == folder_name then return end

  local old_folder = JoinPath(GetSnapshotsRoot(), old_folder_name)
  local new_folder = JoinPath(GetSnapshotsRoot(), folder_name)

  if NormalizePath(old_folder) ~= NormalizePath(new_folder) and SnapshotDirectoryExists(old_folder) then
    DeleteDirectoryRecursive(old_folder)
  end
end

function SaveSnapshotFromPopupImpl(update_snapshot, skip_overwrite_confirm)
  local is_update = type(update_snapshot) == "table"
  local name = is_update and tostring(update_snapshot.name or "") or SanitizeFileName(state.save_name)
  local category = is_update and tostring(update_snapshot.category or "") or Trim(state.save_category)
  local tags = {}
  local desc = is_update and tostring(update_snapshot.description or "") or tostring(state.save_description or "")
  local folder_name = is_update and tostring(update_snapshot.folder or update_snapshot.id or "") or SanitizeFileName(name)

  if is_update then
    if type(update_snapshot.tags) == "table" then
      for _, tag in ipairs(update_snapshot.tags) do
        tags[#tags + 1] = tag
      end
    else
      tags = SplitTags(update_snapshot.tags)
    end
  else
    tags = SplitTags(state.save_tags)
  end

  if name == "" and not is_update then name = SanitizeFileName(state.save_name) end
  if folder_name == "" then folder_name = SanitizeFileName(name) end

  local existing_snapshot = nil
  local existing_index = nil

  if is_update then
    for i, snapshot in ipairs(state.snapshots or {}) do
      if snapshot == update_snapshot or (
        tostring(update_snapshot.id or "") ~= "" and
        tostring(snapshot.id or "") == tostring(update_snapshot.id or "")
      ) then
        existing_snapshot = snapshot
        existing_index = i
        break
      end
    end

    if not existing_snapshot then
      state.status = Tr("status_no_snapshot_selected")
      return false
    end
  else
    existing_snapshot, existing_index = FindSnapshotForSaveName(name, folder_name)
  end

  local folder = JoinPath(GetSnapshotsRoot(), folder_name)
  local folder_exists = SnapshotDirectoryExists(folder)

  if (existing_snapshot or folder_exists) and not skip_overwrite_confirm then
    if not ConfirmOverwriteSnapshot(name) then
      state.status = Tr("status_save_cancelled_same_name")
      return false
    end
  end

  local id
  local created_at
  local favorite

  if existing_snapshot then
    id = existing_snapshot.id
    created_at = existing_snapshot.created_at or os.date("%Y-%m-%d %H:%M:%S")
    favorite = existing_snapshot.favorite == true
  else
    id = MakeID()
    while SnapshotIdExists(id) do
      id = MakeID()
    end
    created_at = os.date("%Y-%m-%d %H:%M:%S")
    favorite = false
  end

  local meta = {
    id = id,
    name = name,
    category = is_update and category or (category ~= "" and category or "Uncategorized"),
    tags = tags,
    description = desc,
    favorite = favorite,
    folder = folder_name,
    created_at = created_at,
    updated_at = os.date("%Y-%m-%d %H:%M:%S"),
  }

  local data, err = CaptureSnapshotData(meta)
  if not data then
    state.status = err or Tr("status_capture_failed")
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return false
  end

  meta.capture_mode = (data.capture and data.capture.mode) or "unknown"
  meta.capture_mode_label = (data.capture and data.capture.mode_label) or ""
  meta.markers_saved = (data.capture and data.capture.markers_saved) == true
  meta.regions_saved = (data.capture and data.capture.regions_saved) == true
  meta.tempo_saved = (data.capture and data.capture.tempo_saved) == true
  meta.track_info_saved = (data.capture and data.capture.track_info_saved) == true

  folder, err = PrepareSnapshotFolderForSave(existing_snapshot, folder_name)
  if not folder then
    state.status = tostring(err or Tr("error_invalid_snapshot_folder"))
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return false
  end

  local media_archive = ArchiveSnapshotMedia(data, folder)
  meta.media_reference_count = media_archive.reference_count or 0
  meta.media_copied_count = media_archive.copied_count or 0
  meta.media_missing_count = media_archive.missing_count or 0

  if state.auto_render_preview then
    local preview_start_pos = GetPreviewRenderStart(data)
    local preview_ok, preview_result = RenderPreviewMp3(folder, preview_start_pos, data.capture.end_pos, data)

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
    if existing_snapshot then
      local old_folder_name = tostring(existing_snapshot.folder or existing_snapshot.id or "")
      if old_folder_name ~= "" and old_folder_name ~= folder_name then
        local old_folder = JoinPath(GetSnapshotsRoot(), old_folder_name)
        MoveSnapshotFolderStrict(folder, old_folder)
      end
    end

    state.status = Tr("status_snapshot_write_failed")
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return false
  end

  if existing_snapshot then
    RemoveUnreferencedSnapshotMedia(data, folder)
  end

  RemoveLegacySnapshotFolderAfterSave(existing_snapshot, folder_name)

  if existing_index then
    state.snapshots[existing_index] = meta
  else
    state.snapshots[#state.snapshots + 1] = meta
  end

  SaveIndex()
  LoadIndex()
  EnsureSnapshotVisibleById(id)
  ResetWaveformCacheState()

  local media_note = ""
  if meta.media_copied_count and meta.media_copied_count > 0 then
    media_note = Tr("status_media_archived_note", { count = meta.media_copied_count })
  end

  if meta.media_missing_count and meta.media_missing_count > 0 then
    media_note = media_note .. Tr("status_missing_media_note", { count = meta.media_missing_count })
  end

  local mode_label = GetCaptureModeDisplay(meta.capture_mode, meta.capture_mode_label)
  if meta.has_preview then
    state.status = Tr("status_saved_preview_ok", { mode = mode_label, name = name, media_note = media_note })
  else
    state.status = Tr("status_saved_preview_failed", { mode = mode_label, name = name, media_note = media_note })
  end

  return true
end

function SaveSnapshotFromPopup()
  if state.save_in_progress or state.save_submitted then
    return false
  end

  state.save_in_progress = true
  local ok, result = pcall(SaveSnapshotFromPopupImpl)
  state.save_in_progress = false

  if not ok then
    state.status = tostring(result or Tr("status_capture_failed"))
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return false
  end

  if result == true then
    state.save_submitted = true
  end

  return result == true
end

function UpdateSnapshotFromCurrentSelection(snapshot)
  if type(snapshot) ~= "table" then
    state.status = Tr("status_no_snapshot_selected")
    return false
  end

  if not GetSmartCaptureContext() then
    state.status = Tr("error_no_capture_context")
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return false
  end

  if not ConfirmUpdateSnapshot(snapshot.name) then
    return false
  end

  if state.save_in_progress then
    return false
  end

  local target_preview_path = GetSnapshotPreviewPath(snapshot)
  if NormalizePath(state.preview_path or "") == NormalizePath(target_preview_path or "") then
    StopInternalPreview(true)
  end

  state.save_in_progress = true
  local ok, result = pcall(SaveSnapshotFromPopupImpl, snapshot, true)
  state.save_in_progress = false

  if not ok then
    state.status = tostring(result or Tr("status_capture_failed"))
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return false
  end

  return result == true
end

function LoadSelectedSnapshot()
  local snapshot = state.snapshots[state.selected]
  if not snapshot then
    state.status = Tr("status_no_snapshot_selected")
    return
  end

  local data_path = GetSnapshotDataPath(snapshot)
  local data, err = LoadLuaTable(data_path)

  if not data then
    state.status = Tr("status_load_failed")
    reaper.MB(Tr("error_load_snapshot_detail", { detail = tostring(err or data_path) }), SCRIPT_NAME, 0)
    return
  end

  local function LoadErrorHandler(err)
    if debug and debug.traceback then
      return debug.traceback(err, 2)
    end
    return tostring(err)
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local call_ok, ok, result_or_err = xpcall(function()
    local restore_ok, restore_err = RestoreSnapshotData(data, GetSnapshotFolderForFileOperation(snapshot))
    if restore_ok then
      PumpPeakBuildQueue(0.25)
      reaper.UpdateArrange()
    end
    return restore_ok, restore_err
  end, LoadErrorHandler)

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock(Tr("undo_load_snapshot"), -1)

  if not call_ok then
    state.status = Tr("status_load_failed")
    reaper.MB(Tr("error_load_snapshot_detail", { detail = tostring(ok or "") }), SCRIPT_NAME, 0)
    return
  end

  if not ok then
    state.status = result_or_err or Tr("status_load_failed")
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return
  end

  state.status = Tr("status_loaded_snapshot", { name = tostring(snapshot.name or "") })
end


function LoadSnapshotAtArrangeTarget(snapshot, target_pos, start_track_index, restore_options)
  if type(snapshot) ~= "table" then
    state.status = Tr("status_no_snapshot_selected")
    return false
  end

  target_pos = tonumber(target_pos)
  start_track_index = tonumber(start_track_index)
  if not target_pos or not start_track_index then
    state.status = Tr("status_load_failed")
    return false
  end

  restore_options = type(restore_options) == "table" and restore_options or {}

  local data_path = GetSnapshotDataPath(snapshot)
  local data, err = LoadLuaTable(data_path)

  if not data then
    state.status = Tr("status_load_failed")
    reaper.MB(Tr("error_load_snapshot_detail", { detail = tostring(err or data_path) }), SCRIPT_NAME, 0)
    return false
  end

  local function LoadErrorHandler(load_err)
    if debug and debug.traceback then
      return debug.traceback(load_err, 2)
    end
    return tostring(load_err)
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local call_ok, ok, result_or_err = xpcall(function()
    local restore_ok, restore_err = RestoreSnapshotData(data, GetSnapshotFolderForFileOperation(snapshot), {
      target_pos = target_pos,
      start_track_index = start_track_index,
      ignore_empty_check_items = restore_options.ignore_empty_check_items,
    })
    if restore_ok then
      if reaper.SetEditCurPos then
        pcall(reaper.SetEditCurPos, target_pos, false, false)
      end
      PumpPeakBuildQueue(0.25)
      reaper.UpdateArrange()
    end
    return restore_ok, restore_err
  end, LoadErrorHandler)

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock(Tr("undo_load_snapshot"), -1)

  if not call_ok then
    state.status = Tr("status_load_failed")
    reaper.MB(Tr("error_load_snapshot_detail", { detail = tostring(ok or "") }), SCRIPT_NAME, 0)
    return false
  end

  if not ok then
    state.status = result_or_err or Tr("status_load_failed")
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return false
  end

  state.status = Tr("status_loaded_snapshot", { name = tostring(snapshot.name or "") })
  return true
end

function GetSnapshotArrangeDragDuration(snapshot)
  local duration = tonumber(snapshot and snapshot.duration)
  if duration and duration > 0 then return duration end

  local data_path = GetSnapshotDataPath(snapshot)
  local data = LoadLuaTable(data_path)
  duration = tonumber(data and data.capture and data.capture.duration)
  if duration and duration > 0 then return duration end

  return 0.25
end

function GetSnapshotArrangeDragPayload(index, snapshot)
  if type(snapshot) ~= "table" then return "" end

  local id = tostring(snapshot.id or "")
  if id ~= "" then return "id:" .. id end

  local folder = tostring(snapshot.folder or "")
  if folder ~= "" then return "folder:" .. folder end

  return "index:" .. tostring(index or 0)
end

function FindSnapshotByArrangeDragPayload(payload)
  payload = tostring(payload or "")
  if payload == "" then return nil, nil end

  local payload_kind, payload_value = payload:match("^([^:]+):(.+)$")
  payload_kind = tostring(payload_kind or "")
  payload_value = tostring(payload_value or "")

  if payload_kind == "id" then
    for i, snapshot in ipairs(state.snapshots or {}) do
      if tostring(snapshot.id or "") == payload_value then
        return i, snapshot
      end
    end
  elseif payload_kind == "folder" then
    for i, snapshot in ipairs(state.snapshots or {}) do
      if tostring(snapshot.folder or "") == payload_value then
        return i, snapshot
      end
    end
  elseif payload_kind == "index" then
    local index = tonumber(payload_value)
    if index and state.snapshots[index] then
      return index, state.snapshots[index]
    end
  end

  return nil, nil
end

function ClearSnapshotArrangeDrag()
  CleanupSnapshotArrangeNativeDragCarrier(state.snapshot_arrange_drag)
  state.snapshot_arrange_drag = nil
end

function MarkSnapshotArrangeDragPayloadConsumed(payload)
  payload = tostring(payload or "")
  if payload == "" then return end

  state.snapshot_arrange_consumed_payload = payload
  local now = reaper.time_precise and reaper.time_precise() or os.clock()
  state.snapshot_arrange_consumed_until = now + 2.0
end

function IsSnapshotArrangeDragPayloadConsumed(payload)
  payload = tostring(payload or "")
  if payload == "" then return false end
  if tostring(state.snapshot_arrange_consumed_payload or "") ~= payload then return false end

  local now = reaper.time_precise and reaper.time_precise() or os.clock()
  if now <= (tonumber(state.snapshot_arrange_consumed_until) or 0) then
    return true
  end

  state.snapshot_arrange_consumed_payload = ""
  state.snapshot_arrange_consumed_until = 0
  return false
end

function MakeSnapshotArrangeNativeDragToken()
  state.snapshot_arrange_drag_counter = (tonumber(state.snapshot_arrange_drag_counter) or 0) + 1

  local seed = reaper.time_precise and reaper.time_precise() or os.clock()
  seed = math.floor((tonumber(seed) or 0) * 1000000)

  return tostring(seed) .. "_" .. tostring(state.snapshot_arrange_drag_counter)
end

function GetSnapshotArrangeNativeDragCarrierDir()
  local dir = JoinPath(state.library_dir, SNAPSHOT_ARRANGE_DRAG_CARRIER_DIR)
  EnsureDir(dir)
  return dir
end

function UInt16LE(value)
  value = math.max(0, math.floor(tonumber(value) or 0))
  return string.char(value % 256, math.floor(value / 256) % 256)
end

function UInt32LE(value)
  value = math.max(0, math.floor(tonumber(value) or 0))
  return string.char(
    value % 256,
    math.floor(value / 256) % 256,
    math.floor(value / 65536) % 256,
    math.floor(value / 16777216) % 256
  )
end

function WriteSilentWavFile(path, duration)
  duration = math.max(0.05, tonumber(duration) or 0.25)

  -- REAPER 原生拖动参考块，使用非常低的采样率可以让载体文件保持很小
  local sample_rate = 1000
  local channels = 1
  local bits_per_sample = 16
  local bytes_per_sample = math.floor(bits_per_sample / 8)
  local block_align = channels * bytes_per_sample
  local sample_count = math.max(1, math.floor(duration * sample_rate + 0.5))
  local data_size = sample_count * block_align
  local byte_rate = sample_rate * block_align

  local file = io.open(path, "wb")
  if not file then return false end

  file:write("RIFF")
  file:write(UInt32LE(36 + data_size))
  file:write("WAVE")
  file:write("fmt ")
  file:write(UInt32LE(16))
  file:write(UInt16LE(1))
  file:write(UInt16LE(channels))
  file:write(UInt32LE(sample_rate))
  file:write(UInt32LE(byte_rate))
  file:write(UInt16LE(block_align))
  file:write(UInt16LE(bits_per_sample))
  file:write("data")
  file:write(UInt32LE(data_size))

  local chunk = string.rep("\0", 8192)
  local remaining = data_size
  while remaining > 0 do
    local size = math.min(remaining, #chunk)
    file:write(chunk:sub(1, size))
    remaining = remaining - size
  end

  file:close()
  return true
end

function PrepareSnapshotArrangeNativeDragCarrier(drag)
  if type(drag) ~= "table" then return false end
  if tostring(drag.carrier_path or "") ~= "" and FileExists(drag.carrier_path) then
    return true
  end

  local dir = GetSnapshotArrangeNativeDragCarrierDir()
  local snapshot = drag.snapshot or {}
  local base = tostring(snapshot.id or snapshot.folder or snapshot.name or "snapshot")
  base = SanitizeFileName(base)
  if base == "" then base = "snapshot" end
  if #base > 80 then base = base:sub(1, 80) end

  local duration_ms = math.max(1, math.floor((tonumber(drag.duration) or 0.25) * 1000 + 0.5))
  local token = tostring(drag.token or MakeSnapshotArrangeNativeDragToken())
  drag.token = token
  local filename = "SFX_Snapshot_Drag_" .. token .. "_" .. base .. "_" .. tostring(duration_ms) .. "ms.wav"
  local path = JoinPath(dir, filename)

  if not WriteSilentWavFile(path, drag.duration) then
    return false
  end

  drag.carrier_path = path
  drag.carrier_filename = filename
  return true
end

function CleanupSnapshotArrangeNativeDragCarrier(drag)
  if type(drag) ~= "table" then return end

  local path = tostring(drag.carrier_path or "")
  if path ~= "" and FileExists(path) then
    pcall(os.remove, path)
  end

  drag.carrier_path = nil
  drag.carrier_filename = nil
end

function SetSnapshotArrangeDragState(index, snapshot, payload)
  if type(snapshot) ~= "table" then return nil end

  local current = state.snapshot_arrange_drag
  local same_drag = type(current) == "table" and tostring(current.payload or "") == tostring(payload or "")

  if same_drag then
    current.index = index
    current.snapshot = snapshot
    current.snapshot_id = tostring(snapshot.id or "")
    current.duration = GetSnapshotArrangeDragDuration(snapshot)
    return current
  end

  CleanupSnapshotArrangeNativeDragCarrier(current)

  local drag = {
    active = true,
    index = index,
    payload = tostring(payload or ""),
    snapshot_id = tostring(snapshot.id or ""),
    snapshot = snapshot,
    duration = GetSnapshotArrangeDragDuration(snapshot),
    token = MakeSnapshotArrangeNativeDragToken(),
    native_drop_pending = true,
    native_drop_attempted = false,
    awaiting_carrier = false,
    await_until = 0,
  }

  state.snapshot_arrange_drag = drag
  StopInternalPreview(true)
  return drag
end

function BeginSnapshotArrangeDragSource(index, snapshot)
  if type(snapshot) ~= "table" then return false end

  if IsMacOS and IsMacOS() then
    if not (reaper.APIExists and reaper.APIExists("SM_DropMediaFiles") and reaper.SM_DropMediaFiles) then return false end
    if not (ImGui.IsItemActive and ImGui.IsMouseDragging and ImGui.IsMouseDown) then return false end
    if not ImGui.IsItemActive(ctx) then return false end
    if not ImGui.IsMouseDown(ctx, MOUSE_BUTTON_LEFT) then return false end
    if not ImGui.IsMouseDragging(ctx, MOUSE_BUTTON_LEFT, 6) then return false end

    local payload = GetSnapshotArrangeDragPayload(index, snapshot)
    if payload == "" or IsSnapshotArrangeDragPayloadConsumed(payload) then return false end

    local current = state.snapshot_arrange_drag
    if type(current) == "table" and current.native_drop_attempted then
      return true
    end

    if not IsSnapshotSelected(index) then
      SelectOnlySnapshot(index)
    else
      state.selected = index
    end

    state.snapshot_list_focused = true
    local drag = SetSnapshotArrangeDragState(index, snapshot, payload)
    if not drag then return false end
    return true
  end

  if not (ImGui.BeginDragDropSource and ImGui.SetDragDropPayload and ImGui.EndDragDropSource) then return false end

  local begin_ok = ImGui.BeginDragDropSource(ctx, SNAPSHOT_ARRANGE_DND_SOURCE_FLAGS)
  if not begin_ok then return false end

  local payload = GetSnapshotArrangeDragPayload(index, snapshot)
  if payload ~= "" then
    ImGui.SetDragDropPayload(ctx, SNAPSHOT_ARRANGE_DND_PAYLOAD_TYPE, payload, COND_ALWAYS)

    if not IsSnapshotSelected(index) then
      SelectOnlySnapshot(index)
    else
      state.selected = index
    end

    state.snapshot_list_focused = true
    local drag = SetSnapshotArrangeDragState(index, snapshot, payload)

    -- if drag and ImGui.Text then
    --   ImGui.Text(ctx, "Drag snapshot to REAPER to load")
    -- end
  end

  ImGui.EndDragDropSource(ctx)
  return true
end

function TryCallSnapshotNativeDropApi(path)
  if not (reaper.APIExists and reaper.APIExists("SM_DropMediaFiles") and reaper.SM_DropMediaFiles) then
    return false
  end

  path = NormalizePath(path)
  if path == "" then return false end

  local calls = {
    { path },
    { path .. "\n" },
    { path, 1 },
    { path .. "\n", 1 },
  }

  local unpack_args = table.unpack or unpack
  for _, args in ipairs(calls) do
    local ok, result = pcall(reaper.SM_DropMediaFiles, unpack_args(args))
    if ok then
      if IsMacOS and IsMacOS() then
        local numeric_result = tonumber(result)
        if (numeric_result and numeric_result > 0) or (numeric_result == nil and result == true) then
          return true
        end
      elseif result ~= false then
        return true
      end
    end
  end

  return false
end

function StartSnapshotArrangeNativeDrop(drag)
  if type(drag) ~= "table" or drag.native_drop_attempted then return false end

  drag.native_drop_attempted = true
  drag.native_drop_pending = false

  if IsMacOS and IsMacOS() then
    drag.native_drop_mouse_released_at = nil
  end

  if not PrepareSnapshotArrangeNativeDragCarrier(drag) then
    state.status = Tr("status_load_failed")
    return false
  end

  local ok = TryCallSnapshotNativeDropApi(drag.carrier_path)
  drag.awaiting_carrier = ok == true
  drag.await_until = (reaper.time_precise and reaper.time_precise() or os.clock()) + SNAPSHOT_ARRANGE_NATIVE_DROP_TIMEOUT

  if not ok then
    state.status = Tr("status_load_failed")
    CleanupSnapshotArrangeNativeDragCarrier(drag)
  end

  return ok
end


function GetMediaItemSourcePathSafe(item)
  if not IsMediaItemValid(item) then return "" end
  if not (reaper.GetActiveTake and reaper.GetMediaItemTake_Source and reaper.GetMediaSourceFileName) then return "" end

  local take = reaper.GetActiveTake(item)
  if not take then return "" end

  local source = reaper.GetMediaItemTake_Source(take)
  if not source then return "" end

  local ok, value1, value2 = pcall(reaper.GetMediaSourceFileName, source, "")
  if not ok then return "" end

  if type(value2) == "string" and value2 ~= "" then return value2 end
  if type(value1) == "string" then return value1 end
  return ""
end

function SnapshotNativeCarrierItemMatches(item, drag)
  if type(drag) ~= "table" then return false end
  if not IsMediaItemValid(item) then return false end

  local source_path = NormalizePath(GetMediaItemSourcePathSafe(item))
  local carrier_path = NormalizePath(drag.carrier_path or "")
  local carrier_filename = tostring(drag.carrier_filename or "")

  if source_path ~= "" and carrier_path ~= "" and NormalizePathForCompare and NormalizePathForCompare(source_path) == NormalizePathForCompare(carrier_path) then
    return true
  end

  local source_filename = GetFileName(source_path)
  if carrier_filename ~= "" and source_filename == carrier_filename then
    local item_len = reaper.GetMediaItemInfo_Value and tonumber(reaper.GetMediaItemInfo_Value(item, "D_LENGTH")) or nil
    local duration = tonumber(drag.duration) or 0.25
    if not item_len or math.abs(item_len - duration) < 0.25 then
      return true
    end
  end

  return false
end

function FindSnapshotNativeCarrierItem(drag)
  if type(drag) ~= "table" then return nil end

  if reaper.CountSelectedMediaItems and reaper.GetSelectedMediaItem then
    local selected_count = reaper.CountSelectedMediaItems(0)
    for i = 0, selected_count - 1 do
      local item = reaper.GetSelectedMediaItem(0, i)
      if SnapshotNativeCarrierItemMatches(item, drag) then
        return item
      end
    end
  end

  if not (reaper.CountTracks and reaper.GetTrack and reaper.CountTrackMediaItems and reaper.GetTrackMediaItem) then
    return nil
  end

  local track_count = reaper.CountTracks(0)
  for ti = 0, track_count - 1 do
    local track = reaper.GetTrack(0, ti)
    local item_count = reaper.CountTrackMediaItems(track)
    for ii = item_count - 1, 0, -1 do
      local item = reaper.GetTrackMediaItem(track, ii)
      if SnapshotNativeCarrierItemMatches(item, drag) then
        return item
      end
    end
  end

  return nil
end

function DeleteSnapshotNativeCarrierItem(item)
  if not IsMediaItemValid(item) then return end
  if not (reaper.GetMediaItem_Track and reaper.DeleteTrackMediaItem) then return end

  local track = reaper.GetMediaItem_Track(item)
  if track then
    pcall(reaper.DeleteTrackMediaItem, track, item)
  end
end

function GetSnapshotNativeDropTargetFromCarrierItem(item)
  if not IsMediaItemValid(item) then return nil end
  if not (reaper.GetMediaItemInfo_Value and reaper.GetMediaItem_Track and reaper.CSurf_TrackToID) then return nil end

  local position = tonumber(reaper.GetMediaItemInfo_Value(item, "D_POSITION"))
  local track = reaper.GetMediaItem_Track(item)
  if not position or not track then return nil end

  local track_id = tonumber(reaper.CSurf_TrackToID(track, false))
  if not track_id or track_id < 1 then return nil end

  return {
    position = position,
    track_index = track_id - 1,
  }
end

function ResolveSnapshotArrangeNativeDrop(drag)
  if type(drag) ~= "table" or drag.awaiting_carrier ~= true then return false end

  local item = FindSnapshotNativeCarrierItem(drag)
  if not item then return false end

  local target = GetSnapshotNativeDropTargetFromCarrierItem(item)
  if not target then return false end

  local ignored_items = { [item] = true }
  MarkSnapshotArrangeDragPayloadConsumed(drag.payload)

  DeleteSnapshotNativeCarrierItem(item)
  if reaper.UpdateArrange then reaper.UpdateArrange() end

  CleanupSnapshotArrangeNativeDragCarrier(drag)
  LoadSnapshotAtArrangeTarget(drag.snapshot, target.position, target.track_index, {
    ignore_empty_check_items = ignored_items,
  })
  return true
end

function PeekSnapshotArrangeDragPayload()
  if not ImGui.GetDragDropPayload then return false end

  local ok, retval, payload_type, payload, is_preview, is_delivery = pcall(ImGui.GetDragDropPayload, ctx)
  if not ok or retval ~= true then return false end
  if tostring(payload_type or "") ~= SNAPSHOT_ARRANGE_DND_PAYLOAD_TYPE then return false end

  return true, tostring(payload or ""), is_preview == true, is_delivery == true
end

function UpdateSnapshotArrangeDrag()
  if IsMacOS and IsMacOS() then
    local drag = state.snapshot_arrange_drag
    if type(drag) ~= "table" then return end

    if drag.native_drop_pending and not drag.native_drop_attempted then
      StartSnapshotArrangeNativeDrop(drag)
    end

    if ResolveSnapshotArrangeNativeDrop(drag) then
      ClearSnapshotArrangeDrag()
      return
    end

    local now = reaper.time_precise and reaper.time_precise() or os.clock()
    if drag.native_drop_attempted and drag.awaiting_carrier and reaper.JS_Mouse_GetState then
      local ok, buttons = pcall(reaper.JS_Mouse_GetState, 1)
      if ok and tonumber(buttons) then
        if tonumber(buttons) == 0 then
          drag.native_drop_mouse_released_at = drag.native_drop_mouse_released_at or now
        else
          drag.native_drop_mouse_released_at = nil
        end
      end

      if drag.native_drop_mouse_released_at
        and now - drag.native_drop_mouse_released_at > SNAPSHOT_ARRANGE_NATIVE_DROP_RELEASE_GRACE
      then
        ClearSnapshotArrangeDrag()
        return
      end
    end

    if drag.native_drop_attempted and (not drag.awaiting_carrier or now > (tonumber(drag.await_until) or 0)) then
      ClearSnapshotArrangeDrag()
    end
    return
  end

  local payload_active, payload = PeekSnapshotArrangeDragPayload()
  local drag = state.snapshot_arrange_drag

  if payload_active then
    if IsSnapshotArrangeDragPayloadConsumed(payload) then
      return
    end

    local index, snapshot = FindSnapshotByArrangeDragPayload(payload)
    if snapshot then
      drag = SetSnapshotArrangeDragState(index, snapshot, payload)
    end
  end

  if type(drag) ~= "table" then return end

  if drag.native_drop_pending and not drag.native_drop_attempted then
    StartSnapshotArrangeNativeDrop(drag)
  end

  if ResolveSnapshotArrangeNativeDrop(drag) then
    ClearSnapshotArrangeDrag()
    return
  end

  local now = reaper.time_precise and reaper.time_precise() or os.clock()
  if drag.native_drop_attempted and (not drag.awaiting_carrier or now > (tonumber(drag.await_until) or 0)) then
    ClearSnapshotArrangeDrag()
  end
end

function PrimeLoadConfirmPopup()
  state.load_popup_load_to_new_tracks = state.load_to_new_tracks == true
  state.load_popup_restore_markers = state.restore_markers ~= false
  state.load_popup_restore_regions = state.restore_regions ~= false
  state.load_popup_restore_tempo = state.restore_tempo ~= false
  state.load_popup_restore_track_info = state.restore_track_info == true
  state.load_popup_restore_empty_tracks = state.restore_empty_tracks == true
  state.load_popup_check_empty_space = state.check_empty_space ~= false
end

function ApplyLoadPopupSettings()
  state.load_to_new_tracks = state.load_popup_load_to_new_tracks == true
  state.restore_markers = state.load_popup_restore_markers ~= false
  state.restore_regions = state.load_popup_restore_regions ~= false
  state.restore_tempo = state.load_popup_restore_tempo ~= false
  state.restore_track_info = state.load_popup_restore_track_info == true
  state.restore_empty_tracks = state.load_popup_restore_empty_tracks == true
  state.check_empty_space = state.load_popup_check_empty_space ~= false
  SaveSettings()
end

function RequestSaveSnapshotPopup(open_now)
  state.save_name = os.date(Tr("default_snapshot_name_format"))
  state.save_category = ""
  state.save_tags = ""
  state.save_description = ""
  state.save_in_progress = false
  state.save_submitted = false
  state.show_save_popup = true

  if open_now and ImGui.OpenPopup then
    ImGui.OpenPopup(ctx, UiLabel("popup_save_snapshot", "SaveSnapshotPopup"))
  else
    state.request_open_save_popup = true
  end
end

function RequestEditSnapshotPopup(snapshot, open_now)
  if type(snapshot) ~= "table" then
    state.status = Tr("status_no_snapshot_selected")
    return
  end

  state.edit_snapshot_id = tostring(snapshot.id or "")
  state.save_name = tostring(snapshot.name or "")
  state.save_category = tostring(snapshot.category or "")
  if state.save_category == "Uncategorized" then state.save_category = "" end
  state.save_tags = JoinTags(snapshot.tags)
  state.save_description = tostring(snapshot.description or "")
  state.save_in_progress = false
  state.save_submitted = false

  if open_now and ImGui.OpenPopup then
    ImGui.OpenPopup(ctx, UiLabel("popup_edit_snapshot", "EditSnapshotPopup"))
  else
    state.request_open_edit_popup = true
  end
end

function RequestLoadSelectedSnapshot()
  local snapshot = state.snapshots[state.selected]
  if not snapshot then
    state.status = Tr("status_no_snapshot_selected")
    return
  end

  if state.show_load_popup then
    PrimeLoadConfirmPopup()
    state.request_open_load_confirm_popup = true
  else
    LoadSelectedSnapshot()
  end
end

function RequestSettingsPopup(open_now)
  state.new_library_dir = state.library_dir
  state.show_settings_popup = true

  if open_now and ImGui.OpenPopup then
    ImGui.OpenPopup(ctx, UiLabel("popup_settings", "SettingsPopup"))
  else
    state.request_open_settings_popup = true
  end
end

function ShowShortcutHelp()
  reaper.MB(Tr("shortcut_help_text"), Tr("shortcut_help_title"), 0)
end

function ExportSelectedSnapshotZip()
  local indices = GetSelectedSnapshotIndices()
  if #indices == 0 then
    state.status = Tr("status_no_snapshot_selected")
    return
  end

  local entries = {}
  for _, index in ipairs(indices) do
    local snapshot = state.snapshots[index]
    if snapshot then
      local snapshot_folder = GetSnapshotFolderForFileOperation(snapshot)
      if not FileExists(JoinPath(snapshot_folder, "snapshot.lua")) then
        reaper.MB(Tr("error_snapshot_data_missing_detail", { path = tostring(snapshot_folder) }), SCRIPT_NAME, 0)
        state.status = Tr("status_export_data_missing")
        return
      end

      entries[#entries + 1] = {
        snapshot = snapshot,
        folder = snapshot_folder,
      }
    end
  end

  if #entries == 0 then
    state.status = Tr("status_no_snapshot_selected")
    return
  end

  local export_snapshot = entries[1].snapshot
  if #entries > 1 then
    export_snapshot = { name = string.format("%s %d Snapshots", Tr("title"), #entries) }
  end

  local zip_path = BrowseForExportZipPath(export_snapshot)
  if not zip_path or zip_path == "" then
    state.status = Tr("status_export_cancelled")
    return
  end

  local ok, result
  if #entries == 1 then
    ok, result = ZipFolder(entries[1].folder, zip_path)
  else
    local temp_dir = JoinPath(GetSnapshotsRoot(), "_export_temp_" .. MakeID())
    EnsureDir(temp_dir)

    local used_names = {}
    local function make_unique_package_folder_name(base_name)
      base_name = SanitizeFileName(base_name)
      if base_name == "" then base_name = "Snapshot" end

      local candidate = base_name
      local index = 2
      while used_names[Lower(candidate)] or PathExists(JoinPath(temp_dir, candidate)) do
        candidate = string.format("%s_%02d", base_name, index)
        index = index + 1
      end

      used_names[Lower(candidate)] = true
      return candidate
    end

    for _, entry in ipairs(entries) do
      local base_name = GetPathBaseName(entry.folder)
      if base_name == "" then
        base_name = entry.snapshot.folder or entry.snapshot.name or "Snapshot"
      end

      local dest_folder = JoinPath(temp_dir, make_unique_package_folder_name(base_name))
      local copy_ok, copy_err = CopyDirectoryRecursive(entry.folder, dest_folder)
      if not copy_ok then
        DeleteDirectoryRecursive(temp_dir)
        state.status = copy_err or Tr("status_export_failed")
        reaper.MB(state.status, SCRIPT_NAME, 0)
        return
      end
    end

    ok, result = ZipFolder(temp_dir, zip_path, false)
    DeleteDirectoryRecursive(temp_dir)
  end

  if not ok then
    state.status = result or Tr("status_export_failed")
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return
  end

  if #entries == 1 then
    state.status = Tr("status_exported_zip", { path = tostring(result) })
  else
    state.status = Tr("status_exported_zip_count", { count = tostring(#entries), path = tostring(result) })
  end
  OpenFolder(GetFileDir(result))
end

function ImportSnapshotDataFolder(source_folder)
  local data_path = JoinPath(source_folder, "snapshot.lua")
  local data, err = LoadLuaTable(data_path)
  if type(data) ~= "table" then
    return false, Tr("status_import_invalid_data"), Tr("error_import_read_detail", { detail = tostring(err or data_path) })
  end

  local meta = data.meta or {}
  if type(meta) ~= "table" then meta = {} end

  meta.name = MakeUniqueSnapshotName(meta.name or GetPathBaseName(source_folder) or Tr("imported_snapshot"))

  local import_id = tostring(meta.id or "")
  if import_id == "" or SnapshotIdExists(import_id) then
    import_id = MakeID()
  end
  meta.id = import_id

  local base_folder = tostring(meta.folder or "")
  if base_folder == "" then
    base_folder = SanitizeFileName(meta.name)
  end
  meta.folder = MakeUniqueSnapshotFolderName(base_folder)
  meta.imported_at = os.date("%Y-%m-%d %H:%M:%S")
  meta.updated_at = os.date("%Y-%m-%d %H:%M:%S")
  meta.has_preview = FileExists(JoinPath(source_folder, PREVIEW_FILE_NAME)) or FileExists(JoinPath(source_folder, LEGACY_PREVIEW_FILE_NAME))
  meta.preview = FileExists(JoinPath(source_folder, PREVIEW_FILE_NAME)) and PREVIEW_FILE_NAME or (meta.has_preview and LEGACY_PREVIEW_FILE_NAME or "")

  data.meta = meta

  local dest_folder = JoinPath(GetSnapshotsRoot(), meta.folder)
  local move_ok, move_err = MoveOrCopySnapshotFolder(source_folder, dest_folder)
  if not move_ok then
    return false, move_err or Tr("status_import_failed"), move_err or Tr("status_import_failed")
  end

  SaveLuaTable(JoinPath(dest_folder, "snapshot.lua"), data)
  state.snapshots[#state.snapshots + 1] = meta

  return true, meta
end

function ImportSnapshotZip()
  local ok_read, zip_path = reaper.GetUserFileNameForRead("", Tr("dialog_import_zip_title"), ".zip")
  if not ok_read or not zip_path or zip_path == "" then
    state.status = Tr("status_import_cancelled")
    return
  end

  zip_path = NormalizePath(zip_path)

  if not FileExists(zip_path) then
    reaper.MB(Tr("error_zip_missing_detail", { path = tostring(zip_path) }), SCRIPT_NAME, 0)
    state.status = Tr("status_import_zip_missing")
    return
  end

  EnsureDir(GetSnapshotsRoot())

  local temp_dir = JoinPath(GetSnapshotsRoot(), "_import_temp_" .. MakeID())
  EnsureDir(temp_dir)

  local unzip_ok, unzip_err = UnzipFile(zip_path, temp_dir)
  if not unzip_ok then
    DeleteDirectoryRecursive(temp_dir)
    state.status = unzip_err or Tr("status_import_failed")
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return
  end

  local source_folders = FindSnapshotDataFolders(temp_dir, 5)
  table.sort(source_folders)

  if #source_folders == 0 then
    DeleteDirectoryRecursive(temp_dir)
    state.status = Tr("status_import_snapshot_missing")
    reaper.MB(Tr("error_zip_invalid_package_detail"), SCRIPT_NAME, 0)
    return
  end

  local imported = {}
  for _, source_folder in ipairs(source_folders) do
    local import_ok, meta_or_status, message = ImportSnapshotDataFolder(source_folder)
    if not import_ok then
      if #imported > 0 then SaveIndex() end
      DeleteDirectoryRecursive(temp_dir)
      state.status = meta_or_status or Tr("status_import_failed")
      reaper.MB(message or state.status, SCRIPT_NAME, 0)
      return
    end

    imported[#imported + 1] = meta_or_status
  end

  DeleteDirectoryRecursive(temp_dir)
  SaveIndex()
  LoadIndex()

  local imported_ids = {}
  for _, meta in ipairs(imported) do
    imported_ids[tostring(meta.id or "")] = true
  end

  ClearSnapshotSelection()
  local last_imported_name = ""
  for i, snapshot in ipairs(state.snapshots or {}) do
    if imported_ids[tostring(snapshot.id or "")] then
      state.selected = i
      state.selected_snapshot_ids[GetSnapshotSelectionKey(snapshot, i)] = true
      last_imported_name = tostring(snapshot.name or "")
    end
  end

  ResetWaveformCacheState()
  if #imported == 1 then
    state.status = Tr("status_imported_snapshot", { name = last_imported_name })
  else
    state.status = Tr("status_imported_snapshot_count", { count = tostring(#imported) })
  end
end

function SetFavorite(snapshot, favorite)
  if not snapshot then return end

  local target = favorite == true
  if snapshot.favorite == target then
    state.status = target and Tr("status_already_favorite") or Tr("status_already_not_favorite")
    return
  end

  snapshot.favorite = target
  snapshot.updated_at = os.date("%Y-%m-%d %H:%M:%S")
  -- 排序收藏夹
  -- SortSnapshots()
  -- SaveIndex()
  state.status = snapshot.favorite and Tr("status_added_favorite") or Tr("status_removed_favorite")
end

function ToggleFavorite(snapshot)
  if not snapshot then return end
  SetFavorite(snapshot, not snapshot.favorite)
end

function FindSnapshotIndexById(id)
  id = tostring(id or "")
  if id == "" then return nil, nil end

  for i, snapshot in ipairs(state.snapshots or {}) do
    if tostring(snapshot.id or "") == id then
      return i, snapshot
    end
  end

  return nil, nil
end

function GetSnapshotSelectionKey(snapshot, index)
  if type(snapshot) == "table" then
    local id = tostring(snapshot.id or "")
    if id ~= "" then return "id:" .. id end

    local folder = tostring(snapshot.folder or "")
    if folder ~= "" then return "folder:" .. folder end
  end

  return "index:" .. tostring(index or 0)
end

function ClearSnapshotSelection()
  state.selected_snapshot_ids = {}
end

function SnapshotSelectionCount()
  local count = 0
  for _, selected in pairs(state.selected_snapshot_ids or {}) do
    if selected then count = count + 1 end
  end
  return count
end

function IsSnapshotSelected(index)
  local snapshot = state.snapshots[index]
  if not snapshot then return false end

  if SnapshotSelectionCount() == 0 then
    return state.selected == index
  end

  local key = GetSnapshotSelectionKey(snapshot, index)
  return (state.selected_snapshot_ids or {})[key] == true
end

function SelectOnlySnapshot(index)
  if not state.snapshots[index] then return end

  ClearSnapshotSelection()
  state.selected = index
  state.selection_anchor_index = index
  state.selected_snapshot_ids[GetSnapshotSelectionKey(state.snapshots[index], index)] = true
end

function ToggleSnapshotSelection(index)
  local snapshot = state.snapshots[index]
  if not snapshot then return end

  if SnapshotSelectionCount() == 0 and state.snapshots[state.selected] then
    state.selected_snapshot_ids[GetSnapshotSelectionKey(state.snapshots[state.selected], state.selected)] = true
  end

  local key = GetSnapshotSelectionKey(snapshot, index)
  state.selected = index
  state.selection_anchor_index = index

  if state.selected_snapshot_ids[key] then
    state.selected_snapshot_ids[key] = nil
    if SnapshotSelectionCount() == 0 then
      state.selected_snapshot_ids[key] = true
    end
  else
    state.selected_snapshot_ids[key] = true
  end
end

function SelectSnapshotRange(index)
  if not state.snapshots[index] then return end

  local anchor = tonumber(state.selection_anchor_index) or state.selected or index
  if not state.snapshots[anchor] or not SnapshotMatchesFilter(state.snapshots[anchor]) then
    anchor = state.selected or index
  end
  if not state.snapshots[anchor] or not SnapshotMatchesFilter(state.snapshots[anchor]) then
    anchor = index
  end

  local first = math.min(anchor, index)
  local last = math.max(anchor, index)

  ClearSnapshotSelection()
  for i = first, last do
    if state.snapshots[i] and SnapshotMatchesFilter(state.snapshots[i]) then
      state.selected_snapshot_ids[GetSnapshotSelectionKey(state.snapshots[i], i)] = true
    end
  end

  state.selected = index
end

function HandleSnapshotListClick(index)
  if IsShiftDown() then
    SelectSnapshotRange(index)
  elseif IsCtrlDown() then
    ToggleSnapshotSelection(index)
  else
    SelectOnlySnapshot(index)
  end

  state.snapshot_list_focused = true
end

function GetSelectedSnapshotIndices()
  local indices = {}

  for i, snapshot in ipairs(state.snapshots or {}) do
    local key = GetSnapshotSelectionKey(snapshot, i)
    if (state.selected_snapshot_ids or {})[key] then
      indices[#indices + 1] = i
    end
  end

  if #indices == 0 and state.snapshots[state.selected] then
    indices[#indices + 1] = state.selected
  end

  table.sort(indices)
  return indices
end

function SnapshotNameExistsExcept(name, except_id)
  name = tostring(name or "")
  except_id = tostring(except_id or "")

  for _, snapshot in ipairs(state.snapshots or {}) do
    if tostring(snapshot.id or "") ~= except_id and tostring(snapshot.name or "") == name then
      return true
    end
  end

  return false
end

function SnapshotFolderNameExistsExcept(folder_name, except_id)
  folder_name = tostring(folder_name or "")
  except_id = tostring(except_id or "")

  for _, snapshot in ipairs(state.snapshots or {}) do
    if tostring(snapshot.id or "") ~= except_id and tostring(snapshot.folder or snapshot.id or "") == folder_name then
      return true
    end
  end

  return false
end

function PrimeRenameSnapshot(snapshot)
  if not snapshot then
    state.status = Tr("status_no_snapshot_selected")
    return
  end

  state.rename_snapshot_id = tostring(snapshot.id or "")
  state.rename_name = tostring(snapshot.name or "")
  state.request_open_rename_popup = true
end

function RenameSnapshotById(snapshot_id, requested_name, metadata_updates)
  local index, snapshot = FindSnapshotIndexById(snapshot_id)
  if not snapshot then
    state.status = Tr("status_no_snapshot_selected")
    return false
  end

  local new_name = SanitizeFileName(requested_name)
  local new_folder_name = SanitizeFileName(new_name)
  local old_name = tostring(snapshot.name or "")
  local old_updated_at = snapshot.updated_at
  local old_category = snapshot.category
  local old_tags = snapshot.tags
  local old_description = snapshot.description
  local old_folder, resolved_old_folder_name = ResolveSnapshotFolder(snapshot)
  local old_folder_name = tostring(resolved_old_folder_name or "")
  if old_folder_name == "" then
    old_folder_name = tostring(snapshot.folder or snapshot.id or "")
  end

  if old_folder == "" then
    old_folder = GetSnapshotFolderForFileOperation(snapshot)
  end

  if type(metadata_updates) == "table" and new_name == old_name and old_folder_name ~= "" then
    new_folder_name = old_folder_name
  end

  local new_folder = JoinPath(GetSnapshotsRoot(), new_folder_name)
  local id = tostring(snapshot.id or "")

  if new_name == old_name
    and old_folder_name == new_folder_name
    and tostring(snapshot.folder or "") == new_folder_name
    and type(metadata_updates) ~= "table"
  then
    state.status = Tr("status_rename_cancelled")
    return true
  end

  if SnapshotNameExistsExcept(new_name, id) then
    local msg = Tr("error_snapshot_name_exists", { name = new_name })
    state.status = msg
    reaper.MB(msg, SCRIPT_NAME, 0)
    return false
  end

  if SnapshotFolderNameExistsExcept(new_folder_name, id) then
    local msg = Tr("error_snapshot_folder_exists", { folder = new_folder_name })
    state.status = msg
    reaper.MB(msg, SCRIPT_NAME, 0)
    return false
  end

  if not FileExists(JoinPath(old_folder, "snapshot.lua")) then
    local msg = Tr("error_snapshot_folder_not_found")
    state.status = msg
    reaper.MB(msg, SCRIPT_NAME, 0)
    return false
  end

  if NormalizePath(old_folder) ~= NormalizePath(new_folder) and PathExists(new_folder) then
    local msg = Tr("error_snapshot_folder_exists", { folder = new_folder_name })
    state.status = msg
    reaper.MB(msg, SCRIPT_NAME, 0)
    return false
  end

  local data_path = JoinPath(old_folder, "snapshot.lua")
  local data = LoadLuaTable(data_path)
  if type(data) ~= "table" then
    local msg = Tr("error_snapshot_data_missing_detail", { path = data_path })
    state.status = msg
    reaper.MB(msg, SCRIPT_NAME, 0)
    return false
  end

  local project_refs = nil
  if NormalizePath(old_folder) ~= NormalizePath(new_folder) then
    project_refs = CollectProjectSnapshotMediaReferences(old_folder, new_folder)
    local refs_ok = ApplyProjectSnapshotMediaReferenceChunks(project_refs, "offline_chunk")
    if not refs_ok then
      ApplyProjectSnapshotMediaReferenceChunks(project_refs, "original_chunk")
      local msg = Tr("error_failed_rename_snapshot_folder", {
        source = old_folder,
        dest = new_folder,
      })
      state.status = msg
      reaper.MB(msg, SCRIPT_NAME, 0)
      return false
    end
    ReleaseSnapshotFileLocks()
  end

  local moved = false
  if NormalizePath(old_folder) ~= NormalizePath(new_folder) then
    local move_ok, move_err = MoveSnapshotFolderStrict(old_folder, new_folder)
    if not move_ok then
      ApplyProjectSnapshotMediaReferenceChunks(project_refs, "original_chunk")
      local msg = tostring(move_err or Tr("error_failed_rename_snapshot_folder", {
        source = old_folder,
        dest = new_folder,
      }))
      state.status = msg
      reaper.MB(msg, SCRIPT_NAME, 0)
      return false
    end
    moved = true
    ReleaseSnapshotFileLocks()
  end

  snapshot.name = new_name
  snapshot.folder = new_folder_name
  if type(metadata_updates) == "table" then
    local category = Trim(metadata_updates.category)
    snapshot.category = category ~= "" and category or "Uncategorized"
    snapshot.tags = type(metadata_updates.tags) == "table" and metadata_updates.tags or SplitTags(metadata_updates.tags)
    snapshot.description = tostring(metadata_updates.description or "")
  end
  snapshot.updated_at = os.date("%Y-%m-%d %H:%M:%S")

  local meta = data.meta
  if type(meta) ~= "table" then meta = {} end
  for key, value in pairs(snapshot) do
    meta[key] = value
  end
  data.meta = meta

  if not SaveLuaTable(JoinPath(new_folder, "snapshot.lua"), data) then
    if moved then
      MoveSnapshotFolderStrict(new_folder, old_folder)
    end
    ApplyProjectSnapshotMediaReferenceChunks(project_refs, "original_chunk")

    snapshot.name = old_name
    snapshot.folder = old_folder_name
    snapshot.category = old_category
    snapshot.tags = old_tags
    snapshot.description = old_description
    snapshot.updated_at = old_updated_at

    local msg = Tr("error_failed_update_snapshot_data")
    state.status = msg
    reaper.MB(msg, SCRIPT_NAME, 0)
    return false
  end

  state.snapshots[index] = snapshot
  if not SaveIndex() then
    if moved then
      MoveSnapshotFolderStrict(new_folder, old_folder)
    end
    ApplyProjectSnapshotMediaReferenceChunks(project_refs, "original_chunk")

    snapshot.name = old_name
    snapshot.folder = old_folder_name
    snapshot.category = old_category
    snapshot.tags = old_tags
    snapshot.description = old_description
    snapshot.updated_at = old_updated_at
    state.snapshots[index] = snapshot

    local msg = Tr("error_failed_update_snapshot_data")
    state.status = msg
    reaper.MB(msg, SCRIPT_NAME, 0)
    return false
  end

  ApplyProjectSnapshotMediaReferenceChunks(project_refs, "new_chunk", true)
  ReleaseSnapshotFileLocks()
  LoadIndex()
  EnsureSnapshotVisibleById(id)
  ResetWaveformCacheState()

  if type(metadata_updates) == "table" then
    state.status = Tr("status_edited_snapshot", { name = new_name })
  else
    state.status = Tr("status_renamed_snapshot", { name = new_name })
  end
  return true
end

function EditSnapshotFromPopup()
  if state.save_in_progress or state.save_submitted then
    return false
  end

  local metadata_updates = {
    category = state.save_category,
    tags = SplitTags(state.save_tags),
    description = state.save_description,
  }

  state.save_in_progress = true
  local ok, result = pcall(
    RenameSnapshotById,
    state.edit_snapshot_id,
    state.save_name,
    metadata_updates
  )
  state.save_in_progress = false

  if not ok then
    state.status = tostring(result or Tr("error_failed_update_snapshot_data"))
    reaper.MB(state.status, SCRIPT_NAME, 0)
    return false
  end

  if result == true then
    state.save_submitted = true
  end

  return result == true
end

function BuildRemoveSnapshotConfirmMessage(entries)
  if #entries == 1 then
    local entry = entries[1]
    return Tr("confirm_remove_snapshot", {
      name = tostring(entry.snapshot.name or ""),
      folder = tostring(entry.folder),
    })
  end

  local names = {}
  local max_names = math.min(#entries, 12)
  for i = 1, max_names do
    names[#names + 1] = "- " .. tostring(entries[i].snapshot.name or Tr("unnamed"))
  end
  if #entries > max_names then
    names[#names + 1] = string.format("- ... (%d)", #entries - max_names)
  end

  return Tr("confirm_remove_snapshots", {
    count = tostring(#entries),
    names = table.concat(names, "\n"),
  })
end

function RemoveSelectedSnapshotFromIndex()
  local indices = GetSelectedSnapshotIndices()
  if #indices == 0 then return false end

  local entries = {}
  for _, index in ipairs(indices) do
    local snapshot = state.snapshots[index]
    if snapshot then
      local folder = GetSnapshotFolderForFileOperation(snapshot)
      local folder_exists = folder ~= "" and SnapshotDirectoryExists(folder)
      local should_delete_folder = folder_exists and IsSnapshotFolderSafeToDelete(folder)

      entries[#entries + 1] = {
        index = index,
        snapshot = snapshot,
        key = GetSnapshotSelectionKey(snapshot, index),
        folder = folder,
        should_delete_folder = should_delete_folder,
      }
    end
  end

  if #entries == 0 then return false end

  local ret = reaper.MB(BuildRemoveSnapshotConfirmMessage(entries), SCRIPT_NAME, 4)
  if ret ~= 6 then return false end

  local removed = {}
  local removed_count = 0
  local errors = {}

  for _, entry in ipairs(entries) do
    local remove_ok = true

    if entry.should_delete_folder then
      RemovePreviewWaveformCache(JoinPath(entry.folder, PREVIEW_FILE_NAME), entry.folder)

      local project_refs = CollectProjectSnapshotMediaReferences(entry.folder, entry.folder)
      local refs_ok = ApplyProjectSnapshotMediaReferenceChunks(project_refs, "offline_chunk")
      if not refs_ok then
        ApplyProjectSnapshotMediaReferenceChunks(project_refs, "original_chunk", true)
        remove_ok = false
        errors[#errors + 1] = Tr("error_failed_offline_snapshot_media", {
          name = tostring(entry.snapshot.name or Tr("unnamed")),
        })
      end

      if remove_ok then
        ReleaseSnapshotFileLocks()

        local ok, err = DeleteDirectoryRecursive(entry.folder)
        if not ok then
          ApplyProjectSnapshotMediaReferenceChunks(project_refs, "original_chunk", true)
          remove_ok = false
          errors[#errors + 1] = tostring(err or Tr("error_failed_delete_snapshot_folder", { path = entry.folder }))
        end
      end
    end

    if remove_ok then
      removed[entry.key] = true
      removed_count = removed_count + 1
    end
  end

  if removed_count == 0 then
    state.status = Tr("status_remove_delete_failed")
    reaper.MB(state.status .. "\n\n" .. table.concat(errors, "\n\n"), SCRIPT_NAME, 0)
    ResetWaveformCacheState()
    return false
  end

  for i = #state.snapshots, 1, -1 do
    if removed[GetSnapshotSelectionKey(state.snapshots[i], i)] then
      table.remove(state.snapshots, i)
    end
  end

  if state.selected > #state.snapshots then state.selected = #state.snapshots end
  if state.selected < 1 then state.selected = 1 end

  ReleaseSnapshotFileLocks()
  if not SaveIndex() then
    local msg = Tr("error_failed_update_snapshot_data")
    state.status = msg
    reaper.MB(msg, SCRIPT_NAME, 0)
    ResetWaveformCacheState()
    return false
  end

  LoadIndex()
  MaybeSynchronizeSnapshotsWithDisk(true)
  ResetWaveformCacheState()
  ClearSnapshotSelection()
  if state.snapshots[state.selected] then
    SelectOnlySnapshot(state.selected)
  end

  if #errors > 0 then
    state.status = Tr("status_remove_delete_failed")
    reaper.MB(state.status .. "\n\n" .. table.concat(errors, "\n\n"), SCRIPT_NAME, 0)
    return true
  end

  state.status = removed_count == 1
    and Tr("status_removed_deleted")
    or Tr("status_removed_deleted_count", { count = tostring(removed_count) })
  reaper.MB(state.status, SCRIPT_NAME, 0)
  return true
end

----------------------------------------
-- Waveform Cache Preview
----------------------------------------

function HasWaveformCacheSupport()
  return reaper.SM_WFC_BeginToFile
    and reaper.SM_WFC_Pump
    and reaper.SM_WFC_GetPathIfReady
end

function CancelWaveformCacheJob(job_key)
  job_key = tostring(job_key or "")
  if job_key == "" or not reaper.SM_WFC_Cancel then return false end

  local ok = pcall(reaper.SM_WFC_Cancel, job_key)
  return ok == true
end

function CancelAllWaveformCacheJobs()
  if not reaper.SM_WFC_Cancel then return false end

  local ok = pcall(reaper.SM_WFC_Cancel, "")
  return ok == true
end

function ResetWaveformCacheState(cancel_jobs)
  if cancel_jobs ~= false then
    if state.waveform_cache_job_key and state.waveform_cache_job_key ~= "" then
      CancelWaveformCacheJob(state.waveform_cache_job_key)
    else
      CancelAllWaveformCacheJobs()
    end
  end

  state.waveform_cache_key = ""
  state.waveform_cache_path = ""
  state.waveform_cache_job_key = ""
  state.waveform_cache_data = nil
  state.waveform_cache_building = false
  state.waveform_cache_status = ""
end

function RemovePreviewWaveformCache(preview_path, snapshot_folder)
  if not preview_path or preview_path == "" then
    return
  end

  CancelAllWaveformCacheJobs()

  if snapshot_folder and snapshot_folder ~= "" then
    EnsureDir(snapshot_folder)
  end

  local cache_path = GetPreviewWaveformCachePath(preview_path)

  if cache_path ~= "" and FileExists(cache_path) then
    pcall(os.remove, cache_path)
  end
end

function ReadWaveformCacheFile(path)
  if not path or path == "" or not FileExists(path) then
    return nil, Tr("error_waveform_cache_file_not_found")
  end

  if not string.unpack then
    return nil, Tr("error_lua_no_string_unpack")
  end

  local f = io.open(path, "rb")
  if not f then
    return nil, Tr("error_waveform_cache_open")
  end

  local header = f:read(64)
  if not header or #header < 64 then
    f:close()
    return nil, Tr("error_waveform_cache_header")
  end

  if header:sub(1, 4) ~= "SMWF" then
    f:close()
    return nil, Tr("error_waveform_cache_magic")
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
    return nil, Tr("error_waveform_cache_parse")
  end

  pixel_cnt = tonumber(pixel_cnt) or 0
  channels = tonumber(channels) or 0
  win_len = tonumber(win_len) or 0

  if version ~= 1 or pixel_cnt <= 0 or channels <= 0 or win_len <= 0 then
    f:close()
    return nil, Tr("error_waveform_cache_unsupported")
  end

  local need = pixel_cnt * channels * 2 * 4
  local data = f:read(need)
  f:close()

  if not data or #data < need then
    return nil, Tr("error_waveform_cache_incomplete")
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
  local snapshot_folder = GetSnapshotFolderForFileOperation(snapshot)
  local cache_key = GetSelectedSnapshotWaveformKey(snapshot, preview_path)

  if state.waveform_cache_key ~= cache_key then
    CancelWaveformCacheJob(state.waveform_cache_job_key)
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
    state.waveform_cache_status = Tr("status_no_preview_waveform")
    return nil
  end

  if not HasWaveformCacheSupport() then
    state.waveform_cache_status = Tr("status_waveform_extension_missing")
    return nil
  end

  EnsureDir(snapshot_folder)

  local cache_path = GetPreviewWaveformCachePath(preview_path)

  if cache_path ~= "" and FileExists(cache_path) then
    local data, err = ReadWaveformCacheFile(cache_path)
    if data then
      state.waveform_cache_path = cache_path
      state.waveform_cache_data = data
      state.waveform_cache_building = false
      state.waveform_cache_status = ""
      return data
    end

    state.waveform_cache_status = err or Tr("status_waveform_read_failed")
  end

  if state.waveform_cache_job_key ~= "" and reaper.SM_WFC_Pump and reaper.SM_WFC_GetPathIfReady then
    local job_key = state.waveform_cache_job_key
    pcall(reaper.SM_WFC_Pump, job_key, 800, 1.5)

    local ok_ready, ready_path = pcall(reaper.SM_WFC_GetPathIfReady, job_key)
    if ok_ready and ready_path and ready_path ~= "" then
      local data, err = nil, Tr("error_waveform_cache_file_not_found")
      if FileExists(ready_path) then
        data, err = ReadWaveformCacheFile(ready_path)
      end

      CancelWaveformCacheJob(job_key)
      state.waveform_cache_job_key = ""

      if data then
        state.waveform_cache_path = ready_path
        state.waveform_cache_data = data
        state.waveform_cache_building = false
        state.waveform_cache_status = ""
        return data
      end

      state.waveform_cache_status = err or Tr("status_waveform_read_failed")
    else
      state.waveform_cache_building = true
      state.waveform_cache_status = Tr("status_waveform_building")
    end

    return nil
  end

  if cache_path ~= "" then
    local ok_begin, job_key = pcall(
      reaper.SM_WFC_BeginToFile,
      preview_path,
      cache_path,
      WAVEFORM_CACHE_PIXELS,
      0.0,
      0.0,
      WAVEFORM_CACHE_MAX_CHANNELS
    )

    if ok_begin and job_key and job_key ~= "" then
      state.waveform_cache_job_key = job_key
      state.waveform_cache_building = true
      state.waveform_cache_status = Tr("status_waveform_building")
      return nil
    end
  end

  state.waveform_cache_status = Tr("status_waveform_build_failed")
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

function SetPreviewLocatePosition(path, position)
  state.preview_locate_path = NormalizePath(path or "")
  state.preview_locate_position = math.max(0, tonumber(position) or 0)
end

function GetPreviewLocatePosition(path, length)
  if NormalizePath(path or "") ~= NormalizePath(state.preview_locate_path or "") then
    return 0
  end

  local pos = math.max(0, tonumber(state.preview_locate_position) or 0)
  length = tonumber(length) or 0
  if length > 0 then
    pos = math.min(pos, math.max(0, length))
  end

  return pos
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
      state.status = Tr("status_looping_preview", { name = tostring(loop_name or "") })
    else
      state.status = Tr("status_preview_finished")
    end
    return
  end

  if state.preview_length > 0 and state.preview_position >= state.preview_length then
    StopInternalPreview(true)
    if loop_enabled and loop_path ~= "" and FileExists(loop_path) and PlayPreviewFile then
      PlayPreviewFile(loop_path, loop_name, 0)
      state.status = Tr("status_looping_preview", { name = tostring(loop_name or "") })
    else
      state.status = Tr("status_preview_finished")
    end
  end
end

function PlayPreviewFile(path, name, start_pos)
  if not HasInternalPreviewSupport() then
    reaper.MB(
      Tr("error_internal_preview_requires_sws"),
      SCRIPT_NAME,
      0
    )
    state.status = Tr("status_internal_preview_requires_sws")
    return false
  end

  if not path or path == "" or not FileExists(path) then
    reaper.MB(Tr("error_preview_file_not_found", { path = tostring(path or "") }), SCRIPT_NAME, 0)
    state.status = Tr("status_preview_file_missing")
    return false
  end

  StopInternalPreview(true)

  local source = reaper.PCM_Source_CreateFromFile(path)
  if not source then
    reaper.MB(Tr("error_preview_source_failed", { path = tostring(path) }), SCRIPT_NAME, 0)
    state.status = Tr("status_preview_source_failed")
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
    reaper.MB(Tr("error_preview_object_failed"), SCRIPT_NAME, 0)
    state.status = Tr("status_preview_object_failed")
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
    reaper.MB(Tr("error_preview_start_failed"), SCRIPT_NAME, 0)
    state.status = Tr("status_preview_start_failed")
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
    state.status = Tr("status_playing_preview_from", {
      seconds = string.format("%.2f", start_pos),
      name = tostring(name or ""),
    })
  else
    state.status = Tr("status_playing_preview", { name = tostring(name or "") })
  end

  return true
end

function AuditionSelectedSnapshot(start_pos)
  local snapshot = state.snapshots[state.selected]
  if not snapshot then return end

  local preview = GetSnapshotPreviewPath(snapshot)

  if not FileExists(preview) then
    reaper.MB(
      Tr("error_no_preview_for_snapshot", { folder = GetSnapshotFolderForFileOperation(snapshot) }),
      SCRIPT_NAME,
      0
    )
    return
  end

  PlayPreviewFile(preview, tostring(snapshot.name or ""), tonumber(start_pos) or 0)
end

function SeekSelectedPreviewToRatio(ratio)
  local snapshot = state.snapshots[state.selected]
  if not snapshot then return false end

  local preview = GetSnapshotPreviewPath(snapshot)
  if not FileExists(preview) then
    state.status = Tr("status_preview_file_missing")
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
  SetPreviewLocatePosition(preview, target_pos)
  return PlayPreviewFile(preview, tostring(snapshot.name or ""), target_pos)
end

function GetSelectedPreviewLocatePosition(snapshot, preview)
  if not snapshot or not preview or preview == "" then return 0 end

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

  return GetPreviewLocatePosition(preview, len)
end

function ResetSelectedPreviewToStart()
  local snapshot = state.snapshots[state.selected]
  if not snapshot then return end

  local preview = GetSnapshotPreviewPath(snapshot)
  SetPreviewLocatePosition(preview, 0)

  if state.preview_is_playing and NormalizePath(state.preview_path) == NormalizePath(preview) then
    PlayPreviewFile(preview, tostring(snapshot.name or ""), 0)
  else
    state.status = Tr("status_preview_cursor_start")
  end
end

function TogglePreviewPlayback()
  if state.preview_is_playing then
    StopInternalPreview(true)
    state.status = Tr("status_preview_stopped")
  else
    local snapshot = state.snapshots[state.selected]
    if not snapshot then return end

    local preview = GetSnapshotPreviewPath(snapshot)
    AuditionSelectedSnapshot(GetSelectedPreviewLocatePosition(snapshot, preview))
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
      ImGui.TextDisabled(ctx, empty_text or Tr("no_existing_items"))
    else
      for i, item in ipairs(items) do
        local label = tostring(item)
        if popup_id == "CategoryPresetPopup" then
          label = DisplayCategoryFilter(item)
        end

        if ImGui.Selectable(ctx, label .. "##selectable_popup_item_" .. tostring(i), false) then
          on_select(item)
        end
      end
    end

    ImGui.EndPopup(ctx)
  end
end

function CalcTextSizeSafe(text, fallback_w, fallback_h)
  local w = tonumber(fallback_w) or 0
  local h = tonumber(fallback_h) or 0

  if reaper.ImGui_CalcTextSize then
    local ok, calc_w, calc_h = pcall(reaper.ImGui_CalcTextSize, ctx, tostring(text or ""))
    if ok then
      w = tonumber(calc_w) or w
      h = tonumber(calc_h) or h
    end
  end

  return w, h
end

function GetFrameHeightSafe(fallback)
  local h = tonumber(fallback) or 22

  if reaper.ImGui_GetFrameHeight then
    local ok, value = pcall(reaper.ImGui_GetFrameHeight, ctx)
    if ok then
      h = tonumber(value) or h
    end
  end

  return h
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
  local frame_height = GetFrameHeightSafe(22)
  local total_w = math.max(knob_size, input_w + db_label_w + 4)
  local total_h = knob_size + frame_height - 7 -- 音量旋钮与分割线的距离

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

function DrawHeaderCloseButton()
  local slot_w = HEADER_CLOSE_SLOT_W
  local hit_h = HEADER_CLOSE_HIT_H
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)

  if ImGui.InvisibleButton(ctx, "##header_close_button", slot_w, hit_h) then
    state.request_close = true
  end

  local hovered = ImGui.IsItemHovered and ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive and ImGui.IsItemActive(ctx)

  if not (draw_list and ImGui.DrawList_AddLine) then return end

  local cx = x0 + slot_w * 0.5
  local cy = y0 + 6.5
  local half = HEADER_CLOSE_X_SIZE * 0.5
  local glow_col = active and 0x3F4A5666 or (hovered and 0x4656665E or 0x3A465255)
  local accent_col = active and 0xAAB3C0D6 or (hovered and 0x8F9CABCC or 0x75808DB8)
  local slash_col = active and 0x7E9AB0D8 or (hovered and 0x6F879BD0 or 0x53687DB8)

  ImGui.DrawList_AddLine(draw_list, cx - half, cy - half, cx + half, cy + half, glow_col, 3.4)
  ImGui.DrawList_AddLine(draw_list, cx - half, cy + half, cx + half, cy - half, glow_col, 3.4)
  ImGui.DrawList_AddLine(draw_list, cx - half, cy - half, cx + half, cy + half, accent_col, 1.45)
  ImGui.DrawList_AddLine(draw_list, cx - half, cy + half, cx + half, cy - half, slash_col, 1.45)
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

  if hovered and state.show_tips then
    ImGui.SetTooltip(ctx, Tr("tooltip_preview_volume"))
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
  local knob_input_gap = -2

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
  local subtitle_text = Tr("subtitle")
  local title_x = ImGui.GetCursorPosX and ImGui.GetCursorPosX(ctx) or 0
  local title_y = ImGui.GetCursorPosY and ImGui.GetCursorPosY(ctx) or 0
  local title_w, title_h = 0, 24

  if font_title then ImGui.PushFont(ctx, font_title, 21) end
  title_w, title_h = CalcTextSizeSafe(title_text, 0, 24)
  ImGui.Text(ctx, title_text)
  if font_title then ImGui.PopFont(ctx) end

  ImGui.SameLine(ctx, nil, 5)

  if font_small then ImGui.PushFont(ctx, font_small, 12) end
  local version_w, version_h = 0, 12
  version_w, version_h = CalcTextSizeSafe(version_text, 0, 12)

  if ImGui.SetCursorPosY then
    ImGui.SetCursorPosY(ctx, title_y + math.max(0, (title_h - version_h) * 0.5))
  end

  ImGui.TextDisabled(ctx, version_text)
  if font_small then ImGui.PopFont(ctx) end

  local knob_w, knob_h = GetPreviewVolumeKnobSize()
  local right_tools_w = knob_w + HEADER_CLOSE_SLOT_W
  ImGui.SameLine(ctx, nil, 0)

  local avail = select(1, ImGui.GetContentRegionAvail(ctx)) or 0
  if avail > right_tools_w then
    ImGui.Dummy(ctx, avail - right_tools_w, 0)
    ImGui.SameLine(ctx, nil, 0)
  end

  if ImGui.SetCursorPosY then
    ImGui.SetCursorPosY(ctx, title_y)
  end
  DrawPreviewVolumeKnob()

  if ImGui.SetCursorPosY then
    ImGui.SetCursorPosY(ctx, title_y + 1)
  end
  DrawHeaderCloseButton()

  local subtitle_w, subtitle_h = 0, 12
  subtitle_w, subtitle_h = CalcTextSizeSafe(subtitle_text, 0, 12)

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

  local save_w = select(1, CalcTextSizeSafe(" " .. Tr("save") .. " ", 52, 0))
  local load_w = select(1, CalcTextSizeSafe(" " .. Tr("load") .. " ", 52, 0))
  local options_w = select(1, CalcTextSizeSafe(" " .. Tr("options") .. " ", 76, 0))
  local frame_height = GetFrameHeightSafe(22)
  local button_total_w = save_w + load_w + options_w + spacing * 3

  local search_w = avail_w - button_total_w

  local function request_settings_popup()
    RequestSettingsPopup(false)
  end

  local function draw_options_menu()
    if ImGui.Button(ctx, Tr("options"), options_w, frame_height) then
      ImGui.OpenPopup(ctx, "TopBarOptions")
    end

    if ImGui.BeginPopup and ImGui.BeginPopup(ctx, "TopBarOptions") then
      if ImGui.MenuItem(ctx, Tr("import_zip")) then
        ImportSnapshotZip()
      end

      if ImGui.MenuItem(ctx, Tr("export_zip")) then
        ExportSelectedSnapshotZip()
      end

      if ImGui.MenuItem(ctx, Tr("view_shortcuts")) then
        ShowShortcutHelp()
      end

      if ImGui.MenuItem(ctx, Tr("settings")) then
        request_settings_popup()
      end

      ImGui.EndPopup(ctx)
    end
  end

  if search_w >= 180 then
    ImGui.SetNextItemWidth(ctx, search_w)
    local changed, v = ImGui.InputTextWithHint(ctx, "##search", Tr("search_hint"), state.filter)
    if changed then state.filter = v end

    ImGui.SameLine(ctx, nil, spacing)

    if ImGui.Button(ctx, Tr("save"), save_w, frame_height) then -- "Smart Save"
      RequestSaveSnapshotPopup(true)
    end

    ImGui.SameLine(ctx, nil, spacing)

    if ImGui.Button(ctx, Tr("load"), load_w, frame_height) then -- "Load at Cursor"
      RequestLoadSelectedSnapshot()
    end

    ImGui.SameLine(ctx, nil, spacing)

    draw_options_menu()
  else
    ImGui.SetNextItemWidth(ctx, -1)
    local changed, v = ImGui.InputTextWithHint(ctx, "##search", Tr("search_hint"), state.filter)
    if changed then state.filter = v end

    if ImGui.Button(ctx, Tr("save"), save_w, frame_height) then
      RequestSaveSnapshotPopup(true)
    end

    ImGui.SameLine(ctx, nil, spacing)

    if ImGui.Button(ctx, Tr("load"), load_w, frame_height) then
      RequestLoadSelectedSnapshot()
    end

    ImGui.SameLine(ctx, nil, spacing)

    draw_options_menu()
  end
end

function DrawFilters()
  ImGui.Text(ctx, Tr("category_label"))
  ImGui.SameLine(ctx, nil, 5)

  local categories = GetCategories()

  ImGui.SetNextItemWidth(ctx, 150)
  if ImGui.BeginCombo(ctx, "##category", DisplayCategoryFilter(state.category_filter)) then
    for i, c in ipairs(categories) do
      if ImGui.Selectable(ctx, DisplayCategoryFilter(c) .. "##category_option_" .. tostring(i), state.category_filter == c) then
        state.category_filter = c
      end
    end
    ImGui.EndCombo(ctx)
  end

  ImGui.SameLine(ctx)

  local changed, fav = ImGui.Checkbox(ctx, Tr("favorites_only"), state.show_favorites_only)
  if changed then state.show_favorites_only = fav end
end

function DrawWaveformPlaceholderBar(message)
  local wave_w = select(1, ImGui.GetContentRegionAvail(ctx))
  wave_w = math.max(80, tonumber(wave_w) or 80)
  local wave_h = 56
  local x, y = ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(ctx, "##selected_snapshot_waveform_placeholder", wave_w, wave_h)

  local draw_list = ImGui.GetWindowDrawList(ctx)
  if draw_list and ImGui.DrawList_AddRectFilled then
    ImGui.DrawList_AddRectFilled(draw_list, x, y, x + wave_w, y + wave_h, 0x111318FF)
  end

  if draw_list and ImGui.DrawList_AddLine then
    local center_y = y + wave_h * 0.5
    ImGui.DrawList_AddLine(draw_list, x, center_y, x + wave_w, center_y, 0xFFFFFF22, 1.0)
  end

  message = tostring(message or "")
  if message ~= "" then
    if draw_list and ImGui.DrawList_AddText then
      ImGui.DrawList_AddText(draw_list, x + 10, y + 20, 0x8A93A2FF, message)
    else
      ImGui.TextDisabled(ctx, message)
    end
  end
end

function DrawWaveformCachePreviewBar()
  local snapshot = state.snapshots[state.selected]

  if not snapshot then
    DrawWaveformPlaceholderBar(Tr("no_snapshot_selected"))
    return
  end

  local preview_path = GetSnapshotPreviewPath(snapshot)
  local waveform_data = StartOrPumpWaveformCache(snapshot)
  local is_selected_preview_playing = state.preview_is_playing and NormalizePath(state.preview_path) == NormalizePath(preview_path)

  local len = 0
  if waveform_data and waveform_data.win_len and waveform_data.win_len > 0 then
    len = waveform_data.win_len
  elseif is_selected_preview_playing and state.preview_length and state.preview_length > 0 then
    len = state.preview_length
  else
    len = tonumber(snapshot.duration) or 0
  end

  local locate_pos = GetPreviewLocatePosition(preview_path, len)
  local pos = is_selected_preview_playing and (tonumber(state.preview_position) or 0) or locate_pos
  if len > 0 then
    pos = math.max(0, math.min(len, pos))
  else
    pos = math.max(0, pos)
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
    local msg = state.waveform_cache_status ~= "" and state.waveform_cache_status or Tr("waveform_preview_unavailable")
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

  local locate_ratio = 0
  if len > 0 then
    locate_ratio = math.max(0, math.min(1, locate_pos / len))
  end

  if draw_list and ImGui.DrawList_AddLine then
    local locate_x = x + locate_ratio * wave_w
    ImGui.DrawList_AddLine(draw_list, locate_x, y, locate_x, y + wave_h, 0x78C7FF88, 1.0)
  end

  local cursor_ratio = 0
  if len > 0 then
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

  if hovered and state.show_tips then
    ImGui.SetTooltip(ctx, Tr("tooltip_waveform_seek"))
  end

  local frame_height = GetFrameHeightSafe(22)
  local rewind_text_w = select(1, CalcTextSizeSafe(" " .. Tr("back_to_start") .. " ", 32, 0))
  local rewind_w = math.max(frame_height, rewind_text_w)
  local play_w = select(1, CalcTextSizeSafe(" " .. Tr("play") .. " ", 52, 0))
  local loop_w = select(1, CalcTextSizeSafe(" " .. Tr("loop_off") .. " ", 76, 0))
  local spacing = 5
  local cursor_x = ImGui.GetCursorPosX and ImGui.GetCursorPosX(ctx) or 0
  local controls_w = rewind_w + spacing + play_w + spacing + loop_w
  local controls_x = cursor_x + math.max(0, (wave_w - controls_w) * 0.5)

  if ImGui.SetCursorPosX then
    ImGui.SetCursorPosX(ctx, controls_x)
  end

  if ImGui.Button(ctx, UiLabel("back_to_start", "preview_start"), rewind_w, frame_height) then
    ResetSelectedPreviewToStart()
  end
  if state.show_tips and ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, Tr("tooltip_preview_start"))
  end

  ImGui.SameLine(ctx, nil, spacing)

  local btn_label = is_selected_preview_playing and Tr("stop") or Tr("play")
  if ImGui.Button(ctx, btn_label .. "##preview_play_stop", play_w, frame_height) then
    if is_selected_preview_playing then
      StopInternalPreview(true)
      state.status = Tr("status_preview_stopped")
    else
      PlayPreviewFile(preview_path, tostring(snapshot.name or ""), locate_pos)
    end
  end

  ImGui.SameLine(ctx, nil, spacing)

  local loop_label = state.preview_loop and Tr("loop_on") or Tr("loop_off")
  if ImGui.Button(ctx, loop_label .. "##preview_loop", loop_w, frame_height) then
    state.preview_loop = not state.preview_loop
    state.status = state.preview_loop and Tr("status_preview_loop_enabled") or Tr("status_preview_loop_disabled")
  end
end

function BeginStableSnapshotTooltip()
  local tooltip_w = 360
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local x = (tonumber(mouse_x) or 0) + 16
  local y = (tonumber(mouse_y) or 0) + 18

  ImGui.SetNextWindowPos(ctx, x, y, ImGui.Cond_Always)
  ImGui.SetNextWindowSize(ctx, tooltip_w, 0, ImGui.Cond_Always)
  ImGui.BeginTooltip(ctx)
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
        local source = ""
        if state.show_capture_abbreviations then
          if s.capture_mode == "time_selection" then
            source = " [TS]"
          elseif s.capture_mode == "razor" then
            source = " [RE]"
          end
        end
        local name = fav .. tostring(s.name or Tr("unnamed")) .. source
        local label = name .. "##snapshot_" .. tostring(i)

        local selected = IsSnapshotSelected(i)
        if ImGui.Selectable(ctx, label, selected) then
          HandleSnapshotListClick(i)
        end

        if ImGui.IsItemClicked and ImGui.IsItemClicked(ctx, MOUSE_BUTTON_LEFT) then
          -- if not IsSnapshotSelected(i) then
          --   SelectOnlySnapshot(i)
          -- else
          --   state.selected = i
          -- end
          state.snapshot_list_focused = true
        end

        BeginSnapshotArrangeDragSource(i, s)

        if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked and ImGui.IsMouseDoubleClicked(ctx, MOUSE_BUTTON_LEFT) then
          state.selected = i
          AuditionSelectedSnapshot()
        end

        if ImGui.IsItemClicked and ImGui.IsItemClicked(ctx, MOUSE_BUTTON_MIDDLE) then
          if not IsSnapshotSelected(i) then
            SelectOnlySnapshot(i)
          else
            state.selected = i
          end
          state.snapshot_list_focused = true
          RequestLoadSelectedSnapshot()
        end

        if ImGui.IsItemClicked and ImGui.IsItemClicked(ctx, MOUSE_BUTTON_RIGHT) then
          if not IsSnapshotSelected(i) then
            SelectOnlySnapshot(i)
          else
            state.selected = i
          end
          state.snapshot_list_focused = true
        end

        if ImGui.BeginPopupContextItem and ImGui.BeginPopupContextItem(ctx, "snapshot_context_" .. tostring(i)) then
          if not IsSnapshotSelected(i) then
            SelectOnlySnapshot(i)
          else
            state.selected = i
          end

          if ImGui.MenuItem(ctx, s.favorite and Tr("remove_favorite") or Tr("add_favorite")) then
            ToggleFavorite(s)
            list_changed = true
          end

          if ImGui.MenuItem(ctx, Tr("load")) then
            RequestLoadSelectedSnapshot()
          end

          if ImGui.MenuItem(ctx, Tr("edit_snapshot")) then
            RequestEditSnapshotPopup(s, false)
          end

          if ImGui.MenuItem(ctx, Tr("update_snapshot")) then
            list_changed = UpdateSnapshotFromCurrentSelection(s) == true
          end

          if ImGui.MenuItem(ctx, Tr("open_folder")) then
            OpenFolder(GetSnapshotFolderForFileOperation(s))
          end

          if ImGui.MenuItem(ctx, Tr("export_zip")) then
            ExportSelectedSnapshotZip()
          end

          ImGui.Separator(ctx)

          if ImGui.MenuItem(ctx, Tr("rename")) then
            PrimeRenameSnapshot(s)
          end

          if ImGui.MenuItem(ctx, Tr("remove")) then
            list_changed = RemoveSelectedSnapshotFromIndex() == true
          end

          ImGui.EndPopup(ctx)
        end

        if list_changed then
          break
        end

        if not (state.snapshot_arrange_drag and state.snapshot_arrange_drag.active) and state.show_tips and ImGui.IsItemHovered(ctx) then
          BeginStableSnapshotTooltip()
          ImGui.Text(ctx, tostring(s.name or ""))
          ImGui.Separator(ctx)
          ImGui.Text(ctx, Tr("meta_category", { value = DisplayCategory(s.category) }))
          ImGui.Text(ctx, Tr("meta_source", { value = GetCaptureModeDisplay(s.capture_mode, s.capture_mode_label) }))
          ImGui.Text(ctx, Tr("meta_tags", { value = JoinTags(s.tags) }))
          ImGui.Text(ctx, Tr("meta_duration", { value = string.format("%.3f", tonumber(s.duration) or 0) }))
          ImGui.Text(ctx, Tr("meta_tracks", { value = tostring(s.track_count or 0) }))
          ImGui.Text(ctx, Tr("meta_items", { value = tostring(s.item_count or 0) }))
          ImGui.Text(ctx, Tr("meta_media_archived", { value = tostring(s.media_copied_count or 0) }))
          if tonumber(s.media_missing_count or 0) and tonumber(s.media_missing_count or 0) > 0 then
            ImGui.Text(ctx, Tr("meta_missing_media", { value = tostring(s.media_missing_count or 0) }))
          end

          if s.has_preview then
            if tonumber(s.preview_start_offset or 0) and tonumber(s.preview_start_offset or 0) > 0 then
              ImGui.Text(ctx, Tr("meta_preview_skip", { value = string.format("%.3f", tonumber(s.preview_start_offset) or 0) }))
            end
          else
            ImGui.TextDisabled(ctx, Tr("meta_preview_missing"))
            if s.preview_error and s.preview_error ~= "" then
              ImGui.TextWrapped(ctx, Tr("meta_preview_error", { value = tostring(s.preview_error) }))
            end
          end
          ImGui.Text(ctx, Tr("meta_created", { value = tostring(s.created_at or "") }))

          if s.description and s.description ~= "" then
            ImGui.Separator(ctx)
            ImGui.TextWrapped(ctx, s.description)
          end
          ImGui.EndTooltip(ctx)
        end
      end
    end

    if visible_count == 0 then
      ImGui.TextDisabled(ctx, Tr("no_snapshots_found"))
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
      ImGui.TextDisabled(ctx, Tr("no_snapshot_selected"))
    else
      local frame_height = GetFrameHeightSafe(22)
      ImGui.Text(ctx, tostring(s.name or Tr("unnamed")))

      ImGui.SameLine(ctx, nil, 5)
      if ImGui.SmallButton(ctx, (s.favorite and "★ " or "☆ ") .. Tr("favorite")) then
        ToggleFavorite(s)
      end

      ImGui.SameLine(ctx, nil, 5)
      if ImGui.SmallButton(ctx, Tr("open_folder")) then
        OpenFolder(GetSnapshotFolderForFileOperation(s))
      end

      ImGui.SameLine(ctx, nil, 5)
      if ImGui.SmallButton(ctx, Tr("export_zip")) then
        ExportSelectedSnapshotZip()
      end

      -- ImGui.SameLine(ctx, nil, 5)
      -- if ImGui.SmallButton(ctx, "Remove") then
      --   RemoveSelectedSnapshotFromIndex()
      -- end

      ImGui.TextDisabled(ctx, Tr("meta_category", { value = DisplayCategory(s.category) }))
      ImGui.TextDisabled(ctx, Tr("meta_source", { value = GetCaptureModeDisplay(s.capture_mode, s.capture_mode_label) }))
      ImGui.TextDisabled(ctx, Tr("meta_tags", { value = JoinTags(s.tags) }))
      ImGui.TextDisabled(ctx, Tr("meta_detail_summary", {
        duration = string.format("%.3f", tonumber(s.duration) or 0),
        tracks = tostring(tonumber(s.track_count) or 0),
        items = tostring(tonumber(s.item_count) or 0),
        media = tostring(tonumber(s.media_copied_count) or 0),
      }))
      ImGui.TextDisabled(ctx, Tr("meta_preview_skip", { value = string.format("%.3f", tonumber(s.preview_start_offset) or 0) }))
      ImGui.TextDisabled(ctx, Tr("meta_created", { value = tostring(s.created_at or "") }))

      if tonumber(s.media_missing_count or 0) and tonumber(s.media_missing_count or 0) > 0 then
        ImGui.TextDisabled(ctx, Tr("meta_missing_media", { value = tostring(s.media_missing_count or 0) }))
      end
      if s.description and s.description ~= "" then
        ImGui.TextWrapped(ctx, s.description)
      end
    end

    ImGui.Dummy(ctx, 0, 5) -- 5 像素间隔
    ImGui.EndChild(ctx)
  end
end

function DrawBottomStatusBar(width, height)
  width = width or 0
  height = height or STATUS_BAR_HEIGHT

  local pushed_padding = false
  if ImGui.StyleVar_WindowPadding then
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)
    pushed_padding = true
  end

  ImGui.Dummy(ctx, 0, STATUS_BAR_PADDING_Y)
  ImGui.PushFont(ctx, font_small, STATUS_BAR_FONT_SIZE)
  ImGui.TextDisabled(ctx, state.status or "")
  ImGui.PopFont(ctx)

  if pushed_padding then
    ImGui.PopStyleVar(ctx)
  end
end

function DrawSnapshotMetadataFields(info_key)
  ImGui.Text(ctx, Tr(info_key))
  ImGui.Separator(ctx)

  ImGui.SetNextItemWidth(ctx, 400)
  local changed, v = ImGui.InputText(ctx, UiLabel("field_name", "save_name"), state.save_name)
  if changed then state.save_name = v end

  ImGui.SetNextItemWidth(ctx, 400)
  local changed2, v2 = ImGui.InputText(ctx, "##CategoryInput", state.save_category)
  if changed2 then state.save_category = v2 end

  ImGui.SameLine(ctx, nil, 3)

  if ImGui.SmallButton(ctx, UiLabel("category_dropdown", "category_presets")) then
    ImGui.OpenPopup(ctx, "CategoryPresetPopup")
  end
  if state.show_tips and ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, Tr("tooltip_choose_categories"))
  end

  DrawSelectablePopupList("CategoryPresetPopup", GetCategories(), function(item)
    if item ~= "All" then
      state.save_category = item == "Uncategorized" and "" or item
    end
  end, Tr("no_existing_categories"))

  ImGui.SetNextItemWidth(ctx, 400)
  local changed3, v3 = ImGui.InputText(ctx, "##TagsInput", state.save_tags)
  if changed3 then state.save_tags = v3 end

  ImGui.SameLine(ctx, nil, 3)

  if ImGui.SmallButton(ctx, UiLabel("tags_dropdown", "tag_presets")) then
    ImGui.OpenPopup(ctx, "TagPresetPopup")
  end
  if state.show_tips and ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, Tr("tooltip_append_tags"))
  end

  DrawSelectablePopupList("TagPresetPopup", GetAllTags(), function(item)
    state.save_tags = AppendTagText(state.save_tags, item)
  end, Tr("no_existing_tags"))

  ImGui.SetNextItemWidth(ctx, 400)
  local changed4, v4 = ImGui.InputTextMultiline(ctx, UiLabel("field_description", "save_description"), state.save_description, 400, 90)
  if changed4 then state.save_description = v4 end

  if state.show_tips then
    ImGui.TextDisabled(ctx, Tr("tip_reuse_names"))
  end
end

function DrawSavePopup()
  if ImGui.BeginPopupModal(ctx, UiLabel("popup_save_snapshot", "SaveSnapshotPopup"), nil, ImGui.WindowFlags_AlwaysAutoResize) then
    state.modal_popup_active = true
    DrawSnapshotMetadataFields("smart_save_info")

    ImGui.Separator(ctx)

    local save_requested = ImGui.Button(ctx, Tr("save"), 100, 30) or IsConfirmKeyPressed()
    if save_requested and not state.save_in_progress and not state.save_submitted then
      if SaveSnapshotFromPopup() then
        state.show_save_popup = false
        ImGui.CloseCurrentPopup(ctx)
      end
    end

    ImGui.SameLine(ctx)

    if ImGui.Button(ctx, Tr("cancel"), 100, 30) and not state.save_in_progress then
      state.show_save_popup = false
      state.save_submitted = false
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end
end

function DrawEditPopup()
  if ImGui.BeginPopupModal(ctx, UiLabel("popup_edit_snapshot", "EditSnapshotPopup"), nil, ImGui.WindowFlags_AlwaysAutoResize) then
    state.modal_popup_active = true
    local _, snapshot = FindSnapshotIndexById(state.edit_snapshot_id)

    if not snapshot then
      ImGui.TextDisabled(ctx, Tr("no_snapshot_selected"))
      ImGui.Separator(ctx)

      if ImGui.Button(ctx, Tr("cancel"), 100, 30) then
        state.edit_snapshot_id = ""
        state.save_submitted = false
        ImGui.CloseCurrentPopup(ctx)
      end
    else
      DrawSnapshotMetadataFields("edit_snapshot_info")
      ImGui.Separator(ctx)

      local edit_requested = ImGui.Button(ctx, Tr("save"), 100, 30) or IsConfirmKeyPressed()
      if edit_requested and not state.save_in_progress and not state.save_submitted then
        if EditSnapshotFromPopup() then
          state.edit_snapshot_id = ""
          ImGui.CloseCurrentPopup(ctx)
        end
      end

      ImGui.SameLine(ctx)

      if ImGui.Button(ctx, Tr("cancel"), 100, 30) and not state.save_in_progress then
        state.edit_snapshot_id = ""
        state.save_submitted = false
        ImGui.CloseCurrentPopup(ctx)
      end
    end

    ImGui.EndPopup(ctx)
  end
end

function DrawRenamePopup()
  if ImGui.BeginPopupModal(ctx, UiLabel("popup_rename_snapshot", "RenameSnapshotPopup"), nil, ImGui.WindowFlags_AlwaysAutoResize) then
    state.modal_popup_active = true
    local _, snapshot = FindSnapshotIndexById(state.rename_snapshot_id)

    if not snapshot then
      ImGui.TextDisabled(ctx, Tr("no_snapshot_selected"))
      ImGui.Separator(ctx)

      if ImGui.Button(ctx, Tr("cancel"), 100, 30) then
        state.status = Tr("status_rename_cancelled")
        ImGui.CloseCurrentPopup(ctx)
      end
    else
      ImGui.Text(ctx, tostring(snapshot.name or Tr("unnamed")))
      ImGui.Separator(ctx)

      ImGui.Text(ctx, Tr("field_new_name"))
      ImGui.SameLine(ctx, nil, 5)
      ImGui.SetNextItemWidth(ctx, 300)
      local changed, value = ImGui.InputText(ctx, "##rename_name", state.rename_name or "")
      if changed then state.rename_name = value end

      ImGui.Separator(ctx)

      local rename_requested = ImGui.Button(ctx, Tr("rename"), 100, 30) or IsConfirmKeyPressed()
      if rename_requested then
        if RenameSnapshotById(state.rename_snapshot_id, state.rename_name) then
          ImGui.CloseCurrentPopup(ctx)
        end
      end

      ImGui.SameLine(ctx)

      if ImGui.Button(ctx, Tr("cancel"), 100, 30) then
        state.status = Tr("status_rename_cancelled")
        ImGui.CloseCurrentPopup(ctx)
      end
    end

    ImGui.EndPopup(ctx)
  end
end

function DrawLoadConfirmPopup()
  if ImGui.BeginPopupModal(ctx, UiLabel("popup_load_snapshot", "LoadSnapshotPopup"), nil, ImGui.WindowFlags_AlwaysAutoResize) then
    state.modal_popup_active = true
    local snapshot = state.snapshots[state.selected]

    if not snapshot then
      ImGui.TextDisabled(ctx, Tr("no_snapshot_selected"))
    else
      ImGui.Text(ctx, Tr("load_snapshot_name", { name = tostring(snapshot.name or Tr("unnamed")) }))
      ImGui.Separator(ctx)

      local changed1, v1 = ImGui.Checkbox(ctx, Tr("load_to_new_tracks"), state.load_popup_load_to_new_tracks)
      if changed1 then state.load_popup_load_to_new_tracks = v1 end

      local changed2, v2 = ImGui.Checkbox(ctx, Tr("check_empty_target"), state.load_popup_check_empty_space)
      if changed2 then state.load_popup_check_empty_space = v2 end

      local changed3, v3 = ImGui.Checkbox(ctx, Tr("restore_markers"), state.load_popup_restore_markers)
      if changed3 then state.load_popup_restore_markers = v3 end

      local changed4, v4 = ImGui.Checkbox(ctx, Tr("restore_regions"), state.load_popup_restore_regions)
      if changed4 then state.load_popup_restore_regions = v4 end

      local changed5, v5 = ImGui.Checkbox(ctx, Tr("restore_tempo"), state.load_popup_restore_tempo)
      if changed5 then state.load_popup_restore_tempo = v5 end

      local changed6, v6 = ImGui.Checkbox(ctx, Tr("restore_track_info"), state.load_popup_restore_track_info)
      if changed6 then state.load_popup_restore_track_info = v6 end
      if state.show_tips and ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, Tr("tooltip_restore_track_info_load"))
      end

      local changed7, v7 = ImGui.Checkbox(ctx, Tr("restore_empty_tracks"), state.load_popup_restore_empty_tracks)
      if changed7 then state.load_popup_restore_empty_tracks = v7 end
      if state.show_tips and ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, Tr("tooltip_restore_empty_tracks"))
      end

      ImGui.Separator(ctx)

      local load_requested = ImGui.Button(ctx, Tr("load"), 100, 30) or IsConfirmKeyPressed()
      if load_requested then
        ApplyLoadPopupSettings()
        state.request_execute_load = true
        ImGui.CloseCurrentPopup(ctx)
      end

      ImGui.SameLine(ctx)

      if ImGui.Button(ctx, Tr("cancel"), 100, 30) then
        ImGui.CloseCurrentPopup(ctx)
      end
    end

    ImGui.EndPopup(ctx)
  end
end

function DrawSettingsPopup()
  if ImGui.BeginPopupModal(ctx, UiLabel("popup_settings", "SettingsPopup"), nil, ImGui.WindowFlags_AlwaysAutoResize) then
    state.modal_popup_active = true
    ImGui.SeparatorText(ctx, Tr("interface"))
    ImGui.Text(ctx, Tr("settings_language"))
    ImGui.SameLine(ctx, nil, 5)
    ImGui.SetNextItemWidth(ctx, 200)
    if ImGui.BeginCombo(ctx, "##language", GetLanguageDisplayName(state.language or language)) then
      for _, option in ipairs(LANGUAGE_OPTIONS) do
        local selected = NormalizeLanguageId(state.language or language) == option.id
        if ImGui.Selectable(ctx, GetLanguageOptionLabel(option) .. "##language_" .. option.id, selected) then
          state.language = option.id
        end
        if selected and ImGui.SetItemDefaultFocus then
          ImGui.SetItemDefaultFocus(ctx)
        end
      end
      ImGui.EndCombo(ctx)
    end

    --ImGui.Separator(ctx)
    ImGui.SeparatorText(ctx, Tr("settings_library_location"))
    ImGui.TextDisabled(ctx, Tr("settings_library_description"))
    --ImGui.Separator(ctx)

    ImGui.SetNextItemWidth(ctx, 400)
    local changed, v = ImGui.InputText(ctx, "##library_dir", state.new_library_dir)
    if changed then state.new_library_dir = v end

    ImGui.SameLine(ctx, nil, 5)
    local frame_height = GetFrameHeightSafe(22)

    if ImGui.Button(ctx, UiLabel("browse", "SelectLibraryDir"), nil, frame_height) then
      if reaper.JS_Dialog_BrowseForFolder then
        local start_dir = state.new_library_dir ~= "" and state.new_library_dir or state.library_dir
        local rv, out = reaper.JS_Dialog_BrowseForFolder(Tr("select_library_directory"), start_dir)
        if rv == 1 and out and out ~= "" then
          state.new_library_dir = NormalizePath(out)
        end
      else
        reaper.MB(Tr("error_folder_browser_requires_js"), SCRIPT_NAME, 0)
      end
    end

    if ImGui.SmallButton(ctx, Tr("use_reaper_resource_path")) then
      state.new_library_dir = DEFAULT_LIBRARY_DIR
    end
    -- if ImGui.Button(ctx, "Use REAPER Resource Path", nil, frame_height) then
    --   state.new_library_dir = DEFAULT_LIBRARY_DIR
    -- end
    ImGui.SameLine(ctx, nil, 5)
    if ImGui.SmallButton(ctx, Tr("open_current_library")) then
      OpenFolder(state.library_dir)
    end
    -- if ImGui.Button(ctx, "Open Current Library", nil, frame_height) then
    --   OpenFolder(state.library_dir)
    -- end

    --ImGui.Separator(ctx)
    ImGui.SeparatorText(ctx, Tr("settings_load_options"))

    local c1, v1 = ImGui.Checkbox(ctx, Tr("show_load_popup"), state.show_load_popup)
    if c1 then state.show_load_popup = v1 end

    local c2, v2 = ImGui.Checkbox(ctx, Tr("load_to_new_tracks"), state.load_to_new_tracks)
    if c2 then state.load_to_new_tracks = v2 end

    local c3, v3 = ImGui.Checkbox(ctx, Tr("check_empty_target"), state.check_empty_space)
    if c3 then state.check_empty_space = v3 end

    local c4, v4 = ImGui.Checkbox(ctx, Tr("restore_markers"), state.restore_markers)
    if c4 then state.restore_markers = v4 end

    local c5, v5 = ImGui.Checkbox(ctx, Tr("restore_regions"), state.restore_regions)
    if c5 then state.restore_regions = v5 end

    local c6, v6 = ImGui.Checkbox(ctx, Tr("restore_tempo"), state.restore_tempo)
    if c6 then state.restore_tempo = v6 end

    local c7, v7 = ImGui.Checkbox(ctx, Tr("restore_track_info"), state.restore_track_info)
    if c7 then state.restore_track_info = v7 end
    if state.show_tips and ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, Tr("tooltip_restore_track_info_settings"))
    end

    local c8, v8 = ImGui.Checkbox(ctx, Tr("restore_empty_tracks"), state.restore_empty_tracks)
    if c8 then state.restore_empty_tracks = v8 end
    if state.show_tips and ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, Tr("tooltip_restore_empty_tracks"))
    end

    --ImGui.Separator(ctx)
    ImGui.SeparatorText(ctx, Tr("settings_save_options"))

    local c9, v9 = ImGui.Checkbox(ctx, Tr("auto_render_preview"), state.auto_render_preview)
    if c9 then state.auto_render_preview = v9 end

    local c10, v10 = ImGui.Checkbox(ctx, Tr("skip_preview_leading_empty"), state.skip_preview_leading_empty)
    if c10 then state.skip_preview_leading_empty = v10 end

    --ImGui.Separator(ctx)
    ImGui.SeparatorText(ctx, Tr("settings_snapshot_options"))
    ImGui.Text(ctx, Tr("settings_snapshot_sort"))
    ImGui.SameLine(ctx, nil, 5)

    local current_sort_label = GetSortLabel(state.sort_order or "newest")
    ImGui.SetNextItemWidth(ctx, 200)
    if ImGui.BeginCombo(ctx, "##snapshot_sort_order", current_sort_label) then
      local sort_items = {
        { key = "newest", label = GetSortLabel("newest") },
        { key = "oldest", label = GetSortLabel("oldest") },
        { key = "alphabetical", label = GetSortLabel("alphabetical") },
      }

      for _, item in ipairs(sort_items) do
        if ImGui.Selectable(ctx, item.label .. "##sort_" .. item.key, state.sort_order == item.key) then
          state.sort_order = item.key
          SaveSettings()
          SortSnapshots()
          state.status = Tr("status_sort_changed", { label = item.label })
        end
      end

      ImGui.EndCombo(ctx)
    end

    --ImGui.Separator(ctx)
    reaper.ImGui_SeparatorText(ctx, Tr("settings_display_options"))

    local c11, v11 = ImGui.Checkbox(ctx, Tr("show_capture_abbreviations"), state.show_capture_abbreviations)
    if c11 then state.show_capture_abbreviations = v11 end

    local c12, v12 = ImGui.Checkbox(ctx, Tr("show_tips"), state.show_tips)
    if c12 then state.show_tips = v12 end

    local c13, v13 = ImGui.Checkbox(ctx, Tr("place_info_panel_bottom"), state.info_panel_at_bottom)
    if c13 then state.info_panel_at_bottom = v13 end

    ImGui.Separator(ctx)

    if ImGui.Button(ctx, Tr("apply"), 100, 30) then
      state.language = NormalizeLanguageId(state.language or language)
      SetLanguage(state.language)
      state.library_dir = NormalizePath(state.new_library_dir)
      EnsureDir(state.library_dir)
      EnsureDir(GetSnapshotsRoot())
      SaveSettings()
      LoadIndex()
      ResetWaveformCacheState()
      state.status = Tr("status_settings_applied")
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.SameLine(ctx, nil, 10)

    if ImGui.Button(ctx, Tr("cancel"), 100, 30) then
      state.language = language
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

function IsKeyPressedSafe(key)
  if not ImGui.IsKeyPressed or key == nil then return false end

  local ok, pressed = pcall(ImGui.IsKeyPressed, ctx, key)
  return ok and pressed == true
end

function IsConfirmKeyPressed()
  return IsKeyPressedSafe(KEY_ENTER) or IsKeyPressedSafe(KEY_KEYPAD_ENTER)
end

function HandleExitShortcut()
  if IsKeyPressedSafe(KEY_ESCAPE) then
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

function IsCtrlDown()
  if ImGui.GetKeyMods then
    local ok, mods = pcall(ImGui.GetKeyMods, ctx)
    if ok and tonumber(mods) and tonumber(MOD_CTRL) then
      local ctrl = tonumber(MOD_CTRL) or 0
      if ctrl > 0 then
        return math.floor((tonumber(mods) or 0) / ctrl) % 2 == 1
      end
    end
  end

  local left_down = false
  local right_down = false

  if ImGui.IsKeyDown then
    if KEY_LEFT_CTRL then
      local ok_left, result_left = pcall(ImGui.IsKeyDown, ctx, KEY_LEFT_CTRL)
      if ok_left then left_down = result_left == true end
    end

    if KEY_RIGHT_CTRL then
      local ok_right, result_right = pcall(ImGui.IsKeyDown, ctx, KEY_RIGHT_CTRL)
      if ok_right then right_down = result_right == true end
    end
  end

  return left_down or right_down
end

function IsAltDown()
  if ImGui.GetKeyMods then
    local ok, mods = pcall(ImGui.GetKeyMods, ctx)
    if ok and tonumber(mods) and tonumber(MOD_ALT) then
      local alt = tonumber(MOD_ALT) or 0
      if alt > 0 then
        return math.floor((tonumber(mods) or 0) / alt) % 2 == 1
      end
    end
  end

  local left_down = false
  local right_down = false

  if ImGui.IsKeyDown then
    if KEY_LEFT_ALT then
      local ok_left, result_left = pcall(ImGui.IsKeyDown, ctx, KEY_LEFT_ALT)
      if ok_left then left_down = result_left == true end
    end

    if KEY_RIGHT_ALT then
      local ok_right, result_right = pcall(ImGui.IsKeyDown, ctx, KEY_RIGHT_ALT)
      if ok_right then right_down = result_right == true end
    end
  end

  return left_down or right_down
end

function HandleGlobalShortcuts()
  if not state.main_window_focused and not state.snapshot_list_focused then return end
  if state.modal_popup_active then return end

  if IsCtrlDown() then
    if IsKeyPressedSafe(KEY_COMMA) then
      RequestSettingsPopup(false)
      return
    end

    if IsKeyPressedSafe(KEY_S) then
      RequestSaveSnapshotPopup(false)
      return
    end

    if IsKeyPressedSafe(KEY_L) then
      RequestLoadSelectedSnapshot()
      return
    end
  end

  if IsAltDown() and IsConfirmKeyPressed() then
    RequestLoadSelectedSnapshot()
  end
end

function HandleSnapshotListShortcuts()
  if not state.main_window_focused and not state.snapshot_list_focused then return end
  if IsTextInputActive() then return end
  if not ImGui.IsKeyPressed then return end

  local snapshot = state.snapshots[state.selected]
  if not snapshot then return end

  if IsKeyPressedSafe(KEY_SPACE) then
    TogglePreviewPlayback()
    return
  end

  if IsKeyPressedSafe(KEY_F) then
    ToggleFavorite(snapshot)
    return
  end

  if not state.snapshot_list_focused then return end

  local shift_down = IsShiftDown()

  if IsKeyPressedSafe(KEY_DELETE) and shift_down then
    RemoveSelectedSnapshotFromIndex()
    return
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

  -- macOS 的字体行高和边界取整会比固定状态栏高度多占几个像素。
  local status_bar_height = STATUS_BAR_HEIGHT + ((IsMacOS and IsMacOS()) and 1 or 0)

  local gap_size = 5
  local splitter_size = 5
  local middle_size = gap_size + splitter_size + gap_size

  local min_list = 150
  local min_info = 150

  local safe_w = math.max(1, avail_w - 1)
  local safe_h = math.max(1, avail_h - status_bar_height - 1)
  local layout_cursor_x = ImGui.GetCursorPosX and ImGui.GetCursorPosX(ctx) or nil
  local layout_cursor_y = ImGui.GetCursorPosY and ImGui.GetCursorPosY(ctx) or nil

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

    DrawSnapshotList(list_w, safe_h)

    -- 5px 像素间隔
    ImGui.SameLine(ctx, nil, gap_size)

    -- 5px 像素分隔条
    DrawSplitter("##splitter_side", "vertical", safe_h, start_x, usable_w, "side_split_ratio", gap_size)

    -- 5px 像素间隔
    ImGui.SameLine(ctx, nil, gap_size)

    DrawInfoPanel(0, safe_h)
  end

  if layout_cursor_y and ImGui.SetCursorPosY then
    ImGui.SetCursorPosY(ctx, layout_cursor_y + safe_h)
  end
  if layout_cursor_x and ImGui.SetCursorPosX then
    ImGui.SetCursorPosX(ctx, layout_cursor_x)
  end

  DrawBottomStatusBar(0, status_bar_height)

  ImGui.PopStyleVar(ctx)
end

----------------------------------------
-- Main Loop
----------------------------------------

function MainLoop()
  UpdatePreviewState()
  PumpPeakBuildQueue(0.02)
  MaybeSynchronizeSnapshotsWithDisk(false)
  ImGui.SetNextWindowSize(ctx, 430, 670, ImGui.Cond_FirstUseEver)

  PushStyle()

  state.main_window_focused = false
  local visible, open = ImGui.Begin(ctx, SCRIPT_NAME, true, WINDOW_FLAGS_MAIN)
  if visible then
    if ImGui.IsWindowFocused then
      local ok_focused, focused = pcall(ImGui.IsWindowFocused, ctx, FOCUSED_FLAGS_ROOT_AND_CHILDREN)
      if not ok_focused then
        ok_focused, focused = pcall(ImGui.IsWindowFocused, ctx)
      end
      state.main_window_focused = ok_focused and focused == true
    end

    if font_normal then ImGui.PushFont(ctx, font_normal, 14) end

    DrawHeader()
    DrawTopBar()
    DrawFilters()
    DrawWaveformCachePreviewBar()
    -- ImGui.Separator(ctx)
    DrawMainContentLayout()

    state.modal_popup_active = false
    if state.request_open_save_popup then
      state.request_open_save_popup = false
      ImGui.OpenPopup(ctx, UiLabel("popup_save_snapshot", "SaveSnapshotPopup"))
    end
    DrawSavePopup()
    if state.request_open_edit_popup then
      state.request_open_edit_popup = false
      ImGui.OpenPopup(ctx, UiLabel("popup_edit_snapshot", "EditSnapshotPopup"))
    end
    DrawEditPopup()
    if state.request_open_rename_popup then
      state.request_open_rename_popup = false
      ImGui.OpenPopup(ctx, UiLabel("popup_rename_snapshot", "RenameSnapshotPopup"))
    end
    DrawRenamePopup()
    if state.request_open_load_confirm_popup then
      state.request_open_load_confirm_popup = false
      ImGui.OpenPopup(ctx, UiLabel("popup_load_snapshot", "LoadSnapshotPopup"))
    end
    DrawLoadConfirmPopup()
    if state.request_execute_load then
      state.request_execute_load = false
      LoadSelectedSnapshot()
    end
    if state.request_open_settings_popup then
      state.request_open_settings_popup = false
      ImGui.OpenPopup(ctx, UiLabel("popup_settings", "SettingsPopup"))
    end
    DrawSettingsPopup()
    HandleExitShortcut()
    HandleGlobalShortcuts()
    HandleSnapshotListShortcuts()

    if font_normal then ImGui.PopFont(ctx) end
    ImGui.End(ctx)
  end

  UpdateSnapshotArrangeDrag()

  PopStyle()

  if state.request_close then
    open = false
  end

  if open then
    reaper.defer(MainLoop)
  else
    ClearSnapshotArrangeDrag()
    StopInternalPreview(true)
    ResetWaveformCacheState()
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
