--[[
 * ReaScript Name: 允许多轨试听(Take)
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
reaper.SetToggleCommandState(sectionID,ownCommandID,1)
reaper.RefreshToolbar2(sectionID, ownCommandID)

track_tb={}
tb={}

function test()
integer = reaper.JS_Mouse_GetState(-1)
state = reaper.JS_VKeys_GetState(0.1)
ret = state:byte(65) 

if ret==1  then 
if flag==0 then 
reaper.Main_OnCommand(reaper.NamedCommandLookup('_BR_SAVE_SOLO_MUTE_ALL_TRACKS_SLOT_1'), 0)
reaper.Main_OnCommand(40340,0) --unsolo all track
reaper.Main_OnCommand(41558,0) --solo item
reaper.Main_OnCommand(reaper.NamedCommandLookup('_BR_CONT_PLAY_MOUSE'),0) 
--reaper.ShowConsoleMsg('solo') 
flag=1
end
end
if ret==0 and flag==1 then 
reaper.Main_OnCommand(41185,0) -- un solo all item
reaper.Main_OnCommand(reaper.NamedCommandLookup('_BR_RESTORE_SOLO_MUTE_ALL_TRACKS_SLOT_1'), 0)
--reaper.ShowConsoleMsg('unsolo') 
flag=0 
end

reaper.defer(test)
end

test()

function exit()
reaper.SetToggleCommandState(sectionID,ownCommandID,0)
reaper.RefreshToolbar2(sectionID,ownCommandID)
end
reaper.atexit(exit)

