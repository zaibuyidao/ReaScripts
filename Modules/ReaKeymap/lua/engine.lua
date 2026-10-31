-- @noindex
return function(reaper, JSON)
local SCRIPT_VERSION, PRESET_VERSION = '0.1.0', 1
local function path_join(...)
  local parts = {...}
  local result = tostring(parts[1] or '')
  local sep = package.config:sub(1, 1)
  for i = 2, #parts do
    local part = tostring(parts[i] or '')
    result = result:gsub('[/\\]+$', '') .. sep .. part:gsub('^[/\\]+', '')
  end
  return result
end

local RESOURCE_PATH = reaper.GetResourcePath()
local DATA_ROOT = path_join(RESOURCE_PATH, 'Data', 'ReaKeymap')
local PRESETS_DIR = path_join(DATA_ROOT, 'Presets')
local BACKUPS_DIR = path_join(DATA_ROOT, 'Backups')
local SETTINGS_PATH = path_join(DATA_ROOT, 'web-settings.json')
local USER_DATA_PATH = path_join(DATA_ROOT, 'userdata.json')

reaper.RecursiveCreateDirectory(DATA_ROOT, 0)
reaper.RecursiveCreateDirectory(PRESETS_DIR, 0)
reaper.RecursiveCreateDirectory(BACKUPS_DIR, 0)

function read_file(path)
  local file, err = io.open(path, 'rb')
  if not file then return nil, err end
  local data = file:read('*a')
  file:close()
  return data
end

function write_file(path, data)
  -- Stage bytes first. Keep the prior file recoverable until rename succeeds.
  local temp = path .. '.tmp'
  local previous = path .. '.previous'
  local file, err = io.open(temp, 'wb')
  if not file then return false, err end
  local ok, write_err = file:write(data or '')
  local closed, close_err = file:close()
  if not ok then return false, write_err end
  if not closed then return false, close_err end
  local exists = read_file(path) ~= nil
  if exists then
    if read_file(previous) then
      local removed, remove_err = os.remove(previous)
      if not removed then return false, remove_err end
    end
    local moved, move_err = os.rename(path, previous)
    if not moved then return false, move_err end
  end
  local moved, move_err = os.rename(temp, path)
  if not moved then
    if exists then os.rename(previous, path) end
    return false, move_err
  end
  return true
end

function copy_array(source)
  local result = {}
  for i, value in ipairs(source or {}) do result[i] = value end
  return result
end

