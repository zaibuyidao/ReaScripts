-- NoIndex: true
-- Freesound integration for Soundmole. Kept as global FS_* entry points so the main script can call them directly.
local M = {}

local sep = package.config:sub(1,1)
local module_dir = debug.getinfo(1, 'S').source:match[[^@?(.*[\/])[^\/]-$]] or ""
local script_path = module_dir:gsub("[/\\]lib[/\\]$", sep)
local EXT_SECTION = "Soundmole"
local colors = {}

function M.configure(opts)
  opts = opts or {}
  if opts.script_path and opts.script_path ~= "" then script_path = opts.script_path end
  if opts.ext_section and opts.ext_section ~= "" then EXT_SECTION = opts.ext_section end
  if opts.colors then colors = opts.colors end
  return M
end

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
function FS_cache_file_is_audio(name)
  local ext = tostring(name or ""):match("%.([^.]+)$")
  if not ext then return false end
  ext = ext:lower()
  if ext == "cmd" or ext == "vbs" or ext == "ps1" or ext == "sh" or ext == "part" or ext == "done" or ext == "fail" or ext == "log" then
    return false
  end
  local types = audio_types or { WAVE=true, MP3=true, FLAC=true, OGG=true, AIFF=true, APE=true, M4A=true, AAC=true, MP4=true }
  return types[ext:upper()] == true
end

function FS_RebuildCacheIndex()
  FS = FS or {}
  local dir = FS_cache_dir()
  local by_fid = {}
  local by_fid_ext = {}

  local function add_cached_file(fid, full, fn)
    fid = tostring(fid or ""):match("%d+")
    if not fid or fid == "" or not FS_cache_file_is_audio(fn) then return end
    if reaper.file_exists(full) and FS_file_size(full) > 0 then
      local ext = (fn:match("%.([^.]+)$") or ""):lower()
      by_fid[fid] = by_fid[fid] or full
      by_fid_ext[fid] = by_fid_ext[fid] or {}
      if ext ~= "" then by_fid_ext[fid][ext] = full end
    end
  end

  local i = 0
  while true do
    local fn = reaper.EnumerateFiles(dir, i)
    if not fn then break end
    add_cached_file(fn:match("__fs(%d+)%."), FS_join(dir, fn), fn)
    i = i + 1
  end

  local j = 0
  while true do
    local sub = reaper.EnumerateSubdirectories(dir, j)
    if not sub then break end
    local fid = sub:match("^fs_(%d+)$")
    if fid then
      local subdir = FS_join(dir, sub)
      local k = 0
      while true do
        local fn = reaper.EnumerateFiles(subdir, k)
        if not fn then break end
        add_cached_file(fid, FS_join(subdir, fn), fn)
        k = k + 1
      end
    end
    j = j + 1
  end
  FS._cache_by_fid = by_fid
  FS._cache_by_fid_ext = by_fid_ext
  FS._cache_index_ready = true
end

function FS_FindCachedByFid(fid, preferred_ext, allow_any)
  fid = tostring(fid or ""):match("%d+")
  if not fid or fid == "" then return nil end
  preferred_ext = tostring(preferred_ext or ""):gsub("^%.", ""):lower()
  if not (FS and FS._cache_index_ready and FS._cache_by_fid) then
    FS_RebuildCacheIndex()
  end
  local p = nil
  if preferred_ext ~= "" and FS and FS._cache_by_fid_ext and FS._cache_by_fid_ext[fid] then
    p = FS._cache_by_fid_ext[fid][preferred_ext]
  end
  if not p and allow_any ~= false then
    p = FS and FS._cache_by_fid and FS._cache_by_fid[fid] or nil
  end
  if p and reaper.file_exists(p) and FS_file_size(p) > 0 then return p end
  if p then
    FS_RebuildCacheIndex()
    if preferred_ext ~= "" and FS and FS._cache_by_fid_ext and FS._cache_by_fid_ext[fid] then
      p = FS._cache_by_fid_ext[fid][preferred_ext]
    end
    if not p and allow_any ~= false then
      p = FS and FS._cache_by_fid and FS._cache_by_fid[fid] or nil
    end
    if p and reaper.file_exists(p) and FS_file_size(p) > 0 then return p end
  end
  return nil
end

function FS_SetEntryLocalPath(e, path)
  if not e or not path or path == "" then return false end
  if not (reaper.file_exists(path) and FS_file_size(path) > 0) then return false end
  if e.path ~= path or e._fs_local_cache_path ~= path then
    e.path = path
    e.filename = path:match("([^/\\]+)$") or path
    e._thumb_waveform = nil
    e._wf_state = nil
    e._wf_enqueued = nil
    e._loading_waveform = false
    e._fs_local_cache_path = path
  end
  return true
end

function FS_MaybeSwapEntryPathToLocal(e)
  if not e or collect_mode ~= COLLECT_MODE_FREESOUND then return end
  if not e.comment then
    if type(EnsureEntryParsed) == "function" then EnsureEntryParsed(e) end
  end
  local cmt = tostring(e.comment or "")
  local src_kind = cmt:match("src_kind@([%w_]+)") or "preview"
  local enc = cmt:match("sug@([^%s]+)")
  local preferred_ext = nil
  local suggest_name = nil
  local suggest_dst = nil
  if enc and enc ~= "" and not (FS and FS.USE_ORIGINAL and src_kind ~= "original") then
    suggest_name = FS_urldecode(enc)
    preferred_ext = suggest_name:match("%.([^.]+)$")
    suggest_dst = FS_local_cache_path_for({ suggest_name = suggest_name, comment = cmt })
    if FS_SetEntryLocalPath(e, suggest_dst) then return end
  end

  local fid = cmt:match("fid@(%d+)")
  local cached = FS_FindCachedByFid(fid, preferred_ext, (src_kind ~= "original") and not (FS and FS.USE_ORIGINAL))
  if cached and suggest_dst and cached ~= suggest_dst and not reaper.file_exists(suggest_dst) then
    FS_ensure_dir(suggest_dst:match("^(.*)[/\\]") or FS_cache_dir())
    if os.rename(cached, suggest_dst) then
      cached = suggest_dst
      FS._cache_index_ready = false
    end
  end
  if cached then FS_SetEntryLocalPath(e, cached) end
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

  local osname = reaper.GetOS()
  local is_win = osname and osname:find("Win") ~= nil
  -- Windows 优先走 ExecProcess，避免CMD弹窗
  if is_win then
    local tmp = FS_join(FS_DB_DIR(), (".fs_http_%d.tmp"):format(math.floor(reaper.time_precise()*1e6)))
    local cmd = ('curl -L -s%s "%s" -o "%s"'):format(hdr, url:gsub('"','\\"'), tmp:gsub('"','\\"'))
    local code = tonumber(reaper.ExecProcess(cmd, 120000)) or -1

    local body = ""
    local f = io.open(tmp, "rb")
    if f then body = f:read("*a") or ""; f:close() end
    os.remove(tmp)

    if code == 0 and body ~= "" then
      return body
    end
  end

  -- macOS/Linux 用 /usr/bin/curl; Windows 作为回退用 curl
  local curl_bin = is_win and "curl" or "/usr/bin/curl"
  local p = io.popen(('%s -L -s%s "%s"'):format(curl_bin, hdr, url:gsub('"','\\"')), "r")
  local body = p and p:read("*a") or ""
  if p then p:close() end
  return body
