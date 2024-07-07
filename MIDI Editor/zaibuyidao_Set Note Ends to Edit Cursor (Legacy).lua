-- @description Set Note Ends to Edit Cursor (Legacy)
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
local getTakes = getAllTakes()

local getTake = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if getTake == nil then return end

function table.sortByKey(tab, key, ascend) -- 對於傳入的table按照指定的key值進行排序,ascend參數決定是否為升序(由低往高),預設為true。
    direct=direct or true
    table.sort(tab,function(a,b)
        if ascend then return a[key]<b[key] end
        return a[key]>b[key]
    end)
end

local function selNoteIterator(take) -- 迭代器 用於返回選中的每一個音符信息表
    local sel=-1
    return function()
        sel=reaper.MIDI_EnumSelNotes(take, sel)
        if sel==-1 then return end
        return getNote(take, sel)
    end
end

local function getSelNotes(take) -- 獲取選中音符
    local notes={}
    for note in selNoteIterator(take) do
        table.insert(notes, note)
    end
    return notes
end

local function min(a,b)
    if a>b then
        return b
    end
    return a
end

reaper.Undo_BeginBlock()
for take, _ in pairs(getTakes) do
    reaper.MIDI_DisableSort(take)

    local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)

    local function getNote(take, sel) -- 根據傳入的sel索引值，返回指定位置的含有音符信息的表
        local retval, selected, muted, startPos, endPos, channel, pitch, vel = reaper.MIDI_GetNote(take, sel)
        return {
            ["retval"]=retval,
            ["selected"]=selected,
            ["muted"]=muted,
            ["startPos"]=startPos,
            ["endPos"]=endPos,
            ["channel"]=channel,
            ["pitch"]=pitch,
            ["vel"]=vel,
            ["sel"]=sel
        }
    end

    local function getAllNotes(take) -- 获取所有音符
        local notes = {}
        for i = 1, notecnt do
            table.insert(notes, getNote(take, i - 1))
        end
        return notes
    end
    
    local function deleteSelNote(take) -- 删除选中音符
        for i = 1, notecnt do
            reaper.MIDI_DeleteNote(take, 0)
        end
    end

    local function insertNote(take, note) -- 插入音符
        reaper.MIDI_InsertNote(take, note.selected, note.muted, note.startPos, note.endPos, note.channel, note.pitch, note.vel, false)
    end

    local notes = getAllNotes(take) -- 1.获取选中音符

    deleteSelNote(take) -- 2.删除选中音符

    local pitchNotes = {}

    for _, v in pairs(notes) do -- 3.将音符按照音高分組，相同音高的音符将被分到同一个组
        -- print(v.pitch)
        if pitchNotes[v.pitch] == nil then pitchNotes[v.pitch] = {} end
        table.insert(pitchNotes[v.pitch],v)
    end

    local dur = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPositionEx(0)) -- 4.獲获光标位置

    for _, v in pairs(pitchNotes) do -- 5.遍历按音高分组后的音符
        table.sortByKey(v, "startPos", true) -- 6.按选中音符的起始位置由小到大排序
        for i = 1, #v do -- 7.处理音符结束位置
            -- print(v[i].startPos)
            if v[i].startPos >= dur then goto continue end
            if not v[i].selected then goto continue end
            if (i == #v) then -- 最后一个音符的结束位置等于光标位置
                v[i].endPos = dur
            else
                v[i].endPos = min(dur,v[i+1].startPos)
            end
            ::continue::
            insertNote(take, v[i]) -- 8.插入新音符
        end
    end

    reaper.MIDI_Sort(take)
end
reaper.Undo_EndBlock("Set Note Ends to Edit Cursor", -1)
reaper.UpdateArrange()