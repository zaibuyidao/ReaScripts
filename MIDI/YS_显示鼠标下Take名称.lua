--[[
 * ReaScript Name: 显示鼠标下Take名称
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

local ctx = reaper.ImGui_CreateContext('My script')
 reaper.ImGui_SetNextWindowSize(ctx, 500, 50)
  
 function loop()
 Take, position = reaper.BR_TakeAtMouseCursor()
 if Take then
 retval, takename = reaper.GetSetMediaItemTakeInfo_String(Take, 'P_NAME', '', false )
 end

   local visible, open = reaper.ImGui_Begin(ctx, 'AtMouseCursor Take Name', true)
   
   if visible then
     reaper.ImGui_Text(ctx, takename)
     reaper.ImGui_End(ctx)
   end
   
   if open then
     reaper.defer(loop)
   else
     reaper.ImGui_DestroyContext(ctx)
   end
 end
 
 reaper.defer(loop)
 
 _, _, sectionID, ownCommandID, _, _, _ = reaper.get_action_context()
 reaper.SetToggleCommandState(sectionID,ownCommandID,1)
 reaper.RefreshToolbar2(sectionID, ownCommandID)
 function exit()
 reaper.SetToggleCommandState(sectionID,ownCommandID,0)
 reaper.RefreshToolbar2(sectionID,ownCommandID)
 end
 reaper.atexit(exit)
