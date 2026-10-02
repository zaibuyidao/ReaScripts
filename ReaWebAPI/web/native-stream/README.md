# Native Stream Demo

Run `reawebapi-native-stream.lua` with ReaWebAPI v0.3.6.4 or later. Lua returns after opening the window.

Choose PCM, Spectrum, Meter/LUFS, realtime Waveform, MIDI, or a registered stream name. Master/input uses the active hardware device's first two channels. Selected track uses its pre-FX source audio. **Selected track · aggregate pre-FX sources** adds recursively routed folder children and receive sources, respecting Mute/Solo. Native PCM summation preserves values above `1.0` and phase cancellation. This is source-content analysis, not track output capture. Start playback for an audio signal, or place the edit cursor over source media for track analysis. MIDI inputs must be enabled in REAPER preferences. `reagba.video` requires the separate ReaGBA extension and a loaded ROM.

The page receives binary packets over the native transport and renders cached data through `requestAnimationFrame`. Detach affects only this page. Device/display queries and native folder watch are low-frequency controls. See [Native Streams](../../docs/native-streams.md).
