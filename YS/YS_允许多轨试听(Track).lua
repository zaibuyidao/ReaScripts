--[[
 * ReaScript Name: 允许多轨试听(Track)
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

flag=0
_, _, sectionID, ownCommandID, _, _, _ = reaper.get_action_context()

track_tb={}

function test()
state = reaper.JS_VKeys_GetState(0)
ret = state:byte(65)
if ret==1 then 
if flag==0 then 
editor=reaper.MIDIEditor_GetActive()
take=reaper.MIDIEditor_GetTake(editor)
track0 = reaper.GetMediaItemTake_Track(take)
temptrack=''
contselitem= reaper.CountSelectedMediaItems(0)
selitem = 0
while selitem < contselitem do
MediaItem = reaper.GetSelectedMediaItem(0, selitem)
track = reaper.GetMediaItem_Track(MediaItem)
if track~=temptrack and track~=track0 then
reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 1)
table.insert(track_tb,track)
end
temptrack=track
selitem = selitem + 1
end -- while item end
--reaper.ShowConsoleMsg('solo') 
flag=1 end
else 
if flag==1 then 

--[[editor=reaper.MIDIEditor_GetActive()
take=reaper.MIDIEditor_GetTake(editor)
track0 = reaper.GetMediaItemTake_Track(take)
temptrack=''
contselitem= reaper.CountSelectedMediaItems(0)
selitem = 0
while selitem < contselitem do
MediaItem = reaper.GetSelectedMediaItem(0, selitem)
track = reaper.GetMediaItem_Track(MediaItem)
if track~=temptrack and track~=track0 then
reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 0)
end
selitem = selitem + 1
end -- while item end --]]
--reaper.ShowConsoleMsg('unsolo')
for i , v in ipairs (track_tb) do  reaper.SetMediaTrackInfo_Value(v, 'I_SOLO', 0) end
track_tb={}
reaper.MIDIEditor_OnCommand(editor,40818) 
reaper.MIDIEditor_OnCommand(editor,40818)
flag=0 end
end
reaper.SetToggleCommandState(sectionID,ownCommandID,1)
reaper.RefreshToolbar2(sectionID, ownCommandID)
reaper.defer(test)
end

test()


function exit()
reaper.SetToggleCommandState(sectionID,ownCommandID,0)
reaper.RefreshToolbar2(sectionID,ownCommandID)
end
reaper.atexit(exit)

