--[[
 * ReaScript Name: Length
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes And CC Events. Run.
 * Version: 2.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-1-23)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end
local title = "Length (Enhanced Edition)"
local HWND =  reaper.MIDIEditor_GetActive()
if not HWND then return end
local take =  reaper.MIDIEditor_GetTake(HWND)
if not take or not reaper.TakeIsMIDI(take) then return end

function Length1(f)
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
        math.floor(f(note_t[4]-strtppq,id)+strtppq)+(note_t[5]-note_t[4]),
        note_t[6],
        note_t[7],
        note_t[8],
        true
      )
    end
  end
  reaper.MIDI_Sort(take)
end

function Length2(f)
  local id = 0
  for i = 1, ({reaper.MIDI_CountEvts( take )})[2] do
    local note_t = ({reaper.MIDI_GetNote( take, i-1 )})
    if note_t[2] then
      id = id + 1
      if id == 1 then strtppq = note_t[5] end
      reaper.MIDI_SetNote(
        take,
        i-1,
        note_t[2],
        note_t[3],
        note_t[4],
        math.floor(note_t[4]+f(note_t[5]-note_t[4]),id),
        note_t[6],
        note_t[7],
        note_t[8],
        true
      )
    end
  end
  reaper.MIDI_Sort(take)
end

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

local percent = reaper.GetExtState("LengthEnhancedVersion", "Percent")
if (percent == "") then percent = "200" end
local toggle = reaper.GetExtState("LengthEnhancedVersion", "Toggle")
if (toggle == "") then toggle = "0" end
local user_ok, input_csv = reaper.GetUserInputs('Length', 2, 'Percent,0=Start+Dur 1=Start 2=Durations', percent ..','.. toggle)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
percent, toggle = input_csv:match("(%d*),(%d*)")
reaper.SetExtState("LengthEnhancedVersion", "Percent", percent, false)
reaper.SetExtState("LengthEnhancedVersion", "Toggle", toggle, false)

function main()
  if user_ok then
    local func
    if not percent:match('[%d%.]+') or not tonumber(percent:match('[%d%.]+')) or not toggle:match('[%d%.]+') or not tonumber(toggle:match('[%d%.]+')) then return end
    func = load("local x = ... return x*"..tonumber(percent:match('[%d%.]+')) / 100)
    if not func then return end
    reaper.Undo_BeginBlock()
    if toggle == "2" then
      Length2(func)
    elseif toggle == "1" then
      Length1(func)
    else
      StretchSelectedNotes(func)
      StretchSelectedCCs(func)
    end
    reaper.Undo_EndBlock(title, 0)
  end
end

function CheckForNewVersion(new_version)
    local app_version = reaper.GetAppVersion()
    app_version = tonumber(app_version:match('[%d%.]+'))
    if new_version > app_version then
      reaper.MB('Update REAPER to newer version '..'('..new_version..' or newer)', '', 0)
      return
     else
      return true
    end
end

local CFNV = CheckForNewVersion(6.03)
if CFNV then main() end
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
