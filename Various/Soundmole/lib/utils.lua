-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"

local sep = package.config:sub(1, 1)

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

-- function EnsureCacheDir(cache_dir)
--   local sep = package.config:sub(1, 1)
--   if not reaper.EnumerateFiles(cache_dir, 0) then
--     os.execute((sep == "/" and "mkdir -p " or "mkdir ") .. '"' .. cache_dir .. '"')
--   end
-- end
function EnsureCacheDir(dir)
  if not reaper.file_exists(dir) then
    reaper.RecursiveCreateDirectory(dir, 0)
  end
end