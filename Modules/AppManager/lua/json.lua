-- @noindex
-- Minimal strict JSON codec for the manager's bounded host messages. No dependencies.
local json = { null = {} }
local array_mt = {}
function json.array(t) return setmetatable(t or {}, array_mt) end

function json.encode(v)
  if v == json.null or v == nil then return 'null' end
  local kind = type(v)
  if kind == 'boolean' then return tostring(v) end

  if kind == 'number' then
    assert(v == v and math.abs(v) < math.huge, 'Invalid JSON number')
    return (string.format('%.17g', v):gsub(',', '.'))
  end

  if kind == 'string' then
    return '"' .. v:gsub('[%z\1-\31\\"]', function(c)
      if c == '"' then return '\\"' end
      if c == '\\' then return '\\\\' end
      return string.format('\\u%04x', c:byte())
    end) .. '"'
  end

  assert(kind == 'table', 'Invalid JSON value')
  local parts = {}
  if getmetatable(v) == array_mt then
    for _, item in ipairs(v) do parts[#parts + 1] = json.encode(item) end
    return '[' .. table.concat(parts, ',') .. ']'
  end

  for key, item in pairs(v) do
    assert(type(key) == 'string', 'JSON object key must be text')
    parts[#parts + 1] = json.encode(key) .. ':' .. json.encode(item)
  end

  return '{' .. table.concat(parts, ',') .. '}'
end

function json.decode(text)
  assert(type(text) == 'string', 'Expected JSON text')
  local pos, length = 1, #text
  local function fail() error('Invalid JSON at byte ' .. pos, 0) end
  local function ws() local _, last = text:find('^[ \t\r\n]*', pos); pos = (last or pos - 1) + 1 end
  local escapes = { ['"']='"', ['\\']='\\', ['/']='/', b='\b', f='\f', n='\n', r='\r', t='\t' }

  local function hex()
    local s = text:sub(pos, pos + 3)
    if #s ~= 4 or not s:match('^%x%x%x%x$') then fail() end
    pos = pos + 4
    return tonumber(s, 16)
  end

  local function str()
    pos = pos + 1
    local out = {}

    while pos <= length do
      local c = text:sub(pos, pos)
      pos = pos + 1
      if c == '"' then return table.concat(out) end
      if c == '\\' then
        c = text:sub(pos, pos)
        pos = pos + 1
        if c == 'u' then
          local n = hex()
          if n >= 0xd800 and n <= 0xdbff then
            if text:sub(pos, pos + 1) ~= '\\u' then fail() end
            pos = pos + 2
            local low = hex()
            if low < 0xdc00 or low > 0xdfff then fail() end
            n = 0x10000 + (n - 0xd800) * 0x400 + low - 0xdc00
          elseif n >= 0xdc00 and n <= 0xdfff then fail() end
          out[#out + 1] = utf8.char(n)
        elseif escapes[c] then out[#out + 1] = escapes[c] else fail() end
      elseif c:byte() < 32 then fail()
      else out[#out + 1] = c end
    end
    fail()
  end

  local parse
  parse = function(depth)
    if depth > 32 then fail() end
    ws()
    local c = text:sub(pos, pos)
    if c == '"' then return str() end
    if c == '{' or c == '[' then
      local object = c == '{'; local t = object and {} or json.array()
      local close = object and '}' or ']'; pos = pos + 1; ws()
      if text:sub(pos, pos) == close then pos = pos + 1; return t end
      while true do
        local key
        if object then
          ws(); if text:sub(pos, pos) ~= '"' then fail() end
          key = str(); if t[key] ~= nil then fail() end
          ws(); if text:sub(pos, pos) ~= ':' then fail() end; pos = pos + 1
        else key = #t + 1 end
        t[key] = parse(depth + 1); ws(); c = text:sub(pos, pos); pos = pos + 1
        if c == close then return t end
        if c ~= ',' then fail() end
      end
    end

    for literal, value in pairs({ ['true']=true, ['false']=false, ['null']=json.null }) do
      if text:sub(pos, pos + #literal - 1) == literal then pos = pos + #literal
        return value
      end
    end

    local start = pos
    if c == '-' then pos = pos + 1 end
    c = text:sub(pos, pos)
    if c == '0' then
      pos = pos + 1
    elseif c:match('[1-9]') then
      repeat pos = pos + 1 until not text:sub(pos, pos):match('%d')
    else
      fail()
    end
  
    if text:sub(pos, pos) == '.' then
      pos = pos + 1; if not text:sub(pos, pos):match('%d') then fail() end
      repeat pos = pos + 1 until not text:sub(pos, pos):match('%d')
    end

    if text:sub(pos, pos):match('[eE]') then
      pos = pos + 1; if text:sub(pos, pos):match('[+-]') then pos = pos + 1 end
      if not text:sub(pos, pos):match('%d') then fail() end
      repeat pos = pos + 1 until not text:sub(pos, pos):match('%d')
    end

    local n = tonumber(text:sub(start, pos - 1))
    if not n or math.abs(n) == math.huge then fail() end
    return n
  end

  local value = parse(0)
  ws()
  if pos <= length then
    fail()
  end

  return value
end

return json
