-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"

local sep = package.config:sub(1, 1)

-- 过滤音频文件
function IsValidAudioFile(path)
  local ext = path:match("%.([^.]+)$")
  if not ext then return false end
  ext = ext:lower()
  return (ext == "wav" or ext == "mp3" or ext == "flac" or ext == "ogg" or ext == "aiff" or ext == "ape" or ext == "wv")
end

function split(str, sep)
  local result = {}
  local plain = true
  local start = 1
  local sep_start, sep_end = string.find(str, sep, start, plain)
  while sep_start do
    table.insert(result, string.sub(str, start, sep_start - 1))
    start = sep_end + 1
    sep_start, sep_end = string.find(str, sep, start, plain)
  end
  table.insert(result, string.sub(str, start))
  return result
end

--------------------------------------------- 保存搜索关键词 ---------------------------------------------

function LoadSavedSearch(EXT_SECTION, saved_search_list)
  saved_search_list = saved_search_list or {}
  local str = reaper.GetExtState(EXT_SECTION, "saved_search_list")
  if not str or str == "" then return saved_search_list end
  local list = split(str, "|;|")
  for _, item in ipairs(list) do
    local name, keyword = item:match("^(.-)%|%|(.*)$")
    if name and name ~= "" then
      table.insert(saved_search_list, {name = name, keyword = keyword})
    end
  end
  return saved_search_list
end

function SaveSavedSearch(EXT_SECTION, saved_search_list)
  local t = {}
  for _, info in ipairs(saved_search_list) do
    -- 防止分隔符串进数据里，建议做简单过滤
    local name = (info.name or ""):gsub("|;|", ""):gsub("||", "")
    local keyword = (info.keyword or ""):gsub("|;|", ""):gsub("||", "")
    table.insert(t, name .. "||" .. keyword)
  end
  local str = table.concat(t, "|;|")
  reaper.SetExtState(EXT_SECTION, "saved_search_list", str, true)
end

-- UCS 标签
function get_ucstag(source, tag)
  if not source then return end
  local _, val = reaper.GetMediaFileMetadata(source, "ASWG:" .. tag)
  if not val or val == "" then return end
  return val
end

--------------------------------------------- 数据库 ---------------------------------------------

mediadb_alias = mediadb_alias or {}

function SaveMediaDBAlias(EXT_SECTION, mediadb_alias)
  mediadb_alias = mediadb_alias or {}
  local t = {}
  for filename, alias in pairs(mediadb_alias) do
    filename = (filename or ""):gsub("|;|", ""):gsub("||", "")
    alias = (alias or ""):gsub("|;|", ""):gsub("||", "")
    table.insert(t, filename .. "||" .. alias)
  end
  local str = table.concat(t, "|;|") or ""
  reaper.SetExtState(EXT_SECTION, "moledb_alias", str, true)
end

function LoadMediaDBAlias(EXT_SECTION)
  local alias_map = {}
  local str = reaper.GetExtState(EXT_SECTION, "moledb_alias")
  if not str or str == "" then return alias_map end
  for _, item in ipairs(split(str, "|;|")) do
    local filename, alias = item:match("^(.-)%|%|(.*)$")
    if filename and filename ~= "" then
      alias_map[filename] = alias
    end
  end
  return alias_map
end

-- 递归扫描目录下所有音频文件
function ScanAllAudioFiles(root_dir)
  local files = {}
  local sep = package.config:sub(1,1)
  local function scan(dir)
    -- 文件
    local i = 0
    while true do
      local file = reaper.EnumerateFiles(dir, i)
      if not file then break end
      local fullpath = dir .. sep .. file
      if IsValidAudioFile(fullpath) then
        table.insert(files, normalize_path(fullpath, false))
      end
      i = i + 1
    end
    -- 子目录
    local j = 0
    while true do
      local sub = reaper.EnumerateSubdirectories(dir, j)
      if not sub then break end
      scan(dir .. sep .. sub)
      j = j + 1
    end
  end
  scan(normalize_path(root_dir, false))
  return files, #files
end

