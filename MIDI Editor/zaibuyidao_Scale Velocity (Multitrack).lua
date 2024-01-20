-- @description Scale Velocity (Multitrack)
-- @version 1.3.1
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

function setVelocity()
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelNotes(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
  end
  
  if #index > 0 then
    local _, _, _, begin_ppqpos, _, _, _, _ = reaper.MIDI_GetNote(take, index[1])
    local _, _, _, end_ppqpos, _, _, _, _ = reaper.MIDI_GetNote(take, index[#index])
    local ppq_offset = (vel_end - vel_start) / (end_ppqpos - begin_ppqpos)
    for i = 1, #index do
      local _, _, _, startppqpos, _, _, _, vel = reaper.MIDI_GetNote(take, index[i])
      if toggle == "1" then
        if end_ppqpos ~= begin_ppqpos then
          new_vel = vel * (((startppqpos - begin_ppqpos) * ppq_offset + vel_start) / 100)
          velocity = math.floor(new_vel)
        else
          velocity = vel_start
        end
      else
        if end_ppqpos ~= begin_ppqpos then
          new_vel = (startppqpos - begin_ppqpos) * ppq_offset + vel_start
          velocity = math.floor(new_vel)
        else
          velocity = vel_start
        end
      end
      velocity = tonumber(velocity)
      if velocity > 127 then velocity = 127 elseif velocity < 1 then velocity = 1 end
      reaper.MIDI_SetNote(take, index[i], nil, nil, nil, nil, nil, nil, velocity, false)
    end
  end
end

function main()
  local title, captions_csv = "", ""
  if language == "简体中文" then
    title = "力度缩放"
    captions_csv = "开始,结束,0=绝对值 1=百分比"
  elseif language == "繁体中文" then
    title = "力度縮放"
    captions_csv = "開始,結束,0=絕對值 1=百分比"
  else
    title = "Scale Velocity"
    captions_csv = "Begin,End,0=Default 1=Percentages"
  end

  vel_start = reaper.GetExtState("SCALE_VELOCITY_MULIT", "Start")
  vel_end = reaper.GetExtState("SCALE_VELOCITY_MULIT", "End")
  toggle = reaper.GetExtState("SCALE_VELOCITY_MULIT", "Toggle")
  if (vel_start == "") then vel_start = "100" end
  if (vel_end == "") then vel_end = "100" end
  if (toggle == "") then toggle = "0" end

  local uok, uinput = reaper.GetUserInputs(title, 3, captions_csv, vel_start..','..vel_end..','.. toggle)
  if not uok then return reaper.SN_FocusMIDIEditor() end
  vel_start, vel_end, toggle = uinput:match("(%d*),(%d*),(%d*)")
  if not tonumber(vel_start) or not tonumber(vel_end) or not tonumber(toggle) then return reaper.SN_FocusMIDIEditor() end
  reaper.SetExtState("SCALE_VELOCITY_MULIT", "Start", vel_start, false)
  reaper.SetExtState("SCALE_VELOCITY_MULIT", "End", vel_end, false)
  reaper.SetExtState("SCALE_VELOCITY_MULIT", "Toggle", toggle, false)

  count_sel_items = reaper.CountSelectedMediaItems(0)
  reaper.Undo_BeginBlock()

  if count_sel_items > 0 then
    for i = 1, count_sel_items do
      item = reaper.GetSelectedMediaItem(0, i - 1)
      take = reaper.GetTake(item, 0)
      if not take or not reaper.TakeIsMIDI(take) then return end
      reaper.MIDI_DisableSort(take)
      setVelocity()
      reaper.MIDI_Sort(take)
    end
  else
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    reaper.MIDI_DisableSort(take)
    setVelocity()
    reaper.MIDI_Sort(take)
    reaper.Undo_EndBlock(title, -1)
  end
end

main()
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()