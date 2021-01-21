--[[
 * ReaScript Name: 鼓分軌
 * Version: 1.0
 * Author: 再補一刀
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
        if note_name == 0 then  note_name = "[88] Standard1 Kick1" end
        if note_name == 1 then  note_name = "[88] Standard1 Kick2" end
        if note_name == 2 then  note_name = "[88] Standard2 Kick1" end
        if note_name == 3 then  note_name = "[88] Standard2 Kick2" end
        if note_name == 4 then  note_name = "[55] Kick Drum1" end
        if note_name == 5 then  note_name = "[55] Kick Drum2" end
        if note_name == 6 then  note_name = "[88] Jazz Kick1" end
        if note_name == 7 then  note_name = "[88] Jazz Kick2" end
        if note_name == 8 then  note_name = "[88] Room Kick1" end
        if note_name == 9 then  note_name = "[88] Room Kick2" end
        if note_name == 10 then note_name = "[88] Power Kick1" end
        if note_name == 11 then note_name = "[88] Power Kick2" end
        if note_name == 12 then note_name = "[88] Electric Kick2" end
        if note_name == 13 then note_name = "[88] Electric Kick1" end
        if note_name == 14 then note_name = "[88] TR-808 Kick" end
        if note_name == 15 then note_name = "[88] TR-909 Kick" end
        if note_name == 16 then note_name = "[88] Dance Kick" end
        if note_name == 17 then note_name = "Voice One" end
        if note_name == 18 then note_name = "Voice Two" end
        if note_name == 19 then note_name = "Voice Three" end
        if note_name == 22 then note_name = "MC-500 Beep1" end
        if note_name == 23 then note_name = "MC-500 Beep2" end
        if note_name == 24 then note_name = "Concert SD" end
        if note_name == 25 then note_name = "Snare Roll" end
        if note_name == 26 then note_name = "Finger Snap2" end
        if note_name == 27 then note_name = "High Q" end
        if note_name == 28 then note_name = "Slap" end
        if note_name == 29 then note_name = "Scratch Push" end
        if note_name == 30 then note_name = "Scratch Pull" end
        if note_name == 31 then note_name = "Sticks" end
        if note_name == 32 then note_name = "Square Click" end
        if note_name == 33 then note_name = "Metronome Click" end
        if note_name == 34 then note_name = "Metronome  Bell" end
        if note_name == 35 then note_name = "Standard3 Kick2" end
        if note_name == 36 then note_name = "[RND] Kick" end
        if note_name == 37 then note_name = "Side Stick" end
        if note_name == 38 then note_name = "[RND] Snare" end
        if note_name == 39 then note_name = "[RND] Hand Clap" end
        if note_name == 40 then note_name = "Standard3 Snare2" end
        if note_name == 41 then note_name = "Low Tom2" end
        if note_name == 42 then note_name = "[RND] Closed Hi-Hat" end
        if note_name == 43 then note_name = "Low Tom1" end
        if note_name == 44 then note_name = "[RND] Pedal Hi-Hat" end
        if note_name == 45 then note_name = "Mid Tom2" end
        if note_name == 46 then note_name = "[RND] Open Hi-Hat" end
        if note_name == 47 then note_name = "Mid Tom1" end
        if note_name == 48 then note_name = "High Tom2" end
        if note_name == 49 then note_name = "[RND] Crash Cymbal" end
        if note_name == 50 then note_name = "High Tom1" end
        if note_name == 51 then note_name = "[RND] Ride Cymbal1" end
        if note_name == 52 then note_name = "Chinese Cymbal" end
        if note_name == 53 then note_name = "[RND] Ride Bell" end
        if note_name == 54 then note_name = "Tambourine" end
        if note_name == 55 then note_name = "Splash Cymbal" end
        if note_name == 56 then note_name = "Cowbell" end
        if note_name == 57 then note_name = "Crash Cymbal2" end
        if note_name == 58 then note_name = "Vibra-slap" end
        if note_name == 59 then note_name = "[RND] Ride Cymbal2" end
        if note_name == 60 then note_name = "High Bongo" end
        if note_name == 61 then note_name = "Low Bongo" end
        if note_name == 62 then note_name = "Mute High Conga" end
        if note_name == 63 then note_name = "Open High Conga" end
        if note_name == 64 then note_name = "Open Low Conga" end
        if note_name == 65 then note_name = "High Timbale" end
        if note_name == 66 then note_name = "Low Timbale" end
        if note_name == 67 then note_name = "High Agogo" end
        if note_name == 68 then note_name = "Low Agogo" end
        if note_name == 69 then note_name = "Cabasa" end
        if note_name == 70 then note_name = "Maracas" end
        if note_name == 71 then note_name = "Short High Whisle" end
        if note_name == 72 then note_name = "Long Low Whisle" end
        if note_name == 73 then note_name = "Short Guiro" end
        if note_name == 74 then note_name = "Long Guiro" end
        if note_name == 75 then note_name = "Claves" end
        if note_name == 76 then note_name = "High Wood Block" end
        if note_name == 77 then note_name = "Low Wood Block" end
        if note_name == 78 then note_name = "Mute Cuica" end
        if note_name == 79 then note_name = "Open Cuica" end
        if note_name == 80 then note_name = "Mute Triangle" end
        if note_name == 81 then note_name = "Open Triangle" end
        if note_name == 82 then note_name = "Shaker" end
        if note_name == 83 then note_name = "Jingle Bell" end
        if note_name == 84 then note_name = "Bell Tree" end
        if note_name == 85 then note_name = "Castanets" end
        if note_name == 86 then note_name = "Mute Surdo" end
        if note_name == 87 then note_name = "Open Surdo" end
        if note_name == 88 then note_name = "Applaus2" end
        if note_name == 97 then note_name = "[88] Standard1 Snare1" end
        if note_name == 98 then note_name = "[88] Standard1 Snare2" end
        if note_name == 99 then note_name = "[88] Standard2 Snare1" end
        if note_name == 100 then note_name = "[88] Standard2 Snare2" end
        if note_name == 101 then note_name = "[55] Snare Drum2" end
        if note_name == 102 then note_name = "Standard1 Snare1" end
        if note_name == 103 then note_name = "Standard1 Snare2" end
        if note_name == 104 then note_name = "Standard Snare3" end
        if note_name == 105 then note_name = "[88] Jazz Snare1" end
        if note_name == 106 then note_name = "[88] Jazz Snare2" end
        if note_name == 107 then note_name = "[88] Room Snare1" end
        if note_name == 108 then note_name = "[88] Room Snare2" end
        if note_name == 109 then note_name = "[88] Power Snare1" end
        if note_name == 110 then note_name = "[88] Power Snare2" end
        if note_name == 111 then note_name = "[55] Gated Snare" end
        if note_name == 112 then note_name = "[88] Dance Snare1" end
        if note_name == 113 then note_name = "[88] Dance Snare2" end
        if note_name == 114 then note_name = "[88] Disco Snare" end
        if note_name == 115 then note_name = "[88] Electric Snare2" end
        if note_name == 116 then note_name = "[55] Electric Snare" end
        if note_name == 117 then note_name = "[88] Electric Snare 3" end
        if note_name == 118 then note_name = "TR-707 Snare" end
        if note_name == 119 then note_name = "[88] TR-808 Snare1" end
        if note_name == 120 then note_name = "[88] TR-808 Snare2" end
        if note_name == 121 then note_name = "[88] TR-909 Snare1" end
        if note_name == 122 then note_name = "[88] TR-909 Snare2" end
        if note_name == 123 then note_name = "Rap Snare" end
        if note_name == 124 then note_name = "Jungle Snare1" end
        if note_name == 125 then note_name = "House Snare1" end
        if note_name == 126 then note_name = "[88] House Snare" end
        if note_name == 127 then note_name = "House Snare2" end
      elseif track_name == "A11-KICK&SN" then
        if note_name == 25 then note_name = "CR-78 Kick1" end
        if note_name == 26 then note_name = "CR-78 Kick2" end
        if note_name == 27 then note_name = "TR-606 Kick1" end
        if note_name == 28 then note_name = "TR-707 Kick" end
        if note_name == 29 then note_name = "TR-808 Kick" end
        if note_name == 30 then note_name = "Hip-Hop Kick2" end
        if note_name == 31 then note_name = "TR-909 Kick1" end
        if note_name == 32 then note_name = "Hip-Hop Kick3" end
        if note_name == 33 then note_name = "Hip-Hop Kick1" end
        if note_name == 34 then note_name = "Jungle Kick2" end
        if note_name == 35 then note_name = "Jungle Kick1" end
        if note_name == 36 then note_name = "Techno Kick2" end
        if note_name == 37 then note_name = "Techno Kick1" end
        if note_name == 38 then note_name = "Standard1 Kick2" end
        if note_name == 39 then note_name = "Standard1 Kick1" end
        if note_name == 40 then note_name = "[88] Standard1 Kick1" end
        if note_name == 41 then note_name = "[88] Standard1 Kick2" end
        if note_name == 42 then note_name = "[88] Standard2 Kick1" end
        if note_name == 43 then note_name = "[88] Standard2 Kick2" end
        if note_name == 44 then note_name = "[55] Kick Drum1" end
        if note_name == 45 then note_name = "[55] Kick Drum2" end
        if note_name == 46 then note_name = "[88] Soft Kick" end
        if note_name == 47 then note_name = "[88] Jazz Kick1" end
        if note_name == 48 then note_name = "[88] Jazz Kick2" end
        if note_name == 49 then note_name = "[55] Concert BD1" end
        if note_name == 50 then note_name = "[88] Room Kick1" end
        if note_name == 51 then note_name = "[88] Room Kick2" end
        if note_name == 52 then note_name = "[88] Power Kick1" end
        if note_name == 53 then note_name = "[88] Power Kick2" end
        if note_name == 54 then note_name = "[88] Electric Kick2" end
        if note_name == 55 then note_name = "[88] Electric Kick1" end
        if note_name == 56 then note_name = "[55] Electric Kick" end
        if note_name == 57 then note_name = "[88] TR-808 Kick" end
        if note_name == 58 then note_name = "[88] TR-909 Kick" end
        if note_name == 59 then note_name = "[88] Dance Kick" end
        if note_name == 60 then note_name = "[88] Standard1 Snare1" end
        if note_name == 61 then note_name = "[88] Standard1 Snare2" end
        if note_name == 62 then note_name = "[88] Standard2 Snare1" end
        if note_name == 63 then note_name = "[88] Standard2 Snare2" end
        if note_name == 64 then note_name = "[55] Snare Drum2" end
        if note_name == 65 then note_name = "[55] Concert Snare" end
        if note_name == 66 then note_name = "[88] Jazz Snare1" end
        if note_name == 67 then note_name = "[88] Jazz Snare2" end
        if note_name == 68 then note_name = "[88] Room Snare1" end
        if note_name == 69 then note_name = "[88] Room Snare2" end
        if note_name == 70 then note_name = "[88] Power Snare1" end
        if note_name == 71 then note_name = "[88] Power Snare2" end
        if note_name == 72 then note_name = "[55] Gated Snare" end
        if note_name == 73 then note_name = "[88] Dance Snare1" end
        if note_name == 74 then note_name = "[88] Dance Snare2" end
        if note_name == 75 then note_name = "[88] Disco Snare" end
        if note_name == 76 then note_name = "[88] Electric Snare2" end
        if note_name == 77 then note_name = "[88] House Snare" end
        if note_name == 78 then note_name = "[55] Electric Snare1" end
        if note_name == 79 then note_name = "[88] Electric Snare3" end
        if note_name == 80 then note_name = "[88] TR-808 Snare1" end
        if note_name == 81 then note_name = "[88] TR-808 Snare2" end
        if note_name == 82 then note_name = "[88] TR-909 Snare1" end
        if note_name == 83 then note_name = "[88] TR-909 Snare2" end
        if note_name == 84 then note_name = "[88] Brush Tap1" end
        if note_name == 85 then note_name = "[88] Brush Tap2" end
        if note_name == 86 then note_name = "[88] Brush Slap1" end
        if note_name == 87 then note_name = "[88] Brush Slap2" end
        if note_name == 88 then note_name = "[88] Brush Slap3" end
        if note_name == 89 then note_name = "[88] Brush Swirl1" end
        if note_name == 90 then note_name = "[88] Brush Swirl2" end
        if note_name == 91 then note_name = "[88] Brush Long Swirl" end
        if note_name == 92 then note_name = "Standard1 Snare1" end
        if note_name == 93 then note_name = "Standard1 Snare2" end
        if note_name == 94 then note_name = "Standard Snare3" end
        if note_name == 95 then note_name = "Rap Snare" end
        if note_name == 96 then note_name = "Hip-Hop Snare2" end
        if note_name == 97 then note_name = "Jungle Snare1" end
        if note_name == 98 then note_name = "Jungle Snare2" end
        if note_name == 99 then note_name = "Techno Snare1" end
        if note_name == 100 then note_name = " Techno Snare2" end
        if note_name == 101 then note_name = " House Snare2" end
        if note_name == 102 then note_name = " CR-78 Snare1" end
        if note_name == 103 then note_name = " CR-78 Snare2" end
        if note_name == 104 then note_name = " TR-606 Snare1" end
        if note_name == 105 then note_name = " TR-606 Snare2" end
        if note_name == 106 then note_name = " TR-707 Snare1" end
        if note_name == 107 then note_name = " TR-707 Snare2" end
        if note_name == 108 then note_name = " Standard3 Snare2" end
        if note_name == 109 then note_name = " TR-808 Snare2" end
        if note_name == 110 then note_name = " TR-909 Snare1" end
        if note_name == 111 then note_name = " TR-909 Snare2" end
      end

      reaper.GetSetMediaTrackInfo_String(dup_track, "P_NAME", track_name .. " " .. note_name, true) -- 定義重複軌道的名稱

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
            if msg:len() == 3 then
                mb1 = msg:byte(1) >> 4
                if mb1 == 9 or mb1 == 8 then -- note-on/off MIDI事件类型
                    local pitch = msg:byte(2)
                    if pitch ~= note_pitch[i] then
                      msg = ""
                    end
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
reaper.SetMediaTrackInfo_Value(source_track, "B_MUTE", 1) -- 靜音源軌道
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("鼓分軌", 0) -- 撤消塊結束 並在撤消歷史中顯示名稱
