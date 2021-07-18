--[[
 * ReaScript Name: 控制器縮放
 * Version: 1.0.1
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-8-26)
  + Initial release
--]]

function main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelCC(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelCC(take, val)
  end
  reaper.Undo_BeginBlock()
  reaper.MIDI_DisableSort(take)
  if #index > 0 then
    local val_start = reaper.GetExtState("ScaleControl", "Start")
    local val_end = reaper.GetExtState("ScaleControl", "End")
    local toggle = reaper.GetExtState("ScaleControl", "Toggle")
    if (val_start == "") then val_start = "85" end
    if (val_end == "") then val_end = "100" end
    if (toggle == "") then toggle = "1" end
    local userOK, userInputsCSV = reaper.GetUserInputs("控制器縮放", 3, "開始,結束,0=絕對值 1=百分比", val_start..','..val_end..','.. toggle)
    if not userOK then return reaper.SN_FocusMIDIEditor() end
    val_start, val_end, toggle = userInputsCSV:match("(%d*),(%d*),(%d*)")
    if not val_start:match('[%d%.]+') or not val_end:match('[%d%.]+') or not toggle:match('[%d%.]+') then return reaper.SN_FocusMIDIEditor() end
    reaper.SetExtState("ScaleControl", "Start", val_start, false)
    reaper.SetExtState("ScaleControl", "End", val_end, false)
    reaper.SetExtState("ScaleControl", "Toggle", toggle, false)
    local _, _, _, begin_ppqpos, _, _, _, _ = reaper.MIDI_GetCC(take, index[1])
    local _, _, _, end_ppqpos, _, _, _, _ = reaper.MIDI_GetCC(take, index[#index])
    local ppq_offset = (val_end - val_start) / (end_ppqpos - begin_ppqpos)
    for i = 1, #index do
      local _, _, _, startppqpos, _, _, _, value = reaper.MIDI_GetCC(take, index[i])
      if toggle == "1" then
        if end_ppqpos ~= begin_ppqpos then
          new_val = value * (((startppqpos - begin_ppqpos) * ppq_offset + val_start) / 100)
          x = math.floor(new_val)
        else
          x = val_start
        end
      else
        if end_ppqpos ~= begin_ppqpos then
          new_val = (startppqpos - begin_ppqpos) * ppq_offset + val_start
          x = math.floor(new_val)
        else
          x = val_start
        end
      end
      if x > 127 then x = 127 elseif x < 1 then x = 1 end
      reaper.MIDI_SetCC(take, index[i], nil, nil, nil, nil, nil, nil, x, false)
    end
  end
  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock("控制器縮放", -1)
end
function CheckForNewVersion(new_version)
    local app_version = reaper.GetAppVersion()
    app_version = tonumber(app_version:match('[%d%.]+'))
    if new_version > app_version then
      reaper.MB('將REAPER更新到 '..'('..new_version..' 或更高版本)', '', 0)
      return
     else
      return true
    end
end
local CFNV = CheckForNewVersion(6.03)
if CFNV then main() end
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
