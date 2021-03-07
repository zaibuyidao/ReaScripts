--[[
 * ReaScript Name: Remove Redundant CCs
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2021-3-7)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local cnt, index = 0, {}
local val = reaper.MIDI_EnumSelCC(take, -1)
while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelCC(take, val)
end
local threshold, idx, tc, tp = 0, -1, 0, 0
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
reaper.MIDI_DisableSort(take)
for i = 1, #index do
    index[i] = reaper.MIDI_EnumSelCC(take, idx)
    retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, index[i])
    pitchbend = 128*msg3+msg2
    diffc = msg3-tc
    diffp = pitchbend-tp
    if diffc < 0 then diffc = math.abs(diffc) end
    if diffp < 0 then diffp = math.abs(diffp) end
    --Msg(index[i] ..' A: '.. diffc ..' B: '..msg3.." C: "..tc)
    --Msg(index[i] ..' A: '.. diffp ..' B: '..pitchbend.." C: "..tp)
    if chanmsg == 176 and diffc <= threshold then
        --Msg(index[i].." ----------------")
        reaper.MIDI_DeleteCC(take, index[i])
    elseif chanmsg == 224 and diffp <= threshold then
        reaper.MIDI_DeleteCC(take, index[i])
    else
        tc = msg3
        tp = pitchbend
        idx = index[i]
    end
end
reaper.MIDI_Sort(take)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Remove Redundant CCs", 0)