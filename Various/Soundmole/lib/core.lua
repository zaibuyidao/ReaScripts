-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"
script_path = script_path:gsub("[/\\]+$","")
script_path = script_path:gsub("[/\\]lib$","") -- 确保不在lib目录下

local sep = package.config:sub(1, 1)
script_path = script_path .. sep

local HAVE_SM_EXT = reaper.APIExists('SM_ProbeMediaBegin') and reaper.APIExists('SM_ProbeMediaNextJSONEx') and reaper.APIExists('SM_ProbeMediaEnd') and reaper.APIExists('SM_GetPeaksCSV')

-- 过滤音频文件，与has_allowed_ext(p)重复
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

function get_meta_first(src, ids)
  for _, id in ipairs(ids) do
    local ok, val = GetMediaFileMetadataSafe(src, id)
    if ok and val and val ~= "" then return val end
  end
  return nil
end

function normalize_key(s)
  if not s or s == "" then return "" end
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  s = s:gsub("%s+", ""):gsub("♯", "#"):gsub("♭", "b")
  s = s:gsub("[Mm][Ii]?[Nn]?[Oo]?[Rr]$", "m")
  local root, accidental, minor = s:match("^([A-Ga-g])([#b]?)(m?)$")
  if root then return string.upper(root) .. accidental .. minor end
  return string.upper(s)
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
  -- 扩展可用
  local have_sm = reaper.APIExists("SM_ListDirBegin") and reaper.APIExists("SM_ListDirNextJSON") and reaper.APIExists("SM_ListDirEnd")
  if have_sm and root_dir and root_dir ~= "" then
    local files = {}
    local count = 0
    local exts_csv = "wav,mp3,flac,ogg,aif,aiff,ape,wv,m4a,aac,mp4"

    local function json_unescape_min(s)
      if not s then return s end
      s = s:gsub("\\\\","\\"):gsub('\\"','"'):gsub("\\n","\n"):gsub("\\r","\r"):gsub("\\t","\t")
      return s
    end

    local root = normalize_path(root_dir, false)
    local h = reaper.SM_ListDirBegin(root, 1, exts_csv)
    if not h then
      return {}, 0
    end

    local BATCH = 20000

    while true do
      local nd = reaper.SM_ListDirNextJSON(h, BATCH)
      if not nd or nd == "" then
        break
      end
      if nd ~= "\n" then
        for line in nd:gmatch("[^\r\n]+") do
          local p = line:match([["path"%s*:%s*"([^"]+)]])
          if p then
            p = json_unescape_min(p)
            p = normalize_path(p, false)
            if IsValidAudioFile(p) then
              files[#files+1] = p
              count = count + 1
            end
          end
        end
      end
      reaper.defer(function() end)
    end

    reaper.SM_ListDirEnd(h)
    return files, count
  end

  -- 回退到旧逻辑
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

--------------------------------------------- 读取文件/item/take元数据相关 ---------------------------------------------

-- 用于 Soundmole 扩展探测元数据的共享构建器
function SM_BuildFileInfoFromProbeMeta(path, meta, opts)
  opts = opts or {}
  meta = meta or {}

  local fullpath = normalize_path((path and path ~= "") and path or (meta.path or ""), false)
  local length = tonumber(meta.len) or 0
  local info = {
    path            = fullpath,
    filename        = opts.filename or (fullpath:match("[^/\\]+$") or fullpath),
    size            = tonumber(meta.size) or 0,
    type            = meta.type or "",
    length          = length,
    samplerate      = to_int(meta.sr),
    channels        = to_int(meta.ch),
    bits            = meta.bits or "",
    genre           = meta.genre or "",
    comment         = meta.comment or "",
    description     = meta.description or "",
    bwf_orig_date   = format_ts(meta.mtime),
    mtime           = tonumber(meta.mtime) or 0,
    ucs_category    = meta.ucs_category or "",
    ucs_subcategory = meta.ucs_subcategory or "",
    ucs_catid       = meta.ucs_catid or "",
    key             = meta.key or "",
    bpm             = meta.bpm or "",
  }

  if opts.section_length ~= nil then info.section_length = opts.section_length end
  if opts.position ~= nil then info.position = opts.position end
  if opts.section_offset ~= nil then info.section_offset = opts.section_offset end
  if opts.source ~= nil then info.source = opts.source end
  if opts.extra then
    for k, v in pairs(opts.extra) do info[k] = v end
  end

  return info
end

-- 用于工程 item/take 行的共享构建器，基于 Soundmole 探测元数据
function SM_BuildItemTakeFileInfoFromProbeMeta(path, meta, item, take, source, opts)
  opts = opts or {}

  local take_name = opts.take_name
  if take_name == nil and take then
    local ok, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    take_name = ok and name or ""
  end

  local filename = opts.filename
  if not filename or filename == "" then
    filename = (take_name and take_name ~= "") and take_name or nil
  end

  local build_opts = { filename = filename }
  if opts.include_section then
    build_opts.section_length = opts.section_length ~= nil and opts.section_length or (tonumber(meta and meta.len) or 0)
  end

  local info = SM_BuildFileInfoFromProbeMeta(path, meta, build_opts)
  if item ~= nil then info.item = item end
  if take ~= nil then info.take = take end

  local item_source = source
  if item_source == nil then item_source = opts.source end
  if item_source ~= nil then info.source = item_source end

  local track = opts.track
  if track == nil and item then track = reaper.GetMediaItem_Track(item) end
  if track ~= nil then info.track = track end

  local track_name = opts.track_name
  if track_name == nil and track then
    local _, name = reaper.GetTrackName(track)
    track_name = name or ""
  end
  if track_name ~= nil then info.track_name = track_name end

  local position = opts.position
  if position == nil and item then position = reaper.GetMediaItemInfo_Value(item, "D_POSITION") end
  if position ~= nil then info.position = position end

  if opts.include_section then
    local section_offset = opts.section_offset
    if section_offset == nil and item and type(GetItemSectionStartPos) == "function" then
      section_offset = GetItemSectionStartPos(item)
    end
    info.section_offset = section_offset or 0
  end

  if opts.extra then
    for k, v in pairs(opts.extra) do info[k] = v end
  end

  return info
end

-- 收集单个音频文件元数据
function CollectFileInfo(path)
  local info = { path = path }

  if HAVE_SM_EXT and path and path ~= "" then
    local h = reaper.SM_ProbeMediaBegin(path, 0, "", 6) -- 单文件exts_csv忽略
    if h then
      while true do
        local chunk = reaper.SM_ProbeMediaNextJSONEx(h, 1, 8) -- 单文件取 1 条
        if not chunk or chunk == "" then break end
        if chunk ~= "\n" then
          local line = chunk:match("[^\r\n]+")
          if line and line ~= "" then
            local m = sm_parse_ndjson_line(line)
            info = SM_BuildFileInfoFromProbeMeta(path, m, {
              section_length = tonumber(m.len) or 0,
            })
            reaper.SM_ProbeMediaEnd(h)
            return info
          end
        end
      end
      reaper.SM_ProbeMediaEnd(h)
    end
  end

  -- 回退到旧逻辑
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

-- Items Assets 收集工程中当前使用的音频文件
function CollectFromItems()
  local files, files_idx = {}, {}
  local item_cnt = reaper.CountMediaItems(0)

  if HAVE_SM_EXT then
    local wanted, first_src = {}, {}
    for i = 0, item_cnt - 1 do
      local item = reaper.GetMediaItem(0, i)
      local take = reaper.GetActiveTake(item)
      if take then
        local src = reaper.GetMediaItemTake_Source(take)
        -- 过滤空对象／非 MediaSource*
        if reaper.ValidatePtr(src, "MediaSource*") then
          local p = normalize_path(reaper.GetMediaSourceFileName(src, ""), false)
          local t = reaper.GetMediaSourceType(src, "")
          if p ~= "" and has_allowed_ext(p) and not wanted[p] then
            wanted[p]     = true
            first_src[p]  = src -- 保存一个 source 以兼容后续逻辑需要
          end
        end
      end
    end

    for path, _ in pairs(wanted) do
      local h = reaper.SM_ProbeMediaBegin(path, 0, "", 6) -- 单文件exts_csv留空即可
      if h then
        local chunk = reaper.SM_ProbeMediaNextJSONEx(h, 1, 8)
        reaper.SM_ProbeMediaEnd(h)
        if chunk and chunk ~= "" and chunk ~= "\n" then
          local line = chunk:match("[^\r\n]+")
          if line and line ~= "" then
            local m = sm_parse_ndjson_line(line)
            local info = SM_BuildFileInfoFromProbeMeta(path, m, {
              source = first_src[path], -- 兼容旧逻辑
            })
            files[info.path] = info
            files_idx[#files_idx+1] = info
          end
        end
      end
    end

    if #files_idx > 0 then
      return files, files_idx
    end
  end

  -- 返回旧逻辑
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

  if HAVE_SM_EXT then -- 单文件模式: Begin > NextJSONEx > 逐行解析 > End
    local wanted = {}
    for i = 0, item_cnt - 1 do
      local item = reaper.GetMediaItem(0, i)
      local take = reaper.GetActiveTake(item)
      if take then
        local src = reaper.GetMediaItemTake_Source(take)
        if reaper.ValidatePtr(src, "MediaSource*") then
          local p = normalize_path(reaper.GetMediaSourceFileName(src, ""), false)
          if p and p ~= "" then wanted[p] = true end
        end
      end
    end

    local meta_by_path = {}
    for p, _ in pairs(wanted) do
      local h = reaper.SM_ProbeMediaBegin(p, 0, "", 6) -- 单文件exts_csv留空
      if h then
        while true do
          local chunk = reaper.SM_ProbeMediaNextJSONEx(h, 1, 8) -- 单文件 1 条即可
          if not chunk or chunk == "" then break end
          if chunk ~= "\n" then
            local line = chunk:match("[^\r\n]+")
            if line and line ~= "" then
              meta_by_path[p] = sm_parse_ndjson_line(line)
            end
          end
        end
        reaper.SM_ProbeMediaEnd(h)
      end
    end

    for i = 0, item_cnt - 1 do
      local item = reaper.GetMediaItem(0, i)
      local take = reaper.GetActiveTake(item)
      if take then
        local src = reaper.GetMediaItemTake_Source(take)
        -- 过滤空对象／非 MediaSource*
        if reaper.ValidatePtr(src, "MediaSource*") then
          local path = normalize_path(reaper.GetMediaSourceFileName(src, ""), false)
          local m = path ~= "" and meta_by_path[path] or nil
          if m and path ~= "" and has_allowed_ext(path) then
            local info = SM_BuildItemTakeFileInfoFromProbeMeta(path, m, item, take, src, {
              include_section = true,
            })
            table.insert(files_idx, info)
          end
        end
      end
    end

    if #files_idx > 0 then
      return files_idx
    end
  end

  -- 回退到旧逻辑
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

  if HAVE_SM_EXT then
    local meta_by_path = {}
    for p, _ in pairs(path_set) do
      local h = reaper.SM_ProbeMediaBegin(p, 0, "", 6) -- 单文件exts_csv置空
      if h then
        while true do
          local chunk = reaper.SM_ProbeMediaNextJSONEx(h, 1, 8) -- 单文件一条足够

          if not chunk or chunk == "" then break end
          if chunk ~= "\n" then
            local line = chunk:match("[^\r\n]+")
            if line and line ~= "" then
              local m = sm_parse_ndjson_line(line)
              local k = normalize_path(p, false)
              meta_by_path[k] = m
            end
          end
        end
        reaper.SM_ProbeMediaEnd(h)
      end
    end

    local item_cnt = reaper.CountMediaItems(0)
    for i = 0, item_cnt - 1 do
      local item = reaper.GetMediaItem(0, i)
      local take = reaper.GetActiveTake(item)
      if take then
        local src = reaper.GetMediaItemTake_Source(take)
        if reaper.ValidatePtr(src, "MediaSource*") then
          local root_src = GetRootSource(src) -- 统一获取音频源
          local path = ""
          if reaper.ValidatePtr(root_src, "MediaSource*") then
            path = normalize_path(reaper.GetMediaSourceFileName(root_src, ""), false)
          end

          if path ~= "" and path_set[path] then
            local m = meta_by_path[path]
            if m and path ~= "" and has_allowed_ext(path) then
              local info = SM_BuildItemTakeFileInfoFromProbeMeta(path, m, item, take, src)
              table.insert(files_idx, info)
            end
          end
        end
      end
    end

    if #files_idx > 0 then
      return files_idx
    end
  end

  -- 回退到旧逻辑
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
          source = real_src,
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
          ucs_category    = get_ucstag(real_src, "category"),
          ucs_catid       = get_ucstag(real_src, "catId"),
          ucs_subcategory = get_ucstag(real_src, "subCategory"),
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

  -- 目录模式 Begin > NextJSONEx > 逐行解析 > End
  if HAVE_SM_EXT then
    local exts_csv = "wav,mp3,flac,ogg,aif,aiff,ape,wv,m4a,aac,mp4"
    local h = reaper.SM_ProbeMediaBegin(proj_path, 0, exts_csv, 6)
    if h then
      while true do
        local chunk = reaper.SM_ProbeMediaNextJSONEx(h, 256, 8) -- 批量取, 预算 8ms
        if not chunk or chunk == "" then break end
        if chunk ~= "\n" then
          for line in chunk:gmatch("[^\r\n]+") do
            if line ~= "" then
              local m = sm_parse_ndjson_line(line)
              if m.path ~= "" then
                local fullpath = normalize_path(m.path, false)
                if not files[fullpath] then
                  local info = SM_BuildFileInfoFromProbeMeta(fullpath, m)
                  files[fullpath] = info
                  files_idx[#files_idx + 1] = info
                end
              end
            end
          end
        end
      end
      reaper.SM_ProbeMediaEnd(h)
      return files, files_idx  -- 成功使用扩展时直接返回
    end
  end

  -- 回退到旧逻辑
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
  -- 逐个单文件模式探针 Begin > NextJSONEx > 逐行解析 > End
  if HAVE_SM_EXT and type(paths) == "table" and #paths > 0 then
    local seen = {}
    for _, raw in ipairs(paths) do
      if type(raw) == "string" and raw ~= "" then
        local inpath = normalize_path(raw, false)
        if has_allowed_ext(inpath) then -- 单文件模式不吃 exts_csv，需在 Lua 侧按扩展名放行
          local h = reaper.SM_ProbeMediaBegin(inpath, 0, "", 6) -- 单文 exts_csv忽略
          if h then
            while true do
              local chunk = reaper.SM_ProbeMediaNextJSONEx(h, 1, 8)
              if not chunk or chunk == "" then break end
              if chunk ~= "\n" then
                for line in chunk:gmatch("[^\r\n]+") do
                  if line ~= "" then
                    local m = sm_parse_ndjson_line(line)
                    local info = SM_BuildFileInfoFromProbeMeta(inpath, m, {
                      position       = 0,
                      section_offset = 0,
                      section_length = tonumber(m and m.len) or 0,
                    })
                    local fullpath = info.path
                    if not seen[fullpath] then
                      files_idx[#files_idx + 1] = info
                      seen[fullpath] = true
                    end
                  end
                end
              end
            end
            reaper.SM_ProbeMediaEnd(h)
          end
        end
      end
    end

    if #files_idx > 0 then
      return files_idx
    end
  end

  -- 回退到旧逻辑
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

function CollectFromDirectory(dir_path)
  dir_path = normalize_path(dir_path, true)
  local files, files_idx = {}, {}

  -- 将当前正在构建的文件表，注册为后台更新的目标
  _G.current_files_map = files
  if reaper.APIExists("SM_ListDirBegin") and dir_path and dir_path ~= "" then
    local exts_csv = "wav,mp3,flac,ogg,aif,aiff,ape,wv,m4a,aac,mp4"
    local h = reaper.SM_ListDirBegin(dir_path, 0, exts_csv)
    if h then
      while true do
        local chunk = reaper.SM_ListDirNextJSON(h, 2000)
        if not chunk or chunk == "" then break end
        if chunk ~= "\n" then
          for line in chunk:gmatch("[^\r\n]+") do
            if line ~= "" then
              local m = sm_parse_ndjson_line(line)
              if m.path ~= "" then
                local fullpath = normalize_path(m.path, false)
                if not files[fullpath] then
                  local info = SM_BuildFileInfoFromProbeMeta(fullpath, m, {
                    extra = { type = "..." },
                  })
                  files[fullpath] = info
                  files_idx[#files_idx+1] = info
                end
              end
            end
          end
        end
      end
      reaper.SM_ListDirEnd(h)
      -- 启动后台探测器
      if _G.async_probe_handle then 
        reaper.SM_ProbeMediaEnd(_G.async_probe_handle) 
        _G.async_probe_handle = nil
      end
      if reaper.APIExists("SM_ProbeMediaBegin") then
        -- Flag 0 = 标准模式
        _G.async_probe_handle = reaper.SM_ProbeMediaBegin(dir_path, 0, exts_csv, 0)
      end

      return files, files_idx
    end
  end

  if HAVE_SM_EXT and dir_path and dir_path ~= "" then
    local exts_csv = "wav,mp3,flac,ogg,aif,aiff,ape,wv,m4a,aac,mp4"
    local h = reaper.SM_ProbeMediaBegin(dir_path, 0, exts_csv, 6)
    if h then
      while true do
        local chunk = reaper.SM_ProbeMediaNextJSONEx(h, 256, 8) -- 一次取一批，max_items=256 / 预算=8ms，按需调大
        if not chunk or chunk == "" then break end
        if chunk ~= "\n" then
          for line in chunk:gmatch("[^\r\n]+") do
            if line ~= "" then
              local m = sm_parse_ndjson_line(line)
              if m.path ~= "" then
                local fullpath = normalize_path(m.path, false)
                if not files[fullpath] then
                  local info = SM_BuildFileInfoFromProbeMeta(fullpath, m)
                  files[fullpath] = info
                  files_idx[#files_idx+1] = info
                end
              end
            end
          end
        end
      end
      reaper.SM_ProbeMediaEnd(h)
      return files, files_idx
    end
  end

  -- 回退到旧逻辑
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

function ProcessAsyncMetadata()
  if not _G.async_probe_handle then return end

  -- 如果不在文件夹模式下，立即停止扫描
  if not _G.current_files_map then
    if reaper.APIExists("SM_ProbeMediaEnd") then
      reaper.SM_ProbeMediaEnd(_G.async_probe_handle)
    end
    _G.async_probe_handle = nil
    return
  end

  -- 批量读取，每次处理 256 个文件，保持 UI 流畅
  local chunk = reaper.SM_ProbeMediaNextJSONEx(_G.async_probe_handle, 256, 8)

  if not chunk or chunk == "" then
    reaper.SM_ProbeMediaEnd(_G.async_probe_handle)
    _G.async_probe_handle = nil
    return
  end

  if chunk ~= "\n" then
    -- 更新当前正在浏览的文件夹表
    local target_map = _G.current_files_map

    for line in chunk:gmatch("[^\r\n]+") do
      if line ~= "" then
        local m = sm_parse_ndjson_line(line)
        if m.path ~= "" then
          local fullpath = normalize_path(m.path, false)
          local info = target_map[fullpath]

          if info then
            local probed = SM_BuildFileInfoFromProbeMeta(fullpath, m, { filename = info.filename })
            for k, v in pairs(probed) do info[k] = v end
          end
        end
      end
    end
  end
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

  if HAVE_SM_EXT and path and path ~= "" then
    local h = reaper.SM_ProbeMediaBegin(path, 0, "", 6)
    if h then
      while true do
        local chunk = reaper.SM_ProbeMediaNextJSONEx(h, 1, 8) -- 单文件取 1 条即可
        if not chunk or chunk == "" then break end
        if chunk ~= "\n" then
          local line = chunk:match("[^\r\n]+")
          if line and line ~= "" then
            local m = sm_parse_ndjson_line(line)
            info = SM_BuildFileInfoFromProbeMeta(path, m, {
              filename       = filename,
              position       = 0,
              section_offset = 0,
              section_length = tonumber(m and m.len) or 0,
            })

            reaper.SM_ProbeMediaEnd(h)
            return info
          end
        end
      end
      reaper.SM_ProbeMediaEnd(h)
    end
  end

  -- 回退到旧逻辑
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
  f:write(('FILE "%s" %d 0 %d 0\n'):format(info.path, tonumber(info.size), tonumber(info.mtime) or 0))
  -- DATA基本属性行
  -- f:write(('DATA %s l:%s n:%s s:%s i:%s\n'):format(quote_if_space('y:' .. (info.bwf_orig_date or "")), info.length or "", info.channels or "", info.samplerate or "", info.bits or ""))
  f:write(('DATA %sl:%s n:%s s:%s i:%s\n'):format(
    (info.bwf_orig_date and info.bwf_orig_date ~= "") and (quote_if_space('y:' .. (info.bwf_orig_date))..' ') or '',
    info.length or "", info.channels or "", info.samplerate or "", info.bits or ""
  ))

  -- DATA类别行
  local ucs = {}
  if info.genre           and info.genre           ~= "" then table.insert(ucs, quote_if_space('g:' .. info.genre))         end
  if info.key             and info.key             ~= "" then table.insert(ucs, quote_if_space('k:' .. info.key))           end
  if info.bpm             and tostring(info.bpm)   ~= "" then table.insert(ucs, quote_if_space('p:' .. tostring(info.bpm))) end
  if info.ucs_category    and info.ucs_category    ~= "" then table.insert(ucs, quote_if_space('category:'    .. info.ucs_category))    end
  if info.ucs_subcategory and info.ucs_subcategory ~= "" then table.insert(ucs, quote_if_space('subcategory:' .. info.ucs_subcategory)) end
  if info.ucs_catid       and info.ucs_catid       ~= "" then table.insert(ucs, quote_if_space('catid:'       .. info.ucs_catid))       end
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

-- 读取现有 FILE 集合
function DB_ReadExistingFileSet(dbpath)
  local set = {}
  local f = io.open(dbpath, "rb")
  if not f then return set end
  for line in f:lines() do
    local p = line:match('^FILE%s+"(.-)"')
    if p and p ~= "" then
      set[normalize_path(p, false)] = true
    end
  end
  f:close()
  return set
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
