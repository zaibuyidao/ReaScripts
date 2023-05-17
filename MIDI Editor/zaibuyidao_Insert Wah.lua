-- @description Insert Wah
-- @version 1.5.1
-- @author zaibuyidao
-- @changelog Init
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
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

local language = getSystemLanguage()

if language == "简体中文" then
    swsmsg = "该脚本需要 SWS 扩展，你想现在就下载它吗？"
    swserr = "警告"
    jsmsg = "请右键单击並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然后重新启动 REAPER 並再次运行脚本，谢谢！\n"
    jstitle = "你必须安裝 JS_ReaScriptAPI"
    jserr = "错误"
elseif language == "繁体中文" then
    swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
    swserr = "警告"
    jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
    jstitle = "你必須安裝 JS_ReaScriptAPI"
    jserr = "錯誤"
else
    swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
    swserr = "Warning"
    jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
    jstitle = "You must install JS_ReaScriptAPI"
    jserr = "Error"
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

function get_ext_state_with_default(section, key, default)
    local value = reaper.GetExtState(section, key)
    if value == "" then
        return default
    else
        return value
    end
end

local cc_num = get_ext_state_with_default("InsertWah", "CCNum", "74")
local cc_begin = get_ext_state_with_default("InsertWah", "CCBegin", "32")
local cc_end = get_ext_state_with_default("InsertWah", "CCEnd", "64")
local cishu = get_ext_state_with_default("InsertWah", "Repetition", "8")
local tick_01 = get_ext_state_with_default("InsertWah", "Length", "480")
local tick_02 = get_ext_state_with_default("InsertWah", "Interval", "20")

if language == "简体中文" then
    title = "插入哇音"
    captions_csv = "CC编号,1,2,重复,长度,间隔"
elseif language == "繁体中文" then
    title = "插入哇音"
    captions_csv = "CC編號,1,2,重複,長度,間隔"
else
    title = "Insert Wah"
    captions_csv = "CC Number,1,2,Repetition,Length (tick),Interval (tick)"
end

local uok, captions_csv = reaper.GetUserInputs(title, 6, captions_csv, cc_num ..','.. cc_begin ..','.. cc_end ..','.. cishu ..','.. tick_01 ..','.. tick_02)
if not uok then return reaper.SN_FocusMIDIEditor() end

cc_num, cc_begin, cc_end, cishu, tick_01, tick_02 = captions_csv:match("(.*),(.*),(.*),(.*),(.*),(.*)")
if not (tonumber(cc_num) or tonumber(cc_begin) or tonumber(cc_end) or tonumber(cishu) or tonumber(tick_01) or tonumber(tick_02)) then
    return reaper.SN_FocusMIDIEditor()
end
cc_num, cc_begin, cc_end, cishu, tick_01, tick_02 = tonumber(cc_num), tonumber(cc_begin), tonumber(cc_end), tonumber(cishu), tonumber(tick_01), tonumber(tick_02)

local states = {
    CCNum = cc_num,
    CCBegin = cc_begin,
    CCEnd = cc_end,
    Repetition = cishu,
    Length = tick_01,
    Interval = tick_02
}

for key, value in pairs(states) do
    reaper.SetExtState("InsertWah", key, value, false)
end

function wah()
    local pos = reaper.GetCursorPositionEx()
    local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
    local bolang = {cc_begin,cc_end}
    ppq = ppq - tick_01
    for j = 1, cishu do
        for k = 1, #bolang do
            ppq = ppq + tick_01
            reaper.MIDI_InsertCC(take, selected, false, ppq, 0xB0, 0, cc_num, bolang[k])
        end
    end

    -- 在循环结束后插入 cc_begin
    ppq = ppq + tick_01
    reaper.MIDI_InsertCC(take, selected, false, ppq, 0xB0, 0, cc_num, cc_begin)
end

function GetCC(take, cc)
    return cc.selected, cc.muted, cc.ppqpos, cc.chanmsg, cc.chan, cc.msg2, cc.msg3
end

function main()
    if take ~= nil then
        retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
        if ccs == 0 then return end

        midi_cc = {}

        for j = 0, ccs - 1 do
            cc = {}
            retval, cc.selected, cc.muted, cc.ppqpos, cc.chanmsg, cc.chan, cc.msg2, cc.msg3 = reaper.MIDI_GetCC(take, j)
            if not midi_cc[cc.msg2] then midi_cc[cc.msg2] = {} end
            table.insert(midi_cc[cc.msg2], cc)
        end

        cc_events = {}
        cc_events_len = 0

        for key, val in pairs(midi_cc) do
            for k = 1, #val - 1 do
                a_selected, a_muted, a_ppqpos, a_chanmsg, a_chan, a_msg2, a_msg3 = GetCC(take, val[k])
                b_selected, b_muted, b_ppqpos, b_chanmsg, b_chan, b_msg2, b_msg3 = GetCC(take, val[k + 1])
                if a_selected == true and b_selected == true then
                    time_interval = (b_ppqpos - a_ppqpos) / interval
                    for z = 1, interval - 1 do
                        cc_events_len = cc_events_len + 1
                        cc_events[cc_events_len] = {}
                        c_ppqpos = a_ppqpos + time_interval * z
                        c_msg3 = math.floor(((b_msg3 - a_msg3) / interval * z + a_msg3) + 0.5)
                        cc_events[cc_events_len].ppqpos = c_ppqpos
                        cc_events[cc_events_len].chanmsg = a_chanmsg
                        cc_events[cc_events_len].chan = a_chan
                        cc_events[cc_events_len].msg2 = a_msg2
                        cc_events[cc_events_len].msg3 = c_msg3
                    end
                end
            end
        end

        for i, cc in ipairs(cc_events) do
            reaper.MIDI_InsertCC(take, selected, false, cc.ppqpos, cc.chanmsg, cc.chan, cc.msg2, cc.msg3)
        end
    end
end

selected = true
interval = tick_01 / tick_02

reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
wah()
main()
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()