-- @description Articulation Map - Patch Change GUI
-- @version 1.9.0
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(...)
    local params = {...}
    for i = 1, #params do
        if i ~= 1 then reaper.ShowConsoleMsg(" ") end
        reaper.ShowConsoleMsg(tostring(params[i]))
    end
    reaper.ShowConsoleMsg("\n")
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
                        print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(tostring(pos)) + 8))
                        print(indent .. string.rep(" ", string.len(tostring(pos)) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. tostring(pos) .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(val))
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

function getSystemLanguage()
    local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))
    local os = reaper.GetOS()
    local lang

    if os == "Win32" or os == "Win64" then -- Windows
        if locale == 936 then -- Simplified Chinese
            lang = "简体中文"
        elseif locale == 950 then -- Traditional Chinese
            lang = "繁體中文"
        else -- English
            lang = "English"
        end
    elseif os == "OSX32" or os == "OSX64" then -- macOS
        local handle = io.popen("/usr/bin/defaults read -g AppleLocale")
        local result = handle:read("*a")
        handle:close()
        lang = result:gsub("_", "-"):match("[a-z]+%-[A-Z]+")
        if lang == "zh-CN" then -- 简体中文
            lang = "简体中文"
        elseif lang == "zh-TW" then -- 繁体中文
            lang = "繁體中文"
        else -- English
            lang = "English"
        end
    elseif os == "Linux" then -- Linux
        local handle = io.popen("echo $LANG")
        local result = handle:read("*a")
        handle:close()
        lang = result:gsub("%\n", ""):match("[a-z]+%-[A-Z]+")
        if lang == "zh_CN" then -- 简体中文
            lang = "简体中文"
        elseif lang == "zh_TW" then -- 繁體中文
            lang = "繁體中文"
        else -- English
            lang = "English"
        end
    end

    return lang
end

function getPathDelimiter()
    local os = reaper.GetOS()
    if os ~= "Win32" and os ~= "Win64" then
        return "/"
    else
        return "\\"
    end
end

SCRIPT_NAME = "PATCH_CHANGE_GUI"

local delimiter = getPathDelimiter()
local language = getSystemLanguage()

if language == "简体中文" then
    WINDOW_TITLE = "技法映射 - 音色更改"
    GLOBAL_FONT = "SimSun"
    FONT_SIZE = 12
    swsmsg = "该脚本需要 SWS 扩展，你想现在就下载它吗？"
    swserr = "警告"
    jsmsg = "请右键单击並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然后重新启动 REAPER 並再次运行脚本，谢谢！\n"
    jstitle = "你必须安裝 JS_ReaScriptAPI"
    jserr = "错误"
    setbank_msg = "请选择后缀为 .reabank 的音色表。"
    setbank_err = "错误"
    setpc_title = "设置 乐器组/力度/音符"
    setpc_retvals_csv = "乐器组,力度,音符"
    setpc_msg = "必须选择PC事件"
    setpc_err = "错误"
    click_to_refresh = " (点击刷新)"
    selbank_msg = "请选择一个音色表"
    selbank_err = "找不到音色表"
    selbank_path = "选择音色表"
    selbank_patch_msg = "请选择后缀为 .reabank 的音色表."
    selbank_patch_err = "错误"
    patch_change_load = "导入文件"
    patch_change_OK = "确定"
    patch_change_Cancel = "取消"
    patch_change_channel = "通道 :"
    patch_change_bank = "库  :"
    patch_change_patch = "音色:"
elseif language == "繁体中文" then
    WINDOW_TITLE = "技法映射 - 音色更改"
    GLOBAL_FONT = "SimSun"
    FONT_SIZE = 12
    swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
    swserr = "警告"
    jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
    jstitle = "你必須安裝 JS_ReaScriptAPI"
    jserr = "錯誤"
    setbank_msg = "請選擇後綴為 .reabank 的音色表。"
    setbank_err = "錯誤"
    setpc_title = "设置 樂器組/力度/音符"
    setpc_retvals_csv = "樂器組,力度,音符"
    setpc_msg = "必須選擇PC事件"
    setpc_err = "錯誤"
    click_to_refresh = " (點擊刷新)"
    selbank_msg = "請選擇一個音色表"
    selbank_err = "找不到音色表"
    selbank_path = "選擇音色表"
    selbank_patch_msg = "請選擇後綴為 .reabank 的音色表."
    selbank_patch_err = "錯誤"
    patch_change_load = "導入文件"
    patch_change_OK = "確定"
    patch_change_Cancel = "取消"
    patch_change_channel = "通道 :"
    patch_change_bank = "庫  :"
    patch_change_patch = "音色:"
