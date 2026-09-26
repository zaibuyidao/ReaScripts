-- NoIndex: true
local json = { null = {} }
local array_mt = {}

function json.array(value) return setmetatable(value or {}, array_mt) end
function json.is_array(value) return getmetatable(value) == array_mt end

function json.encode(value)
  local kind = type(value)
  if value == json.null or kind == "nil" then return "null" end
  if kind == "boolean" then return tostring(value) end

  if kind == "number" then
    assert(value == value and math.abs(value) < math.huge, "Invalid JSON number")
    return (string.format("%.14g", value):gsub(",", "."))
  end

  if kind == "string" then
    return '"' .. value:gsub('[%z\1-\31\\"]', function(c)
      if c == '"' then return '\\"' end
      if c == '\\' then return '\\\\' end
      return string.format("\\u%04x", c:byte())
    end) .. '"'
  end

  assert(kind == "table", "Invalid JSON value")
  local parts = {}

  if getmetatable(value) == array_mt or #value > 0 then
    for _, item in ipairs(value) do
      parts[#parts + 1] = json.encode(item)
    end

    return "[" .. table.concat(parts, ",") .. "]"
  end

  for key, item in pairs(value) do
    parts[#parts + 1] = json.encode(tostring(key)) .. ":" .. json.encode(item)
  end

  return "{" .. table.concat(parts, ",") .. "}"
end

function json.decode(source)
  assert(type(source) == "string", "Expected JSON")
  local position, size = 1, #source

  local function whitespace()
    local _, last = source:find("^[ \t\r\n]*", position)
    position = (last or position - 1) + 1
  end

  local function string_value()
    position = position + 1
    local parts, start = {}, position

    while position <= size do
      local c = source:sub(position, position)

      if c == '"' then
        parts[#parts + 1] = source:sub(start, position - 1)
        position = position + 1

        return table.concat(parts)
      elseif c == '\\' then
        parts[#parts + 1] = source:sub(start, position - 1)
        local escape = source:sub(position + 1, position + 1)
        local replacements = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }

        if escape == "u" then
          local hex = source:sub(position + 2, position + 5)
          assert(#hex == 4 and hex:match("^%x+$"), "Invalid Unicode escape")
          local code = tonumber(hex, 16)
          position = position + 6
          if code >= 0xd800 and code <= 0xdbff then
            assert(source:sub(position, position + 1) == '\\u', "Missing Unicode surrogate")
            local low = tonumber(source:sub(position + 2, position + 5), 16)
            assert(low and low >= 0xdc00 and low <= 0xdfff, "Invalid Unicode surrogate")
            code = 0x10000 + (code - 0xd800) * 0x400 + low - 0xdc00
            position = position + 6
          else
            assert(code < 0xdc00 or code > 0xdfff, "Invalid Unicode surrogate")
          end
          parts[#parts + 1] = utf8.char(code)
        else
          assert(replacements[escape], "Invalid JSON escape")
          parts[#parts + 1] = replacements[escape]
          position = position + 2
        end

        start = position
      else
        assert(c:byte() >= 32, "Invalid JSON control character")
        position = position + 1
      end
    end

    error("Unterminated JSON string")
  end

  local parse

  parse = function(depth)
    assert(depth < 32, "JSON nesting limit")
    whitespace()
    local c = source:sub(position, position)

    if c == '"' then return string_value() end
    if c == "{" or c == "[" then
      local object, close = c == "{", c == "{" and "}" or "]"
      local result = object and {} or json.array()
      position = position + 1
      whitespace()

      if source:sub(position, position) == close then
        position = position + 1

        return result
      end

      while true do
        local key

        if object then
          whitespace()
          assert(source:sub(position, position) == '"', "Expected JSON key")
          key = string_value()
          whitespace()
          assert(source:sub(position, position) == ":", "Expected JSON colon")
          position = position + 1
        end

        local value = parse(depth + 1)
        if object then result[key] = value else result[#result + 1] = value end

        whitespace()

        local delimiter = source:sub(position, position)
        position = position + 1

        if delimiter == close then return result end
        assert(delimiter == ",", "Expected JSON separator")
      end
    end

    for literal, value in pairs({ ["true"] = true, ["false"] = false, ["null"] = json.null }) do
      if source:sub(position, position + #literal - 1) == literal then position = position + #literal return value end
    end

    local token = source:sub(position):match("^-?%d+%.?%d*[eE]?[+-]?%d*")
    assert(token and not token:match("^-?0%d") and not token:match("%.$") and not token:match("%.[eE]"), "Invalid JSON number")
    local value = tonumber(token)
    assert(value and value == value and math.abs(value) < math.huge, "Invalid JSON number")
    position = position + #token

    return value
  end

  local value = parse(0)
  whitespace()
  assert(position > size, "Trailing JSON content")

  return value
end

return json