end

-- 配置与状态
FS = FS or {
  ENABLED           = false, -- 勾选激活
  TOKEN             = "", -- Freesound uses the built-in OAuth2 credentials below.
  DB_DIR            = nil, -- 脚本目录下 FreesoundDB/
  CACHE_DB_FILE     = "FreesoundDB.MoleFileList",
  SEARCH_DB_FILE    = "FreesoundSearch.MoleFileList",
  SAVE_PER_QUERY_DB = false, -- 如果为true，为每个关键词保存独立 DB
  API_PAGE_SIZE     = 150,   -- Freesound 上限 150
  FIRST_PAGE_COUNT  = 5000,  -- 首屏加载数
  last_query        = "",
  USE_ORIGINAL      = FS_bool_from_es("fs_use_original", false),        -- 勾选后使用原始文件
  AUTO_DOWNLOAD_RESULTS = FS_bool_from_es("fs_auto_download_results", false), -- 搜索完成后自动下载整张结果列表
  AUTO_DOWNLOAD_CONCURRENCY = 3,
  OAUTH_BEARER      = reaper.GetExtState(EXT_SECTION,"fs_oauth") or "", -- OAuth2 Access Token
  DOWNLOAD_METHOD   = "curl",                                           -- nil=自动选择 "curl"=强制用curl "ps_iwr"=PowerShell Invoke-WebRequest "ps_bits"=PowerShell BITS
  ui = {
    query       = "",
    sort_idx    = 1,  -- 1 Relevance / 2 Rating / 3 Duration / 4 Downloads / 5 Created_new / 6 Created_old
    arrange_idx = 1,  -- 1 Timbre / 2 Tonality
    num_results = 60, -- 1..450
    max_minutes = 5.5 -- 0.5..30
  }
}
if FS.AUTO_DOWNLOAD_RESULTS == nil then
  FS.AUTO_DOWNLOAD_RESULTS = FS_bool_from_es("fs_auto_download_results", false)
end
if FS.AUTO_DOWNLOAD_CONCURRENCY == nil then
  FS.AUTO_DOWNLOAD_CONCURRENCY = 3
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

-- 将 Freesound 返回的 license URL 转为常见简写
function FS_format_license(lic)
  if not lic or lic == "" then return "" end
  local map = {
    -- CC0 1.0 公共领域贡献
    ["creativecommons.org/publicdomain/zero/1.0"]  = "CC0-1.0",
    -- PDM 1.0 公共领域标记
    ["creativecommons.org/publicdomain/mark/1.0"]  = "PDM-1.0",
    -- CC Sampling+ 取样+
    ["creativecommons.org/licenses/sampling+/1.0"] = "CC-Sampling+-1.0",
    -- CC BY 署名。需注明作者，可改作与再发布，允许商业使用
    ["creativecommons.org/licenses/by/3.0"]        = "CC-BY-3.0",
    ["creativecommons.org/licenses/by/4.0"]        = "CC-BY-4.0",
    -- CC BY-SA 署名 相同方式共享
    ["creativecommons.org/licenses/by-sa/3.0"]     = "CC-BY-SA-3.0",
    ["creativecommons.org/licenses/by-sa/4.0"]     = "CC-BY-SA-4.0",
    -- CC BY-NC 署名 非商业性使用
    ["creativecommons.org/licenses/by-nc/3.0"]     = "CC-BY-NC-3.0",
    ["creativecommons.org/licenses/by-nc/4.0"]     = "CC-BY-NC-4.0",
    -- CC BY-NC-SA 署名 非商业性使用 相同方式共享
    ["creativecommons.org/licenses/by-nc-sa/3.0"] = "CC-BY-NC-SA-3.0",
    ["creativecommons.org/licenses/by-nc-sa/4.0"]  = "CC-BY-NC-SA-4.0",
    -- CC BY-ND 署名 禁止演绎
    ["creativecommons.org/licenses/by-nd/3.0"]     = "CC-BY-ND-3.0",
    ["creativecommons.org/licenses/by-nd/4.0"]     = "CC-BY-ND-4.0",
    -- CC BY-NC-ND 署名 非商业性使用 禁止演绎
    ["creativecommons.org/licenses/by-nc-nd/3.0"] = "CC-BY-NC-ND-3.0",
    ["creativecommons.org/licenses/by-nc-nd/4.0"]  = "CC-BY-NC-ND-4.0",
  }
  local key = lic:gsub("^https?://", ""):gsub("^www%.", ""):gsub("/+$", "")
  for k, v in pairs(map) do
    if key:find(k, 1, true) then return v end
  end
  return lic
