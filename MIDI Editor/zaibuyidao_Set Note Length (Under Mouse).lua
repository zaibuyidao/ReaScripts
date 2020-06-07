--[[
 * ReaScript Name: Set Note Length (Under Mouse)
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-6-7)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local cnt, index = 0, {}
local val = reaper.MIDI_EnumSelNotes(take, -1)
if val ~= -1 then sel_note = true end
while val ~= -1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
end
_, _, _ = reaper.BR_GetMouseCursorContext()
_, _, note_row, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI() -- 获得鼠标下的音高
mouse_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.BR_GetMouseCursorContext_Position()) -- 获得鼠标的位置并将ProjTime转换为PPQ
_, notecnt, _, _ = reaper.MIDI_CountEvts(take)
if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then enum_sel_note = true end
reaper.Undo_BeginBlock()
idx = {} -- 将鼠标悬停的音符的长度存入表中
for i = 1, notecnt do
    _, selected, _, startppqpos, endppqpos, chan, pitch, _ = reaper.MIDI_GetNote(take, i - 1)
    if startppqpos < mouse_ppq_pos and endppqpos > mouse_ppq_pos and note_row == pitch then -- 如果音符在鼠标下
        notelen = endppqpos - startppqpos
        table.insert(idx, notelen) -- --idx[#idx+1] = notelen
    end
end
for k, v in ipairs(idx) do -- 删除表格中的nil值，只保留鼠标悬停的音符的长度值
	if v == nil then
		table.remove(idx, k)
	end
end
reaper.MIDI_DisableSort(take)
if #index > 0 then
    for i = 1, #index do
        _, selected, _, startppqpos, endppqpos, chan, pitch, _ = reaper.MIDI_GetNote(take, index[i])
        reaper.MIDI_SetNote(take, index[i], nil, nil, startppqpos, startppqpos + idx[1], nil, nil, nil, false)
    end
else
    for i = 1, notecnt do
        _, selected, _, startppqpos, endppqpos, chan, pitch, _ = reaper.MIDI_GetNote(take, i - 1)
        reaper.MIDI_SetNote(take, i - 1, true, nil, startppqpos, startppqpos + idx[1], nil, nil, nil, false)
    end
end
reaper.UpdateArrange()
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("Set Note Length (Under Mouse)", 0)
reaper.SN_FocusMIDIEditor()
