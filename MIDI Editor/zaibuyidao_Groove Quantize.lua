-- @description Groove Quantize
-- @version 1.6.3
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

local title, captions_csv = "", ""
if language == "简体中文" then
  title = "律动量化"
  captions_csv = "数量:"
elseif language == "繁体中文" then
  title = "律動量化"
  captions_csv = "數量:"
else
  title = "Groove Quantize"
  captions_csv = "Amount:"
end

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
local fudu = reaper.GetExtState("GROOVE_QUANTIZE", "Amount")
if (fudu == "") then fudu = "3" end

local uok, uinput = reaper.GetUserInputs(title, 1, captions_csv, fudu)
if not uok then return reaper.SN_FocusMIDIEditor() end
fudu = uinput:match("(.*)")
if not tonumber(fudu) then return reaper.SN_FocusMIDIEditor() end
fudu = tonumber(fudu)
reaper.SetExtState("GROOVE_QUANTIZE", "Amount", fudu, false)

reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
for i = 0,  notecnt-1 do
  local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
  local start_meas = reaper.MIDI_GetPPQPos_StartOfMeasure(take, startppqpos)
  local start_tick = startppqpos - start_meas
  local tick = start_tick % midi_tick
  if selected then
    local new_velocity
    if tick == 0 then
      new_velocity = math.min(math.max(vel - 1 + math.random(fudu + 1), 1), 127)
    elseif tick == midi_tick/2 then
      new_velocity = math.min(math.max(vel - 1 - fudu + math.random(fudu + 1), 1), 127)
    else
      new_velocity = math.min(math.max(vel - fudu*2 - 1 + math.random(fudu*2 + 1), 1), 127)
    end
    reaper.MIDI_SetNote(take, i, nil, nil, nil, nil, nil, nil, new_velocity, false)
  end
end
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()