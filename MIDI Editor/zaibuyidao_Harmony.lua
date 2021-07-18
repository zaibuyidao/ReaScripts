--[[
 * ReaScript Name: Harmony
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-3-10)
  + Initial release
--]]

take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive()) --全局take值
if not take or not reaper.TakeIsMIDI(take) then return end
function table.sortByKey(tab,key,ascend) --对于传入的table按照指定的key值进行排序,ascend参数决定是否为升序,默认为true
    if ascend==nil then ascend=true end
    table.sort(tab,function(a,b)
        if ascend then return a[key]<b[key] end
        return a[key]>b[key]
    end)
end
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
function selNoteIterator() --迭代器 用于返回选中的每一个音符信息表
    local sel=-1
    return function()
        sel=reaper.MIDI_EnumSelNotes(take, sel)
        if sel==-1 then return end
        return getNote(sel)
    end
end
function insertNote(note) --插入音符
  reaper.MIDI_InsertNote(take, note.selected, note.muted, note.startPos, note.endPos,note.channel,note.pitch, note.vel, true)
end
function saveData(key1,key2,data) --储存table数据
  reaper.SetExtState(key1, key2,table.serialize(data), false)
end
function getSavedData(key1,key2) --获取已储存的table数据
  return table.unserialize(reaper.GetExtState(key1, key2))
end
function getMutiInput(title,num,lables,defaults)
    title=title or "Title"
    lables=lables or "Lable:"
    local userOK, get_value = reaper.GetUserInputs(title, num, lables, defaults)
    if userOK then return string.split(get_value,",") end
end
function getOverlayPitchsMajor(baseScale,ordinal,origPitch) --核心计算函数,三个参数分别代表音调（CDEFGAB）,偏移值,原音符音高 ,返回叠加后的音符音高
    if ordinal>8 then ordinal=8 end
    if ordinal<-8 then ordinal=-8 end
    local scales={ --音调表 大调 1234567
        0,2,4,5,7,9,11
    }
    local scalesMap={ --音调表的查询表，可以得到音调在音调表中的位置
        [0]=1,[2]=2,[4]=3,[5]=4,[7]=5,[9]=6,[11]=7
    }
    local pos ={  --上叠要用到的表，可以通过0-11的数字得到一个在音调表中的数字
        [0]=0,[1]=0,[2]=2,[3]=2,[4]=4,[5]=5,[6]=5,[7]=7,[8]=7,[9]=9,[10]=9,[11]=11
    }
    local pos2 ={  --下叠要用到的表，可以通过0-11的数字得到一个在音调表中的数字
        [0]=0,[1]=2,[2]=2,[3]=4,[4]=4,[5]=5,[6]=7,[7]=7,[8]=9,[9]=9,[10]=11,[11]=11
    }
    local tonesMap={ --音调对应的数字
        ["C"]=0, ["C#"]=1, ["D"]=2, ["D#"]=3, ["E"]=4, ["F"]=5, ["F#"]=6, ["G"]=7, ["G#"]=8, ["A"]=9, ["A#"]=10, ["B"]=11

    }

    if not tonesMap[baseScale] then return -1 end

    local tempPitch=origPitch-tonesMap[baseScale]
    local p = tempPitch%12
    local b = tempPitch-p
    local result  --最终结果
    if ordinal>0 then  --判断为上叠
        local tp = scalesMap[pos[p]]+ordinal-1 
        b=b+math.floor((tp-1)/7)*12
        local rp= ((tp-1)%7)+1
        result = b+scales[rp]+tonesMap[baseScale]
    elseif ordinal<0 then  --判断为下叠
        local tp = scalesMap[pos2[p]]+ordinal+1
        local rp=tp
        if tp<=0 then 
            b=b-math.floor(1+(-tp)/7)*12
            rp=(6-((-tp)%7))+1
        end
        result = b+scales[rp]+tonesMap[baseScale]
    else
    end

    if result>=0 and result<=127 then return result end --判断是否越界
    return -1
