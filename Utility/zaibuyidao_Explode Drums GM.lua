--[[
 * ReaScript Name: Explode Drums GM
 * Version: 1.0.1
 * Author: zaibuyidao, YS
 * Reference: drums 自动分轨（GM）.lua (增加編輯器外部支持)
 * REAPER: 6.0
 * provides: [main=main,midi_editor,midi_eventlisteditor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-3-7)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
function TBPitch(param)
    for ii, vv in ipairs(tb_pitch) do
        if vv == param then
            startppqpos, endppqpos, chan, pitch, vel = string.match(tb[ii], '(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
            startppqpos, endppqpos, chan, pitch, vel  = tonumber(startppqpos), tonumber(endppqpos), tonumber(chan), tonumber(pitch), tonumber(vel)
            reaper.MIDI_InsertNote(take_new, false, false, startppqpos, endppqpos, chan, pitch, vel, false)
        end
    end
end

tb_kit = {}
tb_kit[0] = 'KICK_0'
tb_kit[1] = 'KICK_1'
tb_kit[2] = 'KICK_2'
tb_kit[3] = 'KICK_3'
tb_kit[4] = 'KICK_4'
tb_kit[5] = 'KICK_5'
tb_kit[6] = 'KICK_6'
tb_kit[7] = 'KICK_7'
tb_kit[8] = 'KICK_8'
tb_kit[9] = 'KICK_9'
tb_kit[10] = 'KICK_10'
tb_kit[11] = 'KICK_11'
tb_kit[12] = 'KICK_12'
tb_kit[13] = 'KICK_13'
tb_kit[14] = 'KICK_14'
tb_kit[15] = 'KICK_15'
tb_kit[16] = 'KICK_16'
tb_kit[17] = 'VOX'
tb_kit[18] = 'VOX'
tb_kit[19] = 'VOX'
tb_kit[20] = '20'
tb_kit[21] = '21'
tb_kit[22] = 'MC-500 BEEP'
tb_kit[23] = 'MC-500 BEEP'
tb_kit[24] = 'SD'
tb_kit[25] = 'SD ROLL'
tb_kit[26] = 'FINGER SNAP'
tb_kit[27] = 'HIGH Q'
tb_kit[28] = 'SLAP'
tb_kit[29] = 'SCRATCH'
tb_kit[30] = 'SCRATCH'
tb_kit[31] = 'STICK'
tb_kit[32] = 'CLICK'
tb_kit[33] = 'METRONOME'
tb_kit[34] = 'METRONOME'
tb_kit[35] = 'KICK_35'
tb_kit[36] = 'KICK_36'
tb_kit[37] = 'STICK'
tb_kit[38] = 'SN_38'
tb_kit[39] = 'CLAP'
tb_kit[40] = 'SN_40'
tb_kit[41] = 'TOM'
tb_kit[42] = 'HI HAT'
tb_kit[43] = 'TOM'
tb_kit[44] = 'HI HAT'
tb_kit[45] = 'TOM'
tb_kit[46] = 'HI HAT'
tb_kit[47] = 'TOM'
tb_kit[48] = 'TOM'
tb_kit[49] = 'CYM'
tb_kit[50] = 'TOM'
tb_kit[51] = 'RIDE'
tb_kit[52] = 'CYM'
tb_kit[53] = 'RIDE'
tb_kit[54] = 'TAMB'
tb_kit[55] = 'CYM'
tb_kit[56] = 'COWBELL'
tb_kit[57] = 'CYM'
tb_kit[58] = 'VIBRASLAP'
tb_kit[59] = 'RIDE'
tb_kit[60] = 'BONGO'
tb_kit[61] = 'BONGO'
tb_kit[62] = 'CONGA'
tb_kit[63] = 'CONGA'
tb_kit[64] = 'CONGA'
tb_kit[65] = 'TIMBALE'
tb_kit[66] = 'TIMBALE'
tb_kit[67] = 'AGOGO'
tb_kit[68] = 'AGOGO'
tb_kit[69] = 'CABASA'
tb_kit[70] = 'MARACA'
tb_kit[71] = 'WHISTLE'
tb_kit[72] = 'WHISTLE'
tb_kit[73] = 'GUIRO'
tb_kit[74] = 'GUIRO'
tb_kit[75] = 'CLAVES'
tb_kit[76] = 'WOODBLOCK'
tb_kit[77] = 'WOODBLOCK'
tb_kit[78] = 'CUICA'
tb_kit[79] = 'CUICA'
tb_kit[80] = 'TRIANGLE'
tb_kit[81] = 'TRIANGLE'
tb_kit[82] = 'SHAKER'
tb_kit[83] = 'JUNGLE BELL'
tb_kit[84] = 'BELL TREE'
tb_kit[85] = 'CASTANETS'
tb_kit[86] = 'SURDO'
tb_kit[87] = 'SURDO'
tb_kit[88] = 'APPLAUS'
tb_kit[89] = '89'
tb_kit[90] = '90'
tb_kit[91] = '91'
tb_kit[92] = '92'
tb_kit[93] = '93'
tb_kit[94] = '94'
tb_kit[95] = '95'
tb_kit[96] = '96'
tb_kit[97] = 'SN_97'
tb_kit[98] = 'SN_98'
tb_kit[99] = 'SN_99'
tb_kit[100] = 'SN_100'
tb_kit[101] = 'SN_101'
tb_kit[102] = 'SN_102'
tb_kit[103] = 'SN_103'
tb_kit[104] = 'SN_104'
tb_kit[105] = 'SN_105'
tb_kit[106] = 'SN_106'
tb_kit[107] = 'SN_107'
tb_kit[108] = 'SN_108'
tb_kit[109] = 'SN_109'
tb_kit[110] = 'SN_110'
tb_kit[111] = 'SN_111'
tb_kit[112] = 'SN_112'
tb_kit[113] = 'SN_113'
tb_kit[114] = 'SN_114'
tb_kit[115] = 'SN_115'
tb_kit[116] = 'SN_116'
tb_kit[117] = 'SN_117'
tb_kit[118] = 'SN_118'
tb_kit[119] = 'SN_119'
tb_kit[120] = 'SN_120'
tb_kit[121] = 'SN_121'
tb_kit[122] = 'SN_122'
tb_kit[123] = 'SN_123'
tb_kit[124] = 'SN_124'
tb_kit[125] = 'SN_125'
tb_kit[126] = 'SN_126'
tb_kit[127] = 'SN_127'

function DrumsExplode()
    reaper.Undo_BeginBlock()
    local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
    local track0 = reaper.GetMediaItemTake_Track(take)
    local track0_midiport = reaper.GetMediaTrackInfo_Value(track0, 'I_MIDIHWOUT') -- MIDI硬件输出索引
    
    local fold = reaper.GetMediaTrackInfo_Value(track0, 'I_FOLDERDEPTH')
    --item = reaper.GetMediaItemTake_Item(take)
    local itempos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local lenth = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local number0 = reaper.GetMediaTrackInfo_Value(track0, 'IP_TRACKNUMBER')
    
    local retval, track0name = reaper.GetSetMediaTrackInfo_String(track0, 'P_NAME', '', false)
    local item_moban = reaper.GetTrackMediaItem(track0, 0)
    local take_moban = reaper.GetMediaItemTake(item_moban, 0)
    
    idx = 0
    tb_drums = {}
    tb_drums[0] = "A"
    tb_drums[1] = "A"
    tb_drums[2] = "A"
    tb_drums[8] = "A"
    tb_drums[9] = "E"
    tb_drums[10] = "E"
    tb_drums[11] = "E"
    tb_drums[16] = "A"
    tb_drums[24] = "E"
    tb_drums[25] = "E"
    tb_drums[26] = "E"
    tb_drums[27] = "E"
    tb_drums[28] = "E"
    tb_drums[29] = "E"
    tb_drums[30] = "E"
    tb_drums[32] = "J"
    tb_drums[40] = "BR"
    tb_drums[50] = "KS"
    
    while retval == true do
        retval, selected, muted, startpos, chanmsg, chan, msg1, msg2 = reaper.MIDI_GetCC(take_moban, idx)
        if chanmsg == 192 then
            if tb_drums[msg1] == nil then
                drums = 'n'
                reaper.ShowMessageBox('非标准鼓组排列！', '错误！', 0)
                reaper.SN_FocusMIDIEditor()
                return
            else
                drums = tb_drums[msg1]
            end
        end
        idx = idx + 1
    end
    
    if drums == 'E' then tb_kit[97] = 'TECHNO HIT' end
    if drums == 'E' then tb_kit[98] = 'PHILLY HIT' end
    if drums == 'E' then tb_kit[99] = 'SHOCK WAVE' end
    if drums == 'E' then tb_kit[100] = 'LO-FI RAVE' end
    if drums == 'E' then tb_kit[101] = 'BAM HIT' end
    if drums == 'E' then tb_kit[102] = 'BIM HIT' end
    if drums == 'E' then tb_kit[103] = 'TAPE REWIND' end
    if drums == 'E' then tb_kit[104] = 'PHONO NOISE' end
    if drums == 'E' then tb_kit[126] = 'VOICE TAH' end
    if drums == 'E' then tb_kit[127] = 'SLAPPY' end
    if drums == 'J' or drums == 'BR' then tb_kit[100] = 'BRUSH TAP' end
    if drums == 'J' or drums == 'BR' then tb_kit[101] = 'BRUSH TAP' end
    if drums == 'J' or drums == 'BR' then tb_kit[102] = 'BRUSH SLAP' end
    if drums == 'J' or drums == 'BR' then tb_kit[103] = 'BRUSH SLAP' end
    if drums == 'J' or drums == 'BR' then tb_kit[104] = 'BRUSH SLAP' end
    if drums == 'J' or drums == 'BR' then tb_kit[105] = 'BRUSH SWIRL' end
    if drums == 'J' or drums == 'BR' then tb_kit[106] = 'BRUSH SWIRL' end
    if drums == 'J' or drums == 'BR' then tb_kit[107] = 'BRUSH SWIRL' end
    if drums == 'BR' then tb_kit[38] = 'BRUSH TAP' end
    if drums == 'BR' then tb_kit[39] = 'BRUSH SLAP' end
    if drums == 'BR' then tb_kit[40] = 'BRUSH SWIRL' end
    if drums == 'KS' then tb_kit[25] = 'A11-KICK 25' end
    if drums == 'KS' then tb_kit[26] = 'A11-KICK 26' end
    if drums == 'KS' then tb_kit[27] = 'A11-KICK 27' end
    if drums == 'KS' then tb_kit[28] = 'A11-KICK 28' end
    if drums == 'KS' then tb_kit[29] = 'A11-KICK 29' end
    if drums == 'KS' then tb_kit[30] = 'A11-KICK 30' end
    if drums == 'KS' then tb_kit[31] = 'A11-KICK 31' end
    if drums == 'KS' then tb_kit[32] = 'A11-KICK 32' end
    if drums == 'KS' then tb_kit[33] = 'A11-KICK 33' end
    if drums == 'KS' then tb_kit[34] = 'A11-KICK 34' end
    if drums == 'KS' then tb_kit[35] = 'A11-KICK 35' end
    if drums == 'KS' then tb_kit[36] = 'A11-KICK 36' end
    if drums == 'KS' then tb_kit[37] = 'A11-KICK 37' end
    if drums == 'KS' then tb_kit[38] = 'A11-KICK 38' end
    if drums == 'KS' then tb_kit[39] = 'A11-KICK 39' end
    if drums == 'KS' then tb_kit[40] = 'A11-KICK 40' end
    if drums == 'KS' then tb_kit[41] = 'A11-KICK 41' end
    if drums == 'KS' then tb_kit[42] = 'A11-KICK 42' end
    if drums == 'KS' then tb_kit[43] = 'A11-KICK 43' end
    if drums == 'KS' then tb_kit[44] = 'A11-KICK 44' end
    if drums == 'KS' then tb_kit[45] = 'A11-KICK 45' end
    if drums == 'KS' then tb_kit[46] = 'A11-KICK 46' end
    if drums == 'KS' then tb_kit[47] = 'A11-KICK 47' end
    if drums == 'KS' then tb_kit[48] = 'A11-KICK 48' end
    if drums == 'KS' then tb_kit[49] = 'A11-KICK 49' end
    if drums == 'KS' then tb_kit[50] = 'A11-KICK 50' end
    if drums == 'KS' then tb_kit[51] = 'A11-KICK 51' end
    if drums == 'KS' then tb_kit[52] = 'A11-KICK 52' end
    if drums == 'KS' then tb_kit[53] = 'A11-KICK 53' end
    if drums == 'KS' then tb_kit[54] = 'A11-KICK 54' end
    if drums == 'KS' then tb_kit[55] = 'A11-KICK 55' end
    if drums == 'KS' then tb_kit[56] = 'A11-KICK 56' end
    if drums == 'KS' then tb_kit[57] = 'A11-KICK 57' end
    if drums == 'KS' then tb_kit[58] = 'A11-KICK 58' end
    if drums == 'KS' then tb_kit[59] = 'A11-KICK 59' end
    if drums == 'KS' then tb_kit[60] = 'A11-SN 60' end
    if drums == 'KS' then tb_kit[61] = 'A11-SN 61' end
    if drums == 'KS' then tb_kit[62] = 'A11-SN 62' end
    if drums == 'KS' then tb_kit[63] = 'A11-SN 63' end
    if drums == 'KS' then tb_kit[64] = 'A11-SN 64' end
    if drums == 'KS' then tb_kit[65] = 'A11-SN 65' end
    if drums == 'KS' then tb_kit[66] = 'A11-SN 66' end
    if drums == 'KS' then tb_kit[67] = 'A11-SN 67' end
    if drums == 'KS' then tb_kit[68] = 'A11-SN 68' end
    if drums == 'KS' then tb_kit[69] = 'A11-SN 69' end
    if drums == 'KS' then tb_kit[70] = 'A11-SN 70' end
    if drums == 'KS' then tb_kit[71] = 'A11-SN 71' end
    if drums == 'KS' then tb_kit[72] = 'A11-SN 72' end
    if drums == 'KS' then tb_kit[73] = 'A11-SN 73' end
    if drums == 'KS' then tb_kit[74] = 'A11-SN 74' end
    if drums == 'KS' then tb_kit[75] = 'A11-SN 75' end
    if drums == 'KS' then tb_kit[76] = 'A11-SN 76' end
    if drums == 'KS' then tb_kit[77] = 'A11-SN 77' end
    if drums == 'KS' then tb_kit[78] = 'A11-SN 78' end
    if drums == 'KS' then tb_kit[79] = 'A11-SN 79' end
    if drums == 'KS' then tb_kit[80] = 'A11-SN 80' end
    if drums == 'KS' then tb_kit[81] = 'A11-SN 81' end
    if drums == 'KS' then tb_kit[82] = 'A11-SN 82' end
    if drums == 'KS' then tb_kit[83] = 'A11-SN 83' end
    if drums == 'KS' then tb_kit[84] = 'A11-SN 84' end
    if drums == 'KS' then tb_kit[85] = 'A11-SN 85' end
    if drums == 'KS' then tb_kit[86] = 'A11-SN 86' end
    if drums == 'KS' then tb_kit[87] = 'A11-SN 87' end
    if drums == 'KS' then tb_kit[88] = 'A11-SN 88' end
    if drums == 'KS' then tb_kit[89] = 'A11-SN 89' end
    if drums == 'KS' then tb_kit[90] = 'A11-SN 90' end
    if drums == 'KS' then tb_kit[91] = 'A11-SN 91' end
    if drums == 'KS' then tb_kit[92] = 'A11-SN 92' end
    if drums == 'KS' then tb_kit[93] = 'A11-SN 93' end
    if drums == 'KS' then tb_kit[94] = 'A11-SN 94' end
    if drums == 'KS' then tb_kit[95] = 'A11-SN 95' end
    if drums == 'KS' then tb_kit[96] = 'A11-SN 96' end
    if drums == 'KS' then tb_kit[97] = 'A11-SN 97' end
    if drums == 'KS' then tb_kit[98] = 'A11-SN 98' end
    if drums == 'KS' then tb_kit[99] = 'A11-SN 99' end
    if drums == 'KS' then tb_kit[100] = 'A11-SN 100' end
    if drums == 'KS' then tb_kit[101] = 'A11-SN 101' end
    if drums == 'KS' then tb_kit[102] = 'A11-SN 102' end
    if drums == 'KS' then tb_kit[103] = 'A11-SN 103' end
    if drums == 'KS' then tb_kit[104] = 'A11-SN 104' end
    if drums == 'KS' then tb_kit[105] = 'A11-SN 105' end
    if drums == 'KS' then tb_kit[106] = 'A11-SN 106' end
    if drums == 'KS' then tb_kit[107] = 'A11-SN 107' end
    if drums == 'KS' then tb_kit[108] = 'A11-SN 108' end
    if drums == 'KS' then tb_kit[109] = 'A11-SN 109' end
    if drums == 'KS' then tb_kit[110] = 'A11-SN 110' end
    if drums == 'KS' then tb_kit[111] = 'A11-SN 111' end
    
    reaper.MIDI_DisableSort(take)
    retal, notecnt, cccnt, evtcnt = reaper.MIDI_CountEvts(take)
    tb = {}
    tbkey = {}
    tbkey2 = {}
    tb_pitch = {}
    idx = 0
    while idx < notecnt do
        retval, selected, muted, startpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, idx)
        reaper.MIDI_SetNote(take, idx, true, false, NULL, NULL, NULL, NULL, NULL, false)
        table.insert(tb, startpos .. ',' .. endppqpos .. ',' .. chan .. ',' .. pitch .. ',' .. vel)
        table.insert(tbkey, tb_kit[pitch])
        table.insert(tb_pitch, pitch)
        idx = idx + 1
    end
    reaper.MIDI_Sort(take)
    --reaper.MIDIEditor_OnCommand(editor, 40002) -- delete all note

    i = reaper.MIDI_EnumSelNotes(take, -1)
    while i > -1 do
      reaper.MIDI_DeleteNote(take, i)
      i = reaper.MIDI_EnumSelNotes(take, -1)
    end

    i = 1
    while tbkey[i] ~= nil do
        tbkey2[i] = tbkey[i]
        i = i + 1
    end

    table.sort(tbkey2)

    tbkey3 = {}
    i = 1
    tempkey = -1
    while i <= #tbkey2 do
        if tbkey2[i] ~= tempkey then
            table.insert(tbkey3, tbkey2[i])
            tempkey = tbkey2[i]
        end
        i = i + 1
    end
    
    track1 = reaper.GetTrack(0, 0)

    flag = 0
    for i, v in ipairs(tbkey3) do
        reaper.InsertTrackAtIndex(number0, false)
        local track_new = reaper.GetTrack(0, number0)
        local _, track_name = reaper.GetSetMediaTrackInfo_String(track0, "P_NAME", "", false)

        reaper.SetMediaTrackInfo_Value(track_new, 'I_MIDIHWOUT', track0_midiport)
        if fold < 0 and flag == 0 then
            reaper.SetMediaTrackInfo_Value(track0, 'I_FOLDERDEPTH', 0)
            reaper.SetMediaTrackInfo_Value(track_new, 'I_FOLDERDEPTH', fold)
            flag = 1
        end
        reaper.CreateTrackSend(track1, track_new)
        reaper.SetTrackSendInfo_Value(track_new, -1, 0, 'B_MUTE', 1)

        if track0name == '' then
            reaper.GetSetMediaTrackInfo_String(track_new, "P_NAME", track0name .. '' .. v, true)
        elseif track0name == "A11-KICK&SN" then
            reaper.GetSetMediaTrackInfo_String(track_new, "P_NAME", v, true)
        else
            reaper.GetSetMediaTrackInfo_String(track_new, "P_NAME", track0name .. ' ' .. v, true)
        end
        
        item_new = reaper.CreateNewMIDIItemInProj(track_new, itempos, itempos + lenth, false)
        take_new = reaper.GetMediaItemTake(item_new, 0)
        item_new2 = reaper.CreateNewMIDIItemInProj(track_new, 0, 0.05, false)
        take_new2 = reaper.GetMediaItemTake(item_new2, 0)
        reaper.MIDI_InsertEvt(take_new2, false, false, 0, string.char(0xFF, 0x21, 0x01, 0x00)) -- 插入PORT
        reaper.MIDI_DisableSort(take_new)
    
        if v == 'A11-KICK 25' then TBPitch(25) end
        if v == 'A11-KICK 26' then TBPitch(26) end
        if v == 'A11-KICK 27' then TBPitch(27)  end
        if v == 'A11-KICK 28' then TBPitch(28) end
        if v == 'A11-KICK 29' then TBPitch(29) end
        if v == 'A11-KICK 30' then TBPitch(30) end
        if v == 'A11-KICK 31' then TBPitch(31) end
        if v == 'A11-KICK 32' then TBPitch(32) end
        if v == 'A11-KICK 33' then TBPitch(33) end
        if v == 'A11-KICK 34' then TBPitch(34) end
        if v == 'A11-KICK 35' then TBPitch(35) end
        if v == 'A11-KICK 36' then TBPitch(36) end
        if v == 'A11-KICK 37' then TBPitch(37) end
        if v == 'A11-KICK 38' then TBPitch(38) end
        if v == 'A11-KICK 39' then TBPitch(39) end
        if v == 'A11-KICK 40' then TBPitch(40) end
        if v == 'A11-KICK 41' then TBPitch(41) end
        if v == 'A11-KICK 42' then TBPitch(42) end
        if v == 'A11-KICK 43' then TBPitch(43) end
        if v == 'A11-KICK 44' then TBPitch(44) end
        if v == 'A11-KICK 45' then TBPitch(45) end
        if v == 'A11-KICK 46' then TBPitch(46) end
        if v == 'A11-KICK 47' then TBPitch(47) end
        if v == 'A11-KICK 48' then TBPitch(48) end
        if v == 'A11-KICK 49' then TBPitch(49) end
        if v == 'A11-KICK 50' then TBPitch(50) end
        if v == 'A11-KICK 51' then TBPitch(51) end
        if v == 'A11-KICK 52' then TBPitch(52) end
        if v == 'A11-KICK 53' then TBPitch(53) end
        if v == 'A11-KICK 54' then TBPitch(54) end
        if v == 'A11-KICK 55' then TBPitch(55) end
        if v == 'A11-KICK 56' then TBPitch(56) end
        if v == 'A11-KICK 57' then TBPitch(57) end
        if v == 'A11-KICK 58' then TBPitch(58) end
        if v == 'A11-KICK 59' then TBPitch(59) end
        if v == 'A11-SN 60' then TBPitch(60) end
        if v == 'A11-SN 61' then TBPitch(61) end
        if v == 'A11-SN 62' then TBPitch(62) end
        if v == 'A11-SN 63' then TBPitch(63) end
        if v == 'A11-SN 64' then TBPitch(64) end
        if v == 'A11-SN 65' then TBPitch(65) end
        if v == 'A11-SN 66' then TBPitch(66) end
        if v == 'A11-SN 67' then TBPitch(67) end
        if v == 'A11-SN 68' then TBPitch(68) end
        if v == 'A11-SN 69' then TBPitch(69) end
        if v == 'A11-SN 70' then TBPitch(70) end
        if v == 'A11-SN 71' then TBPitch(71) end
        if v == 'A11-SN 72' then TBPitch(72) end
        if v == 'A11-SN 73' then TBPitch(73) end
        if v == 'A11-SN 74' then TBPitch(74) end
        if v == 'A11-SN 75' then TBPitch(75) end
        if v == 'A11-SN 76' then TBPitch(76) end
        if v == 'A11-SN 77' then TBPitch(77) end
        if v == 'A11-SN 78' then TBPitch(78) end
        if v == 'A11-SN 79' then TBPitch(79) end
        if v == 'A11-SN 80' then TBPitch(80) end
        if v == 'A11-SN 81' then TBPitch(81) end
        if v == 'A11-SN 82' then TBPitch(82) end
        if v == 'A11-SN 83' then TBPitch(83) end
        if v == 'A11-SN 84' then TBPitch(84) end
        if v == 'A11-SN 85' then TBPitch(85) end
        if v == 'A11-SN 86' then TBPitch(86) end
        if v == 'A11-SN 87' then TBPitch(87) end
        if v == 'A11-SN 88' then TBPitch(88) end
        if v == 'A11-SN 89' then TBPitch(89) end
        if v == 'A11-SN 90' then TBPitch(90) end
        if v == 'A11-SN 91' then TBPitch(91) end
        if v == 'A11-SN 92' then TBPitch(92) end
        if v == 'A11-SN 93' then TBPitch(93) end
        if v == 'A11-SN 94' then TBPitch(94) end
        if v == 'A11-SN 95' then TBPitch(95) end
        if v == 'A11-SN 96' then TBPitch(96) end
        if v == 'A11-SN 97' then TBPitch(97) end
        if v == 'A11-SN 98' then TBPitch(98) end
        if v == 'A11-SN 99' then TBPitch(99) end
        if v == 'A11-SN 100' then TBPitch(100) end
        if v == 'A11-SN 101' then TBPitch(101) end
        if v == 'A11-SN 102' then TBPitch(102) end
        if v == 'A11-SN 103' then TBPitch(103) end
        if v == 'A11-SN 104' then TBPitch(104) end
        if v == 'A11-SN 105' then TBPitch(105) end
        if v == 'A11-SN 106' then TBPitch(106) end
        if v == 'A11-SN 107' then TBPitch(107) end
        if v == 'A11-SN 108' then TBPitch(108) end
        if v == 'A11-SN 109' then TBPitch(109) end
        if v == 'A11-SN 110' then TBPitch(110) end
        if v == 'A11-SN 111' then TBPitch(111) end

        if v == 'KICK_0' then TBPitch(0) end
        if v == 'KICK_1' then TBPitch(1) end
        if v == 'KICK_2' then TBPitch(2) end
        if v == 'KICK_3' then TBPitch(3) end
        if v == 'KICK_4' then TBPitch(4) end
        if v == 'KICK_5' then TBPitch(5) end
        if v == 'KICK_6' then TBPitch(6) end
        if v == 'KICK_7' then TBPitch(7) end
        if v == 'KICK_8' then TBPitch(8) end
        if v == 'KICK_9' then TBPitch(9) end
        if v == 'KICK_10' then TBPitch(10) end
        if v == 'KICK_11' then TBPitch(11) end
        if v == 'KICK_12' then TBPitch(12) end
        if v == 'KICK_13' then TBPitch(13) end
        if v == 'KICK_14' then TBPitch(14) end
        if v == 'KICK_15' then TBPitch(15) end
        if v == 'KICK_16' then TBPitch(16) end
        if v == 'VOX' then TBPitch(17) end
        if v == 'VOX' then TBPitch(18) end
        if v == 'VOX' then TBPitch(19) end
        if v == '20' then TBPitch(20) end
        if v == '21' then TBPitch(21) end
        if v == 'MC-500 BEEP' then TBPitch(22) end
        if v == 'MC-500 BEEP' then TBPitch(23) end
        if v == 'SD' then TBPitch(24) end
        if v == 'SD ROLL' then TBPitch(25) end
        if v == 'FINGER SNAP' then TBPitch(26) end
        if v == 'HIGH Q' then TBPitch(27) end
        if v == 'SLAP' then TBPitch(28) end
        if v == 'SCRATCH' then TBPitch(29) end
        if v == 'SCRATCH' then TBPitch(30) end
        if v == 'STICK' then TBPitch(31) end    
        if v == 'CLICK' then TBPitch(32) end
        if v == 'METRONOME' then TBPitch(33) end
        if v == 'METRONOME' then TBPitch(34) end
        if v == 'KICK_35' then TBPitch(35) end
        if v == 'KICK_36' then TBPitch(36) end
        if v == 'STICK' then TBPitch(37) end
        if v == 'SN_38' then TBPitch(38) end
        if v == 'CLAP' then TBPitch(39) end
        if v == 'SN_40' then TBPitch(40) end
        if v == 'CYM' then take_cym = take_new TBPitch(49) end
        if v == 'CYM' then take_cym = take_new TBPitch(52) end
        if v == 'CYM' then take_cym = take_new TBPitch(55) end
        if v == 'CYM' then take_cym = take_new TBPitch(57) end
        if v == 'HI HAT' then TBPitch(42) end
        if v == 'HI HAT' then TBPitch(44) end
        if v == 'HI HAT' then TBPitch(46) end
        if v == 'RIDE' then TBPitch(51) end
        if v == 'RIDE' then TBPitch(53) end
        if v == 'RIDE' then TBPitch(59) end
        if v == 'TOM' then TBPitch(41) end
        if v == 'TOM' then TBPitch(43) end
        if v == 'TOM' then TBPitch(45) end
        if v == 'TOM' then TBPitch(47) end
        if v == 'TOM' then TBPitch(48) end
        if v == 'TOM' then TBPitch(50) end
        if v == 'TAMB' then TBPitch(54) end
        if v == 'COWBELL' then TBPitch(56) end
        if v == 'VIBRASLAP' then TBPitch(58) end
        if v == 'CONGA' then TBPitch(62) end
        if v == 'CONGA' then TBPitch(63) end
        if v == 'CONGA' then TBPitch(64) end
        if v == 'BONGO' then TBPitch(60) end
        if v == 'BONGO' then TBPitch(61) end
        if v == 'TIMBALE' then TBPitch(65) end
        if v == 'TIMBALE' then TBPitch(66) end
        if v == 'AGOGO' then TBPitch(67) end
        if v == 'AGOGO' then TBPitch(68) end
        if v == 'CABASA' then TBPitch(69) end
        if v == 'MARACA' then TBPitch(70) end
        if v == 'WHISTLE' then TBPitch(71) end
        if v == 'WHISTLE' then TBPitch(72) end
        if v == 'GUIRO' then TBPitch(73) end
        if v == 'GUIRO' then TBPitch(74) end
        if v == 'WOODBLOCK' then TBPitch(76) end
        if v == 'WOODBLOCK' then TBPitch(77) end
        if v == 'CUICA' then TBPitch(78) end
        if v == 'CUICA' then TBPitch(79) end
        if v == 'TRIANGLE' then TBPitch(80) end
        if v == 'TRIANGLE' then TBPitch(81) end
        if v == 'CLAVES' then TBPitch(75) end
        if v == 'SHAKER' then TBPitch(82) end
        if v == 'JUNGLE BELL' then TBPitch(83) end
        if v == 'BELL TREE' then TBPitch(84) end
        if v == 'CASTANETS' then TBPitch(85) end
        if v == 'SURDO' then TBPitch(86) end
        if v == 'SURDO' then TBPitch(87) end
        if v == 'APPLAUS' then TBPitch(88) end
        if v == '89' then TBPitch(89) end
        if v == '90' then TBPitch(90) end
        if v == '91' then TBPitch(91) end
        if v == '92' then TBPitch(92) end
        if v == '93' then TBPitch(93) end
        if v == '94' then TBPitch(94) end
        if v == '95' then TBPitch(95) end
        if v == '96' then TBPitch(96) end
        if v == 'SN_97' then TBPitch(97) end
        if v == 'SN_98' then TBPitch(98) end
        if v == 'SN_99' then TBPitch(99) end
        if v == 'SN_100' then TBPitch(100) end
        if v == 'SN_101' then TBPitch(101) end
        if v == 'SN_102' then TBPitch(102) end
        if v == 'SN_103' then TBPitch(103) end
        if v == 'SN_104' then TBPitch(104) end
        if v == 'SN_105' then TBPitch(105) end
        if v == 'SN_106' then TBPitch(106) end
        if v == 'SN_107' then TBPitch(107) end
        if v == 'SN_108' then TBPitch(108) end
        if v == 'SN_109' then TBPitch(109) end
        if v == 'SN_110' then TBPitch(110) end
        if v == 'SN_111' then TBPitch(111) end
        if v == 'SN_112' then TBPitch(112) end
        if v == 'SN_113' then TBPitch(113) end
        if v == 'SN_114' then TBPitch(114) end
        if v == 'SN_115' then TBPitch(115) end
        if v == 'SN_116' then TBPitch(116) end
        if v == 'SN_117' then TBPitch(117) end
        if v == 'SN_118' then TBPitch(118) end
        if v == 'SN_119' then TBPitch(119) end
        if v == 'SN_120' then TBPitch(120) end
        if v == 'SN_121' then TBPitch(121) end
        if v == 'SN_122' then TBPitch(122) end
        if v == 'SN_123' then TBPitch(123) end
        if v == 'SN_124' then TBPitch(124) end
        if v == 'SN_125' then TBPitch(125) end
        if v == 'SN_126' then TBPitch(126) end
        if v == 'SN_127' then TBPitch(127) end
        if v == 'TECHNO HIT' then TBPitch(97) end
        if v == 'PHILLY HIT' then TBPitch(98) end
        if v == 'SHOCK WAVE' then TBPitch(99) end
        if v == 'LO-FI RAVE' then TBPitch(100) end
        if v == 'BAM HIT' then TBPitch(101) end
        if v == 'BIM HIT' then TBPitch(102) end
        if v == 'TAPE REWIND' then TBPitch(103) end
        if v == 'PHONO NOISE' then TBPitch(104) end
        if v == 'VOICE TAH' then TBPitch(126) end
        if v == 'SLAPPY' then TBPitch(127) end
        if v == 'BRUSH TAP' then TBPitch(38) end
        if v == 'BRUSH TAP' then TBPitch(100) end
        if v == 'BRUSH TAP' then TBPitch(101) end
        if v == 'BRUSH SLAP' then TBPitch(39) end
        if v == 'BRUSH SLAP' then TBPitch(102) end
        if v == 'BRUSH SLAP' then TBPitch(103) end
        if v == 'BRUSH SLAP' then TBPitch(104) end
        if v == 'BRUSH SWIRL' then TBPitch(40) end
        if v == 'BRUSH SWIRL' then TBPitch(105) end
        if v == 'BRUSH SWIRL' then TBPitch(106) end
        if v == 'BRUSH SWIRL' then TBPitch(107) end
    
        reaper.MIDI_Sort(take_new)
    end -- tbkey end

    if take_cym ~= nil then
        reaper.MIDI_DisableSort(take_cym)
        reaper.MIDI_SelectAll(take_cym, false)
        local idx = 0
        cym_49 = {}
        cym_52 = {}
        cym_55 = {}
        cym_57 = {}
        cym_49_n = {}
        cym_52_n = {}
        cym_55_n = {}
        cym_57_n = {}
        cym_49_tick = {}
        cym_52_tick = {}
        cym_55_tick = {}
        cym_57_tick = {}
        cym_49_tick[0] = -81
        cym_52_tick[0] = -81
        cym_55_tick[0] = -81
        cym_57_tick[0] = -81
        idx_49 = {}
        idx_52 = {}
        idx_55 = {}
        idx_57 = {}
        idx_49_n = {}
        idx_52_n = {}
        idx_55_n = {}
        idx_57_n = {}
        repeat
            local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take_cym, idx)
            if pitch == 49 then
                table.insert(cym_49, startppqpos .. ',' .. endppqpos .. ',' .. chan .. ',' .. pitch .. ',' .. vel)
                table.insert(cym_49_tick, startppqpos)
                table.insert(idx_49, idx)
            end
            if pitch == 52 then
                table.insert(cym_52, startppqpos .. ',' .. endppqpos .. ',' .. chan .. ',' .. pitch .. ',' .. vel)
                table.insert(cym_52_tick, startppqpos)
                table.insert(idx_52, idx)
            end
            if pitch == 55 then
                table.insert(cym_55, startppqpos .. ',' .. endppqpos .. ',' .. chan .. ',' .. pitch .. ',' .. vel)
                table.insert(cym_55_tick, startppqpos)
                table.insert(idx_55, idx)
            end
            if pitch == 57 then
                table.insert(cym_57, startppqpos .. ',' .. endppqpos .. ',' .. chan .. ',' .. pitch .. ',' .. vel)
                table.insert(cym_57_tick, startppqpos)
                table.insert(idx_57, idx)
            end
            idx = idx + 1
        until retval == false
    
        if #cym_49_tick > 0 then
            i = 0
            max = #cym_49_tick
            table.insert(cym_49_tick, cym_49_tick[max] + 81)
            while i < max do
                if cym_49_tick[i + 1] - cym_49_tick[i] < 81 or cym_49_tick[i + 2] - cym_49_tick[i + 1] < 81 then
                    table.insert(cym_49_n, cym_49[i + 1])
                    reaper.MIDI_SetNote(take_cym, idx_49[i + 1], true, false, nil, nil, nil, nil, nil, false)
                end
                i = i + 1
            end
        end
    
        if #cym_52_tick > 0 then
            i = 0
            max = #cym_52_tick
            table.insert(cym_52_tick, cym_52_tick[max] + 81)
            while i < max do
                if cym_52_tick[i + 1] - cym_52_tick[i] < 81 or cym_52_tick[i + 2] - cym_52_tick[i + 1] < 81 then
                    table.insert(cym_52_n, cym_52[i + 1])
                    reaper.MIDI_SetNote(take_cym, idx_52[i + 1], true, false, nil, nil, nil, nil, nil, false)
                end
                i = i + 1
            end
        end
    
        if #cym_55_tick > 0 then
            i = 0
            max = #cym_55_tick
            table.insert(cym_55_tick, cym_55_tick[max] + 81)
            while i < max do
                if cym_55_tick[i + 1] - cym_55_tick[i] < 81 or cym_55_tick[i + 2] - cym_55_tick[i + 1] < 81 then
                    table.insert(cym_55_n, cym_55[i + 1])
                    reaper.MIDI_SetNote(take_cym, idx_55[i + 1], true, false, nil, nil, nil, nil, nil, false)
                end
                i = i + 1
            end
        end
    
        if #cym_57_tick > 0 then
            i = 0
            max = #cym_57_tick
            table.insert(cym_57_tick, cym_57_tick[max] + 81)
            while i < max do
                if cym_57_tick[i + 1] - cym_57_tick[i] < 81 or cym_57_tick[i + 2] - cym_57_tick[i + 1] < 81 then
                    table.insert(cym_57_n, cym_57[i + 1])
                    reaper.MIDI_SetNote(take_cym, idx_57[i + 1], true, false, nil, nil, nil, nil, nil, false)
                end
                i = i + 1
            end
        end
        selnoteidx = reaper.MIDI_EnumSelNotes(take_cym, -1)
        while selnoteidx ~= -1 do
            reaper.MIDI_DeleteNote(take_cym, selnoteidx)
            selnoteidx = reaper.MIDI_EnumSelNotes(take_cym, -1)
        end
    
        reaper.MIDI_Sort(take_cym)
    
        track_cym = reaper.GetMediaItemTake_Track(take_cym)
        track_cym_midiport = reaper.GetMediaTrackInfo_Value(track_cym, 'I_MIDIHWOUT')
        fold_cym = reaper.GetMediaTrackInfo_Value(track_cym, 'I_FOLDERDEPTH')
        item_cym = reaper.GetMediaItemTake_Item(take_cym)
        st_cym = reaper.GetMediaItemInfo_Value(item_cym, 'D_POSITION')
        lenth_cym = reaper.GetMediaItemInfo_Value(item_cym, 'D_LENGTH')
        number_cym = reaper.GetMediaTrackInfo_Value(track_cym, 'IP_TRACKNUMBER')
        _, track_cym_name = reaper.GetSetMediaTrackInfo_String(track_cym, 'P_NAME', '', false)
        track1 = reaper.GetTrack(0, 0)
    
        if #cym_49_n > 0 or #cym_52_n > 0 or #cym_55_n > 0 or #cym_57_n > 0 then
            reaper.InsertTrackAtIndex(number_cym, false)
            track_roll = reaper.GetTrack(0, number_cym)
            reaper.SetMediaTrackInfo_Value(track_roll, 'I_MIDIHWOUT', track_cym_midiport)
            if fold_cym < 0 then
                reaper.SetMediaTrackInfo_Value(track_cym, 'I_FOLDERDEPTH', 0)
                reaper.SetMediaTrackInfo_Value(track_roll, 'I_FOLDERDEPTH', fold_cym)
            end
            reaper.CreateTrackSend(track1, track_roll)
            reaper.SetTrackSendInfo_Value(track_roll, -1, 0, 'B_MUTE', 1)
            _, trackname = reaper.GetSetMediaTrackInfo_String(track_roll, 'P_NAME', track_cym_name .. ' ROLL', true)
            item_roll = reaper.CreateNewMIDIItemInProj(track_roll, st_cym, st_cym + lenth_cym, false)
            take_roll = reaper.GetMediaItemTake(item_roll, 0)
            item_roll2 = reaper.CreateNewMIDIItemInProj(track_roll, 0, 0.05, false)
            take_roll2 = reaper.GetMediaItemTake(item_roll2, 0)
            reaper.MIDI_InsertEvt(take_roll2, false, false, 0, string.char(0xFF, 0x21, 0x01, 0x00))
    
            reaper.MIDI_DisableSort(take_roll)
    
            for ii, vv in ipairs(cym_49_n) do
                startppqpos, endppqpos, chan, pitch, vel = string.match(cym_49_n[ii], '(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
                startppqpos, endppqpos, chan, pitch, vel  = tonumber(startppqpos), tonumber(endppqpos), tonumber(chan), tonumber(pitch), tonumber(vel)
                reaper.MIDI_InsertNote(take_roll, false, false, startppqpos, endppqpos, chan, pitch, vel, false)
            end
    
            for ii, vv in ipairs(cym_52_n) do
                startppqpos, endppqpos, chan, pitch, vel = string.match(cym_52_n[ii], '(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
                startppqpos, endppqpos, chan, pitch, vel  = tonumber(startppqpos), tonumber(endppqpos), tonumber(chan), tonumber(pitch), tonumber(vel)
                reaper.MIDI_InsertNote(take_roll, false, false, startppqpos, endppqpos, chan, pitch, vel, false)
            end
    
            for ii, vv in ipairs(cym_55_n) do
                startppqpos, endppqpos, chan, pitch, vel = string.match(cym_55_n[ii], '(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
                startppqpos, endppqpos, chan, pitch, vel  = tonumber(startppqpos), tonumber(endppqpos), tonumber(chan), tonumber(pitch), tonumber(vel)
                reaper.MIDI_InsertNote(take_roll, false, false, startppqpos, endppqpos, chan, pitch, vel, false)
            end
    
            for ii, vv in ipairs(cym_57_n) do
                startppqpos, endppqpos, chan, pitch, vel = string.match(cym_57_n[ii], '(%d+.0),(%d+.0),(%d+),(%d+),(%d+)')
                startppqpos, endppqpos, chan, pitch, vel  = tonumber(startppqpos), tonumber(endppqpos), tonumber(chan), tonumber(pitch), tonumber(vel)
                reaper.MIDI_InsertNote(take_roll, false, false, startppqpos, endppqpos, chan, pitch, vel, false)
            end
    
            reaper.MIDI_Sort(take_roll)
            local _, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take_cym)
            if notecnt == 0 then reaper.DeleteTrack(track_cym) end
        end -- take_roll~=nil
    end -- take_cym=nil
    
    reaper.UpdateArrange()
    reaper.MIDIEditor_OnCommand(editor, 40818)
    reaper.MIDIEditor_OnCommand(editor, 40818)
    
    reaper.Undo_EndBlock('', 0)
end

count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items > 0 then
    for i = 1, count_sel_items do
        item = reaper.GetSelectedMediaItem(0, i - 1)
        take = reaper.GetTake(item, 0)
        if not take or not reaper.TakeIsMIDI(take) then return end
        reaper.MIDI_SelectAll(take, false)
        DrumsExplode()
    end
else
    editor = reaper.MIDIEditor_GetActive()
    take = reaper.MIDIEditor_GetTake(editor)
    if not take or not reaper.TakeIsMIDI(take) then return end
    reaper.MIDI_SelectAll(take, false)
    DrumsExplode()
end