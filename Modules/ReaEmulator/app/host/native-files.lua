-- @noindex
-- Bounded ROM reads for files larger than the Runtime binary bridge's 16 MiB limit.
local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local pairs64 = {}
for i = 0, 4095 do
  pairs64[i] = alphabet:sub((i >> 6) + 1, (i >> 6) + 1) .. alphabet:sub((i & 63) + 1, (i & 63) + 1)
end
local function base64(bytes)
  local parts, count = {}, 0
  for at = 1, #bytes - 2, 3 do
    local a, b, c = bytes:byte(at, at + 2)
    count = count + 1
    parts[count] = pairs64[(a << 4) | (b >> 4)] .. pairs64[((b & 15) << 8) | c]
  end
  local remaining = #bytes % 3
  if remaining > 0 then
    local a, b = bytes:byte(#bytes - remaining + 1, #bytes)
    b = b or 0
    parts[count + 1] = pairs64[(a << 4) | (b >> 4)] ..
      (remaining == 2 and alphabet:sub(((b & 15) << 2) + 1, ((b & 15) << 2) + 1) or '=') .. '='
  end
  return table.concat(parts)
end
local function encode(text)
  return tostring(text):gsub('[^%w%.%-%_~]', function(char) return string.format('%%%02X', char:byte()) end)
end
local function decode(text)
  return text:gsub('%%(%x%x)', function(hex) return string.char(tonumber(hex, 16)) end)
end

return function(window)
  local section, key = 'ReaEmulator.FileReader', tostring(window)
  local owner = tostring(reaper.time_precise())
  reaper.SetExtState(section, key, owner, false)
  local function step()
    if reaper.GetExtState(section, key) ~= owner then return end
    if not reaper.ReaWeb_IsOpen(window) then
      reaper.DeleteExtState(section, key, false)
      return
    end
    -- At most one bounded read per defer pass; no persistent native file handles.
    local message = reaper.ReaWeb_Receive(window)
    local id, offset, length, expected, encodedPath = message:match('^REAEMU_READ\t([%w%-]+)\t(%d+)\t(%d+)\t(%d+)\t(.+)$')
    if id then
      local ok, result = pcall(function()
        offset, length, expected = tonumber(offset), tonumber(length), tonumber(expected)
        if not offset or not length or not expected or length < 1 or length > 262144 or offset > expected or length > expected - offset then error('Invalid read range') end
        local path = decode(encodedPath)
        if path:find('%z') then error('Invalid file path') end
        local file, failure = io.open(path, 'rb')
        if not file then error(failure or 'Cannot open ROM') end
        local worked, data = pcall(function()
          if file:seek('end') ~= expected then error('ROM size changed during loading') end
          assert(file:seek('set', offset))
          local bytes = file:read(length)
          if not bytes or #bytes ~= length then error('Incomplete ROM read') end
          return base64(bytes)
        end)
        file:close()
        if not worked then error(data) end
        return data
      end)
      reaper.ReaWeb_Send(window, (ok and 'REAEMU_DATA\t' or 'REAEMU_ERROR\t') .. id .. '\t' .. (ok and result or encode(result)))
    end
    reaper.defer(step)
  end
  step()
end
