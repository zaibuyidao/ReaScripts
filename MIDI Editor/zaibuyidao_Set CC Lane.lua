--[[
 * ReaScript Name: Set CC Lane
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-7-29)
  + Initial release
--]]

function main()
    cc_lane = reaper.GetExtState("SetCCLane", "Parameter")
    if (cc_lane == "") then cc_lane = "v" end
    user_ok, cc_lane = reaper.GetUserInputs("Set CC Lane", 1, "Parameter (CC# or v,p,g,s,t)", cc_lane)
    reaper.SetExtState("SetCCLane", "Parameter", cc_lane, false)
    if not user_ok then return end
    local HWND = reaper.MIDIEditor_GetActive()
    local take = reaper.MIDIEditor_GetTake(HWND)
    local parameter
    if cc_lane == "a"
    or cc_lane == "b"
    or cc_lane == "c"
    or cc_lane == "d"
    or cc_lane == "e"
    or cc_lane == "f"
    or cc_lane == "h"
    or cc_lane == "i"
    or cc_lane == "j"
    or cc_lane == "k"
    or cc_lane == "l"
    or cc_lane == "m"
    or cc_lane == "n"
    or cc_lane == "o"
    or cc_lane == "q"
    or cc_lane == "r"
    or cc_lane == "u"
    or cc_lane == "w"
    or cc_lane == "x"
    or cc_lane == "y"
    or cc_lane == "x"
    then return end
    if cc_lane == "v" then -- CC: Set CC lane to Velocity
        parameter = 40237
    elseif cc_lane == "p" then -- CC: Set CC lane to Pitch
        parameter = 40366
    elseif cc_lane == "g" then -- CC: Set CC lane to Program
        parameter = 40367
    elseif cc_lane == "s" then -- CC: Set CC lane to Sysex
        parameter = 40371
    elseif cc_lane == "t" then -- CC: Set CC lane to Text Events
        parameter = 40370
    else
        cc_lane = tonumber(cc_lane)
        if cc_lane >= 0 and cc_lane <= 119 then
            parameter = 40238 + cc_lane
        else
            return reaper.SN_FocusMIDIEditor()
        end
    end
    reaper.MIDIEditor_OnCommand(HWND, parameter)
end
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Set CC lane", -1)
reaper.PreventUIRefresh(-1)
reaper.SN_FocusMIDIEditor()
