--[[
 * ReaScript Name: Track send from Name
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

retval,first= reaper.GetUserInputs('按轨道名分配port到设备',1,'输入起始的MIDI 设备port 数','1') 
first_sub=tonumber(first)
port = first_sub - 1
port_a = port * 32
port_b = ( port + 1 ) * 32
txt = ''
name = {} 
msg2=''
name['G15-GuideMelo']=-1
name['Gs Reset']=port_a
name['Sys.A']=port_a  name['VSC-1']=port_a
name['Sys.B']=port_b  name['VSC-2']=port_b
name['SYSTEM_EXCLUSIVE_A']=port_a
name['SYSTEM_EXCLUSIVE_B']=port_b
name['VSC-1(TAB)']=port_a
name['VSC-2(OTHER)']=port_b
name['Sub Sys.B Part']=port_b
name['Vol.AB']=port_a
name['PART  A']=-1
name['*****A DR****']=-1
name['*****B DR****']=-1
name['PART  B']=-1
name['....................']=-1
name['A01  Sys Ex & Tempo']=port_a
name['A01']=port_a+1 name['1-1-']=port_a+1
name['A02']=port_a+2 name['1-2-']=port_a+2
name['A03']=port_a+3 name['1-3-']=port_a+3 
name['A04']=port_a+4 name['1-4-']=port_a+4
name['A05']=port_a+5 name['1-5-']=port_a+5
name['A06']=port_a+6 name['1-6-']=port_a+6
name['A07']=port_a+7 name['1-7-']=port_a+7
name['A08']=port_a+8 name['1-8-']=port_a+8
name['A09']=port_a+9 name['1-9-']=port_a+9
name['A10']=port_a+10 name['1-10-']=port_a+10
name['A11']=port_a+11 name['1-11-']=port_a+11
name['A12']=port_a+12 name['1-12-']=port_a+12
name['A13']=port_a+13 name['1-13-']=port_a+13
name['A14']=port_a+14 name['1-14-']=port_a+14
name['A15']=port_a+15 name['1-15-']=port_a+15
name['A16']=port_a+16 name['1-16-']=port_a+16
name['B01']=port_b+1 name['2-1-']=port_b+1
name['B02']=port_b+2 name['2-2-']=port_b+2
name['B03']=port_b+3 name['2-3-']=port_b+3
name['B04']=port_b+4 name['2-4-']=port_b+4
name['B05']=port_b+5 name['2-5-']=port_b+5
name['B06']=port_b+6 name['2-6-']=port_b+6
name['B07']=port_b+7 name['2-7-']=port_b+7
name['B08']=port_b+8 name['2-8-']=port_b+8
name['B09']=port_b+9 name['2-9-']=port_b+9
name['B10']=port_b+10 name['2-10-']=port_b+10
name['B11']=port_b+11 name['2-11-']=port_b+11
name['B12']=port_b+12 name['2-12-']=port_b+12
name['B13']=port_b+13 name['2-13-']=port_b+13
name['B14']=port_b+14 name['2-14-']=port_b+14
name['B15']=port_b+15 name['2-15-']=port_b+15
name['B16']=port_b+16 name['2-16-']=port_b+16
integer = reaper.CountMediaItems(0) 
 idx = 0
while idx < integer do
 MediaItem = reaper.GetMediaItem(0, idx)
 idx=idx+1
 take = reaper.GetTake(MediaItem, 0)
retval, selected, muted, ppqpos, type_1, msg = reaper.MIDI_GetTextSysexEvt(take, 0, NULL, NULL, NULL, 3, '')
   if type_1 == 3 then
   track  = reaper.GetMediaItem_Track(MediaItem)
   reaper.GetSetMediaTrackInfo_String(track,'P_NAME',msg, true)
   reaper.MIDI_DeleteTextSysexEvt(take, 0)
   ------------
   reaper.MIDI_DisableSort(take)
    i=1
    ccidx=0
    PC = {}
   repeat
       retval,selected,muted,ppqpos, chanmsg, chan, num, val = reaper.MIDI_GetCC(take, ccidx)
     if chanmsg==192  then
      PC[i]=ppqpos
      i = i+1
      end 
    ccidx = ccidx + 1
   until retval == false
   -- get pc 
   
    i=1
    ccidx=0
   repeat
       retval,selected,muted,ppqpos, chanmsg, chan, num, val = reaper.MIDI_GetCC(take, ccidx)
     if chanmsg==176 then
     if num == 0 or num==32 then
      for i, v in ipairs(PC) do
          if (v - ppqpos ) <= 2 then 
          reaper.MIDI_SetCC(take, ccidx, NULL, NULL, PC[i], NULL, NULL, NULL, NULL, false)
          end
          end
      end  
      end 
    ccidx = ccidx + 1
   until retval == false
   
   reaper.MIDI_Sort(take)
   -------------------------  move CC0 CC32
   
   if string.match(msg,'%.%.%.%.%.%.%.%.%.%.%.%.%.%.%.%.%.%.%.%.+')~=nil then msg='....................' end
   if name[msg] == nil then
   if string.match(msg, 'A%d+')~=nil then  msg =string.match(msg, 'A%d+') end
   if string.match(msg, 'B%d+')~=nil then  msg =string.match(msg, 'B%d+') end
   if string.match(msg, '1%-%d+%-')~=nil then  msg =string.match(msg, '1%-%d+%-') end
   if string.match(msg, '2%-%d+%-')~=nil then  msg =string.match(msg, '2%-%d+%-') end
   end
   if name[msg] ~= nil then
  reaper.SetMediaTrackInfo_Value(track, 'I_MIDIHWOUT', name[msg])
  else 
  txt = txt .. msg ..' 无法识别，没有设置任何MIDI端口！ \n'
  end
 end -- if end
end -- while end

reaper.ClearConsole()
reaper.ShowConsoleMsg(txt)
