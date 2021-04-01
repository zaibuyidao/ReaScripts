--[[
 * ReaScript Name: MIDI Channel From Track Send
 * Version: 1.3
 * Author: zaibuyidao
 * Reference: midi chan from track send.lua (dangguidan)
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-4-14)
  + Initial release
--]]

reaper.Main_OnCommand(40340, 0) -- Track: Unsolo all tracks
local count_items = reaper.CountMediaItems(0)
for i = 1, count_items do
    local item = reaper.GetMediaItem(0, i - 1)
    local take = reaper.GetTake(item, 0)
    local item_num = reaper.GetMediaItemInfo_Value(item, 'IP_ITEMNUMBER')
    if item_num == 0 and reaper.TakeIsMIDI(take) then
        local _, _, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
        for i = 1, ccevtcnt do
            local _, _, _, _, chanmsg, _, msg2, _ = reaper.MIDI_GetCC(take, i - 1)
            if chanmsg == 0xB0 then -- CC
                if msg2 == 6 then -- CC#06
                    reaper.MIDI_SetCC(take, i - 1, false, isMuted, nil, nil, nil, nil, nil, true)
                    reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 21036800)
                end
                if msg2 >= 98 and msg2 <= 101 then -- CC#98 - 101
                    reaper.MIDI_SetCC(take, i - 1, false, isMuted, nil, nil, nil, nil, nil, true)
                    reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 21036800)
                end
            end
            if chanmsg == 0xC0 then -- Program Change
                reaper.MIDI_SetCC(take, i - 1, false, isMuted, nil, nil, nil, nil, nil, true)
                reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 21036800)
            end
        end
        for i = 1, textsyxevtcnt do
            local _, _, _, _, _, msg = reaper.MIDI_GetTextSysexEvt(take, i - 1)
            reaper.MIDI_SetTextSysexEvt(take, i - 1, false, isMuted, nil, nil, msg, true)
            reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 21036800)
        end
    end
end
----------------------------------------
integer = reaper.CountMediaItems(0)
idx = 0
while idx < integer do
    MediaItem = reaper.GetMediaItem(0, idx)
    idx = idx + 1
    take = reaper.GetTake(MediaItem, 0)
    -- reaper.TakeIsMIDI(take)
    track = reaper.GetMediaItem_Track(MediaItem)
    num = reaper.GetMediaTrackInfo_Value(track, 'I_MIDIHWOUT')
    chan = math.fmod(num, 32)
    chan = chan - 1
    reaper.MIDI_DisableSort(take)
    retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
    i, ii, iii = 0, 0, 0
    while i < notecnt do
        reaper.MIDI_SetNote(take, i, NULL, NULL, NULL, NULL, chan, NULL, NULL, false)
        i = i + 1
    end
    while ii < ccevtcnt do
        reaper.MIDI_SetCC(take, ii, NULL, NULL, NULL, NULL, chan, NULL, NULL, false)
        ii = ii + 1
    end
    retval, selected, muted, ppqpos, type_1, msg =
        reaper.MIDI_GetTextSysexEvt(take, 0, NULL, NULL, NULL, 3, '')
    if type_1 == 3 then reaper.MIDI_DeleteTextSysexEvt(take, 0) end
    reaper.MIDI_Sort(take)
    -------------------------------------------------------------
    a = string.char(0x00, 0x40, 0x04, 0x01, 0x58, 0x12, 0x40, 0x19, 0x15, 0x00,
                    0x12)
    retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
    iii = 0
    while iii < textsyxevtcnt do
        retval, selected, muted, ppqpos, type_2, sys =
            reaper.MIDI_GetTextSysexEvt(take, iii, NULL, NULL, NULL, -1, '')
        if type_2 == 1 and sys == '@NTC1009' then
            take_sub = take
            idx_sub = iii
        end

        if type_2 == -1 and sys == a then
            reaper.MIDI_DeleteTextSysexEvt(take, iii)
            reaper.MIDI_SetTextSysexEvt(take_sub, idx_sub, NULL, NULL, NULL, 1, '@NTC10', false)
        end
        iii = iii + 1
    end -- sys delete

