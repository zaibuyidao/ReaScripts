# EEL2 backend + WebView UI

**English** | [简体中文](README.zh-CN.md)

Load `reawebapi-eel-backend.eel` in REAPER's Action List with ReaWebAPI installed. Select a track and click **Read selected track**. EEL2 calls `GetSelectedTrack` and `GetTrackName`. The HTML/CSS/JavaScript page only sends commands and displays replies. Keep these files together. No Lua launcher, server or build step is required.

The page subscribes to `message` and `frame` before sending `ready`. EEL2 checks the selected track on each `defer` pass and publishes changed state through `ReaWeb_SetFrame`. JavaScript renders the latest `frame.lua` text with `requestAnimationFrame`. The button requests a fresh snapshot. Track names use `textContent`, preserving Unicode and whitespace. The master track is excluded. Reloading starts a new document session.

Volume uses linear gain `0..4`, displayed in dB (silence to approximately +12.04 dB). Each slider gesture retains at most eight unconfirmed requests and one replaceable pending value. EEL2 coalesces bounded batches, acknowledges superseded steps, and confirms writes after REAPER readback through `ReaWeb_Send`. A full reply queue retains the acknowledgement and pauses request consumption while frame refresh continues. Releasing the slider waits for final-value confirmation. Session, selection generation, track GUID and revision checks prevent stale commands or frames from overwriting a newer gesture. No selection disables the slider. External changes update idle controls.

Rejected commands and 10-second acknowledgement timeouts are reported without automatic retry, because a timed-out command may already have run. Page closure clears pending work. Each applied edit creates a REAPER undo point.

The script filename identifies a reusable window. A nonpersistent ExtState owner prevents two script instances from consuming the same queue. Each `defer` pass processes at most 32 messages. Closing the window ends the loop, and `atexit` closes the window and removes ownership.

This example uses direct extension calls and requires REAPER 6.24+ with ReaWebAPI installed before loading the script. Missing extension functions cause a compilation error. Native string returns become the **first output parameter** in EEL2: `ReaWeb_Receive(#message, id)`. Check `strlen(#message)` for an empty queue.

See [EEL2 support](../../docs/eel-backend-compatibility.md) for optional parameters and limits, or the [track mixer](../eel-mixer/README.md) for bidirectional volume, pan, color, mute and solo.