end
function getOverlayPitchsMinor(baseScale,ordinal,origPitch) --核心计算函数,三个参数分别代表音调（cdefgab）,偏移值,原音符音高 ,返回叠加后的音符音高
    if ordinal>8 then ordinal=8 end
    if ordinal<-8 then ordinal=-8 end
    local scales={ --音调表 小调 6712345
        0,2,3,5,7,8,10
    }
    local scalesMap={ --音调表的查询表，可以得到音调在音调表中的位置
        [0]=1,[2]=2,[3]=3,[5]=4,[7]=5,[8]=6,[10]=7
    }
    local pos ={  --上叠要用到的表，可以通过0-11的数字得到一个在音调表中的数字
        [0]=0,[1]=0,[2]=2,[3]=3,[4]=3,[5]=5,[6]=5,[7]=7,[8]=8,[9]=8,[10]=10,[11]=10
    }
    local pos2 ={  --下叠要用到的表，可以通过0-11的数字得到一个在音调表中的数字
        [0]=0,[1]=2,[2]=2,[3]=3,[4]=5,[5]=5,[6]=7,[7]=7,[8]=8,[9]=8,[10]=10,[11]=10
    }
    local tonesMap={ --音调对应的数字
        ["c"]=0, ["c#"]=1, ["d"]=2, ["d#"]=3, ["e"]=4, ["f"]=5, ["f#"]=6, ["g"]=7, ["g#"]=8, ["a"]=9, ["a#"]=10, ["b"]=11
    }

    if not tonesMap[baseScale] then return -1 end

    local tempPitch=origPitch-tonesMap[baseScale]
    local p = tempPitch%12
    local b = tempPitch-p
    local result  --最终结果
    if ordinal>0 then  --判断为上叠
        local tp = scalesMap[pos[p]]+ordinal-1
        b=b+math.floor((tp-1)/7)*12
        local rp= ((tp-1)%7)+1
        result = b+scales[rp]+tonesMap[baseScale]
    elseif ordinal<0 then  --判断为下叠
        local tp = scalesMap[pos2[p]]+ordinal+1
        local rp=tp
        if tp<=0 then 
            b=b-math.floor(1+(-tp)/7)*12
            rp=(6-((-tp)%7))+1
        end
        result = b+scales[rp]+tonesMap[baseScale]
    else
    end

    if result>=0 and result<=127 then return result end --判断是否越界
    return -1
end
function main()
    --数据的输入和保存
    local inputs=getSavedData("Overlay","inputs")
    if inputs==nil or #inputs<2 then 
        inputs={'C' ,'3'}
    end
    inputs=getMutiInput("Harmony",2,"key,Interval",inputs[1]..","..inputs[2])
    if not inputs then return end
    inputs[2]=tonumber(inputs[2])
    if not inputs[2] then return end
    local savedOffset=tostring(inputs[2])
    if savedOffset=='1' or savedOffset=='0' then savedOffset='2' saveData("Overlay","inputs",{inputs[1],savedOffset}) return end --判断是否输入了1，-1或0
    if savedOffset=='-1' then savedOffset='-2' saveData("Overlay","inputs",{inputs[1],savedOffset}) return end
    saveData("Overlay","inputs",{inputs[1],savedOffset})

    --将已选择音符按照起始位置分组
    local selPitchInfo={}
    for note in selNoteIterator() do
        if selPitchInfo[note.startPos]==nil then selPitchInfo[note.startPos]={} end
        table.insert(selPitchInfo[note.startPos],note)
    end

    local opNote,overlayPitchMajor,overlayPitchMinor --opNote(用来计算叠加音符的音符) overlayPitch(将被叠加音符的音高)

    for startPos,notes in pairs(selPitchInfo) do --遍历每一个分组
        table.sortByKey(notes,"pitch",inputs[2]<0)  --根据上叠或者下叠决定排序顺序
        opNote=notes[1] --取排序后的第一个音符作为计算叠加音符的音符
        overlayPitchMajor=getOverlayPitchsMajor(inputs[1],inputs[2],opNote.pitch) --调用函数计算将要叠加音符的音高
        if overlayPitchMajor>0 then  --插入大调音程，如果计算失败会得到-1，这里判断一下再插入音符
            opNote.pitch=overlayPitchMajor
            insertNote(opNote)
        end
        overlayPitchMinor=getOverlayPitchsMinor(inputs[1],inputs[2],opNote.pitch) --调用函数计算将要叠加音符的音高
        if overlayPitchMinor>0 then  --插入小调音程，如果计算失败会得到-1，这里判断一下再插入音符
            opNote.pitch=overlayPitchMinor
            insertNote(opNote)
        end
    end
end
reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
main()
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("Harmony", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()