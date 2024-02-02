-- @description Copy Tempo/Time Signature In Time Selection (Relative Position)
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   + New Script
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
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
elseif language == "繁體中文" then
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

local EXT_SECTION = 'COPY_TEMPO_MARKERS'

-- 序列化标记/区域数据
local function serialize(marker)
    local str = ''
    for _, value in ipairs(marker) do
        str = str .. type(value) .. '\31' .. tostring(value) .. '\30'
    end
    return str
end

-- 序列化拍号/速度信息
local function serializeTempoMarker(tempoMarker)
    local str = ''
    for _, value in ipairs(tempoMarker) do
        str = str .. type(value) .. '\31' .. tostring(value) .. '\30'
    end
    return str
end

-- 生成键名
local function makeKey(index, prefix)
    prefix = prefix or "marker"
    return string.format("%s%03d", prefix, index)
end

-- 清除扩展状态中的旧数据
local function clearExtState()
    local numMarkers = reaper.CountProjectMarkers(0)
    local numTempoMarkers = reaper.CountTempoTimeSigMarkers(0)
    for i = 1, numMarkers + numTempoMarkers do -- 确保删除所有可能的标记和节拍标记
        reaper.DeleteExtState(EXT_SECTION, makeKey(i), false)
        reaper.DeleteExtState(EXT_SECTION, makeKey(i, "tempo"), false)
    end
end

function main()
    -- 检查是否存在时间选区
    local startTime, endTime = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if startTime == endTime then
        if language == "简体中文" then
            msgTitle = "未进行时间选择。请先选择一个时间范围以进行复制。"
            msgError = "错误"
        elseif language == "繁體中文" then
            msgTitle = "未進行時間選擇。請先選擇一個時間範圍以進行複製。"
            msgError = "錯誤"
        else
            msgTitle = "No time selection made. Please select a time range to copy first."
            msgError = "Error"
        end

        reaper.ShowMessageBox(msgTitle, msgError, 0)
        return
    end

    -- 执行复制操作
    reaper.Main_OnCommand(40698, 0) -- 编辑: 复制项目

    clearExtState()  -- 清除旧数据

    local timeSelectionStart, timeSelectionEnd = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    local numTempoMarkers = reaper.CountTempoTimeSigMarkers(0)
    local copied = 0
    local copiedTempoMarkers = 0

    -- print("时间选区开始: " .. timeSelectionStart .. ", 结束: " .. timeSelectionEnd)

    -- 保存时间选区的起点和终点
    reaper.SetExtState(EXT_SECTION, "timeSelectionStart", tostring(timeSelectionStart), false)
    reaper.SetExtState(EXT_SECTION, "timeSelectionEnd", tostring(timeSelectionEnd), false)

    -- 复制拍号和速度信息
    for i = 0, numTempoMarkers - 1 do
        local retval, timePos, measurePos, beatPos, bpm, timesig_num, timesig_denom, lineartempo = reaper.GetTempoTimeSigMarker(0, i)
        if timePos >= timeSelectionStart and timePos <= timeSelectionEnd then
            copiedTempoMarkers = copiedTempoMarkers + 1
            local tempoMarkerData = {timePos, measurePos, beatPos, bpm, timesig_num, timesig_denom, lineartempo}
            reaper.SetExtState(EXT_SECTION, makeKey(copiedTempoMarkers, "tempo"), serializeTempoMarker(tempoMarkerData), false)
        end
    end
end

main()
