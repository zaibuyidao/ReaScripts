-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"
script_path = script_path:gsub("[/\\]+$","")
script_path = script_path:gsub("[/\\]lib$","") -- 确保不在lib目录下

local sep = package.config:sub(1, 1)
script_path = script_path .. sep

-- 过滤音频文件
function IsValidAudioFile(path)
  local ext = path:match("%.([^.]+)$")
  if not ext then return false end
  ext = ext:lower()
  return (ext == "wav" or ext == "mp3" or ext == "flac" or ext == "ogg" or ext == "aiff" or ext == "ape" or ext == "wv" or ext == "m4a" or ext == "aac" or ext == "mp4")
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

-- 是否为有效的 PCM_source*
local function is_pcm_source(s)
  return s and reaper.ValidatePtr(s, "PCM_source*")
end

-- 旧版本备用，但不够严谨
-- function GetRootSource(src)
--   -- 过滤空对象／非 MediaSource*
--   if not src or not reaper.ValidatePtr(src, "MediaSource*") then
--     return nil
--   end
--   while reaper.GetMediaSourceType(src, "") == "SECTION" do
--     local parent = reaper.GetMediaSourceParent(src)
--     if not parent or not reaper.ValidatePtr(parent, "MediaSource*") then break end
--     src = parent
--   end
--   return src
-- end

function GetRootSource(src)
  if not is_pcm_source(src) then return nil end

  local s = src
  local guard = 0
  while true do
    local t = reaper.GetMediaSourceType(s, "") or ""

    -- 非音频源不支持 PCM 元数据
    if t == "MIDI" or t == "VIDEO" then
      return nil
    end

    local p = reaper.GetMediaSourceParent(s)
    if not is_pcm_source(p) then
      break -- 没有父节点，s 已是根
    end

    if t == "SECTION" or true then
      s = p
    end

    guard = guard + 1
    if guard > 16 then break end
  end
  return s
end

function GetMediaFileMetadataSafe(src, id)
  local root = GetRootSource(src) or src
  if not reaper.ValidatePtr(root, "PCM_source*") then
    return false, nil
  end
  return reaper.GetMediaFileMetadata(root, id)
end

-- UCS 标签读取
function get_ucstag(source, tag)
  if not source or not tag or tag == "" then return nil end

  -- 先检查ASWG
  local ok, val = GetMediaFileMetadataSafe(source, "ASWG:" .. tostring(tag))
  if ok and val and val ~= "" then
    return val
  end
  -- 再检查iXML
  local map = {
    category     = { "IXML:USER:CATEGORY" },
    catId        = { "IXML:USER:CATID" },
    subCategory  = { "IXML:USER:SUBCATEGORY" },
    categoryfull = { "IXML:USER:CATEGORYFULL" },
  }

  local ids = map[tostring(tag)] or {}
  for _, id in ipairs(ids) do
    ok, val = GetMediaFileMetadataSafe(source, id)
    if ok and val and val ~= "" then
      return val
    end
  end
  return nil
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

