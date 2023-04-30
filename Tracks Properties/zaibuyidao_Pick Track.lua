-- @description Pick Track
-- @version 1.0.4
-- @author zaibuyidao
-- @changelog Add multilingual support
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @provides
--   [main=main,midi_editor,midi_eventlisteditor] .
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

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local count_track = reaper.CountTracks(0)
local count_sel_track = reaper.CountSelectedTracks(0)
for i = 0, count_sel_track-1 do
  selected_trk = reaper.GetSelectedTrack(0, 0) -- 當軌道為多選時限定只取第一軌
  track_num = reaper.GetMediaTrackInfo_Value(selected_trk, 'IP_TRACKNUMBER')
end

track_num = math.floor(track_num)

local language = getSystemLanguage()

if language == "简体中文" then
  title = "选择轨道"
  uok, uinput = reaper.GetUserInputs("选择轨道, " .. "共计 " .. count_track .. " 条轨道.", 1, "轨道编号", track_num)
elseif language == "繁体中文" then
  title = "選擇軌道"
  uok, uinput = reaper.GetUserInputs("選擇軌道, " .. "共計 " .. count_track .. " 條軌道.", 1, "軌道編號", track_num)
else
  title = "Pick Track"
  uok, uinput = reaper.GetUserInputs("Pick Track, " .. "total " .. count_track .. " tracks.", 1, "Track number", track_num)
end

sel_only_num = uinput:match("(.*)")
if not uok or not tonumber(sel_only_num) then return reaper.SN_FocusMIDIEditor() end
sel_only_num = tonumber(sel_only_num)

function UnselectAllTracks()
	first_track = reaper.GetTrack(0, 0)
	reaper.SetOnlyTrackSelected(first_track)
	reaper.SetTrackSelected(first_track, false)
end

sel_only_num = sel_only_num-1

for i = 0, count_track-1 do
  if count_track > sel_only_num then
    
    UnselectAllTracks()
    local sel_track = reaper.GetTrack(0, sel_only_num)
    reaper.SetTrackSelected(sel_track, true)

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

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()