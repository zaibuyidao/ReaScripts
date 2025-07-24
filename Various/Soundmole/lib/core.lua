-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"

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