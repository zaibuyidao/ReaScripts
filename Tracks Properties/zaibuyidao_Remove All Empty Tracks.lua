-- @description Remove All Empty Tracks
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   + New Script
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function Main()
  local track_count = reaper.CountTracks(0)
  for i = track_count - 1, 0, -1 do -- 从最后一条轨道开始检查，避免删除轨道时影响索引
    local track = reaper.GetTrack(0, i)
    if reaper.CountTrackMediaItems(track) == 0 then
      reaper.DeleteTrack(track) -- 如果轨道中没有item，则删除轨道
    end
  end
end
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock("Remove All Empty Tracks", -1)