--[[
 * ReaScript Name: MIDI硬件输出设置
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

path= reaper.GetExePath() txt='' tbcheck={}
devid=0 dev='' id='' devtb={}
while devid<6 do
retval, nameout = reaper.GetMIDIOutputName(devid, '')
dev=dev..nameout..',' id=id..devid..','  table.insert(devtb,nameout)
devid=devid+1
end
ret,get=reaper.GetUserInputs('',6,dev,id)
if ret then 
a,b,c,d,e,f=string.match(get,'(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)')
a=tonumber(a) b=tonumber(b) c=tonumber(c) d=tonumber(d) e=tonumber(e) f=tonumber(f)
if (a~=0 and a~=1 and a~=2 and a~=3 and a~=4 and a~=5) then reaper.MB('ID值限定在0-5！','错误！',0) return end
if (b~=0 and b~=1 and b~=2 and b~=3 and b~=4 and b~=5) then reaper.MB('ID值限定在0-5！','错误！',0) return end
if (c~=0 and c~=1 and c~=2 and c~=3 and c~=4 and c~=5) then reaper.MB('ID值限定在0-5！','错误！',0) return end
if (d~=0 and d~=1 and d~=2 and d~=3 and d~=4 and d~=5) then reaper.MB('ID值限定在0-5！','错误！',0) return end
if (e~=0 and e~=1 and e~=2 and e~=3 and e~=4 and e~=5) then reaper.MB('ID值限定在0-5！','错误！',0) return end
if (f~=0 and f~=1 and f~=2 and f~=3 and f~=4 and f~=5) then reaper.MB('ID值限定在0-5！','错误！',0) return end
tbcheck[a]=a tbcheck[b]=b tbcheck[c]=c tbcheck[d]=d tbcheck[e]=e tbcheck[f]=f 
   leng=0
  for k, v in pairs(tbcheck) do
    leng=leng+1
  end
if leng~=6 then  reaper.MB('禁止输入相同的ID！','错误！',0)
return end
keyName='on'..a  value=devtb[1] 
reaper.BR_Win32_WritePrivateProfileString('mididevcache', keyName, value, path..'\\reaper-midihw.ini') txt=txt..keyName..':'..value..'\n'
keyName='on'..b  value=devtb[2]
reaper.BR_Win32_WritePrivateProfileString('mididevcache', keyName, value, path..'\\reaper-midihw.ini') txt=txt..keyName..':'..value..'\n'
keyName='on'..c  value=devtb[3]
reaper.BR_Win32_WritePrivateProfileString('mididevcache', keyName, value, path..'\\reaper-midihw.ini') txt=txt..keyName..':'..value..'\n'
keyName='on'..d  value=devtb[4]
reaper.BR_Win32_WritePrivateProfileString('mididevcache', keyName, value, path..'\\reaper-midihw.ini') txt=txt..keyName..':'..value..'\n'
keyName='on'..e  value=devtb[5]
reaper.BR_Win32_WritePrivateProfileString('mididevcache', keyName, value, path..'\\reaper-midihw.ini') txt=txt..keyName..':'..value..'\n'
keyName='on'..f  value=devtb[6]
reaper.BR_Win32_WritePrivateProfileString('mididevcache', keyName, value, path..'\\reaper-midihw.ini') txt=txt..keyName..':'..value..'\n'

reaper.Main_OnCommand(40004,0)
end

