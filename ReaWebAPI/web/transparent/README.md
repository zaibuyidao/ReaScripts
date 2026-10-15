# Transparent Window / 透明窗口

Requires ReaWebAPI v0.3.8.18 or later. Run `reawebapi-transparent.lua` in REAPER. The example uses a standalone frameless window with transparent margins, a translucent rounded panel, CSS shadows, native drag regions, input and close controls.

Move it over changing REAPER content to inspect desktop Alpha. The opacity slider changes CSS only. Transparent pixels retain rectangular mouse hit testing. Dock requests report `DOCK_UNAVAILABLE`. Native backend requirements and saved Dock behavior are documented in [Host API](../../docs/host-api.md#transparent-windows).

要求 ReaWebAPI v0.3.8.18 或更新版本。在 REAPER 中运行 `reawebapi-transparent.lua`，打开具有透明留白、半透明圆角面板、CSS 阴影、原生拖动区、输入框和关闭控件的独立无边框窗口。

将窗口移到变化的 REAPER 内容上检查桌面 Alpha。滑块仅修改 CSS 不透明度。透明像素仍采用矩形鼠标命中区域，停靠请求返回 `DOCK_UNAVAILABLE`。原生后端要求及 Dock 偏好规则见 [Host API](../../docs/host-api.zh-CN.md#透明窗口)。