else
    WINDOW_TITLE = "Articulation Map - Patch Change"
    GLOBAL_FONT = "Calibri"
    FONT_SIZE = 16
    swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
    swserr = "Warning"
    jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
    jstitle = "You must install JS_ReaScriptAPI"
    jserr = "Error"
    setbank_msg = "Please select reabank file with the suffix .reabank."
    setbank_err = "Error"
    setpc_title = "Set Group/Velocity/Note"
    setpc_retvals_csv = "Group,Velocity,Note"
    setpc_msg = "PC event must be selected"
    setpc_err = "Error"
    click_to_refresh = " (Click to refresh)"
    selbank_msg = "Please select a Reabank file"
    selbank_err = "Can't find reabank"
    selbank_path = "Choose a reabank"
    selbank_patch_msg = "Please select reabank file with the suffix .reabank."
    selbank_patch_err = "Error"
    patch_change_load = "Load File"
    patch_change_OK = "OK"
    patch_change_Cancel = "Cancel"
    patch_change_channel = "MIDI Channel :"
    patch_change_bank = "Bank :"
    patch_change_patch = "Patch:"
end

if not reaper.SNM_GetIntConfigVar then
    local retval = reaper.ShowMessageBox(swsmsg, swserr, 1)
    if retval == 1 then
        if not OS then local OS = reaper.GetOS() end
        if OS=="OSX32" or OS=="OSX64" then
            os.execute("open " .. "http://www.sws-extension.org/download/pre-release/")
        else
            os.execute("start " .. "http://www.sws-extension.org/download/pre-release/")
        end
    end
    return
end

if not reaper.APIExists("JS_Localize") then
    reaper.MB(jsmsg, jstitle, 0)
    local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
    if ok then
      reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
    else
      reaper.MB(err, jserr, 0)
    end
    return reaper.defer(function() end)
end

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not take or not reaper.TakeIsMIDI(take) then return end
local miditick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)

local function parse_bank(bank_line)
    return bank_line:match("Bank (%d+) (%d+) (.-)$")
end

local function parse_patch(bank_line)
    return bank_line:match("^%s*(%d+) (.-)$")
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

function table.sortByKey(tab,key,ascend)
    if ascend==nil then ascend=true end
    table.sort(tab,function(a,b)
        if ascend then return a[key]<b[key] end
        return a[key]>b[key]
    end)
end

-- function string.split(szFullString, szSeparator)  
--     local nFindStartIndex = 1  
--     local nSplitIndex = 1  
--     local nSplitArray = {}  
--     while true do  
--        local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)  
--        if not nFindLastIndex then  
--         nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))  
--         break  
--        end  
--        nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)  
--        nFindStartIndex = nFindLastIndex + string.len(szSeparator)  
--        nSplitIndex = nSplitIndex + 1  
--     end  
--     return nSplitArray  
-- end

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

local function get_reabank_file()
    local ini = read_file(reaper.get_ini_file())
    return ini and ini:match("mididefbankprog=([^\n]*)")
end

function refresh_bank() -- 刷新reabank
    count_sel_items = reaper.CountSelectedMediaItems(0)
    if count_sel_items > 0 then
        for i = 1, count_sel_items do
            local item = reaper.GetSelectedMediaItem(0, i - 1)
            local take = reaper.GetTake(item, 0)
            if not take or not reaper.TakeIsMIDI(take) then return end
            -- reaper.Main_OnCommand( 40716, 0 ) -- View: Toggle show MIDI editor windows
            -- reaper.Main_OnCommand( 40716, 1 ) -- View: Toggle show MIDI editor windows
            local retval, chunk = reaper.GetItemStateChunk(item, "", 0)
            reaper.SetItemStateChunk(item, chunk, 0)
        end
    else
        local editor = reaper.MIDIEditor_GetActive()
        local take = reaper.MIDIEditor_GetTake(editor)
        if not take or not reaper.TakeIsMIDI(take) then return end
        local item = reaper.GetMediaItemTake_Item(take)
        local retval, chunk = reaper.GetItemStateChunk(item, "", 0)
        reaper.SetItemStateChunk(item, chunk, 0)
        reaper.SN_FocusMIDIEditor()
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
    refresh_bank()
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

