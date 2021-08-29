--[[
 * ReaScript Name: Set CC Lane
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

local editor=reaper.MIDIEditor_GetActive()

retval,CC= reaper.GetUserInputs('Set CC lane',1,'设置CC车道为 CC num (0-119)','-1') 

CCnum=tonumber (CC)

if CCnum >= 0 and CCnum <= 119 then

ID = CCnum + 40238

reaper.MIDIEditor_OnCommand(editor, ID)

end

reaper.SN_FocusMIDIEditor()
