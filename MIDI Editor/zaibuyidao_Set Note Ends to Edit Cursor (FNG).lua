-- @description Set Note Ends to Edit Cursor (FNG)
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
local getTakes = getAllTakes()

function endTime(take)
    local curpos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPositionEx(0))
    local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
    local fng_take = reaper.FNG_AllocMidiTake(take)
    for i = 1, notecnt do
        local cur_note = reaper.FNG_GetMidiNote(fng_take, i - 1)
        local selected = reaper.FNG_GetMidiNoteIntProperty(cur_note, "SELECTED") -- 是否有音符被选中
        -- local muted = reaper.FNG_GetMidiNoteIntProperty(cur_note, "MUTED") -- 是否静音
        -- local ppqpos = reaper.FNG_GetMidiNoteIntProperty(cur_note, "POSITION") -- 起始位置
        -- local chan = reaper.FNG_GetMidiNoteIntProperty(cur_note, "CHANNEL") -- 通道
        -- local pitch = reaper.FNG_GetMidiNoteIntProperty(cur_note, "PITCH") -- 音高
        -- local vel = reaper.FNG_GetMidiNoteIntProperty(cur_note, "VELOCITY") -- 力度

        if selected == 1 then
            local noteppq = reaper.FNG_GetMidiNoteIntProperty(cur_note, "POSITION") -- 音符起始位置
            local lenppq = reaper.FNG_GetMidiNoteIntProperty(cur_note, "LENGTH") -- 音符长度
            local endpos = curpos - noteppq
            if noteppq < curpos then
                reaper.FNG_SetMidiNoteIntProperty(cur_note, "LENGTH", endpos) -- 将音符结束位置应用到光标位置
            end
        end
    end
    reaper.FNG_FreeMidiTake(fng_take)
end

function main()
    reaper.Undo_BeginBlock()
    for take, _ in pairs(getTakes) do
        endTime(take)
    end
    reaper.Undo_EndBlock("Set Note Ends to Edit Cursor (FNG)", -1)
end

main()
reaper.UpdateArrange()