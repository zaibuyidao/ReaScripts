--[[
 * ReaScript Name: 啟用MIDI端口0123
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.1 (2021-5-9)
  + 設置完成將自動退出REAPER
 * v1.0.1 (2021-4-1)
  + 文字描述修正
 * v1.0 (2021-4-1)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
reaper.MB("本操作將啟用0123端口，設置完畢後需重啟REAPER才會生效！\n", "注意", 0)
local file = reaper.GetResourcePath() .. "\\" .. "reaper.ini"
local f = io.open(file, "r")
local content = f:read('*all')
f:close()
content = string.gsub(content, "midiouts=0", "midiouts=15")
f = io.open(file, "w")
f:write(content)
f:close()
reaper.Main_OnCommand(40004, 0) -- File: Quit REAPER