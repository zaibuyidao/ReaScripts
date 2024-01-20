-- @description Set Note Length
-- @version 1.5.1
-- @author zaibuyidao
-- @changelog
--   + Add Multi-Language Support
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @provides [main=main,midi_editor,midi_inlineeditor] .
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(...)
    for _, v in ipairs({...}) do
        reaper.ShowConsoleMsg(tostring(v) .. " ")
    end
    reaper.ShowConsoleMsg("\n")
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
elseif language == "繁体中文" then
    swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
    swserr = "警告"
    jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
    jstitle = "你必須安裝 JS_ReaScriptAPI"
else
    swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
    swserr = "Warning"
    jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
    jstitle = "You must install JS_ReaScriptAPI"
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

if not reaper.APIExists("JS_Window_Find") then
    reaper.MB(jsmsg, jstitle, 0)
    local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
    if ok then
        reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
    else
        reaper.MB(err, jserr, 0)
    end
    return reaper.defer(function() end)
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
local window, _, _ = reaper.BR_GetMouseCursorContext()
local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()

if language == "简体中文" then
    title = "设置音符长度"
    captions_csv = "输入嘀答数:"
elseif language == "繁体中文" then
    title = "設置音符長度"
    captions_csv = "輸入嘀答數:"
else
    title = "Set Note Length"
    captions_csv = "Enter A Tick:"
end

tick = reaper.GetExtState("SET_NOTE_LENGTH", "Ticks")
if (tick == "") then tick = "10" end
uok, tick = reaper.GetUserInputs(title, 1, captions_csv, tick)
reaper.SetExtState("SET_NOTE_LENGTH", "Ticks", tick, false)

if window == "midi_editor" then
    if not inline_editor then
        if not uok or not tonumber(tick) then return reaper.SN_FocusMIDIEditor() end
        take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    else
        take = reaper.BR_GetMouseCursorContext_Take()
    end
    reaper.MIDI_DisableSort(take)
    _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
    for i = 1, notecnt do
        _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
        if selected == true then
          reaper.MIDI_SetNote(take, i - 1, selected, muted, startppqpos, startppqpos + tick, chan, pitch, vel, false)
        end
    end
    if not inline_editor then reaper.SN_FocusMIDIEditor() end
    reaper.MIDI_Sort(take)
else
    if not uok or not tonumber(tick) then return end
    count_sel_items = reaper.CountSelectedMediaItems(0)
    if count_sel_items == 0 then return end
    for i = 1, count_sel_items do
        item = reaper.GetSelectedMediaItem(0, count_sel_items - i)
        take = reaper.GetTake(item, 0)
        reaper.MIDI_DisableSort(take)
        if reaper.TakeIsMIDI(take) then
            _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
            for i = 1, notecnt do
                _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
                reaper.MIDI_SetNote(take, i - 1, selected, muted, startppqpos, startppqpos + tick, chan, pitch, vel, false)
            end
        end
        reaper.MIDI_Sort(take)
    end
end
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)