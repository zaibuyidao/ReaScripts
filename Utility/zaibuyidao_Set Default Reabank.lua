--[[
 * ReaScript Name: Set Default Reabank
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
 * Donation: http://www.paypal.me/zaibuyidao
 * provides: [main=main,midi_editor,midi_eventlisteditor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-7-31)
  + Initial release
--]]

function Msg(param) 
    reaper.ShowConsoleMsg(tostring(param) .. "\n") 
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

local function get_reabank_file()
    local ini = read_file(reaper.get_ini_file())
    return ini and ini:match("mididefbankprog=([^\n]*)")
end

local function set_reabank_file(reabank_path)

    local ini_file = reaper.get_ini_file()
    local ini, err = read_file(ini_file)

    if err then
        return
        reaper.MB("Failed to read REAPER's ini file\n無法讀取 REAPER 的 ini 文件", "Error", 0)
    end
    if ini:find("mididefbankprog=") then -- 如果找到 mididefbankprog=
        ini = ini:gsub("mididefbankprog=[^\n]*", "mididefbankprog=" .. reabank_path)
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
        reaper.MB("Failed to write ini file\n寫入ini文件失敗", "Error", 0)
    end

end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local retval, reabank_path = reaper.GetUserFileNameForRead("", "Select reabank file 選擇音色表", "") -- 系統文件路徑
if not retval then return 0 end
local bank_num = reabank_path:reverse():find('[%/%\\]')
local bank_name = reabank_path:sub(-bank_num + 1) .. "" -- 音色表名稱

if string.match(bank_name, "%..+$") ~= ".reabank" then
    return reaper.MB("Please select reabank file with the suffix .reabank!\n請選擇後綴為 .reabank 的音色表！", "Error", 0)
end

set_reabank_file(reabank_path)

local window, _, _ = reaper.BR_GetMouseCursorContext()
local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
if window == "midi_editor" and not inline_editor then reaper.SN_FocusMIDIEditor() end -- 聚焦 MIDI Editor

reaper.Undo_EndBlock("Set Default Reabank", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()