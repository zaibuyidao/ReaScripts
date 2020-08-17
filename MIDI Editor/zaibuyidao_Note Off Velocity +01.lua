--[[
 * ReaScript Name: Note Off Velocity +01
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-8-17)
  + Initial release
--]]

function Msg(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local vel = 1
take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local midi_ok, midi_string = reaper.MIDI_GetAllEvts(take, "")
if not midi_ok then return end
local string_pos, ticks, table_events, offset, flags, msg = 1, 0, {}
local pack, unpack = string.pack, string.unpack
while string_pos < #midi_string do
    offset, flags, msg, string_pos = unpack("i4Bs4", midi_string, string_pos)
    if flags&1 ==1 and #msg >= 3 and msg:byte(1)>>4 == 8 and msg:byte(3) ~= -1 then
        msg = msg:sub(1,2) .. string.char(math.max(0, math.min(127, (msg:byte(3) + vel)//1)))
    end
    table_events[#table_events+1] = pack("i4Bs4", offset, flags, msg)
end
reaper.MIDI_SetAllEvts(take, table.concat(table_events))
reaper.Undo_OnStateChange_Item(0, "Note Off Velocity +01", reaper.GetMediaItemTake_Item(take))