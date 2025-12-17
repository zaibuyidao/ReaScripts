-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"
script_path = script_path:gsub("[/\\]+$","")
script_path = script_path:gsub("[/\\]lib$","") -- 确保不在lib目录下

local sep = package.config:sub(1, 1)
script_path = script_path .. sep

local HAVE_SM_EXT = reaper.APIExists('SM_ProbeMediaBegin') and reaper.APIExists('SM_ProbeMediaNextJSONEx') and reaper.APIExists('SM_ProbeMediaEnd') and reaper.APIExists('SM_GetPeaksCSV')

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

-- 相对路径解析为绝对路径
function resolve_rpp_path(p)
  if not p or p == "" then return "" end
  -- 绝对路径 / UNC 直接归一化
  if p:match('^%a:[/\\]') or p:match('^\\\\') then
    return normalize_path(p, false)
  end
  -- 相对路径，拼接工程目录
  local _, projfn = reaper.EnumProjects(-1, "")
  local base = (projfn and projfn:match("^(.*)[/\\]")) or (reaper.GetProjectPath("") or "")
  if base == "" then
    return normalize_path(p, false) -- 工程未保存时兜底
  end
  return normalize_path(base .. sep .. p, false)
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

-- 按扩展名判断是否为音频. 与IsValidAudioFile(path)重复
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

-- 把 valid_exts 表转成 "wav,flac,..." CSV
function exts_table_to_csv(t)
  local tmp = {}
  for k, v in pairs(t) do if v then tmp[#tmp+1] = k end end
  table.sort(tmp)
  return table.concat(tmp, ",")
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

-- 缩短行高的换行
function TightNewLine(ctx, scale)
  scale = scale or 0.7
  local lh = reaper.ImGui_GetTextLineHeightWithSpacing(ctx)
  -- 用 Dummy 精确推进垂直光标，避免默认的 NewLine 高度
  reaper.ImGui_Dummy(ctx, 0, lh * scale)
end

----------------------------------------------------------------
-- 查询 action 绑定的快捷键
----------------------------------------------------------------

function SM_NormalizeActionCommandID(cmd)
  if cmd == nil then return nil end
  if type(cmd) == "number" then
    return tostring(math.floor(cmd))
  end
  cmd = tostring(cmd)
  if cmd:match("^%d+$") then return cmd end
  if cmd:sub(1, 1) == "_" then return cmd end

  local looked = reaper.NamedCommandLookup(cmd)
  if looked and looked ~= 0 then
    return tostring(looked)
  end
  return cmd
end

-- 读取 reaper-kb.ini
function SM_ReadReaperKBIniText()
  local kb = reaper.GetResourcePath() .. sep .. "reaper-kb.ini"
  local f = io.open(kb, "rb")
  if not f then return nil, kb end
  local s = f:read("*a") or ""
  f:close()
  return s, kb
end

-- 查询操作绑定的快捷键
function SM_GetActionShortcuts(cmd, section_filter)
  local cmd_norm = SM_NormalizeActionCommandID(cmd)
  if not cmd_norm or cmd_norm == "" then return {} end

  local text, kbpath = SM_ReadReaperKBIniText()
  if not text or text == "" then return {} end

  local out = {}
  for line in text:gmatch("[^\r\n]+") do
    if line:sub(1, 4) == "KEY " then
      local mod, key, act, sec = line:match("^KEY%s+([%-%d]+)%s+([%-%d]+)%s+([^%s]+)%s+([%-%d]+)")
      if mod and key and act and sec then
        local secn = tonumber(sec) or 0
        if secn ~= 102 and secn ~= 103 then
          if act == cmd_norm then
            if section_filter == nil or (tonumber(section_filter) == secn) then
              out[#out + 1] = {
                modifier = tonumber(mod) or 0,
                key      = tonumber(key) or 0,
                cmd      = act,
                section  = secn,
                kbpath   = kbpath,
              }
            end
          end
        end
      end
    end
  end
  return out
end

function SM_KeyValueToVK(keyvalue)
  local k = tonumber(keyvalue)
  if not k then return nil end
  return k
end

function SM_VKToName(vk)
  vk = tonumber(vk)
  if not vk then return "" end

  -- A-Z
  if vk >= 65 and vk <= 90 then
    return string.char(vk)
  end
  -- 0-9
  if vk >= 48 and vk <= 57 then
    return string.char(vk)
  end
  -- F1-F24
  if vk >= 112 and vk <= 135 then
    return "F" .. tostring(vk - 111)
  end

  local map = {
    [8]="Backspace",[9]="Tab",[13]="Enter",[27]="Esc",[32]="Space",
    [33]="PageUp",[34]="PageDown",[35]="End",[36]="Home",
    [37]="Left",[38]="Up",[39]="Right",[40]="Down",
    [45]="Insert",[46]="Delete",
  }
  return map[vk] or tostring(vk)
end