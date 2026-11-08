-- @noindex
local M = {}
function M.open(r, path)
  if type(path) ~= 'string' or path:find('[%c"]') then return false end
  local command
  if r.GetOS():match('^Win') then
    path = path:gsub('/', '\\'):gsub('\\+$', '')
    if path:match('^%a:$') then path = path .. '\\.' end
    if not path:match('^%a:\\') and not path:match('^\\\\[^\\]+\\[^\\]+') then return false end
    command = 'explorer.exe "' .. path .. '"'
  else
    if path:sub(1,1) ~= '/' or path:find('[`$\\]') then return false end
    command = (r.GetOS():match('OSX') or r.GetOS():match('macOS')) and '/usr/bin/open ' or '/usr/bin/xdg-open '
    command = command .. '"' .. path .. '"'
  end
  local result = r.ExecProcess(command,-1)
  return result ~= nil and result ~= ''
end
return M
