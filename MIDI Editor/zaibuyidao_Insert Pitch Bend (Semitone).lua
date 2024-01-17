-- @description Insert Pitch Bend (Semitone)
-- @version 1.5.0
-- @author zaibuyidao
-- @changelog Initial release
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

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local pos = reaper.GetCursorPositionEx(0)
local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
local title = ""
local captions_csv = ""
local msg1 = ""
local msg2 = ""
local err = ""

if language == "简体中文" then
  title = "插入弯音(半音)"
  captions_csv = "半音(0=复位),音高范围"
  msg1 = "请输入一个介于 -12 到 12 之间的值"
  msg2 = "弯音间隔不能大于弯音范围"
  err = "错误"
elseif language == "繁体中文" then
  title = "插入彎音(半音)"
  captions_csv = "半音(0=復位),音高範圍"
  msg1 = "請輸入一個介於 -12 到 12 之間的值"
  msg2 = "彎音間隔不能大於彎音範圍"
  err = "錯誤"
else
  title = "'Insert Pitch Bend (Semitone)"
  captions_csv = "Semitone (0=Reset),Pitch Range"
  msg1 = "Please enter a value between -12 and 12"
  msg2 = "The pitch interval cannot be greater than the pitch range"
  err = "Error"
end

local pitch = reaper.GetExtState("Insert_Pitch_Bend_Semitone", "Pitch")
if (pitch == "") then pitch = "0" end
local range = reaper.GetExtState("InsertPitchBendSemitone", "Range")
if (range == "") then range = "12" end

local uok, uinput = reaper.GetUserInputs(title, 2, captions_csv, pitch ..','.. range)
if not uok then return reaper.SN_FocusMIDIEditor() end
pitch, range = uinput:match("(.*),(.*)")
if not tonumber(pitch) or not tonumber(range) then return reaper.SN_FocusMIDIEditor() end
pitch, range = tonumber(pitch), tonumber(range)

if pitch > 12 or pitch < -12 then
  return reaper.MB(msg1, err, 0), reaper.SN_FocusMIDIEditor()
end

if pitch > range then
  return reaper.MB(msg2, err, 0), reaper.SN_FocusMIDIEditor()
end

reaper.SetExtState("InsertPitchBendSemitone", "Pitch", pitch, false)
reaper.SetExtState("InsertPitchBendSemitone", "Range", range, false)

function getSegments(n)
  local x = 8192
  local p = math.floor((x / n) + 0.5) -- 四舍五入
  local arr = {}
  local cur = 0
  for i = 1, n do
    cur = cur + p
    table.insert(arr, math.min(cur, x))
  end
  local res = {}
  for i = #arr, 1, -1 do
    table.insert(res, -arr[i])
  end
  table.insert(res, 0)
  for i = 1, #arr do
    table.insert(res, arr[i])
  end
  res[#res] = 8191 -- 将最后一个点强制设为8191，否则8192会被reaper处理为-8192
  return res
end

function pitchUp(o, targets)
  if #targets == 0 then error() end
  for i = 1, #targets do
    return targets[o + (range + 1)]
  end
end

function pitchDown(p, targets)
  if #targets == 0 then error() end
  for i = #targets, 1, -1 do
    return targets[p + (range + 1)]
  end
end

reaper.Undo_BeginBlock()
local seg = getSegments(range)

if pitch > 0 then
  pitchbend = pitchUp(pitch, seg)
else
  pitchbend = pitchDown(pitch, seg)
end

LSB = pitchbend & 0x7F
MSB = (pitchbend >> 7) + 64

reaper.MIDI_InsertCC(take, false, false, ppq, 224, 0, LSB, MSB)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()