-- NoIndex: true
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

local delimiter = getPathDelimiter()

function checkArticulationMapJSFX()
    local jsfx_path = reaper.GetResourcePath() .. delimiter .. "Effects" .. delimiter .. "zaibuyidao Scripts" .. delimiter .. "JSFX" .. delimiter .. "Articulation Map.jsfx"
    -- 检查路径是否存在
    local jsfx_file = io.open(jsfx_path, "r")
    if jsfx_file == nil then
        reaper.MB(checkamjs_msg, checkamjs_title, 0)
        local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
        if ok then
          reaper.ReaPack_BrowsePackages("zaibuyidao Articulation Map")
        else
          reaper.MB(err, jserr, 0)
        end
        return reaper.defer(function() end)
    end
    -- 关闭文件句柄
    jsfx_file:close()
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

function get_script_path() -- 脚本路径
    local info = debug.getinfo(1,'S');
    local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
    return script_path
end

function parse_bank(bank_line)
    return bank_line:match("Bank (%d+) (%d+) (.-)$")
end

function parse_patch(bank_line)
    return bank_line:match("^%s*(%d+) (.-)$")
end

function get_reabank_file()
    local ini = read_file(reaper.get_ini_file())
    return ini and ini:match("mididefbankprog=([^\n]*)")
end

function refresh_bank() -- 刷新reabank
    count_sel_items = reaper.CountSelectedMediaItems(0)
    if count_sel_items > 0 then
        -- for i = 1, count_sel_items do
        --     local item = reaper.GetSelectedMediaItem(0, i - 1)
        --     local take = reaper.GetTake(item, 0)
        --     if not take or not reaper.TakeIsMIDI(take) then return end
        --     -- reaper.Main_OnCommand(40716, 0) -- View: Toggle show MIDI editor windows
        --     -- reaper.Main_OnCommand(40716, 1) -- View: Toggle show MIDI editor windows
        --     local retval, chunk = reaper.GetItemStateChunk(item, "", 0)
        --     reaper.SetItemStateChunk(item, chunk, 0)
        -- end

        reaper.Main_OnCommand(42465, 0) -- Main Section: MIDI: Reload track support data (bank/program files, notation, etc) for all MIDI items on selected tracks
    else
        local editor = reaper.MIDIEditor_GetActive()
        local take = reaper.MIDIEditor_GetTake(editor)
        if not take or not reaper.TakeIsMIDI(take) then return end
        local item = reaper.GetMediaItemTake_Item(take)
        local retval, chunk = reaper.GetItemStateChunk(item, "", 0)
        reaper.SetItemStateChunk(item, chunk, 0)
        --reaper.SN_FocusMIDIEditor()

        reaper.MIDIEditor_OnCommand(editor, 42102) -- MIDI Editor: Reload track support data (bank/program files, notation, etc)
    end
end

function set_reabank_file(reabank_path)
    local ini_file = reaper.get_ini_file()
    if not ini_file then return end
    local ini, err = read_file(ini_file)

    if err then
        return
        reaper.MB(setbank2_msg, setbank2_err, 0),
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
        reaper.MB(setbank2_msg2, setbank2_err, 0),
        reaper.SN_FocusMIDIEditor()
    end
end

