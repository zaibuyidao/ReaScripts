-- @description Set MIDI Note Shapes
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

local function SetDrumMode(drum_mode)
    local editor = reaper.MIDIEditor_GetActive()
    if not editor then return end
    
    if drum_mode == '0' then
        reaper.MIDIEditor_OnCommand(editor, 40448)  -- Triangle (Drum Mode)
    elseif drum_mode == '1' then
        reaper.MIDIEditor_OnCommand(editor, 40449)  -- Rectangle (Normal Mode)
    elseif drum_mode == '2' then
        reaper.MIDIEditor_OnCommand(editor, 40450)  -- Diamond (Drum Mode)
    end
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

if language == "简体中文" then
    title = "设置MIDI音符形状"
    captions_csv = "0=三角形 1=标准 2=菱形"
elseif language == "繁體中文" then
    title = "設置MIDI音符形状"
    captions_csv = "0=三角形 1=標準 2=菱形"
else
    title = "Set MIDI Note Shapes"
    captions_csv = "0=Triangle 1=Normal 2=Diamond"
end

-- Prompt user to choose the note shape
local rv, drum_mode = reaper.GetUserInputs(title, 1, captions_csv, '0')
if not rv then return end

local editor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(editor)
if not take or not reaper.TakeIsMIDI(take) then return end

-- Apply the drum mode to selected items
-- local count_sel_items = reaper.CountSelectedMediaItems(0)
-- if count_sel_items > 0 then
--     for i = 0, count_sel_items - 1 do
--         local item = reaper.GetSelectedMediaItem(0, i)
--         SetDrumMode(drum_mode)
--         reaper.MIDIEditor_OnCommand(editor, 40500)
--     end
-- end

for take, _ in pairs(getTakes) do
    SetDrumMode(drum_mode)
    reaper.MIDIEditor_OnCommand(editor, 40500)
end

reaper.Undo_EndBlock(title, -1)  -- End the undo block
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()