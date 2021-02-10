--[[
 * ReaScript Name: Explode Drums
 * Version: 1.3
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2021-1-22)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local source_track = reaper.GetSelectedTrack(0, 0)
local item_num = reaper.CountTrackMediaItems(source_track)

for i = 0, item_num-1 do
  local item = reaper.GetTrackMediaItem(source_track, i)
  local take = reaper.GetActiveTake(item)
  local _, notecnt, _, _ = reaper.MIDI_CountEvts(take) -- 獲取軌道中所有item的音符

  note = {}
  note_pitch = {} -- 存儲音高值

  for i = 1, notecnt do
    note[i] = {}
    note[i].ret,
    note[i].sel,
    note[i].muted,
    note[i].startppqpos,
    note[i].endppqpos,
    note[i].chan,
    note[i].pitch,
    note[i].vel = reaper.MIDI_GetNote(take, i - 1)
    note_pitch[#note_pitch+1] = note[i].pitch -- 將所有item的音高存入note_pitch表中
  end
  table.sort(note_pitch) -- 對音高重新排序，去重
  local index = 1
  while note_pitch[index+1] do
    if note_pitch[index] == note_pitch[index+1] then
      table.remove(note_pitch,index+1)
    else
      index = index + 1
    end
  end
  for k, v in pairs(note_pitch) do
    --Msg(k.."---".. v)
  end

  if reaper.TakeIsMIDI(take) then
    for i = 1, #note_pitch do
      reaper.Main_OnCommand(40062, 0) -- Track: Duplicate tracks
      local _, track_name = reaper.GetSetMediaTrackInfo_String(source_track, "P_NAME", "", false) -- 獲取源軌道的名稱
      local dup_track = reaper.GetSelectedTrack(0, 0) -- 重複的軌道為選中狀態
      local track_num = reaper.GetMediaTrackInfo_Value(source_track, 'IP_TRACKNUMBER') -- 選中軌道的編號
      local note_name = note_pitch[i]

      -- 定義鍵位名稱，符合條件將被映射
      if track_name == "A10-DRUMS" or track_name == "B10-DRUMS" or track_name == "B11-SUB DRUMS" then
        if track_name == "A10-DRUMS" then track_name = "A10-DRUMS " end
        if track_name == "B10-DRUMS" then track_name = "B10-DRUMS " end
        if track_name == "B11-SUB DRUMS" then track_name = "B11-SUB DRUMS " end
        if note_name == 0 then note_name = "STANDARD1 KICK1" end
        if note_name == 1 then note_name = "STANDARD1 KICK2" end
        if note_name == 2 then note_name = "STANDARD2 KICK1" end
        if note_name == 3 then note_name = "STANDARD2 KICK2" end
        if note_name == 4 then note_name = "KICK DRUM1" end
        if note_name == 5 then note_name = "KICK DRUM2" end
        if note_name == 6 then note_name = "JAZZ KICK1" end
        if note_name == 7 then note_name = "JAZZ KICK2" end
        if note_name == 8 then note_name = "ROOM KICK1" end
        if note_name == 9 then note_name = "ROOM KICK2" end
        if note_name == 10 then note_name = "POWER KICK1" end
        if note_name == 11 then note_name = "POWER KICK2" end
        if note_name == 12 then note_name = "ELECTRIC KICK2" end
        if note_name == 13 then note_name = "ELECTRIC KICK1" end
        if note_name == 14 then note_name = "TR-808 KICK" end
        if note_name == 15 then note_name = "TR-909 KICK" end
        if note_name == 16 then note_name = "DANCE KICK" end
        if note_name == 17 then note_name = "VOICE ONE" end
        if note_name == 18 then note_name = "VOICE TWO" end
        if note_name == 19 then note_name = "VOICE THREE" end
        if note_name == 22 then note_name = "MC-500 BEEP1" end
        if note_name == 23 then note_name = "MC-500 BEEP2" end
        if note_name == 24 then note_name = "CONCERT SD" end
        if note_name == 25 then note_name = "SNARE ROLL" end
        if note_name == 26 then note_name = "FINGER SNAP2" end
        if note_name == 27 then note_name = "HIGH Q" end
        if note_name == 28 then note_name = "SLAP" end
        if note_name == 29 then note_name = "SCRATCH PUSH" end
        if note_name == 30 then note_name = "SCRATCH PULL" end
        if note_name == 31 then note_name = "STICKS" end
        if note_name == 32 then note_name = "SQUARE CLICK" end
        if note_name == 33 then note_name = "METRONOME CLICK" end
        if note_name == 34 then note_name = "METRONOME  BELL" end
        if note_name == 35 then note_name = "STANDARD3 KICK2" end
        if note_name == 36 then note_name = "KICK" end
        if note_name == 37 then note_name = "SIDE STICK" end
        if note_name == 38 then note_name = "SNARE" end
        if note_name == 39 then note_name = "HAND CLAP" end
        if note_name == 40 then note_name = "STANDARD3 SNARE2" end
        if note_name == 41 then note_name = "LOW TOM2" end
        if note_name == 42 then note_name = "CLOSED HI-HAT" end
        if note_name == 43 then note_name = "LOW TOM1" end
        if note_name == 44 then note_name = "PEDAL HI-HAT" end
        if note_name == 45 then note_name = "MID TOM2" end
        if note_name == 46 then note_name = "OPEN HI-HAT" end
        if note_name == 47 then note_name = "MID TOM1" end
        if note_name == 48 then note_name = "HIGH TOM2" end
        if note_name == 49 then note_name = "CRASH CYMBAL1" end
        if note_name == 50 then note_name = "HIGH TOM1" end
        if note_name == 51 then note_name = "RIDE CYMBAL1" end
        if note_name == 52 then note_name = "CHINESE CYMBAL" end
        if note_name == 53 then note_name = "RIDE BELL" end
        if note_name == 54 then note_name = "TAMBOURINE" end
        if note_name == 55 then note_name = "SPLASH CYMBAL" end
        if note_name == 56 then note_name = "COWBELL" end
        if note_name == 57 then note_name = "CRASH CYMBAL2" end
        if note_name == 58 then note_name = "VIBRA-SLAP" end
        if note_name == 59 then note_name = "RIDE CYMBAL2" end
        if note_name == 60 then note_name = "HIGH BONGO" end
        if note_name == 61 then note_name = "LOW BONGO" end
        if note_name == 62 then note_name = "MUTE HIGH CONGA" end
        if note_name == 63 then note_name = "OPEN HIGH CONGA" end
        if note_name == 64 then note_name = "OPEN LOW CONGA" end
        if note_name == 65 then note_name = "HIGH TIMBALE" end
        if note_name == 66 then note_name = "LOW TIMBALE" end
        if note_name == 67 then note_name = "HIGH AGOGO" end
        if note_name == 68 then note_name = "LOW AGOGO" end
        if note_name == 69 then note_name = "CABASA" end
        if note_name == 70 then note_name = "MARACAS" end
        if note_name == 71 then note_name = "SHORT HIGH WHISLE" end
        if note_name == 72 then note_name = "LONG LOW WHISLE" end
        if note_name == 73 then note_name = "SHORT GUIRO" end
        if note_name == 74 then note_name = "LONG GUIRO" end
        if note_name == 75 then note_name = "CLAVES" end
        if note_name == 76 then note_name = "HIGH WOOD BLOCK" end
        if note_name == 77 then note_name = "LOW WOOD BLOCK" end
        if note_name == 78 then note_name = "MUTE CUICA" end
        if note_name == 79 then note_name = "OPEN CUICA" end
        if note_name == 80 then note_name = "MUTE TRIANGLE" end
        if note_name == 81 then note_name = "OPEN TRIANGLE" end
        if note_name == 82 then note_name = "SHAKER" end
        if note_name == 83 then note_name = "JINGLE BELL" end
        if note_name == 84 then note_name = "BELL TREE" end
        if note_name == 85 then note_name = "CASTANETS" end
        if note_name == 86 then note_name = "MUTE SURDO" end
        if note_name == 87 then note_name = "OPEN SURDO" end
        if note_name == 88 then note_name = "APPLAUS2" end
        if note_name == 97 then note_name = "STANDARD1 SNARE1" end
        if note_name == 98 then note_name = "STANDARD1 SNARE2" end
        if note_name == 99 then note_name = "STANDARD2 SNARE1" end
        if note_name == 100 then note_name = "STANDARD2 SNARE2" end
        if note_name == 101 then note_name = "SNARE DRUM2" end
        if note_name == 102 then note_name = "STANDARD1 SNARE1" end
        if note_name == 103 then note_name = "STANDARD1 SNARE2" end
        if note_name == 104 then note_name = "STANDARD SNARE3" end
        if note_name == 105 then note_name = "JAZZ SNARE1" end
        if note_name == 106 then note_name = "JAZZ SNARE2" end
        if note_name == 107 then note_name = "ROOM SNARE1" end
        if note_name == 108 then note_name = "ROOM SNARE2" end
        if note_name == 109 then note_name = "POWER SNARE1" end
        if note_name == 110 then note_name = "POWER SNARE2" end
        if note_name == 111 then note_name = "GATED SNARE" end
        if note_name == 112 then note_name = "DANCE SNARE1" end
        if note_name == 113 then note_name = "DANCE SNARE2" end
        if note_name == 114 then note_name = "DISCO SNARE" end
        if note_name == 115 then note_name = "ELECTRIC SNARE2" end
        if note_name == 116 then note_name = "ELECTRIC SNARE" end
        if note_name == 117 then note_name = "ELECTRIC SNARE3" end
        if note_name == 118 then note_name = "TR-707 SNARE" end
        if note_name == 119 then note_name = "TR-808 SNARE1" end
        if note_name == 120 then note_name = "TR-808 SNARE2" end
        if note_name == 121 then note_name = "TR-909 SNARE1" end
        if note_name == 122 then note_name = "TR-909 SNARE2" end
        if note_name == 123 then note_name = "RAP SNARE" end
        if note_name == 124 then note_name = "JUNGLE SNARE1" end
        if note_name == 125 then note_name = "HOUSE SNARE1" end
        if note_name == 126 then note_name = "HOUSE SNARE" end
        if note_name == 127 then note_name = "HOUSE SNARE2" end
      elseif track_name == "A11-KICK&SN" then
        if note_name > 59 and note_name < 112 then track_name = "A11-SN " end
        if note_name > 24 and note_name < 60 then track_name = "A11-KICK " end
        if note_name == 25 then note_name = "CR-78 KICK1" end
        if note_name == 26 then note_name = "CR-78 KICK2" end
        if note_name == 27 then note_name = "TR-606 KICK1" end
        if note_name == 28 then note_name = "TR-707 KICK" end
        if note_name == 29 then note_name = "TR-808 KICK" end
        if note_name == 30 then note_name = "HIP-HOP KICK2" end
        if note_name == 31 then note_name = "TR-909 KICK1" end
        if note_name == 32 then note_name = "HIP-HOP KICK3" end
        if note_name == 33 then note_name = "HIP-HOP KICK1" end
        if note_name == 34 then note_name = "JUNGLE KICK2" end
        if note_name == 35 then note_name = "JUNGLE KICK1" end
        if note_name == 36 then note_name = "TECHNO KICK2" end
        if note_name == 37 then note_name = "TECHNO KICK1" end
        if note_name == 38 then note_name = "STANDARD1 KICK2" end
        if note_name == 39 then note_name = "STANDARD1 KICK1" end
        if note_name == 40 then note_name = "STANDARD1 KICK1" end
        if note_name == 41 then note_name = "STANDARD1 KICK2" end
        if note_name == 42 then note_name = "STANDARD2 KICK1" end
        if note_name == 43 then note_name = "STANDARD2 KICK2" end
        if note_name == 44 then note_name = "KICK DRUM1" end
        if note_name == 45 then note_name = "KICK DRUM2" end
        if note_name == 46 then note_name = "SOFT KICK" end
        if note_name == 47 then note_name = "JAZZ KICK1" end
        if note_name == 48 then note_name = "JAZZ KICK2" end
        if note_name == 49 then note_name = "CONCERT BD1" end
        if note_name == 50 then note_name = "ROOM KICK1" end
        if note_name == 51 then note_name = "ROOM KICK2" end
        if note_name == 52 then note_name = "POWER KICK1" end
        if note_name == 53 then note_name = "POWER KICK2" end
        if note_name == 54 then note_name = "ELECTRIC KICK2" end
        if note_name == 55 then note_name = "ELECTRIC KICK1" end
        if note_name == 56 then note_name = "ELECTRIC KICK" end
        if note_name == 57 then note_name = "TR-808 KICK" end
        if note_name == 58 then note_name = "TR-909 KICK" end
        if note_name == 59 then note_name = "DANCE KICK" end
        if note_name == 60 then note_name = "STANDARD1 SNARE1" end
        if note_name == 61 then note_name = "STANDARD1 SNARE2" end
        if note_name == 62 then note_name = "STANDARD2 SNARE1" end
        if note_name == 63 then note_name = "STANDARD2 SNARE2" end
        if note_name == 64 then note_name = "SNARE DRUM2" end
        if note_name == 65 then note_name = "CONCERT SNARE" end
        if note_name == 66 then note_name = "JAZZ SNARE1" end
        if note_name == 67 then note_name = "JAZZ SNARE2" end
        if note_name == 68 then note_name = "ROOM SNARE1" end
        if note_name == 69 then note_name = "ROOM SNARE2" end
        if note_name == 70 then note_name = "POWER SNARE1" end
        if note_name == 71 then note_name = "POWER SNARE2" end
        if note_name == 72 then note_name = "GATED SNARE" end
        if note_name == 73 then note_name = "DANCE SNARE1" end
        if note_name == 74 then note_name = "DANCE SNARE2" end
        if note_name == 75 then note_name = "DISCO SNARE" end
        if note_name == 76 then note_name = "ELECTRIC SNARE2" end
        if note_name == 77 then note_name = "HOUSE SNARE" end
        if note_name == 78 then note_name = "ELECTRIC SNARE1" end
        if note_name == 79 then note_name = "ELECTRIC SNARE3" end
        if note_name == 80 then note_name = "TR-808 SNARE1" end
        if note_name == 81 then note_name = "TR-808 SNARE2" end
        if note_name == 82 then note_name = "TR-909 SNARE1" end
        if note_name == 83 then note_name = "TR-909 SNARE2" end
        if note_name == 84 then note_name = "BRUSH TAP1" end
        if note_name == 85 then note_name = "BRUSH TAP2" end
        if note_name == 86 then note_name = "BRUSH SLAP1" end
        if note_name == 87 then note_name = "BRUSH SLAP2" end
        if note_name == 88 then note_name = "BRUSH SLAP3" end
        if note_name == 89 then note_name = "BRUSH SWIRL1" end
        if note_name == 90 then note_name = "BRUSH SWIRL2" end
        if note_name == 91 then note_name = "BRUSH LONG SWIRL" end
        if note_name == 92 then note_name = "STANDARD1 SNARE1" end
        if note_name == 93 then note_name = "STANDARD1 SNARE2" end
        if note_name == 94 then note_name = "STANDARD SNARE3" end
        if note_name == 95 then note_name = "RAP SNARE" end
        if note_name == 96 then note_name = "HIP-HOP SNARE2" end
        if note_name == 97 then note_name = "JUNGLE SNARE1" end
        if note_name == 98 then note_name = "JUNGLE SNARE2" end
        if note_name == 99 then note_name = "TECHNO SNARE1" end
        if note_name == 100 then note_name = "TECHNO SNARE2" end
        if note_name == 101 then note_name = "HOUSE SNARE2" end
        if note_name == 102 then note_name = "CR-78 SNARE1" end
        if note_name == 103 then note_name = "CR-78 SNARE2" end
        if note_name == 104 then note_name = "TR-606 SNARE1" end
        if note_name == 105 then note_name = "TR-606 SNARE2" end
        if note_name == 106 then note_name = "TR-707 SNARE1" end
        if note_name == 107 then note_name = "TR-707 SNARE2" end
        if note_name == 108 then note_name = "STANDARD3 SNARE2" end
        if note_name == 109 then note_name = "TR-808 SNARE2" end
        if note_name == 110 then note_name = "TR-909 SNARE1" end
        if note_name == 111 then note_name = "TR-909 SNARE2" end
      end

      reaper.GetSetMediaTrackInfo_String(dup_track, "P_NAME", track_name .. note_name, true) -- 定義重複軌道的名稱

      -- 檢查軌道名字是否重複，重複則跳過
      local track_name_tb = {} -- 將軌道名存入track_name_tb表中進行比較
      local count_track = reaper.CountTracks(0) -- 所有軌道計數
  
      for i = 1, count_track do
        local get_count_track = reaper.GetTrack( 0, i - 1) -- 取得所有軌道
        local _, count_track_name = reaper.GetSetMediaTrackInfo_String(get_count_track, "P_NAME", "", false) -- 獲取新建軌的名稱
        
        track_name_tb[#track_name_tb + 1] = count_track_name -- 所有軌道名稱存入track_name_tb表中
        --Msg(track_name_tb[i]) -- 檢查所有軌道名稱
        
        if i ~= track_num+1 then -- 將重複的軌道排除到索引之外
          if (track_name_tb[track_num+1] == track_name_tb[i]) then -- 判斷軌道名字是否重複，需要重複軌道來與其他軌道做比較
            local count_sel_track = reaper.CountSelectedTracks(0) -- 遍歷選中的軌道，實際只有一軌
            for j = 1, count_sel_track do
              get_sel_track = reaper.GetSelectedTrack(0, j - 1)
              reaper.DeleteTrack(get_sel_track)
              goto continue
            end
          end
        end
      end

      -- 啟動循環以運行所有MIDI item
      item_idx = 0
      while (item_idx < item_num) do
        local item = reaper.GetTrackMediaItem(dup_track, item_idx)
        local take = reaper.GetActiveTake(item)
  
        gotAllOK, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
        MIDIlen = MIDIstring:len()
        tableEvents = {}
  
        stringPos = 1
        while stringPos < MIDIlen do
          offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
          local eventType = (msg:byte(1))>>4
          if msg:len() == 3 and (eventType == 9 or eventType == 8) then
            local pitch = msg:byte(2)
            if pitch ~= note_pitch[i] then -- 刪除指定音高之外的音符
              msg = ""
            end
          elseif msg:len() == 3 and eventType == 11 then
            local ccval = msg:byte(3)
            local ccnum = msg:byte(2)
            if ccnum >= 0 and ccnum <= 127 then -- 刪除所有控制器信息
              msg = " "
            end
          elseif msg:len() == 3 and eventType == 14 then
            local LSB = msg:byte(2) -- Least Significant Byte
            local MSB = msg:byte(3) -- Most Significant Byte
            local value = (128*MSB+LSB)-8192 -- 計算彎音值
            if value >= -8091 and value <= 8191 then -- 刪除所有彎音信息
              msg = ""
            end
          end
          table.insert(tableEvents, string.pack("i4Bs4", offset, flags, msg))
        end
        reaper.MIDI_SetAllEvts(take, table.concat(tableEvents))
        item_idx = item_idx + 1
      end
      ::continue::
      reaper.SetOnlyTrackSelected(source_track) -- 选中源軌道
    end
  end
end
--reaper.SetMediaTrackInfo_Value(source_track, "B_MUTE", 1) -- 靜音源軌道

-- 刪除源軌道所有MIDI音符
local source_item_num = reaper.CountTrackMediaItems(source_track)
for i = 0, source_item_num-1 do
  local source_item = reaper.GetTrackMediaItem(source_track, i)
  local source_take = reaper.GetActiveTake(source_item)
  local _, source_notecnt, _, _ = reaper.MIDI_CountEvts(source_take)
  for i = 0, source_notecnt-1 do
    reaper.MIDI_DeleteNote(source_take, 0)
  end
end
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Explode Drums", 0) -- 撤消塊結束 並在撤消歷史中顯示名稱
