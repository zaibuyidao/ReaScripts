--[[
 * ReaScript Name: Articulation Map - Patch Change GUI
 * Version: 1.6
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-7-22)
  + Initial release
--]]

SCRIPT_NAME = "INSERT_PATCH_GUI"

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())

if not take or not reaper.TakeIsMIDI(take) then return end

function Msg(param) 
    reaper.ShowConsoleMsg(tostring(param) .. "\n") 
end

local function parse_bank(bank_line)
    return bank_line:match("Bank (%d+) (%d+) (.-)$")
end

local function parse_patch(bank_line)
    return bank_line:match("^%s*(%d+) (.-)$")
end

function table.print(t)
    local print_r_cache = {}
    local function sub_print_r(t, indent)
        if (print_r_cache[tostring(t)]) then
            print(indent .. "*" .. tostring(t))
        else
            print_r_cache[tostring(t)] = true
            if (type(t) == "table") then
                for pos, val in pairs(t) do
                    if (type(val) == "table") then
                        print(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(pos) + 8))
                        print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. pos .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. pos .. "] => " .. tostring(val))
                    end
                end
            else
                print(indent .. tostring(t))
            end
        end
    end
    if (type(t) == "table") then
        print(tostring(t) .. " {")
        sub_print_r(t, "  ")
        print("}")
    else
        sub_print_r(t, "  ")
    end
end

function string.split(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter == "") then return false end
    local pos, arr = 0, {}
    for st, sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end

function read_file(fname)
    local f, err = io.open(fname)
    if f then
        local contents = f:read("*all")
        f:close()
        return contents, nil
    else
        return nil, err
    end
end

function write_file(fname, contents)
    local f, err = io.open(fname, "w")
    if f then
        f:write(contents)
        f:close()
    else
        return err
    end
end

local function set_reabank_file(reabank_path)

    local ini_file = reaper.get_ini_file()
    local ini, err = read_file(ini_file)

    if err then
        return
        reaper.MB("Failed to read REAPER's ini file\n無法讀取 REAPER 的 ini 文件", "Error", 0),
        reaper.SN_FocusMIDIEditor()
    end
    if ini:find("mididefbankprog=") then -- 如果找到 mididefbankprog=
        ini = ini:gsub("mididefbankprog=[^\n]*", "mididefbankprog=" .. reabank_path) -- 在下一行新增BANK地址
    else
        local pos = ini:find('%[REAPER%]\n')
        if not pos then
            pos = ini:find('%[reaper%]\n')
        end
        if pos then
            ini = ini:sub(1, pos + 8) .. "mididefbankprog=" .. reabank_path .. "\n" .. ini:sub(pos + 9)
        end
    end

    err = write_file(ini_file, ini)
    if err then
        return
        reaper.MB("Failed to write ini file\n寫入ini文件失敗", "Error", 0),
        reaper.SN_FocusMIDIEditor()
    end

end

function parse_banks(lines)
    local result = {}
    for _, line in ipairs(lines) do
        if #line == 0 or line:match("^%s-$") then
            goto continue
        end

        local bank, velocity, name = parse_bank(line)
        if bank and velocity and name then
            table.insert(result, {
                bank = {
                    full_name = "" .. bank .. " : " .. name .." (" .. velocity .. ")",
                    bank = bank,
                    velocity = velocity,
                    name = name
                },
                notes = {}
            })
            goto continue
        end

        local note, name = parse_patch(line)
        if note and name then
            table.insert(result[#result].notes, {
                full_name = line,
                name = name,
                note = note
            })
        end
        ::continue::
    end
    return result
end

function group_banks(banks)
    local result = {}
    for _, bank_item in ipairs(banks) do
        if not result[bank_item.bank.bank] then
            result[bank_item.bank.bank] = {
                banks = {},
                notes = {}
            }
        end
        table.insert(result[bank_item.bank.bank].banks, bank_item.bank)
        for _, note_item in ipairs(bank_item.notes) do
            table.insert(result[bank_item.bank.bank].notes, {
                full_name = note_item.note .. " " .. note_item.name .. " (" .. bank_item.bank.velocity .. ")" ,
                name = note_item.name,
                bank = bank_item.bank.bank,
                velocity = bank_item.bank.velocity,
                note = note_item.note,
            })
        end
    end
    local function find_best_bank(banks)
        for _, bank in ipairs(banks) do
            if tonumber(bank.velocity) == 96 then 
                return {
                    name = bank.name,
                    velocity = bank.velocity,
                    bank = bank.bank,
                    full_name = "" .. tostring(bank.bank) .. " : " .. bank.name
                }
            end
        end
        for _, bank in ipairs(banks) do
            if tonumber(bank.velocity) == 0 then 
                return {
                    name = bank.name,
                    velocity = bank.velocity,
                    bank = bank.bank,
                    full_name = "" .. tostring(bank.bank) .. " : " .. bank.name
                }
            end
        end
        return {
            name = banks[1].name,
            velocity = banks[1].velocity,
            bank = banks[1].bank,
            full_name = "" .. tostring(banks[1].bank) .. " : " .. banks[1].name
        }
    end

    local new_result = {}
    for _, result_item in pairs(result) do
        table.sort(result_item.notes, function(a, b)
            return tonumber(a.note) < tonumber(b.note)
        end)
        table.insert(new_result, {
            notes = result_item.notes,
            bank = find_best_bank(result_item.banks)
        })
    end
    table.sort(new_result, function(a,b)
        return tonumber(a.bank.bank) < tonumber(b.bank.bank)
    end)
    return new_result
