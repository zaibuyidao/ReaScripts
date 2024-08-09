-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"

require('core')
CONFIG = require('config')
short_note_length = CONFIG.pc_to_note.short_note_length
min_long_note_length = CONFIG.pc_to_note.min_long_note_length
delimiter = getPathDelimiter()

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

function move_evnet_to_left(m) -- 选中事件向左移动 x tick
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    _, notes, ccs, _ = reaper.MIDI_CountEvts(take)
    reaper.MIDI_DisableSort(take)
    for i = 0,  ccs - 1 do
        local retval, sel, muted, cc_ppq, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
        if sel == true then
            if chanmsg == 176 then -- and (msg2 == 0 or msg2 == 32) 
                reaper.MIDI_SetCC(take, i, sel, muted, cc_ppq - m, nil, nil, nil, nil, false)
            end
            if chanmsg == 192 then
                reaper.MIDI_SetCC(take, i, sel, muted, cc_ppq - m, nil, nil, nil, nil, false)
            end
        end
        i = i + 1
    end
    for i = 0,  notes - 1 do
        local retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        if sel == true then
            reaper.MIDI_SetNote(take, i, sel, muted, ppq_start - m, ppq_end - m, nil, nil, nil, false)
        end
        i = i + 1
    end
    reaper.MIDI_Sort(take)
end

function move_evnet_to_right(m) -- 选中事件向右移动 x tick
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    _, notes, ccs, _ = reaper.MIDI_CountEvts(take)
    reaper.MIDI_DisableSort(take)
    for i = 0,  ccs - 1 do
        local retval, sel, muted, cc_ppq, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
        if sel == true then
            if chanmsg == 176 then -- and (msg2 == 0 or msg2 == 32)
                reaper.MIDI_SetCC(take, i, sel, muted, cc_ppq + m, nil, nil, nil, nil, false)
            end
            if chanmsg == 192 then
                reaper.MIDI_SetCC(take, i, sel, muted, cc_ppq + m, nil, nil, nil, nil, false)
            end
        end
        i = i + 1
    end
    for i = 0,  notes - 1 do
        local retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        if sel == true then
            reaper.MIDI_SetNote(take, i, sel, muted, ppq_start + m, ppq_end + m, nil, nil, nil, false)
        end
        i = i + 1
    end
    reaper.MIDI_Sort(take)
end

function process_bnkprg_lines(lines)
    local bankMappings = {}
    for i=1,#lines do
        -- 首先确保行以“//”开始
        if not lines[i]:match("^//") then
            -- 删除行中的“//”和行尾的空格
            local cleanLine = lines[i]:gsub("//", ""):gsub("%s*$", "")
            -- 提取并处理bank-velocity-name映射
            local key, value = cleanLine:match("^(%d+-%d+-%d+)=(.+)")
            if key and value then
                bankMappings[key] = {}
                -- value可能包含多个bank-velocity-name，用逗号分隔
                for bankVelocityName in value:gmatch("(%d+-%d+-%d+)") do
                    table.insert(bankMappings[key], bankVelocityName)
                end
            end
        end
    end
    return bankMappings
end

function process_bnkprg_r_lines(lines)
    local bankMappings = {}
    for i=1,#lines do
        if not lines[i]:match("^//") then
            local cleanLine = lines[i]:gsub("//", ""):gsub("%s*$", "")
            local key, value = cleanLine:match("^(%d+-%d+-%d+)=(.+)")
            if key and value then
                -- 清理并排序value中的bank-velocity-name组合，确保一致的顺序
                local valueTable = {}
                for bankVelocityName in value:gmatch("(%d+-%d+-%d+)") do
                    table.insert(valueTable, bankVelocityName)
                end
                table.sort(valueTable)
                local sortedValue = table.concat(valueTable, ",")
                -- 将排序后的字符串映射回key
                bankMappings[sortedValue] = key
            end
        end
    end
    return bankMappings
end

function read_bnkprg_lines(reabank_path)
    local file = io.open(reabank_path, "r")
    if not file then
        print("Failed to open file: " .. reabank_path)
        return {} -- 文件打不开时返回空表
    end
    local lines = {}
    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close()
    return process_bnkprg_lines(lines)
end

function read_bnkprg_r_lines(reabank_path)
    local file = io.open(reabank_path, "r")
    if not file then
        print("Failed to open file: " .. reabank_path)
        return {}  -- 文件打不开时返回空表
    end
    local lines = {}
    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close()
    return process_bnkprg_r_lines(lines)
