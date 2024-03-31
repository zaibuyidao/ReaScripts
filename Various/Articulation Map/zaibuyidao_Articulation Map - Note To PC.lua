-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"

require('core')
CONFIG = require('config')
short_note = CONFIG.pc_to_note.short_note
sustain_note = CONFIG.pc_to_note.sustain_note
delimiter = getPathDelimiter()

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not take or not reaper.TakeIsMIDI(take) then return end
local miditick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)

local note_cnt, note_idx, sustainnote, shortnote, preoffset = 0, {}, sustain_note, short_note, 2 -- sustainnote = miditick/2, shortnote = miditick/8
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
local function noteToPC()
    local MSB, LSB = {}, {}
  
    local midi_ok, midi_string = reaper.MIDI_GetAllEvts(take, "")
    local string_pos, ticks, table_events, offset, flags, msg = 1, 0, {}
    local pack, unpack = string.pack, string.unpack
    while string_pos < #midi_string do
        offset, flags, msg, string_pos = unpack("i4Bs4", midi_string, string_pos)
        if flags & 1 == 1 and #msg >= 3 and msg:byte(1) >> 4 == 8 and msg:byte(3) ~= -1 then
            MSB[#MSB + 1] = msg:byte(3)
        end
    end

    reaper.PreventUIRefresh(1)
    reaper.MIDI_DisableSort(take)

    -- 收集音符信息
    local collectedNotes = {}
    local i = reaper.MIDI_EnumSelNotes(take, -1)
    while i > -1 do
        local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        if selected then
            local bank = MSB[1] or 0  -- 使用第一个MSB值或默认为0
            local bankVelocityName = string.format("%d-%d-%d", bank, vel, pitch)
            table.insert(collectedNotes, {index = i, bankVelocityName = bankVelocityName, startppqpos = startppqpos})
        end
        i = reaper.MIDI_EnumSelNotes(take, i)
    end

    -- 根据开始位置分组音符，并为每个组内的音符按照 pitch 排序
    local noteGroups = {}

    for _, noteInfo in ipairs(collectedNotes) do
        if not noteGroups[noteInfo.startppqpos] then
            noteGroups[noteInfo.startppqpos] = {}
        end
        table.insert(noteGroups[noteInfo.startppqpos], noteInfo)
    end

    for startppqpos, group in pairs(noteGroups) do
        table.sort(group, function(a, b) return a.bankVelocityName < b.bankVelocityName end)

        local bankVelocityNames = {}
        for _, noteInfo in ipairs(group) do
            table.insert(bankVelocityNames, noteInfo.bankVelocityName)
        end

        -- 连接排序后的 bankVelocityName，查找映射
        local mapping = find_mapping_rev(bankMappingsRev, table.concat(bankVelocityNames, ","))
        if mapping then
            local msb, lsb, pc = mapping:match("(%d+)-(%d+)-(%d+)")
            msb, lsb, pc = tonumber(msb), tonumber(lsb), tonumber(pc)

            -- 选择组内的第一个音符来确定插入消息的位置
            local referenceNote = group[1]  -- 假设按pitch排序后的第一个音符作为参考
            local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, referenceNote.index)
            if retval and selected then
                -- 为参考音符插入 MIDI CC 和 PC 消息
                reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, 0, msb)
                reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, 32, lsb)
                reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xC0, chan, pc, 0)
    
                if endppqpos - startppqpos > sustainnote then -- 如果音符长度大于半拍
                    reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, gmem_cc_num, 127)
                    reaper.MIDI_InsertCC(take, true, muted, endppqpos, 0xB0, chan, gmem_cc_num, 32)
                end
            end
        else
            -- 映射不存在，应用 STRUM it，并为每个音符插入CC和PC
            local strumDelay = -1 -- 假定每个音符提前-1 ticks
            
            for i, noteInfo in ipairs(group) do
                local newStartPPQ = noteInfo.startppqpos + (i-1) * strumDelay
                -- 更新音符开始时间，保持结束时间不变
                reaper.MIDI_SetNote(take, noteInfo.index, true, false, newStartPPQ, noteInfo.endppqpos, noteInfo.channel, noteInfo.pitch, noteInfo.velocity, false)
            end
            
            -- 然后为每个音符插入CC和PC消息
            for i, noteInfo in ipairs(group) do
                
                -- 重新获取更新后的音符信息，以确保我们使用正确的startppqpos
                local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, noteInfo.index)
                if retval and selected then
                    -- 为每个更新过的音符插入CC和PC
                    local LSB = vel  -- 使用音符的velocity作为LSB值
                    reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, 0, MSB[1] or 0)
                    reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, 32, LSB)
                    reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xC0, chan, pitch, 0)
                end
            end

            local lastNoteInfo = group[#group]  -- 获取组内最后一个音符信息
            local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, lastNoteInfo.index)
            if retval and selected then
                -- 如果音符长度大于设定的sustainnote阈值，则插入CC119
                if endppqpos - startppqpos > sustainnote then
                    reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, gmem_cc_num, 127)
                    reaper.MIDI_InsertCC(take, true, muted, endppqpos, 0xB0, chan, gmem_cc_num, 32)
                end
            end
        end
    end

    -- 删除已处理的音符
    local i = reaper.MIDI_EnumSelNotes(take, -1)
    while i > -1 do
        reaper.MIDI_DeleteNote(take, i)
        i = reaper.MIDI_EnumSelNotes(take, -1)
    end

    reaper.MIDI_Sort(take)
    reaper.PreventUIRefresh(-1)
end

-- PC转音符
local function pcToNote()
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
            -- 检查是否有映射
            local bankVelocityName = tostring(bank_msb_num) .. "-" .. tostring(vel) .. "-" .. tostring(pitch)
            if bankMappings[bankVelocityName] then
                -- 如果有映射，为每个映射项创建音符
                for _, mapping in ipairs(bankMappings[bankVelocityName]) do
                    local mappedBank, mappedVel, mappedPitch = mapping:match("(%d+)-(%d+)-(%d+)")
                    mappedBank = tonumber(mappedBank)
                    mappedVel = tonumber(mappedVel)
                    mappedPitch = tonumber(mappedPitch)
                    -- 创建音符，这里需要确保音符创建逻辑与原来相符
                    table.insert(notes_store, {
                        take, true, muted, ppqpos, ppqpos+shortnote, chan, mappedPitch, mappedVel, false -- 音符长度同原逻辑
                    })
                end
            else
                -- 没有映射，保持原来的音符创建逻辑
                table.insert(notes_store, {
                    take, true, muted, ppqpos, ppqpos+shortnote, chan, pitch, vel, false -- 音符长度同原逻辑
                })
            end
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

reaper.Undo_BeginBlock()
noteToPC()
reaper.Undo_EndBlock("", -1)
reaper.UpdateArrange()