end

function process_lines(lines)
    for i=1,#lines do
        lines[i] = lines[i]:gsub("%s*//.-$", "")
    end
    return lines
end

local function osOpenCommand()
    local commands = {
        {os = "Win", cmd = 'start ""'},
        {os = "OSX", cmd = 'open ""'},
        {os = "Other", cmd = 'xdg-open'},
    }
    
    local OS = reaper.GetOS()
    
    for _, v in ipairs(commands) do
      if OS:match(v.os) then return v.cmd end
    end
end

local reabank_path = reaper.GetExtState("ArticulationMapPatchChangeGUI", "ReaBankPatch")

if (reabank_path == "") then 

    reaper.ShowMessageBox("The reabank does not exist, please select a reabank!\n音色表不存在，請選擇一個音色表！", "Can't find reabank", 0)
    local retval, new_path = reaper.GetUserFileNameForRead("", "選擇音色表", "") -- 系统文件路径
    if not retval then return 0 end
    local bank_num = new_path:reverse():find('[%/%\\]')
    local bank_name = new_path:sub(-bank_num + 1) .. "" -- 音色表名称

    if string.match(bank_name, "%..+$") ~= ".reabank" then
        return reaper.MB("Please select reabank file with the suffix .reabank!\n請選擇後綴為 .reabank 的音色表！", "Error", 0),
        reaper.SN_FocusMIDIEditor()
    end
    reabank_path = new_path
    reaper.SetExtState("ArticulationMapPatchChangeGUI", "ReaBankPatch", reabank_path, true)

end

set_reabank_file(reabank_path)

function create_reabank_action(get_path)

    local bank_num = get_path:reverse():find('[%/%\\]')
    local bank_name = get_path:sub(-bank_num + 1) .. "" -- 音色表名称
    
    local retval, retvals_csv = reaper.GetUserInputs("Create an action 創建一個動作", 2, "Reabank path 音色表路徑 :,Reabank alias 音色表別名 :,extrawidth=200", get_path.."," .. "Open Reabank - " ..bank_name)
    if not retval or retvals_csv == "" then return 0 end
    
    get_path, bank_name = string.match(retvals_csv, "([^,]+),([^,]*)")
    if not get_path then return 0 end

    local str =	"-- 使用表情映射-插入音色GUI腳本創建的動作，用於一鍵打開音色表。\n" .. [[os.execute(']] .. osOpenCommand() .. [[ "]] .. get_path .. [["')]]
    str = string.gsub(str, [[\]], [[\\]])

    local info = debug.getinfo(1,'S');

    local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- 脚本位置
    local file_name = script_path .. "" .. bank_name .. ".lua" -- 完整路径

    local file, err = io.open(file_name , "w+")

    if not file then
        reaper.ShowMessageBox("不能創建文件 Couldn't create file:\n" .. file_name .. "\n\nError: " .. tostring(err), "Whoops", 0)
        return 0
    end
    
    file:write(str) -- 将内容写入脚本中

    reaper.ShowMessageBox( "成功創建文件 Successfully created file:\n" .. ( string.len(file_name) > 64 and ( "..." .. string.sub(file_name, -56) ) or file_name), "Yes!", 0)
    
    io.close(file)
    
    reaper.AddRemoveReaScript(true, 32060, file_name, true)
end

function read_config_lines(reabank_path)
    local file = io.open(reabank_path, "r")
    local temp = {}
    for line in file:lines() do
        table.insert(temp, line)
    end
    return process_lines(temp)
end

function read_test_lines()
    -- 测试用的数据
    local data = [[
        Bank 0 96 Cinematic Studio Strings
        12 Sustain
        
        Bank 0 1 Cinematic Studio Strings
        22 legato off
        23 Con sordino off
        
        Bank 0 127 Cinematic Studio Strings
        22 legato on
        23 Con sordino on
        ]]
    return string.split(data, "\n")
end

function inset_patch(bank, note, velocity, chan)
    local chan = chan - 1
    reaper.PreventUIRefresh(1)
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    item = reaper.GetMediaItemTake_Item(take)
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
      --local chan = 0
      reaper.MIDI_InsertCC(take, selected, muted, ppq_pos, 0xB0, chan, 0, bank)
      reaper.MIDI_InsertCC(take, selected, muted, ppq_pos, 0xB0, chan, 32, velocity)
      reaper.MIDI_InsertCC(take, selected, muted, ppq_pos, 0xC0, chan, note, 0)
    end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    if (reaper.SN_FocusMIDIEditor) then reaper.SN_FocusMIDIEditor() end
end

function slideF10()
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
    reaper.SN_FocusMIDIEditor()
end

function slideZ10()
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
    reaper.SN_FocusMIDIEditor()