-- 收集单个音频文件元数据
function CollectFileInfo(path)
  local info = { path = path }
  do
    local f = io.open(path, "rb")
    if f then
      f:seek("end")
      info.size = f:seek()
      f:close()
    else
      info.size = 0
    end
  end

  local src = reaper.PCM_Source_CreateFromFile(path)
  if src then
    info.type       = reaper.GetMediaSourceType(src, "")
    info.length     = reaper.GetMediaSourceLength(src) or ""
    info.samplerate = reaper.GetMediaSourceSampleRate(src) or ""
    info.channels   = reaper.GetMediaSourceNumChannels(src) or ""
    info.bits       = reaper.CF_GetMediaSourceBitDepth and reaper.CF_GetMediaSourceBitDepth(src) or ""

    local function get_meta_first(ids)
      for _, id in ipairs(ids) do
        local ok, val = reaper.GetMediaFileMetadata(src, id)
        if ok and val and val ~= "" then return val end
      end
      return nil
    end

    local genre       = get_meta_first({ "XMP:dm/genre", "ID3:TCON", "VORBIS:GENRE", "RIFF:IGNR" })
    local comment     = get_meta_first({ "XMP:dm/logComment", "ID3:COMM", "VORBIS:COMMENT", "RIFF:ICMT" })
    local description = get_meta_first({ "BWF:Description", "RIFF:IDESC", "RIFF:ICMT" })
    local orig_date   = get_meta_first({ "BWF:OriginationDate", "XMP:xmp/CreateDate", "ID3:TDRC", "VORBIS:DATE", "RIFF:ICRD" })

    info.genre         = genre or ""
    info.comment       = comment or ""
    info.description   = description or ""
    info.bwf_orig_date = orig_date or ""

    info.ucs_category    = get_ucstag and get_ucstag(src, "category")    or ""
    info.ucs_catid       = get_ucstag and get_ucstag(src, "catId")       or ""
    info.ucs_subcategory = get_ucstag and get_ucstag(src, "subCategory") or ""

    local bpm_str = get_meta_first({ "XMP:dm/tempo", "ID3:TBPM", "VORBIS:BPM", "RIFF:ACID:tempo" })
    local bpm = bpm_str and tonumber(bpm_str) or nil
    if not bpm then
      local fn = path:match("[^/\\]+$") or path
      local m = fn:match("(%d+)%s*[bB][pP][mM]") or fn:match("[_-](%d+)[_-]?BPM")
      bpm = m and tonumber(m) or nil
    end
    info.bpm = bpm or ""

    local key_str = get_meta_first({ "XMP:dm/key", "ID3:TKEY", "RIFF:IKEY", "VORBIS:KEY", "RIFF:ACID:key" })

    local function normalize_key(s)
      if not s or s == "" then return "" end
      s = s:gsub("%s+", ""):gsub("♯", "#"):gsub("♭", "b")
      s = s:gsub("[Mm][Ii][Nn][Oo]?[Rr]?$", "m")
      local root, accidental, minor = s:match("^([A-Ga-g])([#b]?)(m?)$")
      if root then
        return string.upper(root) .. accidental .. minor
      end
      return string.upper(s)
    end

    if key_str and key_str ~= "" then
      info.key = normalize_key(key_str)
    else
      local fn = path:match("[^/\\]+$") or path
      local k = fn:match("%f[%a]([A-Ga-g][#b♯♭]?%s*[Mm][Ii]?[Nn]?[Oo]?[Rr]?)%f[^%a]") or fn:match("%f[%a]([A-Ga-g][#b♯♭]?m)%f[^%a]") or fn:match("%f[%a]([A-Ga-g][#b♯♭]?)%f[^%a]")
      info.key = k and normalize_key(k) or ""
    end

    reaper.PCM_Source_Destroy(src)
  end

  info.filename = path:match("[^/\\]+$") or path
  return info
end

function quote_if_space(str)
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

-- t:[Metadata]Title       or [ASWG tags]songTitle      or [Cues]001 0:00.000
-- a:[Metadata]Artist      or [ID3 tags]TPE1            or [IXML tags]USER:ARTIST
-- b:[Metadata]Album       or [ASWG tags]library        or [ID3 tags]TOWN         or [ID3 tags]TPE2
-- y:[Metadata]Date        or [BWF tags]OriginationDate
-- g:[Metadata]Genre       or [XMP tags]dm/genre        or [ID3 tags]TCON
-- c:[Metadata]Comment     or [ID3 tags]COMM

-- d:[Metadata]Description or [BWF tags]Description     or [XMP tags]dc/description
-- U:Custom Tags
-- s:Sample rate
-- n:Channel
-- r:Offset
-- l:Length
-- i:Bits
-- m:Track #
-- j:[ID3 tags]APIC: mime:image/jpeg offset:86662062 length:93146

