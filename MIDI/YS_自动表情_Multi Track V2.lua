--[[
 * ReaScript Name: 自动表情_Multi Track V2
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

local retval, shuzhi = reaper.GetUserInputs('自动表情(多轨) ', 8, 'CC min Val=,CC Max Val=,歌曲速度：0 慢 1 快,1:悠扬 2:强烈 3:手动,起音形状 1:正 2:反,弧度 0-100 ,音尾形状 1:正 2:反,弧度 0-100', '88,127,0,1,1,25,1,40')
local min_sub,max_sub,qusu_sub,moshi_sub,qiyin_sub,hudu1_sub,yinwei_sub,hudu2_sub=string.match(shuzhi,"(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)")
local min_val=tonumber (min_sub)
local max_val=tonumber (max_sub)
local qushu=tonumber (qusu_sub)
local moshi=tonumber (moshi_sub)
local qiyin=tonumber (qiyin_sub)
local hudu1=tonumber (hudu1_sub)
local yinwei=tonumber (yinwei_sub)
local hudu2=tonumber (hudu2_sub)

if retval then

if moshi == 3 then
if qiyin == 1 then bsl_in = hudu1 / 100 * -1  else bsl_in = hudu1 / 100 end
if yinwei == 1 then bsl_out = hudu2 / 100 else bsl_out = hudu2 / 100 * -1 end
end
if moshi == 1 then bsl_in = -0.2  bsl_out = 0.4 end
if moshi == 2 then bsl_in = 0.25  bsl_out = 0.4 end

-- qushuzhi

local editor=reaper.MIDIEditor_GetActive()
contselitem= reaper.CountSelectedMediaItems(0)
selitem = 0
while selitem < contselitem do
MediaItem = reaper.GetSelectedMediaItem(0, selitem)
selitem = selitem + 1
take = reaper.GetTake(MediaItem, 0)

if reaper.TakeIsMIDI(take) then

local idx=-1  biaoji = 0
repeat
local n_idx = reaper.MIDI_EnumSelNotes(take,idx)
local retval, sel, mute, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, n_idx)

local dur=endppqpos-startppqpos
 if (dur > 960) then
     reaper.MIDI_InsertCC(take, true,false, startppqpos, 176, 0, 11, min_val)
     reaper.MIDI_InsertCC(take, false,false, startppqpos+720, 176, 0, 11, max_val)
     end
 if (dur == 960) then
     reaper.MIDI_InsertCC(take, true,false, startppqpos, 176, 0, 11, min_val)
     reaper.MIDI_InsertCC(take, false,false, startppqpos+480, 176, 0, 11, max_val)
     end
 if (dur >=480 and dur < 960) then
    reaper.MIDI_InsertCC(take, true,false, startppqpos, 176, 0, 11, min_val)
    reaper.MIDI_InsertCC(take, false,false, startppqpos+360, 176, 0, 11, max_val)
    end --480-960
    if qushu==0 then
    if (dur >= 240 and dur < 480) then
    reaper.MIDI_InsertCC(take, true,false, startppqpos, 176, 0, 11, min_val)
   reaper.MIDI_InsertCC(take, false,false, startppqpos+190, 176, 0, 11, max_val)
   end
    end --240-480
    if qushu==0 then notedur=240 else notedur=480 end
    if (dur > 0 and dur < notedur ) then
     if biaoji == 0 then
     reaper.MIDI_InsertCC(take, false,false, startppqpos, 176, 0, 11, max_val)
     biaoji = 1
     end
     else biaoji = 0
     end -- <240
idx=n_idx
until (n_idx==-1)
reaper.MIDI_Sort(take)

--write end
reaper.MIDI_DisableSort(take)
local ccidx=-1
repeat
     integer = reaper.MIDI_EnumSelCC(take, ccidx)
    reaper.MIDI_SetCCShape(take, ccidx, 5, bsl_in, true)
    reaper.MIDI_SetCC(take, ccidx, false, false, NULL,NULL, NULL, NULL, NULL, true)
    ccidx=integer
until integer==-1
reaper.MIDI_Sort(take)
--shape first

reaper.MIDI_DisableSort(take)
local idx=-1
repeat
local n_idx = reaper.MIDI_EnumSelNotes(take,idx)
local retval, sel, mute, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, n_idx)

local dur=endppqpos-startppqpos
 if (dur >= 960) then
     reaper.MIDI_InsertCC(take, true,false, endppqpos-360, 176, 0, 11, max_val)
     min_sub= math.modf (( (max_val - min_val) / max_val )*65 )+ min_val
     reaper.MIDI_InsertCC(take, false,false, endppqpos-20, 176, 0, 11, min_sub )
     end
idx=n_idx
until (n_idx==-1)
reaper.MIDI_Sort(take)

--write end
reaper.MIDI_DisableSort(take)
local ccidx=-1
repeat
     integer = reaper.MIDI_EnumSelCC(take, ccidx)
    reaper.MIDI_SetCCShape(take, ccidx, 5, bsl_out, true)
    reaper.MIDI_SetCC(take, ccidx, false, false, NULL,NULL, NULL, NULL, NULL, true)
    ccidx=integer
until integer==-1
reaper.MIDI_Sort(take)
--shape first
end -- take is midi
end -- while item end

end
reaper.SN_FocusMIDIEditor()
