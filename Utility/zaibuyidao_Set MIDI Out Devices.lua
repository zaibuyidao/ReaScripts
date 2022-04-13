--[[
 * ReaScript Name: Set MIDI Out Devices
 * Version: 1.0.1
 * Author: zaibuyidao, YS
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * 參考蛋總腳本: YS_MIDI硬件输出设置.lua
--]]

--[[
 * Changelog:
 * v1.0 (2021-10-3)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

local show_msg = reaper.GetExtState("SetMIDIOutDevices", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
  script_name = "設置MIDI硬件輸出"
  text = "This script will set the MIDI output device and exit REAPER,\n該腳本將設置MIDI硬件輸出並退出REAPER,\nPlease make sure the project is saved.\n請確保項目已保存.\nPlease restart REAPER manually after finishing!\n完畢後請手動重啟REAPER!\n\nSelecting Enable Output:\n選擇啟用輸出:\n\n啟用 ID 0, 輸入 1\n啟用 ID 1, 輸入 2\n啟用 ID 2, 輸入 4\n啟用 ID 3, 輸入 8\n啟用 ID 4, 輸入 16\n--\n啟用 ID 0 和 1, 輸入 3 (1+2, ID对应的值相加)\n啟用 ID 1 和 2, 輸入 6 (2+4)\n啟用 ID 2 和 3, 輸入 12 (4+8)\n啟用 ID 3 和 4, 輸入 24 (8+16)\n--\n啟用 ID 0 和 2, 輸入 5 (1+4)\n啟用 ID 1 和 3, 輸入 10 (2+8)\n啟用 ID 2 和 4, 輸入 20 (4+16)\n--\n啟用 ID 0 和 3, 輸入 9 (1+8)\n啟用 ID 1 和 4, 輸入 18 (2+16)\n--\n啟用 ID 1 2 3 4, 輸入 15 (1+2+4+8)\n"
  text = text.."\nWill this page be displayed next time?\n下次還顯示此頁面嗎？"
  local box_ok = reaper.ShowMessageBox("注意事項: \n\n"..text, script_name, 4)

    if box_ok == 7 then
        show_msg = "false"
        reaper.SetExtState("SetMIDIOutDevices", "ShowMsg", show_msg, true)
    end
end

path = reaper.GetExePath()
devout_num = 1

for i = 0, reaper.GetNumMIDIOutputs()-1 do
  local retval, name = reaper.GetMIDIOutputName( i, '' )
  if not name:match(name) then
    devout_num = devout_num + 1
  end
end

devtb = {}
devid = 0
dev = ''
id = ''

while devid < devout_num do
  retval, nameout = reaper.GetMIDIOutputName(devid, '')
  dev = dev .. nameout .. ','
  id = id .. devid .. ','
  table.insert(devtb, nameout)
  devid = devid + 1
end

-- for k, v in pairs(devtb) do
--   Msg(v)
-- end

midi_out = 15 -- 默认激活ID 0-3 的MIDI硬件输出
ret, inp_str = reaper.GetUserInputs('Set MIDI Out Devices', #devtb+1, dev..'Selecting Enable Output:', id .. midi_out)
if not ret then return end

os = reaper.GetOS()
if os ~= "Win32" and os ~= "Win64" then
  r = os.remove(path .. "/reaper-midihw.ini")
else
  r = os.remove(path .. "\\reaper-midihw.ini")
end

t = {}
for word in inp_str:gmatch("([^,]*)") do -- 获取用户输入值
  t[#t+1]=word
end

-- for k, v in ipairs(t) do
--   Msg(v)
-- end

t1={}
t2=t
t3={}
-- table.sort(t2) -- 如果执行排序将导致用户输入的值被打乱
for key, v in pairs(t2) do -- 计算相同值的个数，大于 0 弹出提示
    if t1[t2[key]] == nil then
      t1[t2[key]] = 0 -- 如果没有相同的值会得到 0
    else
      t1[t2[key]] = t1[t2[key]] + 1 -- 统计相同的值的个数
    end
    if key ~= #t2 then
    if t1[t2[key]] > 0 then return reaper.MB('禁止輸入相同的ID!', '錯誤', 0) end
    end
end

for i = 1, #devtb do
  if tonumber(t[i]) > #devtb-1 then return reaper.MB('ID值限定在0-'..#devtb-1, '錯誤', 0) end
  key = 'on' .. t[i]
  value = devtb[i]
  if os ~= "Win32" and os ~= "Win64" then
    reaper.BR_Win32_WritePrivateProfileString('mididevcache', key, value, path .. "/reaper-midihw.ini")
  else
    reaper.BR_Win32_WritePrivateProfileString('mididevcache', key, value, path .. "\\reaper-midihw.ini")
  end
end

-- 启用MIDI硬件输出
if os ~= "Win32" and os ~= "Win64" then
  file = reaper.GetResourcePath() .. "/" .. "reaper.ini"
else
  file = reaper.GetResourcePath() .. "\\" .. "reaper.ini"
end

local f = io.open(file, "r")
local content = f:read('*all')
f:close()
content = string.gsub(content, "midiouts=(%d+)", "midiouts="..t[#devtb+1]) -- 将表格最后一个参数应用到MIDI输出
f = io.open(file, "w")
f:write(content)
f:close()
reaper.Main_OnCommand(40004, 0) -- File: Quit REAPER