-- k:[Metadata]Key         or [ID3 tags]TKEY or [XMP tags]dm/key
-- p:[Metadata]MPM         or [ID3 tags]TBPM or [XMP tags]dm/tempo
-- Category:[ASWG tags]category       or [IXML tags]USER:CATEGORY
-- CatID:[ASWG tags]catId             or [IXML tags]USER:CATID
-- SubCategory:[ASWG tags]subCategory or [IXML tags]USER:SUBCATEGORY

function WriteToMediaDB(info, dbfile, root_path)
  local f = io.open(dbfile, "a+b")
  if not f then return end
  -- FILE行
  f:write(('FILE "%s" %d 0 0 0\n'):format(info.path, info.size))
  -- DATA基本属性行
  -- f:write(('DATA %s l:%s n:%s s:%s i:%s\n'):format(quote_if_space('y:' .. (info.bwf_orig_date or "")), info.length or "", info.channels or "", info.samplerate or "", info.bits or ""))
  f:write(('DATA %sl:%s n:%s s:%s i:%s\n'):format(
    (info.bwf_orig_date and info.bwf_orig_date ~= "") and (quote_if_space('y:' .. (info.bwf_orig_date))..' ') or '',
    info.length or "", info.channels or "", info.samplerate or "", info.bits or ""
  ))

  -- DATA类别行
  local ucs = {}
  if info.genre and info.genre ~= "" then table.insert(ucs, quote_if_space('g:' .. info.genre)) end
  if info.key and info.key ~= "" then table.insert(ucs, quote_if_space('k:' .. info.key)) end
  if info.bpm and tostring(info.bpm) ~= "" then table.insert(ucs, quote_if_space('p:' .. tostring(info.bpm))) end
  if info.ucs_category ~= "" then table.insert(ucs, quote_if_space('category:' .. info.ucs_category)) end
  if info.ucs_subcategory ~= "" then table.insert(ucs, quote_if_space('subcategory:' .. info.ucs_subcategory)) end
  if info.ucs_catid ~= "" then table.insert(ucs, quote_if_space('catid:' .. info.ucs_catid)) end
  if #ucs > 0 then f:write('DATA ' .. table.concat(ucs, " ") .. '\n') end
  -- DATA描述行
  local desc = {}
  if info.comment and info.comment ~= "" then table.insert(desc, quote_if_space('c:' .. info.comment)) end
  if info.description and info.description ~= "" then table.insert(desc, quote_if_space('d:' .. info.description)) end
  if #desc > 0 then f:write('DATA ' .. table.concat(desc, ' ') .. '\n') end
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

function parse_len_to_seconds(s) -- 支持 1:23:45.678 / 0:38.112 / 12.34
  if not s or s == "" then return nil end
  local h, m, sec = s:match("^(%d+):(%d+):([%d%.]+)$")
  if h then return tonumber(h)*3600 + tonumber(m)*60 + tonumber(sec) end
  local mm, ss = s:match("^(%d+):([%d%.]+)$")
  if mm then return tonumber(mm)*60 + tonumber(ss) end
  local n = s:match("^([%d%.]+)$")
  if n then return tonumber(n) end
  return nil
end