end

function ToggleNotePC()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end

    local note_cnt, note_idx = 0, {}
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
        reaper.MB("PC or Note event must be selected\n必須選擇PC或音符事件", "Error", 0),
        reaper.SN_FocusMIDIEditor()
    end

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
      
        for i = 1, #note_idx do
            retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, note_idx[i])
            if selected == true then
              -- if vel == 96 then
              --   LSB = 0
              --   reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, 0, MSB[1]) -- CC#00
              --   reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, 32, LSB) -- CC#32
              --   reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xC0, chan, pitch, 0) -- Program Change
              -- else
                LSB = vel
                reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, 0, MSB[1]) -- CC#00
                reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, 32, LSB) -- CC#32
                reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xC0, chan, pitch, 0) -- Program Change
                -- end
                flag = true
            end
        end
      
        i = reaper.MIDI_EnumSelNotes(take, -1)
        while i > -1 do
            reaper.MIDI_DeleteNote(take, i)
            i = reaper.MIDI_EnumSelNotes(take, -1)
        end
    
        reaper.MIDI_Sort(take)
        reaper.PreventUIRefresh(-1)
    end
    
    local function PCToNote()
        local bank_msb = {}
    
        reaper.PreventUIRefresh(1)
        reaper.MIDI_DisableSort(take)
    
        for i = 1, #ccs_idx do
            retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccs_idx[i])
            if chanmsg == 176 and msg2 == 0 then -- CC#0
                bank_msb_num = msg3
                bank_msb[#bank_msb+1] = bank_msb_num
            end
            if chanmsg == 176 and msg2 == 32 then -- CC#32
                vel = msg3
                if vel == 0 then vel = 96 end
            end
            if chanmsg == 192 then --Program Change
                pitch = msg2
                reaper.MIDI_InsertNote(take, true, muted, ppqpos, ppqpos+120, chan, pitch, vel, false)
            end
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
    
        reaper.MIDI_Sort(take)
        reaper.PreventUIRefresh(-1)
    end
    
    if #note_idx > 0 and #ccs_idx == 0 then
        NoteToPC()
    elseif #ccs_idx > 0 and #note_idx ==0 then
        PCToNote()
    end
    reaper.UpdateArrange()
    reaper.SN_FocusMIDIEditor()
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
        reaper.MB("PC event must be selected\n必須選擇PC事件", "Error", 0),
        reaper.SN_FocusMIDIEditor()
    end

    local bank_msb, note_vel = {}, {}

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
    end

    if bank_msb[1] == nil or note_vel[1] == nil then return reaper.SN_FocusMIDIEditor() end
    -- local MSB = reaper.GetExtState("ArticulationMapPatchChangeGUI", "MSB")
    -- if (MSB == "") then MSB = "0" end
    local user_ok, input_csv = reaper.GetUserInputs('Set Group Velocity', 2, 'Group 樂器組,Velocity 力度', bank_msb[1] ..','.. note_vel[1])
    if not user_ok then return reaper.SN_FocusMIDIEditor() end
    local MSB, LSB = input_csv:match("(.*),(.*)")
    if not tonumber(MSB) or not tonumber(LSB) then return reaper.SN_FocusMIDIEditor() end
    -- reaper.SetExtState("ArticulationMapPatchChangeGUI", "MSB", MSB, false)
    reaper.MIDI_DisableSort(take)
    for i = 1, #index do
        local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, index[i])
        if chanmsg == 176 and msg2 == 0 then -- CC#0
            reaper.MIDI_SetCC(take, index[i], nil, nil, nil, nil, nil, nil, MSB, false)
        end
        if chanmsg == 176 and msg2 == 32 then -- CC#32
            reaper.MIDI_SetCC(take, index[i], nil, nil, nil, nil, nil, nil, LSB, false)
        end
    end
    reaper.MIDI_Sort(take)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.SN_FocusMIDIEditor()
end

function add_fx()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    local track = reaper.GetMediaItemTake_Track(take)
    local pand = reaper.TrackFX_AddByName(track, "Articulation Map", false, 0)
    if pand < 0 then
        reaper.TrackFX_AddByName(track, "Articulation Map", false, -1000)
        local FX1_id = reaper.TrackFX_GetByName(track, "Articulation Map", true)
        reaper.TrackFX_Show(track, FX1_id, 3)
    else
        local FX1_id = reaper.TrackFX_GetByName(track, "Articulation Map", true)
        reaper.TrackFX_Show(track, FX1_id, 3)
    end
end

-- table.print(group_banks(parse_banks(process_lines(read_test_lines()))))
-- os.exit()

-- For Saving ExtState

function pickle(t)
	return Pickle:clone():pickle_(t)
end

Pickle = {
	clone = function (t) local nt = {}
	for i, v in pairs(t) do 
		nt[i] = v 
	end
	return nt 
end 
}

