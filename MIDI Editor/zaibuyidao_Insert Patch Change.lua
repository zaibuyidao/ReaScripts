--[[
 * ReaScript Name: Insert Patch Change
 * Version: 1.1.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-8-10)
  + Initial release
--]]

-- Use the formula bank = MSB × 128 + LSB to find the bank number to use in script.

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function main()
  reaper.Undo_BeginBlock()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  local item = reaper.GetMediaItemTake_Item(take)
  local curpos = reaper.GetCursorPositionEx()
  local ppqpos = reaper.MIDI_GetPPQPosFromProjTime(take, curpos)
  local count, index = 0, {}
  local value = reaper.MIDI_EnumSelNotes(take, -1)
  while value ~= -1 do
    count = count + 1
    index[count] = value
    value = reaper.MIDI_EnumSelNotes(take, value)
  end

  local BANK = reaper.GetExtState("InsertPatchChange", "BANK")
  if (BANK == "") then BANK = "259" end
  local PC = reaper.GetExtState("InsertPatchChange", "PC")
  if (PC == "") then PC = "27" end
  local Tick = reaper.GetExtState("PatchChange", "Tick")
  if (Tick == "") then Tick = "-10" end

  local user_ok, user_input_csv = reaper.GetUserInputs("Insert Patch Change", 3, "Bank,Program number,Offset", BANK ..','.. PC ..','.. Tick)
  if not user_ok then return reaper.SN_FocusMIDIEditor() end
  local BANK, PC, Tick = user_input_csv:match("(.*),(.*),(.*)")
  if not tonumber(BANK) or not (tonumber(PC) or tostring(PC)) or not tonumber(Tick) then return reaper.SN_FocusMIDIEditor() end

  reaper.SetExtState("PatchChange", "BANK", BANK, false)
  reaper.SetExtState("PatchChange", "PC", PC, false)
  reaper.SetExtState("PatchChange", "Tick", Tick, false)

  if (PC == "C-2") then PC = "0"
  elseif (PC == "C#-2") then PC = "1"
  elseif (PC == "D-2") then PC = "2"
  elseif (PC == "D#-2") then PC = "3"
  elseif (PC == "E-2") then PC = "4"
  elseif (PC == "F-2") then PC = "5"
  elseif (PC == "F#-2") then PC = "6"
  elseif (PC == "G-2") then PC = "7"
  elseif (PC == "G#-2") then PC = "8"
  elseif (PC == "A-2") then PC = "9"
  elseif (PC == "A#-2") then PC = "10"
  elseif (PC == "B-2") then PC = "11"
  elseif (PC == "C-1") then PC = "12"
  elseif (PC == "C#-1") then PC = "13"
  elseif (PC == "D-1") then PC = "14"
  elseif (PC == "D#-1") then PC = "15"
  elseif (PC == "E-1") then PC = "16"
  elseif (PC == "F-1") then PC = "17"
  elseif (PC == "F#-1") then PC = "18"
  elseif (PC == "G-1") then PC = "19"
  elseif (PC == "G#-1") then PC = "20"
  elseif (PC == "A-1") then PC = "21"
  elseif (PC == "A#-1") then PC = "22"
  elseif (PC == "B-1") then PC = "23"
  elseif (PC == "C0") then PC = "24"
  elseif (PC == "C#0") then PC = "25"
  elseif (PC == "D0") then PC = "26"
  elseif (PC == "D#0") then PC = "27"
  elseif (PC == "E0") then PC = "28"
  elseif (PC == "F0") then PC = "29"
  elseif (PC == "F#0") then PC = "30"
  elseif (PC == "G0") then PC = "31"
  elseif (PC == "G#0") then PC = "32"
  elseif (PC == "A0") then PC = "33"
  elseif (PC == "A#0") then PC = "34"
  elseif (PC == "B0") then PC = "35"
  elseif (PC == "C1") then PC = "36"
  elseif (PC == "C#1") then PC = "37"
  elseif (PC == "D1") then PC = "38"
  elseif (PC == "D#1") then PC = "39"
  elseif (PC == "E1") then PC = "40"
  elseif (PC == "F1") then PC = "41"
  elseif (PC == "F#1") then PC = "42"
  elseif (PC == "G1") then PC = "43"
  elseif (PC == "G#1") then PC = "44"
  elseif (PC == "A1") then PC = "45"
  elseif (PC == "A#1") then PC = "46"
  elseif (PC == "B1") then PC = "47"
  elseif (PC == "C2") then PC = "48"
  elseif (PC == "C#2") then PC = "49"
  elseif (PC == "D2") then PC = "50"
  elseif (PC == "D#2") then PC = "51"
  elseif (PC == "E2") then PC = "52"
  elseif (PC == "F2") then PC = "53"
  elseif (PC == "F#2") then PC = "54"
  elseif (PC == "G2") then PC = "55"
  elseif (PC == "G#2") then PC = "56"
  elseif (PC == "A2") then PC = "57"
  elseif (PC == "A#2") then PC = "58"
  elseif (PC == "B2") then PC = "59"
  elseif (PC == "C3") then PC = "60"
  elseif (PC == "C#3") then PC = "61"
  elseif (PC == "D3") then PC = "62"
  elseif (PC == "D#3") then PC = "63"
  elseif (PC == "E3") then PC = "64"
  elseif (PC == "F3") then PC = "65"
  elseif (PC == "F#3") then PC = "66"
  elseif (PC == "G3") then PC = "67"
  elseif (PC == "G#3") then PC = "68"
  elseif (PC == "A3") then PC = "69"
  elseif (PC == "A#3") then PC = "70"
  elseif (PC == "B3") then PC = "71"
  elseif (PC == "C4") then PC = "72"
  elseif (PC == "C#4") then PC = "73"
  elseif (PC == "D4") then PC = "74"
  elseif (PC == "D#4") then PC = "75"
  elseif (PC == "E4") then PC = "76"
  elseif (PC == "F4") then PC = "77"
  elseif (PC == "F#4") then PC = "78"
  elseif (PC == "G4") then PC = "79"
  elseif (PC == "G#4") then PC = "80"
  elseif (PC == "A4") then PC = "81"
  elseif (PC == "A#4") then PC = "82"
  elseif (PC == "B4") then PC = "83"
  elseif (PC == "C5") then PC = "84"
  elseif (PC == "C#5") then PC = "85"
  elseif (PC == "D5") then PC = "86"
  elseif (PC == "D#5") then PC = "87"
  elseif (PC == "E5") then PC = "88"
  elseif (PC == "F5") then PC = "89"
  elseif (PC == "F#5") then PC = "90"
  elseif (PC == "G5") then PC = "91"
  elseif (PC == "G#5") then PC = "92"
  elseif (PC == "A5") then PC = "93"
  elseif (PC == "A#5") then PC = "94"
  elseif (PC == "B5") then PC = "95"
  elseif (PC == "C6") then PC = "96"
  elseif (PC == "C#6") then PC = "97"
  elseif (PC == "D6") then PC = "98"
  elseif (PC == "D#6") then PC = "99"
  elseif (PC == "E6") then PC = "100"
  elseif (PC == "F6") then PC = "101"
  elseif (PC == "F#6") then PC = "102"
  elseif (PC == "G6") then PC = "103"
  elseif (PC == "G#6") then PC = "104"
  elseif (PC == "A6") then PC = "105"
  elseif (PC == "A#6") then PC = "106"
  elseif (PC == "B6") then PC = "107"
  elseif (PC == "C7") then PC = "108"
  elseif (PC == "C#7") then PC = "109"
  elseif (PC == "D7") then PC = "110"
  elseif (PC == "D#7") then PC = "111"
  elseif (PC == "E7") then PC = "112"
  elseif (PC == "F7") then PC = "113"
  elseif (PC == "F#7") then PC = "114"
  elseif (PC == "G7") then PC = "115"
  elseif (PC == "G#7") then PC = "116"
  elseif (PC == "A7") then PC = "117"
  elseif (PC == "A#7") then PC = "118"
  elseif (PC == "B7") then PC = "119"
  elseif (PC == "C8") then PC = "120"
  elseif (PC == "C#8") then PC = "121"
  elseif (PC == "D8") then PC = "122"
  elseif (PC == "D#8") then PC = "123"
  elseif (PC == "E8") then PC = "124"
  elseif (PC == "F8") then PC = "125"
  elseif (PC == "F#8") then PC = "126"
  elseif (PC == "G8") then PC = "127"
  end

  local MSB = math.modf(BANK / 128)
  local LSB = math.fmod(BANK, 128)
  reaper.MIDI_DisableSort(take)
  if #index > 0 then
    for i = 1, #index do
      retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, index[i])
      if selected == true then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos+Tick, 0xB0, chan, 0, MSB) -- CC#00
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos+Tick, 0xB0, chan, 32, LSB) -- CC#32
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos+Tick, 0xC0, chan, PC, 0) -- Program Change
      end
    end
  else
    local selected = true
    local muted = false
    local chan = 0
    reaper.MIDI_InsertCC(take, selected, muted, ppqpos+Tick, 0xB0, chan, 0, MSB) -- CC#00
    reaper.MIDI_InsertCC(take, selected, muted, ppqpos+Tick, 0xB0, chan, 32, LSB) -- CC#32
    reaper.MIDI_InsertCC(take, selected, muted, ppqpos+Tick, 0xC0, chan, PC, 0) -- Program Change
  end
  reaper.MIDI_Sort(take)
  reaper.UpdateItemInProject(item)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Insert Patch Change", 0)
end

main()
reaper.SN_FocusMIDIEditor()