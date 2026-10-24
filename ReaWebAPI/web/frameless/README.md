# Frameless Window

Requires ReaWebAPI v0.3.9.2. Run `reawebapi-frameless-resizable.lua` for a resizable window or `reawebapi-frameless-fixed.lua` for a fixed window. Re-running a launcher focuses its existing instance. Linux requires X11/XWayland and a window manager supporting `_NET_WM_MOVERESIZE`.

`launch.lua` is a shared helper; do not run it directly. The `app.json` version identifies this demo and uses `major.minor.patch` (for example, `1.0.0`), independently of the required extension version.

`data-reaweb-drag` declares a rectangular native drag region. `data-reaweb-no-drag` excludes interactive areas. Buttons, links, form controls, editable elements and focusable elements are excluded automatically. Mark custom controls, scroll areas, overlays and Shadow DOM hosts explicitly. Keep drag regions out of animated or rapidly changing layouts. Native input uses the last completed layout snapshot on macOS and Linux.

Dock/Undock preserves the counter and text input. `framelessActive` is false inside every Docker, including floating Docker containers. `resizable:false` prevents interactive resizing while `setSize()` remains available after undocking. Right-click the page for Dock and DevTools. The close button uses the existing lifecycle.

要求 ReaWebAPI v0.3.9.2。运行 `reawebapi-frameless-resizable.lua` 打开可缩放窗口，运行 `reawebapi-frameless-fixed.lua` 打开固定尺寸窗口。重复运行启动脚本会聚焦已有实例。Linux 要求 X11/XWayland 和支持 `_NET_WM_MOVERESIZE` 的窗口管理器。

`launch.lua` 是共用辅助文件，不应单独运行。`app.json` 的版本号表示此示例的版本，采用 `major.minor.patch` 三段格式（例如 `1.0.0`），与所需的插件版本独立。

`data-reaweb-drag` 声明矩形原生拖动区域，`data-reaweb-no-drag` 排除交互区域。按钮、链接、表单控件、可编辑元素及可聚焦元素自动排除。自定义控件、滚动区域、覆盖层和 Shadow DOM 宿主应显式排除。拖动区应避免动画及快速变化的布局，macOS 和 Linux 原生输入使用最近完成的布局快照。

停靠与浮动切换保留计数和输入内容。在任意 Docker 内，包括浮动 Docker，`framelessActive` 为 `false`。`resizable:false` 禁止交互式缩放，浮动状态下仍可调用 `setSize()`。页面右键菜单提供 Dock 和 DevTools，关闭按钮使用已有生命周期。

Use the title-bar toggle and radius control to verify live appearance changes. Counter/input state stays intact. Radius is suspended in Docker and while maximized. macOS/Linux titled windows retain system corners.

使用标题栏开关与半径控件验证动态外观，计数和输入状态保持不变。停靠和最大化时暂停圆角，macOS/Linux 的有标题栏窗口使用系统圆角。
