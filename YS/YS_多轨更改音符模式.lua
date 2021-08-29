--[[
 * ReaScript Name: 多轨更改音符模式
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

reaper.PreventUIRefresh(1)
editor=reaper.MIDIEditor_GetActive()
take1=reaper.MIDIEditor_GetTake(editor)
retval, csv=reaper.GetUserInputs('多轨更改音符模式',1,'矩形：1 ，三角形：2','2')
if  retval then 
if csv=='2' then reaper.MIDIEditor_OnCommand(editor , 40448) else reaper.MIDIEditor_OnCommand(editor , 40449) end
reaper.MIDIEditor_OnCommand(editor , 40500) --next
take=reaper.MIDIEditor_GetTake(editor)
while take~=take1 do 
if csv=='2' then reaper.MIDIEditor_OnCommand(editor , 40448) else reaper.MIDIEditor_OnCommand(editor , 40449) end
reaper.MIDIEditor_OnCommand(editor , 40500) --next
take=reaper.MIDIEditor_GetTake(editor)
end
end
reaper.PreventUIRefresh(-1)
reaper.SN_FocusMIDIEditor()
