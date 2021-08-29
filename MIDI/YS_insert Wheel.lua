--[[
 * ReaScript Name: insert Wheel
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

local num=reaper.GetCursorPositionEx(0)

local editor=reaper.MIDIEditor_GetActive()

local take=reaper.MIDIEditor_GetTake(editor)

local startpos=reaper.MIDI_GetPPQPosFromProjTime(take, num)

retval,banyin= reaper.GetUserInputs('Insert Wheel',1,'输入-12到12 Wheel Val=','0') 

banyinsub=tonumber (banyin)

pitch = 683*banyinsub 

if (pitch > 8191) then pitch = 8191 end
if (pitch < -8192) then pitch = -8191 end

local beishu = math.modf( pitch / 128 )
local yushu = math.fmod( pitch, 128 ) 
if (beishu < 0)
then beishu=beishu-1
end

reaper.MIDI_InsertCC(take, false, false, startpos , 224, 0,yushu,64+beishu)

reaper.SN_FocusMIDIEditor()

