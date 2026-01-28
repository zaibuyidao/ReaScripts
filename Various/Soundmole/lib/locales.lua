-- NoIndex: true
local Locales = {}
local db = {}
local CONTEXT_SEP = "#"

local info = debug.getinfo(1, 'S')
local lib_path = info.source:match([[^@?(.*[\/])[^\/]-$]])
local sep = package.config:sub(1, 1)
local root_path = lib_path:match("(.*)" .. "lib" .. "[\\/]$") or lib_path
local locales_folder = root_path .. "lang" .. sep

function Locales.load(lang_code)
  db = {}
  -- 拼凑完整文件路径
  local file_path = locales_folder .. lang_code .. ".txt"

  local f = io.open(file_path, "r")
  if not f then
    -- reaper.ShowConsoleMsg("[Soundmole] 警告: 找不到语言文件: " .. file_path .. "\n")
    return false
  end

  for line in f:lines() do
    line = line:gsub("//.*$", ""):match("^%s*(.-)%s*$")
    if line ~= "" and line:sub(1,1) ~= "#" then
    local key, val = line:match("^(.-)=(.*)$")
      if key and val then
        key = key:match("^%s*(.-)%s*$")
        val = val:match("^%s*(.-)%s*$")
        val = val:gsub("\\n", "\n") -- 处理换行
        db[key] = val
      end
    end
  end
  f:close()
  return true
end

function Locales.get(str, ...)
  local val = db[str]

  if not val then
    local base_text = str:match("^(.*)" .. CONTEXT_SEP)
    if base_text then
      val = db[base_text]
    end
    val = val or (base_text or str)
  end

  local args = {...}
  if #args > 0 then
    -- 只有当有参数时才格式化，避免 % 符号报错
    local status, res = pcall(string.format, val, table.unpack(args))
    if status then return res else return val end
  end
  return val
end

return Locales