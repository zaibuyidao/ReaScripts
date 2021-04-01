--[[
 * ReaScript Name: 啟用MIDI端口0123
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0.1 (2021-4-1)
  + 文字描述修正
 * v1.0 (2021-4-1)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
reaper.MB("ID 0 = SOUND Canvas VA [A]\nID 1 = SOUND Canvas VA [B]\nID 2 = PhoenixVSTi [A]\nID 3 = PhoenixVSTi [B]", "啟用MIDI端口0123", 0)
local file = reaper.GetResourcePath() .. "\\" .. "reaper.ini"
local f = io.open(file, "r")
local content = f:read('*all')
f:close()
content = string.gsub(content, "midiouts=0", "midiouts=15")
f = io.open(file, "w")
f:write(content)
f:close()
