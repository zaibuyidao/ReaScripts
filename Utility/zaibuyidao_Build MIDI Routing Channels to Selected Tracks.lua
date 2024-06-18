-- @description Build MIDI Routing Channels to Selected Tracks
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

local ZBYDFuncPath = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Utility/zaibuyidao_Functions.lua'
if reaper.file_exists(ZBYDFuncPath) then
  dofile(ZBYDFuncPath)
  if not checkSWSExtension() or not checkJSAPIExtension() then return end
else
  local errorMsg = "Error - Missing Script (错误 - 缺失脚本)\n\n" ..
  "[English]\nThe required 'zaibuyidao Functions' script file was not found. Please ensure the file is correctly placed at:\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\nIf the file is missing, you can install it via ReaPack by searching for 'zaibuyidao Functions' in the ReaPack package browser.\n\n" ..
  "[中文]\n必需的 'zaibuyidao Functions' 脚本文件未找到。请确保文件正确放置在以下位置：\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\n如果文件缺失，您可以通过 ReaPack 包浏览器搜索并安装 'zaibuyidao Functions'。\n"

  reaper.MB(errorMsg, "Missing Script Error/脚本文件缺失错误", 0)

  if reaper.APIExists('ReaPack_BrowsePackages') then
    reaper.ReaPack_BrowsePackages('zaibuyidao Functions')
  else
    local reapackErrorMsg = "Error - ReaPack Not Found (错误 - 未找到 ReaPack)\n\n" ..
    "[English]\nThe ReaPack extension is not found. Please install ReaPack to manage and install REAPER scripts and extensions easily. Visit https://reapack.com for installation instructions.\n\n" ..
    "[中文]\n未找到 ReaPack 扩展。请安装 ReaPack 来便捷地管理和安装 REAPER 脚本及扩展。访问 https://reapack.com 获取安装指南。\n"

    reaper.MB(reapackErrorMsg, "ReaPack Not Found/未找到 ReaPack", 0)
  end
  return
end

local language = getSystemLanguage()

count_sel_track = reaper.CountSelectedTracks(0)
if count_sel_track == 0 then return end

sel_track_name = {}
for i = 0, count_sel_track-1 do
    local select_track = reaper.GetSelectedTrack(0, i)
    local _, get_track_name = reaper.GetTrackName(select_track, "")
    sel_track_name[#sel_track_name+1] = get_track_name
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

for i = 0, count_sel_track-1 do
    local select_track = reaper.GetSelectedTrack(0, i)
    local select_track_num = reaper.GetMediaTrackInfo_Value(select_track,'IP_TRACKNUMBER')
    local isVSTi = reaper.TrackFX_GetInstrument(select_track) -- 判斷是否為VSTi

    if language == "简体中文" then
        title = "创建MIDI路由通道到选定轨道"
        utitle = "创建MIDI路由通道到 "
        captions_csv = "通道总数:,起始通道:"
        msgvst = "未能检测到 VSTi 插件。请确保已正确加载了 VSTi 插件。"
        msgerr = "错误"
    elseif language == "繁體中文" then
        title = "創建MIDI路由通道到選定軌道"
        utitle = "創建MIDI路由通道到 "
        captions_csv = "通道總數:,起始通道:"
        msgvst = "未能檢測到 VSTi 插件。請確保已正確加載了 VSTi 插件。"
        msgerr = "錯誤"
    else
        title = "Build MIDI Routing Channels to Selected Tracks"
        utitle = "Build MIDI Routing Channels to "
        captions_csv = "Total number of channels:,Starting channel:"
        msgvst = "VSTi plugin not detected. Please ensure that a VSTi plugin is correctly loaded."
        msgerr = "Error"
    end

    if isVSTi == -1 then
        return reaper.ShowMessageBox(msgvst, msgerr, 0)
    end

    local channel_total = reaper.GetExtState("BuildMIDIRoutingChannelstoSelectedTracks", "Total")
    if (channel_total == "") then channel_total = "16" end
    local channel_ordinal = reaper.GetExtState("BuildMIDIRoutingChannelstoSelectedTracks", "Ordinal")
    if (channel_ordinal == "") then channel_ordinal = "1" end
    
    local uok, uinput = reaper.GetUserInputs(utitle .. sel_track_name[i+1], 2, captions_csv, channel_total ..','.. channel_ordinal)

    channel_total, channel_ordinal = uinput:match("(.*),(.*)")
    if not uok or not tonumber(channel_total) or not tonumber(channel_ordinal) then return end
    channel_total, channel_ordinal = tonumber(channel_total), tonumber(channel_ordinal)

    reaper.SetExtState("BuildMIDIRoutingChannelstoSelectedTracks", "Total", channel_total, false)
    reaper.SetExtState("BuildMIDIRoutingChannelstoSelectedTracks", "Ordinal", channel_ordinal, false)

    for j = 1, channel_total do
        reaper.InsertTrackAtIndex((select_track_num-1)+j, false) -- 插入轨道
        track_to_send = reaper.GetTrack(0,(select_track_num-1)+j) -- 创建MIDI路由通道轨道
        name_ok, track_name = reaper.GetSetMediaTrackInfo_String(select_track, 'P_NAME', '', 0) -- 获取轨道名称
        if track_name ~= '' then track_name = track_name .. ' ' end
        
        local channel = (channel_ordinal-1)+j
        reaper.GetSetMediaTrackInfo_String(track_to_send, 'P_NAME', track_name ..'MIDI '.. channel, true) -- 设置轨道名称
        reaper.SetMediaTrackInfo_Value(track_to_send, "B_MAINSEND", 0) -- 禁用主/父发送
        reaper.CreateTrackSend(track_to_send, select_track)

        reaper.SetTrackSendInfo_Value(track_to_send, 0, 0, 'I_SRCCHAN', -1)

        if channel < 1 or channel > 16 then channel = 0 end
        if channel == '0' then channel = 'All' end
        reaper.SetTrackSendInfo_Value(track_to_send, 0, 0, 'I_MIDIFLAGS', channel << 5)
    end
end
reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()