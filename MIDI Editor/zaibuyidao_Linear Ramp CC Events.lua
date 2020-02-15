--[[
 * ReaScript Name: Linear Ramp CC Events
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.3
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.3 (2020-2-15)
  + Perform actions based on note length
 * v1.0 (2019-12-12)
  + Initial release
--]]

function Main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
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
  local retval, userInputsCSV = reaper.GetUserInputs("Linear Ramp CC Events", 4, "CC Number,Min Volume,Max Volume,Step", "11,90,127,1")
  if not retval then return reaper.SN_FocusMIDIEditor() end
  local cc_num, cc_begin, cc_end, step = userInputsCSV:match("(.*),(.*),(.*),(.*)")
  cc_num, cc_begin, cc_end, step = tonumber(cc_num), tonumber(cc_begin), tonumber(cc_end), tonumber(step)

  if cc_begin >= cc_end then return reaper.SN_FocusMIDIEditor() end
  local ppq = {} -- 音符开头位置
  local ppq_end = {} -- 音符尾巴位置
  local tbl = {} -- 存储CC值

  for j = cc_begin - 1, cc_end, step do
    j = j + 1
    if j > 127 then j = 127 end
    if j > cc_end then j = cc_end end
    table.insert(tbl, j) -- 将计算得到的CC值存入tbl表
  end

  for i = 1, #index do
    retval, selected, muted, ppq[i], ppq_end[i], chan, pitch, vel = reaper.MIDI_GetNote(take, index[i])
    if selected == true then
      ppq_len = ppq_end[i] - ppq[i]
      if ppq_len >= tick / 2 and ppq_len < tick then
        for k,v in pairs(tbl) do
          reaper.MIDI_InsertCC(take, selected, muted, ppq[i]+(k-1)*5, 0xB0, chan, cc_num, v)
        end
      end
      if ppq_len >= tick and ppq_len < tick * 2 then
          for k,v in pairs(tbl) do
            reaper.MIDI_InsertCC(take, selected, muted, ppq[i]+(k-1)*8, 0xB0, chan, cc_num, v)
          end
      end
      if ppq_len >= tick * 2 then
        for k,v in pairs(tbl) do
          reaper.MIDI_InsertCC(take, selected, muted, ppq[i]+(k-1)*10, 0xB0, chan, cc_num, v)
        end
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