--[[
 * ReaScript Name: Media Explorer Search Filter
 * Version: 1.0.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
 * Provides: [main=main,mediaexplorer] .
--]]

--[[
 * Changelog:
 * v1.0 (2022-7-26)
  + Initial release
--]]

function print(param) 
  reaper.ShowConsoleMsg(tostring(param) .. "\n") 
end

if not reaper.APIExists("JS_Localize") then
  reaper.MB("請右鍵單擊並安裝'js_ReaScriptAPI: API functions for ReaScripts'。然後重新啟動REAPER並再次運行腳本，謝謝！", "你必須安裝 JS_ReaScriptAPI", 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, "錯誤", 0)
  end
  return reaper.defer(function() end)
end

function send_search_text(text)
  local title = reaper.JS_Localize("Media Explorer", "common")
  local hwnd = reaper.JS_Window_Find(title, true)
  local search = reaper.JS_Window_FindChildByID(hwnd, 1015)
  if search == nil then return end
  reaper.JS_Window_SetTitle(search, text)

  local os = reaper.GetOS()
  if os ~= "Win32" and os ~= "Win64" then
    reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
    reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
  else
    if reaper.GetToggleCommandStateEx(32063, 42051) == 1 then
      -- reaper.SetToggleCommandState(32063, 42051, 0) -- 无效
      reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
    end
    -- https://github.com/justinfrankel/WDL/blob/main/WDL/swell/swell-types.h
    reaper.JS_WindowMessage_Post(search, "WM_KEYDOWN", 0x0020, 0, 0, 0) -- 空格
    reaper.JS_WindowMessage_Post(search, "WM_KEYUP", 0x0008, 0, 0, 0) -- 退格
  end
end

local text = reaper.GetExtState("MediaExplorerSearchFilter", "Keywords")
if (text == "") then text = "" end
userok, text = reaper.GetUserInputs("Media Explorer Search Filter", 1, "Keywords 關鍵詞,extrawidth=150", text)
if not userok then return end
reaper.SetExtState("MediaExplorerSearchFilter", "Keywords", text, false)

reaper.Undo_BeginBlock()
send_search_text(text)
reaper.Undo_EndBlock("Media Explorer Search Filter", -1)
reaper.UpdateArrange()