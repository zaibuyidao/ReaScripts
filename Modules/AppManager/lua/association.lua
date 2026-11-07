-- @noindex
local M = {}
local function read_file(path)
  local file = io.open(path, 'rb'); if not file then return nil end
  local data = file:read(65537); file:close()
  return data and #data <= 65536 and data or nil
end
function M.new(r, json, read)
  read = read or read_file
  local windows = r.GetOS():match('^Win') ~= nil
  local function normalize(path)
    if type(path) ~= 'string' or path:find('%z') then return nil end
    if windows then path = path:gsub('\\', '/'):lower() end
    local prefix, rest
    if windows and path:match('^%a:/') then prefix, rest = path:sub(1,3), path:sub(4)
    elseif path:sub(1,2) == '//' then prefix, rest = '//', path:sub(3)
    elseif path:sub(1,1) == '/' then prefix, rest = '/', path:sub(2)
    else return nil end
    local parts = {}
    for part in rest:gmatch('[^/]+') do
      if part == '..' then if #parts == 0 then return nil end; table.remove(parts)
      elseif part ~= '.' then parts[#parts+1] = part end
    end
    return (prefix .. table.concat(parts,'/')):gsub('/+$','')
  end
  local function below(parent, path) return parent and path and path:sub(1,#parent+1) == parent .. '/' end
  local effects = normalize(r.GetResourcePath() .. '/Effects')
  local cache = {}
  local function entries(directory)
    if cache[directory] then return cache[directory] end
    local result, files = {}, {}; cache[directory] = result
    if not effects or not (directory == effects or below(effects,directory)) then return result end
    -- Only this registered Root and its immediate parent; never recurse through Effects.
    r.EnumerateFiles(directory,-1)
    for index=0,127 do
      local name = r.EnumerateFiles(directory,index); if not name then break end
      if not name:find('[/\\]') then files[windows and name:lower() or name] = name end
    end
    for name in pairs(files) do
      if name:match('%.jsfx$') then
        local sidecar = files[name:gsub('%.jsfx$','.json')]
        local raw = sidecar and read(directory .. '/' .. sidecar)
        if raw then
          local ok, data = pcall(json.decode,raw)
          local ui = ok and type(data)=='table' and data.schema==1 and data.JSFX_WebUI
          local entry = type(ui)=='table' and ui.entry
          if type(entry)=='string' and entry:match('%.html$') and not entry:match('^[/\\]') and not entry:match('^%a:') then
            local target = normalize(directory .. '/' .. entry)
            if below(directory,target) then result[target] = true end
          end
        end
      end
    end
    return result
  end
  return function(row)
    if row.type ~= 'unknown' or (row.typeSource ~= nil and row.typeSource ~= json.null)
      or type(row.appId) ~= 'string' or type(row.root) ~= 'string' or type(row.entry) ~= 'string' then return end
    local root = normalize(row.root)
    if not root or not below(effects,root) or row.entry:match('^[/\\]') or row.entry:match('^%a:') then return end
    local entry = normalize(root .. '/' .. row.entry)
    if not below(root,entry) then return end
    local parent = root:match('^(.*)/[^/]+$')
    if entries(root)[entry] or (parent and entries(parent)[entry]) then
      row.type = 'jsfx'; row.typeSource = 'Matching JSFX source and WebUI association entry'
    end
  end
end
return M