function table_count(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do count = count + 1 end
  return count
end

function trim(value)
  return tostring(value or ''):match('^%s*(.-)%s*$')
end

function lower(value)
  return tostring(value or ''):lower()
end

function natural_compare(left, right)
  local a, b = lower(left), lower(right)
  local ai, bi = 1, 1
  local a_len, b_len = #a, #b

  while ai <= a_len and bi <= b_len do
    local a_is_digit = a:sub(ai, ai):match('%d') ~= nil
    local b_is_digit = b:sub(bi, bi):match('%d') ~= nil
    if a_is_digit and b_is_digit then
      local a_run = a:sub(ai):match('^%d+')
      local b_run = b:sub(bi):match('^%d+')
      local a_number = a_run:gsub('^0+', '')
      local b_number = b_run:gsub('^0+', '')
      if a_number == '' then a_number = '0' end
      if b_number == '' then b_number = '0' end
      if #a_number ~= #b_number then return #a_number < #b_number and -1 or 1 end
      if a_number ~= b_number then return a_number < b_number and -1 or 1 end
      if #a_run ~= #b_run then return #a_run < #b_run and -1 or 1 end
      ai, bi = ai + #a_run, bi + #b_run
    else
      local a_run = a:sub(ai):match('^%D+') or ''
      local b_run = b:sub(bi):match('^%D+') or ''
      if a_run ~= b_run then return a_run < b_run and -1 or 1 end
      ai, bi = ai + #a_run, bi + #b_run
    end
  end

  if ai > a_len and bi > b_len then return 0 end
  return ai > a_len and -1 or 1
end

function normalize_shortcut(value)
  return lower(trim(value)):gsub('%s+', ' ')
end

local SHORTCUT_KEY_ALIASES = {
  ['return'] = 'enter', ['esc'] = 'escape', ['spacebar'] = 'space',
  ['leftarrow'] = 'left', ['rightarrow'] = 'right',
  ['uparrow'] = 'up', ['downarrow'] = 'down',
  ['pgup'] = 'pageup', ['pgdn'] = 'pagedown',
  ['num0'] = 'keypad0', ['num1'] = 'keypad1', ['num2'] = 'keypad2',
  ['num3'] = 'keypad3', ['num4'] = 'keypad4', ['num5'] = 'keypad5',
  ['num6'] = 'keypad6', ['num7'] = 'keypad7', ['num8'] = 'keypad8',
  ['num9'] = 'keypad9', ['num.'] = 'keypaddecimal',
  ['num/'] = 'keypaddivide', ['num*'] = 'keypadmultiply',
  ['num-'] = 'keypadsubtract', ['num+'] = 'keypadadd',
  ['numenter'] = 'keypadenter', ['num='] = 'keypadequal',
  ['keypad+'] = 'keypadadd', ['keypad-'] = 'keypadsubtract',
  ['keypad*'] = 'keypadmultiply', ['keypad/'] = 'keypaddivide',
}

function shortcut_canonical(value)
  local text = lower(trim(value)):gsub('%s*%+%s*', '+')
  text = text:gsub('⌘', 'cmd+'):gsub('⌥', 'alt+')
    :gsub('⇧', 'shift+'):gsub('⌃', 'ctrl+')
    :gsub('control%s*%+', 'ctrl+')
    :gsub('command%s*%+', 'cmd+')
    :gsub('option%s*%+', 'alt+')
    :gsub('opt%s*%+', 'alt+')
    :gsub('meta%s*%+', 'cmd+')

  local ctrl = text:find('ctrl+', 1, true) ~= nil
  local shift = text:find('shift+', 1, true) ~= nil
  local alt = text:find('alt+', 1, true) ~= nil
  local super = text:find('cmd+', 1, true) ~= nil
    or text:find('win+', 1, true) ~= nil
    or text:find('super+', 1, true) ~= nil
  text = text:gsub('ctrl%+', ''):gsub('shift%+', ''):gsub('alt%+', '')
    :gsub('cmd%+', ''):gsub('win%+', ''):gsub('super%+', '')
    :gsub('%s+', '')
  text = SHORTCUT_KEY_ALIASES[text] or text
  return (ctrl and 'C' or '') .. (shift and 'S' or '') .. (alt and 'A' or '')
    .. (super and 'M' or '') .. ':' .. text
end

function normalize_path(value)
  local path = lower(tostring(value or ''):gsub('\\', '/'):gsub('^%s+', ''):gsub('%s+$', ''))
  return path:gsub('^scripts/', '')
end

function display_script_path(value)
  local path = tostring(value or ''):gsub('\\', '/')
  if path == '' or path:match('^%a:/') or path:match('^/') or lower(path):match('^scripts/') then return path end
  return 'Scripts/' .. path
end

function script_directory(path)
  if path == '' then return '' end
  local relative = path:gsub('\\','/')
  if relative:sub(1,8):lower() == 'scripts/' then relative = relative:sub(9) end
  local directory = relative:match('^(.*)/[^/]*$')
  return directory == nil and '(脚本)' or directory == '' and '/' or directory
end

function contains_plain(haystack, needle)
  return lower(haystack):find(lower(needle), 1, true) ~= nil
end

function utc_offset_time()
  local now = os.time()
  local local_t = os.date('*t', now)
  local utc_t = os.date('!*t', now)
  local_t.isdst = false
  utc_t.isdst = false
  local offset = os.difftime(os.time(local_t), os.time(utc_t))
  local sign = offset >= 0 and '+' or '-'
  offset = math.abs(offset)
  return os.date('%Y-%m-%dT%H:%M:%S', now)
    .. ('%s%02d:%02d'):format(sign, math.floor(offset / 3600), math.floor(offset % 3600 / 60))
end

function timestamp_for_file()
  return os.date('%Y-%m-%d_%H%M%S')
end

function safe_filename(value)
  local name = trim(value):gsub('[<>:"/\\|?*%c]', '_'):gsub('[%.%s]+$', '')
  if name == '' then name = 'ShortcutPreset_' .. timestamp_for_file() end
  return name
end

local DEFAULT_SETTINGS = {
  current_section_id = 0,
  all_sections_view = true,
  left_panel_width = 205,
  detail_panel_width = 300,
  view_mode = 'managed',
  all_sections_view_mode = 'bound',
  managed_init_from_bound = true,
  type_filter = 'all',
  auto_refresh = true,
  auto_refresh_interval = 5,
  custom_sections = {},
  keep_detail_open = true,
  show_row_checkboxes = false,
  language = 'en',
  theme = 'midnight',
  colorBackground = '#221f22',
  colorPanel = '#221f22',
  colorText = '#eeeeee',
  colorAccent = '#78dce6',
  colorBorder = '#19181a',
  show_alt_recording = false,
  show_alt_sections = false,
}

function load_json_file(path, fallback)
  local raw = read_file(path)
  if not raw then
    if read_file(path .. '.previous') then error('发现未完成的数据写入，请先从 .previous 文件恢复：' .. path, 0) end
    return fallback
  end
  local value, err = JSON.decode(raw)
  if type(value) ~= 'table' or value == JSON.null then
    error('数据文件无效，已停止以避免覆盖原数据：' .. path .. '\n' .. tostring(err), 0)
  end
  return value
end

local legacy_settings = not read_file(SETTINGS_PATH) and load_json_file(path_join(DATA_ROOT, 'settings.json'), {}) or {}
local settings = load_json_file(SETTINGS_PATH, legacy_settings)
for key, value in pairs(DEFAULT_SETTINGS) do
  if settings[key] == nil then settings[key] = value end
end

if not ({en=true,['zh-CN']=true,['zh-TW']=true,ja=true,ko=true})[settings.language] then settings.language='en' end
if not ({reaper=true,modern=true,retro=true,serious=true,cyber=true,warm=true,cold=true,anime=true,forest=true,mono=true,midnight=true,custom=true})[settings.theme] then settings.theme='midnight' end
if type(settings.colorBackground)~='string' or not settings.colorBackground:match('^#%x%x%x%x%x%x$') then settings.colorBackground='#221f22' end
if type(settings.colorPanel)~='string' or not settings.colorPanel:match('^#%x%x%x%x%x%x$') then settings.colorPanel='#221f22' end
if type(settings.colorText)~='string' or not settings.colorText:match('^#%x%x%x%x%x%x$') then settings.colorText='#eeeeee' end
if type(settings.colorAccent)~='string' or not settings.colorAccent:match('^#%x%x%x%x%x%x$') then settings.colorAccent='#78dce6' end
if type(settings.colorBorder)~='string' or not settings.colorBorder:match('^#%x%x%x%x%x%x$') then settings.colorBorder='#19181a' end
if type(settings.custom_sections) ~= 'table' then settings.custom_sections = {} end

local user_data = load_json_file(USER_DATA_PATH, {})
local user_data_signature = read_file(USER_DATA_PATH)
if type(user_data.notes) ~= 'table' then user_data.notes = {} end
if type(user_data.managed) ~= 'table' then user_data.managed = {} end
for key, note in pairs(user_data.notes) do
  if type(key) ~= 'string' or type(note) ~= 'string' then error('userdata.json 的备注字段格式无效，已停止以保留原数据。', 0) end
end

function save_settings()
  return write_file(SETTINGS_PATH, JSON.encode(settings, true) .. '\n')
end

function save_user_data()
  if read_file(USER_DATA_PATH) ~= user_data_signature then
    return false, '用户数据已被其他实例修改，请关闭其他快捷键管理器并重新启动。'
  end
  local raw = JSON.encode(user_data, true) .. '\n'
  local ok, err = write_file(USER_DATA_PATH, raw)
  if ok then user_data_signature = raw end
  return ok, err
end

local BASE_SECTIONS = {
  {id = 0, name = 'Main'},
  {id = 32063, name = 'Media Explorer'},
  {id = 32060, name = 'MIDI Editor'},
  {id = 32061, name = 'MIDI Event List Editor'},
  {id = 32062, name = 'MIDI Inline Editor'},
  {id = 32065, name = 'Crossfade Editor'},
}

local sections, section_by_id = {}, {}
local state

function rebuild_sections()
  sections, section_by_id = {}, {}

  local function add_section(id, name, custom)
    id = tonumber(id)
    if not id or section_by_id[id] then return end
    local handle = reaper.SectionFromUniqueID(id)
    local visible = id == 100 and settings.show_alt_recording == true or id >= 1 and id <= 16 and settings.show_alt_sections == true or id ~= 100 and (id < 1 or id > 16)
    local section = {visible = visible, id = id, name = trim(name) ~= '' and trim(name) or ('Section ' .. id), handle = handle, custom = custom}
    sections[#sections + 1] = section
    section_by_id[id] = section
  end

  for _, section in ipairs(BASE_SECTIONS) do
    add_section(section.id, section.name, false)
    if section.id == 0 then
      add_section(100, 'Main (alt recording)', false)
      for id = 1,16 do add_section(id, 'Main (alt-' .. id .. ')', false) end
    end
  end

  for _, section in ipairs(settings.custom_sections) do add_section(section.id, section.name, true) end
  -- Capture newly enabled sections before allowing edits. Keep earlier snapshots
  -- when a section is hidden so history and restore never lose their identities.
  if state then
    local captured = {}; for _,id in ipairs(state.startup_section_ids) do captured[id]=true end
    for _,section in ipairs(sections) do
      if section.visible and section.handle and not captured[section.id] then
        state.startup_section_ids[#state.startup_section_ids+1]=section.id
        state.startup_capture_complete=false
      end
    end
  end
end

rebuild_sections()

if not section_by_id[tonumber(settings.current_section_id)] then
  settings.current_section_id = 0
  settings.all_sections_view = true
end

-- Session state. UI selection, search, sorting and editors are owned by Vue.
state = {
  all_sections_view = true,
  caches = {}, script_paths = {}, selected = {},
  status = '正在读取 REAPER 操作列表', status_kind = 'normal',
  presets = {}, history = {}, history_cursor = 0,
  startup_snapshot = {}, startup_section_ids = {}, startup_capture_index = 1,
  startup_capture_complete = false,
  last_auto_refresh = 0, action_prompt_active = false,
}
for _, section in ipairs(sections) do if section.visible and section.handle then state.startup_section_ids[#state.startup_section_ids + 1] = section.id end end

function set_status(message, kind)
  state.status = tostring(message or '')
  state.status_kind = kind or 'normal'
end

function tokenize_reaper_line(line)
  local tokens, position, length = {}, 1, #line
  while position <= length do
    while position <= length and line:sub(position, position):match('%s') do position = position + 1 end
    if position > length or line:sub(position, position) == '#' then break end
    if line:sub(position, position) == '"' then
      position = position + 1
      local value = {}
      while position <= length do
        local char = line:sub(position, position)
        if char == '"' then position = position + 1 break end
        if char == '\\' and position < length
            and (line:sub(position + 1, position + 1) == '"' or line:sub(position + 1, position + 1) == '\\') then
          position = position + 1
          value[#value + 1] = line:sub(position, position)
          position = position + 1
        else
          value[#value + 1] = char
          position = position + 1
        end
      end
      tokens[#tokens + 1] = table.concat(value)
    else
      local start = position
      while position <= length and not line:sub(position, position):match('%s') do position = position + 1 end
      tokens[#tokens + 1] = line:sub(start, position - 1)
    end
  end
  return tokens
end

function get_kb_ini_path()
  local ini = reaper.get_ini_file()
  local replaced, count = ini:gsub('[Rr][Ee][Aa][Pp][Ee][Rr]%.ini$', 'reaper-kb.ini')
  if count == 0 then return path_join(RESOURCE_PATH, 'reaper-kb.ini') end
  return replaced
end

function load_script_path_index()
  local index = {}
  local file = io.open(get_kb_ini_path(), 'rb')
  if not file then state.script_paths = index return end
  for line in file:lines() do
    if line:sub(1, 4) == 'SCR ' then
      local fields = tokenize_reaper_line(line)
      local section_id = tonumber(fields[3])
      local named_id = fields[4]
      local script_path = fields[6]
      if section_id and named_id and script_path then
        script_path = display_script_path(script_path)
        index[section_id .. ':' .. named_id] = script_path
        index[section_id .. ':_' .. named_id] = script_path
      end
    end
  end
  file:close()
  state.script_paths = index
end

function shortcut_signature()
  local data = read_file(get_kb_ini_path())
  if not data then return nil end
  local hash = 2166136261
  for i = 1, #data do
    hash = ((hash ~ data:byte(i)) * 16777619) & 0xffffffff
  end
  return ('%d:%08x'):format(#data, hash)
end

load_script_path_index()

function stable_action_key(section_id, command_id, named_id)
  local identity = trim(named_id)
  if identity == '' then identity = tostring(command_id) end
  return tostring(section_id) .. ':' .. identity
end

function command_type(name, named_id, script_path)
  if script_path ~= '' or lower(name):find('script:', 1, true) then return 'script' end
  if lower(name):find('custom:', 1, true) == 1
      or named_id:gsub('^_', ''):match('^[0-9a-fA-F]+$') and #named_id:gsub('^_', '') == 32 then
    return 'custom'
  end
  if named_id ~= '' then return 'extension' end
  return 'native'
end

function read_shortcuts(handle, command_id)
  local shortcuts = {}
  local count = reaper.CountActionShortcuts(handle, command_id)
  for index = 0, count - 1 do
    local ok, description = reaper.GetActionShortcutDesc(handle, command_id, index)
    if ok and trim(description) ~= '' then shortcuts[#shortcuts + 1] = description end
  end
  return shortcuts
end

local catalog_fields={'key','command_id','named_id','name','section_id','section_name','id_text','type','script_path','script_directory','note','shortcut_text','has_conflict'}

function same_catalog(a,b)
  if not a or #a.actions~=#b.actions then return false end
  for i,current in ipairs(b.actions) do
    local previous=a.actions[i]
    for _,field in ipairs(catalog_fields) do if previous[field]~=current[field] then return false end end
    if #previous.shortcuts~=#current.shortcuts then return false end
    for j,shortcut in ipairs(current.shortcuts) do if previous.shortcuts[j]~=shortcut then return false end end
  end
  return true
end

function scan_section(section_id)
  local section = section_by_id[tonumber(section_id)]
  if not section or not section.handle then return nil, '无法读取操作区段：' .. tostring(section_id) end

  local cache = {
    section = section,
    actions = {},
    by_key = {},
    by_command = {},
    by_named = {},
    by_path = {},
    by_name = {},
    shortcut_owners = {},
    shortcut_count = 0,
    bound_count = 0,
    conflict_count = 0,
    scanned_at = reaper.time_precise(),
  }

  local index = 0
  while index < 200000 do
    local command_id, name = reaper.kbd_enumerateActions(section.handle, index)
    if not command_id or command_id == 0 then break end
    name = name or reaper.kbd_getTextFromCmd(command_id, section.handle) or ''
    local reverse = (reaper.ReverseNamedCommandLookup(command_id) or ''):gsub('^_', '')
    local named_id = reverse ~= '' and ('_' .. reverse) or ''
    local script_path = state.script_paths[section.id .. ':' .. named_id]
      or state.script_paths[section.id .. ':' .. reverse] or ''
    local key = stable_action_key(section.id, command_id, named_id)
    local shortcuts = read_shortcuts(section.handle, command_id)
    local action = {
      key = key,
      section_id = section.id,
      section_name = section.name,
      command_id = command_id,
      named_id = named_id,
      named_id_text = reverse,
      name = name,
      script_path = script_path,
      script_directory = script_directory(script_path),
      shortcuts = shortcuts,
      shortcut_text = #shortcuts > 0 and table.concat(shortcuts, ', ') or '',
      note = user_data.notes[key] or '',
    }
    action.type = command_type(action.name, action.named_id, action.script_path)
    action.id_text = reverse ~= '' and reverse or tostring(command_id)
    cache.actions[#cache.actions + 1] = action
    cache.by_key[key] = action
    cache.by_command[tostring(command_id)] = action
    if named_id ~= '' then cache.by_named[named_id] = action end
    if script_path ~= '' then local p = normalize_path(script_path); if cache.by_path[p] == nil then cache.by_path[p] = action else cache.by_path[p] = false end end
    if cache.by_name[name] == nil then cache.by_name[name] = action else cache.by_name[name] = false end
    if #shortcuts > 0 then cache.bound_count = cache.bound_count + 1 end
    cache.shortcut_count = cache.shortcut_count + #shortcuts
    for _, shortcut in ipairs(shortcuts) do
      local normalized = normalize_shortcut(shortcut)
      cache.shortcut_owners[normalized] = cache.shortcut_owners[normalized] or {}
      cache.shortcut_owners[normalized][#cache.shortcut_owners[normalized] + 1] = action
    end
    index = index + 1
  end

  for _, owners in pairs(cache.shortcut_owners) do
    if #owners > 1 then
      cache.conflict_count = cache.conflict_count + 1
      for _, action in ipairs(owners) do action.has_conflict = true end
    end
  end

  local previous=state.caches[section.id]
  if same_catalog(previous,cache) then return previous end
  state.caches[section.id] = cache
  if state.all_sections_view then state.filter_dirty = true end
  return cache
end

function ensure_cache(section_id)
  return state.caches[tonumber(section_id)] or scan_section(section_id)
end

function refresh_section(section_id, quiet)
  load_script_path_index()
  local cache, err = scan_section(section_id)
  if not cache then set_status(err, 'error') return nil end
  if not quiet then
    set_status(('%s 已刷新：%d 个命令，%d 个快捷键'):format(
      cache.section.name, #cache.actions, cache.shortcut_count), 'success')
  end
  return cache
end

function request_all_sections_refresh()
  state.overview_refresh_index = 1
  set_status('正在刷新全部快捷键区段…', 'normal')
end

function action_identity(action)
  return {
    section_id = action.section_id,
    command_id = action.named_id == '' and action.command_id or nil,
    named_command_id = action.named_id_text,
    command_name = action.name,
    script_path = action.script_path,
  }
end

function record_from_action(action, include_note)
  return {
    section_id = action.section_id,
    section_name = action.section_name,
    command_id = action.named_id == '' and action.command_id or nil,
    named_command_id = action.named_id_text,
    command_name = action.name,
    shortcuts = copy_array(action.shortcuts),
    script_path = action.script_path,
    command_type = action.type,
    note = include_note ~= false and action.note or nil,
  }
end

function find_action(identity)
  if type(identity) ~= 'table' then return nil end
  local cache = ensure_cache(tonumber(identity.section_id))
  if not cache then return nil end
  local named_id = trim(identity.named_command_id or identity.named_id)
  if named_id ~= '' then
    local named = cache.by_named['_' .. named_id:gsub('^_', '')]
    if named then return named end
    local path = normalize_path(identity.script_path)
    return path ~= '' and cache.by_path[path] or nil
  end
  if tonumber(identity.command_id) then
    local candidate = cache.by_command[tostring(tonumber(identity.command_id))]
    if candidate and candidate.named_id == '' then return candidate end
    return nil
  end
  local path = normalize_path(identity.script_path)
  if path ~= '' then return cache.by_path[path] or nil end
  return cache.by_name[identity.command_name or identity.name] or nil
end

function action_has_shortcut(action, expected)
  local wanted = normalize_shortcut(expected)
  for _, shortcut in ipairs(action.shortcuts) do
    if normalize_shortcut(shortcut) == wanted then return true end
  end
  return false
end

function capture_identities(identities)
  local records = {}
  for _, identity in ipairs(identities or {}) do
    local action = find_action(identity)
    if action then records[#records + 1] = record_from_action(action, true) end
  end
  return records
end

function collect_records(section_ids, include_unbound, include_notes, selected_only)
  local records = {}
  local selected_set = state.selected
  for _, section_id in ipairs(section_ids or {}) do
    local cache = ensure_cache(section_id)
    if cache then
      for _, action in ipairs(cache.actions) do
        local include = include_unbound or #action.shortcuts > 0
        if selected_only then include = include and selected_set[action.key] end
        if include then records[#records + 1] = record_from_action(action, include_notes) end
      end
    end
  end
  return records
end

function preset_document(name, records, scope, explicit_section_ids)
  local section_map, shortcut_count = {}, 0
  for _, record in ipairs(records) do
    section_map[tostring(record.section_id)] = record.section_name or ('Section ' .. tostring(record.section_id))
    shortcut_count = shortcut_count + #(record.shortcuts or {})
  end

  for _, id in ipairs(explicit_section_ids or {}) do
    id = tonumber(id)
    if id then
      section_map[tostring(id)] = section_by_id[id] and section_by_id[id].name or ('Section ' .. tostring(id))
    end
  end

  local section_list = {}
  for id, section_name in pairs(section_map) do
    section_list[#section_list + 1] = {id = tonumber(id), name = section_name}
  end

  table.sort(section_list, function(a, b) return a.id < b.id end)
  return {
    format = 'ReaKeymapPreset',
    preset_version = PRESET_VERSION,
    preset_name = name,
    created_at = utc_offset_time(),
    reaper_version = reaper.GetAppVersion(),
    script_version = SCRIPT_VERSION,
    scope = scope or 'custom',
    sections = section_list,
    command_count = #records,
    shortcut_count = shortcut_count,
    actions = records,
  }
end

function unique_output_path(directory, stem)
  local base = safe_filename(stem)
  local candidate = path_join(directory, base .. '.json')
  local number = 2
  while read_file(candidate) do
    candidate = path_join(directory, ('%s_%d.json'):format(base, number))
    number = number + 1
  end
  return candidate
end

function write_preset(path, document)
  return write_file(path, JSON.encode(document, true) .. '\n')
end

function create_backup(section_ids, label)
  local records = collect_records(section_ids, true, true, false)
  local name = 'ShortcutBackup_' .. timestamp_for_file()
  local path = unique_output_path(BACKUPS_DIR, name)
  local document = preset_document(label or name, records, 'backup', section_ids)
  document.restore_full_sections = true
  local ok, err = write_preset(path, document)
  if ok then
    state.last_backup_path = path
    return path
  end
  return nil, err
end

function reload_preset_files()
  reaper.EnumerateFiles(PRESETS_DIR, -1)
  state.presets = {}
  local index = 0
  while true do
    local filename = reaper.EnumerateFiles(PRESETS_DIR, index)
    if not filename then break end
    if lower(filename):match('%.json$') then
      state.presets[#state.presets + 1] = {name = filename:gsub('%.json$', ''), path = path_join(PRESETS_DIR, filename)}
    end
    index = index + 1
  end
  table.sort(state.presets, function(a, b) return natural_compare(a.name, b.name) < 0 end)
end

reload_preset_files()

function delete_preset(path)
  if type(path)~='string' then return false,'缺少预设路径。' end
  reload_preset_files()
  local allowed=false
  for _,preset in ipairs(state.presets) do if preset.path==path then allowed=true;break end end
  if not allowed then return false,'预设不存在或不在我的预设列表中。' end
  local parent,filename=path:match('^(.*)[/\\]([^/\\]+)$')
  if not parent or parent:gsub('\\','/')~=PRESETS_DIR:gsub('\\','/')
    or not filename:lower():match('%.json$') or filename:find(':',1,true) then
    return false,'只能删除预设目录中的 JSON 文件。'
  end

  local ok,err=os.remove(path)
  if not ok then return false,'删除预设失败：'..tostring(err) end
  if state.import_preview and state.import_preview.path==path then state.import_preview=nil end
  reload_preset_files()

  return true
end

function reload_backup_files()
  reaper.EnumerateFiles(BACKUPS_DIR, -1)
  state.backups = {}
  local index = 0
  while true do
    local filename = reaper.EnumerateFiles(BACKUPS_DIR, index)
    if not filename then break end
    if lower(filename):match('%.json$') then
      state.backups[#state.backups + 1] = {name = filename, path = path_join(BACKUPS_DIR, filename)}
    end
    index = index + 1
  end
  table.sort(state.backups, function(a, b) return natural_compare(a.name, b.name) > 0 end)
  if not state.last_backup_path and state.backups[1] then state.last_backup_path = state.backups[1].path end
end

reload_backup_files()

function push_history(label, before_records, after_records, full_sections, full_section_ids)
  while #state.history > state.history_cursor do table.remove(state.history) end
  state.history[#state.history + 1] = {
    label = label,
    before = before_records,
    after = after_records,
    full_sections = full_sections == true,
    full_section_ids = copy_array(full_section_ids or {}),
    created_at = utc_offset_time(),
  }
  if #state.history > 30 then table.remove(state.history, 1) end
  state.history_cursor = #state.history
end

function affected_section_ids_from_records(records)
  local seen, result = {}, {}
  for _, record in ipairs(records or {}) do
    local id = tonumber(record.section_id)
    if id and not seen[id] then seen[id] = true result[#result + 1] = id end
  end
  table.sort(result)
  return result
end

function build_apply_plan(records, mode, full_sections, explicit_section_ids)
  mode = mode == 'overwrite' and 'overwrite' or 'merge'
  full_sections = mode == 'overwrite' and full_sections == true
  local plan = {
    mode = mode,
    full_sections = full_sections,
    source_records = records,
    matched = {},
    unmatched = {},
    additions = {},
    desired_by_section = {},
    desired_action_keys = {},
    affected_sections = {},
    affected_section_ids = {},
    shortcut_count = 0,
    conflict_count = 0,
    preset_conflict_count = 0,
    deletion_count = 0,
  }

  if full_sections then
    for _, section_id in ipairs(explicit_section_ids or {}) do
      section_id = tonumber(section_id)
      if section_id and section_by_id[section_id] and section_by_id[section_id].handle then plan.affected_sections[section_id] = true end
    end
  end

  for _, record in ipairs(records or {}) do
    local section_id = tonumber(record.section_id)
    local action = find_action(record)
    if not section_id or not section_by_id[section_id] or not action then
      plan.unmatched[#plan.unmatched + 1] = record
    else
      plan.affected_sections[section_id] = true
      plan.desired_by_section[section_id] = plan.desired_by_section[section_id] or {}
      local desired = plan.desired_by_section[section_id][action.key]
      if not desired then
        desired = {identity = action_identity(action), record = record, shortcuts = {}, shortcut_list = {}}
        plan.desired_by_section[section_id][action.key] = desired
        plan.desired_action_keys[action.key] = true
        plan.matched[#plan.matched + 1] = desired
      end
      for _, shortcut in ipairs(record.shortcuts or {}) do
        local normalized = normalize_shortcut(shortcut)
        if normalized ~= '' and not desired.shortcuts[normalized] then
          desired.shortcuts[normalized] = shortcut
          desired.shortcut_list[#desired.shortcut_list + 1] = shortcut
          plan.shortcut_count = plan.shortcut_count + 1
        end
      end
    end
  end

  for id in pairs(plan.affected_sections) do plan.affected_section_ids[#plan.affected_section_ids + 1] = id end
  table.sort(plan.affected_section_ids)

  local preset_shortcut_targets = {}
  for _, desired in ipairs(plan.matched) do
    for normalized in pairs(desired.shortcuts) do
      local key = tostring(desired.identity.section_id) .. ':' .. normalized
      preset_shortcut_targets[key] = preset_shortcut_targets[key] or {}
      preset_shortcut_targets[key][#preset_shortcut_targets[key] + 1] = desired.identity
    end
  end
  for _, targets in pairs(preset_shortcut_targets) do
    if #targets > 1 then
      plan.preset_conflict_count = plan.preset_conflict_count + 1
      plan.conflict_count = plan.conflict_count + 1
    end
  end

  for _, desired in ipairs(plan.matched) do
    local action = find_action(desired.identity)
    if action then
      for normalized, original in pairs(desired.shortcuts) do
        if not action_has_shortcut(action, original) then
          local step = {identity = desired.identity, shortcut = original, normalized = normalized, conflicts = {}}
          local cache = ensure_cache(action.section_id)
          for _, owner in ipairs(cache.shortcut_owners[normalized] or {}) do
            if owner.key ~= action.key then step.conflicts[#step.conflicts + 1] = action_identity(owner) end
          end
          if #step.conflicts > 0 then plan.conflict_count = plan.conflict_count + 1 end
          plan.additions[#plan.additions + 1] = step
        end
      end
    end
  end

  if mode == 'overwrite' then
    for _, section_id in ipairs(plan.affected_section_ids) do
      local cache = ensure_cache(section_id)
      local desired_section = plan.desired_by_section[section_id] or {}
      if full_sections then
        for _, action in ipairs(cache.actions) do
          local desired = desired_section[action.key]
          local desired_shortcuts = desired and desired.shortcuts or {}
          for _, shortcut in ipairs(action.shortcuts) do
            if not desired_shortcuts[normalize_shortcut(shortcut)] then
              plan.deletion_count = plan.deletion_count + 1
            end
          end
        end
      else
        for key, desired in pairs(desired_section) do
          local action = cache.by_key[key]
          if action then
            for _, shortcut in ipairs(action.shortcuts) do
              if not desired.shortcuts[normalize_shortcut(shortcut)] then
                plan.deletion_count = plan.deletion_count + 1
              end
            end
          end
        end
      end
    end
  end
  return plan
end

function capture_plan_scope(plan)
  local records = {}
  for _, section_id in ipairs(plan.affected_section_ids) do
    local cache = ensure_cache(section_id)
    if plan.full_sections then
      for _, action in ipairs(cache.actions) do
        records[#records + 1] = record_from_action(action, true)
      end
    else
      local desired = plan.desired_by_section[section_id] or {}
      for action_key in pairs(desired) do
        local action = cache.by_key[action_key]
        if action then records[#records + 1] = record_from_action(action, true) end
      end
    end
  end
  return records
end

function apply_plan_notes(plan)
  local changed = false
  local previous = {}

  for _, desired in ipairs(plan.matched) do
    if desired.record.note ~= nil then
      local action = find_action(desired.identity)
      if action then
        previous[action.key] = {action = action, note = user_data.notes[action.key], display = action.note}
        local note = tostring(desired.record.note or '')
        if note == '' then user_data.notes[action.key] = nil else user_data.notes[action.key] = note end
        action.note = note
        changed = true
      end
    end
  end

  if changed then
    local ok, err = save_user_data()
    if not ok then
      for key, item in pairs(previous) do user_data.notes[key], item.action.note = item.note, item.display end
      error('备注保存失败：' .. tostring(err), 0)
    end
    state.filter_dirty = true
  end
end

local function delete_unwanted_shortcuts(action, desired_shortcuts)
  local failed, deleted = 0, 0
  for index = #action.shortcuts - 1, 0, -1 do
    local shortcut = action.shortcuts[index + 1]
    if not desired_shortcuts[normalize_shortcut(shortcut)] then
      if reaper.DeleteActionShortcut(section_by_id[action.section_id].handle, action.command_id, index) then
        deleted = deleted + 1
      else
        failed = failed + 1
      end
    end
  end
  return deleted, failed
end

local function apply_plan_cleanup(plan)
  if plan.mode ~= 'overwrite' then return 0, 0 end
  local deleted, failed = 0, 0
  for _, section_id in ipairs(plan.affected_section_ids) do
    refresh_section(section_id, true)
    local cache = ensure_cache(section_id)
    local desired_section = plan.desired_by_section[section_id] or {}
    if plan.full_sections then
      for _, action in ipairs(cache.actions) do
        local desired = desired_section[action.key]
        local wanted = desired and desired.shortcuts or {}
        local d, f = delete_unwanted_shortcuts(action, wanted)
        deleted, failed = deleted + d, failed + f
      end
    else
      for key, desired in pairs(desired_section) do
        local action = cache.by_key[key]
        if action then
          local d, f = delete_unwanted_shortcuts(action, desired.shortcuts)
          deleted, failed = deleted + d, failed + f
        end
      end
    end
    refresh_section(section_id, true)
  end

  return deleted, failed
end

function verify_plan(plan)
  local success, failed = 0, 0
  for _, desired in ipairs(plan.matched) do
    local action = find_action(desired.identity)
    local ok = action ~= nil
    if ok then
      local actual = {}
      for _, shortcut in ipairs(action.shortcuts) do actual[normalize_shortcut(shortcut)] = true end
      for normalized in pairs(desired.shortcuts) do
        if not actual[normalized] then ok = false break end
      end
      if ok and plan.mode == 'overwrite' then
        for normalized in pairs(actual) do
          if not desired.shortcuts[normalized] then ok = false break end
        end
      end
    end
    if ok then success = success + 1 else failed = failed + 1 end
  end
  return success, failed, #plan.unmatched
end

function start_guide(plan, label, options)
  options = options or {}
  if #plan.affected_section_ids == 0 then
    set_status('预设中没有可匹配的操作命令。', 'error')
    return false
  end
  local backup_path, backup_err = create_backup(plan.affected_section_ids, label .. ' - 应用前备份')
  if not backup_path then
    set_status('无法创建自动备份：' .. tostring(backup_err), 'error')
    return false
  end
  state.guide = {
    plan = plan,
    label = label,
    index = 1,
    applied = 0,
    skipped = 0,
    last_error = nil,
    backup_path = backup_path,
    before_records = collect_records(plan.affected_section_ids, true, true, false),
    suppress_history = options.suppress_history,
    on_complete = options.on_complete,
  }
  apply_plan_notes(plan)
  return true
end

function guide_advance_existing()
  local guide = state.guide
  if not guide then return end
  while guide.index <= #guide.plan.additions do
    local step = guide.plan.additions[guide.index]
    local action = find_action(step.identity)
    if action and action_has_shortcut(action, step.shortcut) then
      guide.applied = guide.applied + 1
      guide.index = guide.index + 1
    else
      break
    end
  end
end

function finish_guide()
  local guide = state.guide
  if not guide then return end
  apply_plan_notes(guide.plan)
  local deleted, delete_failed = apply_plan_cleanup(guide.plan)
  for _, section_id in ipairs(guide.plan.affected_section_ids) do refresh_section(section_id, true) end
  state.last_kb_signature = shortcut_signature()
  local success, failed, unmatched = verify_plan(guide.plan)
  local after_records = collect_records(guide.plan.affected_section_ids, true, true, false)
  if not guide.suppress_history then
    push_history(guide.label, guide.before_records, after_records, true,
      guide.plan.affected_section_ids)
  end
  if guide.on_complete and failed == 0 and unmatched == 0 and delete_failed == 0 then guide.on_complete() end
  set_status(('%s 完成：成功 %d，失败 %d，未找到 %d；清理 %d，清理失败 %d'):format(
    guide.label, success, failed, unmatched, deleted, delete_failed),
    (failed > 0 or unmatched > 0 or delete_failed > 0) and 'warning' or 'success')
  state.guide_result = {
    label = guide.label,
    success = success,
    failed = failed,
    unmatched = unmatched,
    deleted = deleted,
    delete_failed = delete_failed,
    backup_path = guide.backup_path,
  }
  state.guide = nil
  state.filter_dirty = true
end

function load_preset_file(path)
  local raw, read_err = read_file(path)
  if not raw then return nil, '文件无法读取：' .. tostring(read_err) end
  local document, decode_err = JSON.decode(raw)
  if type(document) ~= 'table' or document == JSON.null then return nil, 'JSON 解析失败：' .. tostring(decode_err) end
  if document.format ~= 'ReaKeymapPreset' then return nil, '不是 ReaKeymapPreset 文件' end
  if tonumber(document.preset_version) ~= PRESET_VERSION then
    return nil, ('不兼容的预设版本：%s'):format(tostring(document.preset_version))
  end
  if not JSON.is_array(document.actions) then return nil, '预设缺少有效 actions 数组' end
  if document.sections ~= nil and not JSON.is_array(document.sections) then return nil, 'sections 必须是数组' end
  for _, section in ipairs(document.sections or {}) do
    local id = tonumber(type(section) == 'table' and section.id or section)
    if not id or id < 0 or id % 1 ~= 0 then return nil, '预设包含无效区段 ID' end
  end
  for index, record in ipairs(document.actions) do
    if type(record) ~= 'table' or not tonumber(record.section_id) or tonumber(record.section_id) < 0 or tonumber(record.section_id) % 1 ~= 0 then
      return nil, ('第 %d 条命令缺少有效区段'):format(index)
    end
    if not JSON.is_array(record.shortcuts) then return nil, ('第 %d 条命令缺少有效 shortcuts 数组'):format(index) end
    if record.note ~= nil and type(record.note) ~= 'string' then return nil, '备注必须是字符串' end
    if trim(record.named_command_id) == '' and not tonumber(record.command_id)
        and trim(record.script_path) == '' and trim(record.command_name) == '' then
      return nil, ('第 %d 条命令缺少可用匹配字段'):format(index)
    end
    for shortcut_index, shortcut in ipairs(record.shortcuts) do
      if type(shortcut) ~= 'string' or trim(shortcut) == '' then
        return nil, ('第 %d 条命令的第 %d 个快捷键格式无效'):format(index, shortcut_index)
      end
    end
  end
  return document
end

function prepare_import(path, preferred_mode, preferred_full)
  local document, err = load_preset_file(path)
  if not document then set_status(err, 'error') return false end
  for _, record in ipairs(document.actions) do ensure_cache(record.section_id) end
  local mode = preferred_mode or 'merge'
  local full = preferred_full == true
  state.import_preview = {
    path = path,
    document = document,
    mode = mode,
    full_sections = full,
  }

  local scope_ids = {}

  for _, section in ipairs(document.sections or {}) do
    local id = tonumber(type(section) == 'table' and section.id or section)
    if id then scope_ids[#scope_ids + 1] = id end
  end
  state.import_preview.scope_section_ids = scope_ids
  state.import_preview.plan = build_apply_plan(document.actions, mode, full, scope_ids)
  return true
end

function recompute_import_plan()
  local preview = state.import_preview
  if preview then
    preview.plan = build_apply_plan(preview.document.actions, preview.mode, preview.full_sections,
      preview.scope_section_ids)
  end
end

function open_import_dialog()
  local ok, path = reaper.GetUserFileNameForRead(PRESETS_DIR, '导入 ReaKeymap JSON 预设', '.json')
  if ok and path and path ~= '' then prepare_import(path) end
end

function start_history_restore(redo)
  local entry, target_cursor, records
  if redo then
    entry = state.history[state.history_cursor + 1]
    if not entry then return end
    records = entry.after
    target_cursor = state.history_cursor + 1
  else
    entry = state.history[state.history_cursor]
    if not entry then return end
    records = entry.before
    target_cursor = state.history_cursor - 1
  end
  local plan = build_apply_plan(records, 'overwrite', entry.full_sections, entry.full_section_ids)
  start_guide(plan, (redo and '恢复：' or '撤销：') .. entry.label, {
    suppress_history = true,
    on_complete = function() state.history_cursor = target_cursor end,
  })
end

function edit_shortcut_native(identity, shortcut_index, label)
  local action = find_action(identity)
  if not action then set_status('命令不存在或区段不匹配。', 'error') return false end
  local before = collect_records({action.section_id}, true, true, false)
  local section = section_by_id[action.section_id]
  local ok = reaper.DoActionShortcutDialog(reaper.GetMainHwnd(), section.handle,
    action.command_id, shortcut_index or -1)
  refresh_section(action.section_id, true)
  state.last_kb_signature = shortcut_signature()
  state.detail_shortcut_selection = nil
  local after_action = find_action(identity)
  local after = collect_records({action.section_id}, true, true, false)
  if JSON.encode(before, false) ~= JSON.encode(after, false) then
    push_history(label or '修改快捷键', before, after, true, {action.section_id})
    set_status(('已同步“%s”的快捷键。'):format(action.name), 'success')
    return true
  end
  set_status(ok and '快捷键没有变化。' or '已取消快捷键修改。', 'normal')
  return false
end

function delete_shortcuts(identity, selected_indices)
  local action = find_action(identity)
  if not action then return 0, 0 end
  local indices, shortcut_names = {}, {}
  for index = #action.shortcuts - 1, 0, -1 do
    if selected_indices and selected_indices[index] then
      indices[#indices + 1] = index
      shortcut_names[#shortcut_names + 1] = action.shortcuts[index + 1]
    end
  end
  if #indices == 0 then return 0, 0 end

  local before = {record_from_action(action, true)}
  local deleted, failed = 0, 0
  for _, index in ipairs(indices) do
    if reaper.DeleteActionShortcut(section_by_id[action.section_id].handle, action.command_id, index) then
      deleted = deleted + 1
    else
      failed = failed + 1
    end
  end
  refresh_section(action.section_id, true)
  state.last_kb_signature = shortcut_signature()
  state.detail_shortcut_selection = nil
  local after_action = find_action(identity)
  local after = after_action and {record_from_action(after_action, true)} or {}
  if deleted > 0 then
    local label = deleted == 1 and ('删除快捷键 ' .. shortcut_names[1])
      or ('删除 %d 个快捷键'):format(deleted)
    push_history(label, before, after, false)
    set_status(('已从“%s”删除 %d 个快捷键，失败 %d。'):format(action.name, deleted, failed),
      failed > 0 and 'warning' or 'success')
  else
    set_status('快捷键删除失败。', 'error')
  end
  return deleted, failed
end

function request_batch_delete(identities)
  state.batch_delete = {identities = identities or {}}
end

function execute_batch_delete()
  local batch = state.batch_delete
  if not batch then return end
  local before = capture_identities(batch.identities)
  local section_seen, section_ids, shortcut_count = {}, {}, 0

  for _, record in ipairs(before) do
    shortcut_count = shortcut_count + #(record.shortcuts or {})
    if not section_seen[record.section_id] then
      section_seen[record.section_id] = true
      section_ids[#section_ids + 1] = record.section_id
    end
  end

  local backup, err = create_backup(section_ids, '批量删除前备份')
  if not backup then set_status('无法创建备份：' .. tostring(err), 'error') return end

  local deleted, failed = 0, 0
  for _, identity in ipairs(batch.identities) do
    local action = find_action(identity)
    if action then
      for index = #action.shortcuts - 1, 0, -1 do
        if reaper.DeleteActionShortcut(section_by_id[action.section_id].handle, action.command_id, index) then
          deleted = deleted + 1
        else
          failed = failed + 1
        end
      end
    end
  end

  for _, id in ipairs(section_ids) do refresh_section(id, true) end
  state.last_kb_signature = shortcut_signature()
  local after = capture_identities(batch.identities)
  push_history(('批量删除 %d 个快捷键'):format(shortcut_count), before, after, false)
  set_status(('已删除 %d 个快捷键，失败 %d；备份已创建。'):format(deleted, failed), failed > 0 and 'warning' or 'success')
  state.batch_delete = nil
end

function save_note(identity, note)
  local action = find_action(identity)
  if not action then return false end
  local old_note = user_data.notes[action.key]
  note = tostring(note or '')
  if trim(note) == '' then user_data.notes[action.key] = nil else user_data.notes[action.key] = note end
  action.note = note
  local ok, err = save_user_data()
  if ok then
    state.note_identity = action.key
    state.note_buffer = note
    state.notes_dirty = false
    state.filter_dirty = true
    set_status(('已保存“%s”的备注。'):format(action.name), 'success')
    return true
  end
  user_data.notes[action.key], action.note = old_note, old_note or ''
  set_status('备注保存失败：' .. tostring(err), 'error')
  return false
end

function rebuild_managed_list(clear_existing, include_bound)
  local old_managed, old_initialized = user_data.managed, user_data.managed_initialized
  user_data.managed = {}
  if not clear_existing then for key, value in pairs(old_managed) do user_data.managed[key] = value end end
  if include_bound then
    for _, section in ipairs(sections) do
      local cache = section.visible and ensure_cache(section.id)
      if cache then
        for _, action in ipairs(cache.actions) do
          if #action.shortcuts > 0 then user_data.managed[action.key] = true end
        end
      end
    end
  end

  user_data.managed_initialized = true
  local ok, err = save_user_data()
  if not ok then
    user_data.managed, user_data.managed_initialized = old_managed, old_initialized
    error('管理列表保存失败：' .. tostring(err), 0)
  end

  if clear_existing then state.selected = {} end
  return table_count(user_data.managed)
end

function background_tasks()
  if state.action_prompt_active then
    local ok, result = pcall(reaper.PromptForAction, 0, 0, 0)
    if not ok or result == -1 then
      pcall(reaper.PromptForAction, -1, 0, 0)
      state.action_prompt_active = false
    end
  end

  if state.overview_refresh_index then
    local section = sections[state.overview_refresh_index]
    if section then
      if section.visible and section.handle then refresh_section(section.id, true) end
      state.overview_refresh_index = state.overview_refresh_index + 1
    else
      state.overview_refresh_index = nil
      state.last_kb_signature = shortcut_signature()
      set_status('全部快捷键区段已刷新。', 'success')
    end
    return
  end

  if not state.startup_capture_complete then
    local id = state.startup_section_ids[state.startup_capture_index]
    if id then
      local cache = ensure_cache(id)
      if cache then
        for _, action in ipairs(cache.actions) do
          state.startup_snapshot[#state.startup_snapshot + 1] = record_from_action(action, true)
        end
      end
      state.startup_capture_index = state.startup_capture_index + 1
    else
      state.startup_capture_complete = true
      if user_data.managed_initialized ~= true then
        rebuild_managed_list(false, settings.managed_init_from_bound)
      end
      state.last_kb_signature = shortcut_signature()
      set_status(('启动状态已记录：%d 条命令。'):format(#state.startup_snapshot), 'success')
    end
    return
  end

  if state.all_sections_view then
    for _, section in ipairs(sections) do
      if section.visible and section.handle and not state.caches[section.id] then
        ensure_cache(section.id)
        return
      end
    end
  end

  if settings.auto_refresh then
    local now = reaper.time_precise()
    if now - state.last_auto_refresh >= math.max(2, tonumber(settings.auto_refresh_interval) or 5) then
      state.last_auto_refresh = now
      local signature = shortcut_signature()
      if signature and state.last_kb_signature and signature ~= state.last_kb_signature then
        state.last_kb_signature = signature
        request_all_sections_refresh()
      elseif signature then
        state.last_kb_signature = signature
      end
    end
  end
end

return {
  state = state, settings = settings, user_data = user_data,
  sections = function() return sections end,
  section = function(id) return section_by_id[tonumber(id)] end,
  paths = {data = DATA_ROOT, presets = PRESETS_DIR, backups = BACKUPS_DIR},
  tick = background_tasks, refresh = refresh_section, cache = ensure_cache,
  refresh_all = request_all_sections_refresh, rebuild_sections = rebuild_sections,
  find = find_action, identity = action_identity, record = record_from_action,
  collect = collect_records, document = preset_document, backup = create_backup,
  output_path = unique_output_path, write_preset = write_preset,
  delete_preset = delete_preset,
  reload_files = function() reload_preset_files() reload_backup_files() end,
  prepare_import = prepare_import, import_dialog = open_import_dialog,
  replan = recompute_import_plan, plan = build_apply_plan,
  start_guide = start_guide, advance_guide = guide_advance_existing,
  finish_guide = finish_guide, has_shortcut = action_has_shortcut,
  capture = capture_plan_scope, history = push_history, restore_history = start_history_restore,
  edit_shortcut = edit_shortcut_native, delete_shortcuts = delete_shortcuts,
  batch_delete = function(identities) request_batch_delete(identities) execute_batch_delete() end,
  save_note = save_note, rebuild_managed = rebuild_managed_list,
  save_settings = save_settings, save_user_data = save_user_data,
  canonical = shortcut_canonical, compare = natural_compare, status = set_status,
  sync_signature = function() state.last_kb_signature = shortcut_signature() end,
}
end
