-- @description Preview Selected MIDI Notes for 1 Second
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

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
local section, key_init = "PreviewSelectedMIDINotes", "initial_prompt_shown"
local shown = reaper.GetExtState(section, key_init)
local TITLE, TEXT1, TEXT2

if language == "简体中文" then
  TITLE = "预览选中的MIDI音符"
  TEXT1 = "使用此脚本时，轨道需要开启「录音预备」与「输入监听」，以便正确预览 MIDI 音符。\n\n系统将为您自动设置这些选项。\n\n若不再使用脚本，请记得关闭录音预备。\n\n是否要继续？"
  TEXT2 = "首次使用提示"
elseif language == "繁體中文" then
  TITLE = "預聽選取的MIDI音符"
  TEXT1 = "使用此腳本時，軌道需要開啟「錄音預備」與「輸入監聽」，以正確預覽 MIDI 音符。\n\n系統將自動為您設定這些選項。\n\n若不再使用本腳本，請記得關閉錄音預備。\n\n是否要繼續？"
  TEXT2 = "首次使用提示"
else
  TITLE = "Preview Selected MIDI Notes"
  TEXT1 = "To use this script properly, the track must have both record arm and input monitoring enabled to preview MIDI notes correctly.\n\nThese settings will be applied automatically.\n\nIf you no longer use this script, please remember to disable record arm.\n\nDo you want to continue?"
  TEXT2 = "First-Time Use Notice"
end

if shown ~= "1" then
  local ret = reaper.ShowMessageBox(TEXT1, TEXT2, 4)
  if ret == 6 then
    reaper.SetExtState(section, key_init, "1", true)
  else
    return
  end
end

function SetTrackInput_AllMIDIInputsAllChannels(track, enable_monitor)
  if not track or not reaper.ValidatePtr(track, "MediaTrack*") then
    return false, "无效轨道"
  end

  local ALL_MIDI_INPUTS_INDEX = 62 -- 63为所有MIDI输入，62为虚拟MIDI键盘
  local ALL_CHANNELS = 0
  local I_RECINPUT = 4096 + (ALL_MIDI_INPUTS_INDEX << 5) + ALL_CHANNELS
  
  -- 设置轨道 MIDI 输入为 All MIDI Inputs + All Channels
  reaper.SetMediaTrackInfo_Value(track, "I_RECINPUT", I_RECINPUT)
  
  -- 开启录音监听
  if enable_monitor then
    reaper.SetMediaTrackInfo_Value(track, "I_RECARM", 1)
    reaper.SetMediaTrackInfo_Value(track, "I_RECMON", 1)
  end

  return true
end

local editor = reaper.MIDIEditor_GetActive()
if not editor then return end
local take = reaper.MIDIEditor_GetTake(editor)
if not take then return end
local track = reaper.GetMediaItemTake_Track(take)

-- SetTrackInput_AllMIDIInputsAllChannels(track, false)

local playedNotes = {}
local _, noteCount = reaper.MIDI_CountEvts(take)
for i = 0, noteCount-1 do
  local retval, selected, _, _, _, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
  if retval and selected and not playedNotes[pitch] then
    playedNotes[pitch] = { chan = chan, vel = vel }
    reaper.StuffMIDIMessage(0, 0x90 + chan, pitch, vel)
  end
end

reaper.UpdateArrange()

-- 延迟 1 秒后，发送对应的 Note-Off 停止播放
local start_time = reaper.time_precise()
local function OffCheck()
  if reaper.time_precise() < start_time + 1 then
    reaper.defer(OffCheck)
  else
    for pitch, info in pairs(playedNotes) do
      reaper.StuffMIDIMessage(0, 0x80 + info.chan, pitch, 0)
    end
    reaper.UpdateArrange()
  end
end

reaper.defer(OffCheck)