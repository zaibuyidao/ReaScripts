--[[
 * ReaScript Name: Articulation Map - Set Bank
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
 * v1.0 (2020-8-18)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function main()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelCC(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelCC(take, val)
  end
  if cnt == 0 then return reaper.SN_FocusMIDIEditor() end
  local MSB = reaper.GetExtState("SetInstrumentGroup", "MSB")
  if (MSB == "") then MSB = "0" end
  local user_ok, MSB = reaper.GetUserInputs('Set Bank', 1, 'Bank number', MSB)
  if not user_ok or not tonumber(MSB) then return reaper.SN_FocusMIDIEditor() end
  reaper.SetExtState("SetInstrumentGroup", "MSB", MSB, false)
  reaper.MIDI_DisableSort(take)
  for i = 1, #index do
    retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, index[i])
    if chanmsg == 176 and msg2 == 0 then -- CC#0
      reaper.MIDI_SetCC(take, index[i], nil, nil, nil, nil, nil, nil, MSB, false)
    end
  end
  reaper.MIDI_Sort(take)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Set Bank", -1)
end
main()
reaper.SN_FocusMIDIEditor()