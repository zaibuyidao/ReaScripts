--[[
 * ReaScript Name: Duplicate CC (For Selected CC)
 * Version: 1.0.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-6-12)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

if not reaper.SN_FocusMIDIEditor then
  local retval = reaper.ShowMessageBox("This script requires the SWS extension, would you like to download it now?\n這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
  if retval == 1 then
    Open_URL("http://www.sws-extension.org/download/pre-release/")
  end
end

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take or not reaper.TakeIsMIDI(take) then return end
  local _, _, ccevtcnt, _ = reaper.MIDI_CountEvts(take)

  local target = reaper.GetExtState("DuplicateCCForSelectedCC", "Target")
  if (target == "") then target = "11" end

  local retval, retvals_csv = reaper.GetUserInputs('Duplicate CC (For Selected CC)', 1, 'Target CC', target)
  target = retvals_csv:match("(.*)")
  if not retval or not tonumber(target) then return reaper.SN_FocusMIDIEditor() end
  target = tonumber(target)

  if target > 127 or target < 0 then
    return
    reaper.MB("請輸入從0到127的數值", "錯誤", 0),
    reaper.SN_FocusMIDIEditor()
  end

  reaper.SetExtState("DuplicateCCForSelectedCC", "Target", target, false)
  
  reaper.Undo_BeginBlock()
  reaper.MIDI_DisableSort(take)
  for i = 0, ccevtcnt - 1 do
    local _, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    local _, shape, beztension = reaper.MIDI_GetCCShape(take, i)

    if selected == true then
      ccevtcnt = ccevtcnt + 1
      reaper.MIDI_InsertCC(take, selected, muted, ppqpos, chanmsg, chan, target, msg3)
      reaper.MIDI_SetCCShape(take, ccevtcnt - 1, shape, beztension, false)
    end
  end
  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock("Duplicate CC (For Selected CC)", -1)
  reaper.UpdateArrange()
end

Main()
reaper.SN_FocusMIDIEditor()
