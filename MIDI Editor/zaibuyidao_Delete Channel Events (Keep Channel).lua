--[[
 * ReaScript Name: Delete Channel Events (Keep Channel)
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
 * provides: [main=main,midi_editor,midi_inlineeditor] .
--]]

--[[
 * Changelog:
 * v1.0 (2020-12-26)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end
function DelEvent()
  i = reaper.MIDI_EnumSelNotes(take, -1)
  while i > -1 do
    reaper.MIDI_DeleteNote(take, i)
    i = reaper.MIDI_EnumSelNotes(take, -1)
  end
  j = reaper.MIDI_EnumSelCC(take, -1)
  while j > -1 do
      reaper.MIDI_DeleteCC(take, j)
      j = reaper.MIDI_EnumSelCC(take, -1)
  end
end
function SelChanEvent(amount)
  i = reaper.MIDI_EnumSelNotes(take, -1)
  if i ~= -1 then isSelNote = true end
  j = reaper.MIDI_EnumSelCC(take, -1)
  if j ~= -1 then isSelCC = true end
  if isSelNote or isSelCC then
    while i ~= -1 do
      local note = {}
      note[i] = {}
      note[i].ret,
      note[i].sel,
      note[i].muted,
      note[i].startppqpos,
      note[i].endppqpos,
      note[i].chan,
      note[i].pitch,
      note[i].vel = reaper.MIDI_GetNote(take, i)
      if (note[i].chan == amount)  then
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, note[i].chan, nil, nil, true)
      end
      i = reaper.MIDI_EnumSelNotes(take, i)
    end
    while j ~= -1 do
      local cc = {}
      cc[j] = {}
      cc[j].ret,
      cc[j].sel,
      cc[j].muted,
      cc[j].ppqpos,
      cc[j].chanmsg,
      cc[j].chan,
      cc[j].msg2,
      cc[j].msg3 = reaper.MIDI_GetCC(take, j)
      if (cc[j].chan == amount)  then
        reaper.MIDI_SetCC(take, j, false, nil, nil, nil, cc[j].chan, nil, nil, true)
      end
      j = reaper.MIDI_EnumSelCC(take, j)
    end
  else
    for i = 0, notecnt-1 do
      _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
      if not isSelNote and not (chan == amount) then
        reaper.MIDI_SetNote(take, i, true, nil, nil, nil, chan, nil, nil, true)
      end
    end
    for j = 0, ccevtcnt-1 do
      local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, j)
      if not isSelCC and not (chan == amount) then
        reaper.MIDI_SetCC(take, j, true, nil, nil, nil, chan, nil, nil, true)
      end
    end
  end
end
function Main()
  local window, _, _ = reaper.BR_GetMouseCursorContext()
  local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
  amount = reaper.GetExtState("DeleteChannelEventsKeepChannel", "Channel")
  if (amount == "") then amount = "1" end
  user_ok, amount = reaper.GetUserInputs("Delete Channel Events (Keep Channel)", 1, "Keep channel", amount)
  amount = tonumber(amount)
  reaper.SetExtState("DeleteChannelEventsKeepChannel", "Channel", amount, false)
  amount = amount - 1
  if window == "midi_editor" then
    if not inline_editor then
        if not user_ok or not tonumber(amount) then return reaper.SN_FocusMIDIEditor() end
        take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
        _, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
        reaper.MIDI_DisableSort(take)
        SelChanEvent(amount)
        DelEvent()
        reaper.MIDI_Sort(take)
    else
        if not user_ok or not tonumber(amount) then return end
        take = reaper.BR_GetMouseCursorContext_Take()
        _, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
        reaper.MIDI_DisableSort(take)
        SelChanEvent(amount)
        DelEvent()
        reaper.MIDI_Sort(take)
    end
    if not inline_editor then reaper.SN_FocusMIDIEditor() end
  else
    if not user_ok or not tonumber(amount) then return end
    count_sel_items = reaper.CountSelectedMediaItems(0)
    if count_sel_items == 0 then return end
    for i = 1, count_sel_items do
        item = reaper.GetSelectedMediaItem(0, i - 1)
        take = reaper.GetTake(item, 0)
        _, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
        reaper.MIDI_DisableSort(take)
        if reaper.TakeIsMIDI(take) then
          SelChanEvent(amount)
          DelEvent()
        end
        reaper.MIDI_Sort(take)
    end
  end
end
local title = "Delete Channel Events (Keep Channel)"
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
