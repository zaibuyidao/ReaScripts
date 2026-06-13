-- NoIndex: true
-- Soundmole-owned persistent state. Runtime-only ExtState signals stay in REAPER.
local M = {}

local sep = package.config:sub(1, 1)
local module_dir = debug.getinfo(1, "S").source:match([[^@?(.*[\/])[^\/]-$]]) or ""
local root_dir = module_dir:gsub("[/\\]lib[/\\]$", sep)
local data_dir = root_dir .. "data"
local ini_path = data_dir .. sep .. "Soundmole.ini"
local api = reaper

local sections = {}
local loaded = false
local migrated_sections = {}
local transient_keys = {}
local dirty = false
local flush_scheduled = false
local atexit_registered = false

M.last_error = nil

local function file_exists(path)
  local f = io.open(path, "rb")
  if not f then return false end
  f:close()
  return true
end

local function ensure_data_dir()
  if api and api.RecursiveCreateDirectory then
    api.RecursiveCreateDirectory(data_dir, 0)
  end
end

local function escape_value(value)
  value = tostring(value or "")
  value = value:gsub("\\", "\\\\")
  value = value:gsub("\r", "\\r")
  value = value:gsub("\n", "\\n")
  value = value:gsub("\t", "\\t")
  value = value:gsub("[%z\1-\8\11\12\14-\31\127]", function(c)
    return string.format("\\x%02X", string.byte(c))
  end)
  return "@escaped:" .. value
end

