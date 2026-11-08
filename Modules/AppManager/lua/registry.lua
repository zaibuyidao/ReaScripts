-- @noindex
local M = {}
local sequence = 0
local function read_file(path)
  local file = io.open(path, 'rb')
  if not file then return nil end
  local text = file:read(65537); file:close()
  if not text or #text > 65536 then return nil, 'Metadata exceeds 64 KiB' end
  return text
end
function M.new(r, json, classify, files)
  files = files or {read=read_file, remove=os.remove}
  local windows = r.GetOS():match('^Win') ~= nil
  local base = r.GetResourcePath():gsub('\\', '/') .. '/ReaWebAPI/Apps'
  local saved, generation, offset, count, directories = {}, 0, 0, 0, {}
  local self = {}
  local function comparable(path) return windows and path:lower() or path end
  local function absolute(path)
    if type(path) ~= 'string' or path:find('%c') then return nil end
    if windows then path = path:gsub('\\', '/') end
    if not (windows and (path:match('^%a:/') or path:match('^//[^/]+/[^/]+'))
      or not windows and path:sub(1,1) == '/') then return nil end
    if path:match('^%a:/$') or path == '/' then return path end
    return path:gsub('/+$','')
  end
  local function entry_path(entry)
    if type(entry) ~= 'string' or entry:find('[%c:]') or entry:match('^[/\\]') then return nil end
    entry = entry:gsub('\\','/')
    local parts = {}
    for part in entry:gmatch('[^/]+') do
      if part == '..' then return nil end
      if part ~= '.' then parts[#parts+1] = part end
    end
    entry = table.concat(parts, '/')
    if not (entry:lower():match('%.html$') or entry:lower():match('%.htm$')) then return nil end
    return entry
  end
  function self.directory_exists(path)
    path = absolute(path)
    if not path then return false end
    if path == '/' or path:match('^%a:/$') then
      return r.EnumerateSubdirectories(path,0) ~= nil or r.EnumerateFiles(path,0) ~= nil
    end
    local parent, name = path:match('^(.*)/([^/]+)$')
    if not parent then return false end
    if parent == '' then parent = '/' elseif parent:match('^%a:$') then parent = parent .. '/' end
    local key = comparable(parent)
    if not directories[key] then
      local entries = {}
      r.EnumerateSubdirectories(parent,-1)
      for index=0,8191 do
        local child = r.EnumerateSubdirectories(parent,index)
        if not child then break end
        entries[comparable(child)] = true
      end
      directories[key] = entries
    end
    return directories[key][comparable(name)] == true
  end
  local function decode(path)
    local raw, reason = files.read(path)
    if not raw then return nil, reason, nil end
    local ok, data = pcall(json.decode,raw)
    if not ok or type(data) ~= 'table' or data == json.null then return nil, 'Invalid JSON metadata', raw end
    return data, nil, raw
  end
  local function valid_record(data, id)
    return data and (data.schema == 1 or data.schema == 2) and absolute(data.root)
      and (data.schema == 1 or data.appId == id and data.origin == 'reaweb://' .. id)
  end
  local function inspect(id)
    if not id:match('^[a-z0-9%-]+$') then return nil end
    local profile = base .. '/' .. id
    local path = profile .. '/origin.json'
    local data, reason, raw = decode(path)
    if not raw and not reason and not r.file_exists(path) then return nil end
    local row = {registrationId=id, name=id, appId=json.null, origin=json.null,
      root=json.null, entry=json.null, version=json.null, author=json.null,
      type='unknown', typeSource=json.null, status='unverified',
      validation=reason or 'Binding has not been verified', removable=false,
      rootExists=false, dataExists=false, identityPath=json.null,
      registrationPath=path, dataPath=profile .. '/Data', windowStatePath=profile .. '/WindowState'}
    if not valid_record(data,id) then return row end
    row.appId, row.origin, row.root = id, 'reaweb://' .. id, absolute(data.root)
    row.name = row.root:match('([^/]+)$') or id
    row.removable, row.token = true, tostring(generation) .. ':' .. id
    saved[id] = {raw=raw, row=row}
    row.rootExists = self.directory_exists(row.root)
    row.dataExists = self.directory_exists(row.dataPath)
    local manifest = decode(row.root .. '/app.json')
    if manifest and (manifest.schemaVersion == nil or manifest.schemaVersion == 1)
      and (manifest.id == nil or manifest.id == id) then
      for _, field in ipairs({'name','version','author'}) do
        local value = manifest[field]
        if type(value) == 'string' and #value > 0 and #value <= 1024 and not value:find('%z') then row[field] = value end
      end
    else manifest = nil end
    local entry = data.entry
    if entry == nil and manifest then entry = manifest.entry end
    row.entry = entry_path(entry) or json.null
    if row.rootExists then
      local marker_path = row.root .. '/.reawebapi/identity.json'
      local marker = decode(marker_path)
      if marker and marker.schema == 1 and marker.appId == id then
        row.identityPath = marker_path
        row.type, row.typeSource = 'ordinary', 'Matching persistent ordinary WebUI identity marker'
      end
    end
    classify(row)
    if not row.rootExists then
      row.status, row.validation = 'missing', 'Root does not exist or is not a directory'
    elseif entry ~= nil and row.entry == json.null then
      row.status, row.validation = 'missing', 'Recorded Entry is not a valid relative HTML path'
    elseif row.entry == json.null then row.validation = 'Entry metadata is unavailable'
    elseif r.file_exists(row.root .. '/' .. row.entry) then
      row.status, row.validation = 'available', 'Root is accessible and Entry is a readable HTML file'
    else row.status, row.validation = 'missing', 'Entry is missing or is not a regular HTML file' end
    return row
  end
  function self.begin()
    sequence = sequence + 1
    generation = sequence
    saved, directories, offset, count = {}, {}, 0, 0
    r.EnumerateSubdirectories(base,-1)
  end
  function self.page()
    local rows, complete, truncated = json.array(), false, false
    for _=1,16 do
      if offset >= 8192 then
        complete, truncated = true, r.EnumerateSubdirectories(base,offset) ~= nil
        break
      end
      local id = r.EnumerateSubdirectories(base,offset)
      if not id then complete = true; break end
      offset = offset + 1
      local row = inspect(id)
      if row then rows[#rows+1] = row; count = count + 1 end
    end
    return {apps=rows, total=count, nextOffset=complete and json.null or offset, truncated=truncated}, complete
  end
  function self.validate(id, token)
    local item = type(id) == 'string' and saved[id]
    if not item or token ~= item.row.token then return nil, 'stale' end
    if files.read(item.row.registrationPath) ~= item.raw then return nil, 'stale' end
    return item.row
  end
  function self.remove(id, token)
    local row, error_key = self.validate(id,token)
    if not row then return false, error_key end
    -- Best-effort snapshot check. Lua does not participate in Runtime binding locks.
    if not files.remove(row.registrationPath) then return false, 'removeFailed' end
    saved[id] = nil
    return true
  end
  function self.folder(id, token, kind)
    local row, error_key = self.validate(id,token)
    if not row then return nil, error_key end
    if kind ~= 'root' and kind ~= 'data' then return nil, 'invalidRequest' end
    local path = kind == 'root' and row.root or row.dataPath
    directories = {}
    if not self.directory_exists(path) then return nil, 'folderUnavailable' end
    return path
  end
  return self
end
return M