end

-- 打印
-- for k, v in pairs(bankMappings) do
--     print("Key: " .. k)
--     for _, bvName in ipairs(v) do
--         print("    Value: " .. bvName)
--     end
-- end

function find_mapping(bankMappings, bankVelocityName)
    if bankMappings[bankVelocityName] then
        --print("Mappings for " .. bankVelocityName .. ":")
        for _, mapping in ipairs(bankMappings[bankVelocityName]) do
            -- print("    " .. mapping)
            return mapping
        end
    else
        --print("No mappings found for " .. bankVelocityName)
        return nil
    end
end

function find_mapping_rev(bankMappingsRev, ...)
    -- 获取所有参数并排序
    local args = {...}
    table.sort(args)
    local searchValue = table.concat(args, ",")
    
    -- 查找映射
    local mapping = bankMappingsRev[searchValue]
    if mapping then
        --print("Mapping found: " .. mapping)
        return mapping
    else
        --print("No mapping found for the combination: " .. searchValue)
        return nil
    end
end
-- find_mapping(bankMappings, "0-96-67")
-- find_mapping_rev(bankMappingsRev, "0-96-67", "0-96-74", "0-96-79")

-- 解析 bank-velocity-name 字符串
local function parseBankVelocityName(bvn)
    local bank, velocity, name = bvn:match("(%d+)-(%d+)-(%d+)")
    return tonumber(bank), tonumber(velocity), tonumber(name)
end

function toggleNoteToPC()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    local miditick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
  
    local txt_path = reaper.GetResourcePath() .. delimiter .. "Data" .. delimiter .. "zaibuyidao_articulation_map" .. delimiter .. "simul-arts.txt"
    local bankMappings = read_bnkprg_lines(txt_path)
    local bankMappingsRev = read_bnkprg_r_lines(txt_path)

    local note_cnt, note_idx, sustainnote, shortnote, preoffset = 0, {}, min_long_note_length, short_note_length, 2 -- sustainnote = miditick/2, shortnote = miditick/8
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
        
                    if endppqpos - startppqpos >= sustainnote then -- 如果音符长度大于半拍
                        reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, gmem_cc_num, 96)
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
                    if endppqpos - startppqpos >= sustainnote then
                        reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, gmem_cc_num, 96)
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

    if #note_idx > 0 and #ccs_idx == 0 then
        noteToPC()
    elseif #ccs_idx > 0 and #note_idx ==0 then
        pcToNote()
    end
    reaper.UpdateArrange()
end

