-- @description Quantize
-- @version 1.2.4
-- @author zaibuyidao
-- @changelog Initial release
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
local tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local cur_grid, swing = reaper.MIDI_GetGrid(take)
-- local _, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)

note_cnt, note_idx = 0, {}
note_val = reaper.MIDI_EnumSelNotes(take, -1)
while note_val ~= -1 do
    note_cnt = note_cnt + 1
    note_idx[note_cnt] = note_val
    note_val = reaper.MIDI_EnumSelNotes(take, note_val)
end

ccs_cnt, ccs_idx = 0, {}
ccs_val = reaper.MIDI_EnumSelCC(take, -1)
while ccs_val ~= -1 do
    ccs_cnt = ccs_cnt + 1
    ccs_idx[ccs_cnt] = ccs_val
    ccs_val = reaper.MIDI_EnumSelCC(take, ccs_val)
end

sys_cnt, sys_idx = 0, {}
sys_val = reaper.MIDI_EnumSelTextSysexEvts(take, -1)
while sys_val ~= -1 do
    sys_cnt = sys_cnt + 1
    sys_idx[sys_cnt] = sys_val
    sys_val = reaper.MIDI_EnumSelTextSysexEvts(take, sys_val)
end

local grid = reaper.GetExtState("Quantize", "Grid")
if (grid == "") then grid = "120" end
local toggle = reaper.GetExtState("Quantize", "Toggle")
if (toggle == "") then toggle = "dft" end

if language == "简体中文" then
    title = "量化"
    captions_csv = "输入嘀嗒数,量化 (dft/start/end/pos)"
elseif language == "繁体中文" then
    title = "量化"
    captions_csv = "輸入嘀嗒数,量化 (dft/start/end/pos)"
else
    title = "Quantize"
    captions_csv = "Enter A Tick,Qnz (dft/start/end/pos)"
end

local uok, uinput = reaper.GetUserInputs(title, 2, captions_csv, grid ..','.. toggle)
grid, toggle = uinput:match("(.*),(.*)")
if not uok or not tonumber(grid) or not tostring(toggle) then return reaper.SN_FocusMIDIEditor() end

reaper.SetExtState("Quantize", "Grid", grid, false)
reaper.SetExtState("Quantize", "Toggle", toggle, false)
grid = grid / tick

function StartTimes()
    for i = 1, #note_idx do
        local _, selected, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, note_idx[i])
        if selected then
            local start_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
            local end_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)
            local beats_01, _, _, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_note_qn)
            local beats_02, _, _, end_cdenom = reaper.TimeMap2_timeToBeats(0, end_note_qn)
            local out_pos, out_ppq, out_beatpos
            if swing == 0 then
                if (end_cdenom - start_cdenom) < (grid / 2) and (beats_02 % grid) > (grid / 2) then
                    out_beatpos = start_cdenom - (beats_01 % grid)
                elseif (beats_01 % grid) < (grid / 2) then
                    out_beatpos = start_cdenom - (beats_01 % grid)
                else
                    out_beatpos = start_cdenom - (beats_01 % grid) + grid
                end
                out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
                out_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, out_pos)
            end
            reaper.MIDI_SetNote(take, note_idx[i], true, nil, out_ppq, nil, nil, nil, nil, false)
        end
    end
end
function Position()
    for i = 1, #note_idx do
        local _, selected, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, note_idx[i])
        if selected then
            local start_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
            local end_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)
            local beats_01, _, _, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_note_qn)
            local beats_02, _, _, end_cdenom = reaper.TimeMap2_timeToBeats(0, end_note_qn)
            local out_pos, out_ppq, out_beatpos
            if swing == 0 then
                if (end_cdenom - start_cdenom) < (grid / 2) and (beats_02 % grid) > (grid / 2) then
                    out_beatpos = start_cdenom - (beats_01 % grid)
                elseif (beats_01 % grid) < (grid / 2) then
                    out_beatpos = start_cdenom - (beats_01 % grid)
                else
                    out_beatpos = start_cdenom - (beats_01 % grid) + grid
                end
                out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
                out_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, out_pos)
                endppqpos = endppqpos - (startppqpos - out_ppq)
            end
            reaper.MIDI_SetNote(take, note_idx[i], true, nil, out_ppq, endppqpos, nil, nil, nil, false)
        end
    end
end
function NoteDurations()
    for i = 1, #note_idx do
        local _, selected, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, note_idx[i])
        if selected then
            local start_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
            local end_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)
            local beats_01, _, _, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_note_qn)
            local beats_02, _, _, end_cdenom = reaper.TimeMap2_timeToBeats(0, end_note_qn)
            local out_pos, out_ppq, out_beatpos
            if swing == 0 then
                if (end_cdenom - start_cdenom) < (grid / 2) and (beats_01 % grid) < (grid / 2) then
                    out_beatpos = end_cdenom - (beats_02 % grid) + grid
                elseif (beats_02 % grid) < (grid / 2) then
                    out_beatpos = end_cdenom - (beats_02 % grid)
                else
                    out_beatpos = end_cdenom - (beats_02 % grid) + grid
                end
                out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
                out_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, out_pos)
            end
            reaper.MIDI_SetNote(take, note_idx[i], true, nil, nil, out_ppq, nil, nil, nil, false)
        end
    end
end
function CCEvents()
    for i = 1, #ccs_idx do
        local _, selected, _, ppqpos, _, _, _, _ = reaper.MIDI_GetCC(take, ccs_idx[i])
        if selected then
            local start_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)
            local beats_01, _, _, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_qn)
            local out_pos, out_ppq, out_beatpos
            if swing == 0 then
                if (beats_01 % grid) < (grid / 2) then
                    out_beatpos = start_cdenom - (beats_01 % grid)
                else
                    out_beatpos = start_cdenom - (beats_01 % grid) + grid
                end
                out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
                out_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, out_pos)
            end
            reaper.MIDI_SetCC(take, ccs_idx[i], true, nil, out_ppq, nil, nil, nil, nil, false)
        end
    end
end
function TextSysEvents()
    for i = 1, #sys_idx do
        local _, selected, _, ppqpos, _, _ = reaper.MIDI_GetTextSysexEvt(take, sys_idx[i])
        if selected then
            local start_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)
            local beats_01, _, _, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_qn)
            local out_pos, out_ppq, out_beatpos
            if swing == 0 then
                if (beats_01 % grid) < (grid / 2) then
                    out_beatpos = start_cdenom - (beats_01 % grid)
                else
                    out_beatpos = start_cdenom - (beats_01 % grid) + grid
                end
                out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
                out_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, out_pos)
            end
            reaper.MIDI_SetTextSysexEvt(take, sys_idx[i], true, nil, out_ppq, nil, nil, false) 
        end
    end
end
function main()
    reaper.Undo_BeginBlock()
    reaper.MIDI_DisableSort(take)
    
    local flag

    if reaper.GetToggleCommandStateEx(32060, 40681) == 1 then
        reaper.MIDIEditor_LastFocused_OnCommand(40681,0) -- Options: Correct overlapping notes while editing
        flag = true
    end
    if toggle == "pos" then
        Position()
    elseif toggle == "end" then
        NoteDurations()
    elseif toggle == "start" then
        StartTimes()
    elseif toggle == "dft" then
        StartTimes()
        NoteDurations()
        CCEvents()
        TextSysEvents()
    end
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40659)
    reaper.MIDI_Sort(take)

    if flag then
        reaper.MIDIEditor_LastFocused_OnCommand(40681,0) -- Options: Correct overlapping notes while editing
    end

    reaper.Undo_EndBlock(title, -1)
end

main()
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()