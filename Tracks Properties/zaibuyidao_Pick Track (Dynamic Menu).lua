-- @description Pick Track (Dynamic Menu)
-- @version 1.1.3
-- @author zaibuyidao
-- @changelog Add multilingual support
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @provides: [main=main,midi_editor,midi_eventlisteditor] .
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
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

local language = getSystemLanguage()

local count_track = reaper.CountTracks(0)
local menu = "" -- #Pick Track|#Track List|| -- 標題
for i = 1, count_track do
  local track = reaper.GetTrack(0, i - 1)
  local ok, track_name = reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', '', false)
  local track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
  local folder = reaper.GetMediaTrackInfo_Value(track, 'I_FOLDERDEPTH')

  if reaper.IsTrackSelected(track) == true then
    flag = true
  else
    flag = false
  end

  if language == "简体中文" then
    menu_track = "轨道 "
    menu_folder = "文件夹 "
  elseif language == "繁体中文" then
    menu_track = "軌道 "
    menu_folder = "文件夾 "
  else
    menu_track = "Track "
    menu_folder = "Folder "
  end
  
  if folder <= 0 then
    menu = menu .. (flag and "!" or "") .. menu_track .. i .. ": " .. track_name .. "|"
  else
    menu = menu .. (flag and "!" or "") .. menu_folder .. i .. ": " .. track_name .. "|"
  end
end

local title = "hidden " .. reaper.genGuid()
gfx.init( title, 0, 0, 0, 0, 0 )
local hwnd = reaper.JS_Window_Find( title, true )
if hwnd then
  reaper.JS_Window_Show( hwnd, "HIDE" )
end
gfx.x, gfx.y = gfx.mouse_x-0, gfx.mouse_y-0
local selection = gfx.showmenu(menu)
gfx.quit()

if selection > 0 then
  for i = 0, count_track-1 do
    local track = reaper.GetTrack(0, i)

    if selection == i+1 then
      reaper.SetTrackSelected(track, true)
    else
      reaper.SetTrackSelected(track, false)
    end
  end

  local count_sel_track = reaper.CountSelectedTracks(0)
  for i = 0, count_sel_track-1 do
    local sel_track =  reaper.GetSelectedTrack(0, i)
    local item_num = reaper.CountTrackMediaItems(sel_track)
    if item_num == nil then return end
  
    reaper.SelectAllMediaItems(0, false) -- 取消選擇所有對象
  
    for i = 0, item_num-1 do
      local item = reaper.GetTrackMediaItem(sel_track, i)
      reaper.SetMediaItemSelected(item, true) -- 選中所有item
      reaper.UpdateItemInProject(item)
    end
  end
  reaper.Main_OnCommand(40913,0) -- Track: Vertical scroll selected tracks into view
end

reaper.SN_FocusMIDIEditor()
reaper.defer(function() end)