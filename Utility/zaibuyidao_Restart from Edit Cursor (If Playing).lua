-- @description Restart Transport If Playing
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao

local playing = (reaper.GetPlayState() & 1) == 1
if playing then
  reaper.Main_OnCommand(1016, 0) -- Transport: Stop
  reaper.Main_OnCommand(1007, 0) -- Transport: Play
end