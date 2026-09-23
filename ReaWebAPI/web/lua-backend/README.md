# Lua backend + WebView UI

Run `Open.lua` in REAPER, select a track, then adjust the volume slider. Lua owns REAPER access and polls `ReaWeb_Receive` with `defer`. The page uses only `reaper.host.send` and the `message` event. Closing the window ends the backend. Stopping the script closes its window.

Rerunning the same launcher focuses its existing window. After close, it opens a new window with fresh queues. The launcher passes its `debug.getinfo(1, "S").source` as `instanceKey` to `ReaWeb_Open(path, instanceKey)`. C++ manages window reuse. Nonpersistent ExtState only prevents duplicate Lua polling loops.

Lua sends JSON state with escaped track names. The UI sends `ready` and `volume <linear-amplitude>` text commands. The ready message requests a fresh snapshot after each reload. Applications can instead send JSON values with `host.send` and decode the resulting text with their Lua JSON library.

The window name comes from `<title>` in `index.html`. Edit it or assign `document.title` for a dynamic name. The launcher's `instanceKey` remains an internal identity.

在 REAPER 中运行 `Open.lua`，选择轨道后调整音量滑块。Lua 使用普通 REAPER API，并通过 `defer` 轮询消息。WebView 仅负责 UI。关闭窗口会结束后端，停止脚本会关闭窗口。页面重载后通过 `ready` 请求最新状态。

重复运行同一启动器时聚焦已有窗口。关闭后再次运行会创建新窗口和空消息队列。启动器将 `debug.getinfo(1, "S").source` 作为 `instanceKey` 传给 `ReaWeb_Open(path, instanceKey)`，由 C++ 管理窗口复用。非持久化 ExtState 仅防止重复启动 Lua 轮询循环。

窗口名称来自 `index.html` 的 `<title>`，可直接修改，也可通过 `document.title` 动态更新。启动器的 `instanceKey` 仍仅用于内部身份标识。
