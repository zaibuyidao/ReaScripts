--[[
 * ReaScript Name: 滚擦自动分轨
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

local editor=reaper.MIDIEditor_GetActive()

local take_cym=reaper.MIDIEditor_GetTake(editor)

track_cym=reaper.GetMediaItemTake_Track(take_cym)

reaper.Undo_BeginBlock()

reaper.MIDI_DisableSort(take_cym)
reaper.MIDI_SelectAll(take_cym,false)
idx=0 cym_49={} cym_52={} cym_55={} cym_57={} cym_49_n={} cym_52_n={} cym_55_n={} cym_57_n={}
cym_49_tick={} cym_52_tick={} cym_55_tick={} cym_57_tick={}
cym_49_tick[0]=-81 cym_52_tick[0]=-81 cym_55_tick[0]=-81 cym_57_tick[0]=-81
idx_49={} idx_52={} idx_55={} idx_57={} idx_49_n={} idx_52_n={} idx_55_n={} idx_57_n={} 
repeat
retval,selected, muted,startppqpos,endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take_cym, idx)
if pitch==49 then table.insert(cym_49,startppqpos..','..endppqpos..','..chan..','..pitch..','..vel ) 
   table.insert(cym_49_tick,startppqpos) table.insert(idx_49,idx) end
if pitch==52 then table.insert(cym_52,startppqpos..','..endppqpos..','..chan..','..pitch..','..vel ) 
  table.insert(cym_52_tick,startppqpos) table.insert(idx_52,idx) end
if pitch==55 then table.insert(cym_55,startppqpos..','..endppqpos..','..chan..','..pitch..','..vel )
   table.insert(cym_55_tick,startppqpos) table.insert(idx_55,idx) end
if pitch==57 then table.insert(cym_57,startppqpos..','..endppqpos..','..chan..','..pitch..','..vel ) 
   table.insert(cym_57_tick,startppqpos) table.insert(idx_57,idx) end
idx=idx+1
until retval==false

if #cym_49_tick>0 then 
i=0 max=#cym_49_tick table.insert(cym_49_tick,cym_49_tick[max]+81)
while i<max do
if cym_49_tick[i+1]-cym_49_tick[i]<81 or cym_49_tick[i+2]-cym_49_tick[i+1]<81 then 
table.insert(cym_49_n,cym_49[i+1])  
reaper.MIDI_SetNote(take_cym, idx_49[i+1], true, false, NULL,NULL, NULL, NULL,NULL, false)  end 
i=i+1
end end 

if #cym_52_tick>0 then 
i=0 max=#cym_52_tick table.insert(cym_52_tick,cym_52_tick[max]+81)
while i<max do
if cym_52_tick[i+1]-cym_52_tick[i]<81 or cym_52_tick[i+2]-cym_52_tick[i+1]<81 then 
table.insert(cym_52_n,cym_52[i+1])  
reaper.MIDI_SetNote(take_cym, idx_52[i+1], true, false, NULL,NULL, NULL, NULL,NULL, false)  end 
i=i+1
end end 

if #cym_55_tick>0 then 
i=0 max=#cym_55_tick table.insert(cym_55_tick,cym_55_tick[max]+81)
while i<max do
if cym_55_tick[i+1]-cym_55_tick[i]<81 or cym_55_tick[i+2]-cym_55_tick[i+1]<81 then 
table.insert(cym_55_n,cym_55[i+1])  
reaper.MIDI_SetNote(take_cym, idx_55[i+1], true, false, NULL,NULL, NULL, NULL,NULL, false)  end 
i=i+1
end end 

if #cym_57_tick>0 then 
i=0 max=#cym_57_tick table.insert(cym_57_tick,cym_57_tick[max]+81)
while i<max do
if cym_57_tick[i+1]-cym_57_tick[i]<81 or cym_57_tick[i+2]-cym_57_tick[i+1]<81 then 
table.insert(cym_57_n,cym_57[i+1])  
reaper.MIDI_SetNote(take_cym, idx_57[i+1], true, false, NULL,NULL, NULL, NULL,NULL, false)  end 
i=i+1
end end 

 selnoteidx=reaper.MIDI_EnumSelNotes(take_cym,-1)
 while  selnoteidx~=-1 do
 reaper.MIDI_DeleteNote(take_cym,selnoteidx)
 selnoteidx=reaper.MIDI_EnumSelNotes(take_cym,-1)
 end
reaper.MIDI_Sort(take_cym)

 if #cym_49_n>0 or #cym_52_n>0 or #cym_55_n>0 or #cym_57_n>0 then
track_cym=reaper.GetMediaItemTake_Track(take_cym)
track_cym_midiport=reaper.GetMediaTrackInfo_Value(track_cym, 'I_MIDIHWOUT')
fold_cym = reaper.GetMediaTrackInfo_Value(track_cym, 'I_FOLDERDEPTH')
item_cym= reaper.GetMediaItemTake_Item(take_cym)
st_cym = reaper.GetMediaItemInfo_Value(item_cym, 'D_POSITION')
lenth_cym = reaper.GetMediaItemInfo_Value(item_cym, 'D_LENGTH')
number_cym=reaper.GetMediaTrackInfo_Value(track_cym, 'IP_TRACKNUMBER')
retval, track_cym = reaper.GetSetMediaTrackInfo_String(track_cym, 'P_NAME', '', false)
track1=reaper.GetTrack(0,0)

 reaper.InsertTrackAtIndex(number_cym,false)
 track_roll=reaper.GetTrack(0, number_cym)
 reaper.SetMediaTrackInfo_Value(track_roll,'I_MIDIHWOUT',track_cym_midiport)
 if fold_cym<0 then
 reaper.SetMediaTrackInfo_Value(track_cym, 'I_FOLDERDEPTH', 0)
 reaper.SetMediaTrackInfo_Value(track_roll, 'I_FOLDERDEPTH', fold_cym)
 end
 reaper.CreateTrackSend(track1, track_roll)
 reaper.SetTrackSendInfo_Value(track_roll, -1, 0, 'B_MUTE', 1)
 retval, trackname = reaper.GetSetMediaTrackInfo_String(track_roll, 'P_NAME', track_cym..' ROLL', true)
 item_roll=reaper.CreateNewMIDIItemInProj(track_roll, st_cym, st_cym+lenth_cym, false)
 take_roll= reaper.GetMediaItemTake(item_roll, 0)
 item_roll2=reaper.CreateNewMIDIItemInProj(track_roll, 0, 0.05, false)
 take_roll2= reaper.GetMediaItemTake(item_roll2, 0)
 reaper.MIDI_InsertEvt(take_roll2,false,false,0,string.char(0xFF,0x21,0x01,0x00))
 
 reaper.MIDI_DisableSort(take_roll)
 
 for ii, vv in ipairs(cym_49_n) do 
 startppqpos,endppqpos,chan,pitch,vel=string.match(cym_49_n[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_roll, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end
 
 for ii, vv in ipairs(cym_52_n) do 
 startppqpos,endppqpos,chan,pitch,vel=string.match(cym_52_n[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_roll, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end
 
 for ii, vv in ipairs(cym_55_n) do 
 startppqpos,endppqpos,chan,pitch,vel=string.match(cym_55_n[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_roll, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end
 
 for ii, vv in ipairs(cym_57_n) do 
 startppqpos,endppqpos,chan,pitch,vel=string.match(cym_57_n[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_roll, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end

reaper.MIDI_Sort(take_roll)

end

reaper.UpdateArrange()
reaper.MIDIEditor_OnCommand(editor,40818) 
reaper.MIDIEditor_OnCommand(editor,40818)

reaper.Undo_EndBlock('',0)
