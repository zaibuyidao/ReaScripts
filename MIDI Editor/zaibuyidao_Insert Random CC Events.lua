--[[
 * ReaScript Name: Insert Random CC Events
 * Instructions: Open a MIDI take in MIDI Editor. Position Edit Cursor, Run.
 * Version: 2.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v2.0 (2020-1-5)
  + Version update
 * v1.0 (2019-12-12)
  + Initial release
--]]

selected = false

local retval, userInputsCSV = reaper.GetUserInputs("Insert Random CC Events", 4, "CC Number,CC Events,Repetition,Interval", "11,8,4,240")
if not retval then return reaper.SN_FocusMIDIEditor() end
local cc_num, cc_event, cishu, jiange = userInputsCSV:match("(.*),(.*),(.*),(.*)")
cc_num, cc_event, cishu, jiange = tonumber(cc_num), tonumber(cc_event), tonumber(cishu), tonumber(jiange)

function Main()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    local pos = reaper.GetCursorPositionEx(0)
    local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
    local x = 127
    ppq = ppq - jiange
    for i = 1, cishu do
        for i = 1, cc_event do
            ppq = ppq + jiange
            reaper.MIDI_InsertCC(take, selected, false, ppq, 0xB0, 0, cc_num, math.random(x))
            i=i+1
        end
    end
    reaper.UpdateArrange()
    reaper.MIDI_Sort(take)
end

reaper.Undo_BeginBlock()
Main()
reaper.UpdateArrange()
reaper.Undo_EndBlock("Insert Random CC Events", 0)
reaper.SN_FocusMIDIEditor()
