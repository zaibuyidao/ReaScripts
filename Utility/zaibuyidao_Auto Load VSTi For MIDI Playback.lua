-- @description Auto Load VSTi For MIDI Playback
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

local section = "AutoLoadVSTiForMIDIPlayback"
local key = "VSTiName"

-- 尝试获取保存的 VSTi 名称
local vstiName = reaper.GetExtState(section, key)

if vstiName == "" then
    vstiName = "SOUND Canvas VA"
end

reaper.PreventUIRefresh(1) -- 防止界面更新
reaper.Undo_BeginBlock() -- 撤销块开始
-- 插入一条新的音轨
local new_track_idx = reaper.CountTracks(0)
reaper.InsertTrackAtIndex(new_track_idx, true)
local new_track = reaper.GetTrack(0, new_track_idx)

if language == "简体中文" then
    title = "自动加载 VSTi 以进行 MIDI 回放"
    msgset = "无法找到指定的 VSTi 插件。\n\n请通过脚本 'zaibuyidao_Auto Load VSTi For MIDI Playback (Settings).lua' 设置 VSTi 名称。"
    msgerr = "错误"
elseif language == "繁體中文" then
    title = "自動加載 VSTi 以進行 MIDI 回放"
    msgset = "無法找到指定的 VSTi 插件。\n\n請通過腳本 'zaibuyidao_Auto Load VSTi For MIDI Playback (Settings).lua' 設置 VSTi 名稱。"
    msgerr = "錯誤"
else
    title = "Auto Load VSTi For MIDI Playback"
    msgset = "Unable to find the specified VSTi plugin.\n\nPlease set the VSTi name through the script 'zaibuyidao_Auto Load VSTi For MIDI Playback (Settings).lua'."
    msgerr = "Error"
end

-- 在新音轨上添加 VSTi 插件
local fxIdx = reaper.TrackFX_AddByName(new_track, vstiName, false, 1)

if fxIdx == -1 then
    reaper.ShowMessageBox(msgset, msgerr, 0)
else
    -- 去除名称中的 "VSTi: " 前缀并设置为轨道名称
    local trackName = string.gsub(vstiName, "VSTi: ", "")
    reaper.GetSetMediaTrackInfo_String(new_track, "P_NAME", trackName, true)
    -- 为除新音轨外的所有音轨添加接收
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        if track ~= new_track then
            reaper.SNM_AddReceive(track, new_track, -1) -- 添加接收，类型为默认
        end
    end
end
reaper.Undo_EndBlock(title, -1) -- 撤销块结束
reaper.PreventUIRefresh(-1) -- 恢复界面更新
reaper.UpdateArrange() -- 更新界面显示