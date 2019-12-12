--[[
 * ReaScript Name: Linear Ramp CC Events
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

function Main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelNotes(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
  end

  reaper.Undo_BeginBlock() -- 撤销块开始
  if #index == 0 then return reaper.MB("Please select one or more notes","Error",0) end
  local retval, userInputsCSV = reaper.GetUserInputs("Linear Ramp CC Events", 5, "CC Number,Min Volume,Max Volume,Step,Interval", "11,90,127,1,10")
  if not retval then return reaper.SN_FocusMIDIEditor() end
  local cc_num, cc_begin, cc_end, step, interval = userInputsCSV:match("(.*),(.*),(.*),(.*),(.*)")
  cc_num, cc_begin, cc_end, step, interval = tonumber(cc_num), tonumber(cc_begin), tonumber(cc_end), tonumber(step), tonumber(interval)

  if cc_begin >= cc_end then return reaper.SN_FocusMIDIEditor() end
  local ppq = {} -- 音符位置
  local tbl = {} -- 存储CC值

  for j = cc_begin - 1, cc_end, step do
    j = j + 1
    if j > 127 then j = 127 end
    if j > cc_end then j = cc_end end
    table.insert(tbl, j) -- 将计算得到的CC值存入tbl表
  end

  for i = 1, #index do
    retval, selected, muted, ppq[i], endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, index[i])
    if selected == true then
      for k,v in pairs(tbl) do
        reaper.MIDI_InsertCC(take, selected, muted, ppq[i]+(k-1)*interval, 0xB0, chan, cc_num, v)
      end
    end
  end
  reaper.Undo_EndBlock(script_title, -1) -- 撤销块结束
end

script_title = "Linear Ramp CC Events"
reaper.PreventUIRefresh(1) -- 防止UI刷新
Main() -- 执行功能
-- reaper.MIDIEditor_LastFocused_OnCommand(reaper.NamedCommandLookup("_RS7d3c_38c941e712837e405c3c662e2a39e3d03ffd5364"), 0) -- 移除冗余CCs
reaper.PreventUIRefresh(-1) -- 恢复UI刷新
reaper.UpdateArrange() -- 更新排列
reaper.SN_FocusMIDIEditor() -- 聚焦MIDI编辑器