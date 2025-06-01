-- @description Project Audio File Explorer
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog
--   New Script
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

-- local SCRIPT_NAME = 'Project Audio File Explorer - Browse, search and preview all audio files referenced by or located in the current project.'
local SCRIPT_NAME = 'Project Audio File Explorer - Browse, Search, and Preview Project Audio'
local FLT_MIN, FLT_MAX = reaper.ImGui_NumericLimits_Float()
local ctx = reaper.ImGui_CreateContext('SCRIPT_NAME')
local sans_serif = reaper.ImGui_CreateFont('sans-serif', 14)
reaper.ImGui_Attach(ctx, sans_serif)
reaper.ImGui_SetNextWindowSize(ctx, 947, 447, reaper.ImGui_Cond_FirstUseEver())

-- 状态变量
local selected_row      = -1
local playing_preview   = nil
local playing_path      = nil
local playing_source    = nil
local loop_enabled      = false -- 是否自动循环
local preview_play_len  = 0     -- 当前预览音频长度
local peak_chans        = 2     -- 默认显示2路电平
local seek_pos          = nil   -- 拖动时记住目标位置
local volume            = 1     -- 线性音量（1=0dB，0.5=-6dB，2=+6dB）
local play_rate         = 1     -- 默认速率1.0
local pitch             = 0     -- 音高调节（半音，正负）
local preserve_pitch    = true  -- 变速时是否保持音高
local is_paused         = false -- 是否处于暂停状态
local paused_position   = 0     -- 暂停时的进度
-- 表格列表排序 
local COL_FILENAME      = 2
local COL_SIZE          = 3
local COL_TYPE          = 4
local COL_DATE          = 5
local COL_GENRE         = 6
local COL_COMMENT       = 7
local COL_DESCRIPTION   = 8
local COL_LENGTH        = 9
local COL_CHANNELS      = 10
local COL_SAMPLERATE    = 11
local COL_BITS          = 12
local files_idx_cache   = nil   -- 文件缓存
-- 表格高度
local file_table_height = 300   -- 文件表格初始高度（可根据需要设定默认值）
local min_table_height  = 80    -- 最小高度
local max_table_height  = 800   -- 最大高度
-- ExtState持久化设置
local EXT_SECTION = "ProjectAudioFileExplorer"
local EXT_KEY_TABLE_HEIGHT = "FileTableHeight"
-- 列表过滤
local filename_filter   = nil
-- 预览已读标记
local previewed_files   = {}
local function MarkPreviewed(path) previewed_files[path] = true end
local function IsPreviewed(path) return previewed_files[path] == true end

-- 读取ExtState
local last_height = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_TABLE_HEIGHT))
if last_height then
  file_table_height = math.min(math.max(last_height, min_table_height), max_table_height)
end

-- 收集音频方式（0=Items, 1=RPP, 2=Directory）
local collect_mode = 0
local COLLECT_MODE_ITEMS = 0
local COLLECT_MODE_RPP = 1
local COLLECT_MODE_DIR = 2

-- 收集工程音频文件
local function CollectAllUniqueSources_FromItems()
  local files, files_idx = {}, {}
  local item_cnt = reaper.CountMediaItems(0)
  for i = 0, item_cnt - 1 do
    local item = reaper.GetMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    if take then
      local source = reaper.GetMediaItemTake_Source(take)
      local path = reaper.GetMediaSourceFileName(source, "")
      local typ = reaper.GetMediaSourceType(source, "")
      if path and path ~= "" and not files[path] and (typ == "WAVE" or typ == "MP3" or typ == "FLAC" or typ == "OGG" or typ == "AIFF" or typ == "APE") then
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