end

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

  -- Keep the Freesound source filename visible; fid uniqueness is handled by cache subfolders.
  local function make_unique_suggest(base_noext, ext, fid, length_sec, size_bytes)
    return sanitize_filename(base_noext .. ext)
  end

  for _, s in ipairs(results or {}) do
    -- 预览源
    local pv_mp3, pv_ogg = "", ""
    if s and s.previews then
      pv_mp3 = s.previews["preview-hq-mp3"] or s.previews["preview-lq-mp3"] or ""
      pv_ogg = s.previews["preview-hq-ogg"] or s.previews["preview-lq-ogg"] or ""
    end

    local original_url = (s and s.id ~= nil) and ("https://freesound.org/apiv2/sounds/%d/download/"):format(tonumber(s.id)) or ""
    local want_original = (FS.USE_ORIGINAL and original_url ~= "")
    local src_url = ""
    if want_original then
      src_url = original_url
    else
      src_url = (pv_mp3 ~= "" and pv_mp3) or (pv_ogg ~= "" and pv_ogg) or ""
      if src_url == "" then src_url = (original_url ~= "" and original_url) or (s and s.url or "") end
    end
    local src_kind = (src_url == original_url and original_url ~= "") and "original" or "preview"

    -- 计算展示名（path 字段仅用于列表展示/检索）
    local base_name   = (s and s.original_filename and s.original_filename ~= "" and s.original_filename) or (s and s.name and s.name ~= "" and s.name) or ("freesound_"..tostring(s and s.id or ""))
    local base_noext  = strip_ext(base_name)
    local ext_from_ty = (s and s.type and tostring(s.type) ~= "" and ("."..tostring(s.type):gsub("^%.",""))) or nil

    local ext
    if src_kind == "original" then
      ext = ext_from_ty
        or ext_from_name(s and s.original_filename)
        or ext_from_name(s and s.name)
        or guess_ext_from_url(src_url)
        or ".wav"
    elseif pv_mp3 ~= "" then
      ext = ".mp3"
    elseif pv_ogg ~= "" then
      ext = ".ogg"
    else
      ext = guess_ext_from_url(src_url) or ".mp3"
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
    if s and tonumber(s.avg_rating) then
      desc_prefix[#desc_prefix + 1] = ("⭐%02.1f"):format(tonumber(s.avg_rating))
    end
    if s and tonumber(s.num_downloads) then
      desc_prefix[#desc_prefix + 1] = (function(n)
        local t = tostring(n)
        return "⬇" .. t .. string.rep(" ", math.max(0, 5 - #t))
      end)
      (tonumber(s.num_downloads))
    end
    if s and s.license and s.license ~= "" then
      local t = tostring(FS_format_license(s.license))
      desc_prefix[#desc_prefix + 1] = ("license:%s%s"):format(t, string.rep(" ", math.max(0, 12 - #t)))
    end

    local head = {}
    -- if cur_q ~= "" then head[#head+1] = ("[q:%s]"):format(FS_s(cur_q)) end
    -- if s and s.name and s.name~="" then head[#head+1] = ("[%s]"):format(FS_s(s.name)) end
    -- if s and s.original_filename and s.original_filename~="" then head[#head+1] = ("(%s)"):format(FS_s(s.original_filename)) end
    if tags ~= "" then head[#head+1] = ("%s"):format(FS_s(tags)) end -- 带#号: head[#head+1] = ("#%s"):format(FS_s(tags))
    local desc, tail = "", FS_s(s and s.description or "")
    if tail ~= "" then desc = desc .. " " .. tail end

    -- comment：src@ / src_kind@ / sug@ / fid@
    local fid = s and s.id or nil
    local comment = table.concat(desc_prefix, " ")
    if src_url ~= "" then
      comment = (comment ~= "" and (comment.." ") or "") .. ("src@%s"):format(FS_s(src_url))
      comment = comment .. ("  src_kind@%s"):format(src_kind)
      -- 保持源文件名；同名不同文件通过 fid 子目录隔离
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
      type        = (src_kind == "original" and FS_s(s and s.type or "")) or (pv_mp3 ~= "" and "mp3" or (pv_ogg ~= "" and "ogg" or "")),
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
  FS = FS or {}
  if FS._cache_dir ~= d or not FS._cache_dir_ready then
    FS_ensure_dir(d)
    FS._cache_dir = d
    FS._cache_dir_ready = true
  end
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
    suggest = FS_sanitize_cache_name(suggest)
    local fid = tostring(info and info.comment or ""):match("fid@(%d+)")
    if fid and fid ~= "" then
      suggest = suggest:gsub("__fs" .. fid .. "(%.[^.]+)$", "%1")
      suggest = suggest:gsub("__fs%d+(%.[^.]+)$", "%1")
      local subdir = FS_join(cache_dir, "fs_" .. fid)
      FS_ensure_dir(subdir)
      return FS_join(subdir, suggest)
    end
    return FS_join(cache_dir, suggest)
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
    _key        = expected_key, -- 与 RenderWaveformCell 的防串写一致
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
    -- macOS/Linux 用 /usr/bin/curl; Windows 作为回退用 curl
    local curl_bin = is_win and "curl" or "/usr/bin/curl"
    if not is_win then
      local fchk = io.open(curl_bin, "rb")
      if not fchk then curl_bin = "curl" else fchk:close() end
    end

    local header = ""
    if auth_header and auth_header ~= "" then
      header = string.format(' -H "%s"', auth_header:gsub('"','\\"'))
    end
    local ua = ' -A "Soundmole/1.0"'
    local cmd = string.format(
      '%s --fail -L --retry 3 --retry-delay 1 --connect-timeout 10 --max-time 120 --no-progress-meter -C -%s%s "%s" -o "%s"',
      curl_bin, ua, header, url, dst
    )

    -- Windows 走 ExecProcess, macOS/Linux 走 popen
    local code
    if is_win then
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
  end
  return false
end

function FS_file_size(path)
  local f = io.open(path, "rb")
  if not f then return 0 end
  local sz = f:seek("end") or 0
  f:close()
  return sz
end

function FS_cmd_quote(s)
  s = tostring(s or ""):gsub('"', ''):gsub("%%", "%%%%")
  return '"' .. s .. '"'
end

function FS_sh_quote(s)
  s = tostring(s or ""):gsub("'", "'\\''")
  return "'" .. s .. "'"
end

function FS_ps_quote(s)
  s = tostring(s or ""):gsub("'", "''")
  return "'" .. s .. "'"
end

function FS_bat_escape(s)
  s = tostring(s or ""):gsub("[\r\n]", "")
  return (s:gsub("%%", "%%%%"))
end

function FS_vbs_quote(s)
  s = tostring(s or ""):gsub('"', '""')
  return '"' .. s .. '"'
end

function FS_launch_detached(path, is_win)
  if is_win and reaper.CF_ShellExecute then
    local ok = pcall(reaper.CF_ShellExecute, path)
    if ok then return true end
  end
  if is_win then
    local rc = os.execute('start "" /b ' .. FS_cmd_quote(path))
    return (rc == true or rc == 0)
  end
  local rc = os.execute('sh ' .. FS_sh_quote(path) .. ' >/dev/null 2>&1 &')
  return (rc == true or rc == 0)
end

function FS_write_text_file(path, text)
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(text or "")
  f:close()
  return true
end

function FS_write_ps1_file(path, text)
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(string.char(0xEF, 0xBB, 0xBF))
  f:write(text or "")
  f:close()
  return true
end

function FS_download_job_key(dst)
  return normalize_path(tostring(dst or ""), false)
end

function FS_finish_download_job(job)
  if not job or not job.info or not job.dst then return end
  FS_SetEntryLocalPath(job.info, job.dst)
  do
    local fid = tostring(job.info.comment or ""):match("fid@(%d+)")
    if fid and fid ~= "" then
      FS = FS or {}
      FS._cache_by_fid = FS._cache_by_fid or {}
      FS._cache_by_fid_ext = FS._cache_by_fid_ext or {}
      FS._cache_by_fid[fid] = FS._cache_by_fid[fid] or job.dst
      local ext = tostring(job.dst or ""):match("%.([^.]+)$")
      if ext and ext ~= "" then
        FS._cache_by_fid_ext[fid] = FS._cache_by_fid_ext[fid] or {}
        FS._cache_by_fid_ext[fid][ext:lower()] = job.dst
      end
      FS._cache_index_ready = true
    end
  end
  job.info._fs_downloading = false
  job.info._fs_download_failed = nil

  local w = (job.info._last_thumb_w and tonumber(job.info._last_thumb_w)) or 400
  if type(EnqueueWaveformTask) == "function" then
    waveform_task_queue = waveform_task_queue or {}
    EnqueueWaveformTask(job.info, w)
  end

  if job.after_ready then
    local cb = job.after_ready
    job.after_ready = nil
    reaper.defer(cb)
  end
end

function FS_start_download_async(info, url, dst, auth_header, after_ready)
  if reaper.file_exists(dst) and FS_file_size(dst) > 0 then
    FS_SetEntryLocalPath(info, dst)
    info._fs_downloading = false
    info._fs_download_failed = nil
    return true
  end

  local dst_dir = dst:match("^(.*)[/\\]") or FS_cache_dir()
  if FS._download_dir ~= dst_dir or not FS._download_dir_ready then
    FS_ensure_dir(dst_dir)
    FS._download_dir = dst_dir
    FS._download_dir_ready = true
  end
  FS.download_jobs = FS.download_jobs or {}
  local key = FS_download_job_key(dst)
  local existing = FS.download_jobs[key]
  if existing then
    if after_ready then existing.after_ready = after_ready end
    info._fs_downloading = true
    return false
  end

  local is_win = (package.config:sub(1,1) == "\\")
  local job_base = FS_join(FS_cache_dir(), (".fsdl_%d_%d"):format(math.floor(reaper.time_precise() * 1000000), math.random(1, 1000000)))
  local part = job_base .. ".part"
  local done = job_base .. ".done"
  local fail = job_base .. ".fail"
  local log = job_base .. ".log"
  local script = job_base .. (is_win and ".cmd" or ".sh")
  local launcher = is_win and (job_base .. "_launch.vbs") or nil
  os.remove(part); os.remove(done); os.remove(fail); os.remove(log)

  local header = ""
  if auth_header and auth_header ~= "" then
    header = " -H " .. FS_cmd_quote(auth_header)
  end

  local launched = false
  if is_win then
    local bat_header = ""
    if auth_header and auth_header ~= "" then
      bat_header = " -H " .. FS_cmd_quote(auth_header)
    end
    local worker = table.concat({
      "@echo off",
      "setlocal",
      "set \"part=" .. FS_bat_escape(part) .. "\"",
      "set \"dst=" .. FS_bat_escape(dst) .. "\"",
      "set \"done=" .. FS_bat_escape(done) .. "\"",
      "set \"fail=" .. FS_bat_escape(fail) .. "\"",
      "set \"log=" .. FS_bat_escape(log) .. "\"",
      "set \"url=" .. FS_bat_escape(FS_norm_http(url)) .. "\"",
      "del /f /q \"%part%\" \"%done%\" \"%fail%\" >nul 2>nul",
      ">> \"%log%\" echo start",
      "where curl.exe >nul 2>nul || goto fail",
      "curl.exe --fail --location --silent --show-error --retry 1 --retry-delay 1 --connect-timeout 8 --max-time 45 -A \"Soundmole/1.0\"" .. bat_header .. " \"%url%\" -o \"%part%\" >> \"%log%\" 2>&1",
      "if errorlevel 1 goto fail",
      "if not exist \"%part%\" goto fail",
      "for %%A in (\"%part%\") do if %%~zA LEQ 0 goto fail",
      "move /y \"%part%\" \"%dst%\" >> \"%log%\" 2>&1",
      "if errorlevel 1 goto fail",
      "> \"%done%\" echo ok",
      ">> \"%log%\" echo done",
      "exit /b 0",
      ":fail",
      "del /f /q \"%part%\" >nul 2>nul",
      "> \"%fail%\" echo fail",
      ">> \"%log%\" echo fail",
      "exit /b 1",
      ""
    }, "\r\n")
    local launch = table.concat({
      "Set sh = CreateObject(\"WScript.Shell\")",
      "sh.Run " .. FS_vbs_quote('cmd.exe /d /c "' .. script .. '"') .. ", 0, False",
      ""
    }, "\r\n")
    if FS_write_text_file(script, worker) and FS_write_text_file(launcher, launch) then
      launched = FS_launch_detached(launcher, true)
    end
  else
    local sh = table.concat({
      "#!/bin/sh",
      "rm -f " .. FS_sh_quote(part) .. " " .. FS_sh_quote(done) .. " " .. FS_sh_quote(fail),
      "{",
      "echo \"$(date '+%Y-%m-%dT%H:%M:%S') start\"",
      "curl --fail --location --silent --show-error --retry 1 --retry-delay 1 --connect-timeout 8 --max-time 45 -A " .. FS_sh_quote("Soundmole/1.0") .. (auth_header and auth_header ~= "" and (" -H " .. FS_sh_quote(auth_header)) or "") .. " " .. FS_sh_quote(FS_norm_http(url)) .. " -o " .. FS_sh_quote(part),
      "code=$?",
      "if [ $code -eq 0 ] && [ -s " .. FS_sh_quote(part) .. " ]; then mv -f " .. FS_sh_quote(part) .. " " .. FS_sh_quote(dst) .. " && echo ok > " .. FS_sh_quote(done) .. " && echo \"$(date '+%Y-%m-%dT%H:%M:%S') done\"; else rm -f " .. FS_sh_quote(part) .. "; echo \"download command failed: $code\" > " .. FS_sh_quote(fail) .. "; echo \"$(date '+%Y-%m-%dT%H:%M:%S') fail $code\"; fi",
      "} >> " .. FS_sh_quote(log) .. " 2>&1",
      ""
    }, "\n")
    if FS_write_text_file(script, sh) then
      launched = FS_launch_detached(script, false)
    end
  end

  if not launched then
    info._fs_downloading = false
    info._fs_download_failed = true
    FS.ui = FS.ui or {}
    FS.ui.download_status = "Download start failed"
    return false
  end
  info._fs_downloading = true
  info._fs_download_failed = nil
  FS.ui = FS.ui or {}
  FS.ui.download_status = "Downloading..."
  FS.download_jobs[key] = {
    info = info,
    url = url,
    dst = dst,
    part = part,
    done = done,
    fail = fail,
    log = log,
    script = script,
    launcher = launcher,
    started = reaper.time_precise(),
    after_ready = after_ready
  }
  return false
end

function FS_download_job_count()
  local n = 0
  if FS and FS.download_jobs then
    for _ in pairs(FS.download_jobs) do n = n + 1 end
  end
  return n
end

function FS_KickDownloadQueue()
  if not FS or not FS.download_queue then return end
  FS.download_jobs = FS.download_jobs or {}

  local q = FS.download_queue
  local max_running = math.max(1, tonumber(FS.AUTO_DOWNLOAD_CONCURRENCY or 3) or 3)
  local pos = tonumber(FS.download_queue_pos or 1) or 1

  while pos <= #q and FS_download_job_count() < max_running do
    local info = q[pos]
    pos = pos + 1
    if info then
      FS_ensure_local_before_play(info, nil)
    end
  end

  FS.download_queue_pos = pos
  local remaining = math.max(0, #q - pos + 1)
  if remaining > 0 then
    FS.ui = FS.ui or {}
    FS.ui.download_status = ("Downloads queued: %d"):format(remaining)
  elseif FS_download_job_count() == 0 then
    FS.download_queue = nil
    FS.download_queue_pos = nil
    FS.ui = FS.ui or {}
    FS.ui.download_status = "Download complete"
  else
    FS.download_queue = nil
    FS.download_queue_pos = nil
  end
end

function FS_QueueDownloadList(list)
  if not FS or collect_mode ~= COLLECT_MODE_FREESOUND then return end
  local q, seen = {}, {}
  for _, info in ipairs(list or {}) do
    if info then
      if not info.comment and type(EnsureEntryParsed) == "function" then EnsureEntryParsed(info) end
      local cmt = tostring(info.comment or "")
      local key = cmt:match("fid@(%d+)") or normalize_path(tostring(info.path or ""), false)
      if key ~= "" and not seen[key] then
        seen[key] = true
        q[#q + 1] = info
      end
    end
  end

  FS.download_queue = (#q > 0) and q or nil
  FS.download_queue_pos = (#q > 0) and 1 or nil
  FS.ui = FS.ui or {}
  FS.ui.download_status = (#q > 0) and ("Downloads queued: %d"):format(#q) or "No downloads queued"
  FS_KickDownloadQueue()
end

function FS_ProcessDownloadJobs()
  if not FS then return end
  FS.download_jobs = FS.download_jobs or {}
  local now = reaper.time_precise()
  if FS._last_download_poll and now - FS._last_download_poll < 0.20 then return end
  FS._last_download_poll = now

  FS_KickDownloadQueue()

  for key, job in pairs(FS.download_jobs) do
    local ok = reaper.file_exists(job.dst) and FS_file_size(job.dst) > 0
    local failed = reaper.file_exists(job.fail)
    local timed_out = (now - (job.started or now)) > 70
    local part_size = (job.part and reaper.file_exists(job.part)) and FS_file_size(job.part) or 0

    if ok then
      FS.download_jobs[key] = nil
      os.remove(job.done); os.remove(job.fail); os.remove(job.log); os.remove(job.script); if job.launcher then os.remove(job.launcher) end
      FS.ui = FS.ui or {}
      FS.ui.download_status = "Download complete"
      FS_finish_download_job(job)
    elseif failed or timed_out then
      FS.download_jobs[key] = nil
      os.remove(job.part); os.remove(job.done); os.remove(job.script); if job.launcher then os.remove(job.launcher) end
      if job.info then
        job.info._fs_downloading = false
        job.info._fs_download_failed = true
      end
      FS.ui = FS.ui or {}
      FS.ui.download_status = timed_out and "Download timed out" or "Download failed"
    elseif part_size > 0 then
      FS.ui = FS.ui or {}
      FS.ui.download_status = ("Downloading... %.1f KB"):format(part_size / 1024)
    end
  end

  FS_KickDownloadQueue()
end

function FS_ensure_local_before_play(info, after_ready)
  if not info then return true end
  if collect_mode ~= COLLECT_MODE_FREESOUND then return true end

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
  if FS.USE_ORIGINAL then
    local fid = cmt:match("fid@(%d+)")
    if fid and fid ~= "" then
      src = ("https://freesound.org/apiv2/sounds/%d/download/"):format(tonumber(fid))
      src_kind = "original"
    end
  end
  if not (src and FS_is_http(src)) then return true end

  -- 解析建议文件名，来自 comment 的 sug@
  local suggest
  do
    local enc = cmt:match("sug@([^%s]+)")
    if enc and enc ~= "" then suggest = FS_urldecode(enc) end
  end
  if src_kind == "original" and suggest and suggest ~= "" then
    local typ = tostring(info.type or ""):gsub("^%.", ""):lower()
    if typ ~= "" and not suggest:lower():match("%." .. typ .. "$") then
      suggest = suggest:gsub("%.[^.]+$", "." .. typ)
    end
  end

  local dst = FS_local_cache_path_for({ src = src, suggest_name = suggest, comment = cmt })

  local auth_header = nil
  if src_kind == "original" and (FS.OAUTH_BEARER or "") ~= "" then
    auth_header = "Authorization: Bearer " .. FS.OAUTH_BEARER
  end

  return FS_start_download_async(info, src, dst, auth_header, after_ready)
end

function FS_InitHooks()
  if _G.__FS_HOOKS_INSTALLED then return end
  _G.__FS_HOOKS_INSTALLED = true

  -- 播放钩子
  if type(PlayFromStart)=="function" then
    local __orig = PlayFromStart
    PlayFromStart = function(info)
      FS._play_request_id = (FS._play_request_id or 0) + 1
      local req_id = FS._play_request_id
      if FS_ensure_local_before_play(info, function()
        if FS._play_request_id == req_id then __orig(info) end
      end) == false then return end
      return __orig(info)
    end
  end
  if type(PlayFromCursor)=="function" then
    local __orig = PlayFromCursor
    PlayFromCursor = function(info)
      FS._play_request_id = (FS._play_request_id or 0) + 1
      local req_id = FS._play_request_id
      if FS_ensure_local_before_play(info, function()
        if FS._play_request_id == req_id then __orig(info) end
      end) == false then return end
      return __orig(info)
    end
  end

  -- 插入钩子
  if type(InsertSelectedToProject)=="function" then
    local __orig = InsertSelectedToProject
    InsertSelectedToProject = function(...)
      local args = {...}
      if selected_row and files_idx_cache and files_idx_cache[selected_row] then
        local target_row = selected_row
        local target_info = files_idx_cache[target_row]
        if FS_ensure_local_before_play(target_info, function()
          if selected_row == target_row and files_idx_cache and files_idx_cache[target_row] == target_info then
            __orig(table.unpack(args))
          end
        end) == false then return end
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
        if type(FS_MaybeSwapEntryPathToLocal) == "function" then
          FS_MaybeSwapEntryPathToLocal(info)
        end
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
local FS_DEFAULT_CLIENT_ID     = "7it2dpUb87V7Ks6RbqG8"
local FS_DEFAULT_CLIENT_SECRET = "ALoC8vU8WClGIfbimTYiMi3xp8xBe5X2nENomRIv"
local FS_DEFAULT_AUTH_CODE     = "ni867uXzDY35WAsXnTwx2Cdx3sZt1a"

local FS_K = {
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

function FS_OAuth_ClientID()
  return FS_DEFAULT_CLIENT_ID
end

function FS_OAuth_ClientSecret()
  return FS_DEFAULT_CLIENT_SECRET
end

function FS_OAuth_DefaultCode()
  return FS_DEFAULT_AUTH_CODE
end

-- 打开授权页
function FS_OAuth_OpenAuthorize()
  local client_id = FS_OAuth_ClientID()
  local redirect  = FS_get_es(FS_K.redir)
  if client_id == "" then
    reaper.MB("Built-in Freesound credentials are incomplete.", "Freesound OAuth2", 0)
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

  -- OAuth 令牌交换如果有 grant_type，不加 Bearer
  local is_oauth_token_exchange = (kvpairs and kvpairs.grant_type ~= nil)
  local need_bearer = (not is_oauth_token_exchange) and (FS and (FS.TOKEN or "") == "" and (FS.OAUTH_BEARER or "") ~= "")
  local hdr = need_bearer and (' -H "Authorization: Bearer ' .. (FS.OAUTH_BEARER:gsub('"','\\"')) .. '"') or ""

  local osname = reaper.GetOS()
  local is_win = osname and osname:find("Win") ~= nil

  -- 将数据写入临时文件，避免 macOS 下 & 等被 shell 解释
  local stamp = math.floor(reaper.time_precise() * 1e6)
  local tmp_dat = FS_join(FS_DB_DIR(), (".fs_http_%d.dat"):format(stamp))
  do
    local f = io.open(tmp_dat, "wb")
    if not f then return "" end
    f:write(data or "")
    f:close()
  end

  -- Windows 优先走 ExecProcess，避免CMD弹窗
  if is_win then
    local tmp_out = FS_join(FS_DB_DIR(), (".fs_http_%d.out"):format(stamp))
    local cmd = ('curl -L -s%s -X POST -H "Content-Type: application/x-www-form-urlencoded" ' .. '--data-binary "@%s" "%s" -o "%s"'):format(hdr, tmp_dat:gsub('"','\\"'), url:gsub('"','\\"'), tmp_out:gsub('"','\\"'))
    local code = tonumber(reaper.ExecProcess(cmd, 120000)) or -1
    local body = ""
    local f = io.open(tmp_out, "rb")
    if f then
      body = f:read("*a") or ""
      f:close()
    end
    os.remove(tmp_out)
    os.remove(tmp_dat)
    return (code == 0) and body or ""
  end

  -- macOS/Linux 用 /usr/bin/curl; Windows 作为回退用 curl
  local curl_bin = is_win and "curl" or "/usr/bin/curl"
  local p = io.popen(('%s -L -s%s -X POST -H "Content-Type: application/x-www-form-urlencoded" --data-binary "@%s" "%s"'):format(curl_bin, hdr, tmp_dat:gsub('"','\\"'), url:gsub('"','\\"')), "r")
  local body = p and p:read("*a") or ""
  if p then p:close() end
  os.remove(tmp_dat)
  return body
end

-- 用内置授权换取 OAuth2 令牌
function FS_OAuth_ExchangeCode(auth_code, silent)
  auth_code = tostring(auth_code or "")
  if auth_code == "" then auth_code = FS_OAuth_DefaultCode() end
  local client_id     = FS_OAuth_ClientID()
  local client_secret = FS_OAuth_ClientSecret()
  -- local redirect_uri  = FS_get_es(FS_K.redir)

  if client_id=="" or client_secret=="" then
    if not silent then reaper.MB("Built-in Freesound credentials are incomplete.", "Freesound OAuth2", 0) end
    return false
  end
  if auth_code=="" then
    if not silent then reaper.MB("Built-in Freesound authorization is incomplete.", "Freesound OAuth2", 0) end
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
    if not silent then reaper.MB(("Token exchange failed:\n%s"):format(tostring(reason or "")), "Freesound OAuth2", 0) end
    return false
  end

  -- 保存 token
  FS_set_es(FS_K.acc, obj.access_token or "")
  FS_set_es(FS_K.ref, obj.refresh_token or "")

  FS.OAUTH_BEARER = obj.access_token or ""
  FS.ui = FS.ui or {}
  FS.ui.oauth_code = ""
  FS.ui._oauth_just_saved = true

  -- reaper.MB("OAuth2 Access Token 已保存。", "Freesound OAuth2", 0)
  if not silent then reaper.MB("OAuth2 access token saved.", "Freesound OAuth2", 0) end
  return true
end

-- 刷新 Access Token
function FS_OAuth_Refresh(silent)
  local client_id     = FS_OAuth_ClientID()
  local client_secret = FS_OAuth_ClientSecret()
  local refresh_token = FS_get_es(FS_K.ref)
  if client_id=="" or client_secret=="" or refresh_token=="" then
    if not silent then reaper.MB("Freesound needs to connect once before it can refresh the access token.", "Freesound OAuth2", 0) end
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

function FS_OAuth_EnsureReady(silent)
  local acc = FS_get_es(FS_K.acc)
  if acc ~= "" then
    FS.OAUTH_BEARER = acc
    return true
  end

  if FS_get_es(FS_K.ref) ~= "" and FS_OAuth_Refresh(true) then
    return true
  end

  if (FS.ui and FS.ui._default_oauth_failed) then
    return false
  end

  local ok = FS_OAuth_ExchangeCode(FS_OAuth_DefaultCode(), true)
  if not ok then
    FS.ui = FS.ui or {}
    FS.ui._default_oauth_failed = true
    if not silent then
      reaper.MB("Freesound built-in authorization failed. Please update the built-in Freesound authorization in the script.", "Freesound OAuth2", 0)
    end
  end
  return ok
end

function FS_DrawApiTokenField(ctx)
  FS.OAUTH_BEARER = FS_get_es(FS_K.acc)
end

-- Freesound 标签页 UI
function FS_DrawSidebar(ctx)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), 0x00000000)
  reaper.ImGui_PopStyleColor(ctx)
  reaper.ImGui_Indent(ctx, 8)

  -- 激活 Freesound 模式
  do
    local is_fs_mode = (collect_mode == COLLECT_MODE_FREESOUND)
    local changed_enabled, want_enable = reaper.ImGui_Checkbox(ctx, T("Activate Freesound mode"), is_fs_mode)

    if changed_enabled then
      if want_enable then
        -- 记住上一个模式以便回退
        FS._last_collect_mode = collect_mode
        collect_mode = COLLECT_MODE_FREESOUND
        FS_OAuth_EnsureReady(true)
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

  reaper.ImGui_SeparatorText(ctx, T("Search Sounds"))

  -- 搜索框
  reaper.ImGui_Text(ctx, T("Search"))
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_SetNextItemWidth(ctx, -10)

  local _, q_val = reaper.ImGui_InputText(ctx, "##fs_query", FS_get_query())
  if q_val ~= nil then FS_set_query(q_val) end

  -- Arrange by
  reaper.ImGui_Text(ctx, T("Arrange by"))
  reaper.ImGui_SameLine(ctx)
  local arr = { "Timbre", "Tonality" }
  reaper.ImGui_SetNextItemWidth(ctx, -10)
  local arr_changed, arr_idx0 = reaper.ImGui_Combo(ctx, "##fs_arrange", (FS.ui.arrange_idx or 1)-1, __z(arr))
  if arr_changed then FS.ui.arrange_idx = (arr_idx0 or 0) + 1 end

  -- Sort by
  reaper.ImGui_Text(ctx, T("Sort by"))
  reaper.ImGui_SameLine(ctx)
  local sorts = {
    "Relevance","Rating","Duration","Downloads",
    "Creation Date (newest first)","Creation Date (oldest first)"
  }
  reaper.ImGui_SetNextItemWidth(ctx, -10)
  local s_changed, s_idx0 = reaper.ImGui_Combo(ctx, "##fs_sort", (FS.ui.sort_idx or 1)-1, __z(sorts))
  if s_changed then FS.ui.sort_idx = (s_idx0 or 0) + 1 end

  -- Number of results
  reaper.ImGui_Text(ctx, T("Number of results"))
  reaper.ImGui_SetNextItemWidth(ctx, -10)
  local nr_changed, nr = reaper.ImGui_SliderInt(ctx, "##fs_num", FS.ui.num_results or 200, 1, 450)
  if nr_changed then FS.ui.num_results = nr end

  -- Maximum duration
  reaper.ImGui_Text(ctx, T("Maximum duration"))
  reaper.ImGui_SetNextItemWidth(ctx, -10)
  local md_changed, md = reaper.ImGui_SliderDouble(ctx, "##fs_maxdur", FS.ui.max_minutes or 7.5, 0.5, 30.0, "%.1f")
  if md_changed then FS.ui.max_minutes = md end

  local changed_ad, val_ad = reaper.ImGui_Checkbox(ctx, T("Auto-download search results"), FS.AUTO_DOWNLOAD_RESULTS)
  if changed_ad then
    FS.AUTO_DOWNLOAD_RESULTS = val_ad
    reaper.SetExtState(EXT_SECTION, "fs_auto_download_results", (val_ad and "1" or "0"), true)
  end
  reaper.ImGui_SameLine(ctx)
  HelpMarker(T("After a Freesound search finishes, queue every result in the list for background download. Existing cached files are reused."))

  FS_DrawApiTokenField(ctx)

  local avail_w = select(1, reaper.ImGui_GetContentRegionAvail(ctx))
  local gap = 10 -- 两按钮之间的间距
  local w1 = math.max(0, math.floor((avail_w - gap) * 0.5))
  local w2 = math.max(0, avail_w - gap - w1 - 9)

  -- 清空回到本地增量库
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        colors.fs_button_normal  or 0x274160FF) -- 常态
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), colors.fs_button_hovered or 0x3B7ECEFF) -- 悬停
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  colors.fs_button_active  or 0x4296FAFF) -- 按下
  if reaper.ImGui_Button(ctx, T("Clear (show local cache)"), w1, 40) then
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
  reaper.ImGui_PopStyleColor(ctx, 3)

  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        colors.fs_search_button_normal  or 0xFFF2994A) -- 常态
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), colors.fs_search_button_hovered or 0xFFFFA858) -- 悬停
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  colors.fs_search_button_active  or 0xFFF2998B) -- 按下
  if reaper.ImGui_Button(ctx, T("Search"), w2, 40) then
    local q = FS_get_query():match("^%s*(.-)%s*$")
    FS_OAuth_EnsureReady(true)

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

      local has_search_error = ((wrote_total or 0) == 0 and (err_excerpt or "") ~= "")
      if FS.AUTO_DOWNLOAD_RESULTS and files_idx_cache and not has_search_error then
        FS_QueueDownloadList(files_idx_cache)
      end

      if has_search_error then
        -- reaper.ShowMessageBox("Freesound：未获得结果或 API 响应异常。\n"..tostring(err_excerpt), "Soundmole", 0)
        reaper.ShowMessageBox("Freesound: No results or an unexpected API response.\n" .. tostring(err_excerpt), "Soundmole", 0)
      end
    end
  end
  reaper.ImGui_PopStyleColor(ctx, 3)

  -- OAuth2 设置
  reaper.ImGui_SeparatorText(ctx, T("Original File Access (OAuth2 Settings)"))
  local changed_uo, val_uo = reaper.ImGui_Checkbox(ctx, T("Prefer Original Files over Previews"), FS.USE_ORIGINAL)
  if changed_uo then
    FS.USE_ORIGINAL = val_uo
    reaper.SetExtState(EXT_SECTION, "fs_use_original", (val_uo and "1" or "0"), true)
    if val_uo then FS_OAuth_EnsureReady(true) end
  end
  reaper.ImGui_SameLine(ctx)
  HelpMarker(T("Download/preview the original audio via OAuth2 (requires a valid access token). Uses the original file instead of the MP3/OGG preview."))

  FS.ui = FS.ui or {}
  local has_acc = (FS_get_es(FS_K.acc) ~= "") or ((FS.OAUTH_BEARER or "") ~= "")
  reaper.ImGui_Text(ctx, has_acc and T("Freesound authorization: ready") or T("Freesound authorization: built-in"))
  local dl_count = 0
  if FS.download_jobs then
    for _ in pairs(FS.download_jobs) do dl_count = dl_count + 1 end
  end
  local queued_count = 0
  if FS.download_queue then
    queued_count = math.max(0, #FS.download_queue - (tonumber(FS.download_queue_pos or 1) or 1) + 1)
  end
  if dl_count > 0 or queued_count > 0 then
    if queued_count > 0 then
      reaper.ImGui_Text(ctx, (T("Downloads running: %d, queued: %d")):format(dl_count, queued_count))
    else
      reaper.ImGui_Text(ctx, (T("Downloads running: %d")):format(dl_count))
    end
  elseif FS.ui and FS.ui.download_status and FS.ui.download_status ~= "" then
    reaper.ImGui_Text(ctx, FS.ui.download_status)
  end

  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        colors.fs_button_normal  or 0x274160FF) -- 常态
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), colors.fs_button_hovered or 0x3B7ECEFF) -- 悬停
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  colors.fs_button_active  or 0x4296FAFF) -- 按下
  if reaper.ImGui_Button(ctx, has_acc and T("Reconnect Freesound") or T("Connect Freesound"), -10, 40) then
    if has_acc then
      if not FS_OAuth_Refresh(false) then
        FS.ui._default_oauth_failed = nil
        FS_OAuth_EnsureReady(false)
      end
    else
      FS.ui._default_oauth_failed = nil
      FS_OAuth_EnsureReady(false)
    end
  end

  if FS.ui and FS.ui._oauth_just_saved then
    FS.ui._oauth_just_saved = nil
  end

  if reaper.ImGui_Button(ctx, T("Repair Freesound authorization"), -10, 40) then
    if not FS_OAuth_Refresh(false) then
      FS.ui._default_oauth_failed = nil
      FS_OAuth_EnsureReady(false)
    end
  end
  -- reaper.ImGui_SameLine(ctx)
  reaper.ImGui_SeparatorText(ctx, T("Reset Freesound Authorization"))
  if reaper.ImGui_Button(ctx, T("Reset Freesound authorization"), -10, 40) then
    FS_set_es(FS_K.acc, "")
    FS_set_es(FS_K.ref, "")
    -- 同步清理内存态
    FS.OAUTH_BEARER = ""
    FS.ui.oauth_code = ""
    FS.ui._default_oauth_failed = nil
    FS.ui._oauth_just_saved = true
  end
  reaper.ImGui_PopStyleColor(ctx, 3)
  -- HelpMarker("Uses the built-in Freesound OAuth2 credentials. Repair only when Freesound search or original-file downloads start failing (e.g., 401/403).\n")

  reaper.ImGui_EndDisabled(ctx)
  reaper.ImGui_Unindent(ctx, 8)
end

M.FS = FS
return M
