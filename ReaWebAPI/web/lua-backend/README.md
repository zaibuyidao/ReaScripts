# Lua backend + WebView UI

Run `reawebapi-lua-backend.lua` in REAPER, select a track, then adjust the volume slider. Lua owns REAPER access and polls `ReaWeb_Receive` with `defer`. The page uses only `reaper.host.send` and the `message` event. Closing the window ends the backend. Stopping the script closes its window.

Rerunning the same launcher focuses its existing window. After close, it opens a new window with fresh queues. The launcher passes its `debug.getinfo(1, "S").source` as `instanceKey` to `ReaWeb_Open(path, instanceKey)`. C++ manages window reuse. Nonpersistent ExtState only prevents duplicate Lua polling loops.

Lua sends JSON state with escaped track names. The UI sends `ready` and `volume <linear-amplitude>` text commands. The ready message requests a fresh snapshot after each reload. Applications can instead send JSON values with `host.send` and decode the resulting text with their Lua JSON library.

The window name comes from `<title>` in `index.html`. Edit it or assign `document.title` for a dynamic name. The launcher's `instanceKey` remains an internal identity.

