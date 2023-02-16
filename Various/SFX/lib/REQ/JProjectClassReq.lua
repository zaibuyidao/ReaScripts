--[[
@author n0ne
@version 0.7.0
@noindex
--]]

MEDIA_TRACK_GET_INFO_VALUES = {
    mute = "B_MUTE",
    phase = "B_PHASE",
    tracknumber = "IP_TRACKNUMBER", 
    solo = "I_SOLO", 
    fxen = "I_FXEN", 
    recarm = "I_RECARM", 
    recinput = "I_RECINPUT", -- : int * : record input. <0 = no input, 0..n = mono hardware input, 512+n = rearoute input, 1024 set for stereo input pair. 4096 set for MIDI input, if set, then low 5 bits represent channel (0=all, 1-16=only chan), then next 6 bits represent physical input (63=all, 62=VKB)
    recmode = "I_RECMODE", -- : int * : record mode (0=input, 1=stereo out, 2=none, 3=stereo out w/latcomp, 4=midi output, 5=mono out, 6=mono out w/ lat comp, 7=midi overdub, 8=midi replace
    recmon = "I_RECMON", -- : int * : record monitor (0=off, 1=normal, 2=not when playing (tapestyle))
    --I_RECMONITEMS : int * : monitor items while recording (0=off, 1=on)
    --I_AUTOMODE : int * : track automation mode (0=trim/off, 1=read, 2=touch, 3=write, 4=latch)
    --I_NCHAN : int * : number of track channels, must be 2-64, even
    selected = "I_SELECTED", 
    --I_WNDH : int * : current TCP window height (Read-only)
    folderdepth = "I_FOLDERDEPTH", -- int * : folder depth change (0=normal, 1=track is a folder parent, -1=track is the last in the innermost folder, -2=track is the last in the innermost and next-innermost folders, etc
    --I_FOLDERCOMPACT : int * : folder compacting (only valid on folders), 0=normal, 1=small, 2=tiny children
    --I_MIDIHWOUT : int * : track midi hardware output index (<0 for disabled, low 5 bits are which channels (0=all, 1-16), next 5 bits are output device index (0-31))
    --I_PERFFLAGS : int * : track perf flags (&1=no media buffering, &2=no anticipative FX)
    color = "I_CUSTOMCOLOR", -- int *",custom color, OS dependent color|0x100000 (i.e. ColorToNative(r,g,b)|0x100000). If you do not |0x100000, then it will not be used (though will store the color anyway).
    --I_HEIGHTOVERRIDE : int * : custom height override for TCP window. 0 for none, otherwise size in pixels
    vol = "D_VOL", 
    pan = "D_PAN",
    --D_WIDTH : double * : width of track (-1..1)
    --D_DUALPANL : double * : dualpan position 1 (-1..1), only if I_PANMODE==6
    --D_DUALPANR : double * : dualpan position 2 (-1..1), only if I_PANMODE==6
    --I_PANMODE : int * : pan mode (0 = classic 3.x, 3=new balance, 5=stereo pan, 6 = dual pan)
    --D_PANLAW : double * : pan law of track. <0 for project default, 1.0 for +0dB, etc
    --P_ENV : read only, returns TrackEnvelope *, setNewValue=<VOLENV, <PANENV, etc
    showinmixer = "B_SHOWINMIXER", --,bool *",show track panel in mixer -- do not use on master
    showintcp = "B_SHOWINTCP", --,bool *",show track panel in tcp -- do not use on master
    mainsend = "B_MAINSEND", -- : bool * : track sends audio to parent
    --C_MAINSEND_OFFS : char * : track send to parent channel offset
    --B_FREEMODE : bool * : track free-mode enabled (requires UpdateTimeline() after changing etc)
    --C_BEATATTACHMODE : char * : char * to one char of beat attached mode, -1=def, 0=time, 1=allbeats, 2=beatsposonly
    --F_MCP_FXSEND_SCALE : float * : scale of fx+send area in MCP (0.0=smallest allowed, 1=max allowed)
    --F_MCP_SENDRGN_SCALE : float * : scale of send area as proportion of the fx+send total area (0=min allow, 1=max)
}

MEDIA_TRACK_SET_INFO_VALUES = {
    mute = "B_MUTE",
    phase = "B_PHASE",
    solo = "I_SOLO",
    fxen = "I_FXEN",
    recarm = "I_RECARM", -- int * : 0=not record armed, 1=record armed
    recinput = "I_RECINPUT",
    recmode = "I_RECMODE",
    recmon = "I_RECMON",
    recmonitems = "I_RECMONITEMS",
    automode = "I_AUTOMODE",
    nchan = "I_NCHAN",
    selected = "I_SELECTED",
    folderdepth = "I_FOLDERDEPTH", -- int * : folder depth change (0=normal, 1=track is a folder parent, -1=track is the last in the innermost folder, -2=track is the last in the innermost and next-innermost folders, etc
    --"I_FOLDERCOMPACT",int *",folder compacting (only valid on folders), 0=normal, 1=small, 2=tiny children
    --"I_MIDIHWOUT",int *",track midi hardware output index (<0 for disabled, low 5 bits are which channels (0=all, 1-16), next 5 bits are output device index (0-31))
    --"I_PERFFLAGS",int *",track perf flags (&1=no media buffering, &2=no anticipative FX)
    color = "I_CUSTOMCOLOR", -- int *",custom color, OS dependent color|0x100000 (i.e. ColorToNative(r,g,b)|0x100000). If you do not |0x100000, then it will not be used (though will store the color anyway).
    --"I_HEIGHTOVERRIDE",int *",custom height override for TCP window. 0 for none, otherwise size in pixels
    vol = "D_VOL",
    pan = "D_PAN",
    --"D_WIDTH",double *",width of track (-1..1)
    --"D_DUALPANL",double *",dualpan position 1 (-1..1), only if I_PANMODE==6
    --"D_DUALPANR",double *",dualpan position 2 (-1..1), only if I_PANMODE==6
    --"I_PANMODE",int *",pan mode (0 = classic 3.x, 3=new balance, 5=stereo pan, 6 = dual pan)
    --"D_PANLAW",double *",pan law of track. <0 for project default, 1.0 for +0dB, etc
    showinmixer = "B_SHOWINMIXER", --,bool *",show track panel in mixer -- do not use on master
    showintcp = "B_SHOWINTCP", --,bool *",show track panel in tcp -- do not use on master
    mainsend = "B_MAINSEND", -- : bool * : track sends audio to parent
    --"C_MAINSEND_OFFS",char *",track send to parent channel offset
    --"B_FREEMODE",bool *",track free-mode enabled (requires UpdateTimeline() after changing etc)
    --"C_BEATATTACHMODE",char *",char * to one char of beat attached mode, -1=def, 0=time, 1=allbeats, 2=beatsposonly
    --"F_MCP_FXSEND_SCALE",float *",scale of fx+send area in MCP (0.0=smallest allowed, 1=max allowed)
    --"F_MCP_SENDRGN_SCALE",float * : scale of send area as proportion of the fx+send total area (0=min allow, 1=max)
}

MEDIA_TRACK_GET_SET_INFO_STRINGS = {
    name = "P_NAME", 
    icon = "P_ICON",
    mcp_layout = "P_MCP_LAYOUT",
    tcp_layout = "P_TCP_LAYOUT"
}

MEDIA_ITEM_GET_INFO_VALUES = {
	mute = 'B_MUTE', -- : bool * to muted state
	-- B_LOOPSRC : bool * to loop source
	-- B_ALLTAKESPLAY : bool * to all takes play
	select = 'B_UISEL', -- : bool * to ui selected
	-- C_BEATATTACHMODE : char * to one char of beat attached mode, -1=def, 0=time, 1=allbeats, 2=beatsosonly
	-- C_LOCK : char * to one char of lock flags (&1 is locked, currently)
	vol = "D_VOL", 				-- : double * of item volume (volume bar)
	position = "D_POSITION", 	-- : double * of item position (seconds)
	length = "D_LENGTH", 		-- : double * of item length (seconds)
	-- D_SNAPOFFSET : double * of item snap offset (seconds)
	fadeinlen = "D_FADEINLEN", 	-- : double * of item fade in length (manual, seconds)
	fadeoutlen = "D_FADEOUTLEN",-- : double * of item fade out length (manual, seconds)
	fadeindir = "D_FADEINDIR",	-- : double * of item fade in curve [-1; 1]
	fadeoutdir = "D_FADEOUTDIR",-- : double * of item fade out curve [-1; 1]
	fadeinlen_auto = "D_FADEINLEN_AUTO",-- : double * of item autofade in length (seconds, -1 for no autofade set)
	fadeoutlen_auto = "D_FADEOUTLEN_AUTO",-- : double * of item autofade out length (seconds, -1 for no autofade set)
	fadeinshape = "C_FADEINSHAPE", -- : int * to fadein shape, 0=linear, ...
	fadeoutshape = "C_FADEOUTSHAPE", -- : int * to fadeout shape
	-- I_GROUPID : int * to group ID (0 = no group)
	-- I_LASTY : int * to last y position in track (readonly)
	-- I_LASTH : int * to last height in track (readonly)
	-- I_CUSTOMCOLOR : int * : custom color, OS dependent color|0x100000 (i.e. ColorToNative(r,g,b)|0x100000). If you do not |0x100000, then it will not be used (though will store the color anyway).
	-- I_CURTAKE : int * to active take
	number = "IP_ITEMNUMBER", --: int, item number within the track (read-only, returns the item number directly)
	-- F_FREEMODE_Y : float * to free mode y position (0..1)
	-- F_FREEMODE_H : float * to free mode height (0..1)
	track = "P_TRACK" --: MediaTrack * (read only)
}

MEDIA_ITEM_SET_INFO_VALUES = {
	mute = "B_MUTE", -- : bool * to muted state
	-- B_LOOPSRC : bool * to loop source
	-- B_ALLTAKESPLAY : bool * to all takes play
	select = 'B_UISEL', -- : bool * to ui selected
	-- C_BEATATTACHMODE : char * to one char of beat attached mode, -1=def, 0=time, 1=allbeats, 2=beatsosonly
	-- C_LOCK : char * to one char of lock flags (&1 is locked, currently)
	vol = "D_VOL", --: double * of item volume (volume bar)
	position = "D_POSITION", -- : double * of item position (seconds)
	length = "D_LENGTH", -- : double * of item length (seconds)
	-- D_SNAPOFFSET : double * of item snap offset (seconds)
	fadeinlen = "D_FADEINLEN", 	-- : double * of item fade in length (manual, seconds)
	fadeoutlen = "D_FADEOUTLEN",-- : double * of item fade out length (manual, seconds)
	fadeindir = "D_FADEINDIR",	-- : double * of item fade in curve [-1; 1]
	fadeoutdir = "D_FADEOUTDIR",-- : double * of item fade out curve [-1; 1]
	fadeinlen_auto = "D_FADEINLEN_AUTO",-- : double * of item autofade in length (seconds, -1 for no autofade set)
	fadeoutlen_auto = "D_FADEOUTLEN_AUTO",-- : double * of item autofade out length (seconds, -1 for no autofade set)
	fadeinshape = "C_FADEINSHAPE", -- : int * to fadein shape, 0=linear, ...
	fadeoutshape = "C_FADEOUTSHAPE", -- : int * to fadeout shape
	-- I_GROUPID : int * to group ID (0 = no group)
	-- I_LASTY : int * to last y position in track (readonly)
	-- I_LASTH : int * to last height in track (readonly)
	-- I_CUSTOMCOLOR : int * : custom color, OS dependent color|0x100000 (i.e. ColorToNative(r,g,b)|0x100000). If you do not |0x100000, then it will not be used (though will store the color anyway).
	-- I_CURTAKE : int * to active take
	-- F_FREEMODE_Y : float * to free mode y position (0..1)
	freemode_h = "F_FREEMODE_H" -- : float * to free mode height (0..1)
}

MEDIA_ITEM_GET_SET_INFO_STRINGS = {
	notes = "P_NOTES", 	-- : char * : item note text (do not write to returned pointer, use setNewValue to update)
	guid = "GUID" 		-- : GUID * : 16-byte GUID, can query or update. If using a _String() function, GUID is a string {xyz-...}.
}

MEDIA_ITEM_TAKE_GET_INFO_VALUES = {
	startoffs = "D_STARTOFFS", --: double *, start offset in take of item
	vol = "D_VOL", --: double *, take volume
	-- D_PAN : double *, take pan
	-- D_PANLAW : double *, take pan law (-1.0=default, 0.5=-6dB, 1.0=+0dB, etc)
	playrate =  "D_PLAYRATE", -- : double *, take playrate (1.0=normal, 2.0=doublespeed, etc)
	pitch = "D_PITCH", --: double *, take pitch adjust (in semitones, 0.0=normal, +12 = one octave up, etc)
	-- B_PPITCH, bool *, preserve pitch when changing rate
	-- I_CHANMODE, int *, channel mode (0=normal, 1=revstereo, 2=downmix, 3=l, 4=r)
	-- I_PITCHMODE, int *, pitch shifter mode, -1=proj default, otherwise high word=shifter low word = parameter
	-- I_CUSTOMCOLOR : int *, custom color, OS dependent color|0x100000 (i.e. ColorToNative(r,g,b)|0x100000). If you do not |0x100000, then it will not be used (though will store the color anyway).
	number = "IP_TAKENUMBER", -- : int, take number within the item (read-only, returns the take number directly)
	-- P_TRACK : pointer to MediaTrack (read-only)
	-- P_ITEM : pointer to MediaItem (read-only)
	-- P_SOURCE : PCM_source *. Note that if setting this, you should first retrieve the old source, set the new, THEN delete the old.
}

MEDIA_ITEM_TAKE_SET_INFO_VALUES = {
	startoffs = "D_STARTOFFS", --: double *, start offset in take of item
	vol = "D_VOL", --: double *, take volume
	-- D_PAN : double *, take pan
	-- D_PANLAW : double *, take pan law (-1.0=default, 0.5=-6dB, 1.0=+0dB, etc)
	playrate = "D_PLAYRATE", -- : double *, take playrate (1.0=normal, 2.0=doublespeed, etc)
	pitch = "D_PITCH" --: double *, take pitch adjust (in semitones, 0.0=normal, +12 = one octave up, etc)
	-- B_PPITCH, bool *, preserve pitch when changing rate
	-- I_CHANMODE, int *, channel mode (0=normal, 1=revstereo, 2=downmix, 3=l, 4=r)
	-- I_PITCHMODE, int *, pitch shifter mode, -1=proj default, otherwise high word=shifter low word = parameter
	-- I_CUSTOMCOLOR : int *, custom color, OS dependent color|0x100000 (i.e. ColorToNative(r,g,b)|0x100000). If you do not |0x100000, then it will not be used (though will store the color anyway).
	-- IP_TAKENUMBER : int, take number within the item (read-only, returns the take number directly)
}

MEDIA_ITEM_TAKE_GET_SET_INFO_STRINGS = {
	name = "P_NAME", 	-- : char * to take name
	guid = "GUID" 		-- : GUID * : 16-byte GUID, can query or update. If using a _String() function, GUID is a string {xyz-...}.
}

TRACK_SEND_GET_INFO_VALUES = {
	mute = "B_MUTE", -- : returns bool *
	phase = "B_PHASE", --: returns bool *, true to flip phase
	mono = "B_MONO", --: returns bool *
	vol = "D_VOL", -- : returns double *, 1.0 = +0dB etc
	pan = "D_PAN", --: returns double *, -1..+1
	panlaw = "D_PANLAW", --: returns double *,1.0=+0.0db, 0.5=-6dB, -1.0 = projdef etc
	sendmode = "I_SENDMODE", --: returns int *, 0=post-fader, 1=pre-fx, 2=post-fx (deprecated), 3=post-fx
	automode = "I_AUTOMODE", --: returns int * : automation mode (-1=use track automode, 0=trim/off, 1=read, 2=touch, 3=write, 4=latch)
	srcchan = "I_SRCCHAN", --: returns int *, index,&1024=mono, -1 for none
	dstchan = "I_DSTCHAN", --: returns int *, index, &1024=mono, otherwise stereo pair, hwout:&512=rearoute
	midiflags = "I_MIDIFLAGS", --: returns int *, low 5 bits=source channel 0=all, 1-16, next 5 bits=dest channel, 0=orig, 1-16=chanP_DESTTRACK : read only, returns MediaTrack *, destination track, only applies for sends/recvs
	srctrack = "P_SRCTRACK", --: read only, returns MediaTrack *, source track, only applies for sends/recvs
	env = "P_ENV" -- : read only, returns TrackEnvelope *, setNewValue=<VOLENV, <PANENV, etc

}

TRACK_SEND_SET_INFO_VALUES = {
	mute = "B_MUTE", -- : returns bool *
	phase = "B_PHASE", --: returns bool *, true to flip phase
	mono = "B_MONO", --: returns bool *
	vol = "D_VOL", -- : returns double *, 1.0 = +0dB etc
	pan = "D_PAN", --: returns double *, -1..+1
	panlaw = "D_PANLAW", --: returns double *,1.0=+0.0db, 0.5=-6dB, -1.0 = projdef etc
	sendmode = "I_SENDMODE", --: returns int *, 0=post-fader, 1=pre-fx, 2=post-fx (deprecated), 3=post-fx
	automode = "I_AUTOMODE", --: returns int * : automation mode (-1=use track automode, 0=trim/off, 1=read, 2=touch, 3=write, 4=latch)
	srcchan = "I_SRCCHAN", --: returns int *, index,&1024=mono, -1 for none
	dstchan = "I_DSTCHAN", --: returns int *, index, &1024=mono, otherwise stereo pair, hwout:&512=rearoute
	midiflags = "I_MIDIFLAGS" --: returns int *, low 5 bits=source channel 0=all, 1-16, next 5 bits=dest channel, 0=orig, 1-16=chanSee CreateTrackSend, RemoveTrackSend, GetTrackNumSends.
}
------------------------------------------------
-- ERROR FUNCTION
J_ERROR_NOTICE = 1
J_ERROR_WARNING = 2
J_ERROR_ERROR = 3

J_ERROR_LEVEL = 0 -- Show all

function jError(msg, level)
	if level < J_ERROR_LEVEL then return false end
	level_msgs = {}
	level_msgs[1] = "*** J ERROR NOTICE : "
	level_msgs[2] = "*** J ERROR WARNING: "
	level_msgs[3] = "*** J ERROR !!!!!!!: "
	
	reaper.ShowConsoleMsg(level_msgs[level])
	reaper.ShowConsoleMsg(tostring(msg))
	reaper.ShowConsoleMsg("\n")
end