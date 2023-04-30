-- @description Pick Track
-- @version 1.0.5
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

function UnselectAllTracks() -- 反选所有轨道
  local first_track = reaper.GetTrack(0, 0)
  if first_track ~= nil then
      reaper.SetOnlyTrackSelected(first_track)
      reaper.SetTrackSelected(first_track, false)
  end
end

function validateInput(input)
  local nums = {}
  for num in input:gmatch("%d+") do
    local n = tonumber(num)
    if nums[n] then
      return false
    end
    nums[n] = true
  end
  return true
end

function checkOnlyNumbers(input)
  local numbers = true
  for num_str in string.gmatch(input, "([^,]+)") do
    if not tonumber(num_str) then
      numbers = false
      break
    end
  end
  return numbers
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local count_track = reaper.CountTracks(0)
local language = getSystemLanguage()
local num_inputs = math.min(10, count_track)
local captions_csv = ""
local extstate_section = "PICK_TRACK"

if language == "简体中文" then
  title = "选择轨道"
  msgbox1 = "请勿输入重复的轨道编号."
  msgbox2 = "请输入数字."
  err = "错误"
  ip_track = "轨道 "
elseif language == "繁体中文" then
  title = "選擇軌道"
  msgbox1 = "請勿輸入重複的軌道編號."
  msgbox2 = "請輸入數字."
  err = "錯誤"
  ip_track = "軌道 "
else
  title = "Pick Track"
  msgbox1 = "Please do not input duplicate track numbers."
  msgbox2 = "Please enter the number."
  err = "Error"
  ip_track = "Track "
end

for i = 1, num_inputs do
  if i == num_inputs then
    captions_csv = captions_csv .. ip_track .. tostring(i)
  else
    captions_csv = captions_csv .. ip_track .. tostring(i) .. ","
  end
end

local retval, retvals_csv = false, ""

retvals_csv = reaper.GetExtState(extstate_section, "previous_values")

all_numbers = true
repeat
  retval, retvals_csv = reaper.GetUserInputs(title, num_inputs, captions_csv, retvals_csv)
  if not retval then return end

  if not validateInput(retvals_csv) then
    reaper.ShowMessageBox(msgbox1, err, 0)
  end

  if not checkOnlyNumbers(retvals_csv) then
    reaper.ShowMessageBox(msgbox2, err, 0)
  end

until validateInput(retvals_csv) and checkOnlyNumbers(retvals_csv)

reaper.SetExtState(extstate_section, "previous_values", retvals_csv, true)

local tracks_to_select = {}
for num in retvals_csv:gmatch("%d+") do
  local n = tonumber(num)
  if n >= 1 and n <= count_track then
    tracks_to_select[n] = true
  end
end

UnselectAllTracks()

reaper.SelectAllMediaItems(0, false) -- 取消選擇所有對象

local sel_tracks = {} -- 记录选中轨道的表格
for track_num, _ in pairs(tracks_to_select) do
  local track = reaper.GetTrack(0, track_num - 1)
  table.insert(sel_tracks, track) -- 把选中的轨道加入表格
  reaper.SetTrackSelected(track, true)

  local item_num = reaper.CountTrackMediaItems(track)
  if item_num == nil then return end

  for i = 0, item_num-1 do
    local item = reaper.GetTrackMediaItem(track, i)
    reaper.SetMediaItemSelected(item, true) -- 選中所有item
    reaper.UpdateItemInProject(item)
  end
end

-- 恢复选中的轨道
for _, track in ipairs(sel_tracks) do
  reaper.SetTrackSelected(track, true)
end

reaper.Main_OnCommand(40913,0) -- Track: Vertical scroll selected tracks into view
reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()