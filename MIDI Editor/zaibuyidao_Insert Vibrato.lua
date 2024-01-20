-- @description Insert Vibrato
-- @version 2.0.6
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

local _SN_FocusMIDIEditor = reaper.SN_FocusMIDIEditor
reaper.SN_FocusMIDIEditor = function(...) if _SN_FocusMIDIEditor then _SN_FocusMIDIEditor(...) end end

function get_curve0(bottom, top, num) -- 正弦曲线间隙版本
  local scale = math.abs(top-bottom) / 2
  local step_length = math.pi * 2 / (num -2)
  local result = {}
  local cur = -math.pi
  local revert = 1
  if (top < bottom) then revert = -1 end
  local offset = bottom + scale
  if (top < bottom) then offset = bottom - scale end
  for i=1,num/2 do
    table.insert(result, math.floor(math.cos(cur) * scale * revert + offset + 0.5))
    cur = cur + step_length
  end

  -- 复制对称点
  local s = #result
  for i=s,1,-1 do
    table.insert(result,result[i])
  end

  return result
end

function get_curve1(bottom, top, num) -- 正弦曲线版本
  local scale = math.abs(top-bottom) / 2
  local step_length = math.pi * 2 / num
  local result = {}
  local cur = -math.pi
  local revert = 1
  if (top < bottom) then revert = -1 end
  local offset = bottom + scale
  if (top < bottom) then offset = bottom - scale end
  for i=1,num do
    table.insert(result, math.floor(math.cos(cur) * scale * revert + offset + 0.5))
    cur = cur + step_length
  end
  return result
end

function get_curve2(bottom, top, num) -- 三角波曲线版本
  local result = {}
  local step = (top - bottom) / (num / 2)
  local cur = bottom
  for i = 1, num/2 do
    table.insert(result,  math.floor(cur))
    cur = cur + step
  end
  for i = 1, num/2 do
    table.insert(result, math.floor(cur))
    cur = cur - step
  end
  return result
end

function get_curve3(bottom, top, num) -- 方波曲线版本
  local result = {}
  for i = 1, num/2 do
    table.insert(result,  math.floor(bottom))
  end
  for i = 1, num/2 do
    table.insert(result, math.floor(top))
  end
  return result
end

function get_curve4(bottom, top, num) -- 锯齿波曲线版本
  local result = {}
  local step = (top - bottom) / (num - 1)
  local cur = bottom
  for i = 1, num do
    table.insert(result,  math.floor(cur))
    cur = cur + step
  end
  return result
end

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not take or not reaper.TakeIsMIDI(take) then return end

local bottom = reaper.GetExtState("INSERT_VIBRATO", "Bottom")
if (bottom == "") then bottom = "0" end
local top = reaper.GetExtState("INSERT_VIBRATO", "Top")
if (top == "") then top = "1024" end
local times = reaper.GetExtState("INSERT_VIBRATO", "Times") 
if (times == "") then times = "16" end
local length = reaper.GetExtState("INSERT_VIBRATO", "Length")
if (length == "") then length = "240" end
local num = reaper.GetExtState("INSERT_VIBRATO", "Num")
if (num == "") then num = "12" end
local shape = reaper.GetExtState("INSERT_VIBRATO", "Shape")
if (shape == "") then shape = "0" end

local captions_csv = ""
if language == "简体中文" then
  title = "插入揉弦"
  captions_csv = "起始点,最高点,重复,长度,点数,0=正弦波 1=三角波"
elseif language == "繁体中文" then
  title = "插入揉弦"
  captions_csv = "起始點,最高點,重複,長度,點數,0=正弦波 1=三角波"
else
  title = "Insert Vibrato"
  captions_csv = "Starting value,Highest value,Repetitions,Length,Points,0=Sine 1=Triangle"
end

local uok, uinput = reaper.GetUserInputs(title, 6, captions_csv, bottom ..','.. top ..','.. times .. "," .. length .. "," .. num .. "," .. shape)
if not uok then return reaper.SN_FocusMIDIEditor() end
bottom, top, times, length, num, shape = uinput:match("(.*),(.*),(.*),(.*),(.*),(.*)")
if not tonumber(bottom) or not tonumber(top) or not tonumber(times) or not tonumber(length) or not tonumber(num) or not tonumber(shape) then return reaper.SN_FocusMIDIEditor() end
bottom, top, times, length, num, shape = tonumber(bottom), tonumber(top), tonumber(times), tonumber(length), tonumber(num), tonumber(shape)
if times < 1 or shape > 1 then return reaper.SN_FocusMIDIEditor() end

reaper.SetExtState("INSERT_VIBRATO", "Bottom", bottom, false)
reaper.SetExtState("INSERT_VIBRATO", "Top", top, false)
reaper.SetExtState("INSERT_VIBRATO", "Times", times, false)
reaper.SetExtState("INSERT_VIBRATO", "Length", length, false)
reaper.SetExtState("INSERT_VIBRATO", "Num", num, false)
reaper.SetExtState("INSERT_VIBRATO", "Shape", shape, false)

local step_length = length / num

local cur_pos = reaper.GetCursorPositionEx() -- 获取光标位置
local cur_tick = reaper.MIDI_GetPPQPosFromProjTime(take, cur_pos) -- 转换光标的tick位置
reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)

idx = reaper.MIDI_EnumSelCC(take, -1) -- 反选所有CC
while idx ~= -1 do
  reaper.MIDI_SetCC(take, idx, false, false, nil, nil, nil, nil, nil, false)
  idx = reaper.MIDI_EnumSelCC(take, idx)
end

chan = 0 -- 通道默认为0

if shape == 0 then
  curve = get_curve1(bottom, top, num)
elseif shape == 1 then
  curve = get_curve2(bottom, top, num)
elseif shape == 2 then
  curve = get_curve3(bottom, top, num)
elseif shape == 3 then
  curve = get_curve4(bottom, top, num)
end

-- for j = 1, #curve do
--   Msg(curve[j])
-- end

for i = 1, times do
  for j = 1, #curve do
    local value = curve[j]
    value = value + 8192
    local LSB = value & 0x7f -- 低7位
    local MSB = value >> 7 & 0x7f -- 高7位
    reaper.MIDI_InsertCC(take, true, false, cur_tick, 224, chan, LSB, MSB) -- 224=弯音，LSB+MSB=弯音值
    cur_tick = cur_tick + step_length
  end
end
if (curve[#curve] ~= bottom) then
  value = bottom + 8192
  reaper.MIDI_InsertCC(take, false, false, cur_tick, 224, chan, value & 0x7f, value >> 7 & 0x7f)
end

if shape == 0 or shape == 1 then
  j = reaper.MIDI_EnumSelCC(take, -1) -- 选中CC设置形状
  while j ~= -1 do
    reaper.MIDI_SetCCShape(take, j, 1, 0, false)
    reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, false)
    j = reaper.MIDI_EnumSelCC(take, j)
  end
elseif shape == 2 or shape == 3 then
  j = reaper.MIDI_EnumSelCC(take, -1) -- 选中CC设置形状
  while j ~= -1 do
    reaper.MIDI_SetCCShape(take, j, 0, 0, false)
    reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, false)
    j = reaper.MIDI_EnumSelCC(take, j)
  end
end

reaper.MIDI_Sort(take)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40366) -- CC: Set CC lane to Pitch

-- local c = get_curve(0,1024,12)
-- for j = 1, #c do
--   Msg(c[j])
-- end