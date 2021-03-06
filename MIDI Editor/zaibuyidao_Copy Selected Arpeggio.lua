--[[
 * ReaScript Name: Copy Selected Arpeggio
 * Version: 1.2.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-3-6)
  + Initial release
--]]

midiEditor=reaper.MIDIEditor_GetActive()
take = reaper.MIDIEditor_GetTake(midiEditor) --全局take值
if not take or not reaper.TakeIsMIDI(take) then return end
function table.serialize(obj) --将table序列化为字符串
  local lua = ""
  local t = type(obj)
  if t == "number" then
      lua = lua .. obj
  elseif t == "boolean" then
      lua = lua .. tostring(obj)
  elseif t == "string" then
      lua = lua .. string.format("%q", obj)
  elseif t == "table" then
      lua = lua .. "{\n"
  for k, v in pairs(obj) do
      lua = lua .. "[" .. table.serialize(k) .. "]=" .. table.serialize(v) .. ",\n"
  end
  local metatable = getmetatable(obj)
      if metatable ~= nil and type(metatable.__index) == "table" then
      for k, v in pairs(metatable.__index) do
          lua = lua .. "[" .. table.serialize(k) .. "]=" .. table.serialize(v) .. ",\n"
      end
  end
      lua = lua .. "}"
  elseif t == "nil" then
      return nil
  else
      error("can not serialize a " .. t .. " type.")
  end
  return lua
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
function selNoteIterator() --迭代器 用于返回选中的每一个音符信息表
    local sel=-1
    return function()
        sel=reaper.MIDI_EnumSelNotes(take, sel)
        if sel==-1 then return end
        return getNote(sel)
    end
end
function getPPQStartOfMeasure(note) --获取音符所在小节起始位置
  if type(note)=="number" then return reaper.MIDI_GetPPQPos_StartOfMeasure(take, note) end
  return reaper.MIDI_GetPPQPos_StartOfMeasure(take, note.startPos)
end
function saveData(key1,key2,data) --储存table数据
  reaper.SetExtState(key1, key2, data, false)
end
function main()
  reaper.Undo_BeginBlock()
  reaper.MIDI_DisableSort(take)
  local notes={}
  local startMeasure,tempMeasure=-1,0
  local pitchsFlag={}
  for note in selNoteIterator() do
      table.insert(notes,note)
      tempMeasure=getPPQStartOfMeasure(note)
      if startMeasure<startMeasure or startMeasure<0 then startMeasure=tempMeasure end
      pitchsFlag[note.pitch]=1
  end
  local tempIndex,pitchIndex,lineNum={},{},0
  for pitch in pairs(pitchsFlag) do
    table.insert(tempIndex,pitch)
    lineNum=lineNum+1
  end
  table.sort(tempIndex)
  for index,value in ipairs(tempIndex) do
    pitchIndex[value]=index
  end
  local outData,insertIndex={},0
  for _,note in pairs(notes) do
    insertIndex=pitchIndex[note.pitch]
    if outData[insertIndex] == nil then outData[insertIndex]={} end
    note.startPos=note.startPos-startMeasure
    note.endPos=note.endPos-startMeasure
    note.pitch=nil
    note.sel=nil
    table.insert(outData[insertIndex],note)
  end
  outData.lineNum=lineNum
  saveData("CopySelectedArpeggio","data",table.serialize(outData))
  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock("Copy Selected Arpeggio", -1)
end

main()
reaper.UpdateArrange()