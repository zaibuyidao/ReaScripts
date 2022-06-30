--[[
 * ReaScript Name: Cakewalk Style Cursor Follow (Main)
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2022-6-30)
  + Initial release
--]]

function print(string)
    reaper.ShowConsoleMsg(tostring(string)..'\n')
end

flag = false

function main()
    isPlay = reaper.GetPlayState()
    if isPlay == 0 then
        if flag == false then
            reaper.Main_OnCommand(39513, 0) -- Set default mouse modifier action for "Media item left click" to "Select item and move edit cursor" (factory default)
            reaper.Main_OnCommand(39577, 0) -- Set default mouse modifier action for "Track left click" to "Deselect all items and move edit cursor" (factory default)
            flag = true
        end
    elseif isPlay == 1 then
        if flag == true then
            reaper.Main_OnCommand(39579, 0) -- Set default mouse modifier action for "Track left click" to "Deselect all items"
            reaper.Main_OnCommand(39515, 0) -- Set default mouse modifier action for "Media item left click" to "Select item"
            flag = false
        end
    end
    reaper.defer(main)
end

local _, _, sectionId, cmdId = reaper.get_action_context()
if sectionId ~= -1 then
    reaper.SetToggleCommandState(sectionId, cmdId, 1)
    reaper.RefreshToolbar2(sectionId, cmdId)
    main()
    reaper.atexit(function()
        reaper.SetToggleCommandState(sectionId, cmdId, 0)
        reaper.RefreshToolbar2(sectionId, cmdId)
    end)
end

reaper.defer(function() end)