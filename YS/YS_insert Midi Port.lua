--[[
 * ReaScript Name: insert Midi Port
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

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

bl,input=reaper.GetUserInputs('Insert Midi Port',1,'Port Num : 1-16','1')
if bl==false then return end 
input=(tonumber(input))-1
if input<0 or input>15 then reaper.MB('请输入1-16之间的数值！','错误！',0)  return end
item=reaper.GetSelectedMediaItem(0,0)
idx=0
while item~=nil do
item=reaper.GetSelectedMediaItem(0,idx)
take=reaper.GetMediaItemTake(item,0)
reaper.MIDI_InsertEvt(take,false,false,0,tb2[input])
idx=idx+1
item=reaper.GetSelectedMediaItem(0,idx)
end -- while end

