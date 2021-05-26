--[[
 * ReaScript Name: Notes Become Pitch Bend
 * Version: 1.6
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.5 (2021-5-26)
  + 刪除冗餘Pitch
 * v1.0 (2019-12-12)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end
local editor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(editor)
if take == nil then return end

local cnt, index = 0, {}
local val = reaper.MIDI_EnumSelNotes(take, -1)
while val ~= - 1 do
  cnt = cnt + 1
  index[cnt] = val
  val = reaper.MIDI_EnumSelNotes(take, val)
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local pitch = {}
local startppqpos = {}
local endppqpos = {}
local vel = {}
local tbl={}
tbl["12"]="8191"
tbl["11"]="7513"
tbl["10"]="6830"
tbl["9"]="6147"
tbl["8"]="5464"
tbl["7"]="4781"
tbl["6"]="4098"
tbl["5"]="3415"
tbl["4"]="2732"
tbl["3"]="2049"
tbl["2"]="1366"
tbl["1"]="683"
tbl["0"]="0"
tbl["-1"]="-683"
tbl["-2"]="-1366"
tbl["-3"]="-2049"
tbl["-4"]="-2732"
tbl["-5"]="-3415"
tbl["-6"]="-4098"
tbl["-7"]="-4781"
tbl["-8"]="-5464"
tbl["-9"]="-6147"
tbl["-10"]="-6830"
tbl["-11"]="-7513"
tbl["-12"]="-8192"

if #index > 1 then
  for i = 1, #index do
    retval, sel, muted, startppqpos[i], endppqpos[i], chan, pitch[i], vel[i] = reaper.MIDI_GetNote(take, index[i])
    if sel == true then
      if pitch[i-1] then
        local offset = tostring(pitch[i]-pitch[1])
          local value = tonumber(tbl[offset])
          if value == nil then return reaper.MB("Please adjust the note interval. The limit is only one octaves.","Error",0) end
          value = value + 8192
          local lsb = value & 0x7f
          local msb = value >> 7 & 0x7f
          reaper.MIDI_InsertCC(take, false, false, startppqpos[i], 224, 0, lsb, msb)
      end
      if i == #index then
        ii = reaper.MIDI_EnumSelNotes(take, -1)
        while ii > -1 do
          reaper.MIDI_DeleteNote(take, ii)
          ii = reaper.MIDI_EnumSelNotes(take, -1)
        end
        if (pitch[1] ~= pitch[i]) then
          reaper.MIDI_InsertCC(take, false, false, endppqpos[i], 224, 0, 0, 64)
        end
        reaper.MIDI_InsertNote(take, sel, muted, startppqpos[1], endppqpos[i], chan, pitch[1], vel[1], true)
      end
    end
    reaper.UpdateArrange()
  end
else
  reaper.MB("Please select two or more notes","Error",0)
end
reaper.Undo_EndBlock("Notes Become Pitch Bend", 0)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.MIDIEditor_OnCommand(editor , 40366) -- CC: Set CC lane to Pitch