-- 基于当前工程RPP内容，收集所有音频文件
function CollectAllUniqueSources_FromRPP()
  local files, files_idx = {}, {}
  local proj = 0
  local tracks = {}
  tracks[#tracks+1] = reaper.GetMasterTrack(proj)
  local track_count = reaper.CountTracks(proj)
  for i = 0, track_count-1 do
    tracks[#tracks+1] = reaper.GetTrack(proj, i)
  end

  for _, track in ipairs(tracks) do
    local ret, chunk = reaper.GetTrackStateChunk(track, "", false)
    if ret and chunk then
      for path in chunk:gmatch('FILE%s+"(.-)"') do
        if not files[path] then
          local info = { path = path, filename = path:match("[^\\/]+$") or path }
          -- 获取文件大小
          local f = io.open(path, "rb")
          if f then
            f:seek("end")
            info.size = f:seek()
            f:close()
          else
            info.size = 0
          end

          local src = reaper.PCM_Source_CreateFromFile(path)
          if src then
            info.source = src
            info.type = reaper.GetMediaSourceType(src, "")
            info.length = reaper.GetMediaSourceLength(src)
            info.samplerate = reaper.GetMediaSourceSampleRate(src)
            info.channels = reaper.GetMediaSourceNumChannels(src)
            info.bits = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(src) or "-"
            local _, genre = reaper.GetMediaFileMetadata(src, "XMP:dm/genre")
            local _, comment = reaper.GetMediaFileMetadata(src, "MP:dm/logComment")
            local _, description = reaper.GetMediaFileMetadata(src, "BWF:Description")
            local _, orig_date  = reaper.GetMediaFileMetadata(src, "BWF:OriginationDate")
            info.genre = genre or ""
            info.comment = comment or ""
            info.description = description or ""
            info.bwf_orig_date = orig_date or ""
          end
          files[path] = info
          files_idx[#files_idx+1] = info
        end
      end
    end
  end
  return files, files_idx
end

-- 从工程目录收集音频文件
function CollectAllUniqueSources_FromProjectDirectory()
  local files, files_idx = {}, {}
  -- 获取当前工程路径
  local proj_path = reaper.GetProjectPath("")
  if not proj_path or proj_path == "" then return files, files_idx end
  -- 支持的扩展名
  local valid_exts = {wav=true, mp3=true, flac=true, ogg=true, aiff=true, ape=true}
  local i = 0
  while true do
    local file = reaper.EnumerateFiles(proj_path, i)
    if not file then break end
    local ext = file:match("^.+%.([^.]+)$")
    if ext and valid_exts[ext:lower()] then
      local fullpath = proj_path .. "/" .. file
      if not files[fullpath] then
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

-- 收集音频文件旧版本
-- function CollectFiles()
--   local files, files_idx = CollectAllUniqueSources_FromProjectDirectory()
--   files_idx_cache = files_idx
--   -- 清空已预览标记
--   previewed_files = {}
-- end

-- 按文件名排序
local function SortFilesByFilenameAsc()
  if files_idx_cache then
    table.sort(files_idx_cache, function(a, b)
      return (a.filename or "") < (b.filename or "")
    end)
  end
end

function CollectFiles()
  local files, files_idx
  if collect_mode == COLLECT_MODE_ITEMS then
    files, files_idx = CollectAllUniqueSources_FromItems()
  elseif collect_mode == COLLECT_MODE_RPP then
    files, files_idx = CollectAllUniqueSources_FromRPP()
  elseif collect_mode == COLLECT_MODE_DIR then
    files, files_idx = CollectAllUniqueSources_FromProjectDirectory()
  end
  files_idx_cache = files_idx
  previewed_files = {}

  SortFilesByFilenameAsc() -- 自从按文件名排序

  -- if do_sort then
  --   SortFilesByFilenameAsc()
  -- end
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

local function VAL2DB(x)
  if x < 0.0000000298023223876953125 then
    return -150
  else
    return math.max(-150, math.log(x) * 8.6858896380650365530225783783321)
  end
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

function loop()
  -- 首次使用时收集音频文件
  if not files_idx_cache then
    CollectFiles()
  end
  reaper.ImGui_PushFont(ctx, sans_serif)
  -- 以下会进行每帧调用，导致脚本卡顿。所以用 files_idx_cache 作为唯一音频列表的数据表
  -- local files, files_idx = CollectAllUniqueSources()
  -- local files, files_idx = CollectAllUniqueSources_FromRPP()
  -- local files, files_idx = CollectAllUniqueSources_FromProjectDirectory()

  local visible, open = reaper.ImGui_Begin(ctx, SCRIPT_NAME, true)
  if visible then
    reaper.ImGui_Text(ctx, ("%d audio files found."):format(#files_idx_cache))
    if playing_preview and playing_path then
      reaper.ImGui_SameLine(ctx, nil, 1)
      reaper.ImGui_Text(ctx, " Now playing: " .. playing_path)
    end

    -- 过滤器
    reaper.ImGui_Text(ctx, "Filter:")
    reaper.ImGui_SameLine(ctx)
    -- reaper.ImGui_SetNextItemWidth(ctx, 500)
    if not filename_filter then
      filename_filter = reaper.ImGui_CreateTextFilter()
      reaper.ImGui_Attach(ctx, filename_filter)
    end
    reaper.ImGui_TextFilter_Draw(filename_filter, ctx, "##FilterQWERT")

    -- 清空过滤器内容
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Clear") then
      reaper.ImGui_TextFilter_Set(filename_filter, "")
    end

    -- 音频源下拉菜单
    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_SetNextItemWidth(ctx, 120)
    local collect_mode_options = { "From Items", "From RPP", "Project Directory" }
    if reaper.ImGui_BeginCombo(ctx, "Source##collect_mode_combo", collect_mode_options[collect_mode + 1]) then
      for i = 0, #collect_mode_options - 1 do
        local is_selected = (i == collect_mode)
        if reaper.ImGui_Selectable(ctx, collect_mode_options[i + 1], is_selected) then
          if collect_mode ~= i then
            collect_mode = i
            CollectFiles()
          end
        end
        if is_selected then reaper.ImGui_SetItemDefaultFocus(ctx) end
      end
      reaper.ImGui_EndCombo(ctx)
    end

    -- 刷新按钮
    reaper.ImGui_SameLine(ctx, nil, 10)
    if reaper.ImGui_Button(ctx, "Rescan") then
      CollectFiles()
    end

    -- 使用Slider调整表格可视高度
    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_PushItemWidth(ctx, -65)
    local changed, new_height = reaper.ImGui_SliderInt(ctx, "Height", file_table_height, min_table_height, max_table_height, "%d px")
    reaper.ImGui_SameLine(ctx)
    HelpMarker("Adjust the table height by dragging.\nCtrl + left-click to input a value directly.\n\n" .. "Click 'Rescan' to refresh the file list.")
    reaper.ImGui_PopItemWidth(ctx)
    if changed then
      file_table_height = new_height
      reaper.SetExtState(EXT_SECTION, EXT_KEY_TABLE_HEIGHT, tostring(file_table_height), true)
    end

    -- 支持表格排序和冻结首行
    reaper.ImGui_BeginChild(ctx, "##file_table_child", 0, file_table_height)
    if reaper.ImGui_BeginTable(ctx, "filelist", 13,
      reaper.ImGui_TableFlags_RowBg()
      | reaper.ImGui_TableFlags_Borders()
      | reaper.ImGui_TableFlags_Resizable()
      | reaper.ImGui_TableFlags_ScrollY()
      | reaper.ImGui_TableFlags_ScrollX()
      | reaper.ImGui_TableFlags_Sortable()
      | reaper.ImGui_TableFlags_Hideable()
    ) then
      reaper.ImGui_TableSetupScrollFreeze(ctx, 0, 1) -- 只冻结表头
      reaper.ImGui_TableSetupColumn(ctx, "Mark",        reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 20)
      reaper.ImGui_TableSetupColumn(ctx, "File",        reaper.ImGui_TableColumnFlags_WidthFixed(), 150, COL_FILENAME)
      reaper.ImGui_TableSetupColumn(ctx, "Size",        reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_SIZE)
      reaper.ImGui_TableSetupColumn(ctx, "Type",        reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_TYPE)
      reaper.ImGui_TableSetupColumn(ctx, "Date",        reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_DATE)
      reaper.ImGui_TableSetupColumn(ctx, "Genre",       reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_GENRE)
      reaper.ImGui_TableSetupColumn(ctx, "Comment",     reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_COMMENT)
      reaper.ImGui_TableSetupColumn(ctx, "Description", reaper.ImGui_TableColumnFlags_WidthFixed(), 100, COL_DESCRIPTION)
      reaper.ImGui_TableSetupColumn(ctx, "Length",      reaper.ImGui_TableColumnFlags_WidthFixed(), 60, COL_LENGTH)
      reaper.ImGui_TableSetupColumn(ctx, "Channels",    reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_CHANNELS)
      reaper.ImGui_TableSetupColumn(ctx, "Samplerate",  reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_SAMPLERATE)
      reaper.ImGui_TableSetupColumn(ctx, "Bits",        reaper.ImGui_TableColumnFlags_WidthFixed(), 40, COL_BITS)
      reaper.ImGui_TableSetupColumn(ctx, "Path",        reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoSort(), 100)
      -- 此处新增时，记得累加 filelist 的列表数量
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
            elseif spec.user_id == COL_GENRE then -- Genre 列排序
              if (a.genre or "") ~= (b.genre or "") then
                if spec.sort_dir == reaper.ImGui_SortDirection_Descending() then
                  return (a.genre or "") > (b.genre or "")
                else
                  return (a.genre or "") < (b.genre or "")
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
          local row_hovered = false
        
          -- mark
          reaper.ImGui_TableSetColumnIndex(ctx, 0)
          if IsPreviewed(info.path) then
            local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
            local cx, cy = reaper.ImGui_GetCursorScreenPos(ctx)
            local radius = 2
            local color = 0x22ff22ff
            reaper.ImGui_DrawList_AddCircleFilled(draw_list, cx + radius + 10, cy + radius + 5, radius, color)
            reaper.ImGui_Dummy(ctx, radius*2+4, radius*2+4)
          else
            reaper.ImGui_Dummy(ctx, 10, 10)
          end

          -- File
          reaper.ImGui_TableSetColumnIndex(ctx, 1)
          if reaper.ImGui_Selectable(ctx, info.filename, selected_row == i, reaper.ImGui_SelectableFlags_SpanAllColumns()) then
            selected_row = i
          end
          if reaper.ImGui_IsItemHovered(ctx) then
            row_hovered = true
          end
          -- 双击播放
          if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            PlayFile(info.source, info.path, loop_enabled)
          end
          -- Ctrl+左键 或 Ctrl+I 插入到工程
          local ctrl = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl())
          local is_ctrl_click = reaper.ImGui_IsItemClicked(ctx, 0) and ctrl
          local is_ctrl_I = ctrl and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_I())
          if (is_ctrl_click or (selected_row == i and is_ctrl_I)) then
            reaper.InsertMedia(info.path, 0)
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
            PlayFile(info.source, info.path, loop_enabled)
          end

          -- Type
          reaper.ImGui_TableSetColumnIndex(ctx, 3)
          reaper.ImGui_Text(ctx, info.type)
          if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
          if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            PlayFile(info.source, info.path, loop_enabled)
          end

          -- Date
          reaper.ImGui_TableSetColumnIndex(ctx, 4)
          reaper.ImGui_Text(ctx, info.bwf_orig_date or "-")
          if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
          if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            PlayFile(info.source, info.path, loop_enabled)
          end

          -- Genre
          reaper.ImGui_TableSetColumnIndex(ctx, 5)
          reaper.ImGui_Text(ctx, info.genre or "-")
          if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
          if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            PlayFile(info.source, info.path, loop_enabled)
          end

          -- Comment
          reaper.ImGui_TableSetColumnIndex(ctx, 6)
          reaper.ImGui_Text(ctx, info.comment or "-")
          if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
          if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            PlayFile(info.source, info.path, loop_enabled)
          end

          -- Description
          reaper.ImGui_TableSetColumnIndex(ctx, 7)
          reaper.ImGui_Text(ctx, info.description or "-")
          if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
          if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            PlayFile(info.source, info.path, loop_enabled)
          end 

          -- Length
          reaper.ImGui_TableSetColumnIndex(ctx, 8)
          local len_str = (info.length and info.length > 0) and reaper.format_timestr(info.length, "") or "-"
          reaper.ImGui_Text(ctx, len_str)
          
          if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
          if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            PlayFile(info.source, info.path, loop_enabled)
          end

          -- Channels
          reaper.ImGui_TableSetColumnIndex(ctx, 9)
          reaper.ImGui_Text(ctx, info.channels)
          if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
          if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            PlayFile(info.source, info.path, loop_enabled)
          end

          -- Samplerate
          reaper.ImGui_TableSetColumnIndex(ctx, 10)
          reaper.ImGui_Text(ctx, info.samplerate or "-") -- reaper.ImGui_Text(ctx, info.samplerate and (info.samplerate .. " Hz") or "-")
          if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
          if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            PlayFile(info.source, info.path, loop_enabled)
          end

          -- Bits
          reaper.ImGui_TableSetColumnIndex(ctx, 11)
          reaper.ImGui_Text(ctx, info.bits or "-")
          if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
          if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            PlayFile(info.source, info.path, loop_enabled)
          end

          -- Path
          reaper.ImGui_TableSetColumnIndex(ctx, 12)
          reaper.ImGui_Text(ctx, info.path)
          if reaper.ImGui_IsItemHovered(ctx) then row_hovered = true end
          if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            PlayFile(info.source, info.path, loop_enabled)
          end
  
          -- 在所有列渲染之后，再设置背景色
          if row_hovered or selected_row == i then
            reaper.ImGui_TableSetBgColor(ctx, reaper.ImGui_TableBgTarget_RowBg1(), 0x2d83ec66)
          end
        end
      end

      reaper.ImGui_EndTable(ctx)
    end
    reaper.ImGui_EndChild(ctx)
    reaper.ImGui_Separator(ctx)
    -- 播放控制按钮
    -- Play 按钮
    if reaper.ImGui_Button(ctx, "Play") then
      if selected_row > 0 and files_idx_cache[selected_row] then
        PlayFile(files_idx_cache[selected_row].source, files_idx_cache[selected_row].path, loop_enabled)
        is_paused = false
        paused_position = 0
      end
    end
    -- Pause 按钮
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Pause") then
      if playing_preview and not is_paused then
        -- 暂停: 记录当前位置并停止播放
        local ok, pos = reaper.CF_Preview_GetValue(playing_preview, "D_POSITION")
        if ok then
          paused_position = pos
        else
          paused_position = 0
        end
        reaper.CF_Preview_Stop(playing_preview)
        is_paused = true
        playing_preview = nil
      elseif is_paused and playing_source then
        -- 继续播放: 从暂停处重新播放
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
          is_paused = false
        end
      end
    end
    -- Stop 按钮
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Stop") then
      StopPlay()
      is_paused = false
      paused_position = 0
    end
    -- 循环开关
    reaper.ImGui_SameLine(ctx)
    local rv
    rv, loop_enabled = reaper.ImGui_Checkbox(ctx, "Loop", loop_enabled)
    if rv and playing_preview and reaper.CF_Preview_SetValue then
      reaper.CF_Preview_SetValue(playing_preview, "B_LOOP", loop_enabled and 1 or 0)
    end
    -- 音量
    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_PushItemWidth(ctx, 200)
    local rv2
    rv2, volume = reaper.ImGui_SliderDouble(ctx, "Volume", volume, 0, 2, string.format("%.2f dB", VAL2DB(volume)), reaper.ImGui_SliderFlags_Logarithmic())
    reaper.ImGui_PopItemWidth(ctx)
    if rv2 and playing_preview and reaper.CF_Preview_SetValue then
      reaper.CF_Preview_SetValue(playing_preview, "D_VOLUME", volume)
    end
    -- 音高
    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_PushItemWidth(ctx, 40)
    local rv3
    rv3, pitch = reaper.ImGui_InputDouble(ctx, "Pitch", pitch) -- (ctx, "Pitch", pitch, 1, 12, "%.3f")
    reaper.ImGui_PopItemWidth(ctx)
    if rv3 and playing_preview and reaper.CF_Preview_SetValue then
      reaper.CF_Preview_SetValue(playing_preview, "D_PITCH", pitch)
    end
    -- 播放速率输入框
    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_PushItemWidth(ctx, 40)
    local rv4
    rv4, play_rate = reaper.ImGui_InputDouble(ctx, "Rate##RatePlayrate", play_rate) -- (ctx, "Rate##RatePlayrate", play_rate, 0.05, 0.1, "%.3f")
    reaper.ImGui_PopItemWidth(ctx)
    if rv4 and playing_preview and reaper.CF_Preview_SetValue then
      reaper.CF_Preview_SetValue(playing_preview, "D_PLAYRATE", play_rate)
    end

    -- 设置弹窗
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Settings##Popup") then
      reaper.ImGui_OpenPopup(ctx, "Settings##Popup")
    end
    if reaper.ImGui_BeginPopupModal(ctx, "Settings##Popup", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
      -- 收集切换
      reaper.ImGui_Text(ctx, "Audio file source:")
      local changed_collect_mode = false
      if reaper.ImGui_RadioButton(ctx, "From Items (Default)", collect_mode == COLLECT_MODE_ITEMS) then
        if collect_mode ~= COLLECT_MODE_ITEMS then changed_collect_mode = true end
        collect_mode = COLLECT_MODE_ITEMS
      end
      if reaper.ImGui_RadioButton(ctx, "From RPP (All in project state)", collect_mode == COLLECT_MODE_RPP) then
        if collect_mode ~= COLLECT_MODE_RPP then changed_collect_mode = true end
        collect_mode = COLLECT_MODE_RPP
      end
      if reaper.ImGui_RadioButton(ctx, "From Project Directory", collect_mode == COLLECT_MODE_DIR) then
        if collect_mode ~= COLLECT_MODE_DIR then changed_collect_mode = true end
        collect_mode = COLLECT_MODE_DIR
      end
      if changed_collect_mode then
        CollectFiles()
      end

      -- 更改速率是否保持音高
      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, "Playback settings:")
      local changed_pp
      changed_pp, preserve_pitch = reaper.ImGui_Checkbox(ctx, "Preserve pitch when changing rate", preserve_pitch)
      if changed_pp and playing_preview and reaper.CF_Preview_SetValue then
        reaper.CF_Preview_SetValue(playing_preview, "B_PPITCH", preserve_pitch and 1 or 0)
      end

      -- 关闭按钮
      reaper.ImGui_Separator(ctx)
      if reaper.ImGui_Button(ctx, "Close##Rate_close") then
        reaper.ImGui_CloseCurrentPopup(ctx)
      end
      reaper.ImGui_EndPopup(ctx)
    end
    
    -- 保持音高勾选项，代码备留
    -- reaper.ImGui_SameLine(ctx, nil, 10)
    -- local rv6
    -- rv6, preserve_pitch = reaper.ImGui_Checkbox(ctx, "Preserve pitch when changing rate", preserve_pitch)
    -- if rv6 and playing_preview and reaper.CF_Preview_SetValue then
    --   reaper.CF_Preview_SetValue(playing_preview, "B_PPITCH", preserve_pitch and 1 or 0)
    -- end

    -- 电平表通道选项
    -- reaper.ImGui_Separator(ctx)
    reaper.ImGui_SameLine(ctx, nil, 10)
    reaper.ImGui_SetNextItemWidth(ctx, -65)
    local rv5, new_peaks = reaper.ImGui_InputInt(ctx, 'Peaks', peak_chans, 1, 1)
    if rv5 then
      peak_chans = math.max(2, math.min(128, new_peaks or 2))
    end
    reaper.ImGui_SameLine(ctx)
    HelpMarker("Open settings to adjust playback and audio file collection options.\n\n" .. 
    "Audio file source modes:\n" ..
    "1. From Items (Default):\n" ..
    "   Only lists audio files actually used by items in the current project.\n" ..
    "2. From RPP (All in project state):\n" ..
    "   Lists all audio files referenced anywhere in the project file, including those not currently placed on tracks.\n" ..
    "3. From Project Directory:\n" ..
    "   Scans and lists all audio files in the project directory, whether or not they are used or referenced in the project.\n\n" ..
    "You can change file source and enable pitch preservation.")

    -- 进度条与时间显示，可拖动跳转
    local position, length = 0, 0
    
    if is_paused then
      -- 暂停时，始终显示paused_position
      position = paused_position
      if playing_source then
        local ok_len, len = reaper.CF_Preview_GetValue(playing_source, "D_LENGTH")
        if ok_len then length = len end
      end
    else
      -- 正常播放时，实时获取position和length
      if playing_preview and reaper.CF_Preview_GetValue then
        local ok_pos, pos = reaper.CF_Preview_GetValue(playing_preview, "D_POSITION")
        local ok_len, len = reaper.CF_Preview_GetValue(playing_preview, "D_LENGTH")
        if ok_pos then position = pos end
        if ok_len then length = len end
      end
    end
    -- 格式化时间标签
    local label = string.format("%s / %s", reaper.format_timestr(position, ""), reaper.format_timestr(length, ""))
    -- 大宽度进度条（铺满采用-FLT_MIN）
    reaper.ImGui_PushItemWidth(ctx, -FLT_MIN)
    local changed, want_pos = reaper.ImGui_SliderDouble(ctx, "##position", seek_pos or position, 0, length, label)
    reaper.ImGui_PopItemWidth(ctx)
    -- 拖动跳转逻辑，只有播放状态下才能跳转
    if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) and playing_preview and reaper.CF_Preview_SetValue and not is_paused then
      reaper.CF_Preview_SetValue(playing_preview, "D_POSITION", seek_pos)
      seek_pos = nil
    -- elseif changed then
    --   seek_pos = want_pos
    -- end
    elseif changed then
      if is_paused then
        paused_position = want_pos
      else
        seek_pos = want_pos
      end
    end

    -- 电平信号
    local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
    local spacing_x, spacing_h = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())
    local meter_h = math.max(spacing_h, ((avail_h + spacing_h) / peak_chans) - spacing_h)
    for i = 0, peak_chans - 1 do
      local valid, peak = false, 0
      if playing_preview and reaper.CF_Preview_GetPeak then
        valid, peak = reaper.CF_Preview_GetPeak(playing_preview, i)
      end
      reaper.ImGui_BeginDisabled(ctx, not valid)
      reaper.ImGui_ProgressBar(ctx, peak or 0, -FLT_MIN, meter_h, ' ')
      reaper.ImGui_EndDisabled(ctx)
    end

    -- 自动停止非Loop播放。只要没勾选Loop且快播完就自动Stop
    if playing_preview and not loop_enabled then
      local ok_pos, position = reaper.CF_Preview_GetValue(playing_preview, "D_POSITION")
      local ok_len, length   = reaper.CF_Preview_GetValue(playing_preview, "D_LENGTH")
      if ok_pos and ok_len and (length - position) < 0.03 then -- 距离结尾小于0.03秒
        StopPlay()
      end
    end

    reaper.ImGui_End(ctx)
  end
  reaper.ImGui_PopFont(ctx)
  if open then reaper.defer(loop) else StopPlay() end
end

reaper.defer(loop)
