--[[
 * ReaScript Name: Set Midi Port
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

tb={}
tb[string.char(0xFF,0x21,0x01,0x00)]=0
tb[string.char(0xFF,0x21,0x01,0x01)]=1
tb[string.char(0xFF,0x21,0x01,0x02)]=2
tb[string.char(0xFF,0x21,0x01,0x03)]=3
tb[string.char(0xFF,0x21,0x01,0x04)]=4
tb[string.char(0xFF,0x21,0x01,0x05)]=5
tb[string.char(0xFF,0x21,0x01,0x06)]=6
tb[string.char(0xFF,0x21,0x01,0x07)]=7
tb[string.char(0xFF,0x21,0x01,0x08)]=8
tb[string.char(0xFF,0x21,0x01,0x09)]=9
tb[string.char(0xFF,0x21,0x01,0x0A)]=10
tb[string.char(0xFF,0x21,0x01,0x0B)]=11
tb[string.char(0xFF,0x21,0x01,0x0C)]=12
tb[string.char(0xFF,0x21,0x01,0x0D)]=13
tb[string.char(0xFF,0x21,0x01,0x0E)]=14
tb[string.char(0xFF,0x21,0x01,0x0F)]=15
tb2={}
tb2[(0)]=string.char(0xFF,0x21,0x01,0x00)
tb2[(1)]=string.char(0xFF,0x21,0x01,0x01)
tb2[(2)]=string.char(0xFF,0x21,0x01,0x02)
tb2[(3)]=string.char(0xFF,0x21,0x01,0x03)
tb2[(4)]=string.char(0xFF,0x21,0x01,0x04)
tb2[(5)]=string.char(0xFF,0x21,0x01,0x05)
tb2[(6)]=string.char(0xFF,0x21,0x01,0x06)
tb2[(7)]=string.char(0xFF,0x21,0x01,0x07)
tb2[(8)]=string.char(0xFF,0x21,0x01,0x08)
tb2[(9)]=string.char(0xFF,0x21,0x01,0x09)
tb2[(10)]=string.char(0xFF,0x21,0x01,0x0A)
tb2[(11)]=string.char(0xFF,0x21,0x01,0x0B)
tb2[(12)]=string.char(0xFF,0x21,0x01,0x0C)
tb2[(13)]=string.char(0xFF,0x21,0x01,0x0D)
tb2[(14)]=string.char(0xFF,0x21,0x01,0x0E)
tb2[(15)]=string.char(0xFF,0x21,0x01,0x0F)
biao={}

tr_idx=0
tr_count=reaper.CountTracks(0)
while  tr_idx<tr_count do
track = reaper.GetTrack(0, tr_idx)
item = reaper.GetTrackMediaItem(track, 0)
if item~=nil then 
take = reaper.GetMediaItemTake(item, 0)
if reaper.TakeIsMIDI(take) then
--item_in = reaper.GetMediaItemInfo_Value(item, 'D_POSITION' )
--if item_in~=0 then reaper.SetMediaItemInfo_Value(item, 'D_POSITION' , 0) end
reaper.MIDI_DisableSort(take)

idx=0

repeat
retval, selected, muted, ppqpos, msg = reaper.MIDI_GetEvt(take, idx,false, false, 0, '')

if tb[msg]~=nil then

port = reaper.GetMediaTrackInfo_Value(track, 'I_MIDIHWOUT')
if port~=-1 then
port= math.modf(port / 32)
table.insert(biao,port)
reaper.MIDI_SetEvt(take, idx, false, false, ppqpos, tb2[port], false)
end -- port -1
end
idx=idx + 1
retval, selected, muted, ppqpos, msg = reaper.MIDI_GetEvt(take, idx,false, false, 0, '')
until ppqpos > 0 or retval==false

reaper.MIDI_Sort(take)

end -- if midi take end
end --item end

tr_idx=tr_idx+1

end --while end




