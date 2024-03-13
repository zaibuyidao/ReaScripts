-- NoIndex: true
function inset_patch(bank, note, velocity, chan) -- 插入音色
  local chan = chan - 1
  reaper.PreventUIRefresh(1)
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take or not reaper.TakeIsMIDI(take) then return end

  local currentTrack = reaper.GetMediaItemTake_Track(take)
  if currentTrack ~= initialTrack then return end
  local item = reaper.GetMediaItemTake_Item(take)
  local cur_pos = reaper.GetCursorPositionEx()
  local ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, cur_pos)
  local count, index = 0, {}
  local value = reaper.MIDI_EnumSelNotes(take, -1)
  while value ~= -1 do
    count = count + 1
    index[count] = value
    value = reaper.MIDI_EnumSelNotes(take, value)
  end

  if #index > 0 then
    for i = 1, #index do
      retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, index[i])
      if selected == true then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, chan, 0, bank)
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, chan, 32, velocity)
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xC0, chan, note, 0)
      end
    end
  else
    local selected = true
    local muted = false
    reaper.MIDI_InsertCC(take, selected, muted, ppq_pos, 0xB0, chan, 0, bank)
    reaper.MIDI_InsertCC(take, selected, muted, ppq_pos, 0xB0, chan, 32, velocity)
    reaper.MIDI_InsertCC(take, selected, muted, ppq_pos, 0xC0, chan, note, 0)
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  if (reaper.SN_FocusMIDIEditor) then reaper.SN_FocusMIDIEditor() end
end

function slideF10() -- 选中事件向左移动 10 ticks
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take or not reaper.TakeIsMIDI(take) then return end
  _, notes, ccs, _ = reaper.MIDI_CountEvts(take)
  reaper.MIDI_DisableSort(take)
  for i = 0,  ccs - 1 do
      local retval, sel, muted, cc_ppq, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
      if sel == true then
          if chanmsg == 176 then -- and (msg2 == 0 or msg2 == 32) 
              reaper.MIDI_SetCC(take, i, sel, muted, cc_ppq-10, nil, nil, nil, nil, false)
          end
          if chanmsg == 192 then
              reaper.MIDI_SetCC(take, i, sel, muted, cc_ppq-10, nil, nil, nil, nil, false)
          end
      end
      i = i + 1
  end
  for i = 0,  notes - 1 do
      local retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
      if sel == true then
          reaper.MIDI_SetNote(take, i, sel, muted, ppq_start-10, ppq_end-10, nil, nil, nil, false)
      end
      i = i + 1
  end
  reaper.MIDI_Sort(take)
end

function slideZ10() -- 选中事件向右移动 10 ticks
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take or not reaper.TakeIsMIDI(take) then return end
  _, notes, ccs, _ = reaper.MIDI_CountEvts(take)
  reaper.MIDI_DisableSort(take)
  for i = 0,  ccs - 1 do
      local retval, sel, muted, cc_ppq, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
      if sel == true then
          if chanmsg == 176 then -- and (msg2 == 0 or msg2 == 32)
              reaper.MIDI_SetCC(take, i, sel, muted, cc_ppq+10, nil, nil, nil, nil, false)
          end
          if chanmsg == 192 then
              reaper.MIDI_SetCC(take, i, sel, muted, cc_ppq+10, nil, nil, nil, nil, false)
          end
      end
      i = i + 1
  end
  for i = 0,  notes - 1 do
      local retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
      if sel == true then
          reaper.MIDI_SetNote(take, i, sel, muted, ppq_start+10, ppq_end+10, nil, nil, nil, false)
      end
      i = i + 1
  end
  reaper.MIDI_Sort(take)
end

