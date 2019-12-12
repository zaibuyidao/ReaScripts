--[[
 * ReaScript Name: Strum Down
 * Version: 1.0
 * Author: kawa & zaibuyidao
 * Tick function realize: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

if (package.config:sub(1, 1) == "\\") then end
local n = 40815 -- 删除长度小于1/256音符的全部音符
local c = 40659
function deepcopy(t)
    local n = type(t)
    local e
    if n == 'table' then
        e = {}
        for t, n in next, t, nil do e[deepcopy(t)] = deepcopy(n) end
        setmetatable(e, deepcopy(getmetatable(t)))
    else
        e = t
    end
    return e
end
function createMIDIFunc3(I)
    local e = {}
    e.allNotes = {}
    e.selectedNotes = {}
    e._editingNotes_Original = {}
    e.editingNotes = {}
    e.editorHwnd = nil
    e.take = nil
    e.mediaItem = nil
    e.mediaTrack = nil
    e._limitMaxCount = 1e4 -- 限制音符的最大计数10000
    e._isSafeLimit = true
    function e:_showLimitNoteMsg()
        reaper.ShowMessageBox("Over " .. tostring(self._limitMaxCount) ..
                                  " clip num.\nStop process", "Stop", 0)
    end
    function e:getMidiNotes()
        reaper.PreventUIRefresh(2)
        -- reaper.MIDIEditor_OnCommand(self.editorHwnd, n) -- 删除长度小于1/256音符的全部音符
        reaper.MIDIEditor_OnCommand(self.editorHwnd, c)
        reaper.PreventUIRefresh(-1)
        local r = {}
        local i = {}
        local a, o, d, t, n, l, c, p = reaper.MIDI_GetNote(self.take, 0)
        local e = 0
        while a do
            _, _, _, t, n, _, _, _ = reaper.MIDI_GetNote(self.take, e)
            local s = {
                selection = o,
                mute = d,
                startQn = t,
                endQn = n,
                chan = l,
                pitch = c,
                vel = p,
                take = self.take,
                idx = e,
                length = n - t
            }
            table.insert(r, s)
            if (o == true) then table.insert(i, s) end
            e = e + 1
            a, o, d, t, n, l, c, p = reaper.MIDI_GetNote(self.take, e)
            if (e > self._limitMaxCount) then
                r = {}
                i = {}
                self:_showLimitNoteMsg()
                self._isSafeLimit = false
                break
                reaper.SN_FocusMIDIEditor()
            end
        end
        self.m_existMaxNoteIdx = e
        return r, i
    end
    function e:detectTargetNote()
        if (self._isSafeLimit == false) then return {} end
        if (#self.selectedNotes >= 1) then
            self._editingNotes_Original = deepcopy(self.selectedNotes)
            self.editingNotes = deepcopy(self.selectedNotes)
            return self.editingNotes
        else
            self._editingNotes_Original = deepcopy(self.allNotes)
            self.editingNotes = deepcopy(self.allNotes)
            return self.editingNotes
        end
    end
    function e:correctOverWrap()
        reaper.MIDIEditor_OnCommand(self.editorHwnd, c)
    end
    function e:flush(t, e)
        self:_deleteAllOriginalNote()
        self:_editingNoteToMediaItem(t)
        self:correctOverWrap()
        if (e == true) then reaper.MIDI_Sort(self.take) end
    end
    function e:insertNoteFromC(e)
        e.idx = self.m_existMaxNoteIdx + 1
        self.m_existMaxNoteIdx = self.m_existMaxNoteIdx + 1
        table.insert(self.editingNotes, e)
        return e
    end
    function e:insertNotesFromC(e)
        for t, e in ipairs(e) do self:insertNoteFromC(e) end
        return e
    end
    function e:insertMidiNote(n, o, e, t, i, r, a)
        local e = e
        local t = t
        local l = o
        local i = i or false
        local a = a or false
        local r = r or 1
        local o = n
        local n = self.m_existMaxNoteIdx + 1
        self.m_existMaxNoteIdx = self.m_existMaxNoteIdx + 1
        local e = {
            selection = i,
            mute = a,
            startQn = e,
            endQn = t,
            chan = r,
            pitch = o,
            vel = l,
            take = self.take,
            idx = n,
            length = t - e
        }
        table.insert(self.editingNotes, e)
    end
    function e:deleteNote(t)
        for e, n in ipairs(self.editingNotes) do
            if (n.idx == t.idx) then
                table.remove(self.editingNotes, e)
                break
            end
        end
    end
    function e:deleteNotes(e)
        if (e == self.editingNotes) then
            self.editingNotes = {}
            return
        end
        for t, e in ipairs(e) do self:deleteNote(e) end
    end
    function e:_init(e)
        self.editorHwnd = reaper.MIDIEditor_GetActive()
        self.take = e or reaper.MIDIEditor_GetTake(self.editorHwnd)
        if (self.take == nil) then return end
        self.allNotes, self.selectedNotes = self:getMidiNotes()
        self.mediaItem = reaper.GetMediaItemTake_Item(self.take)
        self.mediaTrack = reaper.GetMediaItemTrack(self.mediaItem)
    end
    function e:_deleteAllOriginalNote(e)
        local e = e or self._editingNotes_Original
        while (#e > 0) do
            local t = #e
            reaper.MIDI_DeleteNote(e[t].take, e[t].idx)
            table.remove(e, #e)
        end
    end
    function e:_insertNoteToMediaItem(e, o)
        local t = self.take
        if t == nil then return end
        local a = e.selection or false
        local d = e.mute
        local r = reaper.MIDI_GetPPQPosFromProjQN(t, e.startQn)
        local l = reaper.MIDI_GetPPQPosFromProjQN(t, e.endQn)
        local i = e.chan
        local c = e.pitch
        local s = e.vel
        local n = 0
        if (o == true) then
            local e = .9
            local o = reaper.MIDI_GetProjQNFromPPQPos(t, e)
            local e = reaper.MIDI_GetProjQNFromPPQPos(t, e * 2)
            n = e - o
        end
        reaper.MIDI_InsertNote(t, a, d, r, l - n, i, c, s, true)
    end
    function e:_editingNoteToMediaItem(t)
        for n, e in ipairs(self.editingNotes) do
            self:_insertNoteToMediaItem(e, t)
        end
    end
    e:_init(I)
    return e
end
if (package.config:sub(1, 1) == "\\") then end
local i = "STRUM-IT - Low To High"
local function o(e)
    local t = {}
    for e, n in ipairs(e) do
        local e = n.startQn
        if (t[e] == nil) then
            t[e] = {}
            t[e].startQn = e
            t[e].notes = {}
        end
        table.insert(t[e].notes, n)
    end
    return t
end
local function n(n)
    local t = createMIDIFunc3()
    local e = t:detectTargetNote()
    if (#e < 1) then return end
    reaper.Undo_BeginBlock()
    local n = n or 10
    local e = o(e)
    for o, e in pairs(e) do
        table.sort(e.notes, function(e, t) return (e.pitch < t.pitch) end)
        for t, e in ipairs(e.notes) do
            e.startQn = e.startQn + n * (t - 1)
            reaper.MIDI_SetNote(e.take, e.idx, e.selection, e.mute,
                                e.startQn,
                                e.endQn,
                                e.chan, e.pitch, e.vel, true)
        end
    end
    t:correctOverWrap()
    reaper.Undo_EndBlock(i, -1)
end
local userOK, tick = reaper.GetUserInputs('STRUM-IT', 1, 'Down', '4')
if not userOK then return reaper.SN_FocusMIDIEditor() end
local e = tick
n(e)
reaper.SN_FocusMIDIEditor()
