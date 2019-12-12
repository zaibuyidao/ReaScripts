--[[
 * ReaScript Name: Split Notes
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
     + Initial Release
--]]

function SplitNotes(div)
  if div == nil or div <= 0 then return end
  local midieditor, take, notes, len, len_div
  midieditor = reaper.MIDIEditor_GetActive()
  if midieditor == nil then return end
  take = reaper.MIDIEditor_GetTake(midieditor)
  if take == nil then return end
  _, notes = reaper.MIDI_CountEvts(take)
  if notes > 0 then
    notes_t = {}
    for i = 1, notes do
      notes_t[i] = {}
      _, notes_t[i].sel, notes_t[i].muted, notes_t[i].start, notes_t[i].ending, notes_t[i].chan, notes_t[i].pitch, notes_t[i].vel = reaper.MIDI_GetNote(take, i-1)
    end
    
    for i = 1, notes do reaper.MIDI_DeleteNote(take, 0) end
    
    for i = 1, #notes_t do
      if notes_t[i].sel then
        len = notes_t[i].ending - notes_t[i].start
        len_div = math.floor(len / div)
        mult_len = notes_t[i].start + div * len_div
		
        for j = 1, len_div do
          reaper.MIDI_InsertNote(
            take, 
            notes_t[i].sel, 
            notes_t[i].muted, 
            notes_t[i].start + (j-1) * div , 
            notes_t[i].start + (j-1) * div + div, 
            notes_t[i].chan, 
            notes_t[i].pitch, 
            notes_t[i].vel
          )
          if mult_len < notes_t[i].ending then
            reaper.MIDI_InsertNote(
              take, 
              notes_t[i].sel, 
              notes_t[i].muted, 
              notes_t[i].start + div * len_div, 
              notes_t[i].ending, 
              notes_t[i].chan, 
              notes_t[i].pitch, 
              notes_t[i].vel
            )
          end
        end
      else
        reaper.MIDI_InsertNote(
          take, 
          notes_t[i].sel, 
          notes_t[i].muted, 
          notes_t[i].start, 
          notes_t[i].ending, 
          notes_t[i].chan, 
          notes_t[i].pitch, 
          notes_t[i].vel
        )
      end
    end
    reaper.MIDI_Sort(take)
  end
end

script_title = "Split Notes"

userOK, div_ret = reaper.GetUserInputs('Split Notes', 1, 'Length', '240')
div = tonumber(div_ret)
if not userOK then return reaper.SN_FocusMIDIEditor() end

if div ~= nil then
  reaper.Undo_BeginBlock()  
  SplitNotes(div)
  reaper.Undo_EndBlock(script_title, 0)
end

reaper.SN_FocusMIDIEditor()