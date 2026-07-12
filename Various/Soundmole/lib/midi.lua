-- NoIndex: true
local M = {}

local cache, errors, order = {}, {}, {}
local thumb_cache, thumb_errors, thumb_order = {}, {}, {}
local CACHE_LIMIT, THUMB_LIMIT, THUMB_GRID = 8, 256, 256

function M.is_file(path)
  local ext = tostring(path or ""):match("%.([^.]+)$")
  ext = ext and ext:lower() or ""
  return ext == "mid" or ext == "midi"
end

local function touch(path)
  for i = #order, 1, -1 do
    if order[i] == path then table.remove(order, i) break end
  end
  order[#order + 1] = path
  while #order > CACHE_LIMIT do
    local old = table.remove(order, 1)
    cache[old], errors[old] = nil, nil
  end
end

local function u16(s, p)
  local a, b = s:byte(p, p + 1)
  if not b then return end
  return a * 256 + b
end

local function u32(s, p)
  local a, b, c, d = s:byte(p, p + 3)
  if not d then return end
  return ((a * 256 + b) * 256 + c) * 256 + d
end

local function vlq(s, p, limit)
  local value = 0
  for _ = 1, 4 do
    if p > limit then return end
    local b = s:byte(p); p = p + 1
    value = value * 128 + (b & 0x7F)
    if b < 0x80 then return value, p end
  end
  return value, p
end

function M.seconds_at_tick(data, tick)
  tick = math.max(0, tonumber(tick) or 0)
  if data.ticks_per_second and data.ticks_per_second > 0 then
    return tick / data.ticks_per_second
  end
  local ppq = tonumber(data.ppq) or 0
  if ppq <= 0 then return 0 end
  local tempos = data.tempos or {}
  local lo, hi, found = 1, #tempos, 1
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    if (tempos[mid].tick or 0) <= tick then found, lo = mid, mid + 1 else hi = mid - 1 end
  end
  local tempo = tempos[found] or { tick = 0, usec = 500000, sec = 0 }
  return (tempo.sec or 0) + (tick - (tempo.tick or 0)) / ppq * (tempo.usec or 500000) / 1000000
end

function M.seconds_at_qn(data, qn)
  local ppq = tonumber(data and data.ppq) or 0
  if ppq <= 0 then return 0 end
  return M.seconds_at_tick(data, (tonumber(qn) or 0) * ppq)
end

local function parse(path)
  local f, err = io.open(path, "rb")
  if not f then return nil, err or "open failed" end
  local s = f:read("*a"); f:close()
  if not s or #s < 14 or s:sub(1, 4) ~= "MThd" then return nil, "invalid MIDI header" end

  local header_len = u32(s, 5)
  local format, track_count, division = u16(s, 9), u16(s, 11), u16(s, 13)
  if not header_len or not format or not track_count or not division or header_len < 6 then
    return nil, "invalid MIDI header data"
  end

  local data = {
    path = path, format = format, track_count = track_count, division = division,
    notes = {}, program_changes = {}, tempos = {}, channels = {}, channel_enabled = {}, event_count = 0,
    max_tick = 0,
  }
  if (division & 0x8000) == 0 then
    data.ppq = division
  else
    local fps_code = 256 - ((division >> 8) & 0xFF)
    local fps = (fps_code == 29) and 29.97 or fps_code
    data.ticks_per_second = fps * (division & 0xFF)
  end

  local used, pos, parsed_tracks = {}, 9 + header_len, 0
  while parsed_tracks < track_count and pos + 7 <= #s do
    local chunk_id, chunk_len = s:sub(pos, pos + 3), u32(s, pos + 4)
    if not chunk_len then break end
    local first, last = pos + 8, math.min(#s, pos + 7 + chunk_len)
    pos = last + 1
    if chunk_id == "MTrk" then
      parsed_tracks = parsed_tracks + 1
      local p, tick, running, active = first, 0, nil, {}
      while p <= last do
        local delta; delta, p = vlq(s, p, last)
        if not delta then break end
        tick = tick + delta
        if tick > data.max_tick then data.max_tick = tick end

        local status = s:byte(p)
        if not status then break end
        if status < 0x80 then
          status = running
          if not status then break end
        else
          p = p + 1
          if status < 0xF0 then running = status
          elseif status < 0xF8 then running = nil end
        end
        data.event_count = data.event_count + 1

        if status == 0xFF then
          local meta = s:byte(p); p = p + 1
          local len; len, p = vlq(s, p, last)
          if not len then break end
          if meta == 0x51 and len == 3 and p + 2 <= last then
            local a, b, c = s:byte(p, p + 2)
            data.tempos[#data.tempos + 1] = { tick = tick, usec = a * 65536 + b * 256 + c }
          end
          p = math.min(last + 1, p + len)
          if meta == 0x2F then break end
        elseif status == 0xF0 or status == 0xF7 then
          local len; len, p = vlq(s, p, last)
          if not len then break end
          p = math.min(last + 1, p + len)
        elseif status >= 0xF0 then
          local sys_len = (status == 0xF1 or status == 0xF3) and 1 or (status == 0xF2 and 2 or 0)
          p = math.min(last + 1, p + sys_len)
        else
          local kind, channel = status & 0xF0, (status & 0x0F) + 1
          local bytes = (kind == 0xC0 or kind == 0xD0) and 1 or 2
          local d1, d2 = s:byte(p), bytes == 2 and s:byte(p + 1) or 0
          if not d1 or (bytes == 2 and not d2) then break end
          p = p + bytes
          used[channel] = true
          if kind == 0x90 and d2 > 0 then
            local key = channel * 128 + d1
            active[key] = active[key] or {}
            active[key][#active[key] + 1] = { tick = tick, velocity = d2, pitch = d1, channel = channel }
          elseif kind == 0x80 or (kind == 0x90 and d2 == 0) then
            local key = channel * 128 + d1
            local stack = active[key]
            local note = stack and table.remove(stack)
            if note then
              note.end_tick = math.max(tick, note.tick)
              data.notes[#data.notes + 1] = note
            end
          elseif kind == 0xC0 then
            data.program_changes[#data.program_changes + 1] = {
              tick = tick, channel = channel, program = d1,
            }
          end
        end
      end
      for _, stack in pairs(active) do
        for _, note in ipairs(stack) do
          note.end_tick = math.max(tick, note.tick)
          data.notes[#data.notes + 1] = note
        end
      end
    end
  end

  for channel = 1, 16 do
    if used[channel] then
      data.channels[#data.channels + 1] = channel
      data.channel_enabled[channel] = true
    end
  end

  if data.ppq and data.ppq > 0 then
    table.sort(data.tempos, function(a, b) return a.tick < b.tick end)
    local merged = {}
    for _, tempo in ipairs(data.tempos) do
      if merged[#merged] and merged[#merged].tick == tempo.tick then merged[#merged] = tempo
      else merged[#merged + 1] = tempo end
    end
    if not merged[1] or merged[1].tick > 0 then table.insert(merged, 1, { tick = 0, usec = 500000 }) end
    data.tempos = merged
    local elapsed = 0
    for i, tempo in ipairs(merged) do
      if i > 1 then
        local prev = merged[i - 1]
        elapsed = elapsed + (tempo.tick - prev.tick) / data.ppq * prev.usec / 1000000
      end
      tempo.sec = elapsed
    end
    data.length_qn = data.max_tick / data.ppq
    data.estimated_seconds = data.length_qn * 0.5
  else
    data.length_qn = 0
  end

  data.duration_seconds = M.seconds_at_tick(data, data.max_tick)
  if not data.estimated_seconds then data.estimated_seconds = data.duration_seconds end
  -- REAPER previews beat-based MIDI sources at a 120 BPM base tempo. Keep this
  -- separate from the SMF tempo-map duration so drawing and CF_Preview seeking
  -- use the same time axis as Media Explorer.
  data.preview_seconds = math.max(0, tonumber(data.estimated_seconds) or tonumber(data.duration_seconds) or 0)
  for _, note in ipairs(data.notes) do
    note.file_start_sec = M.seconds_at_tick(data, note.tick)
    note.file_end_sec = M.seconds_at_tick(data, note.end_tick)
    if data.ppq and data.ppq > 0 then
      note.start_sec = note.tick / data.ppq * 0.5
      note.end_sec = note.end_tick / data.ppq * 0.5
    else
      note.start_sec = note.file_start_sec
      note.end_sec = note.file_end_sec
    end
  end
  for _, pc in ipairs(data.program_changes) do
    pc.file_sec = M.seconds_at_tick(data, pc.tick)
    pc.sec = (data.ppq and data.ppq > 0) and (pc.tick / data.ppq * 0.5) or pc.file_sec
  end
  table.sort(data.notes, function(a, b)
    if a.tick == b.tick then return a.pitch < b.pitch end
    return a.tick < b.tick
  end)
  data.min_pitch, data.max_pitch = 127, 0
  for _, note in ipairs(data.notes) do
    if note.pitch < data.min_pitch then data.min_pitch = note.pitch end
    if note.pitch > data.max_pitch then data.max_pitch = note.pitch end
  end
  if #data.notes == 0 then data.min_pitch, data.max_pitch = 0, 127 end
  return data
end

function M.get(path, allow_parse)
  path = tostring(path or "")
  if path == "" or not M.is_file(path) then return nil end
  if cache[path] ~= nil then touch(path); return cache[path] or nil, errors[path] end
  if allow_parse == false then return nil end
  local data, err = parse(path)
  cache[path], errors[path] = data or false, err
  touch(path)
  return data, err
end

local function project(data, width, respect_channels)
  width = math.max(1, math.floor(tonumber(width) or 1))
  local mask = ""
  if respect_channels then
    local bits = {}
    for channel = 1, 16 do bits[channel] = data.channel_enabled[channel] == false and "0" or "1" end
    mask = table.concat(bits)
  end
  local key = tostring(width) .. "|" .. mask
  if data._projection_key == key and data._projection_points then return data._projection_points end

  local lanes = {}
  local duration = math.max(0.000001, tonumber(data.preview_seconds) or tonumber(data.estimated_seconds) or tonumber(data.duration_seconds) or 0)
  for _, note in ipairs(data.notes or {}) do
    if not respect_channels or data.channel_enabled[note.channel] ~= false then
      local x0 = math.min(width - 1, math.floor(math.max(0, math.min(1, (note.start_sec or 0) / duration)) * width))
      local x1 = math.ceil(math.max(0, math.min(1, (note.end_sec or note.start_sec or 0) / duration)) * width)
      if x1 <= x0 then x1 = x0 + 1 end
      if x1 > width then x1 = width end
      local lane = lanes[note.pitch]
      if not lane then lane = {}; lanes[note.pitch] = lane end
      local n = #lane
      if n >= 2 and x0 <= lane[n] + 1 then
        if x1 > lane[n] then lane[n] = x1 end
      else
        lane[n + 1], lane[n + 2] = x0, x1
      end
    end
  end

  local points = {}
  for pitch = tonumber(data.min_pitch) or 0, tonumber(data.max_pitch) or 127 do
    local lane = lanes[pitch]
    if lane then
      for i = 1, #lane, 2 do
        points[#points + 1] = lane[i] / width
        points[#points + 1] = lane[i + 1] / width
        points[#points + 1] = pitch
      end
    end
  end
  data._projection_key, data._projection_points = key, points
  return points
end

function M.project(data, width, respect_channels)
  if not data then return {} end
  return project(data, width, respect_channels == true)
end

local function project_program_changes(data)
  local duration = math.max(0.000001, tonumber(data.preview_seconds) or tonumber(data.estimated_seconds) or 0)
  local points = {}
  for _, pc in ipairs(data.program_changes or {}) do
    points[#points + 1] = math.max(0, math.min(1, (tonumber(pc.sec) or 0) / duration))
    points[#points + 1] = pc.channel or 1
    points[#points + 1] = pc.program or 0
  end
  return points
end

-- 表格仅缓存有上限的轻量像素投影，避免大量可见 MIDI 反复解析或长期保留完整事件表。
function M.thumbnail(path, allow_parse)
  path = tostring(path or "")
  if path == "" or not M.is_file(path) then return nil end
  if thumb_cache[path] ~= nil then
    return thumb_cache[path] or nil, thumb_errors[path], true
  end

  local data, err = M.get(path, allow_parse)
  if not data then
    if err then
      thumb_cache[path], thumb_errors[path] = false, err
      thumb_order[#thumb_order + 1] = path
      while #thumb_order > THUMB_LIMIT do
        local old = table.remove(thumb_order, 1)
        thumb_cache[old], thumb_errors[old] = nil, nil
      end
    end
    return nil, err, err ~= nil
  end

  local points = project(data, THUMB_GRID, false)
  local thumb = {
    points = points,
    program_changes = project_program_changes(data),
    duration_seconds = data.duration_seconds,
    estimated_seconds = data.estimated_seconds,
    preview_seconds = data.preview_seconds,
    min_pitch = data.min_pitch,
    max_pitch = data.max_pitch,
  }
  thumb_cache[path] = thumb
  thumb_order[#thumb_order + 1] = path
  while #thumb_order > THUMB_LIMIT do
    local old = table.remove(thumb_order, 1)
    thumb_cache[old], thumb_errors[old] = nil, nil
  end
  return thumb, nil, true
end

return M