function parse_banks(lines, vel_show, bnk_show) -- 音色名称
    if #lines == 0 then
        -- 没有行数据时，返回默认项
        return {{bank = {full_name = "未选择音色库", bank = "N/A", velocity = "N/A", name = "N/A"}, notes = {}}}
    end
    local result = {}
    for _, line in ipairs(lines) do
        if #line == 0 or line:match("^%s-$") then
            goto continue
        end

        local bank, velocity, name = parse_bank(line)
        if bank and velocity and name then
            local full_name
            if vel_show and bnk_show then
                full_name = "" .. bank .. " : " .. bank*128+velocity .. " - " .. name .. " (" .. line_velocity .. velocity .. ")"
            elseif vel_show and not bnk_show then
                full_name = "" .. bank .. " : " .. name .. " (" .. line_velocity .. velocity .. ")"
            elseif not vel_show and bnk_show then
                full_name = "" .. bank .. " : " .. bank*128+velocity .. " - " .. name
            else -- vel_show = false ，bnk_show = false
                full_name = "" .. bank .. " : " .. name
            end
            table.insert(result, {
                bank = {
                    full_name = full_name,
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

function group_banks(banks, vel_show)
    if #banks == 0 or (banks[1] and banks[1].bank and banks[1].bank.full_name == "未选择音色库") then
        -- 没有银行数据时，返回默认项
        return {{bank = {full_name = "未选择音色库", bank = "N/A", velocity = "N/A", name = "N/A"}, notes = {}}}
    end
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
            local full_name
            if vel_show then
                full_name = note_item.note .. " " .. note_item.name .. " (" .. line_velocity .. bank_item.bank.velocity .. ")" -- 当velocity show为true时显示velocity
            else
                full_name = note_item.note .. " " .. note_item.name -- 当velocity show为false时不显示velocity
            end
            table.insert(result[bank_item.bank.bank].notes, {
                full_name = full_name,
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

function get_reabank_file_path()
    local ini = read_file(reaper.get_ini_file())
    local str = ini and ini:match("mididefbankprog=([^\n]*)")
    if str then
        return str
    else
        return ""
    end
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

function read_config_lines(reabank_path)
    local file = io.open(reabank_path, "r")
    if not file then
        return {}  -- 文件打不开时返回空表
    end
    local temp = {}
    for line in file:lines() do
        table.insert(temp, line)
    end
    return process_lines(temp)
end

function normalize_color(r, g, b, a)
    return {r / 255, g / 255, b / 255, a}
end

function getActiveMIDITrack()
    local midiEditor = reaper.MIDIEditor_GetActive()
    if midiEditor then
        local take = reaper.MIDIEditor_GetTake(midiEditor)
        if take then
            return reaper.GetMediaItemTake_Track(take)
        end
    end
    return nil
end

function selectReaBankFile()
    local function extractFileName(filePath)
        if type(filePath) ~= "string" or not filePath:find('[%/%\\]') then
            return "<未知文件>"
        end
        local bankNum = filePath:reverse():find('[%/%\\]')
        local bankName = filePath:sub(-bankNum + 1)
        return bankName
    end

    local track = getActiveMIDITrack()
    if track then
        local retval, trackStateChunk = reaper.GetTrackStateChunk(track, "", false)
        if retval and string.find(trackStateChunk, "MIDIBANKPROGFN") then
            local existingPath = trackStateChunk:match("MIDIBANKPROGFN \"([^\"]*)\"")
            if existingPath then
                return existingPath, extractFileName(existingPath)
            end
        end
    end

    local ini_file = reaper.get_ini_file()
    local ini, err = read_file(ini_file)
    if ini and ini:find("mididefbankprog=") then
        local defaultReaBankPath = ini:match("mididefbankprog=([^\n]*)")
        if defaultReaBankPath and defaultReaBankPath ~= "" then
            return defaultReaBankPath, extractFileName(defaultReaBankPath)
        end
    end

    -- 如果找不到 reabank 文件，返回空表
    return "NoReabank", "<无音色配置文件>"
end

function reSelectReaBankFile() -- 重新选择reabank
    local function extractFileName(filePath)
        local bankNum = filePath:reverse():find('[%/%\\]')
        local bankName = filePath:sub(-bankNum + 1)
        return bankName
    end

    local retval, filePath = reaper.GetUserFileNameForRead("", selbank_path, ".reabank")
    if retval then
        return filePath, extractFileName(filePath)
    end
end

function applyReaBankToTrack(track, reabankPath)
    local track = getActiveMIDITrack()
    if not track then return false end

    local ret, trackStateChunk = reaper.GetTrackStateChunk(track, "", false)
    if ret and trackStateChunk then
        local bankString = "MIDIBANKPROGFN \"" .. reabankPath .. "\"\n"
        if string.find(trackStateChunk, "MIDIBANKPROGFN") then
            trackStateChunk = string.gsub(trackStateChunk, "MIDIBANKPROGFN \"[^\"]*\"", bankString)
        else
            trackStateChunk = trackStateChunk:gsub("<TRACK", "<TRACK\n" .. bankString)
        end

        return reaper.SetTrackStateChunk(track, trackStateChunk, false)
    end
    return false
end

function getFileName(filePath)
    -- 检查 filePath 是否为字符串
    if type(filePath) == "string" and filePath ~= "" then
        local bankNum = filePath:reverse():find('[%/%\\]')
        if bankNum then
            return filePath:sub(-bankNum + 1)
        else
            return filePath
        end
    else
        -- 如果 filePath 不是字符串或为空字符串，则返回默认文件名
        return "<无音色配置文件>"
    end
end