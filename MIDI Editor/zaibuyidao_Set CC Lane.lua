-- @description Set CC Lane
-- @version 1.2.5
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

function main()
    reaper.Undo_BeginBlock()
    local title, captions_csv = "", ""
    if language == "简体中文" then
        title = "设置CC车道"
        captions_csv = "输入(CC编号 或 v,p,g,c,b,t,s):"
    elseif language == "繁體中文" then
        title = "設置CC車道"
        captions_csv = "輸入(CC編號 或 v,p,g,c,b,t,s):"
    else
        title = "Set CC Lane"
        captions_csv = "Enter (CC# or v,p,g,c,b,t,s):"
    end

    cc_lane = reaper.GetExtState("SET_CC_LANE", "Parameter")
    if (cc_lane == "") then cc_lane = "v" end
    uok, cc_lane = reaper.GetUserInputs(title, 1, captions_csv, cc_lane)
    reaper.SetExtState("SET_CC_LANE", "Parameter", cc_lane, false)
    if not uok then return end

    local HWND = reaper.MIDIEditor_GetActive()
    local take = reaper.MIDIEditor_GetTake(HWND)
    local parameter
    if cc_lane == "v" then
        parameter = 40237 -- CC: Set CC lane to Velocity
    elseif cc_lane == "p" then
        parameter = 40366 -- CC: Set CC lane to Pitch
    elseif cc_lane == "g" then
        parameter = 40367 -- CC: Set CC lane to Program
    elseif cc_lane == "c" then
        parameter = 40368 -- CC: Set CC lane to Channel Pressure
    elseif cc_lane == "b" then
        parameter = 40369 -- CC: Set CC lane to Bank/Program Select
    elseif cc_lane == "t" then
        parameter = 40370 -- CC: Set CC lane to Text Events
    elseif cc_lane == "s" then
        parameter = 40371 -- CC: Set CC lane to Sysex
    else
        cc_lane = tonumber(cc_lane)
        if cc_lane == nil or cc_lane < 0 or cc_lane > 119 then
            cc_lane = "v"
            reaper.SetExtState("SET_CC_LANE", "Parameter", cc_lane, false)
            return reaper.SN_FocusMIDIEditor()
        end
        parameter = cc_lane + 40238 -- CC: Set CC lane to 000 Bank Select MSB
    end
    reaper.MIDIEditor_OnCommand(HWND, parameter)
    reaper.Undo_EndBlock(title, -1)
end
main()
reaper.SN_FocusMIDIEditor()