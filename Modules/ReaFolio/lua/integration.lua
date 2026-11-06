-- @noindex
local M = {}

local function fail(code) error('LINK_' .. code, 0) end

local function text(value, limit)
  if type(value) ~= 'string' or #value > (limit or 32768) or value:find('[%z\1-\31\127]') then fail('INVALID') end
  return value
end

local function number(value)
  if type(value) ~= 'number' or value ~= value or value < 0 or value == math.huge then fail('INVALID') end
  return value
end

local function guid(value)
  text(value, 38)
  if not value:match('^%{%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x%}$') then fail('INVALID') end
  return value:upper()
end

local function path(value)
  value = text(value):gsub('\\', '/')
  if not (value:match('^%a:/') or value:match('^/')) then fail('INVALID') end
  if value:find('/%.%./') or value:match('/%.%.$') or value:find('/%./') then fail('INVALID') end
  return value
end

local function path_key(r, value)
  value = path(value):gsub('/+$', '')
  return r.GetOS():match('Win') and value:lower() or value
end

local function project_path(value)
  value = path(value)
  if not value:lower():match('%.rpp$') then fail('INVALID') end
  return value
end

local function current_project(r)
  local project, filename = r.EnumProjects(-1, '')
  if not project or not filename or filename == '' then fail('SAVE_PROJECT') end
  return project, project_path(filename)
end

local function find_project(r, filename)
  local found, key = nil, path_key(r, filename)
  local index = 0

  while true do
    local project, candidate = r.EnumProjects(index, '')
    if not project then break end
    if candidate ~= '' and path_key(r, candidate) == key then
      if found then fail('PROJECT_AMBIGUOUS') end
      found = project
    end

    index = index + 1
  end

  return found
end

local function action(r, command, section, capture)
  if section ~= 'main' then fail('SECTION') end
  command = text(command, 256)
  local id

  if command:match('^%d+$') then
    id = tonumber(command)
    if id < 1 or id > 2147483647 then
      fail('ACTION_MISSING')
    end
  elseif command:match('^_[%w_&%.%-]+$') then
    id = r.NamedCommandLookup(command)
  else
    fail('INVALID')
  end
  if not id or id == 0 then fail('ACTION_MISSING') end
  local name = r.kbd_getTextFromCmd(id, r.SectionFromUniqueID(0))
  if not name or name == '' then fail('ACTION_MISSING') end

  local stable = r.ReverseNamedCommandLookup(id)

  if stable and stable ~= '' then
    stable = '_' .. stable:gsub('^_', '')
    if not capture and command:match('^%d+$') then fail('ACTION_NAMED') end
    command = stable
  end

  return id, command, name
end

