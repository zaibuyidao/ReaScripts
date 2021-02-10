--[[
 * ReaScript Name: Implode Drums
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2021-1-20)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

function UnselectAllTracks() -- 反選所有軌道
    firstTrack = reaper.GetTrack(0, 0)
    if firstTrack == nil then return end
    reaper.SetOnlyTrackSelected(firstTrack)
    reaper.SetTrackSelected(firstTrack, false)
end

function deleteTrackByName(findname) -- 按軌道名刪除軌道
    for i = reaper.CountTracks()-1, 0, -1 do 
        local track = reaper.GetTrack(0, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", 0)
        if name == findname then
            reaper.DeleteTrack(track)   
            break -- 退出循環/僅刪除一個匹配項
        end 
    end
end

TB = {} -- 將所有用於匹配的軌道名稱存入表中
TB[1] = {"A10-DRUMS CLOSED HI-HAT", "A10-DRUMS PEDAL HI-HAT", "A10-DRUMS OPEN HI-HAT"} -- A10-DRUMS HI-HAT
TB[2] = {"A10-DRUMS HIGH TOM1", "A10-DRUMS HIGH TOM2", "A10-DRUMS MID TOM1", "A10-DRUMS MID TOM2", "A10-DRUMS LOW TOM1", "A10-DRUMS LOW TOM2"} -- A10-DRUMS TOM
TB[3] = {"A10-DRUMS CRASH CYMBAL1", "A10-DRUMS CRASH CYMBAL2"} -- A10-DRUMS CRASH CYMBAL
TB[4] = {"A10-DRUMS RIDE CYMBAL1", "A10-DRUMS RIDE CYMBAL2"} -- A10-DRUMS RIDE CYMBAL
TB[5] = {"B10-DRUMS CLOSED HI-HAT", "B10-DRUMS PEDAL HI-HAT", "B10-DRUMS OPEN HI-HAT"} -- B10-DRUMS HI-HAT
TB[6] = {"B10-DRUMS HIGH TOM1", "B10-DRUMS HIGH TOM2", "B10-DRUMS MID TOM1", "B10-DRUMS MID TOM2", "B10-DRUMS LOW TOM1", "B10-DRUMS LOW TOM2"} -- B10-DRUMS TOM
TB[7] = {"B10-DRUMS CRASH CYMBAL1", "B10-DRUMS CRASH CYMBAL2"} -- B10-DRUMS CRASH CYMBAL
TB[8] = {"B10-DRUMS RIDE CYMBAL1", "B10-DRUMS RIDE CYMBAL2"} -- B10-DRUMS RIDE CYMBAL
TB[9] = {"B11-SUB DRUMS CLOSED HI-HAT", "B11-SUB DRUMS PEDAL HI-HAT", "B11-SUB DRUMS OPEN HI-HAT"} -- B11-SUB DRUMS HI-HAT
TB[10] = {"B11-SUB DRUMS HIGH TOM1", "B11-SUB DRUMS HIGH TOM2", "B11-SUB DRUMS MID TOM1", "B11-SUB DRUMS MID TOM2", "B11-SUB DRUMS LOW TOM1", "B11-SUB DRUMS LOW TOM2"} -- B11-SUB DRUMS TOM
TB[11] = {"B11-SUB DRUMS CRASH CYMBAL1", "B11-SUB DRUMS CRASH CYMBAL2"} -- B11-SUB DRUMS CRASH CYMBAL
TB[12] = {"B11-SUB DRUMS RIDE CYMBAL1", "B11-SUB DRUMS RIDE CYMBAL2"} -- B11-SUB DRUMS RIDE CYMBAL
TB[13] = {"A10-DRUMS HIGH BONGO", "A10-DRUMS LOW BONGO"} -- A10-DRUMS BONGO
TB[14] = {"B10-DRUMS HIGH BONGO", "B10-DRUMS LOW BONGO"} -- B10-DRUMS BONGO
TB[15] = {"B11-SUB DRUMS HIGH BONGO", "B11-SUB DRUMS LOW BONGO"} -- B11-SUB DRUMS BONGO
TB[16] = {"A10-DRUMS MUTE HIGH CONGA", "A10-DRUMS OPEN HIGH CONGA", "A10-DRUMS OPEN LOW CONGA"} -- A10-DRUMS CONGA
TB[17] = {"B10-DRUMS MUTE HIGH CONGA", "B10-DRUMS OPEN HIGH CONGA", "B10-DRUMS OPEN LOW CONGA"} -- B10-DRUMS CONGA
TB[18] = {"B11-SUB DRUMS MUTE HIGH CONGA", "B11-SUB DRUMS OPEN HIGH CONGA", "B11-SUB DRUMS OPEN LOW CONGA"} -- B11-SUB DRUMS CONGA
TB[19] = {"A10-DRUMS HIGH TIMBALE", "A10-DRUMS LOW TIMBALE"} -- A10-DRUMS TIMBALE
TB[20] = {"B10-DRUMS HIGH TIMBALE", "B10-DRUMS LOW TIMBALE"} -- B10-DRUMS TIMBALE
TB[21] = {"B11-SUB DRUMS HIGH TIMBALE", "B11-SUB DRUMS LOW TIMBALE"} -- B11-SUB DRUMS TIMBALE
TB[22] = {"A10-DRUMS HIGH AGOGO", "A10-DRUMS LOW AGOGO"} -- A10-DRUMS AGOGO
TB[23] = {"B10-DRUMS HIGH AGOGO", "B10-DRUMS LOW AGOGO"} -- B10-DRUMS AGOGO
TB[24] = {"B11-SUB DRUMS HIGH AGOGO", "B11-SUB DRUMS LOW AGOGO"} -- B11-SUB DRUMS AGOGO
TB[25] = {"A10-DRUMS SHORT HIGH WHISLE", "A10-DRUMS LONG LOW WHISLE"} -- A10-DRUMS WHISLE
TB[26] = {"B10-DRUMS SHORT HIGH WHISLE", "B10-DRUMS LONG LOW WHISLE"} -- B10-DRUMS WHISLE
TB[27] = {"B11-SUB DRUMS SHORT HIGH WHISLE", "B11-SUB DRUMS LONG LOW WHISLE"} -- B11-SUB DRUMS WHISLE
TB[28] = {"A10-DRUMS SHORT GUIRO", "A10-DRUMS LONG GUIRO"} -- A10-DRUMS GUIRO
TB[29] = {"B10-DRUMS SHORT GUIRO", "B10-DRUMS LONG GUIRO"} -- B10-DRUMS GUIRO
TB[30] = {"B11-SUB DRUMS SHORT GUIRO", "B11-SUB DRUMS LONG GUIRO"} -- B11-SUB DRUMS GUIRO
TB[31] = {"A10-DRUMS HIGH WOOD BLOCK", "A10-DRUMS LOW WOOD BLOCK"} -- A10-DRUMS WOOD BLOCK
TB[32] = {"B10-DRUMS HIGH WOOD BLOCK", "B10-DRUMS LOW WOOD BLOCK"} -- B10-DRUMS WOOD BLOCK
TB[33] = {"B11-SUB DRUMS HIGH WOOD BLOCK", "B11-SUB DRUMS LOW WOOD BLOCK"} -- B11-SUB DRUMS WOOD BLOCK
TB[34] = {"A10-DRUMS MUTE CUICA", "A10-DRUMS OPEN CUICA"} -- A10-DRUMS CUICA
TB[35] = {"B10-DRUMS MUTE CUICA", "B10-DRUMS OPEN CUICA"} -- B10-DRUMS CUICA
TB[36] = {"B11-SUB DRUMS MUTE CUICA", "B11-SUB DRUMS OPEN CUICA"} -- B11-SUB DRUMS CUICA
TB[37] = {"A10-DRUMS MUTE TRIANGLE", "A10-DRUMS OPEN TRIANGLE"} -- A10-DRUMS TRIANGLE
TB[38] = {"B10-DRUMS MUTE TRIANGLE", "B10-DRUMS OPEN TRIANGLE"} -- B10-DRUMS TRIANGLE
TB[39] = {"B11-SUB DRUMS MUTE TRIANGLE", "B11-SUB DRUMS OPEN TRIANGLE"} -- B11-SUB DRUMS TRIANGLE
TB[40] = {"A10-DRUMS MUTE SURDO", "A10-DRUMS OPEN SURDO"} -- A10-DRUMS SURDO
TB[41] = {"B10-DRUMS MUTE SURDO", "B10-DRUMS OPEN SURDO"} -- B10-DRUMS SURDO
TB[42] = {"B11-SUB DRUMS MUTE SURDO", "B11-SUB DRUMS OPEN SURDO"} -- B11-SUB DRUMS SURDO

function ImplodeDrums()
    reaper.Undo_BeginBlock()
    UnselectAllTracks()
    for x = 1, #TB do
        local countTracks = reaper.CountTracks(0) -- 計數所有軌道
        local flagName
        for i = 0, countTracks-1 do
            for j = 0, countTracks-1 do
                local track = reaper.GetTrack(0, j)
                if track ~= nil then
                    reaper.SetTrackSelected(track, false)
                    retval, noteName = reaper.GetTrackName(track, "")
                    if retval then
                        if x == 1 then
                            for key, value in ipairs(TB[1]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true) -- 如果名称符合条件，对应轨道将被选中
                                end
                                flagName = "A10-DRUMS HI-HAT" -- 设置轨道名
                            end
                        end
                        if x == 2 then
                            for key, value in ipairs(TB[2]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "A10-DRUMS TOM"
                            end
                        end
                        if x == 3 then
                            for key, value in ipairs(TB[3]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "A10-DRUMS CRASH CYMBAL"
                            end
                        end
                        if x == 4 then
                            for key, value in ipairs(TB[4]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "A10-DRUMS RIDE CYMBAL"
                            end
                        end
                        if x == 5 then
                            for key, value in ipairs(TB[5]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B10-DRUMS HI-HAT"
                            end
                        end
                        if x == 6 then
                            for key, value in ipairs(TB[6]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B10-DRUMS TOM"
                            end
                        end
                        if x == 7 then
                            for key, value in ipairs(TB[7]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B10-DRUMS CRASH CYMBAL"
                            end
                        end
                        if x == 8 then
                            for key, value in ipairs(TB[8]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B10-DRUMS RIDE CYMBAL"
                            end
                        end
                        if x == 9 then
                            for key, value in ipairs(TB[9]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B11-SUB DRUMS HI-HAT"
                            end
                        end
                        if x == 10 then
                            for key, value in ipairs(TB[10]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B11-SUB DRUMS TOM"
                            end
                        end
                        if x == 11 then
                            for key, value in ipairs(TB[11]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B11-SUB DRUMS CRASH CYMBAL"
                            end
                        end
                        if x == 12 then
                            for key, value in ipairs(TB[12]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B11-SUB DRUMS RIDE CYMBAL"
                            end
                        end
                        if x == 13 then
                            for key, value in ipairs(TB[13]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "A10-DRUMS BONGO"
                            end
                        end
                        if x == 14 then
                            for key, value in ipairs(TB[14]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B10-DRUMS BONGO"
                            end
                        end
                        if x == 15 then
                            for key, value in ipairs(TB[15]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B11-SUB DRUMS BONGO"
                            end
                        end
                        if x == 16 then
                            for key, value in ipairs(TB[16]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "A10-DRUMS CONGA"
                            end
                        end
                        if x == 17 then
                            for key, value in ipairs(TB[17]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B10-DRUMS CONGA"
                            end
                        end
                        if x == 18 then
                            for key, value in ipairs(TB[18]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B11-SUB DRUMS CONGA"
                            end
                        end
                        if x == 19 then
                            for key, value in ipairs(TB[19]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "A10-DRUMS TIMBALE"
                            end
                        end
                        if x == 20 then
                            for key, value in ipairs(TB[20]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B10-DRUMS TIMBALE"
                            end
                        end
                        if x == 21 then
                            for key, value in ipairs(TB[21]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B11-SUB DRUMS TIMBALE"
                            end
                        end
                        if x == 22 then
                            for key, value in ipairs(TB[22]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "A10-DRUMS AGOGO"
                            end
                        end
                        if x == 23 then
                            for key, value in ipairs(TB[23]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B10-DRUMS AGOGO"
                            end
                        end
                        if x == 24 then
                            for key, value in ipairs(TB[24]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B11-SUB DRUMS AGOGO"
                            end
                        end
                        if x == 25 then
                            for key, value in ipairs(TB[25]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "A10-DRUMS WHISLE"
                            end
                        end
                        if x == 26 then
                            for key, value in ipairs(TB[26]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B10-DRUMS WHISLE"
                            end
                        end
                        if x == 27 then
                            for key, value in ipairs(TB[27]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B11-SUB DRUMS WHISLE"
                            end
                        end
                        if x == 28 then
                            for key, value in ipairs(TB[28]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "A10-DRUMS GUIRO"
                            end
                        end
                        if x == 29 then
                            for key, value in ipairs(TB[29]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B10-DRUMS GUIRO"
                            end
                        end
                        if x == 30 then
                            for key, value in ipairs(TB[30]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B11-SUB DRUMS GUIRO"
                            end
                        end
                        if x == 31 then
                            for key, value in ipairs(TB[31]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "A10-DRUMS WOOD BLOCK"
                            end
                        end
                        if x == 32 then
                            for key, value in ipairs(TB[32]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B10-DRUMS WOOD BLOCK"
                            end
                        end
                        if x == 33 then
                            for key, value in ipairs(TB[33]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B11-SUB DRUMS WOOD BLOCK"
                            end
                        end
                        if x == 34 then
                            for key, value in ipairs(TB[34]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "A10-DRUMS CUICA"
                            end
                        end
                        if x == 35 then
                            for key, value in ipairs(TB[35]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B10-DRUMS CUICA"
                            end
                        end
                        if x == 36 then
                            for key, value in ipairs(TB[36]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B11-SUB DRUMS CUICA"
                            end
                        end
                        if x == 37 then
                            for key, value in ipairs(TB[37]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "A10-DRUMS TRIANGLE"
                            end
                        end
                        if x == 38 then
                            for key, value in ipairs(TB[38]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B10-DRUMS TRIANGLE"
                            end
                        end
                        if x == 39 then
                            for key, value in ipairs(TB[39]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B11-SUB DRUMS TRIANGLE"
                            end
                        end
                        if x == 40 then
                            for key, value in ipairs(TB[40]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "A10-DRUMS SURDO"
                            end
                        end
                        if x == 41 then
                            for key, value in ipairs(TB[41]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B10-DRUMS SURDO"
                            end
                        end
                        if x == 42 then
                            for key, value in ipairs(TB[42]) do
                                if noteName == value then
                                    reaper.SetTrackSelected(track, true)
                                end
                                flagName = "B11-SUB DRUMS SURDO"
                            end
                        end
                    end
                end
            end

            reaper.SelectAllMediaItems(0, false) -- 取消選擇所有item

            -- 如果軌道內item大於1，那麼刪除編號為0的item
            for k = 0, reaper.CountSelectedTracks(0)-1 do -- 刪除編號為0的item
                local slelTrack = reaper.GetSelectedTrack(0, k)
                local itemNum = reaper.CountTrackMediaItems(slelTrack)
                if itemNum > 1 then
                    for i = 0, itemNum-1 do
                        local item = reaper.GetTrackMediaItem(slelTrack, i)
                        local item_num = reaper.GetMediaItemInfo_Value(item, 'IP_ITEMNUMBER')
                        if item_num == 0 then reaper.SetMediaItemSelected(item, true) end -- 如果item編號為0那麼選中
                        if item_num > 0 then
                            reaper.Main_OnCommand(40699,0) -- 刪除item
                        end
                    end
                end
            end

            for k = 0, reaper.CountSelectedTracks(0)-1 do -- 計數選中的item
                local slelTrack = reaper.GetSelectedTrack(0, k)
                local itemNum = reaper.CountTrackMediaItems(slelTrack)
                for i = 0, itemNum-1 do
                    local item = reaper.GetTrackMediaItem(slelTrack, i)
                    reaper.SetMediaItemSelected(item, true) -- 設置item為選中，用於之後的合併軌道，粘合item
                    -- local item_num = reaper.GetMediaItemInfo_Value(item, 'IP_ITEMNUMBER')
                    -- if item_num == 0 then reaper.SetMediaItemSelected(item, false) end -- 防止編號為0的item被粘合(啟用有BUG)
                end
            end
        end
        
        reaper.Main_OnCommand(40644, 0) -- Item: Implode items across tracks into items on one track 合併軌道
        reaper.Main_OnCommand(40362, 0) -- Item: Glue items, ignoring time selection 粘合item

        -- 打開MIDI編輯器，並將鼓音符形狀統一設置為三角形
        reaper.Main_OnCommand(40153, 0) -- Item: Open in built-in MIDI editor (set default behavior in preferences) 打開MIDI編輯器
        count_sel_items = reaper.CountSelectedMediaItems(0) -- 選中所有item
        if count_sel_items > 0 then
            for i = 1, count_sel_items do
                local item = reaper.GetSelectedMediaItem(0, i - 1)
                local take = reaper.GetTake(item, 0)
                if not take or not reaper.TakeIsMIDI(take) then return end
                if reaper.GetToggleCommandStateEx(32060, 40448) ~= 1 then -- View: Show events as triangles (drum mode)
                    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40448) -- View: Show events as triangles (drum mode) 切換模式為三角形
                end
                reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40477) -- Misc: Close window if not docked, otherwise pass to main window
            end
        end
        -- 關閉MIDI編輯器，返回主界面

        reaper.SelectAllMediaItems(0, false) -- 粘合item後，item 默認將被選中。此處需執行一次取消選擇所有item

        local countSelTracksAgain = reaper.CountSelectedTracks(0) -- 再次計數選中的軌道
        if countSelTracksAgain > 0 then
            for t = 0, countSelTracksAgain-1 do
                local getSelTrack = reaper.GetSelectedTrack(0, t)
                countItems = reaper.CountTrackMediaItems(getSelTrack) -- 用item去獲取軌道的編號，以用於反選軌道
                for i = 1, countItems do
                    item = reaper.GetMediaItem(0, i - 1)
                    take = reaper.GetTake(item, 0)
                    itemTrack = reaper.GetMediaItem_Track(item)
                    trackNumber = reaper.GetMediaTrackInfo_Value(itemTrack, 'IP_TRACKNUMBER') -- 選中軌道的編號
                end
                reaper.UpdateItemInProject(item)
            end

            trackNumber = trackNumber - 1
            local getCombineTrack = reaper.GetSelectedTrack(0, trackNumber) -- 獲取合併後的主軌道
            reaper.SetTrackSelected(getCombineTrack, false) -- 將主軌道反選
            reaper.Main_OnCommand(40005, 0) -- Track: Remove tracks 移除合併後的次要軌道
            reaper.SetTrackSelected(getCombineTrack, true) -- 再次選中主軌道
            reaper.GetSetMediaTrackInfo_String(getCombineTrack, "P_NAME", flagName, true) -- 改名稱
        end
    end
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Implode Drums", 0)
end

ImplodeDrums()