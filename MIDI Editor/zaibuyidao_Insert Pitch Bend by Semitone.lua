-- @description Insert Pitch Bend by Semitone
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about
--   Pitch Bend Script Series, filter "zaibuyidao pitch bend" in ReaPack or Actions to access all scripts.
--   Requires JS_ReaScriptAPI & SWS Extension

local ZBYDFuncPath = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Utility/zaibuyidao_Functions.lua'
if reaper.file_exists(ZBYDFuncPath) then
  dofile(ZBYDFuncPath)
  if not checkSWSExtension() or not checkJSAPIExtension() then return end
else
  local errorMsg = "Error - Missing Script (错误 - 缺失脚本)\n\n" ..
  "[English]\nThe required 'zaibuyidao Functions' script file was not found. Please ensure the file is correctly placed at:\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\nIf the file is missing, you can install it via ReaPack by searching for 'zaibuyidao Functions' in the ReaPack package browser.\n\n" ..
  "[中文]\n必需的 'zaibuyidao Functions' 脚本文件未找到。请确保文件正确放置在以下位置：\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\n如果文件缺失，您可以通过 ReaPack 包浏览器搜索并安装 'zaibuyidao Functions'。\n"

  reaper.MB(errorMsg, "Missing Script Error/脚本文件缺失错误", 0)

  if reaper.APIExists('ReaPack_BrowsePackages') then
    reaper.ReaPack_BrowsePackages('zaibuyidao Functions')
  else
    local reapackErrorMsg = "Error - ReaPack Not Found (错误 - 未找到 ReaPack)\n\n" ..
    "[English]\nThe ReaPack extension is not found. Please install ReaPack to manage and install REAPER scripts and extensions easily. Visit https://reapack.com for installation instructions.\n\n" ..
    "[中文]\n未找到 ReaPack 扩展。请安装 ReaPack 来便捷地管理和安装 REAPER 脚本及扩展。访问 https://reapack.com 获取安装指南。\n"

    reaper.MB(reapackErrorMsg, "ReaPack Not Found/未找到 ReaPack", 0)
  end
  return
end

local language = getSystemLanguage()

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local pos = reaper.GetCursorPositionEx(0)
local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
local title = ""
local captions_csv = ""
local msg1 = ""
local msg2 = ""
local err = ""

if language == "简体中文" then
  title = "按半音插入弯音"
  captions_csv = "半音(0=复位):,弯音范围:"
  msg1 = "请输入一个介于 -12 到 12 之间的值"
  msg2 = "半音间隔不能大于弯音范围"
  err = "错误"
elseif language == "繁体中文" then
  title = "按半音插入彎音"
  captions_csv = "半音(0=復位):,彎音範圍:"
  msg1 = "請輸入一個介於 -12 到 12 之間的值"
  msg2 = "半音間隔不能大於彎音範圍"
  err = "錯誤"
else
  title = "Insert Pitch Bend by Semitone"
  captions_csv = "Semitone (0=Reset):,Pitchwheel Range:"
  msg1 = "Please enter a value between -12 and 12"
  msg2 = "The semitone interval cannot be greater than the pitchwheel range."
  err = "Error"
end

local pitch = reaper.GetExtState("INSERT_PITCHBEND_SEMITONE", "Pitch")
if (pitch == "") then pitch = "0" end
local range = reaper.GetExtState("INSERT_PITCHBEND_SEMITONE", "Range")
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

reaper.SetExtState("INSERT_PITCHBEND_SEMITONE", "Pitch", pitch, false)
reaper.SetExtState("INSERT_PITCHBEND_SEMITONE", "Range", range, false)

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