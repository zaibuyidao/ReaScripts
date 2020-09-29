--[[
 * ReaScript Name: Toggle Mute PC CC6
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: Mute PC CC6.lua (dangguidan)
 * REAPER: 6.0
 * provides: [main=main,midi_editor,midi_eventlisteditor] .
--]]

--[[
 * Changelog:
 * v1.0 (2020-4-15)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

function UnMuteCC()
  local count_items = reaper.CountMediaItems(0)
  for i = 1, count_items do
    local item = reaper.GetMediaItem(0, count_items - i)
    local take = reaper.GetTake(item, 0)
    local item_num = reaper.GetMediaItemInfo_Value(item, 'IP_ITEMNUMBER')
    if item_num == 0 and reaper.TakeIsMIDI(take) then
      _, _, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
      for i = 1, ccevtcnt do
        local _, _, _, _, chanmsg, _, msg2, _ = reaper.MIDI_GetCC(take, i - 1)
        if chanmsg == 0xB0 then -- CC
          if msg2 == 6 then -- CC#06
            reaper.MIDI_SetCC(take, i - 1, false, false, nil, nil, nil, nil, nil, true)
            reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 21036800)
          end
          if msg2 >= 98 and msg2 <= 101 then -- CC#98 - 101
            reaper.MIDI_SetCC(take, i - 1, false, false, nil, nil, nil, nil, nil, true)
            reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 21036800)
          end
        end
        if chanmsg == 0xC0 then -- Program Change
          reaper.MIDI_SetCC(take, i - 1, false, false, nil, nil, nil, nil, nil, true)
          reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 21036800)
        end
      end
      for i = 1, textsyxevtcnt do
        local _, _, _, _, _, msg = reaper.MIDI_GetTextSysexEvt(take, i - 1)
        reaper.MIDI_SetTextSysexEvt(take, i - 1, false, false, nil, nil, msg, true)
        reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 21036800)
      end
      reaper.MIDI_Sort(take)
    end
  end
end

function MuteCC()
  local count_items = reaper.CountMediaItems(0)
  for i = 1, count_items do
    local item = reaper.GetMediaItem(0, count_items - i)
    local take = reaper.GetTake(item, 0)
    local item_num = reaper.GetMediaItemInfo_Value(item, 'IP_ITEMNUMBER')
    if item_num == 0 and reaper.TakeIsMIDI(take) then
      _, _, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
      for i = 1, ccevtcnt do
        local _, _, _, _, chanmsg, _, msg2, _ = reaper.MIDI_GetCC(take, i - 1)
        if chanmsg == 0xB0 then -- CC
          if msg2 == 6 then -- CC#06
            reaper.MIDI_SetCC(take, i - 1, false, true, nil, nil, nil, nil, nil, true)
            reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 16777471)
          end
          if msg2 >= 98 and msg2 <= 101 then -- CC#98 - 101
            reaper.MIDI_SetCC(take, i - 1, false, true, nil, nil, nil, nil, nil, true)
            reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 16777471)
          end
        end
        if chanmsg == 0xC0 then -- Program Change
          reaper.MIDI_SetCC(take, i - 1, false, true, nil, nil, nil, nil, nil, true)
          reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 16777471)
        end
      end
      for i = 1, textsyxevtcnt do
        local _, _, _, _, _, msg = reaper.MIDI_GetTextSysexEvt(take, i - 1)
        reaper.MIDI_SetTextSysexEvt(take, i - 1, false, true, nil, nil, msg, true)
        reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 16777471)
      end
      reaper.MIDI_Sort(take)
    end
  end
end

local flag
local count_items = reaper.CountMediaItems(0)
for i = 1, count_items do
  local item = reaper.GetMediaItem(0, i - 1)
  local take = reaper.GetTake(item, 0)
  local item_num = reaper.GetMediaItemInfo_Value(item, 'IP_ITEMNUMBER')
  if item_num == 0 and reaper.TakeIsMIDI(take) then
    _, _, ccevtcnt, _ = reaper.MIDI_CountEvts(take)
    for i = 1, ccevtcnt do
      _, _, muted, _, chanmsg, _, _, _ = reaper.MIDI_GetCC(take, i - 1)
      if chanmsg == 0xC0 then -- Program Change
        if muted then
          flag = true
        else
          flag = false
        end
      end
    end
  end
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

if flag then
  UnMuteCC()
else
  MuteCC()
end

reaper.Undo_EndBlock("Toggle Mute PC CC6", 0)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()