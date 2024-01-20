-- @description Scale Control
-- @version 1.0.2
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

if not reaper.SN_FocusMIDIEditor then
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
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelCC(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelCC(take, val)
  end

  reaper.Undo_BeginBlock()
  reaper.MIDI_DisableSort(take)
  if #index > 0 then
    local title, captions_csv = "", ""
    if language == "简体中文" then
      title = "控制器缩放"
      captions_csv = "开始,结束,0=绝对值 1=百分比"
    elseif language == "繁体中文" then
      title = "控制器縮放"
      captions_csv = "開始,結束,0=絕對值 1=百分比"
    else
      title = "Scale Control"
      captions_csv = "Begin,End,0=Default 1=Percentages"
    end

    local val_start = reaper.GetExtState("SCALE_CONTROL", "Start")
    local val_end = reaper.GetExtState("SCALE_CONTROL", "End")
    local toggle = reaper.GetExtState("SCALE_CONTROL", "Toggle")
    if (val_start == "") then val_start = "100" end
    if (val_end == "") then val_end = "100" end
    if (toggle == "") then toggle = "0" end

    local uok, uinput = reaper.GetUserInputs(title, 3, captions_csv, val_start..','..val_end..','.. toggle)
    if not uok then return reaper.SN_FocusMIDIEditor() end
    val_start, val_end, toggle = uinput:match("(%d*),(%d*),(%d*)")
    if not val_start:match('[%d%.]+') or not val_end:match('[%d%.]+') or not toggle:match('[%d%.]+') then return reaper.SN_FocusMIDIEditor() end
    reaper.SetExtState("SCALE_CONTROL", "Start", val_start, false)
    reaper.SetExtState("SCALE_CONTROL", "End", val_end, false)
    reaper.SetExtState("SCALE_CONTROL", "Toggle", toggle, false)

    local _, _, _, begin_ppqpos, _, _, _, _ = reaper.MIDI_GetCC(take, index[1])
    local _, _, _, end_ppqpos, _, _, _, _ = reaper.MIDI_GetCC(take, index[#index])
    local ppq_offset = (val_end - val_start) / (end_ppqpos - begin_ppqpos)

    for i = 1, #index do
      local _, _, _, startppqpos, _, _, _, value = reaper.MIDI_GetCC(take, index[i])
      if toggle == "1" then
        if end_ppqpos ~= begin_ppqpos then
          new_val = value * (((startppqpos - begin_ppqpos) * ppq_offset + val_start) / 100)
          x = math.floor(new_val)
        else
          x = val_start
        end
      else
        if end_ppqpos ~= begin_ppqpos then
          new_val = (startppqpos - begin_ppqpos) * ppq_offset + val_start
          x = math.floor(new_val)
        else
          x = val_start
        end
      end
      if x > 127 then x = 127 elseif x < 1 then x = 1 end
      reaper.MIDI_SetCC(take, index[i], nil, nil, nil, nil, nil, nil, x, false)
    end
  end
  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock(title, -1)
end

main()
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()