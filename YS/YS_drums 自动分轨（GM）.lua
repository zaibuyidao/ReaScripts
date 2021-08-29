--[[
 * ReaScript Name: drums 自动分轨（GM）
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

tb_kit={}
tb_kit[0]='KICK_0'
tb_kit[1]='KICK_1'
tb_kit[2]='KICK_2'
tb_kit[3]='KICK_3'
tb_kit[4]='KICK_4'
tb_kit[5]='KICK_5'
tb_kit[6]='KICK_6'
tb_kit[7]='KICK_7'
tb_kit[8]='KICK_8'
tb_kit[9]='KICK_9'
tb_kit[10]='KICK_10'
tb_kit[11]='KICK_11'
tb_kit[12]='KICK_12'
tb_kit[13]='KICK_13'
tb_kit[14]='KICK_14'
tb_kit[15]='KICK_15'
tb_kit[16]='KICK_16'
tb_kit[17]='VOX'
tb_kit[18]='VOX'
tb_kit[19]='VOX'
tb_kit[20]='20'
tb_kit[21]='21'
tb_kit[22]='MC-500 BEEP'
tb_kit[23]='MC-500 BEEP'
tb_kit[24]='SD'
tb_kit[25]='SD ROLL'
tb_kit[26]='FINGER SNAP'
tb_kit[27]='HIGH Q'
tb_kit[28]='SLAP'
tb_kit[29]='SCRATCH'
tb_kit[30]='SCRATCH'
tb_kit[31]='STICK'
tb_kit[32]='CLICK'
tb_kit[33]='METRONOME'
tb_kit[34]='METRONOME'
tb_kit[35]='KICK_35'
tb_kit[36]='KICK_36'
tb_kit[37]='STICK'
tb_kit[38]='SN_38'
tb_kit[39]='CLAP'
tb_kit[40]='SN_40'
tb_kit[41]='TOM'
tb_kit[42]='HI HAT'
tb_kit[43]='TOM'
tb_kit[44]='HI HAT'
tb_kit[45]='TOM'
tb_kit[46]='HI HAT'
tb_kit[47]='TOM'
tb_kit[48]='TOM'
tb_kit[49]='CYM'
tb_kit[50]='TOM'
tb_kit[51]='RIDE'
tb_kit[52]='CYM'
tb_kit[53]='RIDE'
tb_kit[54]='TAMB'
tb_kit[55]='CYM'
tb_kit[56]='COWBELL'
tb_kit[57]='CYM'
tb_kit[58]='VIBRASLAP'
tb_kit[59]='RIDE'
tb_kit[60]='BONGO'
tb_kit[61]='BONGO'
tb_kit[62]='CONGA'
tb_kit[63]='CONGA'
tb_kit[64]='CONGA'
tb_kit[65]='TIMBALE'
tb_kit[66]='TIMBALE'
tb_kit[67]='AGOGO'
tb_kit[68]='AGOGO'
tb_kit[69]='CABASA'
tb_kit[70]='MARACA'
tb_kit[71]='WHISTLE'
tb_kit[72]='WHISTLE'
tb_kit[73]='GUIRO'
tb_kit[74]='GUIRO'
tb_kit[75]='CLAVES'
tb_kit[76]='WOODBLOCK'
tb_kit[77]='WOODBLOCK'
tb_kit[78]='CUICA'
tb_kit[79]='CUICA'
tb_kit[80]='TRIANGLE'
tb_kit[81]='TRIANGLE'
tb_kit[82]='SHAKER'
tb_kit[83]='JUNGLE BELL'
tb_kit[84]='BELL TREE'
tb_kit[85]='CASTANETS'
tb_kit[86]='SURDO'
tb_kit[87]='SURDO'
tb_kit[88]='APPLAUS'
tb_kit[89]='89'
tb_kit[90]='90'
tb_kit[91]='91'
tb_kit[92]='92'
tb_kit[93]='93'
tb_kit[94]='94'
tb_kit[95]='95'
tb_kit[96]='96'
tb_kit[97]='SN_97' 
tb_kit[98]='SN_98' 
tb_kit[99]='SN_99' 
tb_kit[100]='SN_100' 
tb_kit[101]='SN_101' 
tb_kit[102]='SN_102' 
tb_kit[103]='SN_103' 
tb_kit[104]='SN_104' 
tb_kit[105]='SN_105'
tb_kit[106]='SN_106'
tb_kit[107]='SN_107'
tb_kit[108]='SN_108'
tb_kit[109]='SN_109'
tb_kit[110]='SN_110'
tb_kit[111]='SN_111'
tb_kit[112]='SN_112'
tb_kit[113]='SN_113'
tb_kit[114]='SN_114'
tb_kit[115]='SN_115'
tb_kit[116]='SN_116'
tb_kit[117]='SN_117'
tb_kit[118]='SN_118'
tb_kit[119]='SN_119'
tb_kit[120]='SN_120'
tb_kit[121]='SN_121'
tb_kit[122]='SN_122'
tb_kit[123]='SN_123'
tb_kit[124]='SN_124'
tb_kit[125]='SN_125'
tb_kit[126]='SN_126' 
tb_kit[127]='SN_127' 

reaper.Undo_BeginBlock()

local editor=reaper.MIDIEditor_GetActive()
reaper.MIDIEditor_OnCommand(editor,40214)  -- unselect all

local take=reaper.MIDIEditor_GetTake(editor)

track0=reaper.GetMediaItemTake_Track(take)
track0_midiport=reaper.GetMediaTrackInfo_Value(track0, 'I_MIDIHWOUT')
fold = reaper.GetMediaTrackInfo_Value(track0, 'I_FOLDERDEPTH')
item= reaper.GetMediaItemTake_Item(take)
st = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
lenth = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
number0=reaper.GetMediaTrackInfo_Value(track0, 'IP_TRACKNUMBER')
retval, track0name = reaper.GetSetMediaTrackInfo_String(track0, 'P_NAME', '', false)
item_moban = reaper.GetTrackMediaItem(track0, 0)
take_moban= reaper.GetMediaItemTake(item_moban, 0)

idx=0
tb_drums={} 
tb_drums[0]="A"
tb_drums[1]="A"
tb_drums[2]="A"
tb_drums[8]="A"
tb_drums[9]="E"
tb_drums[10]="E"
tb_drums[11]="E"
tb_drums[16]="A"
tb_drums[24]="E"
tb_drums[25]="E"
tb_drums[26]="E"
tb_drums[27]="E"
tb_drums[28]="E"
tb_drums[29]="E"
tb_drums[30]="E"
tb_drums[32]="J"
tb_drums[40]="BR"
while retval==true do
retval, selected, muted, startpos, chanmsg, chan, msg1, msg2 = reaper.MIDI_GetCC(take_moban, idx)
if chanmsg==192 then 
if tb_drums[msg1]==nil then 
drums='n' reaper.ShowMessageBox('非标准鼓组排列！', '错误！',0) 
reaper.SN_FocusMIDIEditor() return else drums=tb_drums[msg1] end
end
idx=idx+1
end 
 if drums=='E' then tb_kit[97]='TECHNO HIT' end
 if drums=='E' then tb_kit[98]='PHILLY HIT' end
 if drums=='E' then tb_kit[99]='SHOCK WAVE' end
 if drums=='E' then tb_kit[100]='LO-FI RAVE' end
 if drums=='E' then tb_kit[101]='BAM HIT' end
 if drums=='E' then tb_kit[102]='BIM HIT' end
 if drums=='E' then tb_kit[103]='TAPE REWIND' end
 if drums=='E' then tb_kit[104]='PHONO NOISE' end
 if drums=='E' then tb_kit[126]='VOICE TAH' end
 if drums=='E' then tb_kit[127]='SLAPPY' end
 if drums=='J' or drums=='BR' then tb_kit[100]='BRUSH TAP' end
 if drums=='J' or drums=='BR' then tb_kit[101]='BRUSH TAP' end
 if drums=='J' or drums=='BR' then tb_kit[102]='BRUSH SLAP' end
 if drums=='J' or drums=='BR' then tb_kit[103]='BRUSH SLAP' end
 if drums=='J' or drums=='BR' then tb_kit[104]='BRUSH SLAP' end
 if drums=='J' or drums=='BR' then tb_kit[105]='BRUSH SWIRL' end
 if drums=='J' or drums=='BR' then tb_kit[106]='BRUSH SWIRL' end
 if drums=='J' or drums=='BR' then tb_kit[107]='BRUSH SWIRL' end
 if drums=='BR' then tb_kit[38]='BRUSH TAP' end
 if drums=='BR' then tb_kit[39]='BRUSH SLAP' end
 if drums=='BR' then tb_kit[40]='BRUSH SWIRL' end


track1=reaper.GetTrack(0,0)

tb_track={}
reaper.MIDI_DisableSort(take)
retal,notecnt,cccnt,evtcnt=reaper.MIDI_CountEvts(take)
tb={}
tbkey={} tbkey2={} tb_pitch={}
idx=0
 while idx<notecnt do
 retval, selected, muted, startpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, idx)
 reaper.MIDI_SetNote(take,idx,true,false,NULL,NULL,NULL,NULL,NULL,false)
 table.insert(tb,startpos..','..endppqpos..','..chan..','..pitch..','..vel)
 table.insert(tbkey,tb_kit[pitch])
 table.insert(tb_pitch,pitch)
 idx=idx+1
 end
 reaper.MIDI_Sort(take)
 reaper.MIDIEditor_OnCommand(editor,40002) --delete all note
 i=1
while tbkey[i]~=nil do tbkey2[i]=tbkey[i] i=i+1 end
 table.sort(tbkey2)
 tbkey3={} 
 i=1
 tempkey=-1
 while i<=#tbkey2 do
 if tbkey2[i]~=tempkey then  table.insert(tbkey3,tbkey2[i]) tempkey=tbkey2[i]
 end
 i=i+1
 end
 flag=0
 for i, v in ipairs(tbkey3) do
 reaper.InsertTrackAtIndex(number0,false)
 track_new=reaper.GetTrack(0, number0)
 reaper.SetMediaTrackInfo_Value(track_new,'I_MIDIHWOUT',track0_midiport)
 if fold<0 and flag==0 then
 reaper.SetMediaTrackInfo_Value(track0, 'I_FOLDERDEPTH', 0)
 reaper.SetMediaTrackInfo_Value(track_new, 'I_FOLDERDEPTH', fold)
 flag=1
 end
 reaper.CreateTrackSend(track1, track_new)
 reaper.SetTrackSendInfo_Value(track_new, -1, 0, 'B_MUTE', 1)
 retval, trackname = reaper.GetSetMediaTrackInfo_String(track_new, 'P_NAME', track0name..' '..v, true)
 item_new=reaper.CreateNewMIDIItemInProj(track_new, st, st+lenth, false)
 take_new= reaper.GetMediaItemTake(item_new, 0)
 item_new2=reaper.CreateNewMIDIItemInProj(track_new, 0, 0.05, false)
 take_new2= reaper.GetMediaItemTake(item_new2, 0)
 reaper.MIDI_InsertEvt(take_new2,false,false,0,string.char(0xFF,0x21,0x01,0x00))
 reaper.MIDI_DisableSort(take_new)
 
 if v=='KICK_0' then
 for ii, vv in ipairs(tb_pitch) do 
 if vv==0 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_1' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==1 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_2' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==2  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_3' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==3  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_4' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==4  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_5' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==5  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_6' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==6  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_7' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==7 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_8' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==8   then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_9' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==9 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_10' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==10  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_11' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==11  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_12' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==12 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_13' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==13  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_14' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==14 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_15' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==15 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_16' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==16 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='VOX' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==17 or vv==18 or vv==19 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='20' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==20  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='21' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==21  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 

 
 if v=='MC-500 BEEP' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==22 or vv==23 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='SD' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==24  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='SD ROLL' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==25  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='FINGER SNAP' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==26  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='HIGH Q' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==27  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='SLAP' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==28  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='SCRATCH' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==29 or vv==30 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 

 
 if v=='STICK' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==31  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='CLICK' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==32  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='METRONOME' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==33 or vv==34  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_35' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==35  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='KICK_36' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==36  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='SN_38' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==38  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 if v=='SN_40' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==40  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 

 if v=='CYM' then
 take_cym=take_new
 for ii, vv in ipairs(tb_pitch) do
 if vv==49 or vv==52 or vv==55 or vv==57 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- cym end

 if v=='HI HAT' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==42 or vv==44 or vv==46 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- HIHAT end

 if v=='RIDE' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==51 or vv==53 or vv==59 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- RIDE end

  if v=='TOM' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==41 or vv==43 or vv==45 or vv==47 or vv==48 or vv==50 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- TOM end

   if v=='CONGA' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==62 or vv==63 or vv==64  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- CONGA end

    if v=='BONGO' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==60 or vv==61 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- BONGO end

    if v=='TIMBALE' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==65 or vv==66 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- TIMBALE end

	if v=='AGOGO' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==67 or vv==68 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- AGOGO end

	if v=='WHISTLE' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==71 or vv==72 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- WHISTLE end

	if v=='GUIRO' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==73 or vv==74 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- GUIRO end


	if v=='WOODBLOCK' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==76 or vv==77 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- WOODBLOCK end


	if v=='CUICA' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==78 or vv==79 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- CUICA end


	if v=='TRIANGLE' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==80 or vv==81  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- TRIANGLE end
 
	if v=='SURDO' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==86 or vv==87 then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- SURDO end
 
	if v=='STICK' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==37  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- STICK end
 
	if v=='CLAP' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==39  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- CLAP end
 
	if v=='TAMB' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==54  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- TAMB end
 
	if v=='COWBELL' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==56  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- COWBELL end
 
	if v=='VIBRASLAP' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==58  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- VIBRASLAP end
 
	if v=='CABASA' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==69  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- CABASA end
 
	if v=='MARACA' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==70  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- MARACA end
 
	if v=='CLAVES' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==75  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- CLAVES end
 
	if v=='SHAKER' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==82  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- SHAKER end
 
	if v=='JUNGLE BELL' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==83  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- JUNGLE BELL end
 
	if v=='BELL TREE' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==84  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- BELL TREE end
 
	if v=='CASTANETS' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==85  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- CASTANETS end
 
	if v=='APPLAUS' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==88  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end -- APPLAUS end
 
	if v=='89' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==89  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 
	if v=='90' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==90  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='91' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==91  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='92' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==92  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='93' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==93  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='94' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==94  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='95' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==95  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='96' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==96  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_97' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==97  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_98' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==98  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 
	if v=='SN_99' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==99  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_100' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==100  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_101' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==101  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_102' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==102  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_103' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==103  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
  
	if v=='SN_104' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==104  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_105' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==105  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_106' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==106  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_107' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==107  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_108' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==108  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_109' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==109  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 

	if v=='SN_110' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==110  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_111' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==111  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_112' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==112  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_113' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==113  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_114' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==114  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_115' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==115  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_116' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==116  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_117' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==117  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_118' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==118  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_119' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==119  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_120' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==120  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_121' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==121  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_122' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==122  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_123' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==123  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_124' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==124  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_125' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==125  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_126' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==126  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SN_127' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==127  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='TECHNO HIT' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==97  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='PHILLY HIT' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==98  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end  
 
	if v=='SHOCK WAVE' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==99  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='LO-FI RAVE' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==100  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='BAM HIT' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==101  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='BIM HIT' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==102  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='TAPE REWIND' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==103  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='PHONO NOISE' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==104  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='VOICE TAH' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==126  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='SLAPPY' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==127  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
	if v=='BRUSH TAP' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==38 or vv==100 or vv==101  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 
	if v=='BRUSH SLAP' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==39 or vv==102 or vv==103 or vv==104  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
 
 
	if v=='BRUSH SWIRL' then
 for ii, vv in ipairs(tb_pitch) do
 if vv==40 or vv==105 or vv==106 or vv==107  then
 startppqpos,endppqpos,chan,pitch,vel=string.match(tb[ii],'(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
 startppqpos=tonumber(startppqpos) endppqpos=tonumber(endppqpos) chan=tonumber(chan) pitch=tonumber(pitch) vel=tonumber(vel)
 reaper.MIDI_InsertNote(take_new, false,false, startppqpos, endppqpos, chan, pitch, vel, false)
 end end
 end 
  
 
 reaper.MIDI_Sort(take_new)
 end --tbkey3 end
 
 --------------------------------------------------------------------------
 if take_cym~=nil then
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

 
 track_cym=reaper.GetMediaItemTake_Track(take_cym)
 track_cym_midiport=reaper.GetMediaTrackInfo_Value(track_cym, 'I_MIDIHWOUT')
 fold_cym = reaper.GetMediaTrackInfo_Value(track_cym, 'I_FOLDERDEPTH')
 item_cym= reaper.GetMediaItemTake_Item(take_cym)
 st_cym = reaper.GetMediaItemInfo_Value(item_cym, 'D_POSITION')
 lenth_cym = reaper.GetMediaItemInfo_Value(item_cym, 'D_LENGTH')
 number_cym=reaper.GetMediaTrackInfo_Value(track_cym, 'IP_TRACKNUMBER')
 retval, track_cym_name = reaper.GetSetMediaTrackInfo_String(track_cym, 'P_NAME', '', false)
 track1=reaper.GetTrack(0,0)
 
 
 if #cym_49_n>0 or #cym_52_n>0 or #cym_55_n>0 or #cym_57_n>0 then
  reaper.InsertTrackAtIndex(number_cym,false)
  track_roll=reaper.GetTrack(0, number_cym)
  reaper.SetMediaTrackInfo_Value(track_roll,'I_MIDIHWOUT',track_cym_midiport)
  if fold_cym<0 then
  reaper.SetMediaTrackInfo_Value(track_cym, 'I_FOLDERDEPTH', 0)
  reaper.SetMediaTrackInfo_Value(track_roll, 'I_FOLDERDEPTH', fold_cym)
  end
  reaper.CreateTrackSend(track1, track_roll)
  reaper.SetTrackSendInfo_Value(track_roll, -1, 0, 'B_MUTE', 1)
  retval, trackname = reaper.GetSetMediaTrackInfo_String(track_roll, 'P_NAME', track_cym_name..' ROLL', true)
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
 retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take_cym)
 if notecnt==0 then reaper.DeleteTrack(track_cym) end
 end --take_roll~=nil
 end --take_cym=nil
 
reaper.UpdateArrange()
reaper.MIDIEditor_OnCommand(editor,40818) 
reaper.MIDIEditor_OnCommand(editor,40818)

reaper.Undo_EndBlock('',0)


