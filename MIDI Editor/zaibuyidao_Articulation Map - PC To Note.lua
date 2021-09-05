--[[
 * ReaScript Name: Articulation Map - PC To Note
 * Version: 1.4
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-8-4)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not take or not reaper.TakeIsMIDI(take) then return end

function Msg(param) 
  reaper.ShowConsoleMsg(tostring(param) .. "\n") 
end

print = Msg

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not take or not reaper.TakeIsMIDI(take) then return end

local miditick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local sustainnote, shortnote = miditick/2, miditick/8

reaper.gmem_attach('gmem_articulation_map')
gmem_cc_num = reaper.gmem_read(1)
gmem_cc_num = math.floor(gmem_cc_num)

function print_r ( t )  
  local print_r_cache={}
  local function sub_print_r(t,indent)
      if (print_r_cache[tostring(t)]) then
          print(indent.."*"..tostring(t))
      else
          print_r_cache[tostring(t)]=true
          if (type(t)=="table") then
              for pos,val in pairs(t) do
                  if (type(val)=="table") then
                      print(indent.."["..pos.."] => "..tostring(t).." {")
                      sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                      print(indent..string.rep(" ",string.len(pos)+6).."}")
                  elseif (type(val)=="string") then
                      print(indent.."["..pos..'] => "'..val..'"')
                  else
                      print(indent.."["..pos.."] => "..tostring(val))
                  end
              end
          else
              print(indent..tostring(t))
          end
      end
  end
  if (type(t)=="table") then
      print(tostring(t).." {")
      sub_print_r(t,"  ")
      print("}")
  else
      sub_print_r(t,"  ")
  end
  print()
end

function table.sortByKey(tab,key,ascend)
  if ascend==nil then ascend=true end
  table.sort(tab,function(a,b)
      if ascend then return a[key]<b[key] end
      return a[key]>b[key]
  end)
end
function string.split(szFullString, szSeparator)  
  local nFindStartIndex = 1  
  local nSplitIndex = 1  
  local nSplitArray = {}  
  while true do  
     local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)  
     if not nFindLastIndex then  
      nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))  
      break  
     end  
     nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)  
     nFindStartIndex = nFindLastIndex + string.len(szSeparator)  
     nSplitIndex = nSplitIndex + 1  
  end  
  return nSplitArray  
end
function getNote(sel) --根据传入的sel索引值，返回指定位置的含有音符信息的表
  local retval, selected, muted, startPos, endPos, channel, pitch, vel = reaper.MIDI_GetNote(take, sel)
  return {
      ["retval"]=retval,
      ["selected"]=selected,
      ["muted"]=muted,
      ["startPos"]=startPos,
      ["endPos"]=endPos,
      ["channel"]=channel,
      ["pitch"]=pitch,
      ["vel"]=vel,
      ["sel"]=sel
  }
end
function setNote(note,sel,arg) --传入一个音符信息表已经索引值，对指定索引位置的音符信息进行修改
  reaper.MIDI_SetNote(take,sel,note["selected"],note["muted"],note["startPos"],note["endPos"],note["channel"],note["pitch"],note["vel"],arg or false)
end
function selNoteIterator() --迭代器 用于返回选中的每一个音符信息表
  local sel=-1
  return function()
      sel=reaper.MIDI_EnumSelNotes(take, sel)
      if sel==-1 then return end
      return getNote(sel)
  end
end
function getMutiInput(title,num,lables,defaults)
  title=title or "Title"
  lables=lables or "Lable:"
  local userOK, getValue = reaper.GetUserInputs(title, num, lables, defaults)
  if userOK then return string.split(getValue,",") end
end

local ccs_cnt, ccs_idx = 0, {}
local ccs_val = reaper.MIDI_EnumSelCC(take, -1)
while ccs_val ~= -1 do
    ccs_cnt = ccs_cnt + 1
    ccs_idx[ccs_cnt] = ccs_val
    ccs_val = reaper.MIDI_EnumSelCC(take, ccs_val)
end