function get_script_path() -- 脚本路径
    local info = debug.getinfo(1,'S');
    local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
    return script_path
end

local reabank_path = reaper.GetExtState("ArticulationMapPatchChangeGUI", "ReaBankPatch")

if (reabank_path == "") then 
    reaper.ShowMessageBox(selbank_msg, selbank_path, 0)
    local retval, new_path = reaper.GetUserFileNameForRead("", selbank, "") -- 系统文件路径
    if not retval then return 0 end
    local bank_num = new_path:reverse():find('[%/%\\]')
    local bank_name = new_path:sub(-bank_num + 1) .. "" -- 音色表名称

    if string.match(bank_name, "%..+$") ~= ".reabank" then
        return reaper.MB(selbank_patch_msg, selbank_patch_err, 0),
        reaper.SN_FocusMIDIEditor()
    end
    reabank_path = new_path
    reaper.SetExtState("ArticulationMapPatchChangeGUI", "ReaBankPatch", reabank_path, true)
end

set_reabank_file(reabank_path)

function create_reabank_action(get_path) -- 创建音色表
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
    reaper.SN_FocusMIDIEditor()
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
    reaper.SN_FocusMIDIEditor()
end

reaper.gmem_attach('gmem_articulation_map')
gmem_cc_num = reaper.gmem_read(1)
gmem_cc_num = math.floor(gmem_cc_num)

local track = reaper.GetMediaItemTake_Track(take)
local pand = reaper.TrackFX_AddByName(track, "Articulation Map", false, 0)
if pand < 0 then
    gmem_cc_num = 119
end

function ToggleNotePC()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end

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
    if (reaper.SN_FocusMIDIEditor) then reaper.SN_FocusMIDIEditor() end
end

function set_group_velocity()
    -- local show_msg = reaper.GetExtState("ArticulationMapSetGroupVelocityNote", "ShowMsg")
    -- if (show_msg == "") then show_msg = "true" end

    -- if show_msg == "true" then
    --     script_name = "Set Group/Velocity/Note"
    --     text = "Select PC event to modify Instrument Group/Velocity/Note individually or together. If not, please leave it blank.\n選擇 PC 事件以單獨或一起修改樂器組/力度/音符。如果不執行請留空。"
    --     text = text.."\n\nWill this list be displayed next time?\n下次還顯示此列表嗎？"
    --     local box_ok = reaper.ShowMessageBox(""..text, script_name, 4)
    
    --     if box_ok == 7 then
    --         show_msg = "false"
    --         reaper.SetExtState("ArticulationMapSetGroupVelocityNote", "ShowMsg", show_msg, true)
    --     end
    -- end

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

function add_jsfx()
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
          if self:mouseRClick() and self.onRClick then self.onRClick() end -- if mouseR clicked and released, execute onRClick()
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
    if self:mouseClick() and self.onClick then self.onClick() end -- if mouse clicked and released, execute onClick()
    gfx.set(r,g,b,a) -- set the drawing colour for the e.Element
    self:draw_body()
    self:draw_frame()
    -- Draw label
    gfx.set(0, 0, 0, 1) -- set label color
    gfx.setfont(1, fnt, fnt_sz) -- set label font
    self:draw_label()
end

-- 按钮位置: 1-左 2-上 3-右 4-下
local btn1 = Button:new(10,10,25,30, 178/255,178/255,178/255,0.3, "A",GLOBAL_FONT,FONT_SIZE, 0)
local btn4 = Button:new(45,10,25,30, 0.7,0.7,0.7,0.3, "B",GLOBAL_FONT,FONT_SIZE, 0)
local btn5 = Button:new(80,10,25,30, 0.7,0.7,0.7,0.3, "<",GLOBAL_FONT,FONT_SIZE, 0)
local btn6 = Button:new(115,10,25,30, 0.7,0.7,0.7,0.3, ">",GLOBAL_FONT,FONT_SIZE, 0)
local btn7 = Button:new(150,10,25,30, 0.7,0.7,0.7,0.3, "NP",GLOBAL_FONT,FONT_SIZE, 0)
local btn10 = Button:new(185,10,25,30, 0.7,0.7,0.7,0.3, "PC",GLOBAL_FONT,FONT_SIZE, 0)
local btn9 = Button:new(220,10,25,30, 0.7,0.7,0.7,0.3, "RB",GLOBAL_FONT,FONT_SIZE, 0)
local btn11 = Button:new(255,10,75,30, 0.7,0.7,0.7,0.3, "Sus:CC#" .. gmem_cc_num,GLOBAL_FONT,FONT_SIZE, 0)
local btn8 = Button:new(10,210,100,30, 0.8,0.8,0.8,0.8, patch_change_load,GLOBAL_FONT,FONT_SIZE, 0)
local btn2 = Button:new(120,210,100,30, 0.8,0.8,0.8,0.8, patch_change_OK,GLOBAL_FONT,FONT_SIZE, 0)
local btn3 = Button:new(230,210,100,30, 0.8,0.8,0.8,0.8, patch_change_Cancel,GLOBAL_FONT,FONT_SIZE, 0)
local Button_TB = { btn1, btn2, btn3, btn4, btn5, btn6, btn7, btn8, btn9, btn10, btn11 }

