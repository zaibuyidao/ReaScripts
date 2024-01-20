-- @description Set CC Lane
-- @version 1.2.3
-- @author zaibuyidao
-- @changelog
--   + Add Multi-Language Support
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

function main()
    reaper.Undo_BeginBlock()
    local title, captions_csv = "", ""
    if language == "简体中文" then
        title = "设置CC车道"
        captions_csv = "参数 (CC编号 或 v,p,g,c,b,t,s)"
    elseif language == "繁体中文" then
        title = "設置CC車道"
        captions_csv = "參數 (CC編號 或 v,p,g,c,b,t,s)"
    else
        title = "Set CC Lane"
        captions_csv = "Parameter (CC# or v,p,g,c,b,t,s)"
    end

    cc_lane = reaper.GetExtState("SET_CC_LANE", "Parameter")
    if (cc_lane == "") then cc_lane = "v" end
    uok, cc_lane = reaper.GetUserInputs(title, 1, captions_csv, cc_lane)
    reaper.SetExtState("SET_CC_LANE", "Parameter", cc_lane, false)
    if not uok then return end

    local HWND = reaper.MIDIEditor_GetActive()
    local take = reaper.MIDIEditor_GetTake(HWND)
    local parameter
    if cc_lane == "v" then
        parameter = 40237 -- CC: Set CC lane to Velocity
    elseif cc_lane == "p" then
        parameter = 40366 -- CC: Set CC lane to Pitch
    elseif cc_lane == "g" then
        parameter = 40367 -- CC: Set CC lane to Program
    elseif cc_lane == "c" then
        parameter = 40368 -- CC: Set CC lane to Channel Pressure
    elseif cc_lane == "b" then
        parameter = 40369 -- CC: Set CC lane to Bank/Program Select
    elseif cc_lane == "t" then
        parameter = 40370 -- CC: Set CC lane to Text Events
    elseif cc_lane == "s" then
        parameter = 40371 -- CC: Set CC lane to Sysex
    else
        cc_lane = tonumber(cc_lane)
        if cc_lane == nil or cc_lane < 0 or cc_lane > 119 then
            cc_lane = "v"
            reaper.SetExtState("SetCCLane", "Parameter", cc_lane, false)
            return reaper.SN_FocusMIDIEditor()
        end
        parameter = cc_lane + 40238 -- CC: Set CC lane to 000 Bank Select MSB
    end
    reaper.MIDIEditor_OnCommand(HWND, parameter)
    reaper.Undo_EndBlock(title, -1)
end
main()
reaper.SN_FocusMIDIEditor()