function Pickle:pickle_(root)
	if type(root) ~= "table" then 
		error("can only pickle tables, not " .. type(root) .. "s")
	end
	self._tableToRef = {}
	self._refToTable = {}
	local savecount = 0
	self:ref_(root)
	local s = ""
	while #self._refToTable > savecount do
		savecount = savecount + 1
		local t = self._refToTable[savecount]
		s = s .. "{\n"
		for i, v in pairs(t) do
			s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
		end
	s = s .. "},\n"
	end
	return string.format("{%s}", s)
end

function Pickle:value_(v)
	local vtype = type(v)
	if     vtype == "string" then return string.format("%q", v)
	elseif vtype == "number" then return v
	elseif vtype == "boolean" then return tostring(v)
	elseif vtype == "table" then return "{"..self:ref_(v).."}"
	else error("pickle a " .. type(v) .. " is not supported")
	end 
end

function Pickle:ref_(t)
	local ref = self._tableToRef[t]
	if not ref then 
		if t == self then error("can't pickle the pickle class") end
		table.insert(self._refToTable, t)
		ref = #self._refToTable
		self._tableToRef[t] = ref
	end
	return ref
end

-- unpickle

function unpickle(s)
	if type(s) ~= "string" then
		error("can't unpickle a " .. type(s) .. ", only strings")
	end
	local gentables = load("return " .. s)
	local tables = gentables()
	for tnum = 1, #tables do
		local t = tables[tnum]
		local tcopy = {}
		for i, v in pairs(t) do tcopy[i] = v end
		for i, v in pairs(tcopy) do
			local ni, nv
			if type(i) == "table" then ni = tables[i[1]] else ni = i end
			if type(v) == "table" then nv = tables[v[1]] else nv = v end
			t[i] = nil
			t[ni] = nv
		end
	end
	return tables[1]
end

-- Simple Element Class

local Element = {}
function Element:new(x,y,w,h, r,g,b,a, lbl,fnt,fnt_sz, norm_val,norm_val2)
    local elm = {}
    elm.def_xywh = {x,y,w,h,fnt_sz} -- its default coord,used for Zoom etc
    elm.x, elm.y, elm.w, elm.h = x, y, w, h
    elm.r, elm.g, elm.b, elm.a = r, g, b, a
    elm.lbl, elm.fnt, elm.fnt_sz  = lbl, fnt, fnt_sz
    elm.norm_val = norm_val
    elm.norm_val2 = norm_val2

    setmetatable(elm, self)
    self.__index = self 
    return elm
end

-- Function for Child Classes(args = Child,Parent Class)

function extended(Child, Parent)
    setmetatable(Child,{__index = Parent}) 
end

-- Element Class Methods(Main Methods)

function Element:update_xywh()
    if not Z_w or not Z_h then return end -- return if zoom not defined
    self.x, self.w = math.ceil(self.def_xywh[1]* Z_w) , math.ceil(self.def_xywh[3]* Z_w) -- upd x,w
    self.y, self.h = math.ceil(self.def_xywh[2]* Z_h) , math.ceil(self.def_xywh[4]* Z_h) -- upd y,h
    if self.fnt_sz then --fix it!--
        self.fnt_sz = math.max(9,self.def_xywh[5]* (Z_w+Z_h)/2)
        self.fnt_sz = math.min(22,self.fnt_sz)
    end       
end

function Element:pointIN(p_x, p_y)
    return p_x >= self.x and p_x <= self.x + self.w and p_y >= self.y and p_y <= self.y + self.h
end

function Element:mouseIN()
    return gfx.mouse_cap&1==0 and self:pointIN(gfx.mouse_x,gfx.mouse_y)
end

function Element:mouseDown()
    return gfx.mouse_cap&1==1 and self:pointIN(mouse_ox,mouse_oy)
end

function Element:mouseUp() -- its actual for sliders and knobs only!
    return gfx.mouse_cap&1==0 and self:pointIN(mouse_ox,mouse_oy)
end

function Element:mouseClick()
    return gfx.mouse_cap&1==0 and last_mouse_cap&1==1 and
    self:pointIN(gfx.mouse_x,gfx.mouse_y) and self:pointIN(mouse_ox,mouse_oy)         
end

function Element:mouseR_Down()
    return gfx.mouse_cap&2==2 and self:pointIN(mouse_ox,mouse_oy)
end

function Element:mouseM_Down()
    return gfx.mouse_cap&64==64 and self:pointIN(mouse_ox,mouse_oy)
end

function Element:draw_frame()
    local x,y,w,h  = self.x,self.y,self.w,self.h
    gfx.rect(x, y, w, h, false)            -- frame1
    gfx.roundrect(x, y, w-1, h-1, 3, true) -- frame2         
end

function Element:mouseRClick()
    return gfx.mouse_cap & 2 == 0 and last_mouse_cap & 2 == 2 and
    self:pointIN(gfx.mouse_x, gfx.mouse_y) and self:pointIN(mouse_ox, mouse_oy)         
end
-- Create Element Child Classes(Button,Slider,Knob)

local Button = {}
local Knob = {}
local Slider = {}
local Rng_Slider = {}
local Frame = {}
local CheckBox = {}
local Textbox = {}
extended(Button,     Element)
extended(Knob,       Element)
extended(Slider,     Element)
extended(Rng_Slider, Element)
extended(Frame,      Element)
extended(CheckBox,   Element)
extended(Textbox,    Element)