function ParseMediaDBFile(dbpath)
  local entries = {}
  local f = io.open(dbpath, "rb")
  if not f then return entries end

  local entry = {}
  for raw in f:lines() do
    local line = (raw or ""):gsub("\r","")
    if line:sub(1,3) == "\239\187\191" then line = line:sub(4) end
    if line:find("^FILE") then
      if entry.path then table.insert(entries, entry) end
      entry = {}
      -- REAPER格式 FILE "path" size 0 mtime 0，当前仅取 path + size，其他数值忽略
      entry.path, entry.size = line:match('^FILE%s+"(.-)"%s+(%d+)%s+%d+%s+%d+%s+%d+$')
      if not entry.path then
        -- 兼容旧格式 FILE "path" size type
        entry.path, entry.size, entry.type = line:match('^FILE%s+"(.-)"%s+(%d+)%s+(%S+)$')
      end
      entry.size = tonumber(entry.size) or 0
      if entry.path then
        entry.filename = entry.path:match("([^/\\]+)$") or entry.path
      else
        entry.filename = ""
      end

    elseif line:find("^DATA") then
      -- g / k / p
      do
        local v = line:match('"[Gg]:([^"]-)"') or line:match('[Gg]:"([^"]-)"') or line:match('[Gg]:([^%s"]+)')
        if v and v ~= "" then entry.genre = v end
      end
      do
        local v = line:match('"[Kk]:([^"]-)"') or line:match('[Kk]:"([^"]-)"') or line:match('[Kk]:([^%s"]+)')
        if v and v ~= "" then entry.key = v end
      end
      do
        local v = line:match('"[Pp]:([%d%.]+)"') or line:match('[Pp]:"([%d%.]+)"') or line:match('[Pp]:([%d%.]+)')
        if v and v ~= "" then entry.bpm = tonumber(v) or entry.bpm or 0 end
      end
      -- UCS
      do
        local v = line:match('"category:([^"]-)"') or line:match('category:"([^"]-)"') or line:match('category:([^%s"]+)')
        if v and v ~= "" then entry.ucs_category = v end
      end
      do
        local v = line:match('"subcategory:([^"]-)"') or line:match('subcategory:"([^"]-)"') or line:match('subcategory:([^%s"]+)')
        if v and v ~= "" then entry.ucs_subcategory = v end
      end
      do
        local v = line:match('"catid:([^"]-)"') or line:match('catid:"([^"]-)"') or line:match('catid:([^%s"]+)')
        if v and v ~= "" then entry.ucs_catid = v end
      end
      -- c / d
      do
        local v = line:match('"[Cc]:([^"]-)"') or line:match('[Cc]:"([^"]-)"') or line:match('[Cc]:([^%s"]+)')
        if v and v ~= "" then entry.comment = v end
      end
      do
        local v = line:match('"[Dd]:([^"]-)"') or line:match('[Dd]:"([^"]-)"') or line:match('[Dd]:([^%s"]+)')
        if v and v ~= "" then entry.description = v end
      end
      -- y / l / n / s / i
      do
        local v = line:match('"[Yy]:([^"]-)"') or line:match('[Yy]:"([^"]-)"') or line:match('[Yy]:([%d%-]+)')
        if v and v ~= "" then entry.bwf_orig_date = v end
      end
      do
        local raw = line:match('"[Ll]:([^"]-)"') or line:match('[Ll]:"([^"]-)"') or line:match('[Ll]:([%d:%.]+)')
        local secs = parse_len_to_seconds(raw)
        if secs then entry.length = secs end
      end
      do
        local v = line:match('"[Nn]:([^"]-)"') or line:match('[Nn]:"([^"]-)"') or line:match('[Nn]:(%d+)')
        if v and v ~= "" then entry.channels = tonumber(v) or entry.channels or 0 end
      end
      do
        local v = line:match('"[Ss]:([^"]-)"') or line:match('[Ss]:"([^"]-)"') or line:match('[Ss]:(%d+)')
        if v and v ~= "" then entry.samplerate = tonumber(v) or entry.samplerate or 0 end
      end
      do
        local v = line:match('"[Ii]:([^"]-)"') or line:match('[Ii]:"([^"]-)"') or line:match('[Ii]:(%d+)')
        if v and v ~= "" then entry.bits = tonumber(v) or entry.bits or 0 end
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

