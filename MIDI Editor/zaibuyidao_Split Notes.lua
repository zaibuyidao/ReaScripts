-- @description Split Notes
-- @version 1.4.1
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

function SplitNotes(divLength)
  -- 檢查divLength參數是否存在
  if divLength == nil then return end

  -- 獲取當前的MIDI編輯器和音軌
  local midiEditor = reaper.MIDIEditor_GetActive()
  if midiEditor == nil then return end
  local activeTake = reaper.MIDIEditor_GetTake(midiEditor)
  if activeTake == nil then return end

  -- 禁用MIDI排序以提高效率
  reaper.MIDI_DisableSort(activeTake)
  local _, noteCount = reaper.MIDI_CountEvts(activeTake)

  -- 只有在有音符時才繼續
  if noteCount > 0 then
    local notes = {}
    
    -- 遍歷所有音符，並儲存其屬性
    for i = 1, noteCount do
      local note = {}
      _, note.isSelected, note.isMuted, note.startPos, note.endPos, note.channel, note.pitch, note.velocity = reaper.MIDI_GetNote(activeTake, i - 1)
      table.insert(notes, note)

      -- 檢查分割長度是否有效
      if note.isSelected and divLength > note.endPos - note.startPos then return end
    end

    -- 刪除原始音符
    for i = 1, noteCount do reaper.MIDI_DeleteNote(activeTake, 0) end

    -- 根據分割長度插入新音符
    for _, note in ipairs(notes) do
      if note.isSelected then
        local noteLength = note.endPos - note.startPos
        local divisionCount = math.floor(noteLength / divLength)

        for j = 1, divisionCount do
          reaper.MIDI_InsertNote(activeTake, note.isSelected, note.isMuted, note.startPos + (j - 1) * divLength, note.startPos + j * divLength, note.channel, note.pitch, note.velocity, false)
        end

        -- 處理剩餘的部分
        local remainingLength = note.startPos + divisionCount * divLength
        if remainingLength < note.endPos then
          reaper.MIDI_InsertNote(activeTake, note.isSelected, note.isMuted, remainingLength, note.endPos, note.channel, note.pitch, note.velocity, false)
        end
      else
        -- 對未選中的音符，直接插入原音符
        reaper.MIDI_InsertNote(activeTake, note.isSelected, note.isMuted, note.startPos, note.endPos, note.channel, note.pitch, note.velocity, false)
      end
    end

    -- 啟用並進行MIDI排序
    reaper.MIDI_Sort(activeTake)
  end
end

local title = ""
local captions_csv = ""
if language == "简体中文" then
  title = "分割音符"
  captions_csv = "长度 (tick):"
elseif language == "繁体中文" then
  title = "分割音符"
  captions_csv = "長度 (tick):"
else
  title = "Split Notes"
  captions_csv = "Length (tick):"
end

div_ret = reaper.GetExtState("SPLIT_NOTES", "Length")
if (div_ret == "") then div_ret = "240" end

uok, div_ret = reaper.GetUserInputs(title, 1, captions_csv, div_ret)
reaper.SetExtState("SPLIT_NOTES", "Length", div_ret, false)
div = tonumber(div_ret)
if not uok then return reaper.SN_FocusMIDIEditor() end

if div ~= nil then
  reaper.Undo_BeginBlock()  
  SplitNotes(div)
  reaper.Undo_EndBlock(title, -1)
end
reaper.SN_FocusMIDIEditor()