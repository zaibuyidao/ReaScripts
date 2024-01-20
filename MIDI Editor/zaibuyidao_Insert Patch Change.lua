-- @description Insert Patch Change
-- @version 1.1.6
-- @author zaibuyidao
-- @changelog
--   + Add Multi-Language Support
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

-- Use the formula bank = MSB × 128 + LSB to find the bank number to use in script.

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

function main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  local item = reaper.GetMediaItemTake_Item(take)
  local curpos = reaper.GetCursorPositionEx()
  local ppqpos = reaper.MIDI_GetPPQPosFromProjTime(take, curpos)
  local count, index = 0, {}
  local value = reaper.MIDI_EnumSelNotes(take, -1)
  while value ~= -1 do
    count = count + 1
    index[count] = value
    value = reaper.MIDI_EnumSelNotes(take, value)
  end

  local title = ""
  local captions_csv = ""

  if language == "简体中文" then
    title = "插入音色"
    captions_csv = "音色库,音色编号,偏移"
  elseif language == "繁体中文" then
    title = "插入音色"
    captions_csv = "音色庫,音色編號,偏移"
  else
    title = "Insert Patch Change"
    captions_csv = "Bank,Program number,Offset"
  end

  local BANK = reaper.GetExtState("INSERT_PATCH_CHANGE", "BANK")
  if (BANK == "") then BANK = "259" end
  local PC = reaper.GetExtState("INSERT_PATCH_CHANGE", "PC")
  if (PC == "") then PC = "27" end
  local Tick = reaper.GetExtState("INSERT_PATCH_CHANGE", "Tick")
  if (Tick == "") then Tick = "-10" end

  local uok, uinput = reaper.GetUserInputs(title, 3, captions_csv, BANK ..','.. PC ..','.. Tick)
  if not uok then return reaper.SN_FocusMIDIEditor() end
  local BANK, PC, Tick = uinput:match("(.*),(.*),(.*)")
  if not tonumber(BANK) or not (tonumber(PC) or tostring(PC)) or not tonumber(Tick) then return reaper.SN_FocusMIDIEditor() end

  reaper.SetExtState("INSERT_PATCH_CHANGE", "BANK", BANK, false)
  reaper.SetExtState("INSERT_PATCH_CHANGE", "PC", PC, false)
  reaper.SetExtState("INSERT_PATCH_CHANGE", "Tick", Tick, false)

  if (PC == "C-2") then PC = "0"
  elseif (PC == "C#-2") then PC = "1"
  elseif (PC == "D-2") then PC = "2"
  elseif (PC == "D#-2") then PC = "3"
  elseif (PC == "E-2") then PC = "4"
  elseif (PC == "F-2") then PC = "5"
  elseif (PC == "F#-2") then PC = "6"
  elseif (PC == "G-2") then PC = "7"
  elseif (PC == "G#-2") then PC = "8"
  elseif (PC == "A-2") then PC = "9"
  elseif (PC == "A#-2") then PC = "10"
  elseif (PC == "B-2") then PC = "11"
  elseif (PC == "C-1") then PC = "12"
  elseif (PC == "C#-1") then PC = "13"
  elseif (PC == "D-1") then PC = "14"
  elseif (PC == "D#-1") then PC = "15"
  elseif (PC == "E-1") then PC = "16"
  elseif (PC == "F-1") then PC = "17"
  elseif (PC == "F#-1") then PC = "18"
  elseif (PC == "G-1") then PC = "19"
  elseif (PC == "G#-1") then PC = "20"
  elseif (PC == "A-1") then PC = "21"
  elseif (PC == "A#-1") then PC = "22"
  elseif (PC == "B-1") then PC = "23"
  elseif (PC == "C0") then PC = "24"
  elseif (PC == "C#0") then PC = "25"
  elseif (PC == "D0") then PC = "26"
  elseif (PC == "D#0") then PC = "27"
  elseif (PC == "E0") then PC = "28"
  elseif (PC == "F0") then PC = "29"
  elseif (PC == "F#0") then PC = "30"
  elseif (PC == "G0") then PC = "31"
  elseif (PC == "G#0") then PC = "32"
  elseif (PC == "A0") then PC = "33"
  elseif (PC == "A#0") then PC = "34"
  elseif (PC == "B0") then PC = "35"
  elseif (PC == "C1") then PC = "36"
  elseif (PC == "C#1") then PC = "37"
  elseif (PC == "D1") then PC = "38"
  elseif (PC == "D#1") then PC = "39"
  elseif (PC == "E1") then PC = "40"
  elseif (PC == "F1") then PC = "41"
  elseif (PC == "F#1") then PC = "42"
  elseif (PC == "G1") then PC = "43"
  elseif (PC == "G#1") then PC = "44"
  elseif (PC == "A1") then PC = "45"
  elseif (PC == "A#1") then PC = "46"
  elseif (PC == "B1") then PC = "47"
  elseif (PC == "C2") then PC = "48"
  elseif (PC == "C#2") then PC = "49"
  elseif (PC == "D2") then PC = "50"
  elseif (PC == "D#2") then PC = "51"
  elseif (PC == "E2") then PC = "52"
  elseif (PC == "F2") then PC = "53"
  elseif (PC == "F#2") then PC = "54"
  elseif (PC == "G2") then PC = "55"
  elseif (PC == "G#2") then PC = "56"
  elseif (PC == "A2") then PC = "57"
  elseif (PC == "A#2") then PC = "58"
  elseif (PC == "B2") then PC = "59"
  elseif (PC == "C3") then PC = "60"
  elseif (PC == "C#3") then PC = "61"
  elseif (PC == "D3") then PC = "62"
  elseif (PC == "D#3") then PC = "63"
  elseif (PC == "E3") then PC = "64"
  elseif (PC == "F3") then PC = "65"
  elseif (PC == "F#3") then PC = "66"
  elseif (PC == "G3") then PC = "67"
  elseif (PC == "G#3") then PC = "68"
  elseif (PC == "A3") then PC = "69"
  elseif (PC == "A#3") then PC = "70"
  elseif (PC == "B3") then PC = "71"
  elseif (PC == "C4") then PC = "72"
  elseif (PC == "C#4") then PC = "73"
  elseif (PC == "D4") then PC = "74"
  elseif (PC == "D#4") then PC = "75"
  elseif (PC == "E4") then PC = "76"
  elseif (PC == "F4") then PC = "77"
  elseif (PC == "F#4") then PC = "78"
  elseif (PC == "G4") then PC = "79"
  elseif (PC == "G#4") then PC = "80"
  elseif (PC == "A4") then PC = "81"
  elseif (PC == "A#4") then PC = "82"
  elseif (PC == "B4") then PC = "83"
  elseif (PC == "C5") then PC = "84"
  elseif (PC == "C#5") then PC = "85"
  elseif (PC == "D5") then PC = "86"
  elseif (PC == "D#5") then PC = "87"
  elseif (PC == "E5") then PC = "88"
  elseif (PC == "F5") then PC = "89"
  elseif (PC == "F#5") then PC = "90"
  elseif (PC == "G5") then PC = "91"
  elseif (PC == "G#5") then PC = "92"
  elseif (PC == "A5") then PC = "93"
  elseif (PC == "A#5") then PC = "94"
  elseif (PC == "B5") then PC = "95"
  elseif (PC == "C6") then PC = "96"
  elseif (PC == "C#6") then PC = "97"
  elseif (PC == "D6") then PC = "98"
  elseif (PC == "D#6") then PC = "99"
  elseif (PC == "E6") then PC = "100"
  elseif (PC == "F6") then PC = "101"
  elseif (PC == "F#6") then PC = "102"
  elseif (PC == "G6") then PC = "103"
  elseif (PC == "G#6") then PC = "104"
  elseif (PC == "A6") then PC = "105"
  elseif (PC == "A#6") then PC = "106"
  elseif (PC == "B6") then PC = "107"
  elseif (PC == "C7") then PC = "108"
  elseif (PC == "C#7") then PC = "109"
  elseif (PC == "D7") then PC = "110"
  elseif (PC == "D#7") then PC = "111"
  elseif (PC == "E7") then PC = "112"
  elseif (PC == "F7") then PC = "113"
  elseif (PC == "F#7") then PC = "114"
  elseif (PC == "G7") then PC = "115"
  elseif (PC == "G#7") then PC = "116"
  elseif (PC == "A7") then PC = "117"
  elseif (PC == "A#7") then PC = "118"
  elseif (PC == "B7") then PC = "119"
  elseif (PC == "C8") then PC = "120"
  elseif (PC == "C#8") then PC = "121"
  elseif (PC == "D8") then PC = "122"
  elseif (PC == "D#8") then PC = "123"
  elseif (PC == "E8") then PC = "124"
  elseif (PC == "F8") then PC = "125"
  elseif (PC == "F#8") then PC = "126"
  elseif (PC == "G8") then PC = "127"
  end

  reaper.Undo_BeginBlock()
  local MSB = math.modf(BANK / 128)
  local LSB = math.fmod(BANK, 128)
  reaper.MIDI_DisableSort(take)
  if #index > 0 then
    for i = 1, #index do
      retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, index[i])
      if selected then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos+Tick, 0xB0, chan, 0, MSB) -- CC#00
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos+Tick, 0xB0, chan, 32, LSB) -- CC#32
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos+Tick, 0xC0, chan, PC, 0) -- Program Change
      end
    end
  else
    local selected = true
    local muted = false
    local chan = 0
    reaper.MIDI_InsertCC(take, selected, muted, ppqpos+Tick, 0xB0, chan, 0, MSB) -- CC#00
    reaper.MIDI_InsertCC(take, selected, muted, ppqpos+Tick, 0xB0, chan, 32, LSB) -- CC#32
    reaper.MIDI_InsertCC(take, selected, muted, ppqpos+Tick, 0xC0, chan, PC, 0) -- Program Change
  end
  reaper.MIDI_Sort(take)
  reaper.UpdateItemInProject(item)
  reaper.Undo_EndBlock(title, -1)
end

main()
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()