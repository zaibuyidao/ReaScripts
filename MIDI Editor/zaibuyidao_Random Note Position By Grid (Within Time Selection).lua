-- @description Random Note Position By Grid (Within Time Selection)
-- @version 2.0
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

-- USER AREA
-- Settings that the user can customize.

midi_grid = 1 -- 1 is the default MIDI grid. Random intervals are based on the MIDI grid, where you can set multiples of the grid.

-- End of USER AREA

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
  
if language == "简体中文" then
    title = "按网格随机音符位置"
elseif language == "繁体中文" then
    title = "按網格隨機音符位置"
else
    title = "Random Note Position By Grid"
end

function isOverlap(take, rand_pos, notelen, notecnt, currentIndex)
    for j = 0, notecnt - 1 do
        if j ~= currentIndex then
            _, _, _, startppqpos, endppqpos = reaper.MIDI_GetNote(take, j)
            -- 检查随机位置是否与任何现有音符重叠
            if (rand_pos < endppqpos and rand_pos + notelen > startppqpos) then
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
    local grid = math.floor(midi_tick*grid_qn)*midi_grid

    _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
    if notecnt == 0 then return end

    local time_start, time_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, 0)
    local loop_start, loop_end, loop_len

    if time_start == time_end then
        -- 没有时间选区，寻找选中音符的范围
        local min_start, max_end
        for i = 0, notecnt - 1 do
            local _, selected, _, startppqpos, endppqpos = reaper.MIDI_GetNote(take, i)
            if selected then
                if not min_start or startppqpos < min_start then
                    min_start = startppqpos
                end
                if not max_end or endppqpos > max_end then
                    max_end = endppqpos
                end
            end
        end
        if min_start and max_end then
            time_start = reaper.MIDI_GetProjTimeFromPPQPos(take, min_start)
            time_end = reaper.MIDI_GetProjTimeFromPPQPos(take, max_end)
            reaper.GetSet_LoopTimeRange2(0, true, false, time_start, time_end, false)
        else
            return -- 没有选中的音符
        end
    end

    loop_start = math.floor(0.5+reaper.MIDI_GetPPQPosFromProjTime(take, time_start))
    loop_end = math.floor(0.5+reaper.MIDI_GetPPQPosFromProjTime(take, time_end))
    loop_len = math.floor(loop_end - loop_start)
    local times = math.floor(loop_len/grid)
    local new_loop_start = loop_start - loop_start % grid

    reaper.MIDI_DisableSort(take)
    sel = reaper.MIDI_EnumSelNotes(take, -1)
    if sel ~= -1 then sel_note = true end
    local flag
    if reaper.GetToggleCommandStateEx(32060, 40681) == 1 then
        reaper.MIDIEditor_LastFocused_OnCommand(40681,0) -- Options: Correct overlapping notes while editing
        flag = true
    end

    for i = 1, notecnt do
        _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
        notelen = endppqpos - startppqpos
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
                    -- reaper.ShowConsoleMsg("Max retries reached for note " .. i .. "\n")
                    break
                end
            until not isOverlap(take, rand_pos, notelen, notecnt, i - 1)

            if retry_count <= max_retries then
                -- reaper.ShowConsoleMsg("Moving note " .. i .. " to position " .. rand_pos .. "\n")
                reaper.MIDI_SetNote(take, i - 1, nil, nil, rand_pos, rand_pos + notelen, nil, nil, nil, false)
            end
        end
    end
    reaper.MIDI_Sort(take)

    if flag then
        reaper.MIDIEditor_LastFocused_OnCommand(40681,0) -- Options: Correct overlapping notes while editing
    end
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()