-- Create Slider Child Classes(V_Slider,H_Slider)

local H_Slider = {}
local V_Slider = {}
extended(H_Slider, Slider)
extended(V_Slider, Slider)

-- Button Class Methods

function Button:draw_body()
    gfx.rect(self.x,self.y,self.w,self.h, true) -- draw btn body
end

function Button:draw_lbl()
    local x,y,w,h  = self.x,self.y,self.w,self.h
    local lbl_w, lbl_h = gfx.measurestr(self.lbl)
    gfx.x = x+(w-lbl_w)/2; gfx.y = y+(h-lbl_h)/2
    gfx.drawstr(self.lbl)
end

function Button:draw()
    self:update_xywh() -- Update xywh(if wind changed)
    local r,g,b,a  = self.r,self.g,self.b,self.a
    local fnt,fnt_sz = self.fnt, self.fnt_sz
    -- Get mouse state
          -- in element
          if self:mouseIN() then a=a+0.1 end
          -- in elm L_down
          if self:mouseDown() then a=a+0.2 end
          -- in elm L_up(released and was previously pressed) --
          if self:mouseClick() and self.onClick then self.onClick() end
    -- Draw btn body, frame
    gfx.set(r,g,b,a)    -- set body color
    self:draw_body()    -- body
    self:draw_frame()   -- frame
    -- Draw label
    gfx.set(0, 0, 0, 1)   -- set label color gfx.set 按钮文字颜色
    gfx.setfont(1, fnt, fnt_sz) -- set label fnt
    self:draw_lbl()             -- draw lbl
end

-- CheckBox Class Methods
function CheckBox:set_norm_val()
    local x,y,w,h  = self.x,self.y,self.w,self.h
    local val = self.norm_val      -- current value,check
    local menu_tb = self.norm_val2 -- checkbox table
    local menu_str = ""
       for i=1, #menu_tb,1 do
         if i~=val then menu_str = menu_str..menu_tb[i].."|"
                   else menu_str = menu_str.."!"..menu_tb[i].."|" -- add check
         end
       end
    gfx.x = self.x; gfx.y = self.y + self.h
    local new_val = gfx.showmenu(menu_str)        -- show checkbox menu
    if new_val>0 then self.norm_val = new_val end -- change check(!)
end

function CheckBox:draw_body()
    gfx.rect(self.x,self.y,self.w,self.h, true) -- draw checkbox body
end

function CheckBox:draw_lbl()
    local x,y,w,h  = self.x,self.y,self.w,self.h
    local lbl_w, lbl_h = gfx.measurestr(self.lbl)
    gfx.x = x-lbl_w-5; gfx.y = y+(h-lbl_h)/2
    gfx.drawstr(self.lbl) -- draw checkbox label
end

function CheckBox:draw_val()
    local x,y,w,h  = self.x,self.y,self.w,self.h
    local val = self.norm_val2[self.norm_val]
    local val_w, val_h = gfx.measurestr(val)
    gfx.x = x+5; gfx.y = y+(h-val_h)/2
    gfx.drawstr(val) -- draw checkbox val
end

function CheckBox:draw()
    self:update_xywh() -- Update xywh(if wind changed)
    local r,g,b,a  = self.r,self.g,self.b,self.a
    local fnt,fnt_sz = self.fnt, self.fnt_sz
    -- Get mouse state
          -- in element
          if self:mouseIN() then a=a+0.1 end
          -- in elm L_down
          if self:mouseDown() then a=a+0.2 end
          -- in elm L_up(released and was previously pressed) --
          if self:mouseClick() then self:set_norm_val()
             if self:mouseClick() and self.onClick then self.onClick() end
          end
    -- Draw ch_box body, frame
    gfx.set(r,g,b,a)    -- set body color
    self:draw_body()    -- body
    self:draw_frame()   -- frame
    -- Draw label
    gfx.set(0, 0, 0, 1)   -- set label,val color -- (0.7, 0.9, 0.4, 1) 下拉框颜色
    gfx.setfont(1, fnt, fnt_sz) -- set label,val fnt
    self:draw_lbl()             -- draw lbl
    self:draw_val()             -- draw val
end

-- Frame Class Methods
function Frame:draw()
   self:update_xywh() -- Update xywh(if wind changed)
   local r,g,b,a  = self.r,self.g,self.b,self.a
   if self:mouseIN() then a=a+0.1 end
   gfx.set(r,g,b,a)   -- set frame color
   self:draw_frame()  -- draw frame
end

--  Textbox Class Methods

function Textbox:draw_body()
    gfx.rect(self.x, self.y, self.w, self.h, true) -- draw textbox body
end

function Textbox:draw_label()
    local lbl_w, lbl_h = gfx.measurestr(self.lbl)
    gfx.x = self.x + (self.w - lbl_w) / 2
    gfx.y = self.y + (self.h - lbl_h) / 2
    gfx.drawstr(self.lbl)
end

