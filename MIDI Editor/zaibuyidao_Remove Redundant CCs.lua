--[[
 * ReaScript Name: Remove Redundant CCs
 * Version: 1.1
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
local editor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(editor)
local cnt, index = 0, {}
local val = reaper.MIDI_EnumSelCC(take, -1)
while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelCC(take, val)
end
local idx, tc, tp = -1, "", ""
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
reaper.MIDI_DisableSort(take)
for i = 1, #index do
    index[i] = reaper.MIDI_EnumSelCC(take, idx)
    retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, index[i])
    pitchbend = 128 * msg3 + msg2
    if chanmsg == 176 and tc == msg3 then
        reaper.MIDI_DeleteCC(take, index[i])
    elseif chanmsg == 224 and tp == pitchbend then
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