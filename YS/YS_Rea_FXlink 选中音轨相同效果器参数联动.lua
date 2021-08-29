--[[
 * ReaScript Name: Rea_FXlink 选中音轨相同效果器参数联动
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

function Q_link()
--retval1, tracknumber, itemnumber, fx1number = reaper.GetFocusedFX2()
retval1, tracknumber, fx1number, paramnumber = reaper.GetLastTouchedFX()
if retval1 then
TK1=reaper.GetTrack(0,tracknumber-1)
if reaper.IsTrackSelected(TK1) then 
retval, fxname=reaper.TrackFX_GetFXName(TK1,fx1number,'')
weizhi=string.find (fxname, ':')
fxname=string.sub(fxname, weizhi+2)
NumParams=reaper.TrackFX_GetNumParams(TK1,fx1number)

Params_idx=0 tb_Params={}
while  Params_idx<NumParams do
Params_val, minval, maxval = reaper.TrackFX_GetParam(TK1,fx1number, Params_idx)
table.insert(tb_Params,Params_val) Params_idx=Params_idx+1 end

seltrackidx=0
seltracknum=reaper.CountSelectedTracks(0)
while seltrackidx<seltracknum do
seltrack=reaper.GetSelectedTrack(0,seltrackidx)
if seltrack~=TK1 then
integer=reaper.TrackFX_GetByName(seltrack, fxname, false)
   if integer~=-1 then 
      for i , v in ipairs(tb_Params) do
      reaper.TrackFX_SetParam(seltrack, integer, i-1, v)
      end
   end
end --if end
seltrackidx=seltrackidx+1
end --while end
reaper.TrackFX_SetParam(TK1, fx1number, 0, tb_Params[1])
end
end  --Track1Selected 
reaper.defer(Q_link)
--keyid=reaper.NamedCommandLookup('_RSa275eca631c3e9e9f8bea3029f2fe4a2f33b4c94')
end
Q_link()

_, _, sectionID, ownCommandID, _, _, _ = reaper.get_action_context()
reaper.SetToggleCommandState(sectionID,ownCommandID,1)
reaper.RefreshToolbar2(sectionID, ownCommandID)

function exit()
reaper.SetToggleCommandState(sectionID,ownCommandID,0)
reaper.RefreshToolbar2(sectionID,ownCommandID)
end
reaper.atexit(exit)

