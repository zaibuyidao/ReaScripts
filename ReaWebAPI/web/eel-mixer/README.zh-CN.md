# EEL2 轨道混音控制

[English](README.md) | **简体中文**

安装 ReaWebAPI 后，在 REAPER 6.24+ 的 Action List 加载 `reawebapi-eel-mixer.eel`。脚本直接调用扩展函数，缺少扩展会导致编译错误。保持目录完整，无需 Lua 启动器、服务器或构建步骤。

页面显示首个选中轨道的名称、音量、声像、颜色、Mute 和 Solo 状态。操作通过消息交给 EEL2，由标准 REAPER API 执行。后端每次 `defer` 检查宿主侧变化，通过 `ReaWeb_SetFrame` 发布变化后的状态。前端使用 `requestAnimationFrame` 绘制 `frame.lua`，执行确认继续使用 `ReaWeb_Send`。关闭窗口后停止 defer 循环，重复启动复用窗口及其消息队列所有者。

- 音量为 `0..4` 线性增益，以 dB 显示，范围为静音至约 +12.04 dB。声像为 `-1..1`，控制 `D_PAN`，不控制双声像位置或宽度。
- Solo 切换 solo-in-place（`I_SOLO = 2`）。已有的非零 Solo 模式均显示为启用。
- 颜色通过 `ColorToNative` 和 `ColorFromNative` 转换。Default 清除 `I_CUSTOMCOLOR`，区分黑色与未设置自定义颜色。
- 命令包含页面会话、请求 ID、选择状态版本和轨道 GUID。切换轨道后，EEL2 拒绝旧命令。未选择轨道时禁用控件，不包含主轨。

文本协议的首行包含数值字段，后续内容保留原始轨道名称。名称使用 `textContent` 显示。每次实际编辑生成 REAPER 撤销点。

每个推子最多保留 8 个未确认请求和 1 个可替换的待发送值。EEL2 在有界接收批次内合并同一推子的操作，明确回复已被后续值替代的请求，实际写入须经 REAPER 读回后确认。回复队列满时暂停消费，保留尚未发送的确认，帧刷新继续运行。

松开推子后等待最终值执行确认。编辑和未确认请求期间保护显示值，通过递增的回复与快照序号拒绝旧状态。键盘操作使用相同保护。命令拒绝或 10 秒内未确认时显示错误，不自动重试，因为超时命令可能已经执行。页面关闭或重载时清除待处理操作，空闲控件继续同步 REAPER 的外部变化。

参见 [EEL2 支持与调用约定](../../docs/eel-backend-compatibility.zh-CN.md)。[最简示例](../eel-backend/README.zh-CN.md)包含轨道名称按钮及相同保护机制的音量推子。
