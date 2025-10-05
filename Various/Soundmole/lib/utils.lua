-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"
script_path = script_path:gsub("[/\\]+$","")
script_path = script_path:gsub("[/\\]lib$","") -- 确保不在lib目录下

local sep = package.config:sub(1, 1)
script_path = script_path .. sep

-- 规范分隔符，传 true 表示是文件夹
function normalize_path(path, is_dir)
  if not path then return "" end
  if reaper.GetOS():find("Win") then
    path = path:gsub("/", "\\")
    -- 合并所有连续的反斜杠为一个
    path = path:gsub("\\+", "\\")
    -- 处理盘符后多余斜杠，如 E:\\\ 变为 E:\
    path = path:gsub("^(%a:)[\\]+", "%1\\")
    -- 文件夹结尾补斜杠，且只补一个
    if is_dir then
      path = path:gsub("\\+$", "") .. "\\"
    end
  else
    -- 合并所有连续的斜杠为一个
    path = path:gsub("/+", "/")
    if is_dir then
      path = path:gsub("/+$", "") .. "/"
    end
  end
  return path
end

function EnsureCacheDir(dir)
  if not reaper.file_exists(dir) then
    reaper.RecursiveCreateDirectory(dir, 0)
  end
end

--------------------------------------------- C++扩展支持 ---------------------------------------------

-- 将秒级时间戳转为 "YYYY/M/D HH:MM:SS"
function format_ts(ts)
  ts = tonumber(ts)
  if not ts or ts <= 0 then return "" end
  local t = os.date("*t", ts)
  return string.format("%d/%d/%d %02d:%02d:%02d", t.year, t.month, t.day, t.hour, t.min, t.sec)
end

-- 把数值安全转为整数。优先 tointeger，其次四舍五入
function to_int(x)
  local n = tonumber(x)
  if not n then return 0 end
  return math.tointeger(n) or math.floor(n + 0.5)
end

-- 按扩展名判断是否为音频
function has_allowed_ext(p)
  if not p or p == "" then return false end
  local ext = p:match("%.([^.]+)$")
  if not ext then return false end
  ext = ext:lower()
  return (ext == "wav" or ext == "w64" or ext == "aif" or ext == "aiff"
    or ext == "mp3" or ext == "ogg" or ext == "opus" or ext == "flac"
    or ext == "ape" or ext == "wv"  or ext == "m4a"  or ext == "aac"
    or ext == "mp4"
  )
end

-- 解析元数据
function sm_parse_ndjson_line(line)
  local function get_str(k)
    return (line:match('"'..k..'":"(.-)"')) or "" -- 纯字符串字段
  end
  local function get_num(k)
    local v = line:match('"'..k..'":([%-%d%.]+)')
    return v and tonumber(v) or 0
  end
  return {
    path           = get_str("path"),
    size           = get_num("size"),
    mtime          = get_num("mtime"),
    sr             = get_num("sr"),
    ch             = get_num("ch"),
    len            = get_num("len"),
    bits           = get_str("bits"), -- 在C++中由SWS扩展回传
    type           = get_str("type"),
    genre          = get_str("genre"),
    comment        = get_str("comment"),
    description    = get_str("description"),
    key            = get_str("key"),
    bpm            = get_str("bpm"),
    ucs_category   = get_str("ucs_category"),
    ucs_subcategory= get_str("ucs_subcategory"),
    ucs_catid      = get_str("ucs_catid"),
  }
end