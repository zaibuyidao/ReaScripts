-- @description Notes To Pitch Bend (Pre-Grid Point)
-- @version 1.0
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

range = 12

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
  title = "音符变弯音"
  err_title = "错误"
  err_msg1 = "请检查音符间隔，并将其限制在一个八度内"
  err_msg2 = "请选择两个或更多音符"
elseif language == "繁体中文" then
  swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
  swserr = "警告"
  jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
  jstitle = "你必須安裝 JS_ReaScriptAPI"
  title = "音符變彎音"
  err_title = "錯誤"
  err_msg1 = "請檢查音符間隔，並將其限制在一個八度内"
  err_msg2 = "請選擇兩個或更多音符"
else
  swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
  swserr = "Warning"
  jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
  jstitle = "You must install JS_ReaScriptAPI"
  title = "Notes Become Pitch Bend"
  err_title = "Error"
  err_msg1 = "Please check the note interval and limit it to one octave."
  err_msg2 = "Please select two or more notes."
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

local editor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(editor)
if take == nil then return end

local cnt, index = 0, {}
local val = reaper.MIDI_EnumSelNotes(take, -1)
while val ~= - 1 do
  cnt = cnt + 1
  index[cnt] = val
  val = reaper.MIDI_EnumSelNotes(take, val)
end

function getSegments(n)
  local x = 8192
  local p = math.floor((x / n) + 0.5) -- 四舍五入
  local arr = {}
  local cur = 0
  for i = 1, n do
    cur = cur + p
    table.insert(arr, math.min(cur, x))
  end
  local res = {}
  for i = #arr, 1, -1 do
    table.insert(res, -arr[i])
  end
  table.insert(res, 0)
  for i = 1, #arr do
    table.insert(res, arr[i])
  end
  res[#res] = 8191 -- 将最后一个点强制设为8191，否则8192会被reaper处理为-8192
  return res
end

function pitchUp(o, targets)
  if #targets == 0 then error() end
  for i = 1, #targets do
    return targets[o + (range + 1)]
  end
end

function pitchDown(p, targets)
  if #targets == 0 then error() end
  for i = #targets, 1, -1 do
    return targets[p + (range + 1)]
  end
end

local pitch = {}
local startppqpos = {}
local endppqpos = {}
local vel = {}
local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local cur_gird, swing = reaper.MIDI_GetGrid(take)
local tick_gird = midi_tick * cur_gird

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

if #index > 1 then
  local prevLSB, prevMSB = 0, 64  -- 初始化前一个音符的弯音值为（0, 64）

  for i = 1, #index do
    retval, selected, muted, startppqpos[i], endppqpos[i], chan, pitch[i], vel[i] = reaper.MIDI_GetNote(take, index[i])
    if selected then
      if i > 1 then  -- 从第二个音符开始插入网格点
        reaper.MIDI_InsertCC(take, true, false, startppqpos[i]-tick_gird, 224, 0, prevLSB, prevMSB)
      end

      if pitch[i-1] then
        local pitchnote = (pitch[i]-pitch[1])
        local seg = getSegments(range)
        
        if pitchnote > 0 then
          pitchbend = pitchUp(pitchnote, seg)
        else
          pitchbend = pitchDown(pitchnote, seg)
        end
        
        if pitchbend == nil then return reaper.MB(err_msg1, err_title, 0) end

        LSB = pitchbend & 0x7F
        MSB = (pitchbend >> 7) + 64

        prevLSB, prevMSB = LSB, MSB  -- 更新前一个音符的弯音值

        reaper.MIDI_InsertCC(take, false, false, startppqpos[i], 224, 0, LSB, MSB)
      end

      if i == #index then
        j = reaper.MIDI_EnumSelNotes(take, -1)
        while j > -1 do
          reaper.MIDI_DeleteNote(take, j)
          j = reaper.MIDI_EnumSelNotes(take, -1)
        end
        if (pitch[1] ~= pitch[i]) then
          reaper.MIDI_InsertCC(take, false, false, endppqpos[i], 224, 0, 0, 64)
        end
        reaper.MIDI_InsertNote(take, selected, muted, startppqpos[1], endppqpos[i], chan, pitch[1], vel[1], true)
      end

      j = reaper.MIDI_EnumSelCC(take, -1) -- 选中CC设置形状
      while j ~= -1 do
        reaper.MIDI_SetCCShape(take, j, 1, 0, false)
        reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, false)
        j = reaper.MIDI_EnumSelCC(take, j)
      end
    end
  end
else
  reaper.MB(err_msg2, err_title, 0)
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.MIDIEditor_OnCommand(editor, 40366) -- CC: Set CC lane to Pitch