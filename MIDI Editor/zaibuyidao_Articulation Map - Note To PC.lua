--[[
 * ReaScript Name: Articulation Map - Note To PC
 * Version: 1.4
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-8-4)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function NoteToPC()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take or not reaper.TakeIsMIDI(take) then return end

  local miditick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)

  reaper.gmem_attach('gmem_articulation_map')
  gmem_cc_num = reaper.gmem_read(1)
  gmem_cc_num = math.floor(gmem_cc_num)
  
  local sustainnote = miditick/2

  local track = reaper.GetMediaItemTake_Track(take)
  local pand = reaper.TrackFX_AddByName(track, "Articulation Map", false, 0)
  if pand < 0 then
      gmem_cc_num = 119
  end

  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelNotes(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
  end
  if cnt == 0 then return reaper.SN_FocusMIDIEditor() end

  local MSB, LSB = {}

  local midi_ok, midi_string = reaper.MIDI_GetAllEvts(take, "")
  local string_pos, ticks, table_events, offset, flags, msg = 1, 0, {}
  local pack, unpack = string.pack, string.unpack
  while string_pos < #midi_string do
      offset, flags, msg, string_pos = unpack("i4Bs4", midi_string, string_pos)
      if flags&1 ==1 and #msg >= 3 and msg:byte(1)>>4 == 8 and msg:byte(3) ~= -1 then
          MSB[#MSB+1] = msg:byte(3)
      end
  end

  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()
  reaper.MIDI_DisableSort(take)

  i,idx=2,-1

  tbidx={}
  tbst={}
  tbend={}
  tbchan={}
  tbpitch={}
  tbpitch2={}
  tbvel={}
  tempst=0
  TBinteger={}
  integer = reaper.MIDI_EnumSelNotes(take,idx)

  while (integer ~= -1) do

    integer = reaper.MIDI_EnumSelNotes(take,idx)
    TBinteger[i]=integer
    
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)
    
    if startppqpos == tempst then
      tbidx[i]=integer
      tbst[i]=startppqpos
      tbend[i]=endppqpos
      tbchan[i]=chan
      tbpitch[i]=pitch
      tbpitch2[i]=pitch
      tbvel[i]=vel
      i=i+1
    else 
      -- STRUM it
      low=tbpitch[1]

      for i, v in ipairs(tbpitch) do
        if (low < v) then low=low else low=v end
      end -- get low note

      table.sort (tbpitch)
      tbp_new={}
      for i, v in ipairs(tbpitch) do
        tbp_new [ v ] = i
      end
    
      for i, vv in ipairs(tbidx) do
        reaper.MIDI_SetNote(take, vv, true, false, tbst[i] + (#tbpitch -tbp_new[tbpitch2[i]])*-1, tbend[i], nil, nil,nil, false)
      end --strum it end
      tbidx={}
      tbst={}
      tbend={}
      tbchan={}
      tbpitch={}
      tbpitch2={}
      tbvel={}
      tbidx[1]=integer
      tbst[1]=startppqpos
      tbend[1]=endppqpos
      tbchan[1]=chan
      tbpitch[1]=pitch
      tbpitch2[1]=pitch
      tbvel[1]=vel
      i=2
      tempst = tbst[1]
    end--if end
    
    idx=integer
  end -- while end

  for i = 1, #index do
      retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, index[i])
      if selected == true then
          LSB = vel
          reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, 0, MSB[1])
          reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, 32, LSB)
          reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xC0, chan, pitch, 0)

          if endppqpos - startppqpos > sustainnote then
              reaper.MIDI_InsertCC(take, true, muted, startppqpos-10, 0xB0, chan, gmem_cc_num, 127) -- 插入CC需提前于PC 默认10tick
              reaper.MIDI_InsertCC(take, true, muted, endppqpos, 0xB0, chan, gmem_cc_num, 0)
          end
      end
  end

  i = reaper.MIDI_EnumSelNotes(take, -1)
  while i > -1 do
      reaper.MIDI_DeleteNote(take, i)
      i = reaper.MIDI_EnumSelNotes(take, -1)
  end

  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock("Note To PC", -1)
  reaper.PreventUIRefresh(-1)
end

NoteToPC()
reaper.UpdateArrange()
if (reaper.SN_FocusMIDIEditor) then reaper.SN_FocusMIDIEditor() end