local function markers(r, project, filename, kind)
  local result, index = {}, 0

  while true do
    local ok, region, start, finish, name, id = r.EnumProjectMarkers3(project, index)
    if ok == 0 then break end

    if region == (kind == 'region') then
      local stable

      if r.GetRegionOrMarker and r.GetSetRegionOrMarkerInfo_String then
        local object = r.GetRegionOrMarker(project, index, '')
        if object then
          local found, value = r.GetSetRegionOrMarkerInfo_String(project, object, 'GUID', '', false)
          if found and value ~= '' then stable = guid(value) end
        end
      elseif r.GetSetProjectInfo_String then
        local found, value = r.GetSetProjectInfo_String(project, 'MARKER_GUID:' .. index, '', false)
        if found and value ~= '' then stable = guid(value) end
      end
      result[#result + 1] = {label = (region and 'Region ' or 'Marker ') .. id .. (name ~= '' and ': ' .. name or ''), target = {kind = kind, project = filename, guid = stable, id = id, start = start, finish = finish, name = name}}
    end

    index = index + 1
  end

  return result
end

local function frame(r, project, start, finish)
  start, finish = number(start), number(finish or start)
  r.SetEditCurPos2(project, start, true, false)

  if finish > start then
    local padding = math.max((finish - start) * 0.05, 0.25)
    r.GetSet_ArrangeView2(project, true, 0, 0, math.max(0, start - padding), finish + padding)
  end
end

local function capture(r, request)
  local kind, result = request.kind, {}

  if kind == 'action' then
    local _, command, name = action(r, request.command, request.section, true)
    return {links = {{label = name, target = {kind = kind, section = 'main', command = command}}}}
  end

  local project, filename = current_project(r)

  if kind == 'time' then
    local position = number(r.GetCursorPositionEx(project))
    result[1] = {label = r.format_timestr_pos(position, '', 0), target = {kind = kind, project = filename, start = position}}
  elseif kind == 'selection' then
    local start, finish = r.GetSet_LoopTimeRange2(project, false, false, 0, 0, false)

    if finish <= start then fail('NO_SELECTION') end
    result[1] = {label = r.format_timestr_pos(start, '', 0) .. ' – ' .. r.format_timestr_pos(finish, '', 0),
      target = {kind = kind, project = filename, start = start, finish = finish}}
  elseif kind == 'track' then
    for index = 0, r.CountSelectedTracks2(project, true) - 1 do
      local track = r.GetSelectedTrack2(project, index, true)
      local _, name = r.GetTrackName(track)
      result[#result + 1] = {label = name ~= '' and name or 'Track',
        target = {kind = kind, project = filename, guid = guid(r.GetTrackGUID(track))}}
    end
  elseif kind == 'item' then
    for index = 0, r.CountSelectedMediaItems(project) - 1 do
      local item = r.GetSelectedMediaItem(project, index)
      local _, stable = r.GetSetMediaItemInfo_String(item, 'GUID', '', false)
      local take = r.GetActiveTake(item)
      local name = take and r.GetTakeName(take) or ''
      result[#result + 1] = {label = name ~= '' and name or 'Media item',
        target = {kind = kind, project = filename, guid = guid(stable)}}
    end
  elseif kind == 'marker' or kind == 'region' then
    result = markers(r, project, filename, kind)
  else fail('INVALID') end
  if #result == 0 then fail('NO_TARGET') end

  return {links = result}
end

local function validate(target)
  if type(target) ~= 'table' then fail('INVALID') end
  if target.kind == 'action' then return end
  if target.kind == 'file' then
    path(target.path)
    return
  end
  project_path(target.project)
  if target.kind == 'project' then
    return
  elseif target.kind == 'track' or target.kind == 'item' then
    guid(target.guid)
  elseif target.kind == 'time' then
    number(target.start)
  elseif target.kind == 'selection' then
    if number(target.finish) <= number(target.start) then fail('INVALID') end
  elseif target.kind == 'marker' or target.kind == 'region' then
    if target.guid then
      guid(target.guid)
    else
      if number(target.id) % 1 ~= 0 then fail('INVALID') end
      number(target.start); number(target.finish); text(target.name)
    end
  else
    fail('INVALID')
  end
end

local function resolve_object(r, project, target)
  if target.kind == 'track' then
    for index = -1, r.CountTracks(project) - 1 do
      local track = index < 0 and r.GetMasterTrack(project) or r.GetTrack(project, index)
      if r.GetTrackGUID(track):upper() == target.guid:upper() then return track end
    end
  elseif target.kind == 'item' then
    for index = 0, r.CountMediaItems(project) - 1 do
      local item = r.GetMediaItem(project, index)
      local _, stable = r.GetSetMediaItemInfo_String(item, 'GUID', '', false)
      if stable:upper() == target.guid:upper() then return item end
    end
  else
    for _, entry in ipairs(markers(r, project, target.project, target.kind)) do
      local candidate = entry.target
      if target.guid then
        if candidate.guid == target.guid:upper() then return candidate end
      elseif candidate.id == target.id and candidate.name == target.name
        and math.abs(candidate.start - target.start) < 0.000001
        and math.abs(candidate.finish - target.finish) < 0.000001 then return candidate end
    end
  end

  fail('TARGET_MISSING')
end

local function execute(r, request)
  local target = request.target
  validate(target)

  if target.kind == 'action' then
    local id = action(r, target.command, target.section, false)
    local active = r.EnumProjects(-1, '')
    r.Main_OnCommandEx(id, 0, active)
    return {done = true}
  elseif target.kind == 'file' then
    if not r.CF_ShellExecute then fail('SWS_REQUIRED') end
    if not r.CF_ShellExecute(path(target.path)) then fail('OPEN_FAILED') end
    return {done = true}
  end

  local project = find_project(r, target.project)

  if not project then
    if not r.file_exists(target.project) then fail('PROJECT_MISSING') end
    if request.allowOpen ~= true then return {needsOpen = true, project = target.project} end
    local previous = r.EnumProjects(-1, '')
    -- New project tab, ignoring the user's default template when supported.
    local section = r.SectionFromUniqueID(0)
    local command = r.kbd_getTextFromCmd(41929, section)
    r.Main_OnCommand(command and command ~= '' and 41929 or 40859, 0)
    if r.EnumProjects(-1, '') == previous then fail('OPEN_FAILED') end
    r.Main_openProject(target.project)
    project = find_project(r, target.project)
    if not project then fail('OPEN_FAILED') end
  end

  local object
  if target.kind == 'track' or target.kind == 'item' or target.kind == 'marker' or target.kind == 'region' then
    object = resolve_object(r, project, target)
  end

  r.SelectProjectInstance(project)
  if target.kind == 'time' then
    frame(r, project, target.start)
  elseif target.kind == 'selection' then
    r.GetSet_LoopTimeRange2(project, true, false, target.start, target.finish, false)
    frame(r, project, target.start, target.finish)
  elseif target.kind == 'marker' or target.kind == 'region' then frame(r, project, object.start, object.finish)
  elseif target.kind == 'track' then
    r.SetOnlyTrackSelected(object)
    r.Main_OnCommandEx(40913, 0, project)
  elseif target.kind == 'item' then
    r.SelectAllMediaItems(project, false)
    r.SetMediaItemSelected(object, true)
    r.SetOnlyTrackSelected(r.GetMediaItemTrack(object))
    r.Main_OnCommandEx(40913, 0, project)
    local start = r.GetMediaItemInfo_Value(object, 'D_POSITION')
    frame(r, project, start, start + r.GetMediaItemInfo_Value(object, 'D_LENGTH'))
    r.UpdateArrange()
  end

  return {done = true}
end

function M.handle(r, request)
  if request.operation == 'capture' then return capture(r, request)
  elseif request.operation == 'execute' then return execute(r, request)
  else fail('INVALID') end
end

return M
