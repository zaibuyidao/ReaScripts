--[[
 * ReaScript Name: Move Selected Items
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-3-15)
  + Initial release
--]]

function main()
	reaper.PreventUIRefresh(1)
	reaper.Undo_BeginBlock()
	count_sel_items = reaper.CountSelectedMediaItems(0)
	if count_sel_items == 0 then return end
	interval = reaper.GetExtState("MoveSelectedItems", "Tick")
    if (interval == "") then interval = "10" end
	userOK, interval = reaper.GetUserInputs("Move Selected Items", 1, "Enter A Tick", interval)
	if not userOK then return end
	reaper.SetExtState("MoveSelectedItems", "Tick", interval, false)
	midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
	for i = 1, count_sel_items do
		item = reaper.GetSelectedMediaItem(0, count_sel_items - i)
		track = reaper.GetMediaItem_Track(item)
		item_id = reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
		item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		qn_item_pos = reaper.TimeMap2_timeToQN(0, item_pos)
		ppq_item_pos = math.floor(qn_item_pos * midi_tick + 0.5) -- 获得item的tick位置
		new_ppq_item_pos = ppq_item_pos + interval
		new_qn_item_pos = new_ppq_item_pos / midi_tick
		new_item_pos = reaper.TimeMap2_QNToTime(0, new_qn_item_pos)
		reaper.SetMediaItemInfo_Value(item, "D_POSITION", new_item_pos)
	end
	reaper.Undo_EndBlock("Move Selected Items", -1)
	reaper.PreventUIRefresh(-1)
	reaper.UpdateArrange()
end
main()
