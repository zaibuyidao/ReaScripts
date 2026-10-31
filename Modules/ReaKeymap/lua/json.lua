-- @noindex
local JSON = {}
JSON.null = {}

local function json_escape(value)
  local replacements = {
    ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
    ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
  }
  return tostring(value):gsub('[%z\1-\31\\"]', function(char)
    return replacements[char] or ('\\u%04x'):format(char:byte())
  end)
end

local function is_json_array(value)
  if type(value) ~= 'table' or value == JSON.null then return false end
  local meta = getmetatable(value)
  if meta and meta.json_type == 'object' then return false end
  local max, count = 0, 0
  for key in pairs(value) do
    if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then return false end
    if key > max then max = key end
    count = count + 1
  end
  return max == count
end

local function json_encode_value(value, pretty, depth, seen)
  if value == JSON.null then return 'null' end
  local kind = type(value)
  if kind == 'nil' then return 'null' end
  if kind == 'boolean' then return value and 'true' or 'false' end
  if kind == 'number' then
    if value ~= value or value == math.huge or value == -math.huge then return 'null' end
    return ('%.17g'):format(value)
  end
  if kind == 'string' then return '"' .. json_escape(value) .. '"' end
  if kind ~= 'table' then error('JSON 不支持类型：' .. kind) end
  if seen[value] then error('JSON 不支持循环引用') end
  seen[value] = true

  local indent = pretty and string.rep('  ', depth) or ''
  local next_indent = pretty and string.rep('  ', depth + 1) or ''
  local separator = pretty and ',\n' or ','
  local result = {}
  if is_json_array(value) then
    for i = 1, #value do
      result[#result + 1] = next_indent .. json_encode_value(value[i], pretty, depth + 1, seen)
    end
    seen[value] = nil
    if #result == 0 then return '[]' end
    return '[' .. (pretty and '\n' or '') .. table.concat(result, separator)
      .. (pretty and ('\n' .. indent) or '') .. ']'
  end

  local keys = {}
  for key in pairs(value) do
    if type(key) ~= 'string' then error('JSON 对象键必须是字符串') end
    keys[#keys + 1] = key
  end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local colon = pretty and ': ' or ':'
    result[#result + 1] = next_indent .. '"' .. json_escape(key) .. '"' .. colon
      .. json_encode_value(value[key], pretty, depth + 1, seen)
  end
  seen[value] = nil
  if #result == 0 then return '{}' end
  return '{' .. (pretty and '\n' or '') .. table.concat(result, separator)
    .. (pretty and ('\n' .. indent) or '') .. '}'
end

function JSON.encode(value, pretty)
  return json_encode_value(value, pretty ~= false, 0, {})
end

local function utf8_char(codepoint)
  if codepoint <= 0x7f then return string.char(codepoint) end
  if codepoint <= 0x7ff then
    return string.char(0xc0 | (codepoint >> 6), 0x80 | (codepoint & 0x3f))
  end
  if codepoint <= 0xffff then
    return string.char(0xe0 | (codepoint >> 12), 0x80 | ((codepoint >> 6) & 0x3f),
      0x80 | (codepoint & 0x3f))
  end
  return string.char(0xf0 | (codepoint >> 18), 0x80 | ((codepoint >> 12) & 0x3f),
    0x80 | ((codepoint >> 6) & 0x3f), 0x80 | (codepoint & 0x3f))
end

function JSON.decode(text)
  local source = tostring(text or ''):gsub('^\239\187\191', '')
  local position, length = 1, #source

  local function fail(message)
    error(('%s（位置 %d）'):format(message, position), 0)
  end

  local function skip_space()
    while position <= length and source:sub(position, position):match('%s') do
      position = position + 1
    end
  end

  local parse_value
  local function parse_string()
    if source:sub(position, position) ~= '"' then fail('需要字符串') end
    position = position + 1
    local result = {}
    while position <= length do
      local char = source:sub(position, position)
      if char == '"' then
        position = position + 1
        return table.concat(result)
      end
      if char == '\\' then
        position = position + 1
        local escaped = source:sub(position, position)
        local simple = {['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
        if simple[escaped] then
          result[#result + 1] = simple[escaped]
          position = position + 1
        elseif escaped == 'u' then
          local hex = source:sub(position + 1, position + 4)
          if not hex:match('^%x%x%x%x$') then fail('无效 Unicode 转义') end
          local codepoint = tonumber(hex, 16)
          position = position + 5
          if codepoint >= 0xd800 and codepoint <= 0xdbff
              and source:sub(position, position + 1) == '\\u' then
            local low_hex = source:sub(position + 2, position + 5)
            local low = tonumber(low_hex, 16)
            if low and low >= 0xdc00 and low <= 0xdfff then
              codepoint = 0x10000 + ((codepoint - 0xd800) << 10) + (low - 0xdc00)
              position = position + 6
            end
          end
          result[#result + 1] = utf8_char(codepoint)
        else
          fail('无效转义字符')
        end
      else
        if char:byte() < 32 then fail('字符串包含控制字符') end
        result[#result + 1] = char
        position = position + 1
      end
    end
    fail('字符串没有结束引号')
  end

  local function parse_number()
    local start = position
    if source:sub(position, position) == '-' then position = position + 1 end
    if source:sub(position, position) == '0' then
      position = position + 1
    else
      if not source:sub(position, position):match('%d') then fail('无效数字') end
      while source:sub(position, position):match('%d') do position = position + 1 end
    end
    if source:sub(position, position) == '.' then
      position = position + 1
      if not source:sub(position, position):match('%d') then fail('无效小数') end
      while source:sub(position, position):match('%d') do position = position + 1 end
    end
    local exponent = source:sub(position, position)
    if exponent == 'e' or exponent == 'E' then
      position = position + 1
      local sign = source:sub(position, position)
      if sign == '+' or sign == '-' then position = position + 1 end
      if not source:sub(position, position):match('%d') then fail('无效指数') end
      while source:sub(position, position):match('%d') do position = position + 1 end
    end
    local number = tonumber(source:sub(start, position - 1))
    if not number then fail('无效数字') end
    return number
  end

  local function parse_array()
    local result = setmetatable({}, {json_type = 'array'})
    position = position + 1
    skip_space()
    if source:sub(position, position) == ']' then position = position + 1 return result end
    while true do
      result[#result + 1] = parse_value()
      skip_space()
      local char = source:sub(position, position)
      if char == ']' then position = position + 1 return result end
      if char ~= ',' then fail('数组需要逗号或结束括号') end
      position = position + 1
      skip_space()
    end
  end

  local function parse_object()
    local result = setmetatable({}, {json_type = 'object'})
    position = position + 1
    skip_space()
    if source:sub(position, position) == '}' then position = position + 1 return result end
    while true do
      if source:sub(position, position) ~= '"' then fail('对象键必须是字符串') end
      local key = parse_string()
      skip_space()
      if source:sub(position, position) ~= ':' then fail('对象键后需要冒号') end
      position = position + 1
      skip_space()
      local value = parse_value()
      if value ~= JSON.null then result[key] = value end
      skip_space()
      local char = source:sub(position, position)
      if char == '}' then position = position + 1 return result end
      if char ~= ',' then fail('对象需要逗号或结束括号') end
      position = position + 1
      skip_space()
    end
  end

  function parse_value()
    skip_space()
    local char = source:sub(position, position)
    if char == '"' then return parse_string() end
    if char == '{' then return parse_object() end
    if char == '[' then return parse_array() end
    if char == '-' or char:match('%d') then return parse_number() end
    if source:sub(position, position + 3) == 'true' then position = position + 4 return true end
    if source:sub(position, position + 4) == 'false' then position = position + 5 return false end
    if source:sub(position, position + 3) == 'null' then position = position + 4 return JSON.null end
    fail('无法识别的 JSON 值')
  end

  local ok, result = pcall(parse_value)
  if not ok then return nil, result end
  skip_space()
  if position <= length then return nil, ('JSON 尾部存在多余内容（位置 %d）'):format(position) end
  return result
end


JSON.is_array = is_json_array
return JSON
