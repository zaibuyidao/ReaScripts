--[[
 * ReaScript Name: Insert Vibrato
 * Instructions: Open a MIDI take in MIDI Editor. Position Edit Cursor, Run.
 * Version: 1.3
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
  + Initial release
--]]

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local retval, userInputsCSV = reaper.GetUserInputs("Insert Vibrato", 3, "Amplitude:1-10,Repetition:1-10,Interval:1-99", "3,7,7") 
  if not retval then return reaper.SN_FocusMIDIEditor() end
  local fudu, cishu, jiange = userInputsCSV:match("(.*),(.*),(.*)")
  fudu, cishu, jiange = tonumber(fudu), tonumber(cishu), tonumber(jiange)
  
  local t1 = {0, 48, 96, 144, 192, 240, 192, 144, 96, 48, 0}
  local t2 = {0, 96, 192, 288, 384, 480, 384, 288, 192, 96, 0}
  local t3 = {0, 144, 288, 432, 576, 720, 576, 432, 288, 144, 0}
  local t4 = {0, 192, 384, 576, 768, 960, 768, 576, 384, 192, 0}
  local t5 = {0, 240, 480, 720, 960, 1200, 960, 720, 480, 240, 0}
  local t6 = {0, 288, 576, 864, 1152, 1440, 1152, 864, 576, 288, 0}
  local t7 = {0, 336, 672, 1008, 1344, 1680, 1344, 1008, 672, 336, 0}
  local t8 = {0, 384, 768, 1152, 1536, 1920, 1536, 1152, 768, 384, 0}
  local t9 = {0, 432, 864, 1296, 1728, 2160, 1728, 1296, 864, 432, 0}
  local t10 = {0, 480, 960, 1440, 1920, 2400, 1920, 1440, 960, 480, 0}
  local tb = {t1, t2, t3, t4, t5, t6, t7, t8, t9, t10}
  
  local cur_pos = reaper.GetCursorPositionEx()
  local startpos = reaper.MIDI_GetPPQPosFromProjTime(take, cur_pos)
  startpos = startpos - jiange
  
  if fudu < 1  or fudu > 10 then return reaper.SN_FocusMIDIEditor() end
  if cishu < 1 or cishu > 10 then return reaper.SN_FocusMIDIEditor() end
  if jiange < 1 or jiange > 99 then return reaper.SN_FocusMIDIEditor() end
  
  for i = 1, cishu do
    for i = 1, 11 do
      startpos = startpos + jiange
      local value = tb[fudu][i]
      value = value + 8192
      local LSB = value & 0x7f
      local MSB = value >> 7 & 0x7f
      reaper.MIDI_InsertCC(take, false, false, startpos, 224, 0, LSB, MSB)
      i=i+1
    end
    reaper.UpdateArrange()
  end
end

script_title = "Insert Vibrato"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()
