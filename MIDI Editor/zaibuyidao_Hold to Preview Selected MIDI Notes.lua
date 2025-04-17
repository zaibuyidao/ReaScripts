-- @description Hold to Preview Selected MIDI Notes
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
local temporary_arm = false -- 跟踪是否打开了ARM

function SetTrackInput_AllMIDIInputsAllChannels(track, enable_monitor)
  if not track or not reaper.ValidatePtr(track, "MediaTrack*") then
    return false, "无效轨道"
  end

  local ALL_MIDI_INPUTS_INDEX = 63
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

function EnsureTrackArmed(track)
  if not track or not reaper.ValidatePtr(track, "MediaTrack*") then return false end

  local is_armed = reaper.GetMediaTrackInfo_Value(track, "I_RECARM")
  if is_armed == 1 then
    temporary_arm = false
    return true
  else
    reaper.SetMediaTrackInfo_Value(track, "I_RECARM", 1)
    temporary_arm = true
    return true
  end
end

function RestoreTrackArmIfTemporary(track)
  if temporary_arm and track and reaper.ValidatePtr(track, "MediaTrack*") then
    reaper.SetMediaTrackInfo_Value(track, "I_RECARM", 0)
    temporary_arm = false
  end
end

local editor = reaper.MIDIEditor_GetActive()
if editor == nil then return end

local take = reaper.MIDIEditor_GetTake(editor)
if take == nil then return end

local track = reaper.GetMediaItemTake_Track(take)

-- 检查是否首次运行脚本
local section = "PreviewSelectedMIDINotes"
local key = "initial_prompt_shown"
local shown = reaper.GetExtState(section, key)

if language == "简体中文" then
  title = "预览选中的MIDI音符"
  TEXT1 = "使用此脚本时，轨道需要开启「录音预备」与「输入监听」，以便正确预览 MIDI 音符。\n\n系统将为您自动设置这些选项。\n\n若不再使用脚本，请记得关闭录音预备。\n\n是否要继续？"
  TEXT2 = "首次使用提示"
elseif language == "繁體中文" then
  title = "預聽選取的MIDI音符"
  TEXT1 = "使用此腳本時，軌道需要開啟「錄音預備」與「輸入監聽」，以正確預覽 MIDI 音符。\n\n系統將自動為您設定這些選項。\n\n若不再使用本腳本，請記得關閉錄音預備。\n\n是否要繼續？"
  TEXT2 = "首次使用提示"
else
  title = "Preview Selected MIDI Notes"
  TEXT1 = "To use this script properly, the track must have both record arm and input monitoring enabled to preview MIDI notes correctly.\n\nThese settings will be applied automatically.\n\nIf you no longer use this script, please remember to disable record arm.\n\nDo you want to continue?"
  TEXT2 = "First-Time Use Notice"
end

if shown ~= "1" then
  local ret = reaper.ShowMessageBox(TEXT1, TEXT2, 4) -- MB_YESNO
  
  if ret == 6 then -- 用户选择“是”
    reaper.SetExtState(section, key, "1", true) -- 永久存储
    reaper.SetMediaTrackInfo_Value(track, "I_RECARM", 1)
    reaper.SetMediaTrackInfo_Value(track, "I_RECMON", 1)
  else
    return -- 用户选择“否”则终止脚本
  end
end

local ok, msg = SetTrackInput_AllMIDIInputsAllChannels(track, false)
EnsureTrackArmed(track)

local start_time = reaper.time_precise()
local key_state = reaper.JS_VKeys_GetState(start_time - 2)
local custom_cursor_path = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Various/Advanced Solo/lib/speaker.cur'
-- local custom_cursor_path = debug.getinfo(1, 'S').source:match[[^@?(.*[\/])[^\/]-$]] .. '/speaker.cur'

local function detect_key_press()
  -- 检测被按下的按键
  for key_code = 1, 255 do
    if key_state:byte(key_code) ~= 0 then
      reaper.JS_VKeys_Intercept(key_code, 1) -- 拦截按键，防止干扰其他操作
      return key_code -- 返回检测到的按键码
    end
  end
  return nil -- 没有检测到按键
end

local key = detect_key_press()
if not key then return end -- 如果没有检测到按键，结束脚本

local function is_key_held()
  -- 检测按键是否持续被按下
  key_state = reaper.JS_VKeys_GetState(start_time - 2)
  return key_state:byte(key) == 1
end

local function release()
  -- 恢复初始状态并释放资源
  reaper.JS_Mouse_SetCursor(reaper.JS_Mouse_LoadCursor(32512)) -- 加载默认光标（箭头）
  reaper.JS_VKeys_Intercept(key, -1)

  local _, noteCount, _, _ = reaper.MIDI_CountEvts(take)
  if noteCount == 0 then return end
  
  for i = 0, noteCount-1 do
    local retval, selected, muted, startPPQ, endPPQ, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if retval and selected then
      reaper.StuffMIDIMessage(0, 0x80 + chan, pitch, 0) -- 发送 Note-Off: 0x80 为 Note-Off 状态字节
    end
  end

  RestoreTrackArmIfTemporary(track)
  reaper.UpdateArrange()
end

local function update_cursor_on_hold()
  -- 当按键持续按下时更新光标
  if not is_key_held() then return end
  local cursor = reaper.JS_Mouse_LoadCursorFromFile(custom_cursor_path)
  if cursor then
      reaper.JS_Mouse_SetCursor(cursor)
  end
  reaper.defer(update_cursor_on_hold)
end

local function main()
  reaper.PreventUIRefresh(1)
  if not is_key_held() then return end
  local _, noteCount, _, _ = reaper.MIDI_CountEvts(take)
  if noteCount == 0 then return end
  
  for i = 0, noteCount-1 do
    local retval, selected, muted, startPPQ, endPPQ, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if retval and selected then
      reaper.StuffMIDIMessage(0, 0x90 + chan, pitch, vel) -- 发送 Note-On: 0x90 为 Note-On 状态字节
    end
  end

  update_cursor_on_hold()
  reaper.defer(main)
  reaper.PreventUIRefresh(-1)
end

reaper.defer(main)
reaper.atexit(release)