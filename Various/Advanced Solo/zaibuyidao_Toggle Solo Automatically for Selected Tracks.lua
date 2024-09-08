-- NoIndex: true
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

function main()
  -- 获取当前项目状态改变计数
  local currentProjectStateChangeCount = reaper.GetProjectStateChangeCount()

  -- 如果状态改变计数有变化，则执行以下操作
  if not lastStateChangeCount or lastStateChangeCount ~= currentProjectStateChangeCount then
    reaper.PreventUIRefresh(1)
    -- 获取项目中轨道的数量
    local trackCount = reaper.CountTracks()

    for i = 0, trackCount - 1 do
      local track = reaper.GetTrack(0, i)
      local isTrackSelected = reaper.IsTrackSelected(track)
      local isSolo = reaper.GetMediaTrackInfo_Value(track, 'I_SOLO')

      -- 如果轨道被选中且当前不是独奏状态，设置为独奏状态
      if isTrackSelected then
        if isSolo == 0 then 
          reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
        end
      -- 如果轨道未被选中但处于独奏状态，取消独奏状态
      elseif isSolo ~= 0 then
        reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 0)
      end
    end

    reaper.PreventUIRefresh(-1)
  end

  -- 更新最后的状态改变计数
  lastStateChangeCount = currentProjectStateChangeCount

  -- 重新调用main函数，保持脚本运行
  reaper.defer(main)
end

(function()
  local _, _, sectionId, cmdId = reaper.get_action_context()
  if sectionId ~= -1 then
    reaper.SetToggleCommandState(sectionId, cmdId, 1)
    reaper.RefreshToolbar2(sectionId, cmdId)
    main()
    reaper.atexit(function()
      reaper.SoloAllTracks(0)
      reaper.SetToggleCommandState(sectionId, cmdId, 0)
      reaper.RefreshToolbar2(sectionId, cmdId)
    end)
  end
end)()