-- 采集全部元数据
function CollectFileInfo(path)
  local info = { path = path }
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
    info.type = reaper.GetMediaSourceType(src, "")
    info.length = reaper.GetMediaSourceLength(src) or ""
    info.samplerate = reaper.GetMediaSourceSampleRate(src) or ""
    info.channels = reaper.GetMediaSourceNumChannels(src) or ""
    info.bits = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(src) or ""
    local _, genre = reaper.GetMediaFileMetadata(src, "XMP:dm/genre")
    local _, comment = reaper.GetMediaFileMetadata(src, "XMP:dm/logComment")
    local _, description = reaper.GetMediaFileMetadata(src, "BWF:Description")
    local _, orig_date  = reaper.GetMediaFileMetadata(src, "BWF:OriginationDate")
    info.genre = genre or ""
    info.comment = comment or ""
    info.description = description or ""
    info.bwf_orig_date = orig_date or ""
    info.ucs_category    = get_ucstag and get_ucstag(src, "category") or ""
    info.ucs_catid       = get_ucstag and get_ucstag(src, "catId") or ""
    info.ucs_subcategory = get_ucstag and get_ucstag(src, "subCategory") or ""
    reaper.PCM_Source_Destroy(src)
  end
  info.filename = path:match("[^/\\]+$") or path
  return info
end

local function quote_if_space(str)
  if str:find("%s") then
    return '"' .. str .. '"'
  else
    return str
  end
end

function AddPathToDBFile(dbfile, new_path)
  local lines = {}
  for line in io.lines(dbfile) do table.insert(lines, line) end
  local already_exist = false
  for _, l in ipairs(lines) do
    if l:match('^PATH%s+"(.-)"') == new_path then
      already_exist = true
      break
    end
  end
  if not already_exist then
    -- 最顶部插入
    table.insert(lines, 1, ('PATH "%s"'):format(new_path))
    -- 写回
    local f = io.open(dbfile, "wb")
    for _, l in ipairs(lines) do f:write(l, "\n") end
    f:close()
  end
end

function WriteToMediaDB(info, dbfile, root_path)
  local f = io.open(dbfile, "a+b")
  if not f then return end
  -- FILE行
  f:write(('FILE "%s" %d %s\n'):format(info.path, info.size, info.type))
  -- DATA基本属性行
  f:write(('DATA z:%d y:%s l:%s n:%s s:%s i:%s\n'):format(
    info.size or 0, info.bwf_orig_date or "", info.length or "", info.channels or "", info.samplerate or "", info.bits or ""
  ))
  -- DATA类别行
  local ucs = {}
  if info.genre ~= "" then table.insert(ucs, 'g:' .. quote_if_space(info.genre)) end
  if info.ucs_category ~= "" then table.insert(ucs, 't:' .. quote_if_space(info.ucs_category)) end
  if info.ucs_subcategory ~= "" then table.insert(ucs, 'u:' .. quote_if_space(info.ucs_subcategory)) end
  if info.ucs_catid ~= "" then table.insert(ucs, 'a:' .. quote_if_space(info.ucs_catid)) end
  if #ucs > 0 then f:write('DATA ' .. table.concat(ucs, " ") .. '\n') end
  -- DATA描述行
  if info.comment ~= "" or info.description ~= "" then
    f:write(('DATA c:"%s" d:"%s"\n'):format(info.comment or "", info.description or ""))
  end
  f:close()
end

-- 获取下一个可用编号
function GetNextMediaDBIndex(db_dir)
  local max_index = -1
  for i = 0, 255 do
    local prefix = ("%02x"):format(i)
    local dbfile = string.format("%s/%s.MoleFileList", db_dir, prefix)
    local f = io.open(dbfile, "rb")
    if f then
      max_index = i
      f:close()
    end
  end
  return ("%02x"):format(max_index + 1)
end

function BuildMediaDB(root_dir, db_dir)
  local filelist = ScanAllAudioFiles(root_dir)
  local db_index = GetNextMediaDBIndex(db_dir) -- 例如"00"
  local dbfile = string.format("%s/%s.MoleFileList", db_dir, db_index)
  for _, path in ipairs(filelist) do
    local info = CollectFileInfo(path)
    WriteToMediaDB(info, dbfile)
  end
end

