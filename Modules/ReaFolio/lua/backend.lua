-- @noindex
local directory = debug.getinfo(1, 'S').source:sub(2):match('^(.*[/\\])')
local json = dofile(directory .. 'json.lua')
local M = {}

function fail(code) error(code, 0) end

function read(path, limit)
  local file = io.open(path, 'rb')

  if not file then
    fail('FILE_IO')
  end

  local text = file:read(limit + 1)
  file:close()

  if not text or #text > limit then
    fail('BUFFER_LIMIT')
  end

  return text
end

function exists(path)
  local file = io.open(path, 'rb')

  if file then
    file:close()
    return true
  end

  return false
end

function normalize(path, windows)
  path = path:gsub('\\', '/'):gsub('/+$', '')

  return windows and path:lower() or path
end

function valid_filename(filename)
  if type(filename) ~= 'string'
    or #filename > 240
    or not filename:lower():match('%.md$')
    or filename:find('[%z\1-\31\127<>:"/\\|?*]') then
    fail('UNSAFE_PATH')
  end

  local title = filename:sub(1, -4)

  if title == ''
    or title:match('^%s')
    or title:match('[. ]$') then
    fail('UNSAFE_PATH')
  end
end

function M.begin(request, dataPath, windows)
  if type(request) ~= 'table'
    or (request.action ~= 'delete-note' and request.action ~= 'rename-note') then
    fail('INVALID_REQUEST')
  end

  if type(request.root) ~= 'string'
    or type(request.filename) ~= 'string'
    or type(request.token) ~= 'string'
    or type(request.expected) ~= 'string' then
    fail('INVALID_REQUEST')
  end

  local filename = request.filename
  valid_filename(filename)

  if request.action == 'rename-note' then
    valid_filename(request.destination)

    if type(request.expectedStaged) ~= 'string'
      or not request.expectedStaged:match('^%d+:%d+:%d+$') then
      fail('INVALID_REQUEST')
    end
  end

  if #request.token ~= 36 or not request.token:match('^[%x%-]+$') then
    fail('UNSAFE_PATH')
  end

  if not request.expected:match('^%d+:%d+:%d+$') then
    fail('INVALID_REQUEST')
  end

  local config = json.decode(read(dataPath .. '/settings.json', 65536))

  if type(config.root) ~= 'string'
    or normalize(config.root, windows) ~= normalize(request.root, windows) then
    fail('UNSAFE_PATH')
  end

  local root = config.root:gsub('\\', '/'):gsub('/+$', '')
  local source = root .. '/' .. filename
  local target = root .. '/.reafolio-trash/' .. request.token .. '.md'
  local destination = request.action == 'rename-note' and root .. '/' .. request.destination or nil

  if destination
    and exists(destination)
    and normalize(destination, windows) ~= normalize(source, windows) then
    fail('FILE_EXISTS')
  end

  if exists(target) then
    fail('FILE_EXISTS')
  end

  local file = io.open(source, 'rb')

  if not file then
    fail('CONFLICT')
  end

  return {
    file = file,
    source = source,
    target = target,
    expected = request.expected,
    length = 0,
    a = 2166136261,
    b = 5381,
    destination = destination,
    staged = destination and root .. '/.reafolio-trash/' .. request.token .. '.pending.md' or nil,
    expectedStaged = request.expectedStaged,
    sourceExpected = request.expected,
    phase = 'source'
  }
end

function M.step(job)
  local chunk = job.file:read(65536)

  if chunk then
    job.length = job.length + #chunk

    if job.length > 16 * 1024 * 1024 then
      job.file:close()
      job.file = nil
      fail('BUFFER_LIMIT')
    end

    for index = 1, #chunk do
      local byte = chunk:byte(index)
      job.a = ((job.a ~ byte) * 16777619) & 0xffffffff
      job.b = ((job.b * 33) ~ byte) & 0xffffffff
    end

    return false
  end

  job.file:close()
  job.file = nil

  local signature = string.format('%d:%d:%d', job.length, job.a, job.b)

  if signature ~= job.expected then
    fail('CONFLICT')
  end

  if job.destination and job.phase == 'source' then
    local file = io.open(job.staged, 'rb')

    if not file then
      fail('FILE_IO')
    end

    job.file = file
    job.expected = job.expectedStaged
    job.phase = 'staged'
    job.length = 0
    job.a = 2166136261
    job.b = 5381

    return false
  end

  if job.destination and job.phase == 'staged' then
    local file = io.open(job.source, 'rb')

    if not file then
      fail('CONFLICT')
    end

    job.file = file
    job.expected = job.sourceExpected
    job.phase = 'source-final'
    job.length = 0
    job.a = 2166136261
    job.b = 5381

    return false
  end

  if exists(job.target) then
    fail('FILE_EXISTS')
  end

  if not os.rename(job.source, job.target) then
    fail('FILE_IO')
  end

  if job.destination then
    if exists(job.destination) or not os.rename(job.staged, job.destination) then
      if not exists(job.source) and os.rename(job.target, job.source) then
        fail('FILE_IO')
      end

      fail('RENAME_RECOVERY_REQUIRED')
    end
  end

  return true
end

function M.run(reaper, id, key, dataPath)
  local section = 'ReaWebAPI.reafolio.Backends'

  if reaper.GetExtState(section, key) == tostring(id) then
    return
  end

  reaper.SetExtState(section, key, tostring(id), false)

  local job, requestId

  local function reply(value, code, replyId)
    reaper.ReaWeb_Send(id, json.encode({
      type = 'reafolio-reply',
      id = replyId or requestId,
      value = value,
      error = code
    }))
  end

  reaper.atexit(function()
    if job and job.file then
      job.file:close()
    end

    if reaper.GetExtState(section, key) == tostring(id) then
      reaper.DeleteExtState(section, key, false)

      if reaper.ReaWeb_IsOpen(id) then
        reaper.ReaWeb_Close(id)
      end
    end
  end)

  local function loop()
    if not reaper.ReaWeb_IsOpen(id) then
      return
    end

    for _ = 1, 8 do
      local text = reaper.ReaWeb_Receive(id)

      if text == '' then
        break
      end

      local ok, request = pcall(json.decode, text)

      if ok
        and type(request) == 'table'
        and request.type == 'reafolio'
        and type(request.id) == 'string' then
        if job then
          reply(nil, 'BUSY', request.id)
        else
          requestId = request.id

          local started, result = pcall(
            M.begin,
            request,
            dataPath,
            reaper.GetOS():match('Win') ~= nil
          )

          if started then
            job = result
          else
            reply(nil, result)
          end
        end
      end
    end

    if job then
      local ok, finished = pcall(M.step, job)

      if not ok then
        if job.file then
          job.file:close()
        end

        reply(nil, finished)
        job = nil
      elseif finished then
        reply(true)
        job = nil
      end
    end

    reaper.defer(loop)
  end

  loop()
end

return M
