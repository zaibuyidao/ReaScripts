-- @description Batch Folder Media Importer
-- @version 1.0
-- @author zaibuyidao, ChangoW
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

-- 设置 package.path 以加载 REAPER 内置 ImGui 库
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.3.2'
local ctx = ImGui.CreateContext('Batch Folder Media Importer')

-----------------------------------------------------------
-- 脚本状态变量（必须在所有使用它们的函数之前声明）
-----------------------------------------------------------
local activeDirs     = {}    -- 存储每个子目录复选框的选中状态
local inputPath      = ""    -- 导入的基目录路径
local importInterval = 0   -- 每个媒体项之间编辑光标前移的时间（毫秒）
local selectAll      = false -- “全选”复选框状态
local subdirectories = {}    -- 基目录下的所有子目录列表

-----------------------------------------------------------
-- 工具函数
-----------------------------------------------------------

--- 拼接多个路径部分，自动使用操作系统对应的路径分隔符
-- @param ... 多个路径部分
-- @return string 拼接后的完整路径
function joinPaths(...)
  local parts = {...}
  local osStr = reaper.GetOS()
  local delimiter = (osStr == "Win32" or osStr == "Win64") and "\\" or "/"
  local path = ""
  for i, part in ipairs(parts) do
    -- 去除部分末尾和开头的分隔符，避免重复
    if i == 1 then
      path = part:gsub("[/\\]+$", "")
    else
      path = path .. delimiter .. part:gsub("^[/\\]+", ""):gsub("[/\\]+$", "")
    end
  end
  return path
end

--- 获取指定目录下的所有文件名称（按自然排序）
-- @param directory string 目录路径
-- @return table 包含所有音频文件名称的表
local function getAudioFilesInDirectory(directory)
  local audioFiles = {}
  local files = getFilesInDirectory(directory)
  for _, file in ipairs(files) do
    -- 假设音频文件以 ".wav", ".mp3", ".flac" 等为扩展名
    if file:match("%.wav$") or file:match("%.mp3$") or file:match("%.flac$") then
      table.insert(audioFiles, file)
    end
  end
  return audioFiles
end

-- 获取基目录下的所有音频文件，并将其作为“子目录”显示
local function getAllSubdirectories(directory, parentPath)
  local subdirs = {}
  
  -- 获取基目录下的音频文件
  local audioFiles = getAudioFilesInDirectory(directory)
  if #audioFiles > 0 then
    -- 如果基目录下有音频文件，添加为一个特殊的子目录项
    table.insert(subdirs, directory)  -- 添加基目录本身
  end

  local i = 0
  while true do
    local subdir = reaper.EnumerateSubdirectories(directory, i)
    if not subdir then break end
    local fullPath = joinPaths(directory, subdir)
    -- 递归调用
    local subsubdirs = getAllSubdirectories(fullPath, parentPath)
    if #subsubdirs > 0 then
      for _, subsubdir in ipairs(subsubdirs) do
        table.insert(subdirs, subsubdir)
      end
    else
      table.insert(subdirs, fullPath)
    end
    i = i + 1
  end
  return subdirs
end

function naturalSortCompare(a, b)
  local function padnum(d) return ("%012d"):format(tonumber(d)) end
  return tostring(a):gsub("%d+", padnum) < tostring(b):gsub("%d+", padnum)
end

--- 获取指定目录下的所有文件名称（按自然排序）
-- @param directory string 目录路径
-- @return table 包含所有文件名称的表
function getFilesInDirectory(directory)
  local files = {}
  local i = 0
  while true do
    local filename = reaper.EnumerateFiles(directory, i)
    if not filename then break end
    table.insert(files, filename)
    i = i + 1
  end
  table.sort(files, naturalSortCompare)
  return files
end

-- 根据操作系统规范化路径分隔符
local function normalizePathDelimiters(inputPath)
  local osStr = reaper.GetOS()
  if osStr == "Win32" or osStr == "Win64" then
    -- Windows 使用单个反斜杠作为路径分隔符
    inputPath = inputPath:gsub("/", "\\"):gsub("\\\\", "\\")
  else
    -- 其他操作系统使用正斜杠作为路径分隔符
    inputPath = inputPath:gsub("\\", "/")
  end
  return inputPath
end

--- 将编辑光标前移指定时长（单位：毫秒）
-- @param timeLength number 前移的时长（毫秒）
local function moveEditCursorByTime(timeLength)
  local currentPos = reaper.GetCursorPosition()
  reaper.SetEditCurPos(currentPos + timeLength / 1000, true, true)
