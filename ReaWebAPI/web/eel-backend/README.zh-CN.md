# EEL2 后端 + WebView UI

[English](README.md) | **简体中文**

安装 ReaWebAPI 后，在 REAPER Action List 加载 `reawebapi-eel-backend.eel`。选择轨道并点击 **Read selected track**。EEL2 调用 `GetSelectedTrack` 和 `GetTrackName`，HTML/CSS/JavaScript 页面仅发送命令并显示响应。保持文件同目录，无需 Lua 启动器、服务器或构建步骤。

页面先订阅 `message` 和 `frame`，再发送 `ready`。EEL2 每次 `defer` 检查选中轨道，通过 `ReaWeb_SetFrame` 发布变化后的状态。JavaScript 使用 `requestAnimationFrame` 绘制最新的 `frame.lua` 文本。按钮请求新的状态快照。名称通过 `textContent` 显示，保留 Unicode 和空白字符。不包含主轨，页面重载时建立新会话。

音量使用 `0..4` 线性增益，以 dB 显示，范围为静音至约 +12.04 dB。推子最多保留 8 个未确认请求和 1 个可替换的待发送值。EEL2 合并有界批次中的操作，确认被替代的请求，并在 REAPER 读回后通过 `ReaWeb_Send` 确认写入。回复队列满时保留确认并暂停消费请求，帧刷新继续运行。松开推子后等待最终值确认。会话、选择状态版本、轨道 GUID 和修订序号共同防止旧命令或旧帧覆盖新操作。未选择轨道时禁用推子，空闲控件同步外部变化。

命令拒绝或 10 秒内未确认时显示错误，不自动重试，因为超时命令可能已经执行。页面关闭时清除待处理操作，每次实际编辑生成 REAPER 撤销点。

脚本路径用于标识可复用的窗口。非持久化 ExtState 所有者避免两个脚本实例消费同一队列。每次 `defer` 最多处理 32 条消息。窗口关闭后循环结束，`atexit` 关闭窗口并清除所有权记录。

本示例直接调用扩展函数，要求 REAPER 6.24+，并在加载脚本前安装 ReaWebAPI。缺少扩展函数会导致编译错误。原生字符串返回值在 EEL2 中对应**第一个输出参数**：`ReaWeb_Receive(#message, id)`。通过 `strlen(#message)` 判断空队列。

可选参数和限制参见 [EEL2 支持说明](../../docs/eel-backend-compatibility.zh-CN.md)。[轨道混音示例](../eel-mixer/README.zh-CN.md)演示音量、声像、颜色、Mute 和 Solo 的双向同步。
