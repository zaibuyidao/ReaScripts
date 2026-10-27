# EEL2 track mixer

**English** | [简体中文](README.zh-CN.md)

Load `reawebapi-eel-mixer.eel` in REAPER 6.24+ with ReaWebAPI installed. The script calls extension functions directly. Install the extension before loading the script, otherwise missing functions cause a compilation error. Keep this directory intact. No Lua launcher, server or build step is required.

The first selected track supplies its name, volume, pan, color, mute and solo state. The page sends commands to EEL2, which uses standard REAPER APIs and checks external changes on each `defer` pass. Changed state is published with `ReaWeb_SetFrame` and rendered from `frame.lua` with `requestAnimationFrame`. Execution acknowledgements use `ReaWeb_Send`. Closing the window stops the deferred loop. Repeated launches reuse the window and its queue owner.

- Volume: linear gain `0..4`, displayed in dB (silence to approximately +12.04 dB). Pan: `-1..1`. This example controls `D_PAN`, not dual-pan positions or width.
- Solo toggles solo-in-place (`I_SOLO = 2`). Existing nonzero solo modes display as active.
- Colors use `ColorToNative`/`ColorFromNative`. Default clears `I_CUSTOMCOLOR`, preserving the distinction between black and no custom color.
- Commands carry a document session, request ID, selection generation and track GUID. EEL2 rejects stale commands after a selection change. No selection disables the controls. Master tracks are excluded.

The text protocol carries numeric fields on the first line and the unchanged track name on subsequent lines. Names are displayed with `textContent`. Each applied edit creates a REAPER undo point.

Each slider permits at most eight unconfirmed requests and one replaceable pending value. EEL2 coalesces each bounded receive batch, explicitly acknowledges superseded steps, and confirms applied writes only after REAPER readback. A full reply queue pauses consumption and retains the unsent acknowledgement while frame refresh continues.

Releasing a slider drains the final value through execution confirmation. Editing and unconfirmed writes protect the displayed value, while monotonically numbered replies and snapshots reject older state. Keyboard input uses the same protection. A rejected command or a 10-second confirmation timeout is reported without automatic retry, because a timed-out command may already have run. Closing or reloading the page discards its pending work. External REAPER changes resume updating idle controls.

See [EEL2 support and calling conventions](../../docs/eel-backend-compatibility.md). The [minimal example](../eel-backend/README.md) includes the track-name button and the same protected volume control.
