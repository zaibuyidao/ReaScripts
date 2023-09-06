-- @description Toggle Select Notes in Measure Groups (After)
-- @version 1.0.2
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not take or not reaper.TakeIsMIDI(take) then return end

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
    title = "切换音符选择"
    lable = "输入小节数"
elseif language == "繁体中文" then
    swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
    swserr = "警告"
    jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
    jstitle = "你必須安裝 JS_ReaScriptAPI"
    title = "切換音符選擇"
    lable = "輸入小節數"
else
    swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
    swserr = "Warning"
    jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
    jstitle = "You must install JS_ReaScriptAPI"
    title = "Toggle Note Selection"
    lable = "Enter measure count"
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

-- 获取选中音符的小节
function getNoteMeasureStart(noteStartPPQ)
    local time = reaper.MIDI_GetProjTimeFromPPQPos(take, noteStartPPQ)
    local _, measure = reaper.TimeMap2_timeToBeats(0, time)
    return math.floor(measure)
end

-- 获取起始和结束小节
function getStartEndMeasures()
    local _, numNotes = reaper.MIDI_CountEvts(take)
    local startMeasure, endMeasure = math.huge, -math.huge

    for i = 0, numNotes - 1 do
        local _, sel, _, startppq, _, _, _, _ = reaper.MIDI_GetNote(take, i)
        if sel then
            local measure = getNoteMeasureStart(startppq)
            startMeasure = math.min(startMeasure, measure)
            endMeasure = math.max(endMeasure, measure)
        end
    end

    return startMeasure, endMeasure
end

-- 在指定的小节范围内根据用户输入选中音符
function selectNotesBasedOnUserInput(startMeasure, endMeasure, userCount)
    local _, numNotes = reaper.MIDI_CountEvts(take)
    local cycle = userCount * 2
    for i = 0, numNotes - 1 do
        local _, selected, _, startppq, _, _, _, _ = reaper.MIDI_GetNote(take, i)

        if selected then  -- 仅对已选中的音符操作
            local measure = getNoteMeasureStart(startppq) - startMeasure + 1

            if (measure - 1) % cycle >= userCount then
                reaper.MIDI_SetNote(take, i, true, nil, nil, nil, nil, nil, nil, false)
            else
                reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
            end
        end
    end
end

-- 检查指定的小节范围内是否有音符被选中
function areNotesSelectedInSpecifiedMeasures(startMeasure, endMeasure, userCount)
    local _, numNotes = reaper.MIDI_CountEvts(take)
    local cycle = userCount * 2
    for i = 0, numNotes - 1 do
        local _, selected, _, startppq, _, _, _, _ = reaper.MIDI_GetNote(take, i)
        local measure = getNoteMeasureStart(startppq) - startMeasure + 1

        if selected and (measure - 1) % cycle >= userCount then
            return true
        end
    end
    return false
end

-- 主函数
local startMeasure, endMeasure = getStartEndMeasures()
local retval, userCount = reaper.GetUserInputs(title, 1, lable, "2")
userCount = tonumber(userCount)

reaper.Undo_BeginBlock()
if retval and userCount and areNotesSelectedInSpecifiedMeasures(startMeasure, endMeasure, userCount) then
    selectNotesBasedOnUserInput(startMeasure, endMeasure, userCount)
end
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()