--[[
 * ReaScript Name: Insert Bend
 * Instructions: Open a MIDI take in MIDI Editor. Position Edit Cursor, Run.
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
 * v1.0 (2020-1-12)
  + Initial release
--]]

step = 128
selected = false
muted = false
chan = 0

function Main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  local pos = reaper.GetCursorPositionEx(0)
  local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
  local retval, userInputsCSV = reaper.GetUserInputs("Insert Bend", 3, "Range (Multiples of 128),,Interval", "0,1408,10")
  if not retval then return reaper.SN_FocusMIDIEditor() end
  local cc_begin, cc_end, interval = userInputsCSV:match("(.*),(.*),(.*)")
  cc_begin, cc_end, interval = tonumber(cc_begin), tonumber(cc_end), tonumber(interval)
  if cc_begin < -8192 or cc_begin > 8191 or cc_end < -8192 or cc_end > 8191 then
    return
      reaper.MB("Please enter a value from -8192 through 8191", "Error", 0),
      reaper.SN_FocusMIDIEditor()
  end

  local tbl = {} -- 存储弯音值
  if cc_begin < cc_end then
    for j = cc_begin - 1, cc_end, step do
      j = j + 1
      table.insert(tbl, j)
    end
  end
  if cc_begin > cc_end then
    for y = cc_end - 1, cc_begin, step do
      y = y + 1
      table.insert(tbl, y)
      table.sort(tbl,function(cc_begin,cc_end) return cc_begin > cc_end end)
    end
  end
  for k,v in pairs(tbl) do
    local value = v + 8192
    local LSB = value & 0x7f
    local MSB = value >> 7 & 0x7f
    reaper.MIDI_InsertCC(take, selected, muted, ppq+(k-1)*interval, 224, chan, LSB, MSB)
  end
end

script_title = "Insert Bend"
reaper.PreventUIRefresh(1) -- 防止UI刷新
reaper.Undo_BeginBlock() -- 撤销块开始
Main() -- 执行函数
reaper.Undo_EndBlock(script_title, 0) -- 撤销块结束
reaper.PreventUIRefresh(-1) -- 恢复UI刷新
reaper.UpdateArrange() -- 更新排列
reaper.SN_FocusMIDIEditor() -- 聚焦MIDI编辑器