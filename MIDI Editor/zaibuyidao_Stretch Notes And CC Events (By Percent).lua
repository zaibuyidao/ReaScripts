--[[
 * ReaScript Name: Stretch Notes And CC Events (By Percent)
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
     + Initial Release
--]]

local title = "Stretch Notes And CC Events"
local HWND =  reaper.MIDIEditor_GetActive()
if not HWND then return end
local take =  reaper.MIDIEditor_GetTake(HWND)
if not take or not reaper.TakeIsMIDI(take) then return end

function StretchSelectedNotes(f)
  local id = 0
  for i = 1, ({reaper.MIDI_CountEvts( take )})[2] do
    local note_t = ({reaper.MIDI_GetNote( take, i-1 )})
    if note_t[2] then
    id = id + 1
    if id == 1 then strtppq = note_t[4] end
    reaper.MIDI_SetNote(
      take,
      i-1,
      note_t[2],
      note_t[3],
      math.floor(f(note_t[4]-strtppq,id)+strtppq),
      math.floor(f(note_t[4]-strtppq,id)+strtppq+f(note_t[5]-note_t[4]),id),
      note_t[6],
      note_t[7],
      note_t[8],
      true
    )
    end
  end
  reaper.MIDI_Sort(take)
end

function StretchSelectedCCs(f)
  local id = 0
  for i = 1, ({reaper.MIDI_CountEvts( take )})[3] do
    local cc_t = ({reaper.MIDI_GetCC( take, i-1 )})
    if cc_t[2] then
    id = id + 1
    if id == 1 then ppqpos = cc_t[4] end
    reaper.MIDI_SetCC(
      take,
      i-1,
      cc_t[2],
      cc_t[3],
      math.floor(f(cc_t[4]-ppqpos,id)+ppqpos),
      cc_t[5],
      cc_t[6],
      cc_t[7],
      cc_t[8],
      true
    )
    end
  end
  reaper.MIDI_Sort(take)
end

function Main()
  local retval, str_user_input = reaper.GetUserInputs('Stretch Notes And CC Events', 1, 'By Percent', '200')
  if retval then
    local func
    if not str_user_input:match('[%d%.]+') or not tonumber(str_user_input:match('[%d%.]+')) then return end
    func = load("local x = ... return x*"..tonumber(str_user_input:match('[%d%.]+')) / 100)
    if not func then return end
    reaper.Undo_BeginBlock()
    StretchSelectedNotes(func)
    StretchSelectedCCs(func)
    reaper.Undo_EndBlock(title, -1)
  end
end

Main()
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
