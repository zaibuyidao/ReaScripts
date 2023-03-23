-- @description Edit Metadata Tag Custom Tags
-- @version 1.0.2
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @provides
--  [main=main,mediaexplorer] .
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

local TAG = 'U' -- Custom Tags

function print(value)
  reaper.ShowConsoleMsg(tostring(value) .. '\n')
end

if not reaper.SNM_GetIntConfigVar then
  local retval = reaper.ShowMessageBox("This script requires the SWS Extension.\n該脚本需要 SWS 擴展。\n\nDo you want to download it now? \n你想現在就下載它嗎？", "Warning 警告", 1)
  if retval == 1 then
    if not OS then local OS = reaper.GetOS() end
    if OS=="OSX32" or OS=="OSX64" then
      os.execute("open " .. "http://www.sws-extension.org/download/pre-release/")
    else
      os.execute("start " .. "http://www.sws-extension.org/download/pre-release/")
    end
  end
  return
end

if not reaper.APIExists("JS_Localize") then
  reaper.MB("Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\n請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n\nThen restart REAPER and run the script again, thank you!\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n", "You must install JS_ReaScriptAPI 你必須安裝JS_ReaScriptAPI", 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, "錯誤", 0)
  end
  return reaper.defer(function() end)
end

function getSystemLanguage()
  local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))
  local os = reaper.GetOS()
  local lang

  if os == "Win32" or os == "Win64" then -- Windows
    if locale == 936 then -- Simplified Chinese
      lang = "简体中文"
    elseif locale == 950 then -- Traditional Chinese
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  elseif os == "OSX32" or os == "OSX64" then -- macOS
    local handle = io.popen("/usr/bin/defaults read -g AppleLocale")
    local result = handle:read("*a")
    handle:close()
    lang = result:gsub("_", "-"):match("[a-z]+%-[A-Z]+")
    if lang == "zh-CN" then -- 简体中文
      lang = "简体中文"
    elseif lang == "zh-TW" then -- 繁体中文
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  elseif os == "Linux" then -- Linux
    local handle = io.popen("echo $LANG")
    local result = handle:read("*a")
    handle:close()
    lang = result:gsub("%\n", ""):match("[a-z]+%-[A-Z]+")
    if lang == "zh_CN" then -- 简体中文
      lang = "简体中文"
    elseif lang == "zh_TW" then -- 繁體中文
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  end

  return lang
end

function getPathDelimiter()
  if not reaper.GetOS():match("^Win") then
    return "/"
  else
    return "\\"
  end
end

local sep = getPathDelimiter()

function get_mediadb_path(db_name)
  local resource_path = reaper.GetResourcePath() .. sep
  local ini_path = resource_path .. 'reaper.ini'
  local ini_file = io.open(ini_path)
  local content = ini_file:read('*all')
  ini_file:close()

  local shortcut_idx = content:match('ShortcutT(%d+)=' .. db_name)
  if shortcut_idx == nil then return end
  local mediadb_filename = content:match('Shortcut' .. shortcut_idx .. '=([^\n\r]+)')

  return resource_path .. 'MediaDB' .. sep .. mediadb_filename
end

function esc(s)
  local matches =
  {
    ["^"] = "%^";
    ["$"] = "%$";
    ["("] = "%(";
    [")"] = "%)";
    ["%"] = "%%";
    ["."] = "%.";
    ["["] = "%[";
    ["]"] = "%]";
    ["*"] = "%*";
    ["+"] = "%+";
    ["-"] = "%-";
    ["?"] = "%?";
  }
  return (s:gsub(".", matches))
end

function get_sel_item_path_from_me(hwnd) -- 获取选中文件的路径
  local list = reaper.JS_Window_FindChild(hwnd, 'List1', true)
  local sel_count, sel_index = reaper.JS_ListView_ListAllSelItems(list) -- 获取选中项的数量和索引
  if sel_count == 0 then return end
  local sel_index1 = tonumber(sel_index:match('[^,]+')) -- 选中的第一个文件的序号
  local name = reaper.JS_ListView_GetItem(list, sel_index1, 0) -- 选中的第一个文件的名称
  local is_full_path = name:match('[/\\]') -- 检查是否显示完整文件路径
  local ext = name:match(".+%.(%w+)$") -- 获取扩展名，比如 wav
  local resume_ext, resume_full_path, resume_lead_path = false, false, false

  if not ext or not reaper.IsMediaExtension(ext, false) then -- 如果显示扩展名没有开启，那么就开启
    resume_ext = true
    reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42091, 0, 0, 0) -- Options: Show file extension even when file type displayed
    name = reaper.JS_ListView_GetItem(list, sel_index1, 0)
  end
  
  local folderhwnd = reaper.JS_Window_FindChildByID(hwnd, 1002)
  local folder = reaper.JS_Window_GetTitle(folderhwnd) -- 获取数据库名称

  if not folder:match('[/\\]') then -- 路径中是否包含分隔符/或\
    if not reaper.file_exists(name) then -- 检查路径是否有效
      reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42026, 0, 0, 0) -- Browser: Show full path in databases and searches

      if is_full_path then
        resume_lead_path = true
      else
        resume_full_path = true
      end
    end
  end

  local outputs = {}  -- 储存路径
  for idx in sel_index:gmatch('[^,]+') do -- 遍历 sel_index 中所有以逗号分隔的值
    local fn = reaper.JS_ListView_GetItem(list, tonumber(idx), 0)
    fn = fn:match('[/\\]') and fn or folder .. sep.. fn
    if not reaper.file_exists(fn) then break end -- 检查路径是否有效
    outputs[#outputs+1] = esc(fn)
  end

  if resume_ext then reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42091, 0, 0, 0) end -- Options: Show file extension even when file type displayed
  if resume_lead_path then reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42134, 0, 0, 0) end -- Browser: Show leading path in databases and searches
  if resume_full_path then reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42026, 0, 0, 0) end -- Browser: Show full path in databases and searches
  return outputs
