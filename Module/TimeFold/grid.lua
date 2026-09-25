-- NoIndex: true
function snap(reaper, project, position, seconds_per_pixel, minimum, maximum)
  if reaper.GetToggleCommandStateEx(0, 1157) ~= 1 then return position end

  local _, division, mode, swing = reaper.GetSetProjectGrid(project, false)
  local qn = reaper.TimeMap2_timeToQN(project, position)
  local measure = reaper.TimeMap_QNToMeasures(project, qn)
  local best, distance = position, math.huge

  for index = math.max(0, measure - 1), measure + 1 do
    local _, first, last = reaper.TimeMap_GetMeasureInfo(project, index)
    local base = mode == 3 and last - first or division * 4
    local step = math.max(1e-9, base)
    local duration = reaper.TimeMap2_QNToTime(project, qn + step) - position
    local pixels = math.max(1e-9, duration / seconds_per_pixel)

    while pixels < 4 and step * 2 <= last - first + 1e-9 do
      step, pixels = step * 2, pixels * 2
    end

    while pixels > 8 do
      step, pixels = step / 2, pixels / 2
    end

    local shift = mode == 1 and math.abs(step - base) < 1e-9 and swing * step / 2 or 0
    local cell = math.floor((qn - first) / step)

    local function consider(value)
      if value < first - 1e-9 or value > last + 1e-9 then return end
      local time = reaper.TimeMap2_QNToTime(project, value)
      local delta = math.abs(time - position)
      if time >= minimum and time <= maximum and delta < distance then best, distance = time, delta end
    end
  
    consider(first)
    consider(last)
  
    for i = cell - 2, cell + 2 do
      consider(first + i * step + (i % 2 == 1 and shift or 0))
    end
  end

  return best
end

return snap
