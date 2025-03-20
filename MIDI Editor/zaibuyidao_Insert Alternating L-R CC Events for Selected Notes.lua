-- @description Insert Alternating L/R CC Events for Selected Notes
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   + New Script
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
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

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not take or not reaper.TakeIsMIDI(take) then return end

------------------------------------------------------------
-- 根据指定键值对表进行排序，默认为升序排序
------------------------------------------------------------
function table.sortByKey(tab, key, ascend)
    ascend = (ascend == nil) and true or ascend
    table.sort(tab, function(a, b)
        if ascend then
            return a[key] < b[key]
        else
            return a[key] > b[key]
        end
    end)
end

------------------------------------------------------------
-- 根据索引返回包含音符信息的表
------------------------------------------------------------
local function getNote(sel)
    local retval, selected, muted, startPos, endPos, channel, pitch, vel = reaper.MIDI_GetNote(take, sel)
    return {
        retval = retval,
        selected = selected,
        muted = muted,
        startPos = startPos,
        endPos = endPos,
        channel = channel,
        pitch = pitch,
        vel = vel,
        sel = sel
    }
end

------------------------------------------------------------
-- 更新指定索引的音符信息
------------------------------------------------------------
local function setNote(note, sel, noSort)
    reaper.MIDI_SetNote(take, sel, note.selected, note.muted, note.startPos, note.endPos, note.channel, note.pitch, note.vel, noSort or false)
end

------------------------------------------------------------
-- 迭代器：返回所有被选中的音符信息表
------------------------------------------------------------
local function selNoteIterator()
    local sel = -1
    return function()
        sel = reaper.MIDI_EnumSelNotes(take, sel)
        if sel == -1 then return nil end
        return getNote(sel)
    end
end

------------------------------------------------------------
-- 按照音符 startPos 分组处理被选中的音符
-- 对每个分组，按音高排序后选中组内第一个音符
------------------------------------------------------------
local function setOneNote()
    local selectedPos = 1
    local noteGroups = {}
    -- 遍历所有选中音符，按 startPos 分组，并先取消所有选中状态
    for note in selNoteIterator() do
        note.selected = false
        setNote(note, note.sel, true)
        local groupKey = note.startPos
        noteGroups[groupKey] = noteGroups[groupKey] or {}
        table.insert(noteGroups[groupKey], note)
    end
    -- 对每个分组排序并选择组内第一个音符
    for _, notes in pairs(noteGroups) do
        if #notes > 0 then
            table.sortByKey(notes, "pitch", true)
            if selectedPos <= #notes then
                notes[selectedPos].selected = true
                setNote(notes[selectedPos], notes[selectedPos].sel, true)
            end
        end
    end
end

------------------------------------------------------------
-- 主函数
------------------------------------------------------------
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

reaper.MIDI_DisableSort(take)
local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)

local msg2 = reaper.GetExtState("InsertAlternatingLRCCEvents", "CCNum")
if msg2 == "" then msg2 = "10" end
local msg3 = reaper.GetExtState("InsertAlternatingLRCCEvents", "ValueA")
if msg3 == "" then msg3 = "1" end
local msg4 = reaper.GetExtState("InsertAlternatingLRCCEvents", "ValueB")
if msg4 == "" then msg4 = "127" end

if language == "简体中文" then
    title = "插入交替 L/R CC 事件"
    captions_csv = "CC编号:,左值:,右值:"
elseif language == "繁體中文" then
    title = "插入交替 L/R CC 事件"
    captions_csv = "CC編號:,左值:,右值:"
else
    title = "Insert Alternating L/R CC Events"
    captions_csv = "CC Number:,Left Value:,Right Value:"
end

local uok, uinput = reaper.GetUserInputs(title, 3, captions_csv, msg2..','..msg3..','..msg4)
if not uok then return reaper.SN_FocusMIDIEditor() end

msg2, msg3, msg4 = uinput:match("([^,]+),([^,]+),([^,]+)")
if not (tonumber(msg2) and tonumber(msg3) and tonumber(msg4)) then return end

reaper.SetExtState("InsertAlternatingLRCCEvents", "CCNum", msg2, false)
reaper.SetExtState("InsertAlternatingLRCCEvents", "ValueA", msg3, false)
reaper.SetExtState("InsertAlternatingLRCCEvents", "ValueB", msg4, false)

setOneNote()

reaper.MIDIEditor_OnCommand(midiEditor, 40671) -- Unselect all CC events

-- 遍历所有音符，对被选中的音符交替插入CC事件
local flag = true
for i = 0, notecnt - 1 do
    local retval, selected, muted, startpos, endpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected then
        if flag then
            reaper.MIDI_InsertCC(take, selected, muted, startpos, 0xB0, chan, tonumber(msg2), tonumber(msg3))
            flag = false
        else
            reaper.MIDI_InsertCC(take, selected, muted, startpos, 0xB0, chan, tonumber(msg2), tonumber(msg4))
            flag = true
        end
    end
end

local j = reaper.MIDI_EnumSelCC(take, -1)
while j ~= -1 do
  reaper.MIDI_SetCCShape(take, j, 0, 0, true)
  reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, true)
  j = reaper.MIDI_EnumSelCC(take, j)
end

reaper.MIDI_Sort(take)
reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