local function unescape_value(value)
  if value:sub(1, 9) ~= "@escaped:" then return value end
  value = value:sub(10)
  local out = {}
  local i = 1
  while i <= #value do
    local c = value:sub(i, i)
    if c ~= "\\" then
      out[#out + 1] = c
      i = i + 1
    else
      local n = value:sub(i + 1, i + 1)
      if n == "n" then
        out[#out + 1] = "\n"
        i = i + 2
      elseif n == "r" then
        out[#out + 1] = "\r"
        i = i + 2
      elseif n == "t" then
        out[#out + 1] = "\t"
        i = i + 2
      elseif n == "\\" then
        out[#out + 1] = "\\"
        i = i + 2
      elseif n == "x" and value:sub(i + 2, i + 3):match("^%x%x$") then
        out[#out + 1] = string.char(tonumber(value:sub(i + 2, i + 3), 16))
        i = i + 4
      else
        out[#out + 1] = n ~= "" and n or "\\"
        i = i + (n ~= "" and 2 or 1)
      end
    end
  end
  return table.concat(out)
end

local function load_ini()
  if loaded then return end
  loaded = true
  sections = {}

  local source_path = ini_path
  if not file_exists(source_path) then
    if file_exists(ini_path .. ".bak") then
      source_path = ini_path .. ".bak"
      dirty = true
    elseif file_exists(ini_path .. ".tmp") then
      source_path = ini_path .. ".tmp"
      dirty = true
    end
  end

  local f = io.open(source_path, "rb")
  if not f then return end

  local current
  for line in f:lines() do
    line = line:gsub("\r$", "")
    local section = line:match("^%s*%[([^%]]+)%]%s*$")
    if section then
      current = section
      sections[current] = sections[current] or {}
    elseif current and not line:match("^%s*[;#]") then
      local key, value = line:match("^([^=]+)=(.*)$")
      if key then
        key = key:gsub("^%s+", ""):gsub("%s+$", "")
        if key ~= "" then sections[current][key] = unescape_value(value) end
      end
    end
  end
  f:close()
end

local function sorted_keys(tbl)
  local keys = {}
  for key in pairs(tbl or {}) do keys[#keys + 1] = key end
  table.sort(keys)
  return keys
end

local function copy_file(source_path, destination_path)
  local source, source_err = io.open(source_path, "rb")
  if not source then return false, source_err or "could not open temporary INI file" end
  local destination, destination_err = io.open(destination_path, "wb")
  if not destination then
    source:close()
    return false, destination_err or "could not open INI file"
  end

  while true do
    local chunk = source:read(65536)
    if not chunk then break end
    local ok, write_err = destination:write(chunk)
    if not ok then
      source:close()
      destination:close()
      return false, write_err or "could not write INI file"
    end
  end

  source:close()
  local ok, close_err = destination:close()
  if not ok then return false, close_err or "could not close INI file" end
  return true
end

local function replace_file(tmp_path)
  if os.rename(tmp_path, ini_path) then return true end

  local backup_path = ini_path .. ".bak"
  os.remove(backup_path)
  local had_original = file_exists(ini_path)
  if had_original and not os.rename(ini_path, backup_path) then
    local copied, copy_err = copy_file(tmp_path, ini_path)
    if copied then
      os.remove(tmp_path)
      return true
    end
    return false, copy_err or "could not create INI backup"
  end

  if os.rename(tmp_path, ini_path) then
    os.remove(backup_path)
    return true
  end

  if had_original then os.rename(backup_path, ini_path) end
  local copied, copy_err = copy_file(tmp_path, ini_path)
  if copied then
    os.remove(tmp_path)
    os.remove(backup_path)
    return true
  end
  return false, copy_err or "could not replace INI file"
end

function M.flush()
  load_ini()
  if not dirty then return true end
  ensure_data_dir()

  local tmp_path = ini_path .. ".tmp"
  local f, err = io.open(tmp_path, "wb")
  if not f then
    M.last_error = err or "could not open temporary INI file"
    return false, M.last_error
  end

  f:write("; Soundmole local persistent state.\n")
  f:write("; This file is user data and is not managed by REAPER or ReaPack.\n")
  f:write("; Values prefixed with @escaped: use \\\\, \\n, \\r, \\t and \\xHH escapes.\n")

  for _, section in ipairs(sorted_keys(sections)) do
    f:write("\n[", section, "]\n")
    for _, key in ipairs(sorted_keys(sections[section])) do
      f:write(key, "=", escape_value(sections[section][key]), "\n")
    end
  end

  local ok, close_err = f:close()
  if not ok then
    os.remove(tmp_path)
    M.last_error = close_err or "could not close temporary INI file"
    return false, M.last_error
  end

  local replaced, replace_err = replace_file(tmp_path)
  if not replaced then
    os.remove(tmp_path)
    M.last_error = replace_err
    return false, replace_err
  end

  dirty = false
  M.last_error = nil
  return true
end

local function schedule_flush()
  if api and api.atexit and not atexit_registered then
    atexit_registered = true
    api.atexit(function()
      if dirty then M.flush() end
    end)
  end

  if api and api.defer then
    if not flush_scheduled then
      flush_scheduled = true
      api.defer(function()
        flush_scheduled = false
        if dirty then M.flush() end
      end)
    end
    return true
  end
  return M.flush()
end

local function extstate_keys(section)
  if not (api and api.GetResourcePath) then return {} end
  local path = api.GetResourcePath() .. sep .. "reaper-extstate.ini"
  local f = io.open(path, "rb")
  if not f then return {} end

  local keys = {}
  local current
  for line in f:lines() do
    line = line:gsub("\r$", "")
    local found_section = line:match("^%s*%[([^%]]+)%]%s*$")
    if found_section then
      current = found_section
    elseif current == section and not line:match("^%s*[;#]") then
      local key = line:match("^([^=]+)=")
      if key then
        key = key:gsub("^%s+", ""):gsub("%s+$", "")
        if key ~= "" then keys[#keys + 1] = key end
      end
    end
  end
  f:close()
  return keys
end

function M.migrate_extstate_section(section)
  section = tostring(section or "")
  if section == "" or migrated_sections[section] then return true end
  migrated_sections[section] = true
  load_ini()

  local keys = extstate_keys(section)
  if #keys == 0 then
    if dirty then return schedule_flush() end
    return true
  end

  sections[section] = sections[section] or {}
  local imported = false
  for _, key in ipairs(keys) do
    if not transient_keys[key] and sections[section][key] == nil and api and api.GetExtState then
      sections[section][key] = api.GetExtState(section, key) or ""
      imported = true
      dirty = true
    end
  end

  if imported or dirty then
    local ok = M.flush()
    if not ok then return false, M.last_error end
  end

  if api and api.DeleteExtState then
    for _, key in ipairs(keys) do
      api.DeleteExtState(section, key, true)
    end
  end
  return true
end

function M.get(section, key)
  section, key = tostring(section or ""), tostring(key or "")
  M.migrate_extstate_section(section)
  load_ini()
  local value = sections[section] and sections[section][key]
  return value == nil and "" or value
end

function M.set(section, key, value)
  section, key = tostring(section or ""), tostring(key or "")
  if section == "" or key == "" then return false, "section and key are required" end
  M.migrate_extstate_section(section)
  load_ini()
  sections[section] = sections[section] or {}
  value = tostring(value or "")
  if sections[section][key] == value then return true end
  sections[section][key] = value
  dirty = true
  return schedule_flush()
end

function M.delete(section, key)
  section, key = tostring(section or ""), tostring(key or "")
  M.migrate_extstate_section(section)
  load_ini()
  if not sections[section] or sections[section][key] == nil then return true end
  sections[section][key] = nil
  if next(sections[section]) == nil then sections[section] = nil end
  dirty = true
  return schedule_flush()
end

function M.install_state_facade(keys)
  transient_keys = {}
  for _, key in ipairs(keys or {}) do transient_keys[tostring(key)] = true end

  local function require_persistent_key(key)
    key = tostring(key or "")
    if transient_keys[key] then
      error("runtime key must use SM_GetRuntimeState/SM_SetRuntimeState: " .. key, 3)
    end
  end

  local function require_runtime_key(key)
    key = tostring(key or "")
    if not transient_keys[key] then
      error("unregistered runtime state key: " .. key, 3)
    end
  end

  _G.SM_GetState = function(section, key)
    require_persistent_key(key)
    return M.get(section, key)
  end

  _G.SM_SetState = function(section, key, value, persist)
    require_persistent_key(key)
    if persist == false then
      error("SM_SetState is persistent; use SM_SetRuntimeState for runtime-only values", 2)
    end
    return M.set(section, key, value)
  end

  _G.SM_DeleteState = function(section, key)
    require_persistent_key(key)
    return M.delete(section, key)
  end

  _G.SM_GetRuntimeState = function(section, key)
    require_runtime_key(key)
    return (api and api.GetExtState and api.GetExtState(section, key)) or ""
  end

  _G.SM_SetRuntimeState = function(section, key, value)
    require_runtime_key(key)
    if api and api.SetExtState then return api.SetExtState(section, key, tostring(value or ""), false) end
    return false
  end
end

function M.configure(opts)
  opts = opts or {}
  api = opts.reaper_api or api
  if opts.ini_path and opts.ini_path ~= "" then
    ini_path = opts.ini_path
    data_dir = ini_path:match("^(.*)[/\\][^/\\]+$") or "."
  end
  sections = {}
  loaded = false
  migrated_sections = {}
  dirty = false
  flush_scheduled = false
  atexit_registered = false
  M.last_error = nil
end

function M.path()
  return ini_path
end

return M
