-- @description Insert Pitch Bend
-- @version 1.5.4
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
local pos = reaper.GetCursorPositionEx()
local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
local title = ""
local captions_csv = ""
local msg = ""
local err = ""

if language == "简体中文" then
  title = "插入弯音"
  captions_csv = "弯音值(0=复位):"
  msg = "请输入一个介于 -8192 到 8191 之间的弯音值"
  err = "错误"
elseif language == "繁體中文" then
  title = "插入彎音"
  captions_csv = "彎音值(0=復位):"
  msg = "請輸入一個介於 -8192 到 8191 之間的彎音值"
  err = "錯誤"
else
  title = "Insert Pitch Bend"
  captions_csv = "Pitch Bend Value (0=Reset):"
  msg = "Please enter a pitch bend value between -8192 and 8191."
  err = "Error"
end

local pitchbend = reaper.GetExtState("INSERT_PITCHBEND", "Pitchbend")
if (pitchbend == "") then pitchbend = "0" end

local uok, uinput = reaper.GetUserInputs(title, 1, captions_csv, pitchbend)
if not uok then return reaper.SN_FocusMIDIEditor() end
pitchbend = uinput:match("(.*)")
if not tonumber(pitchbend) then return reaper.SN_FocusMIDIEditor() end
pitchbend = tonumber(pitchbend)

if pitchbend < -8192 or pitchbend > 8191 then
  return reaper.MB(msg, err, 0), reaper.SN_FocusMIDIEditor()
end

reaper.SetExtState("INSERT_PITCHBEND", "Pitchbend", pitchbend, false)

reaper.Undo_BeginBlock()
local LSB = pitchbend & 0x7F
local MSB = (pitchbend >> 7) + 64
reaper.MIDI_InsertCC(take, false, false, ppq, 224, 0, LSB, MSB)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()