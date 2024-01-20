-- @description Humanize Velocity
-- @version 1.5.2
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

local title, captions_csv = "", ""
if language == "简体中文" then
  title = "力度人性化"
  captions_csv = "强度:"
elseif language == "繁体中文" then
  title = "力度人性化"
  captions_csv = "強度:"
else
  title = "Humanize Velocity"
  captions_csv = "Strength:"
end

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local _, noteCount, _, _ = reaper.MIDI_CountEvts(take)
local strength = reaper.GetExtState("HUMANIZE_VELOCITY", "Strength")
if (strength == "") then strength = "3" end
local uok, uinput = reaper.GetUserInputs(title, 1, captions_csv, strength)
if not uok then return reaper.SN_FocusMIDIEditor() end
strength = tonumber(uinput:match("(.*)"))
reaper.SetExtState("HUMANIZE_VELOCITY", "Strength", tostring(strength), false)
reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
for i = 0,  noteCount - 1 do
  local _, isSelected, muted, startppqpos, endppqpos, chan, pitch, velocity = reaper.MIDI_GetNote(take, i)
  if isSelected then
    local velocityChange = math.random(-strength, strength)
    local newVelocity = velocity + velocityChange
    if newVelocity > 127 then newVelocity = 127 end
    if newVelocity < 1 then newVelocity = 1 end
    reaper.MIDI_SetNote(take, i, isSelected, muted, startppqpos, endppqpos, chan, pitch, math.floor(newVelocity), false)
  end
end
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()