-- x,y,w,h, r,g,b,a, lbl,fnt,fnt_sz, norm_val = check, norm_val2 = checkbox table
local ch_box1 = CheckBox:new(50,50,280,30,  0.8,0.8,0.8,0.3, patch_change_bank,GLOBAL_FONT,FONT_SIZE, 1, {})
local ch_box2 = CheckBox:new(50,90,280,30,  0.8,0.8,0.8,0.3, patch_change_patch,GLOBAL_FONT,FONT_SIZE, 1, {})
local ch_box3 = CheckBox:new(170,130,160,30,  0.8,0.8,0.8,0.3, patch_change_channel,GLOBAL_FONT,FONT_SIZE, 1, {"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16"})
local CheckBox_TB = {ch_box1, ch_box2, ch_box3}

local W_Frame = Frame:new(10,10,320,230,  0,0.9,0,0.1 ) -- 边框虚线尺寸
local Frame_TB = { W_Frame }

-- 文本框
local bank_num = reabank_path:reverse():find('[%/%\\]')
local bank_name = reabank_path:sub(-bank_num + 1) -- 音色表名称
local textb = Textbox:new(10,170,320,30, 0.8,0.8,0.8,0.3, bank_name..click_to_refresh, GLOBAL_FONT, FONT_SIZE, 0)
local Textbox_TB = { textb }

btn3.onClick = function () -- 按钮 退出
    gfx.quit()
    reaper.SN_FocusMIDIEditor()
end
btn5.onClick = function () slideF10() end -- 按钮 -10Tick
btn6.onClick = function () slideZ10() end -- 按钮 +10Tick
-- btn7.onClick = function () create_reabank_action(reabank_path) end -- 创建音色表脚本
btn7.onClick = function () ToggleNotePC() end -- 按钮 NOTE/PC 来回切
btn9.onClick = function () -- 按钮 编辑音色表
    local rea_patch = '\"'..reabank_path..'\"'
    edit_reabank = 'start "" '..rea_patch
    os.execute(edit_reabank)
end
btn10.onClick = function () set_group_velocity() end -- 按钮 设置乐器组参数
btn11.onClick = function () add_jsfx() end -- 按钮 添加表情映射插件
textb.onClick = function () refresh_bank() end -- 点击刷新reabank

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
        -- ch_box2.norm_val = 1 -- 新增判断
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
    btn2.onRClick = function ()
        local bank_item = store[ch_box1.norm_val]
        local note_item = bank_item.notes[ch_box2.norm_val]
        reaper.StuffMIDIMessage(0, 0xb0+midi_chan-1, 0, bank_item.bank.bank) -- MSB
        reaper.StuffMIDIMessage(0, 0xb0+midi_chan-1, 0x20, bank_item.bank.velocity) -- LSB
        reaper.StuffMIDIMessage(0, 0xc0+midi_chan-1, note_item.note, 0) -- Program
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
        -- ch_box2.norm_val = 1 -- 新增判断
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
    btn2.onRClick = function ()
        local note_item = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val]
        reaper.StuffMIDIMessage(0, 0xb0+midi_chan-1, 0, note_item.bank) -- MSB
        reaper.StuffMIDIMessage(0, 0xb0+midi_chan-1, 0x20, note_item.velocity) -- LSB
        reaper.StuffMIDIMessage(0, 0xc0+midi_chan-1, note_item.note, 0) -- Program
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
        return reaper.MB(setbank_msg, setbank_err, 0),
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

    textb = Textbox:new(10,170,320,30, 0.8,0.8,0.8,0.3, bank_name..click_to_refresh, GLOBAL_FONT, FONT_SIZE, 0)
    Textbox_TB = { textb }