end

-- 统计指定目录及其子目录中的音频文件数量
local function countAudioFilesInDirectory(directory)
  local count = 0
  -- 获取当前目录下的所有文件
  local files = getFilesInDirectory(directory)
  for _, file in ipairs(files) do
    -- 检查文件扩展名是否为音频格式
    if file:match("%.wav$") or file:match("%.mp3$") or file:match("%.flac$") or file:match("%.ogg$") then
      count = count + 1
    end
  end
  return count
end

-- 获取指定目录下的所有子目录，并统计所有音频文件数量
local function countAudioFilesRecursively(directory)
  local totalCount = 0
  -- 首先统计基目录下的音频文件数量
  totalCount = totalCount + countAudioFilesInDirectory(directory)
  
  -- 遍历所有子目录并递归统计音频文件数量
  local i = 0
  while true do
    local subdir = reaper.EnumerateSubdirectories(directory, i)
    if not subdir then break end
    local fullPath = joinPaths(directory, subdir)
    -- 递归统计子目录下的音频文件数量
    totalCount = totalCount + countAudioFilesRecursively(fullPath)
    i = i + 1
  end
  
  return totalCount
end

-- 获取基目录KR下的音频文件总数
local function getTotalAudioFiles(inputPath)
  local totalFiles = countAudioFilesRecursively(inputPath)
  return totalFiles
end

-- 打印音频文件数量
-- local function showAudioFileCount(inputPath)
--   local totalFiles = getTotalAudioFiles(inputPath)
--   reaper.ShowConsoleMsg("Total Audio Files: " .. totalFiles .. "\n")
-- end

-----------------------------------------------------------
-- 核心业务逻辑
-----------------------------------------------------------

--- 将指定基目录下的各子目录中的音频文件依次插入工程中
-- 每个子目录对应一个新轨道（首个文件插入时创建轨道并命名为子目录名称）
-- 插入后编辑光标自动前移指定时长
-- @param baseDirectory string 基目录路径
-- @param subdirectories table 子目录路径列表

--- 获取当前选中的轨道编号
-- 如果没有选中任何轨道，则返回 0
local function getFirstSelectedTrackNumber()
  local track = reaper.GetSelectedTrack(0, 0)
  if track then
    return reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
  end
  -- 如果没有选中轨道，返回最后一个轨道的编号
  local trackCount = reaper.CountTracks(0)
  if trackCount > 0 then
    return trackCount  -- 返回最后一轨的编号
  end
  return 0
end

