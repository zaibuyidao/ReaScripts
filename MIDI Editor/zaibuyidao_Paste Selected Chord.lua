--[[
 * ReaScript Name: Paste Selected Chord
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-2-28)
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
function table.unserialize(lua) --将字符串反序列化为table
  local t = type(lua)
  if t == "nil" or lua == "" then
      return nil
  elseif t == "number" or t == "string" or t == "boolean" then
      lua = tostring(lua)
  else
      error("can not unserialize a " .. t .. " type.")
  end
  lua = "return " .. lua
  local func = load(lua)
  if func == nil then
      return nil
  end
  return func()
end
function countEvts() --获取选中音符数量
    local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
    return notecnt
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
function getSelIndexs() --获取全部被选中音符的索引值
    local sel=-1
    local ret={}
    repeat
        sel = reaper.MIDI_EnumSelNotes(take, sel)
        if sel~=-1 then
          local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, sel)
          table.insert(ret,sel)
        end
    until sel == -1
    return ret
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
function deleteSelNote() --删除选中音符
  reaper.MIDIEditor_OnCommand(midiEditor, 40002)
end
function insertNote(note) --插入音符
  reaper.MIDI_InsertNote(take, note.selected, note.muted, note.startPos, note.endPos,note.channel,note.pitch, note.vel, true)
end
function getPPQStartOfMeasure(note) --获取音符所在小节起始位置
  if type(note)=="number" then return reaper.MIDI_GetPPQPos_StartOfMeasure(take, note) end
  return reaper.MIDI_GetPPQPos_StartOfMeasure(take, note.startPos)
end
function saveData(key1,key2,data) --储存table数据
  reaper.SetExtState(key1, key2, data, false)
end
function getSavedData(key1,key2) --获取已储存的table数据
  return table.unserialize(reaper.GetExtState(key1, key2))
end
function main()
  local pasteInfos=getSavedData("CopySelectedChord","data")
  local selPitchInfo={}
  local tempStartMeasure=0
  for note in selNoteIterator() do
    tempStartMeasure=getPPQStartOfMeasure(note)
    if selPitchInfo[tempStartMeasure]==nil then selPitchInfo[tempStartMeasure]={} end
    table.insert(selPitchInfo[tempStartMeasure],note.pitch)
  end
  deleteSelNote()
  for startMeasure,pitchs in pairs(selPitchInfo) do
    table.sort(pitchs)
    for i,pitch in ipairs(pitchs) do
      if i>pasteInfos.lineNum then break end
      local notes=pasteInfos[i]
      for j,note in ipairs(notes) do
        note.pitch=pitch
        note.startPos=note.startPos+startMeasure
        note.endPos=note.endPos+startMeasure
        insertNote(note)
        note.startPos=note.startPos-startMeasure
        note.endPos=note.endPos-startMeasure
      end
    end
  end
end

script_title = "Paste Selected Chord"
reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
main()
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock(script_title, 0)
reaper.UpdateArrange()