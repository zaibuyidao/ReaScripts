-- @description Random Note Ends (Customizable)
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Random Note Script Series, filter "zaibuyidao random note" in ReaPack or Actions to access all scripts.

-- USER AREA
-- Settings that the user can customize.

amount = 3

-- End of USER AREA

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

function main()
    for take, _ in pairs(getTakes) do
        local sel_note = false
        local flag = false
        local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
    
        if reaper.GetToggleCommandStateEx(32060, 40681) == 1 then
            reaper.MIDIEditor_LastFocused_OnCommand(40681,0)
            flag = true
        end
    
        i = reaper.MIDI_EnumSelNotes(take, -1)
        if i ~= -1 then sel_note = true end
        while i ~= -1 do
            local note = {}
            note[i] = {}
            note[i].ret,
            note[i].sel,
            note[i].muted,
            note[i].startppqpos,
            note[i].endppqpos,
            note[i].chan,
            note[i].pitch,
            note[i].vel = reaper.MIDI_GetNote(take, i)
            note_len = note[i].endppqpos - note[i].startppqpos
            if note_len > amount then
                if note[i].sel then
                    reaper.MIDI_SetNote(take, i, nil, nil, nil, (note[i].endppqpos-amount-1)+math.random(amount*2+1), nil, nil, nil, true)
                end
            end

            i = reaper.MIDI_EnumSelNotes(take, i)
        end

        for i = 0, notecnt - 1 do
            _, selected, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, i)
            note_len = endppqpos - startppqpos
            if note_len > amount then
                if not sel_note then
                    reaper.MIDI_SetNote(take, i, nil, nil, nil, (endppqpos-amount-1)+math.random(amount*2+1), nil, nil, nil, true)
                end
            end
        end

        reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40659)
        reaper.MIDI_Sort(take)
    
        if flag then
            reaper.MIDIEditor_LastFocused_OnCommand(40681,0)
        end
    end
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Random Note Ends (Customizable)", -1)
reaper.SN_FocusMIDIEditor()