function ToggleNotePC()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take or not reaper.TakeIsMIDI(take) then return end
  local miditick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)

  local note_cnt, note_idx, sustainnote, shortnote, preoffset = 0, {}, miditick/2, miditick/8, 2
  local note_val = reaper.MIDI_EnumSelNotes(take, -1)
  while note_val ~= -1 do
      note_cnt = note_cnt + 1
      note_idx[note_cnt] = note_val
      note_val = reaper.MIDI_EnumSelNotes(take, note_val)
  end
  
  local ccs_cnt, ccs_idx = 0, {}
  local ccs_val = reaper.MIDI_EnumSelCC(take, -1)
  while ccs_val ~= -1 do
      ccs_cnt = ccs_cnt + 1
      ccs_idx[ccs_cnt] = ccs_val
      ccs_val = reaper.MIDI_EnumSelCC(take, ccs_val)
  end

  if note_cnt == 0 and ccs_cnt == 0 then
      return
      -- reaper.MB("PC or Note event must be selected\n必須選擇PC或音符事件", "Error", 0),
      reaper.SN_FocusMIDIEditor()
  end

  -- 音符转PC
  local function NoteToPC()
      local MSB, LSB = {}
      
      local midi_ok, midi_string = reaper.MIDI_GetAllEvts(take, "")
      local string_pos, ticks, table_events, offset, flags, msg = 1, 0, {}
      local pack, unpack = string.pack, string.unpack
      while string_pos < #midi_string do
          offset, flags, msg, string_pos = unpack("i4Bs4", midi_string, string_pos)
          if flags&1 ==1 and #msg >= 3 and msg:byte(1)>>4 == 8 and msg:byte(3) ~= -1 then
              MSB[#MSB+1] = msg:byte(3)
          end
      end
  
      reaper.PreventUIRefresh(1)
      reaper.MIDI_DisableSort(take)
  
      local index, tempStart, integer = -1, 0, 0
      local noteData = {}
      integer = reaper.MIDI_EnumSelNotes(take, index)
  
      while (integer ~= -1) do
          integer = reaper.MIDI_EnumSelNotes(take, index)
  
          local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)
  
          if startppqpos == tempStart then
              table.insert(noteData, {index = integer, start = startppqpos, endPos = endppqpos, channel = chan, pitch = pitch, velocity = vel})
          else
              if #noteData > 0 then
                  -- STRUM it
                  local lowestNote = noteData[1].pitch
                  for _, note in ipairs(noteData) do
                      lowestNote = math.min(lowestNote, note.pitch)
                  end
              
                  table.sort(noteData, function(a, b) return a.pitch < b.pitch end)
              
                  for i, note in ipairs(noteData) do
                      local offset = (i - 1) * -1
                      reaper.MIDI_SetNote(take, note.index, true, false, note.start + offset, note.endPos, nil, nil, nil, false)
                  end
              end
              
              noteData = {}
              table.insert(noteData, {index = integer, start = startppqpos, endPos = endppqpos, channel = chan, pitch = pitch, velocity = vel})
              tempStart = startppqpos
          end
  
          index = integer
      end
  
      for i = 1, #note_idx do
          local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, note_idx[i])
          if selected == true then
              local LSB = vel
              reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, 0, MSB[1])
              reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, 32, LSB)
              reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xC0, chan, pitch, 0)
  
              if endppqpos - startppqpos > sustainnote then -- 如果音符长度大于半拍，那么插入CC119
                  reaper.MIDI_InsertCC(take, true, muted, startppqpos - 10, 0xB0, chan, gmem_cc_num, 127) -- 插入CC需提前于PC 默认10tick
                  reaper.MIDI_InsertCC(take, true, muted, endppqpos, 0xB0, chan, gmem_cc_num, 0)
              end
          end
      end
  
      local i = reaper.MIDI_EnumSelNotes(take, -1)
      while i > -1 do
          reaper.MIDI_DeleteNote(take, i)
          i = reaper.MIDI_EnumSelNotes(take, -1)
      end
  
      reaper.MIDI_Sort(take)
      reaper.PreventUIRefresh(-1)
  end
  
  -- PC转音符
  local function PCToNote()
      local bank_msb = {}
  
      reaper.PreventUIRefresh(1)
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
      reaper.PreventUIRefresh(-1)
  end

  if #note_idx > 0 and #ccs_idx == 0 then
      NoteToPC()
  elseif #ccs_idx > 0 and #note_idx ==0 then
      PCToNote()
  end
  reaper.UpdateArrange()
end

function set_group_velocity()
  reaper.PreventUIRefresh(1)
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take or not reaper.TakeIsMIDI(take) then return end
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelCC(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelCC(take, val)
  end

  if cnt == 0 then
      return
      reaper.MB(setpc_msg, setpc_err, 0),
      reaper.SN_FocusMIDIEditor()
  end

  local bank_msb, note_vel, note_pitch = {}, {}, {}

  for i = 1, #index do
      local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, index[i])
      if chanmsg == 176 and msg2 == 0 then -- GET BANK NUM
          bank_msb_num = msg3
          bank_msb[#bank_msb+1] = bank_msb_num
      end
      if chanmsg == 176 and msg2 == 32 then -- CC#32
          note_vel_num = msg3
          note_vel[#note_vel+1] = note_vel_num
      end
      if chanmsg == 192 then -- Program Change
          note_pitch_num = msg2
          note_pitch[#note_pitch+1] = note_pitch_num
      end
  end

  if bank_msb[1] == nil or note_vel[1] == nil then return reaper.SN_FocusMIDIEditor() end
  local user_ok, input_csv = reaper.GetUserInputs(setpc_title, 3, setpc_retvals_csv, bank_msb[1] ..','.. note_vel[1] ..','.. note_pitch[1])
  local MSB, LSB, NOTE_P = input_csv:match("(.*),(.*),(.*)")

  reaper.MIDI_DisableSort(take)
  for i = 1, #index do
      local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, index[i])
      if LSB == "" and MSB == "" and NOTE_P == "" then return reaper.SN_FocusMIDIEditor() end

      if chanmsg == 176 and msg2 == 0 then -- CC#0
          if MSB ~= "" then
              reaper.MIDI_SetCC(take, index[i], nil, nil, nil, nil, nil, nil, MSB, false)
          end
      end
      if chanmsg == 176 and msg2 == 32 then -- CC#32
          if LSB ~= "" then
              reaper.MIDI_SetCC(take, index[i], nil, nil, nil, nil, nil, nil, LSB, false)
          end
      end
      if chanmsg == 192 then -- Program Change
          if NOTE_P ~= "" then
              reaper.MIDI_SetCC(take, index[i], nil, nil, nil, nil, nil, NOTE_P, nil, false)
          end
      end
  end
  reaper.MIDI_Sort(take)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.SN_FocusMIDIEditor()
end

function add_or_toggle_articulation_map_jsfx()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take or not reaper.TakeIsMIDI(take) then return end

  local track = reaper.GetMediaItemTake_Track(take)
  local fxIndex = reaper.TrackFX_GetByName(track, "Articulation Map", false)

  if fxIndex < 0 then
      -- 如果插件不存在，则添加它到顶部
      fxIndex = reaper.TrackFX_AddByName(track, "Articulation Map", false, -1000)
  end

  -- 检查浮动窗口是否打开
  local isFloating = reaper.TrackFX_GetFloatingWindow(track, fxIndex) ~= nil
  if isFloating then
      -- 如果浮动窗口打开，则关闭它
      reaper.TrackFX_Show(track, fxIndex, 2)
  else
      -- 如果浮动窗口关闭，则打开它
      reaper.TrackFX_Show(track, fxIndex, 3)
  end
end