end

local function extract_label_value(text)
  if text == nil then text = '' end
  local pattern = "[%u%l]%s*:%s*([^\"]+)"
  local value = text:match(pattern)
  return value
end

function check_names(take_names)
  local same_take_name = true
  local first_name = take_names[1]

  for i = 2, #take_names do
    if first_name ~= take_names[i] then
      same_take_name = false
      break
    end
  end

  return same_take_name and first_name or ""
end

local column_list = {'Title', 'Artist', 'Album', 'Date', 'Genre', 'Comment', 'Description', 'BPM', 'KEY', 'Custom Tags', 'Start Offset', 'Track Number'}
local tag_list = {'T', 'A', 'B', 'y', 'G', 'c', 'd', 'P', 'K', 'U', 'R', 'M'}
local title = reaper.JS_Localize("Media Explorer","common")
local hwnd = reaper.JS_Window_Find(title, true)
local cbo = reaper.JS_Window_FindChildByID(hwnd, 1002)
local namedb = reaper.JS_Window_GetTitle(cbo)
local active_dbpath = get_mediadb_path(namedb)
if active_dbpath == nil then return end

local file = io.open(active_dbpath)
local mediadb = file:read('*all')
file:close()
local path_sel = get_sel_item_path_from_me(hwnd)
if not path_sel or #path_sel == 0 then return end

local tag_name
local tag_names = {}
for k, v in pairs(path_sel) do
  local chunk = mediadb:match('(FILE \"'..v..'\".-[\n\r])FILE ') or mediadb:match('(FILE \"'..v..'\".+)')
  if chunk then
    local get_tag = chunk:match('\"'..'[Uu]'..':[^\"]+\"') or chunk:match('[Uu]'..':%S+') or chunk:match('[Uu]'..':')
    tag_name = extract_label_value(get_tag)
    tag_names[#tag_names + 1] = tag_name
  end
end

local language = getSystemLanguage()

if language == "简体中文" then
  script_title = "编辑元数据标签"
  custom = "自定义标签"
elseif language == "繁体中文" then
  script_title = "編輯元數據標簽"
  custom = "自定義標簽"
else
  script_title = "Edit Metadata Tag"
  custom = "Custom Tags"
end

local uok, uinput = reaper.GetUserInputs(script_title, 1, custom .. ', extrawidth=200', check_names(tag_names))
if not uok then return end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

for k, v in pairs(path_sel) do
  local chunk = mediadb:match('(FILE \"'..v..'\".-[\n\r])FILE ') or mediadb:match('(FILE \"'..v..'\".+)') -- 文件对应的块
  if chunk then
    local get_tag = chunk:match('\"'..'[Uu]'..':[^\"]+\"') or chunk:match('[Uu]'..':%S+') or chunk:match('[Uu]'..':')
    local new_chunk -- = get_tag and chunk:gsub(esc(get_tag), '\"' .. tag .. ':'.. uinput ..'\"')

    if get_tag then
      -- 如果存在U:或者u:标签，则直接替换
      if uinput:find(" ") then
        new_chunk = chunk:gsub(esc(get_tag), '\"' .. TAG .. ':' .. uinput .. '\"')
      else
        new_chunk = chunk:gsub(esc(get_tag), TAG .. ':' .. uinput)
      end
    else
      -- 如果不存在U:或者u:标签，插入新标签到s:前面
      local s_tag_match = chunk:match("s:[%d:]+")
      if s_tag_match then
        if uinput:find(" ") then
          new_chunk = chunk:gsub("(%s*" .. s_tag_match .. ")", ' "' .. TAG .. ':' .. uinput .. '"%1') -- 在 s: 标签前插入带引号的新标签
        else
          new_chunk = chunk:gsub("(%s*" .. s_tag_match .. ")", ' '.. TAG .. ':' .. uinput .. '%1') -- 在 s: 标签前插入不带引号的新标签
        end
      end
    end

    if new_chunk then
      mediadb = mediadb:gsub(esc(chunk), new_chunk)
    end
  end
end

local file = io.open(active_dbpath, 'w')
file:write(mediadb)
file:close()
reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 40018, 0, 0, 0) -- Browser: Refresh

reaper.Undo_EndBlock(script_title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()