-- @description Set CC Curve Shape (Dynamic Menu)
-- @version 1.0.2
-- @author zaibuyidao
-- @changelog
--   + Add Multi-Language Support
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
elseif language == "繁体中文" then
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

local HWND = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(HWND)

local square, linear, slow_start_end, fast_start, fast_end, bezier
local def_square, def_linear, def_slow_start_end, def_fast_start, def_fast_end, def_bezier

-- CC曲线形状勾选状态，如果状态为1则勾选。
if reaper.GetToggleCommandStateEx(32060, 42081) == 1 then square = true end
if reaper.GetToggleCommandStateEx(32060, 42080) == 1 then linear = true end
if reaper.GetToggleCommandStateEx(32060, 42082) == 1 then slow_start_end = true end
if reaper.GetToggleCommandStateEx(32060, 42083) == 1 then fast_start = true end
if reaper.GetToggleCommandStateEx(32060, 42084) == 1 then fast_end = true end
if reaper.GetToggleCommandStateEx(32060, 42085) == 1 then bezier = true end
-- 默认CC曲线形状勾选状态，如果状态为1则勾选。
if reaper.GetToggleCommandStateEx(32060, 42087) == 1 then def_square = true end
if reaper.GetToggleCommandStateEx(32060, 42086) == 1 then def_linear = true end
if reaper.GetToggleCommandStateEx(32060, 42088) == 1 then def_slow_start_end = true end
if reaper.GetToggleCommandStateEx(32060, 42089) == 1 then def_fast_start = true end
if reaper.GetToggleCommandStateEx(32060, 42090) == 1 then def_fast_end = true end
if reaper.GetToggleCommandStateEx(32060, 42091) == 1 then def_bezier = true end

if language == "简体中文" then
  ms_def = "默认 CC 曲线形狀"
  mn_square = "正方形"
  mn_linear = "线性"
  mn_slow_start_end = "慢速开始/结束"
  mn_fast_start = "快速开始"
  mn_fast_end = "快速结束"
  mn_bezier = "贝塞尔"
  mn_def_square = "正方形"
  mn_def_linear = "线性"
  mn_def_slow_start_end = "慢速开始/结束"
  mn_def_fast_start = "快速开始"
  mn_def_fast_end = "快速结束"
  mn_def_bezier = "贝塞尔"
elseif language == "繁体中文" then
  ms_def = "默認 CC 曲綫形狀"
  mn_square = "正方形"
  mn_linear = "綫性"
  mn_slow_start_end = "慢速開始/結束"
  mn_fast_start = "快速開始"
  mn_fast_end = "快速結束"
  mn_bezier = "貝塞爾"
  mn_def_square = "正方形"
  mn_def_linear = "綫性"
  mn_def_slow_start_end = "慢速開始/結束"
  mn_def_fast_start = "快速開始"
  mn_def_fast_end = "快速結束"
  mn_def_bezier = "貝塞爾"
else
  ms_def = "Default CC curve shape"
  mn_square = "Square"
  mn_linear = "Linear"
  mn_slow_start_end = "Slow start/end"
  mn_fast_start = "Fast start"
  mn_fast_end = "Fast end"
  mn_bezier = "Bezier"
  mn_def_square = "Square"
  mn_def_linear = "Linear"
  mn_def_slow_start_end = "Slow start/end"
  mn_def_fast_start = "Fast start"
  mn_def_fast_end = "Fast end"
  mn_def_bezier = "Bezier"
end

local menu = "" -- #CC curve shape||
menu = menu
.. (square and "!" or "") .. mn_square .. "|"
.. (linear and "!" or "") .. mn_linear .. "|"
.. (slow_start_end and "!" or "") .. mn_slow_start_end .. "|"
.. (fast_start and "!" or "") .. mn_fast_start .. "|"
.. (fast_end and "!" or "") .. mn_fast_end .. "|"
.. (bezier and "!" or "") .. mn_bezier .. "|"
.. ">" .. ms_def .. "|"
.. (def_square and "!" or "") .. mn_def_square .. "|"
.. (def_linear and "!" or "") .. mn_def_linear .. "|"
.. (def_slow_start_end and "!" or "") .. mn_def_slow_start_end .. "|"
.. (def_fast_start and "!" or "") .. mn_def_fast_start .. "|"
.. (def_fast_end and "!" or "") .. mn_def_fast_end .. "|"
.. (def_bezier and "!" or "") .. mn_def_bezier .. "|"

local title = "hidden " .. reaper.genGuid()
gfx.init( title, 0, 0, 0, 0, 0 )
local hwnd = reaper.JS_Window_Find(title, true)
if hwnd then
  reaper.JS_Window_Show( hwnd, "HIDE" )
end
gfx.x, gfx.y = gfx.mouse_x-0, gfx.mouse_y-0
local selection = gfx.showmenu(menu)
gfx.quit()

if selection > 0 then
  selection = selection - 0 -- 此处selection值与标题行数关联，标题占用一行-1，占用两行则-2
  -- 设置CC曲线形状
  if selection == 1 then reaper.MIDIEditor_OnCommand(HWND, 42081) end -- Set CC shape to square
  if selection == 2 then reaper.MIDIEditor_OnCommand(HWND, 42080) end -- Set CC shape to linear
  if selection == 3 then reaper.MIDIEditor_OnCommand(HWND, 42082) end -- Set CC shape to slow start/end
  if selection == 4 then reaper.MIDIEditor_OnCommand(HWND, 42083) end -- Set CC shape to fast start
  if selection == 5 then reaper.MIDIEditor_OnCommand(HWND, 42084) end -- Set CC shape to fast end
  if selection == 6 then reaper.MIDIEditor_OnCommand(HWND, 42085) end -- Set CC shape to bezier
  -- 设置默认CC曲线形状
  if selection == 7 then reaper.MIDIEditor_OnCommand(HWND, 42087) end -- Set default CC shape to square
  if selection == 8 then reaper.MIDIEditor_OnCommand(HWND, 42086) end -- Set default CC shape to linear
  if selection == 9 then reaper.MIDIEditor_OnCommand(HWND, 42088) end -- Set default CC shape to slow start/end
  if selection == 10 then reaper.MIDIEditor_OnCommand(HWND, 42089) end -- Set default CC shape to fast start
  if selection == 11 then reaper.MIDIEditor_OnCommand(HWND, 42090) end -- Set default CC shape to fast end
  if selection == 12 then reaper.MIDIEditor_OnCommand(HWND, 42091) end -- Set default CC shape to bezier
end

reaper.SN_FocusMIDIEditor()
reaper.defer(function() end)