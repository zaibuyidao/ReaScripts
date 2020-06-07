--[[
 * ReaScript Name: Select Note With The Same Channel (Under Mouse)
 * Version: 1.0
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
_, _, _ = reaper.BR_GetMouseCursorContext()
_, _, note_row, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI() -- 获得鼠标下的音高
mouse_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.BR_GetMouseCursorContext_Position()) -- 获得鼠标的位置并将工程时间转换为PPQ
_, notecnt, _, _ = reaper.MIDI_CountEvts(take)
reaper.MIDI_DisableSort(take)
reaper.Undo_BeginBlock()
idx = {} -- 将鼠标悬停的音符的chan存入表中
for i = 1, notecnt do
    _, sel, _, startppqpos, endppqpos, chan, pitch, _ = reaper.MIDI_GetNote(take, i - 1)
    if startppqpos < mouse_ppq_pos and endppqpos > mouse_ppq_pos and note_row == pitch then -- 如果音符在鼠标下
      table.insert(idx, chan) -- --idx[#idx+1] = notelen
    end
end
for k, v in ipairs(idx) do -- 删除表格中的nil值，只保留鼠标悬停的音符的chan值
	if v == nil then
		table.remove(idx, k)
	end
end
for i = 1, notecnt do
  retval, sel, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
  if chan == idx[1] then
    reaper.MIDI_SetNote(take, i - 1, true, nil, nil, nil, nil, nil, nil, false)
  end
end
reaper.Undo_EndBlock("Select Note With The Same Channel (Under Mouse)", 0)
reaper.MIDI_Sort(take)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
