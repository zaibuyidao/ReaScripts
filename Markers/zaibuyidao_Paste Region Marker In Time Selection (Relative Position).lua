-- @description Paste Region Marker In Time Selection (Relative Position)
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   + New Script
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(...)
  for _, v in ipairs({...}) do
    reaper.ShowConsoleMsg(tostring(v) .. " ")
  end
  reaper.ShowConsoleMsg("\n")
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

local language = getSystemLanguage()

if language == "简体中文" then
  swsmsg = "该脚本需要 SWS 扩展，你想现在就下载它吗？"
  swserr = "警告"
  jsmsg = "请右键单击並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然后重新启动 REAPER 並再次运行脚本，谢谢！\n"
  jstitle = "你必须安裝 JS_ReaScriptAPI"
elseif language == "繁體中文" then
  swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
  swserr = "警告"
  jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
  jstitle = "你必須安裝 JS_ReaScriptAPI"
else
  swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
  swserr = "Warning"
  jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
  jstitle = "You must install JS_ReaScriptAPI"
end

if not reaper.SN_FocusMIDIEditor then
  local retval = reaper.ShowMessageBox(swsmsg, swserr, 1)
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

if not reaper.APIExists("JS_Window_Find") then
  reaper.MB(jsmsg, jstitle, 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, jserr, 0)
  end
  return reaper.defer(function() end)
end

local EXT_SECTION = 'COPY_PASTE_REGION_MARKER_IN_TIME_SELECTION'

-- 反序列化标记/区域数据
local function unserialize(str)
  local tbl = {}
  for typeStr, value in str:gmatch('(.-)\31(.-)\30') do
    if typeStr == 'number' then
      table.insert(tbl, tonumber(value))
    elseif typeStr == 'boolean' then
      table.insert(tbl, value == 'true')
    else
      table.insert(tbl, value)
    end
  end
  return tbl
end

-- 生成剪贴板迭代器
local function clipboardIterator()
  local index = 0
  return function()
    index = index + 1
    local key = string.format("marker%03d", index)
    if reaper.HasExtState(EXT_SECTION, key) then
      return key
    end
  end
end

-- 读取剪贴板数据
local function readClipboard()
  local markers = {}
  for key in clipboardIterator() do
    table.insert(markers, unserialize(reaper.GetExtState(EXT_SECTION, key)))
    -- 调试信息：打印读取的标记
    -- print("读取标记: "..key)
  end
  return markers
end

-- 粘贴标记和区域
local function pasteMarkersAndRegions()
  local markers = readClipboard()
  if #markers < 1 then return end

  -- 调试信息：打印标记数量
  -- print("总共标记数量: "..#markers)

  local timeSelectionStart = tonumber(reaper.GetExtState(EXT_SECTION, "timeSelectionStart")) or 0
  local timeSelectionEnd = tonumber(reaper.GetExtState(EXT_SECTION, "timeSelectionEnd")) or 0
  local timeSelectionLength = timeSelectionEnd - timeSelectionStart

  local editCursorPos = reaper.GetCursorPosition()
  local offset = editCursorPos - timeSelectionStart

  local _, markerId, regionId = reaper.CountProjectMarkers(0)
  reaper.Undo_BeginBlock()

  for _, marker in ipairs(markers) do
    local newStart = marker[2] + offset
    local newEnd = marker[1] and (marker[3] + offset) or newStart
    local name = marker[4] -- 获取名称

    -- 避免超出复制区域的长度
    if newEnd - newStart > timeSelectionLength then
      newEnd = newStart + timeSelectionLength
    end

    if marker[1] then
      regionId = regionId + 1
      marker[5] = regionId
    else
      markerId = markerId + 1
      marker[5] = markerId
    end

    reaper.AddProjectMarker2(0, marker[1], newStart, newEnd, name, marker[5], marker[6])
  end

  reaper.Undo_EndBlock("Paste Region Marker In Time Selection (Relative Position)", -1)
end

-- 执行粘贴操作
pasteMarkersAndRegions()
reaper.defer(function() end) -- 禁用自动撤销点