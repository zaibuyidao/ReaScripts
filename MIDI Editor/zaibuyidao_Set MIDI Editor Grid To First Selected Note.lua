-- @description Set MIDI Editor Grid To First Selected Note
-- @version 1.0
-- @author zaibuyidao
-- @changelog Initial release
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
    title = "将MIDI编辑器网格设置为第一个选定的音符"
elseif language == "繁体中文" then
    title = "將MIDI編輯器網格設定為第一個選取的音符"
else
    title = "Set MIDI Editor Grid To First Selected Note"
end

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not take or not reaper.TakeIsMIDI(take) then return end
local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local cnt, index = 0, {}
local val = reaper.MIDI_EnumSelNotes(take, -1)
if val ~= -1 then sel_note = true end
while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
end
reaper.Undo_BeginBlock()
if #index > 1 then -- 所有选中的音符，以最开头的音符长度作为网格值
    local _, _, _, startpos, endpos, _, _, _ = reaper.MIDI_GetNote(take, index[1])
    local notelen = endpos-startpos
    division = notelen / (midi_tick * 4)
    reaper.SetMIDIEditorGrid(project, division)
elseif #index == 1 then -- 选中一个音符，以当前音符长度作为网格值
    local _, _, _, startpos, endpos, _, _, _ = reaper.MIDI_GetNote(take, index[1])
    local notelen = endpos-startpos
    division = notelen / (midi_tick * 4)
    reaper.SetMIDIEditorGrid(project, division)
end
reaper.Undo_EndBlock(title, 0)