function togglePCToCC(msb, lsb)
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end

    local ccs_cnt, ccs_idx = 0, {}
    local ccs_val = reaper.MIDI_EnumSelCC(take, -1)
    while ccs_val ~= -1 do
        ccs_cnt = ccs_cnt + 1
        ccs_idx[ccs_cnt] = ccs_val
        ccs_val = reaper.MIDI_EnumSelCC(take, ccs_val)
    end

    if ccs_cnt == 0 then
        return
        reaper.SN_FocusMIDIEditor()
    end

    function processEvents(take)
        local cc58Selected = false
        local pcSelected = false
        local cc0cc32Selected = false
    
        -- 遍历所有选中的CC事件
        for i = 1, #ccs_idx do
            retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccs_idx[i])
            if chanmsg == 176 and msg2 == gmem_cc58_num then
                cc58Selected = true
            end
            -- 检查是否为CC0或CC32
            if chanmsg == 176 and (msg2 == 0 or msg2 == 32) then
                cc0cc32Selected = true
            end

            if chanmsg == 192 then
                pcSelected = true
            end
        end

        -- 基于选中的事件类型调用相应函数或不做任何操作
        if cc58Selected and not (pcSelected or cc0cc32Selected) then
            ccToPC()
            setFocusToWindow(WINDOW_TITLE) -- 聚焦窗口
        elseif (pcSelected or cc0cc32Selected) and not cc58Selected then
            pcToCC()
        else
            -- 如果CC58和PC/CC0/CC32同时被选中，或者这些特定事件均未被选中，不执行任何操作
            -- reaper.ShowMessageBox("No specific action taken. Either mixed selection or no relevant selection.", "Info", 0)
        end
    end

    local function deleteSelectedPCAndCC(take)
        local eventIdxToDelete = {} -- 用于收集所有选中的PC、CC0和CC32事件的索引
    
        local i = reaper.MIDI_EnumSelCC(take, -1)
        while i > -1 do
            local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
            
            -- 检查是否为PC事件
            if chanmsg == 192 and selected then
                table.insert(eventIdxToDelete, i)
            end
            
            -- 检查是否为CC0或CC32
            if chanmsg == 176 and selected and (msg2 == 0 or msg2 == 32) then
                table.insert(eventIdxToDelete, i)
            end
    
            i = reaper.MIDI_EnumSelCC(take, i)
        end
    
        -- 反向遍历并删除收集到的事件，以避免在删除事件后改变后续事件的索引
        for i = #eventIdxToDelete, 1, -1 do
            reaper.MIDI_DeleteCC(take, eventIdxToDelete[i])
        end
    end

    local function deleteSelectedCC(take)
        local eventIdxToDelete = {} -- 用于收集所有选中的PC、CC0和CC32事件的索引
    
        local i = reaper.MIDI_EnumSelCC(take, -1)
        while i > -1 do
            local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
            -- 检查是否为CC58
            if chanmsg == 176 and selected and (msg2 == gmem_cc58_num) then
                table.insert(eventIdxToDelete, i)
            end

            i = reaper.MIDI_EnumSelCC(take, i)
        end
    
        -- 反向遍历并删除收集到的事件，以避免在删除事件后改变后续事件的索引
        for i = #eventIdxToDelete, 1, -1 do
            reaper.MIDI_DeleteCC(take, eventIdxToDelete[i])
        end
    end

    function ccToPC()
        reaper.PreventUIRefresh(1)
        reaper.MIDI_DisableSort(take)

        bankMSB = reaper.GetExtState("ARTICULATION_MAP", "bankMSB")
        bankLSB = reaper.GetExtState("ARTICULATION_MAP", "bankLSB")
        if (bankMSB == "") then bankMSB = msb or "" end
        if (bankLSB == "") then bankLSB = lsb or "" end

        -- 请求用户输入Bank MSB和LSB
        local retval, userInput = reaper.GetUserInputs("Bank Select", 2, "Enter Bank MSB:,Enter Bank LSB:", bankMSB .. ','.. bankLSB)
        if not retval then return end
        local bankMSB, bankLSB = userInput:match("([^,]+),([^,]+)")
        bankMSB, bankLSB = tonumber(bankMSB), tonumber(bankLSB)
        if not retval or not bankMSB or not bankLSB then
            return
        end
    
        reaper.SetExtState("ARTICULATION_MAP", "bankMSB", bankMSB, false)
        reaper.SetExtState("ARTICULATION_MAP", "bankLSB", bankLSB, false)
    
        -- 遍历所有选中的MIDI事件
        for i = 1, #ccs_idx do
            local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccs_idx[i])
            if chanmsg == 176 and msg2 == gmem_cc58_num then -- CC58控制器
                local program = msg3
                reaper.MIDI_InsertCC(take, true, muted, ppqpos, 0xB0, chan, 0, bankMSB or 0)
                reaper.MIDI_InsertCC(take, true, muted, ppqpos, 0xB0, chan, 32, bankLSB)
                reaper.MIDI_InsertCC(take, true, muted, ppqpos, 0xC0, chan, program, 0)
            end
        end

        -- 删除选中的CC58事件
        deleteSelectedCC(take)

        reaper.MIDI_Sort(take)
        reaper.PreventUIRefresh(-1)
    end

    function pcToCC()
        reaper.PreventUIRefresh(1)
        reaper.MIDI_DisableSort(take)
    
        for i = 1, #ccs_idx do
            local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccs_idx[i])
            if chanmsg == 192 then
                local program = msg2
                reaper.MIDI_InsertCC(take, true, muted, ppqpos, 0xB0, chan, gmem_cc58_num, program)
            end
        end

        -- 删除选中的PC事件
        deleteSelectedPCAndCC(take)

        reaper.MIDI_Sort(take)
        reaper.PreventUIRefresh(-1)
    end

    processEvents(take)

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
        -- reaper.MB(setpc_msg, setpc_err, 0),
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
    local uok, uinput = reaper.GetUserInputs(setpc_title, 3, setpc_retvals_csv, "" ..','.. "" ..','.. "") -- bank_msb[1] ..','.. note_vel[1] ..','.. note_pitch[1]
    local MSB, LSB, NOTE_P = uinput:match("(.*),(.*),(.*)")

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
    local fxFirst = reaper.TrackFX_GetByName(track, "Pre-trigger Events", false)
  
    if fxIndex < 0 then
        -- 如果插件不存在，则添加它到顶部
        fxFirst = reaper.TrackFX_AddByName(track, "Pre-trigger Events", false, -1000)
        fxIndex = reaper.TrackFX_AddByName(track, "Articulation Map", false, -1001)
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

