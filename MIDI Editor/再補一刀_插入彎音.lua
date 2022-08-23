-- @description 插入彎音
-- @version 1.4.1
-- @author 再補一刀
-- @changelog 優化彎音
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires SWS Extensions

function print(...)
  local params = {...}
  for i = 1, #params do
    if i ~= 1 then reaper.ShowConsoleMsg(" ") end
    reaper.ShowConsoleMsg(tostring(params[i]))
  end
  reaper.ShowConsoleMsg("\n")
end

function table.print(t)
  local print_r_cache = {}
  local function sub_print_r(t, indent)
    if (print_r_cache[tostring(t)]) then
      print(indent .. "*" .. tostring(t))
    else
      print_r_cache[tostring(t)] = true
      if (type(t) == "table") then
        for pos, val in pairs(t) do
          if (type(val) == "table") then
            print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(t) .. " {")
            sub_print_r(val, indent .. string.rep(" ", string.len(tostring(pos)) + 8))
            print(indent .. string.rep(" ", string.len(tostring(pos)) + 6) .. "}")
          elseif (type(val) == "string") then
            print(indent .. "[" .. tostring(pos) .. '] => "' .. val .. '"')
          else
            print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(val))
          end
        end
      else
        print(indent .. tostring(t))
      end
    end
  end
  if (type(t) == "table") then
    print(tostring(t) .. " {")
    sub_print_r(t, "  ")
    print("}")
  else
    sub_print_r(t, "  ")
  end
end

function open_url(url)
  if not OS then local OS = reaper.GetOS() end
  if OS=="OSX32" or OS=="OSX64" then
    os.execute("open ".. url)
  else
    os.execute("start ".. url)
  end
end

if not reaper.SN_FocusMIDIEditor then
  local retval = reaper.ShowMessageBox("這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
  if retval == 1 then
    open_url("http://www.sws-extension.org/download/pre-release/")
  end
end

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local pos = reaper.GetCursorPositionEx()
local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)

local pitchbend = reaper.GetExtState("InsertPitchBend", "值")
if (pitchbend == "") then pitchbend = "0" end
local uok, uinput = reaper.GetUserInputs('插入彎音', 1, 'Value', pitchbend)
if not uok then return reaper.SN_FocusMIDIEditor() end
pitchbend = uinput:match("(.*)")
if not tonumber(pitchbend) then return reaper.SN_FocusMIDIEditor() end
pitchbend = tonumber(pitchbend)

reaper.SetExtState("InsertPitchBend", "Pitchbend", pitchbend, false)

if pitchbend < -8192 or pitchbend > 8191 then
  return reaper.MB("請輸入一個介於 -8192 到 8191 之間的值", "錯誤", 0), reaper.SN_FocusMIDIEditor()
end

reaper.Undo_BeginBlock()
pitchbend = pitchbend + 8192
local LSB = pitchbend & 0x7F
local MSB = (pitchbend >> 7) + 64
reaper.MIDI_InsertCC(take, false, false, ppq, 224, 0, LSB, MSB)
reaper.Undo_EndBlock("插入彎音", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()