end -- while end
----------------------------------------------------- midi port from send
tb = {}
tb[string.char(0xFF, 0x21, 0x01, 0x00)] = 0
tb[string.char(0xFF, 0x21, 0x01, 0x01)] = 1
tb[string.char(0xFF, 0x21, 0x01, 0x02)] = 2
tb[string.char(0xFF, 0x21, 0x01, 0x03)] = 3
tb[string.char(0xFF, 0x21, 0x01, 0x04)] = 4
tb[string.char(0xFF, 0x21, 0x01, 0x05)] = 5
tb[string.char(0xFF, 0x21, 0x01, 0x06)] = 6
tb[string.char(0xFF, 0x21, 0x01, 0x07)] = 7
tb[string.char(0xFF, 0x21, 0x01, 0x08)] = 8
tb[string.char(0xFF, 0x21, 0x01, 0x09)] = 9
tb[string.char(0xFF, 0x21, 0x01, 0x0A)] = 10
tb[string.char(0xFF, 0x21, 0x01, 0x0B)] = 11
tb[string.char(0xFF, 0x21, 0x01, 0x0C)] = 12
tb[string.char(0xFF, 0x21, 0x01, 0x0D)] = 13
tb[string.char(0xFF, 0x21, 0x01, 0x0E)] = 14
tb[string.char(0xFF, 0x21, 0x01, 0x0F)] = 15
tb2 = {}
tb2[(0)] = string.char(0xFF, 0x21, 0x01, 0x00)
tb2[(1)] = string.char(0xFF, 0x21, 0x01, 0x01)
tb2[(2)] = string.char(0xFF, 0x21, 0x01, 0x02)
tb2[(3)] = string.char(0xFF, 0x21, 0x01, 0x03)
tb2[(4)] = string.char(0xFF, 0x21, 0x01, 0x04)
tb2[(5)] = string.char(0xFF, 0x21, 0x01, 0x05)
tb2[(6)] = string.char(0xFF, 0x21, 0x01, 0x06)
tb2[(7)] = string.char(0xFF, 0x21, 0x01, 0x07)
tb2[(8)] = string.char(0xFF, 0x21, 0x01, 0x08)
tb2[(9)] = string.char(0xFF, 0x21, 0x01, 0x09)
tb2[(10)] = string.char(0xFF, 0x21, 0x01, 0x0A)
tb2[(11)] = string.char(0xFF, 0x21, 0x01, 0x0B)
tb2[(12)] = string.char(0xFF, 0x21, 0x01, 0x0C)
tb2[(13)] = string.char(0xFF, 0x21, 0x01, 0x0D)
tb2[(14)] = string.char(0xFF, 0x21, 0x01, 0x0E)
tb2[(15)] = string.char(0xFF, 0x21, 0x01, 0x0F)
biao = {}

tr_idx = 0
tr_count = reaper.CountTracks(0)
while tr_idx < tr_count do
    track = reaper.GetTrack(0, tr_idx)
    item = reaper.GetTrackMediaItem(track, 0)
    if item ~= nil then
        take = reaper.GetMediaItemTake(item, 0)
        if reaper.TakeIsMIDI(take) then
            -- item_in = reaper.GetMediaItemInfo_Value(item, 'D_POSITION' )
            -- if item_in~=0 then reaper.SetMediaItemInfo_Value(item, 'D_POSITION' , 0) end
            reaper.MIDI_DisableSort(take)

            idx = 0

            repeat
              retval, selected, muted, ppqpos, msg = reaper.MIDI_GetEvt(take, idx, false, false, 0, '')

              if tb[msg] ~= nil then

                  port = reaper.GetMediaTrackInfo_Value(track, 'I_MIDIHWOUT')
                  if port ~= -1 then
                      port = math.modf(port / 32)
                      table.insert(biao, port)
                      if port ~= -1 and port < 16 then
                          reaper.MIDI_SetEvt(take, idx, false, false, ppqpos, tb2[port], false)
                      end
                  end -- port -1
              end
              idx = idx + 1
              retval, selected, muted, ppqpos, msg = reaper.MIDI_GetEvt(take, idx, false, false, 0, '')
            until ppqpos > 0 or retval == false

            reaper.MIDI_Sort(take)

        end -- if midi take end
    end -- item end

    tr_idx = tr_idx + 1

end -- while end

reaper.Main_OnCommand(40849, 0) -- File: Export project MIDI...
