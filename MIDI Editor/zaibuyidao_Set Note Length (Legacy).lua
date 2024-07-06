-- @description Set Note Length (Legacy)
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @provides [main=main,midi_editor,midi_inlineeditor] .
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

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
local window, _, _ = reaper.BR_GetMouseCursorContext()
local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()

if language == "简体中文" then
    title = "设置音符长度"
    captions_csv = "输入嘀答数:"
elseif language == "繁體中文" then
    title = "設置音符長度"
    captions_csv = "輸入嘀答數:"
else
    title = "Set Note Length"
    captions_csv = "Enter A Tick:"
end

local tick = reaper.GetExtState("SET_NOTE_LENGTH", "Ticks")
if (tick == "") then tick = "10" end
uok, tick = reaper.GetUserInputs(title, 1, captions_csv, tick)
reaper.SetExtState("SET_NOTE_LENGTH", "Ticks", tick, false)

if window == "midi_editor" then
    if not inline_editor then
        if not uok or not tonumber(tick) then return reaper.SN_FocusMIDIEditor() end

        for take, _ in pairs(getTakes) do
            reaper.MIDI_DisableSort(take)
            local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
            for i = 0, notecnt - 1 do
                local _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
                if selected == true then
                  reaper.MIDI_SetNote(take, i, selected, muted, startppqpos, startppqpos + tick, chan, pitch, vel, false)
                end
            end

            reaper.MIDI_Sort(take)
        end
    else
        local take = reaper.BR_GetMouseCursorContext_Take()
        reaper.MIDI_DisableSort(take)
        local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
        for i = 0, notecnt - 1 do
            local _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
            if selected == true then
              reaper.MIDI_SetNote(take, i, selected, muted, startppqpos, startppqpos + tick, chan, pitch, vel, false)
            end
        end

        reaper.MIDI_Sort(take)
    end
    
    if not inline_editor then reaper.SN_FocusMIDIEditor() end
else
    if not uok or not tonumber(tick) then return end
    local count_sel_items = reaper.CountSelectedMediaItems(0)
    if count_sel_items == 0 then return end

    for i = 0, count_sel_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetTake(item, 0)
        reaper.MIDI_DisableSort(take)
        if reaper.TakeIsMIDI(take) then
            local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
            for i = 0, notecnt - 1 do
                local _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
                reaper.MIDI_SetNote(take, i, selected, muted, startppqpos, startppqpos + tick, chan, pitch, vel, false)
            end
        end
        reaper.MIDI_Sort(take)
    end
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()