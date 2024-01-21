-- @description Auto Expression
-- @version 1.3.3
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

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
if take == nil then return end

local cnt, index = 0, {}
local val = reaper.MIDI_EnumSelNotes(take, -1)
while val ~= - 1 do
  cnt = cnt + 1
  index[cnt] = val
  val = reaper.MIDI_EnumSelNotes(take, val)
end

if #index > 0 then
  if language == "简体中文" then
    title = "自动表情"
    captions_csv = "CC编号:,最小值:,最大值:"
  elseif language == "繁体中文" then
    title = "自動表情"
    captions_csv = "CC編號:,最小值:,最大值:"
  else
    title = "Auto expression"
    captions_csv = "CC Number:,Min value:,Max value:"
  end
  
  local cc_number = reaper.GetExtState("AUTO_EXPRESSION", "CC_Number")
  local min_val = reaper.GetExtState("AUTO_EXPRESSION", "Begin")
  local max_val = reaper.GetExtState("AUTO_EXPRESSION", "End")
  if (cc_number == "") then cc_number = "11" end
  if (min_val == "") then min_val = "90" end
  if (max_val == "") then max_val = "127" end

  local uok, uinput = reaper.GetUserInputs(title, 3, captions_csv, cc_number ..','.. min_val ..','.. max_val)
  cc_number, min_val, max_val = uinput:match("(.*),(.*),(.*)")
  if not uok or not tonumber(cc_number) or not tonumber(min_val) or not tonumber(max_val) then return reaper.SN_FocusMIDIEditor() end
  cc_number, min_val, max_val = tonumber(cc_number), tonumber(min_val), tonumber(max_val)
  if min_val > 127 or min_val < 0 or max_val > 127 or max_val < 0 or cc_number > 127 or cc_number < 0  then return reaper.SN_FocusMIDIEditor() end
  if min_val >= max_val then return reaper.SN_FocusMIDIEditor() end

  reaper.SetExtState("AUTO_EXPRESSION", "CC_Number", cc_number, false)
  reaper.SetExtState("AUTO_EXPRESSION", "Begin", min_val, false)
  reaper.SetExtState("AUTO_EXPRESSION", "End", max_val, false)

  local diff = max_val - min_val
  local startppqpos = {} -- 音符开头位置
  local endppqpos = {} -- 音符尾巴位置
  local tbl = {} -- 存储CC值

  for j = min_val, max_val do
    if j > 127 then j = 127 end
    if j > max_val then j = max_val end
    table.insert(tbl, j) -- 将计算得到的CC值存入tbl表
  end

  reaper.PreventUIRefresh(1) -- 防止UI刷新
  reaper.Undo_BeginBlock() -- 撤销块开始

  reaper.MIDI_DisableSort(take)
  for i = 1, #index do
    retval, selected, muted, startppqpos[i], endppqpos[i], chan, pitch, vel = reaper.MIDI_GetNote(take, index[i])
    if selected == true then
      ppq_len = endppqpos[i] - startppqpos[i]
      if ppq_len > 0 and ppq_len < tick/2 then -- 大于 0 并且 小于 240
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i], 0xB0, chan, cc_number, max_val)
      end
      if ppq_len >= tick/2 and ppq_len < tick then -- 大于等于 240 并且 小于 480
        for k, v in pairs(tbl) do
          local interval = math.floor((tick/4+tick/8+tick/48)/diff) -- 以 八分音符稍短 作为长度-190
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i]+(k-1)*interval, 0xB0, chan, cc_number, v)
        end
      end
      if ppq_len >= tick and ppq_len < tick*2 then -- 大于等于 480 并且 小于960
        for k, v in pairs(tbl) do
          local interval = math.floor((tick*0.75)/diff) -- 以 八分音符附点 作为长度-360
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i]+(k-1)*interval, 0xB0, chan, cc_number, v)
        end
      end
      if ppq_len == tick*2 then -- 等于 960
        for k, v in pairs(tbl) do
          local interval = math.floor(tick/diff) -- 以 四分音符 拍作为长度-480
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i]+(k-1)*interval, 0xB0, chan, cc_number, v)
        end
      end
      if ppq_len > tick*2 then -- 大于 960
        for k, v in pairs(tbl) do
          local interval = math.floor((tick*1.5)/diff) -- 以 四分音符附点 拍作为长度-720
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i]+(k-1)*interval, 0xB0, chan, cc_number, v)
        end
      end
      if ppq_len >= tick*2 then -- 大于等于 960, 插入减弱表情
        for k, v in pairs(tbl) do
          local interval = math.floor((tick/2+tick/12)/(diff-12)) -- 以 八分音符稍短 作为长度-280 并 将差值减去12
          if k >= 13 then -- 排序从第12个数开始，插入CC
            reaper.MIDI_InsertCC(take, selected, muted, endppqpos[i]-(tick/24)-(k-13)*interval, 0xB0, chan, cc_number, v) -- 尾巴减少 20 Tick
          end
        end
      end
    end
  end
  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock(title, -1) -- 撤销块结束
  reaper.PreventUIRefresh(-1) -- 恢复UI刷新
end

-- reaper.MIDIEditor_LastFocused_OnCommand(reaper.NamedCommandLookup("_RS7d3c_38c941e712837e405c3c662e2a39e3d03ffd5364"), 0) -- 移除冗余CCs
reaper.UpdateArrange() -- 更新排列
reaper.SN_FocusMIDIEditor() -- 聚焦MIDI编辑器