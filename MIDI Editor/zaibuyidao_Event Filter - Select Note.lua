-- @description Event Filter - Select Note
-- @version 1.0.2
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
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
  jserr = "错误"
elseif language == "繁体中文" then
  swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
  swserr = "警告"
  jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
  jstitle = "你必須安裝 JS_ReaScriptAPI"
  jserr = "錯誤"
else
  swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
  swserr = "Warning"
  jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
  jstitle = "You must install JS_ReaScriptAPI"
  jserr = "Error"
end

if not reaper.SNM_GetIntConfigVar then
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

if not reaper.APIExists("JS_Localize") then
  reaper.MB(jsmsg, jstitle, 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, jserr, 0)
  end
  return reaper.defer(function() end)
end

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
_, notecnt, _, _ = reaper.MIDI_CountEvts(take)

local min_key = reaper.GetExtState("SelectNote", "MinKey")
if (min_key == "") then min_key = "0" end
local max_key = reaper.GetExtState("SelectNote", "MaxKey")
if (max_key == "") then max_key = "127" end
local min_vel = reaper.GetExtState("SelectNote", "MinVel")
if (min_vel == "") then min_vel = "1" end
local max_vel = reaper.GetExtState("SelectNote", "MaxVel")
if (max_vel == "") then max_vel = "127" end
local min_dur = reaper.GetExtState("SelectNote", "MinDur")
if (min_dur == "") then min_dur = "0" end
local max_dur = reaper.GetExtState("SelectNote", "MaxDur")
if (max_dur == "") then max_dur = "65535" end
local min_chan = reaper.GetExtState("SelectNote", "MinChan")
if (min_chan == "") then min_chan = "1" end
local max_chan = reaper.GetExtState("SelectNote", "MaxChan")
if (max_chan == "") then max_chan = "16" end
local min_meas = reaper.GetExtState("SelectNote", "MinMeas")
if (min_meas == "") then min_meas = "1" end
local max_meas = reaper.GetExtState("SelectNote", "MaxMeas")
if (max_meas == "") then max_meas = "99" end
local min_tick = reaper.GetExtState("SelectNote", "MinTick")
if (min_tick == "") then min_tick = "0" end
local max_tick = reaper.GetExtState("SelectNote", "MaxTick")
if (max_tick == "") then max_tick = "1919" end
local reset = reaper.GetExtState("SelectNote", "Reset")
if (reset == "") then reset = "n" end

if language == "简体中文" then
  title = "选择音符"
  captions_csv = "音高,,力度,,时值,,通道,,拍子,,嘀嗒,,重置 (y/n)"
elseif language == "繁体中文" then
  title = "選擇音符"
  captions_csv = "音高,,力度,,時值,,通道,,拍子,,嘀嗒,,重置 (y/n)"
else
  title = "Select Note"
  captions_csv = "Key,,Velocity,,Duration,,Channel,,Beat,,Tick,,Reset (y/n)"
end

retval_ok, retvals_csv = reaper.GetUserInputs(title, 13, captions_csv, min_key ..','.. max_key ..','.. min_vel ..','.. max_vel ..','.. min_dur ..','.. max_dur ..','.. min_chan ..','.. max_chan ..','.. min_meas ..','.. max_meas ..','.. min_tick ..','.. max_tick ..','.. reset)
if not retval_ok then return reaper.SN_FocusMIDIEditor() end

min_key, max_key, min_vel, max_vel, min_dur, max_dur, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick, reset = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
if not tonumber(min_key) or not tonumber(max_key) or not tonumber(min_vel) or not tonumber(max_vel) or not tonumber(min_dur) or not tonumber(max_dur) or not tonumber(min_meas) or not tonumber(max_meas) or not tonumber(min_tick) or not tonumber(max_tick) or not tostring(reset) then return reaper.SN_FocusMIDIEditor() end
min_key, max_key, min_vel, max_vel, min_dur, max_dur, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick, reset = tonumber(min_key), tonumber(max_key), tonumber(min_vel), tonumber(max_vel), tonumber(min_dur), tonumber(max_dur), tonumber(min_chan), tonumber(max_chan), tonumber(min_meas), tonumber(max_meas), tonumber(min_tick), tonumber(max_tick), tostring(reset)

