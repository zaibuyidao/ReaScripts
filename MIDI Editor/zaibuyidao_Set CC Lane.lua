--[[
 * ReaScript Name: Set CC Lane
 * Version: 1.2.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-7-29)
  + Initial release
--]]

function Msg(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end
function main()
    reaper.Undo_BeginBlock()
    cc_lane = reaper.GetExtState("SetCCLane", "Parameter")
    if (cc_lane == "") then cc_lane = "v" end
    user_ok, cc_lane = reaper.GetUserInputs("Set CC Lane", 1, "Parameter (CC# or v,p,g,c,b,t,s)", cc_lane)
    reaper.SetExtState("SetCCLane", "Parameter", cc_lane, false)
    if not user_ok then return end
    local HWND = reaper.MIDIEditor_GetActive()
    local take = reaper.MIDIEditor_GetTake(HWND)
    local parameter
    if cc_lane == "v" then
        parameter = 40237 -- CC: Set CC lane to Velocity
    elseif cc_lane == "p" then
        parameter = 40366 -- CC: Set CC lane to Pitch
    elseif cc_lane == "g" then
        parameter = 40367 -- CC: Set CC lane to Program
    elseif cc_lane == "c" then
        parameter = 40368 -- CC: Set CC lane to Channel Pressure
    elseif cc_lane == "b" then
        parameter = 40369 -- CC: Set CC lane to Bank/Program Select
    elseif cc_lane == "t" then
        parameter = 40370 -- CC: Set CC lane to Text Events
    elseif cc_lane == "s" then
        parameter = 40371 -- CC: Set CC lane to Sysex
    else
        cc_lane = tonumber(cc_lane)
        if cc_lane == nil or cc_lane < 0 or cc_lane > 119 then
            cc_lane = "v"
            reaper.SetExtState("SetCCLane", "Parameter", cc_lane, false)
            return reaper.SN_FocusMIDIEditor()
        end
        parameter = cc_lane + 40238 -- CC: Set CC lane to 000 Bank Select MSB
    end
    reaper.MIDIEditor_OnCommand(HWND, parameter)
    reaper.Undo_EndBlock("Set CC lane", -1)
end
main()
reaper.SN_FocusMIDIEditor()
