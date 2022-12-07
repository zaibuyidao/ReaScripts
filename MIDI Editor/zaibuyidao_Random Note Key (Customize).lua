-- @description Random Note Key (Customize)
-- @version 1.0
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires SWS Extensions

-- USER AREA
-- Settings that the user can customize.

key_signature = "C" -- Use # : C C# D D#...
key_min = "C5"
key_max = "C6"

-- End of USER AREA

if not reaper.SN_FocusMIDIEditor then
    local retval = reaper.ShowMessageBox("This script requires the SWS extension, would you like to download it now?\n\n這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
    if retval == 1 then
        open_url("http://www.sws-extension.org/download/pre-release/")
    end
end

function main()
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    _, notecnt, _, _ = reaper.MIDI_CountEvts(take)

    key_map = {} --音名和键位表
    local octave, key --音名和键位，用于插入键值对
    for i = 0 , 11 do
        octave = "C" .. i
        key = i * 12
        key_map[octave] = key
        octave = "C#" .. i
        key = i * 12 + 1
        key_map[octave] = key
        octave = "D" .. i
        key = i * 12 + 2
        key_map[octave] = key
        octave = "D#" .. i
        key = i * 12 + 3
        key_map[octave] = key
        octave = "E" .. i
        key = i * 12 + 4
        key_map[octave] = key
        octave = "F" .. i
        key = i * 12 + 5
        key_map[octave] = key
        octave = "F#" .. i
        key = i * 12 + 6
        key_map[octave] = key
        octave = "G" .. i
        key = i * 12 + 7
        key_map[octave] = key
        octave = "G#" .. i
        key = i * 12 + 8
        key_map[octave] = key
        octave = "A" .. i
        key = i * 12 + 9
        key_map[octave] = key
        octave = "A#" .. i
        key = i * 12 + 10
        key_map[octave] = key
        octave = "B" .. i
        key = i * 12 + 11
        key_map[octave] = key
    end
    if key_map[key_min] > 127 then
        key_map[key_min] = 127
    elseif key_map[key_min] < 0 then
        key_map[key_min] = 0
    elseif key_map[key_max] > 127 then
        key_map[key_max] = 127
    elseif key_map[key_max] < 0 then
        key_map[key_max] = 0
    elseif key_map[key_min] > key_map[key_max] then
        local t = key_map[key_max]
        key_map[key_max] = key_map[key_min]
        key_map[key_min] = t
    end
    if key_map[key_min] == key_map[key_max] then
        return
            reaper.MB("Random interval is empty, please re-enter", "Error", 0),
            reaper.SN_FocusMIDIEditor()
    end
    local diff = (key_map[key_max]+1) - key_map[key_min]

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
        local scales = {0,2,4,5,7,9,11} --大调音阶表
        local scales_map = {[0]=1,[2]=2,[4]=3,[5]=4,[7]=5,[9]=6,[11]=7} --大调音阶表的查询表，可以得到音高在音阶表中的位置
        local scales_pos = {[0]=0,[1]=0,[2]=2,[3]=2,[4]=4,[5]=5,[6]=5,[7]=7,[8]=7,[9]=9,[10]=9,[11]=11} --12半音的音阶表，可以通过0-11的数字得到一个在音阶中的数字
        local tones_map = {["C"]=0, ["C#"]=1, ["D"]=2, ["D#"]=3, ["E"]=4, ["F"]=5, ["F#"]=6, ["G"]=7, ["G#"]=8, ["A"]=9, ["A#"]=10, ["B"]=11} --音名所对应的数字
        if selected or not sel_note then
            pitch = tonumber(key_map[key_min]+math.random(diff))-1
            local tempPitch=pitch-tones_map[key_signature]
            local p = tempPitch%12
            local b = tempPitch-p
            local tp = scales_map[scales_pos[p]]
            local rp = ((tp-1)%7)+1
            local result = b+scales[rp]+tones_map[key_signature]
            reaper.MIDI_SetNote(take, i - 1, nil, nil, nil, nil, nil, result, nil, false)
        end
    end
    reaper.MIDI_Sort(take)

    if flag then
        reaper.MIDIEditor_LastFocused_OnCommand(40681, 0)
    end
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Random Note Key", -1)
reaper.UpdateArrange()