--gActiveLayer = 1
function Textbox:draw()
    local r,g,b,a  = self.r,self.g,self.b,self.a
    local fnt,fnt_sz = self.fnt, self.fnt_sz
    --if (self.tab & (1 << gActiveLayer)) == 0 and self.tab ~= 0 then return end

    self:update_xywh() -- Update xywh(if wind changed)
    --self:update_zoom() -- check and update if window resized

    -- in elm R_up (released and was previously pressed), run onRClick (user defined)
    if self:mouseRClick() and self.onRClick then self.onRClick() end -- if mouseR clicked and released, execute onRClick()
    gfx.set(r,g,b,a) -- set the drawing colour for the e.Element
    self:draw_body()
    self:draw_frame()
    -- Draw label
    gfx.set(0, 0, 0, 1) -- set label color
    gfx.setfont(1, fnt, fnt_sz) -- set label font
    self:draw_label()
end

-- 按钮位置: 1-左 2-上 3-右 4-下
local btn1 = Button:new(10,10,25,30, 0.7,0.7,0.7,0.3, "1","Arial",15, 0 )
local btn4 = Button:new(52,10,25,30, 0.7,0.7,0.7,0.3, "2","Arial",15, 0 )
local btn5 = Button:new(94,10,25,30, 0.7,0.7,0.7,0.3, "<","Arial",15, 0 )
local btn6 = Button:new(136,10,25,30, 0.7,0.7,0.7,0.3, ">","Arial",15, 0 )
--local btn8 = Button:new(170,10,25,30, 0.7,0.7,0.7,0.3, "+","Arial",15, 0 )
local btn7 = Button:new(178,10,25,30, 0.7,0.7,0.7,0.3, "NP","Arial",15, 0 )
local btn10 = Button:new(220,10,25,30, 0.7,0.7,0.7,0.3, "GV","Arial",15, 0 )
local btn9 = Button:new(262,10,25,30, 0.7,0.7,0.7,0.3, "ED","Arial",15, 0 )
local btn11 = Button:new(304,10,25,30, 0.7,0.7,0.7,0.3, "FX","Arial",15, 0 )

local btn8 = Button:new(10,210,100,30, 0.8,0.8,0.8,0.8, "Load File","Arial",15, 0 )
local btn2 = Button:new(120,210,100,30, 0.8,0.8,0.8,0.8, "OK","Arial",15, 0 )
local btn3 = Button:new(230,210,100,30, 0.8,0.8,0.8,0.8, "Cancel","Arial",15, 0 )

local Button_TB = { btn1, btn2, btn3, btn4, btn5, btn6, btn7, btn8, btn9, btn10, btn11 }

-- x,y,w,h, r,g,b,a, lbl,fnt,fnt_sz, norm_val = check, norm_val2 = checkbox table
local ch_box1 = CheckBox:new(50,50,280,30,  0.8,0.8,0.8,0.3, "Bank :","Arial",15,  1, {})
local ch_box2 = CheckBox:new(50,90,280,30,  0.8,0.8,0.8,0.3, "Patch:","Arial",15,  1, {})
local ch_box3 = CheckBox:new(170,130,160,30,  0.8,0.8,0.8,0.3, "MIDI Channel :","Arial",15,  1, {"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16"})
--local ch_box3 = CheckBox:new(120,130,210,30,  0.8,0.8,0.8,0.3, "MIDI Channel :","Arial",15,  1, {"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16"})
local CheckBox_TB = {ch_box1,ch_box2,ch_box3}

local W_Frame = Frame:new(10,10,320,230,  0,0.9,0,0.1 ) -- 虚线尺寸
local Frame_TB = { W_Frame }

-- 文本框
local bank_num = reabank_path:reverse():find('[%/%\\]')
local bank_name = reabank_path:sub(-bank_num + 1) -- 音色表名称
local textb = Textbox:new(10,170,320,30, 0.8,0.8,0.8,0.3, bank_name, "Arial", 15, 0)
local Textbox_TB = { textb }

btn3.onClick = function ()
    gfx.quit()
    reaper.SN_FocusMIDIEditor()
end   -- 退出按钮
btn5.onClick = function () slideF10() end -- -10Tick
btn6.onClick = function () slideZ10() end -- +10Tick
--btn7.onClick = function () create_reabank_action(reabank_path) end -- 创建音色表脚本
btn7.onClick = function () ToggleNotePC() end   -- NOTE PC 来回切
btn9.onClick = function () -- 编辑音色表
    local rea_patch = '\"'..reabank_path..'\"'
    edit_reabank = 'start "" '..rea_patch
    os.execute(edit_reabank)
end
btn10.onClick = function () set_group_velocity() end -- 设置乐器组
btn11.onClick = function () add_fx() end -- 添加表情映射插件

midi_chan = reaper.GetExtState("ArticulationMapPatchChangeGUI", "MIDIChannel")
if midi_chan == "" then midi_chan = 1 end
ch_box3.norm_val = tonumber(midi_chan)
ch_box3.onClick = function()
    midi_chan = ch_box3.norm_val
    reaper.SetExtState("ArticulationMapPatchChangeGUI", "MIDIChannel", midi_chan, false)
end
midi_chan = tonumber(midi_chan)