end

btn8.onRClick = function () -- 右键点击刷新reabank
    if read_config_lines(reabank_path) == 1 or read_config_lines(reabank_path) == 0 then return end
    store = parse_banks(read_config_lines(reabank_path)) -- 模式1数据
    store_grouped = group_banks(store)                   -- 模式2数据

    state_getter = switch_mode_1()
    current_mode = "1"
    push_current_state()

    set_reabank_file(reabank_path)

    local bank_num = reabank_path:reverse():find('[%/%\\]')
    local bank_name = reabank_path:sub(-bank_num + 1) -- 音色表名称
    
    textb = Textbox:new(10,170,320,30, 0.8,0.8,0.8,0.3, bank_name..click_to_refresh, GLOBAL_FONT, FONT_SIZE, 0)
    Textbox_TB = { textb }

    refresh_bank()
end

-- Main DRAW function

function DRAW()
    for key,btn     in pairs(Button_TB)   do btn:draw()    end
    for key,ch_box  in pairs(CheckBox_TB) do ch_box:draw() end
    for key, textb  in pairs(Textbox_TB)  do textb:draw()  end
    -- for key,frame   in pairs(Frame_TB)    do frame:draw()  end -- 启用外框线
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
    local R, G, B = 240,240,240 -- 0..255 form
    local Wnd_bgd = R + G*256 + B*65536 -- red+green*256+blue*65536  

    local Wnd_Dock, Wnd_X, Wnd_Y = 0, 800, 320
    default_Wnd_W, default_Wnd_H = 340, 250 -- 默认窗口尺寸
    Wnd_W, Wnd_H = default_Wnd_W, default_Wnd_H -- 设置当前窗口尺寸为默认尺寸

    -- Init window
    gfx.clear = Wnd_bgd
    local pExtState = readExtState()
    if pExtState then
        gfx.init(WINDOW_TITLE, pExtState.w, pExtState.h, pExtState.d, pExtState.x, pExtState.y)
    else 
        gfx.init(WINDOW_TITLE, Wnd_W, Wnd_H, Wnd_Dock, Wnd_X, Wnd_Y)
    end

    -- Init mouse last
    last_mouse_cap = 0
    last_x, last_y = 0, 0
    mouse_ox, mouse_oy = -1, -1

    if reaper.JS_Window_FindEx then
        hwnd = reaper.JS_Window_Find(WINDOW_TITLE, true)
        if hwnd then reaper.JS_Window_AttachTopmostPin(hwnd) end
    end
end

function mainloop()
    -- 缩放级别
    -- Z_w, Z_h = gfx.w/Wnd_W, gfx.h/Wnd_H
    -- if Z_w<0.6 then Z_w = 0.6 elseif Z_w>2 then Z_w = 2 end
    -- if Z_h<0.6 then Z_h = 0.6 elseif Z_h>2 then Z_h = 2 end

    -- 锁定界面尺寸
    local cur_w, cur_h = gfx.w, gfx.h
    if cur_w ~= default_Wnd_W or cur_h ~= default_Wnd_H then
        local pExtState = readExtState()
        if pExtState then
            gfx.init(WINDOW_TITLE, default_Wnd_W, default_Wnd_H, pExtState.d, pExtState.x, pExtState.y)
        else
            gfx.init(WINDOW_TITLE, default_Wnd_W, default_Wnd_H, Wnd_Dock, Wnd_X, Wnd_Y)
        end
    end

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
    if char == 13 then -- Enter
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
    if char == 26161 then -- F1
        local rea_patch = '\"'..reabank_path..'\"'
        if not OS then local OS = reaper.GetOS() end
        if OS=="OSX32" or OS=="OSX64" then
            edit_reabank = 'open "" '..rea_patch
        else
            edit_reabank = 'start "" '..rea_patch
        end
        os.execute(edit_reabank)
    end

    if char == -1 or char == 27 then saveExtState() end -- saveState (window position)
    if char ~= -1 then reaper.defer(mainloop) end -- defer
    gfx.update()
end

Init()
mainloop()