reaper.SetExtState("SelectNote", "MinKey", min_key, false)
reaper.SetExtState("SelectNote", "MaxKey", max_key, false)
reaper.SetExtState("SelectNote", "MinVel", min_vel, false)
reaper.SetExtState("SelectNote", "MaxVel", max_vel, false)
reaper.SetExtState("SelectNote", "MinDur", min_dur, false)
reaper.SetExtState("SelectNote", "MaxDur", max_dur, false)
reaper.SetExtState("SelectNote", "MinChan", min_chan, false)
reaper.SetExtState("SelectNote", "MaxChan", max_chan, false)
reaper.SetExtState("SelectNote", "MinMeas", min_meas, false)
reaper.SetExtState("SelectNote", "MaxMeas", max_meas, false)
reaper.SetExtState("SelectNote", "MinTick", min_tick, false)
reaper.SetExtState("SelectNote", "MaxTick", max_tick, false)

min_chan = min_chan - 1
max_chan = max_chan - 1
min_meas = min_meas - 1

if reset == "y" then
  min_key = "0"
  max_key = "127"
  min_vel = "1"
  max_vel = "127"
  min_dur = "0"
  max_dur = "65535"
  min_chan = "1"
  max_chan = "16"
  min_meas = "1"
  max_meas = "99"
  min_tick = "0"
  max_tick = "1919"
  reset = "n"

  retval_ok, retvals_csv = reaper.GetUserInputs(title, 13, captions_csv, min_key ..','.. max_key ..','.. min_vel ..','.. max_vel ..','.. min_dur ..','.. max_dur ..','.. min_chan ..','.. max_chan ..','.. min_meas ..','.. max_meas ..','.. min_tick ..','.. max_tick ..','.. reset)
  if not retval_ok then return reaper.SN_FocusMIDIEditor() end
  
  min_key, max_key, min_vel, max_vel, min_dur, max_dur, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick, reset = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
  if not tonumber(min_key) or not tonumber(max_key) or not tonumber(min_vel) or not tonumber(max_vel) or not tonumber(min_dur) or not tonumber(max_dur) or not tonumber(min_meas) or not tonumber(max_meas) or not tonumber(min_tick) or not tonumber(max_tick) or not tostring(reset) then return reaper.SN_FocusMIDIEditor() end
  min_key, max_key, min_vel, max_vel, min_dur, max_dur, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick, reset = tonumber(min_key), tonumber(max_key), tonumber(min_vel), tonumber(max_vel), tonumber(min_dur), tonumber(max_dur), tonumber(min_chan), tonumber(max_chan), tonumber(min_meas), tonumber(max_meas), tonumber(min_tick), tonumber(max_tick), tostring(reset)
  
  reaper.SetExtState("SelectNote", "MinKey", min_key, false)
  reaper.SetExtState("SelectNote", "MaxKey", max_key, false)
  reaper.SetExtState("SelectNote", "MinVel", min_vel, false)
  reaper.SetExtState("SelectNote", "MaxVel", max_vel, false)
  reaper.SetExtState("SelectNote", "MinDur", min_dur, false)
  reaper.SetExtState("SelectNote", "MaxDur", max_dur, false)
  reaper.SetExtState("SelectNote", "MinChan", min_chan, false)
  reaper.SetExtState("SelectNote", "MaxChan", max_chan, false)
  reaper.SetExtState("SelectNote", "MinMeas", min_meas, false)
  reaper.SetExtState("SelectNote", "MaxMeas", max_meas, false)
  reaper.SetExtState("SelectNote", "MinTick", min_tick, false)
  reaper.SetExtState("SelectNote", "MaxTick", max_tick, false)

  min_chan = min_chan - 1
  max_chan = max_chan - 1
  min_meas = min_meas - 1
end

function main()
  for i = 0,  notecnt - 1 do
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    local start_meas = reaper.MIDI_GetPPQPos_StartOfMeasure(take, startppqpos)
    local start_tick = startppqpos - start_meas
    local tick = start_tick % midi_tick
    local duration = endppqpos - startppqpos
    reaper.Undo_BeginBlock()
    reaper.MIDI_DisableSort(take)

    if selected == true then
      if not (pitch >= min_key and pitch <= max_key) then -- Key
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
      if not (vel >= min_vel and vel <= max_vel) then -- Velocity
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
      if not (duration >= min_dur and duration <= max_dur) then -- Duration
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
      if not (chan >= min_chan and chan <= max_chan) then -- Channel
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
      if not (start_tick >= min_meas * midi_tick and start_tick < max_meas * midi_tick) then -- Beat
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
      if not (tick >= min_tick and tick <= max_tick) then -- Tick
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
    end
  end
  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock(title, -1)
end

main()
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()