function ParseMediaDBFile(dbpath)
  local entries = {}
  local f = io.open(dbpath, "rb")
  if not f then return entries end
  local entry = {}
  for line in f:lines() do
    if line:find("^FILE") then
      if entry.path then table.insert(entries, entry) end
      entry = {}
      entry.path, entry.size, entry.type = line:match('^FILE%s+"(.-)"%s+(%d+)%s+(%S+)$')
      entry.size = tonumber(entry.size) or 0
      if entry.path then
        entry.filename = entry.path:match("([^/\\]+)$") or entry.path
      else
        entry.filename = ""
      end
    elseif line:find("^DATA") then
      -- 分类行
      if line:find("g:") or line:find("t:") or line:find("u:") or line:find("a:") then
        local gq = line:match('g:"(.-)"')
        entry.genre = gq or line:match('g:([^%s]+)') or ""
        local tq = line:match('t:"(.-)"')
        entry.ucs_category = tq or line:match('t:([^%s]+)') or ""
        local uq = line:match('u:"(.-)"')
        entry.ucs_subcategory = uq or line:match('u:([^%s]+)') or ""
        local aq = line:match('a:"(.-)"')
        entry.ucs_catid = aq or line:match('a:([^%s]+)') or ""
      -- 描述行
      elseif line:find('c:') or line:find('d:') then
        entry.comment = line:match('c:"(.-)"') or ""
        entry.description = line:match('d:"(.-)"') or ""
      else
        -- 属性行
        entry.bwf_orig_date = line:match('y:([%d%-]+)') or ""
        entry.length = tonumber(line:match('l:([%d%.]+)')) or 0
        entry.channels = tonumber(line:match('n:(%d+)')) or 0
        entry.samplerate = tonumber(line:match('s:(%d+)')) or 0
        entry.bits = tonumber(line:match('i:(%d+)')) or 0
      end
      entry.data = entry.data or {}
      table.insert(entry.data, line)
    end
  end
  if entry.path then table.insert(entries, entry) end
  f:close()
  return entries
end

function RemoveFromMediaDB(path, dbfile)
  local tmp = {}
  local keep = true
  for line in io.lines(dbfile) do
    -- 当遇到 FILE 行且路径匹配时，切换到跳过状态
    if line:match('^FILE%s+"(.-)"') == path then
      keep = false
    elseif line:find("^FILE") then
      keep = true
    end
    if keep then table.insert(tmp, line) end
  end
  -- 写回文件
  local f = io.open(dbfile, "wb")
  for _, l in ipairs(tmp) do f:write(l, "\n") end
  f:close()
end

-- 获取数据库路径列表
function GetPathListFromDB(dbpath)
  local paths = {}
  for line in io.lines(dbpath) do
    local path = line:match('^PATH%s+"(.-)"')
    if path then table.insert(paths, path) end
  end
  return paths
end

--------------------------------------------- RS5K ---------------------------------------------

function GetOrCreateRS5k(track)
  if not track then return nil end
  local cnt = reaper.TrackFX_GetCount(track)
  for i = 0, cnt-1 do
    local _, name = reaper.TrackFX_GetFXName(track, i, "")
    if name:find("RS5K") then
      return i
    end
  end
  return reaper.TrackFX_AddByName(track, "ReaSamplOmatic5000 (Cockos)", false, 1)
end

-- 往选中轨道的 RS5k 依次添加样本
function LoadAudioToRS5k(track, path)
  if not track or not path or path == "" then return end
  local fx = GetOrCreateRS5k(track)
  if not fx or fx < 0 then return end
  -- 找第一个空槽，最多16槽
  local slot = 0
  while slot < 16 do
    local param = ("FILE%d"):format(slot)
    local val = reaper.TrackFX_GetNamedConfigParm(track, fx, param)
    if not val or val == "" then break end
    slot = slot + 1
  end

  if slot >= 16 then
    reaper.ShowMessageBox("RS5k sample slots full", "Warning", 0)
  else
    local param = ("FILE%d"):format(slot)
    reaper.TrackFX_SetNamedConfigParm(track, fx, param, path)
    reaper.TrackFX_SetOpen(track, fx, true)
  end
end
