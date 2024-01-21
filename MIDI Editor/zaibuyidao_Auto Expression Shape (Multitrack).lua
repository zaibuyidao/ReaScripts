-- @description Auto Expression Shape (Multitrack)
-- @version 1.2.2
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

if language == "简体中文" then
  title = "自动表情形狀"
  captions_csv = "CC编号,最小值,最大值,速度(0=慢 1=快),开始弧度(-100至100),结束弧度(-100至100),extrawidth=5"
elseif language == "繁体中文" then
  title = "自動表情形狀"
  captions_csv = "CC編號,最小值,最大值,速度(0=慢 1=快),開始弧度(-100至100),結束弧度(-100至100),extrawidth=5"
else
  title = "Auto Expression Shape"
  captions_csv = "CC number,Min value,Max value,Speed(0=Slow 1=Fast),Bezier in(-100 - 100),Bezier out(-100 - 100),extrawidth=5"
end

local cc_num = reaper.GetExtState("AUTO_EXPRESSION_SHAPE_MULTI", "CC")
local val_01 = reaper.GetExtState("AUTO_EXPRESSION_SHAPE_MULTI", "Val1")
local val_02 = reaper.GetExtState("AUTO_EXPRESSION_SHAPE_MULTI", "Val2")
local speed = reaper.GetExtState("AUTO_EXPRESSION_SHAPE_MULTI", "Speed")
local bezier_in = reaper.GetExtState("AUTO_EXPRESSION_SHAPE_MULTI", "BezierIn")
local bezier_out = reaper.GetExtState("AUTO_EXPRESSION_SHAPE_MULTI", "BezierOut")
local flag = 0

if (cc_num == "") then cc_num = "11" end
if (val_01 == "") then val_01 = "88" end
if (val_02 == "") then val_02 = "127" end
if (speed == "") then speed = "0" end
if (bezier_in == "") then bezier_in = "-20" end
if (bezier_out == "") then bezier_out = "40" end

local user_ok, user_input_csv = reaper.GetUserInputs(title, 6, captions_csv, cc_num..','..val_01..','.. val_02..','.. speed..','..bezier_in..','.. bezier_out)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
cc_num, val_01, val_02, speed, bezier_in, bezier_out = user_input_csv:match("(.*),(.*),(.*),(.*),(.*),(.*)")
if not tonumber(cc_num) or not tonumber(val_01) or not tonumber(val_02)  or not tonumber(speed) or not tonumber(bezier_in) or not tonumber(bezier_out) then return reaper.SN_FocusMIDIEditor() end
cc_num, val_01, val_02, speed, bezier_in, bezier_out = tonumber(cc_num), tonumber(val_01), tonumber(val_02), tonumber(speed), tonumber(bezier_in), tonumber(bezier_out)

reaper.SetExtState("AUTO_EXPRESSION_SHAPE_MULTI", "CC", cc_num, false)
reaper.SetExtState("AUTO_EXPRESSION_SHAPE_MULTI", "Val1", val_01, false)
reaper.SetExtState("AUTO_EXPRESSION_SHAPE_MULTI", "Val2", val_02, false)
reaper.SetExtState("AUTO_EXPRESSION_SHAPE_MULTI", "Speed", speed, false)
reaper.SetExtState("AUTO_EXPRESSION_SHAPE_MULTI", "BezierIn", bezier_in, false)
reaper.SetExtState("AUTO_EXPRESSION_SHAPE_MULTI", "BezierOut", bezier_out, false)

function StartInsert()
  reaper.MIDI_DisableSort(take)
  i = reaper.MIDI_EnumSelNotes(take, -1)
  while i ~= -1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    local len = endppqpos - startppqpos
    if speed == 0 then
      if len >= (tick / 2) and len < tick then -- 如果长度大于等于 240 并且 长度小于 480
        reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
        reaper.MIDI_InsertCC(take, false, muted, startppqpos + (tick * 0.4), 0xB0, chan, cc_num, val_02)
      end
    end
    if len >= tick and len < tick * 2 then -- 如果长度大于等于 480 并且 长度小于 960
      reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      reaper.MIDI_InsertCC(take, false, muted, startppqpos + (tick * 0.75), 0xB0, chan, cc_num, val_02)
    end
    if len == tick * 2 then -- 如果长度等于 960
      reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      reaper.MIDI_InsertCC(take, false, muted, startppqpos + tick, 0xB0, chan, cc_num, val_02)
    end
    if len > tick * 2 then -- 如果长度大于 960
      reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      reaper.MIDI_InsertCC(take, false, muted, startppqpos + (tick * 1.5), 0xB0, chan, cc_num, val_02)
    end
    if speed == 0 then speed_note = (tick / 2) else speed_note = tick end
    if len > 0 and len < speed_note then -- 如果长度大于0 并且小于 240
      if flag == 0 then
        reaper.MIDI_InsertCC(take, false, muted, startppqpos, 0xB0, chan, cc_num, val_02)
        flag = 1
      end
    else
      flag = 0
    end
    i = reaper.MIDI_EnumSelNotes(take, i)
  end

  j = reaper.MIDI_EnumSelCC(take, -1)
  while j ~= -1 do
    reaper.MIDI_SetCCShape(take, j, 5, bezier_in / 100, true)
    reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, true)
    j = reaper.MIDI_EnumSelCC(take, j)
  end

  reaper.MIDI_Sort(take)
end

function EndInsert()
  reaper.MIDI_DisableSort(take)
  i = reaper.MIDI_EnumSelNotes(take, -1)
  while i ~= -1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    local len = endppqpos - startppqpos
    local val_03 = math.modf(((val_02-val_01)/val_02)*65) + val_01
    if len >= tick * 2 then -- 如果长度大于等于 960
      reaper.MIDI_InsertCC(take, true, muted, endppqpos - (tick * 0.75), 0xB0, chan, cc_num, val_02)
      reaper.MIDI_InsertCC(take, false, muted, endppqpos - (tick / 24), 0xB0, chan, cc_num, val_03)
    end
    i = reaper.MIDI_EnumSelNotes(take, i)
  end

  j = reaper.MIDI_EnumSelCC(take, -1)
  while j ~= -1 do
    reaper.MIDI_SetCCShape(take, j, 5, bezier_out / 100, true)
    reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, true)
    j = reaper.MIDI_EnumSelCC(take, j)
  end

  reaper.MIDI_Sort(take)
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items > 0 then
  for i = 1, count_sel_items do
    item = reaper.GetSelectedMediaItem(0, i - 1)
    take = reaper.GetTake(item, 0)
    if not take or not reaper.TakeIsMIDI(take) then return end
    StartInsert()
    EndInsert()
  end
else
  take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take or not reaper.TakeIsMIDI(take) then return end
  StartInsert()
  EndInsert()
end
reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()