-- @description Trim MIDI Item Edges
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/u/zaibuyidao
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about
--   Requires JS_ReaScriptAPI & SWS Extension

function get_note_bounds_ppq(take)
  local ret, notecnt = reaper.MIDI_CountEvts(take)
  if not ret or notecnt == 0 then return end

  local min_ppq, max_ppq = math.huge, -math.huge
  for i = 0, notecnt - 1 do
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if retval then
      if startppqpos < min_ppq then min_ppq = startppqpos end
      if endppqpos > max_ppq then max_ppq = endppqpos end
    end
  end
  if min_ppq == math.huge or max_ppq == -math.huge or max_ppq <= min_ppq then
    return
  end
  return min_ppq, max_ppq
end

function trim_item_to_notes(item)
  local take = reaper.GetActiveTake(item)
  if not (take and reaper.TakeIsMIDI(take)) then return false end
  reaper.MIDI_Sort(take)

  local min_ppq, max_ppq = get_note_bounds_ppq(take)
  if not min_ppq then return end

  local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, min_ppq)
  local end_qn = reaper.MIDI_GetProjQNFromPPQPos(take, max_ppq) + 1e-9 -- 末端防截短

  reaper.MIDI_SetItemExtents(item, start_qn, end_qn)
  return true
end

function collect_selected_items()
  local items = {}
  local total = reaper.CountMediaItems(0)
  for i = 0, total - 1 do
    local item = reaper.GetMediaItem(0, i)
    if item and reaper.IsMediaItemSelected(item) then
      items[#items+1] = item
    end
  end
  return items
end

function main()
  local items = collect_selected_items()
  if #items == 0 then return end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local j = 0
  for _, item in ipairs(items) do
    if trim_item_to_notes(item) then
      j = j + 1
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock(string.format("Trim MIDI Item Edges (Processed %d)", j), -1)
end

main()
