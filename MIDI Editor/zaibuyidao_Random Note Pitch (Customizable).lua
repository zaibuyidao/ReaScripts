-- @description Random Note Pitch (Customizable)
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

min_val = 60
max_val = 72

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

-- local language = getSystemLanguage()
-- local getTakes = getAllTakes()

function main()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end

    if min_val > 127 then
        min_val = 127
    elseif min_val < 0 then
        min_val = 0
    elseif max_val > 127 then
        max_val = 127
    elseif max_val < 0 then
        max_val = 0
    elseif min_val > max_val then
        local t = max_val
        max_val = min_val
        min_val = t
    end

    if min_val == max_val then
        return
            reaper.MB("Random interval is empty, please re-enter", "Error", 0),
            reaper.SN_FocusMIDIEditor()
    end

    local diff = (max_val+1) - min_val
    local sel_note = false

    reaper.MIDI_DisableSort(take)
    local sel = reaper.MIDI_EnumSelNotes(take, -1)
    if sel ~= -1 then sel_note = true end

    local flag
    if reaper.GetToggleCommandStateEx(32060, 40681) == 1 then
        reaper.MIDIEditor_LastFocused_OnCommand(40681,0) --Options: Correct overlapping notes while editing
        flag = true
    end

    local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)

    for i = 0, notecnt - 1 do
        _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        if selected or not sel_note then
            pitch = tonumber(min_val + math.random(diff)) - 1
            reaper.MIDI_SetNote(take, i, nil, nil, nil, nil, nil, pitch, nil, false)
        end
    end

    reaper.MIDI_Sort(take)

    if flag then
        reaper.MIDIEditor_LastFocused_OnCommand(40681, 0)
    end
    --reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40767) -- Force selected notes into key signature
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Random Note Pitch (Customizable)", -1)
reaper.UpdateArrange()