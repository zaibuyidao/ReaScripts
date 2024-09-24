-- @description Track Follows Item/Razor Selection
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @reference: Lokasenna_Track selection follows item selection.lua (Optimize only)
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

local sel_items, sel_tracks, sel_razor = {}, {}, {}

local function ShallowEqual(t1, t2)
  if #t1 ~= #t2 then return false end
  for k, v in pairs(t1) do
    if v ~= t2[k] then return false end
  end
  return true
end

local function GetRazorTracks()
  local tracks = {}
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, str = reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", "", false)
    if str ~= "" then table.insert(tracks, track) end
  end
  return tracks
end

local function ProcessTracks(tracks)
  if #tracks > 0 then
    reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
    reaper.SetOnlyTrackSelected(tracks[1])
    for _, v in pairs(tracks) do
      reaper.SetTrackSelected(v, true)
    end
  end
end

-- State: On/Off
(function()
  local _, _, sectionId, cmdId = reaper.get_action_context()
  if sectionId ~= -1 then
    reaper.SetToggleCommandState(sectionId, cmdId, 1)
    reaper.RefreshToolbar2(sectionId, cmdId)
    reaper.atexit(function()
      reaper.SetToggleCommandState(sectionId, cmdId, 0)
      reaper.RefreshToolbar2(sectionId, cmdId)
    end)
  end
end)()

local function Main()
  reaper.PreventUIRefresh(1)
  local num_tracks = reaper.CountSelectedTracks(0)
  local cur_tracks = {}
  for i = 1, num_tracks do
    cur_tracks[i] = reaper.GetSelectedTrack(0, i - 1)
  end
  if ShallowEqual(sel_tracks, cur_tracks) then
    local cur_razor = GetRazorTracks()
    if not ShallowEqual(sel_razor, cur_razor) then
      sel_razor = cur_razor
      ProcessTracks(sel_razor)
    elseif #cur_razor == 0 then
      local num_items = reaper.CountSelectedMediaItems(0)
      local cur_items = {}
      for i = 1, num_items do
        cur_items[i] = reaper.GetSelectedMediaItem(0, i - 1)
      end
      if not ShallowEqual(sel_items, cur_items) then
        sel_items = cur_items
        local tracks = {}
        for i = 1, num_items do
          tracks[i] = reaper.GetMediaItem_Track(sel_items[i])
        end
        ProcessTracks(tracks)
        if num_items > 0 then
          reaper.SetMixerScroll(reaper.GetSelectedTrack(0, 0))
        end
      end
    end
  else
    sel_tracks = cur_tracks
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.defer(Main)
end
Main()