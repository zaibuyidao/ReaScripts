# ReaEmulator 0.1.0

在 REAPER 内运行 EmulatorJS 4.2.3。本包包含 47 个模拟器核心及其运行资源，已包含 PPSSPP 内存修复与原生文件录像适配；不含 ROM 或 BIOS。

## 安装与启动

1. 安装 ReaWebAPI 0.3.9.44 或更新版本，然后重启 REAPER。
2. 使用 ReaPack 安装后，在 Action List 运行 zaibuyidao_ReaEmulator.lua。手动安装时，将整个 ReaEmulator 文件夹放入 REAPER 的 Scripts 目录，再加载此脚本。
3. 在窗口中选择或拖入自己的 ROM；需要 BIOS 的游戏须自行配置 BIOS。

用户无需安装 Node.js、Python、npm 或 7-Zip。保留目录结构和 app.json，不要修改 App ID，以免改变持久化存储位置。

## 使用说明

- 存档、控制器、作弊码和画面设置使用 EmulatorJS 菜单。音频通过系统设备播放，不进入 REAPER 音轨。
- config.json 接受 EmulatorJS 的 EJS_* 选项，例如 EJS_core、EJS_biosUrl。本地资源使用 App 目录内的相对路径。核心列表见 cores.json。
- 默认关闭浏览器数据库存档。可在 config.json 设置 "EJS_disableDatabases": false 启用。更换游戏前请先保存进度。
- PSP、DOS 和其他线程核心需要宿主提供跨源隔离、共享 WASM 内存和 Worker；PSP 还需要 WebGL2。Linux 需要与 ReaWebAPI 匹配且支持上述能力的 WebKitGTK 运行库。
- 存档、截图和录像通过原生保存对话框导出。录像开始前选择路径，停止后等待写入完成。录像格式取决于系统 WebView 的 MediaRecorder 支持；没有可用编码格式时无法录像。
- 普通本地游戏不需要联网。游戏、BIOS、手柄及联机兼容性取决于所选核心和系统环境。

许可证与来源见 LICENSE、THIRD_PARTY_NOTICES.md 和 licenses/cores/。
