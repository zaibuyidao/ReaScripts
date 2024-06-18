-- @description Add MIDI Hardware Output & Receives to Selected Tracks (Transcription)
-- @version 1.0
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

function main()
    count_sel_track = reaper.CountSelectedTracks(0)
    if count_sel_track == 0 then return end
    local output_device = reaper.GetExtState("AddMIDIHardwareOutput", "Device")
    if (output_device == "") then output_device = "0" end
    local ordinal = reaper.GetExtState("AddMIDIHardwareOutput", "Ordinal")
    if (ordinal == "") then ordinal = "1" end
    local maxval = reaper.GetExtState("AddMIDIHardwareOutput", "MaxVal")
    if (maxval == "") then maxval = "16" end
    local track_num = reaper.GetExtState("AddMIDIHardwareOutput", "Track")
    if (track_num == "") then track_num = "1" end
    local toggle = reaper.GetExtState("AddMIDIHardwareOutput", "Toggle")
    if (toggle == "") then toggle = "dft" end

    if language == "简体中文" then
        title = "添加MIDI硬件输出和接收到选定轨道"
        captions_csv = "MIDI硬件输出:,发送通道开始:,发送通道结束:,接收轨道编号:,模式 (dft/ch/recv/rmv):"
    elseif language == "繁體中文" then
        title = "添加MIDI硬件輸出和接收到選定軌道"
        captions_csv = "MIDI硬件輸出:,發送通道開始:,發送通道結束:,接收軌道編號:,模式 (dft/ch/recv/rmv):"
    else
        title = "Add MIDI Hardware Output & Receives to Selected Tracks (Transcription)"
        captions_csv = "MIDI Hardware Output:,Send to Channel Start:,Send to Channel End:,Receive from Track:,Mode (dft/ch/recv/rmv):"
    end

    local uok, uinput = reaper.GetUserInputs(title, 5, captions_csv, output_device ..','.. ordinal ..','.. maxval ..','.. track_num ..','.. toggle)
    output_device, ordinal, maxval, track_num, toggle = uinput:match("(.*),(.*),(.*),(.*),(.*)")
    if not uok or not tonumber(output_device) or not tonumber(ordinal) or not tonumber(maxval) or not tonumber(track_num) or not tostring(toggle) then return end

    reaper.SetExtState("AddMIDIHardwareOutput", "Device", output_device, false)
    reaper.SetExtState("AddMIDIHardwareOutput", "Ordinal", ordinal, false)
    reaper.SetExtState("AddMIDIHardwareOutput", "MaxVal", maxval, false)
    reaper.SetExtState("AddMIDIHardwareOutput", "Track", track_num, false)
    reaper.SetExtState("AddMIDIHardwareOutput", "Toggle", toggle, false)

    maxval, output_device = tonumber(maxval), tonumber(output_device)
    ordinal = ordinal - 1
    reaper.Undo_BeginBlock()
    if toggle == "dft" then
        commandID_03 = reaper.NamedCommandLookup("_S&M_SENDS5") -- SWS/S&M: Remove receives from selected tracks
        reaper.Main_OnCommand(commandID_03, 0)
        for i = 1, count_sel_track do
            select_track = reaper.GetSelectedTrack(0, i - 1)
            channel = i + ordinal
            if channel >= maxval then channel = maxval end
            if channel < 1 or channel > 16 then channel = 0 end
            number = channel | output_device << 5
            reaper.SetMediaTrackInfo_Value(select_track,"I_MIDIHWOUT", number)
            track_to_receive = reaper.GetTrack(0, track_num - 1)
            reaper.CreateTrackSend(track_to_receive, select_track)
            commandID_02 = reaper.NamedCommandLookup("_SWS_MUTERECVS") -- SWS: Mute all receives for selected track(s)
            reaper.Main_OnCommand(commandID_02, 0)
            commandID_01 = reaper.NamedCommandLookup("_SWS_DISMPSEND") -- SWS: Disable master/parent send on selected track(s)
            reaper.Main_OnCommand(commandID_01, 0)
        end
    elseif toggle == "ch" then
        for i = 1, count_sel_track do
            select_track = reaper.GetSelectedTrack(0, i - 1)
            channel = i + ordinal
            if channel >= maxval then channel = maxval end
            if channel < 1 or channel > 16 then channel = 0 end
            number = channel | output_device << 5
            reaper.SetMediaTrackInfo_Value(select_track,"I_MIDIHWOUT", number)
        end
        -- commandID_01 = reaper.NamedCommandLookup("_SWS_DISMPSEND") -- SWS: Disable master/parent send on selected track(s)
        -- reaper.Main_OnCommand(commandID_01, 0)
    elseif toggle == "recv" then
        commandID_03 = reaper.NamedCommandLookup("_S&M_SENDS5") -- SWS/S&M: Remove receives from selected tracks
        reaper.Main_OnCommand(commandID_03, 0)
        for i = 1, count_sel_track do
            select_track = reaper.GetSelectedTrack(0, i - 1)
            track_to_receive = reaper.GetTrack(0, track_num - 1)
            reaper.CreateTrackSend(track_to_receive, select_track)
        end
        commandID_02 = reaper.NamedCommandLookup("_SWS_MUTERECVS") -- SWS: Mute all receives for selected track(s)
        reaper.Main_OnCommand(commandID_02, 0)
        -- commandID_01 = reaper.NamedCommandLookup("_SWS_DISMPSEND") -- SWS: Disable master/parent send on selected track(s)
        -- reaper.Main_OnCommand(commandID_01, 0)
    elseif toggle == "rmv" then
        for i = 1, count_sel_track do
            select_track = reaper.GetSelectedTrack(0, i - 1)
            number = 0 | -1 << 5
            reaper.SetMediaTrackInfo_Value(select_track,"I_MIDIHWOUT", number)
        end
        commandID_03 = reaper.NamedCommandLookup("_S&M_SENDS5") -- SWS/S&M: Remove receives from selected tracks
        reaper.Main_OnCommand(commandID_03, 0)
        commandID_04 = reaper.NamedCommandLookup("_SWS_ENMPSEND") -- SWS: Enable master/parent send on selected track(s)
        reaper.Main_OnCommand(commandID_04, 0)
    end
    reaper.Undo_EndBlock(title, -1)
end
reaper.PreventUIRefresh(1)
main()
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()