function LoadAudioToRS5k(track, path)
  if not path or path == "" then return end
  reaper.PreventUIRefresh(1)

  local insert_idx = reaper.CountTracks(0)
  if track and reaper.ValidatePtr(track, "MediaTrack*") then
    local tn = tonumber(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")) or 0
    if tn > 0 then insert_idx = math.floor(tn) end
  end

  reaper.InsertTrackAtIndex(insert_idx, true)
  local new_tr = reaper.GetTrack(0, insert_idx)
  if not new_tr then
    reaper.PreventUIRefresh(-1)
    return
  end
  -- 轨道命名为文件名
  local basename = (path:match("([^/\\]+)$") or "Sample"):gsub("%.%w+$", "")
  reaper.GetSetMediaTrackInfo_String(new_tr, "P_NAME", basename, true)

  -- 添加RS5K
  local fx = reaper.TrackFX_AddByName(new_tr, "ReaSamplomatic5000 (Cockos)", false, 1)
  if fx < 0 then
    fx = reaper.TrackFX_AddByName(new_tr, "VSTi: ReaSamplomatic5000 (Cockos)", false, 1)
  end
  -- 载入样本到RS5K第0槽
  reaper.TrackFX_SetNamedConfigParm(new_tr, fx, "FILE0", path)
  -- reaper.TrackFX_SetOpen(new_tr, fx, true)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end

function FindRS5KOnTrack(track)
  local fx_count = reaper.TrackFX_GetCount(track)
  for i = 0, fx_count - 1 do
    local _, name = reaper.TrackFX_GetFXName(track, i, "")
    if name:find("RS5K", 1, true) then
      return i
    end
  end
  return -1
end

-- 将当前样本加入已有RS5K，并设为活跃槽
function LoadOnlySelectedToRS5k(track, path)
  if not track or not path or path == "" then return end
  reaper.PreventUIRefresh(1)
  local fx = FindRS5KOnTrack(track)
  if fx == -1 then reaper.PreventUIRefresh(-1) return end
  -- 载入样本到RS5K第0槽
  reaper.TrackFX_SetNamedConfigParm(track, fx, "FILE0", path)
  reaper.TrackFX_SetOpen(track, fx, true)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end

--------------------------------------------- 数据库模式加载优化 ---------------------------------------------

-- 解析DATA到entry
function _apply_data_line(entry, line)
  -- g / k / p
  do
    local v = line:match('"[Gg]:([^"]-)"') or line:match('[Gg]:"([^"]-)"') or line:match('[Gg]:([^%s"]+)')
  if v and v ~= "" then entry.genre = v end
    if v and v ~= "" then entry.genre = v end
  end
  do
    local v = line:match('"[Kk]:([^"]-)"') or line:match('[Kk]:"([^"]-)"') or line:match('[Kk]:([^%s"]+)')
    if v and v ~= "" then entry.key = v end
  end
  do
    local v = line:match('"[Pp]:([%d%.]+)"') or line:match('[Pp]:"([%d%.]+)"') or line:match('[Pp]:([%d%.]+)')
    if v and v ~= "" then entry.bpm = tonumber(v) or entry.bpm or 0 end
  end
  -- UCS
  do
    local v = line:match('"category:([^"]-)"') or line:match('category:"([^"]-)"') or line:match('category:([^%s"]+)')
    if v and v ~= "" then entry.ucs_category = v end
  end
  do
    local v = line:match('"subcategory:([^"]-)"') or line:match('subcategory:"([^"]-)"') or line:match('subcategory:([^%s"]+)')
    if v and v ~= "" then entry.ucs_subcategory = v end
  end
  do
    local v = line:match('"catid:([^"]-)"') or line:match('catid:"([^"]-)"') or line:match('catid:([^%s"]+)')
    if v and v ~= "" then entry.ucs_catid = v end
  end
  -- c / d
  do
    local v = line:match('"[Cc]:([^"]-)"') or line:match('[Cc]:"([^"]-)"') or line:match('[Cc]:([^%s"]+)')
    if v and v ~= "" then entry.comment = v end
  end
  do
    local v = line:match('"[Dd]:([^"]-)"') or line:match('[Dd]:"([^"]-)"') or line:match('[Dd]:([^%s"]+)')
    if v and v ~= "" then entry.description = v end
  end
  -- y / l / n / s / i
  do
    local v = line:match('"[Yy]:([^"]-)"') or line:match('[Yy]:"([^"]-)"') or line:match('[Yy]:([%d%-]+)')
    if v and v ~= "" then entry.bwf_orig_date = v end
  end
  do
    local raw = line:match('"[Ll]:([^"]-)"') or line:match('[Ll]:"([^"]-)"') or line:match('[Ll]:([%d:%.]+)')
    local secs = parse_len_to_seconds(raw)
    if secs then entry.length = secs end
  end
  do
    local v = line:match('"[Nn]:([^"]-)"') or line:match('[Nn]:"([^"]-)"') or line:match('[Nn]:(%d+)')
    if v and v ~= "" then entry.channels = tonumber(v) or entry.channels or 0 end
  end
  do
    local v = line:match('"[Ss]:([^"]-)"') or line:match('[Ss]:"([^"]-)"') or line:match('[Ss]:(%d+)')
    if v and v ~= "" then entry.samplerate = tonumber(v) or entry.samplerate or 0 end
  end
  do
    local v = line:match('"[Ii]:([^"]-)"') or line:match('[Ii]:"([^"]-)"') or line:match('[Ii]:(%d+)')
    if v and v ~= "" then entry.bits = tonumber(v) or entry.bits or 0 end
  end
end

-- 开启流式读取
function MediaDBStreamStart(dbpath, opts)
  local f = io.open(dbpath, "rb")
  if not f then return nil end
  return { f = f, eof = false, entry = nil, dbpath = dbpath, opts = opts or { lazy_data = true } }
end

-- 流式读取MediaDB，每次返回最多max_count条记录
function MediaDBStreamRead(stream, max_count)
  local out = {}
  local s = stream
  if not s or not s.f then return out end
  local f = s.f
  local added = 0
  local entry = s.entry or {}
  local lazy = not (s.opts and s.opts.lazy_data == false) -- 默认懒解析
  local eager = (s.opts and s.opts.eager_tags) or nil     -- 需要优先解析的DATA键集合

  while added < (max_count or 1000) do
    local raw = f:read("*l")
    if not raw then
      if entry.path then table.insert(out, entry) end
      s.entry = nil
      s.eof = true
      break
    end

    local line = (raw or ""):gsub("\r","")
    if #line >= 3 and line:sub(1,3) == "\239\187\191" then line = line:sub(4) end -- strip BOM

    if line:find("^FILE") then
      -- 推入上一条
      if entry.path then
        table.insert(out, entry)
        added = added + 1
        if added >= (max_count or 1000) then
          local new_path, new_size = line:match('^FILE%s+"(.-)"%s+(%d+)')
          entry = { path = new_path, size = tonumber(new_size) or 0, filename = new_path and (new_path:match("([^/\\]+)$") or new_path) or "" }
          s.entry = entry
          break
        end
      end

      entry = {}
      entry.path, entry.size = line:match('^FILE%s+"(.-)"%s+(%d+)%s+%d+%s+%d+%s+%d+$')
      if not entry.path then
        entry.path, entry.size = line:match('^FILE%s+"(.-)"%s+(%d+)%s*')
      end
      entry.size = tonumber(entry.size) or 0
      entry.filename = entry.path and (entry.path:match("([^/\\]+)$") or entry.path) or ""

    elseif line:find("^DATA") then
      if lazy then
        -- 只解析用户勾选的键，其余走懒加载。后续可 EnsureEntryParsed 全量解析
        if eager then
          if eager.g then
            local v = line:match('"[Gg]:([^"]-)"') or line:match('[Gg]:"([^"]-)"') or line:match('[Gg]:([^%s"]+)')
            if v and v ~= "" then entry.genre = v end
          end
          if eager.k then
            local v = line:match('"[Kk]:([^"]-)"') or line:match('[Kk]:"([^"]-)"') or line:match('[Kk]:([^%s"]+)')
            if v and v ~= "" then entry.key = v end
          end
          if eager.p then
            local v = line:match('"[Pp]:([%d%.]+)"') or line:match('[Pp]:"([%d%.]+)"') or line:match('[Pp]:([%d%.]+)')
            if v and v ~= "" then entry.bpm = tonumber(v) or entry.bpm or 0 end
          end
          if eager.category then
            local v = line:match('"category:([^"]-)"') or line:match('category:"([^"]-)"') or line:match('category:([^%s"]+)')
            if v and v ~= "" then entry.ucs_category = v end
          end
          if eager.subcategory then
            local v = line:match('"subcategory:([^"]-)"') or line:match('subcategory:"([^"]-)"') or line:match('subcategory:([^%s"]+)')
            if v and v ~= "" then entry.ucs_subcategory = v end
          end
          if eager.catid then
            local v = line:match('"catid:([^"]-)"') or line:match('catid:"([^"]-)"') or line:match('catid:([^%s"]+)')
            if v and v ~= "" then entry.ucs_catid = v end
          end
          if eager.c then
            local v = line:match('"[Cc]:([^"]-)"') or line:match('[Cc]:"([^"]-)"') or line:match('[Cc]:([^%s"]+)')
            if v and v ~= "" then entry.comment = v end
          end
          if eager.d then
            local v = line:match('"[Dd]:([^"]-)"') or line:match('[Dd]:"([^"]-)"') or line:match('[Dd]:([^%s"]+)')
            if v and v ~= "" then entry.description = v end
          end
          if eager.y then
            local v = line:match('"[Yy]:([^"]-)"') or line:match('[Yy]:"([^"]-)"') or line:match('[Yy]:([%d%-]+)')
            if v and v ~= "" then entry.bwf_orig_date = v end
          end
          if eager.l then
            local raw_len = line:match('"[Ll]:([^"]-)"') or line:match('[Ll]:"([^"]-)"') or line:match('[Ll]:([%d:%.]+)')
            local secs = parse_len_to_seconds(raw_len)
            if secs then entry.length = secs end
          end
          if eager.n then
            local v = line:match('"[Nn]:([^"]-)"') or line:match('[Nn]:"([^"]-)"') or line:match('[Nn]:(%d+)')
            if v and v ~= "" then entry.channels = tonumber(v) or entry.channels or 0 end
          end
          if eager.s then
            local v = line:match('"[Ss]:([^"]-)"') or line:match('[Ss]:"([^"]-)"') or line:match('[Ss]:(%d+)')
            if v and v ~= "" then entry.samplerate = tonumber(v) or entry.samplerate or 0 end
          end
          if eager.i then
            local v = line:match('"[Ii]:([^"]-)"') or line:match('[Ii]:"([^"]-)"') or line:match('[Ii]:(%d+)')
            if v and v ~= "" then entry.bits = tonumber(v) or entry.bits or 0 end
          end
        end
        -- 保存原始 DATA 行，供后续 EnsureEntryParsed 做完整解析
        entry._data_lines = entry._data_lines or {}
        entry._data_lines[#entry._data_lines + 1] = line
      else
        -- 非懒解析，直接全量解析
        _apply_data_line(entry, line)
      end
    end
  end

  s.entry = entry
  return out
end

function MediaDBStreamClose(stream)
  if stream and stream.f then stream.f:close() end
end

-- 可见时一次性解析 DATA 行
function EnsureEntryParsed(entry)
  if not entry or entry._parsed then return end
  local lines = entry._data_lines
  if lines then
    for i = 1, #lines do _apply_data_line(entry, lines[i]) end
    entry._data_lines = nil
  end
  entry._parsed = true
end