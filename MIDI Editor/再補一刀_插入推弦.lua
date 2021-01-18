--[[
 * ReaScript Name: 插入推弦
 * Version: 1.2
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-1-12)
  + Initial release
--]]

step = 128
selected = true
muted = false
chan = 0

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  local pos = reaper.GetCursorPositionEx(0)
  local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)

  local bend_start = reaper.GetExtState("Bend", "Start")
  if (bend_start == "") then bend_start = "0" end
  local bend_end = reaper.GetExtState("Bend", "End")
  if (bend_end == "") then bend_end = "1408" end
  local interval = reaper.GetExtState("Bend", "Interval")
  if (interval == "") then interval = "20" end

  local user_ok, user_input_csv = reaper.GetUserInputs("插入推弦", 3, "開始,結束,間隔", bend_start..','..bend_end..','.. interval)
  if not user_ok then return reaper.SN_FocusMIDIEditor() end
  bend_start, bend_end, interval = user_input_csv:match("(.*),(.*),(.*)")
  if not tonumber(bend_start) or not tonumber(bend_end) or not tonumber(interval) then return reaper.SN_FocusMIDIEditor() end
  bend_start, bend_end, interval = tonumber(bend_start), tonumber(bend_end), tonumber(interval)

  reaper.SetExtState("Bend", "Start", bend_start, false)
  reaper.SetExtState("Bend", "End", bend_end, false)
  reaper.SetExtState("Bend", "Interval", interval, false)

  if bend_start < -8192 or bend_start > 8191 or bend_end < -8192 or bend_end > 8191 then
    return
      reaper.MB("請輸入一個介於-8192到8191之間的值", "錯誤", 0),
      reaper.SN_FocusMIDIEditor()
  end
  local tbl = {} -- 存儲彎音值
  if bend_start < bend_end then
    for j = bend_start - 1, bend_end, step do
      j = j + 1
      table.insert(tbl, j)
    end
  end
  if bend_start > bend_end then
    for y = bend_end - 1, bend_start, step do
      y = y + 1
      table.insert(tbl, y)
      table.sort(tbl,function(bend_start,bend_end) return bend_start > bend_end end)
    end
  end
  for k, v in pairs(tbl) do
    local value = v + 8192
    local LSB = value & 0x7f
    local MSB = value >> 7 & 0x7f
    reaper.MIDI_InsertCC(take, selected, muted, ppq+(k-1)*interval, 224, chan, LSB, MSB)
  end
end

local script_title = "插入推弦"
reaper.Undo_BeginBlock() -- 撤銷塊開始
Main() -- 執行函數
reaper.Undo_EndBlock(script_title, -1) -- 撤銷塊結束
reaper.UpdateArrange() -- 更新排列
reaper.SN_FocusMIDIEditor() -- 聚焦MIDI編輯器