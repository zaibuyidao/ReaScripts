-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"

require('core')

function togglePCToCC()
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
        if (bankMSB == "") then bankMSB = "" end
        if (bankLSB == "") then bankLSB = "" end
    
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

reaper.Undo_BeginBlock()
togglePCToCC()
reaper.Undo_EndBlock("", -1)