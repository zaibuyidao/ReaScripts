-- @noindex
local M = {}
-- Compatibility with Runtime builds whose validated reveal operation fails at
-- ILCreateFromPathW. Only this exact post-validation error permits the fallback.
function M.open_legacy(r, result, row, folder)
  local err = result.error
  if type(err) ~= 'table' or err.code ~= 'INVALID_PATH' or err.message ~= 'Cannot locate file in Explorer' or not r.GetOS():match('^Win') then return false end
  local path = folder == 'root' and row.root or row.dataPath
  if type(path) ~= 'string' or path:find('[%c"]') then return false end
  path = path:gsub('/', '\\'):gsub('\\+$', '')
  if path:match('^%a:$') then path = path .. '\\.' end
  if not path:match('^%a:\\') and not path:match('^\\\\[^\\]+\\[^\\]+') then return false end
  -- ExecProcess launches the executable directly; no cmd.exe, no shell expansion.
  local launched = r.ExecProcess('explorer.exe "' .. path .. '"', -1)
  return launched ~= nil and launched ~= ''
end

return M
