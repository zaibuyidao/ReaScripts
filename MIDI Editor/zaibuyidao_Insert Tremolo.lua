-- @description Insert Tremolo
-- @version 1.0.1
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
if take == nil then return reaper.SN_FocusMIDIEditor() end

local cc_num = reaper.GetExtState("InsertTremolo", "CC_Num")
local cc_begin = reaper.GetExtState("InsertTremolo", "CC_Begin")
local cc_end = reaper.GetExtState("InsertTremolo", "CC_End")
local cishu = reaper.GetExtState("InsertTremolo", "Cishu")
local tick = reaper.GetExtState("InsertTremolo", "Tick")

if (cc_num == "") then cc_num = "11" end
if (cc_begin == "") then cc_begin = "100" end
if (cc_end == "") then cc_end = "70" end
if (cishu == "") then cishu = "8" end
if (tick == "") then tick = "120" end

if language == "简体中文" then
    title = "插入颤音"
    captions_csv = "CC编号,1,2,重复,间隔"
elseif language == "繁体中文" then
    title = "插入顫音"
    captions_csv = "CC編號,1,2,重複,間隔"
else
    title = "Insert Tremolo"
    captions_csv = "CC Number,1,2,Repetition,Interval"
end

local uok, captions_csv = reaper.GetUserInputs(title, 5, captions_csv, cc_num ..','.. cc_begin ..','.. cc_end ..','.. cishu ..','.. tick)
if not uok then return reaper.SN_FocusMIDIEditor() end
cc_num, cc_begin, cc_end, cishu, tick = captions_csv:match("(.*),(.*),(.*),(.*),(.*)")
if not (tonumber(cc_num) or tonumber(cc_begin) or tonumber(cc_end) or tonumber(cishu) or tonumber(tick)) then
    return reaper.SN_FocusMIDIEditor()
end

reaper.SetExtState("InsertTremolo", "CC_Num", cc_num, false)
reaper.SetExtState("InsertTremolo", "CC_Begin", cc_begin, false)
reaper.SetExtState("InsertTremolo", "CC_End", cc_end, false)
reaper.SetExtState("InsertTremolo", "Cishu", cishu, false)
reaper.SetExtState("InsertTremolo", "Tick", tick, false)

cc_num, cc_begin, cc_end, cishu, tick = tonumber(cc_num), tonumber(cc_begin), tonumber(cc_end), tonumber(cishu), tonumber(tick)
selected = true
chan = 0

reaper.Undo_BeginBlock()

local cuspos = reaper.GetCursorPositionEx(0)
local ppqpos = reaper.MIDI_GetPPQPosFromProjTime(take, cuspos)
local bolang = {cc_begin, cc_end}
ppqpos = ppqpos - tick

for j = 1, cishu do
    for k = 1, #bolang do
        ppqpos = ppqpos + tick
        reaper.MIDI_InsertCC(take, selected, false, ppqpos, 0xB0, chan, cc_num, bolang[k])
    end
end

reaper.Undo_EndBlock(title, -1)
reaper.SN_FocusMIDIEditor()
reaper.UpdateArrange()