local function importMediaFromDirectories(baseDirectory, subdirectories)
  local firstSelectedTrackNumber = getFirstSelectedTrackNumber()
  -- 开始 Undo 块和UI刷新锁定
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local trackOffset = 0

  -- 遍历每个子目录，并根据选中的轨道进行处理
  for i, subdir in ipairs(subdirectories) do
    if activeDirs[i] then
      local files = getAudioFilesInDirectory(subdir)
      for fileIndex, fileName in ipairs(files) do
        local fullPath = joinPaths(subdir, fileName)
        if fileIndex == 1 then
          -- 插入首个文件时创建新轨道，并命名为子目录名称
          trackOffset = trackOffset + 1
          reaper.InsertMedia(fullPath, 1)
          local newTrack = reaper.GetTrack(0, (firstSelectedTrackNumber - 1) + trackOffset)

          if newTrack then
            -- 获取基目录名称
            local baseDirName = inputPath:match("([^/\\]+)$")
            -- 获取相对路径部分
            local relativeSubdir = subdir:sub(#baseDirectory + 1)
          
            -- 如果相对路径部分为空，表示只是基目录本身
            if relativeSubdir == "" then
              relativeSubdir = baseDirName  -- 只保留基目录名，不加反斜杠
            else
              relativeSubdir = baseDirName .. "\\" .. relativeSubdir  -- 拼接基目录和子目录
            end
          
            -- 设置轨道名称
            reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", relativeSubdir, true)
          end

          reaper.Main_OnCommand(41174, 0)  -- 激活新轨道
        else
          reaper.InsertMedia(fullPath, 0)
        end
        moveEditCursorByTime(importInterval)
      end
    end
  end

  -- 结束UI刷新锁定和 Undo 块
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Batch Import Media", -1)
end

-----------------------------------------------------------
-- ImGui 界面循环
-----------------------------------------------------------

--- 主循环函数，用于绘制 ImGui 界面并响应用户交互
-- @param currentSubdirectories table 当前基目录下的子目录列表
local showSelectAll = false  -- 控制 "Select All" 复选框的显示

local function mainLoop(currentSubdirectories)
  return function()
    local visible, open = ImGui.Begin(ctx, "Batch Folder Media Importer", true)
    if visible then
      teext = reaper.ImGui_Button(ctx, "Browse...", -1)
      ImGui.SetItemTooltip(ctx, 'Select import folder')
      if teext then
        local retval, folder = reaper.JS_Dialog_BrowseForFolder("Select import folder:", "")
        if retval then
          inputPath = normalizePathDelimiters(folder)
          currentSubdirectories = getAllSubdirectories(inputPath, "")
          -- 如果子目录列表不为空，则显示 "Select All" 复选框
          if #currentSubdirectories > 0 then
            showSelectAll = true
          else
            showSelectAll = false
          end
          activeDirs = {}  -- 选择新目录时重置各子目录复选状态
        end
      end

      local changed, new_inputPath = reaper.ImGui_InputText(ctx, "Import Path", inputPath, 256)
      if changed then
        inputPath = new_inputPath
      end

      local keys = reaper.JS_VKeys_GetState(0)
      if keys:byte(0xD) ~= 0 then
        inputPath = normalizePathDelimiters(inputPath)
        currentSubdirectories = getAllSubdirectories(inputPath, "")
        if #currentSubdirectories > 0 then
          showSelectAll = true
        else
          showSelectAll = false
        end
        activeDirs = {}  -- 粘贴路径时重置各子目录复选状态
      end

      _, importInterval = ImGui.InputInt(ctx, "Interval (ms)", importInterval, 1, 100)
      
      -- 只有当 showSelectAll 为 true 时才显示 "Select All" 复选框
      if showSelectAll then
        local changed_selectAll, new_selectAll = reaper.ImGui_Checkbox(ctx, "Select All", selectAll)
        local totalFiles = getTotalAudioFiles(inputPath)
        ImGui.SeparatorText(ctx, totalFiles ..' Audio Files, '.. #currentSubdirectories .." Folders.")
        if changed_selectAll then
          selectAll = new_selectAll
          for i = 1, #currentSubdirectories do
            activeDirs[i] = selectAll
          end
        end
      end

      -- 显示子目录复选框
      -- for i, subdir in ipairs(currentSubdirectories) do
      --   _, activeDirs[i] = reaper.ImGui_Checkbox(ctx, subdir, activeDirs[i])
      -- end

      -- 在显示子目录时隐藏inputPath部分
      -- for i, subdir in ipairs(currentSubdirectories) do
      --   local relativeSubdir = subdir:sub(#inputPath + 2) -- 去除inputPath部分
      --   _, activeDirs[i] = reaper.ImGui_Checkbox(ctx, relativeSubdir, activeDirs[i])
      -- end

      -- 获取 inputPath 的基目录名称
      local baseDirName = inputPath:match("([^/\\]+)$")

      -- 显示子目录时保留基目录名称并隐藏inputPath部分
      -- for i, subdir in ipairs(currentSubdirectories) do
      --   -- 获取相对路径（去掉inputPath部分），并与基目录名称拼接
      --   local relativeSubdir = baseDirName .. "\\" .. subdir:sub(#inputPath + 2)  -- 加入反斜杠
      --   _, activeDirs[i] = reaper.ImGui_Checkbox(ctx, relativeSubdir, activeDirs[i])
      -- end

      -- 显示子目录时保留基目录名称并隐藏inputPath部分
      for i, subdir in ipairs(currentSubdirectories) do
        -- 获取相对路径（去掉inputPath部分），并与基目录名称拼接
        local relativeSubdir = subdir:sub(#inputPath + 2)  -- 去掉inputPath部分
      
        -- 如果相对路径为空，表示只是基目录
        if relativeSubdir == "" then
          relativeSubdir = baseDirName  -- 只保留基目录名称
        else
          relativeSubdir = baseDirName .. "\\" .. relativeSubdir  -- 拼接基目录和子目录
        end
      
        -- 显示复选框
        _, activeDirs[i] = reaper.ImGui_Checkbox(ctx, relativeSubdir, activeDirs[i])
      end

      if reaper.ImGui_Button(ctx, "OK", -1) then
        importMediaFromDirectories(joinPaths(inputPath, ""), currentSubdirectories)
      end

      ImGui.End(ctx)
    end

    if open then
      reaper.defer(mainLoop(currentSubdirectories))
    end
  end
end

-----------------------------------------------------------
-- 脚本入口：启动 ImGui 主循环
-----------------------------------------------------------
reaper.defer(mainLoop(subdirectories))