function toggle_pre_trigger_jsfx()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end

    local track = reaper.GetMediaItemTake_Track(take)
    local fxFirst = reaper.TrackFX_GetByName(track, "Pre-trigger Events", false)

    -- 检查浮动窗口是否打开
    local isFloating = reaper.TrackFX_GetFloatingWindow(track, fxFirst) ~= nil
    if isFloating then
        -- 如果浮动窗口打开，则关闭它
        reaper.TrackFX_Show(track, fxFirst, 2)
    else
        -- 如果浮动窗口关闭，则打开它
        reaper.TrackFX_Show(track, fxFirst, 3)
    end
end

-- AM-JSFX插件参数设置
function setJSFXParameter(param_index, value)
    local active_take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not active_take or not reaper.TakeIsMIDI(active_take) then return end

    local track = reaper.GetMediaItemTake_Track(active_take)
    local fx_name = "Articulation Map"

    -- 查找指定名称的插件
    local fx_index = reaper.TrackFX_GetByName(track, fx_name, false)
    if fx_index == -1 then
        -- reaper.ShowMessageBox("JSFX plugin '" .. fx_name .. "' not found on track.", "Error", 0)
        return
        -- add_or_toggle_articulation_map_jsfx()
    end

    if value ~= nil then
        reaper.TrackFX_SetParam(track, fx_index, param_index, value)
    end
end

function process_and_save_reabank_mappings(reabank_path)
    local delimiter = package.config:sub(1,1)  -- 获取系统路径分隔符 ('\' for Windows, '/' for Unix)
    local txt_path = reaper.GetResourcePath() .. delimiter .. "Data" .. delimiter .. "zaibuyidao_articulation_map" .. delimiter .. "simul-arts.txt"

    -- 读取原始 simul-arts.txt 文件内容到表
    local original_content = {}
    local f = io.open(txt_path, "r")
    if f then
        local current_bank_name = nil
        for line in f:lines() do
            local bank_comment = line:match("^//(.+)$")
            if bank_comment then
                current_bank_name = "//" .. bank_comment
                original_content[current_bank_name] = {}
            elseif current_bank_name and line:match("^%d+-%d+-%d+=") then
                table.insert(original_content[current_bank_name], line)
            end
        end
        f:close()
    end

    -- 处理 reabank 文件，更新或添加新的 articulations
    local updates = {}
    local file = io.open(reabank_path, "r")
    if not file then
        -- print("Failed to open file: " .. reabank_path)
        return {}
    end

    local current_bank_name = nil
    for line in file:lines() do
        local bank_header = line:match("^(Bank %d+ %d+ .+)$")  -- 捕获整个Bank行
        if bank_header then
            current_bank_name = "//" .. bank_header
            updates[current_bank_name] = {}  -- 初始化，即使没有//!也初始化防止错误
        elseif current_bank_name and line:match("^//!") then
            local key, values = line:match("^//!%s*(%d+-%d+-%d+)%s*=%s*(.+)%s*$")
            if key and values then
                values = values:gsub("%s+", "")  -- 移除数字间的空格
                updates[current_bank_name] = updates[current_bank_name] or {}
                table.insert(updates[current_bank_name], key .. "=" .. values)
            end
        end
    end
    file:close()

    -- 将更新写回 simul-arts.txt，覆盖或添加新项
    f = io.open(txt_path, "w")
    if not f then
        print("Cannot open file to write: " .. txt_path)
        return {}
    end

    -- 首先写入那些在 updates 中有提及并且存在 //! 行的内容
    for bank_name, lines in pairs(updates) do
        if #lines > 0 then  -- 仅处理有//!行的bank
            f:write(bank_name .. "\n")
            for _, line in ipairs(lines) do
                f:write(line .. "\n")
            end
        elseif original_content[bank_name] then
            -- 对于 updates 中提到但无有效 //! 行的bank，保留原始内容
            for _, line in ipairs(original_content[bank_name]) do
                f:write(line .. "\n")
            end
        end
    end

    -- 写入未在 updates 中提及的原始内容
    for bank_name, lines in pairs(original_content) do
        if not updates[bank_name] then
            f:write(bank_name .. "\n")
            for _, line in ipairs(lines) do
                f:write(line .. "\n")
            end
        end
    end

    f:close()  -- 关闭文件
end