if read_config_lines(reabank_path) == 1 or read_config_lines(reabank_path) == 0 then return end
local store = parse_banks(read_config_lines(reabank_path))      -- 模式1数据
local store_grouped = group_banks(store)            -- 模式2数据
local current_state         -- 当前选中的参数
local current_mode = "1"    -- 当前模式

local function push_current_state() -- 保存当前状态
    if current_state then -- 新增判断
        reaper.SetProjExtState(0, SCRIPT_NAME, "baseState", pickle(current_state))
    end
    reaper.SetProjExtState(0, SCRIPT_NAME, "baseStateMode", current_mode)
end

local function pop_current_state()  -- 读出当前状态
    local _, baseStateStr = reaper.GetProjExtState(0, SCRIPT_NAME, "baseState")
    if baseStateStr ~= "" then
        current_state = unpickle(baseStateStr)
    end

    local _, r = reaper.GetProjExtState(0, SCRIPT_NAME, "baseStateMode")
    if r ~= "" then
        current_mode = r
    else 
        current_mode = "1"
    end
end

local function switch_mode_1() -- 模式1 切换
    local function update_current_state()
        current_state = {
            velocity = store[ch_box1.norm_val].bank.velocity,
            note = store[ch_box1.norm_val].notes[ch_box2.norm_val].note,
            bank = store[ch_box1.norm_val].bank.bank
        }
        push_current_state()
    end

    local bank_titles = {}
    local box1_index = 1
    for i, bank_item in ipairs(store) do
        table.insert(bank_titles, bank_item.bank.full_name)
        if current_state and tonumber(bank_item.bank.velocity)==tonumber(current_state.velocity) and tonumber(bank_item.bank.bank)==tonumber(current_state.bank) then
            box1_index = i
        end
    end
    ch_box1.norm_val = box1_index
    ch_box1.norm_val2 = bank_titles

    local function update_patch_box()
        local bank_index = ch_box1.norm_val
        if not store[bank_index] then bank_index = 1 end
        local selected = 1
        local note_titles = {}
        for i, note_item in ipairs(store[bank_index].notes) do
            table.insert(note_titles, note_item.full_name)
            if current_state and tonumber(note_item.note) == tonumber(current_state.note) then
                selected = i
            end
        end
        ch_box2.norm_val = selected
        ch_box2.norm_val2 = note_titles
    end
    
    ch_box1.onClick = function()
        update_patch_box()
        ch_box2.norm_val = 1 -- 新增判断
        update_current_state()
    end

    ch_box2.onClick = function()
        update_current_state()
    end

    update_patch_box()
    
    btn2.onClick = function ()
        local bank_item = store[ch_box1.norm_val]
        local note_item = bank_item.notes[ch_box2.norm_val]
        inset_patch(bank_item.bank.bank, note_item.note, bank_item.bank.velocity, midi_chan)
        -- gfx.quit()
    end
end

local function switch_mode_2() -- 模式2 切换
    local function update_current_state()
        current_state = {
            velocity = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val].velocity,
            note = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val].note,
            bank = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val].bank
        }
        push_current_state()
    end
    local bank_titles = {}
    local box1_index = 1
    for i, bank_item in ipairs(store_grouped) do
        table.insert(bank_titles, bank_item.bank.full_name)
        if current_state and tonumber(bank_item.bank.bank)==tonumber(current_state.bank) then
            box1_index = i
        end
    end
    ch_box1.norm_val = box1_index
    ch_box1.norm_val2 = bank_titles

    local function update_patch_box()
        local bank_index = ch_box1.norm_val
        if not store_grouped[bank_index] then bank_index = 1 end
        local selected = 1
        local note_titles = {}
        for i, note_item in ipairs(store_grouped[bank_index].notes) do
            table.insert(note_titles, note_item.full_name)
            if current_state and tonumber(note_item.note) == tonumber(current_state.note) and tonumber(note_item.velocity) == tonumber(current_state.velocity) then
                selected = i
            end
        end
        ch_box2.norm_val = selected
        ch_box2.norm_val2 = note_titles
    end
    
    ch_box1.onClick = function()
        update_patch_box()
        ch_box2.norm_val = 1 -- 新增判断
        update_current_state()
    end

    ch_box2.onClick = function()
        update_current_state()
    end

    update_patch_box()
    
    btn2.onClick = function ()
        local note_item = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val]
        inset_patch(note_item.bank, note_item.note, note_item.velocity, midi_chan)
        -- gfx.quit()
    end
end

pop_current_state() -- 读取数据
if current_mode == "2" then
    switch_mode_2()
else 
    switch_mode_1()
end

btn1.onClick = function () -- 切换模式1
    state_getter = switch_mode_1()
    current_mode = "1"
    push_current_state()

end

btn4.onClick = function () -- 切换模式2
    state_getter = switch_mode_2()
    current_mode = "2"
    push_current_state()
end