local function PCToNote()
  local bank_msb = {}

  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()
  reaper.MIDI_DisableSort(take)

  local notes_store = {}  -- 保存即将被插入的音符
  local cc119s = {}   -- 保存选中的cc119值

  for i = 1, #ccs_idx do
      retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccs_idx[i])
      if chanmsg == 176 and msg2 == 0 then
          bank_msb_num = msg3
          bank_msb[#bank_msb+1] = bank_msb_num
      elseif chanmsg == 176 and msg2 == 32 then
          vel = msg3
          if vel == 0 then vel = 96 end
      elseif chanmsg == 176 and msg2 == gmem_cc_num then -- 延音控制器
          table.insert(cc119s, { ppqpos, msg3 })
      elseif chanmsg == 192 then
          pitch = msg2
          table.insert(notes_store, {
              take, true, muted, ppqpos, ppqpos+shortnote, chan, pitch, vel, false -- 音符长度由PC当前位置+CC119归零值组成
          })
      end
  end

  -- 对cc119进行排序
  table.sort(cc119s, function (a,b)
      return a[1] < b[1]
  end)

  -- 遍历被保存的即将被插入的音符，根据cc119s列表来动态改变音符的结束位置
  for i,note in ipairs(notes_store) do
      -- 遍历cc119列表，查找符合条件的cc119值
      for j, c in ipairs(cc119s) do
          -- 如果当前被遍历的cc119不是最后一个，当前cc119位置等于音符起始位置 且 当前状态为开 且下一个状态为 关
          if j ~= #cc119s and (c[1] <= note[4] and c[1] > note[4]-sustainnote) and c[2] >= 64 and c[2] <=127 and cc119s[j+1][2]>=0 and cc119s[j+1][2]<=63 then -- 原 c[1] >= note[4]-480)
              -- 则当前音符的结束位置为下一个cc119的位置
              note[5] = cc119s[j+1][1]
              break
          end
      end
      reaper.MIDI_InsertNote(table.unpack(note))
  end

  if bank_msb[1] == nil or vel == nil or pitch == nil then return reaper.SN_FocusMIDIEditor() end

  i = reaper.MIDI_EnumSelCC(take, -1)
  while i > -1 do
      reaper.MIDI_DeleteCC(take, i)
      i = reaper.MIDI_EnumSelCC(take, -1)
  end
  
  local midi_ok, midi_string = reaper.MIDI_GetAllEvts(take, "")
  if not midi_ok then reaper.ShowMessageBox("Error loading MIDI", "Error", 0) return end
  local string_pos, ticks, table_events, offset, flags, msg = 1, 0, {}
  local pack, unpack = string.pack, string.unpack
  while string_pos < #midi_string do
      offset, flags, msg, string_pos = unpack("i4Bs4", midi_string, string_pos)
      if flags&1 ==1 and #msg >= 3 and msg:byte(1)>>4 == 8 and msg:byte(3) ~= -1 then
          msg = msg:sub(1,2) .. string.char(msg:byte(3) + bank_msb[1])
      end
      table_events[#table_events+1] = pack("i4Bs4", offset, flags, msg)
  end
  reaper.MIDI_SetAllEvts(take, table.concat(table_events))

  --修复错位
  local decreaseValue=2
  local rangeL=0 --起始范围
  local rangeR=1 --结束范围
  local noteGroups={} --音符组,以第一个插入的音符起始位置作为索引
  local groupData={} --音符组的索引对应的最近一次插入的音符的起始位置，即 最近一次插入的音符起始位置=groupData[音符组索引]
  local flag --用以标记当前音符是否已经插入到音符组中
  local diff --差值
  local lastIndex --上一个插入音符的索引
  for note in selNoteIterator() do
      flag=false
      for index,notes in pairs(noteGroups) do
          diff=math.abs(note.startPos-groupData[index]) --计算差值
          if diff <= rangeR and diff >= rangeL and index==lastIndex then --判断差值是否符合
              table.insert(noteGroups[index],note)
              groupData[index]=note.startPos
              flag=true --如果符合则插入音符组，并标记flag
              break
          end
      end
      if flag then goto continue end --如果flag被标记，那么音符已经插入过，直接处理下一个音符
      noteGroups[note.startPos]={} --以当前音符起始位置作为索引，创建以此为索引的新表，并插入音符到该表中
      groupData[note.startPos]=note.startPos
      lastIndex=note.startPos
      table.insert(noteGroups[note.startPos],note)
      ::continue::
  end
  for index,notes in pairs(noteGroups) do
      if #notes==1 then goto continue end

      if notes[1].startPos==notes[2].startPos then --如果存在起始位置相同的音符，那么则按照音高排序
          table.sortByKey(notes,"pitch",decreaseValue<0)
      else
          table.sortByKey(notes,"startPos",decreaseValue<0) --否则按照起始位置进行排序
      end

      for i=1,#notes do
          notes[i].startPos=notes[1].startPos
          notes[i].endPos=notes[1].endPos
          setNote(notes[i],notes[i].sel) --将改变音高后的note重新设置
      end
      ::continue::
  end

  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock("PC To Note", -1)
  reaper.PreventUIRefresh(-1)
end

PCToNote()
reaper.UpdateArrange()
if (reaper.SN_FocusMIDIEditor) then reaper.SN_FocusMIDIEditor() end
