--[[
 * ReaScript Name: Move Events Left 10ms
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2022-3-24)
  + Initial release
--]]

ms = -10

function msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

if not reaper.SN_FocusMIDIEditor then
  local retval = reaper.ShowMessageBox("這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
  if retval == 1 then
    Open_URL("http://www.sws-extension.org/download/pre-release/")
  end
end

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not take or not reaper.TakeIsMIDI(take) then return end
_, notes, ccs, sysex = reaper.MIDI_CountEvts(take)

ms = ms / 1000

function NOTES() -- 音符事件
  for i = 0, notes - 1 do
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      pro_start = (reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)) + ms
      qqq_pro_start = reaper.MIDI_GetPPQPosFromProjTime(take, pro_start)
      pro_end = (reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)) + ms
      qqq_pro_end = reaper.MIDI_GetPPQPosFromProjTime(take, pro_end)
      reaper.MIDI_SetNote(take, i, selected, muted, qqq_pro_start, qqq_pro_end, chan, pitch, vel, false)
    end
  end
end

function CCS() -- CC事件
  for i = 0, ccs - 1 do
    local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    if selected == true then
      pro_ccstart = (reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)) + ms
      qqq_pro_ccstart = reaper.MIDI_GetPPQPosFromProjTime(take, pro_ccstart)
      reaper.MIDI_SetCC(take, i, selected, muted, qqq_pro_ccstart, chanmsgIn, chanIn, msg2In, msg3In, false)
    end
  end
end

function SYSEX() -- Sysex事件
  for i = 0, sysex - 1 do
    local retval, selected, muted, ppqpos, types, msg = reaper.MIDI_GetTextSysexEvt(take, i)
    if selected == true then
      pro_sysstart = (reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)) + ms
      qqq_pro_sysstart = reaper.MIDI_GetPPQPosFromProjTime(take, pro_sysstart)
      reaper.MIDI_SetTextSysexEvt(take, i, selected, muted, qqq_pro_sysstart, types, msg, false) 
    end
  end
end

reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
NOTES()
CCS()
SYSEX()
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("Move Events Left 10ms", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()