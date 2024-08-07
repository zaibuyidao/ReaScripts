-- @description Random Note Position by Grid Within Time Selection (Single Line Only)
-- @version 1.0.4
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Random Note Script Series, filter "zaibuyidao random note" in ReaPack or Actions to access all scripts.

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

if language == "简体中文" then
    title = "在时间选区内按网格随机音符位置(仅限单旋律)"
elseif language == "繁体中文" then
    title = "在時間選區内按網格隨機音符位置(僅限單旋律)"
else
    title = "Random Note Position by Grid Within Time Selection (Single Line Only)"
end

function isOverlap(take, rand_pos, notelen, pitch, notecnt, currentIndex, checkPitch)
    for j = 0, notecnt - 1 do
        if j ~= currentIndex then
            local _, _, _, startppqpos, endppqpos, _, notePitch, _ = reaper.MIDI_GetNote(take, j)
            if (not checkPitch or pitch == notePitch) and (rand_pos < endppqpos and rand_pos + notelen > startppqpos) then
                return true
            end
        end
    end
    return false
end

function main()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
    local grid_qn = reaper.MIDI_GetGrid(take)
    local grid = math.floor(midi_tick * grid_qn)

    local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
    if notecnt == 0 then return end

    -- 清除现有的时间选区
    -- reaper.GetSet_LoopTimeRange2(0, true, false, 0, 0, false)

    local time_start, time_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, 0)
    local loop_start, loop_end, loop_len

    -- https://forum.cockos.com/showthread.php?t=293115
    -- save the existing time selection
    local time_start_original, time_end_original = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, 0)

    if time_start == time_end then
        local min_start, max_end
        for i = 0, notecnt - 1 do
            local _, selected, _, startppqpos, endppqpos = reaper.MIDI_GetNote(take, i)
            if selected then
                min_start = min_start and math.min(min_start, startppqpos) or startppqpos
                max_end = max_end and math.max(max_end, endppqpos) or endppqpos
            end
        end
        if min_start and max_end then
            time_start = reaper.MIDI_GetProjTimeFromPPQPos(take, min_start)
            time_end = reaper.MIDI_GetProjTimeFromPPQPos(take, max_end)
            reaper.GetSet_LoopTimeRange2(0, true, false, time_start, time_end, false)
        else
            return
        end
    end

    loop_start = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_start))
    loop_end = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_end))
    loop_len = loop_end - loop_start
    local times = math.floor(loop_len / grid)
    local new_loop_start = loop_start - loop_start % grid

    reaper.MIDI_DisableSort(take)
    local flag
    if reaper.GetToggleCommandStateEx(32060, 40681) == 1 then
        reaper.MIDIEditor_LastFocused_OnCommand(40681, 0)
        flag = true
    end

    for i = 0, notecnt - 1 do
        local _, selected, _, startppqpos, endppqpos, _, pitch, _ = reaper.MIDI_GetNote(take, i)
        local notelen = endppqpos - startppqpos
        if selected then
            local retry_count = 0
            local max_retries = 50
            local rand_pos

            repeat
                local rand_grid = math.random(0, times) * grid
                rand_pos = new_loop_start + rand_grid
                if rand_pos + notelen > loop_end then
                    rand_pos = loop_end - notelen
                end

                retry_count = retry_count + 1
                if retry_count > max_retries then
                    break
                end
            until not isOverlap(take, rand_pos, notelen, pitch, notecnt, i, true)

            if retry_count <= max_retries then
                reaper.MIDI_SetNote(take, i, nil, nil, rand_pos, rand_pos + notelen, nil, nil, nil, false)
            end
        end
    end

    for i = 0, notecnt - 1 do
        local _, selected, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, i)
        local notelen = endppqpos - startppqpos
        if selected then
            local retry_count = 0
            local max_retries = 50
            local rand_pos

            repeat
                local rand_grid = math.random(times) * grid
                rand_pos = new_loop_start + rand_grid - grid
                if rand_pos + notelen > loop_end then
                    rand_pos = loop_end - notelen
                end

                retry_count = retry_count + 1
                if retry_count > max_retries then
                    break
                end
            until not isOverlap(take, rand_pos, notelen, _, notecnt, i, false)

            if retry_count <= max_retries then
                reaper.MIDI_SetNote(take, i, nil, nil, rand_pos, rand_pos + notelen, nil, nil, nil, false)
            end
        end
    end

    -- restore the existing time selection
    reaper.GetSet_LoopTimeRange2(0, true, false, time_start_original, time_end_original, false)

    reaper.MIDI_Sort(take)

    if flag then
        reaper.MIDIEditor_LastFocused_OnCommand(40681, 0) -- Options: Correct overlapping notes while editing
    end
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()