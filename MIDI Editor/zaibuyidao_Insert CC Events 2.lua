--[[
 * ReaScript Name: Insert CC Events 2
 * Instructions: Open a MIDI take in MIDI Editor. Position Edit Cursor, Run.
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
 * v1.0 (2019-12-19)
  + Initial release
--]]

local retval, userInputsCSV = reaper.GetUserInputs("Insert CC Events 2", 5, "CC Number,First,Second,Repetition,Interval", "11,100,70,1,120")
if not retval then return reaper.SN_FocusMIDIEditor() end
local cc_num, cc_begin, cc_end, cishu, tick = userInputsCSV:match("(.*),(.*),(.*),(.*),(.*)")
cc_num, cc_begin, cc_end, cishu, tick = tonumber(cc_num), tonumber(cc_begin), tonumber(cc_end), tonumber(cishu)*8, tonumber(tick)

function Main()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    local pos = reaper.GetCursorPositionEx(0)
    local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
    local bolang = {cc_begin,cc_end}
    ppq = ppq - tick
    for i = 1, cishu do
        for i = 1, #bolang do
            ppq = ppq + tick
            reaper.MIDI_InsertCC(take, selected, false, ppq, 0xB0, 0, cc_num, bolang[i])
            i=i+1
        end
    end
end

reaper.Undo_BeginBlock()
selected = true
Main()
reaper.UpdateArrange()
reaper.Undo_EndBlock("Insert CC Events 2", -1)
reaper.SN_FocusMIDIEditor()