btn8.onClick = function () -- 选择音色表
    local retval, path = reaper.GetUserFileNameForRead("", "選擇音色表", "") -- 系统文件路径
    if not retval then return 0 end
    local bank_num = path:reverse():find('[%/%\\]')
    local bank_name = path:sub(-bank_num + 1) .. "" -- 音色表名称

    if string.match(bank_name, "%..+$") ~= ".reabank" then
        return reaper.MB("Please select reabank file with the suffix .reabank!\n請選擇後綴為 .reabank 的音色表！", "Error", 0),
        reaper.SN_FocusMIDIEditor()
    end

    reabank_path = path
    reaper.SetExtState("ArticulationMapPatchChangeGUI", "ReaBankPatch", reabank_path, true)

    if read_config_lines(reabank_path) == 1 or read_config_lines(reabank_path) == 0 then return end
    store = parse_banks(read_config_lines(reabank_path)) -- 模式1数据
    store_grouped = group_banks(store)                   -- 模式2数据

    state_getter = switch_mode_1()
    current_mode = "1"
    push_current_state()

    set_reabank_file(reabank_path)

    textb = Textbox:new(10,170,320,30, 0.7,0.7,0.7,0.3, bank_name, "Arial", 15, 0)
    Textbox_TB = { textb }
end

-- Main DRAW function

function DRAW()
    for key,btn     in pairs(Button_TB)   do btn:draw()    end
    for key,ch_box  in pairs(CheckBox_TB) do ch_box:draw() end
    for key, textb  in pairs(Textbox_TB)  do textb:draw()  end
    --for key,frame   in pairs(Frame_TB)    do frame:draw()  end -- 启用外框线
end

function saveExtState() -- 保存窗口信息
    local d,x,y,w,h=gfx.dock(-1,0,0,0,0)
    reaper.SetProjExtState(0, SCRIPT_NAME, "pExtState", pickle({
        x = x,y = y, d = d, w = w, h = h
    }))
end

function readExtState() -- 读取窗口信息
    local __, pExtStateStr = reaper.GetProjExtState(0, SCRIPT_NAME, "pExtState")
    local pExtState
    if pExtStateStr ~= "" then
        pExtState = unpickle(pExtStateStr)
    end 
    return pExtState
end

-- INIT

function Init()
    -- Some gfx Wnd Default Values
    local R,G,B = 240,240,240            -- 0..255 form
    local Wnd_bgd = R + G*256 + B*65536  -- red+green*256+blue*65536  
    local Wnd_Title = "Articulation Map Patch Change"

    local Wnd_Dock,Wnd_X,Wnd_Y = 0,800,320
    Wnd_W,Wnd_H = 340,250 -- global values(used for define zoom level) -- 脚本界面尺寸
    -- Init window
    gfx.clear = Wnd_bgd
    local pExtState = readExtState()
    if pExtState then
        gfx.init(Wnd_Title, pExtState.w, pExtState.h, pExtState.d, pExtState.x, pExtState.y)
    else 
        gfx.init( Wnd_Title, Wnd_W,Wnd_H, Wnd_Dock, Wnd_X, Wnd_Y )
    end

    -- Init mouse last
    last_mouse_cap = 0
    last_x, last_y = 0, 0
    mouse_ox, mouse_oy = -1, -1

    if reaper.JS_Window_FindEx then
        hwnd = reaper.JS_Window_Find(Wnd_Title, true)
        if hwnd then reaper.JS_Window_AttachTopmostPin(hwnd) end
    end
end

function mainloop()
    -- zoom level
    Z_w, Z_h = gfx.w/Wnd_W, gfx.h/Wnd_H
    if Z_w<0.6 then Z_w = 0.6 elseif Z_w>2 then Z_w = 2 end
    if Z_h<0.6 then Z_h = 0.6 elseif Z_h>2 then Z_h = 2 end 
    -- mouse and modkeys
    if gfx.mouse_cap&1==1   and last_mouse_cap&1==0  or   -- L mouse
       gfx.mouse_cap&2==2   and last_mouse_cap&2==0  or   -- R mouse
       gfx.mouse_cap&64==64 and last_mouse_cap&64==0 then -- M mouse
       mouse_ox, mouse_oy = gfx.mouse_x, gfx.mouse_y 
    end
    Ctrl  = gfx.mouse_cap&4==4
    Shift = gfx.mouse_cap&8==8
    Alt   = gfx.mouse_cap&16==16 -- Shift state

    DRAW() -- Main() 

    last_mouse_cap = gfx.mouse_cap
    last_x, last_y = gfx.mouse_x, gfx.mouse_y
    gfx.mouse_wheel = 0 -- reset gfx.mouse_wheel 
    char = gfx.getchar()
    if char == 13 then -- Enter 键
        if current_mode == "1" then
            local bank_item = store[ch_box1.norm_val]
            local note_item = bank_item.notes[ch_box2.norm_val]
            inset_patch(bank_item.bank.bank, note_item.note, bank_item.bank.velocity, midi_chan)
        elseif current_mode == "2" then
            local note_item = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val]
            inset_patch(note_item.bank, note_item.note, note_item.velocity, midi_chan)
        end
        gfx.quit()
    end
    if char ~= -1 then reaper.defer(mainloop) end -- defer
    if char == -1 or char == 27 then saveExtState() end -- saveState (window position)
    gfx.update()

end

Init()
mainloop()