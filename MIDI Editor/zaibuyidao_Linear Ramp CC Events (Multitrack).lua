-- @description Linear Ramp CC Events (Multitrack)
-- @version 1.7.1
-- @author zaibuyidao
-- @changelog
--   + Add Multi-Language Support
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires SWS Extensions

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

function autoExp(tbl)
  i = reaper.MIDI_EnumSelNotes(take, -1)
  while i ~= -1 do
    retval, selected, muted, startppqpos[i], endppqpos[i], chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      ppq_len = endppqpos[i] - startppqpos[i]
      if ppq_len > 0 and ppq_len < tick/2 then -- 大於 0 並且 小於 240
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i], 0xB0, chan, cc_num, cc_end)
      end
      if ppq_len >= tick/2 and ppq_len < tick then -- 大於等於 240 並且 小於 480
        for k, v in pairs(tbl) do
          local interval = math.floor((tick/4+tick/8+tick/48)/diff) -- 以 八分音符(稍短) 作為長度-190
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i]+(k-1)*interval, 0xB0, chan, cc_num, v)
        end
      end
      if ppq_len >= tick and ppq_len < tick*2 then -- 大於等於 480 並且 小於960
        for k, v in pairs(tbl) do
          local interval = math.floor((tick*0.75)/diff) -- 以 八分音符附點 作為長度-360
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i]+(k-1)*interval, 0xB0, chan, cc_num, v)
        end
      end
      if ppq_len == tick*2 then -- 等於 960
        for k, v in pairs(tbl) do
          local interval = math.floor(tick/diff) -- 以 四分音符 拍作為長度-480
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i]+(k-1)*interval, 0xB0, chan, cc_num, v)
        end
      end
      if ppq_len > tick*2 then -- 大於 960
        for k, v in pairs(tbl) do
          local interval = math.floor((tick*1.5)/diff) -- 以 四分音符附點 拍作為長度-720
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i]+(k-1)*interval, 0xB0, chan, cc_num, v)
        end
      end
    end
    i = reaper.MIDI_EnumSelNotes(take, i)
  end
end

reaper.Undo_BeginBlock() -- 撤銷塊開始
reaper.PreventUIRefresh(1) -- 防止UI刷新

if language == "简体中文" then
  title = "线性斜坡CC事件"
  captions_csv = "最小值,最大值,CC编号,步长"
elseif language == "繁体中文" then
  title = "線性斜坡CC事件"
  captions_csv = "最小值,最大值,CC編號,步長"
else
  title = "Linear Ramp CC Events"
  captions_csv = "Min Value,Max Value,CC Number,Step"
end

cc_begin = reaper.GetExtState("LINER_RAMP_CC_EVENTS", "Begin")
if (cc_begin == "") then cc_begin = "90" end
cc_end = reaper.GetExtState("LINER_RAMP_CC_EVENTS", "End")
if (cc_end == "") then cc_end = "127" end
cc_num = reaper.GetExtState("LINER_RAMP_CC_EVENTS", "Number")
if (cc_num == "") then cc_num = "11" end
step = reaper.GetExtState("LINER_RAMP_CC_EVENTS", "Step")
if (step == "") then step = "1" end

local uok, uinput = reaper.GetUserInputs(title, 4, captions_csv, cc_begin ..','.. cc_end ..',' .. cc_num ..','.. step)
cc_begin, cc_end, cc_num, step = uinput:match("(.*),(.*),(.*),(.*)")
if not uok or not tonumber(cc_begin) or not tonumber(cc_end) or not tonumber(cc_num) or not tonumber(step) then return reaper.SN_FocusMIDIEditor() end
cc_begin, cc_end, cc_num, step = tonumber(cc_begin), tonumber(cc_end), tonumber(cc_num), tonumber(step)
if cc_begin > 127 or cc_begin < 0 or cc_end > 127 or cc_end < 0  then return reaper.SN_FocusMIDIEditor() end
if cc_begin >= cc_end then return reaper.SN_FocusMIDIEditor() end
reaper.SetExtState("LINER_RAMP_CC_EVENTS", "Number", cc_num, false)
reaper.SetExtState("LINER_RAMP_CC_EVENTS", "Begin", cc_begin, false)
reaper.SetExtState("LINER_RAMP_CC_EVENTS", "End", cc_end, false)
reaper.SetExtState("LINER_RAMP_CC_EVENTS", "Step", step, false)

tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
diff = cc_end - cc_begin
startppqpos = {} -- 音符开头位置
endppqpos = {} -- 音符尾巴位置

-- 生成CC值的表
function createCCValueTable(cc_begin, cc_end, step)
  local tb = {} -- 初始化存储CC值的表
  for j = cc_begin, cc_end, step do
    if j > 127 then j = 127 end -- 确保CC值不超过127
    table.insert(tb, j) -- 将计算得到的CC值存入tbl表
  end
  return tb -- 返回填充好的表
end

local tb = createCCValueTable(cc_begin, cc_end, step)
local count_sel_items = reaper.CountSelectedMediaItems(0)

if count_sel_items > 0 then
  for i = 1, count_sel_items do
    item = reaper.GetSelectedMediaItem(0, i - 1)
    take = reaper.GetTake(item, 0)
    if not take or not reaper.TakeIsMIDI(take) then return end
    reaper.MIDI_DisableSort(take)
    autoExp(tb)
    reaper.MIDI_Sort(take)
  end
else
  take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take or not reaper.TakeIsMIDI(take) then return end
  reaper.MIDI_DisableSort(take)
  autoExp(tb)
  reaper.MIDI_Sort(take)
end

-- reaper.MIDIEditor_LastFocused_OnCommand(reaper.NamedCommandLookup("_RS7d3c_38c941e712837e405c3c662e2a39e3d03ffd5364"), 0) -- 移除冗餘CCs
reaper.PreventUIRefresh(-1) -- 恢复UI刷新
reaper.UpdateArrange() -- 更新排列
reaper.Undo_EndBlock(title, -1) -- 撤銷塊結束
reaper.SN_FocusMIDIEditor() -- 聚焦MIDI編輯器