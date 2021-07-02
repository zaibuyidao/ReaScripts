--[[
 * ReaScript Name: 啟用MIDI端口0123
 * Version: 1.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.2 (2021-7-2)
  + 優化彈窗
 * v1.1 (2021-5-9)
  + 設置完成將自動退出REAPER
 * v1.0.1 (2021-4-1)
  + 文字描述修正
 * v1.0 (2021-4-1)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
script_name = "啟用MIDI端口0123"
text = "本操作將啟用0123端口並退出REAPER，請確保項目已保存。\n設置完畢後請手動重啟REAPER！\n"
text = text.."\n要繼續嗎？"
local box_ok = reaper.ShowMessageBox("注意：\n\n"..text, script_name, 4)
if box_ok == 7 then return end
local file = reaper.GetResourcePath() .. "\\" .. "reaper.ini"
local f = io.open(file, "r")
local content = f:read('*all')
f:close()
content = string.gsub(content, "midiouts=0", "midiouts=15")
f = io.open(file, "w")
f:write(content)
f:close()
reaper.Main_OnCommand(40004, 0) -- File: Quit REAPER