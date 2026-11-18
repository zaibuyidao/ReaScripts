# Third-party components

- EmulatorJS 4.2.3 (commit `e150dc0491ae747028919fb82d6598954976ede6`) is provided under GPL-3.0. See `licenses/emulatorjs/LICENSE` and [EmulatorJS 4.2.3](https://github.com/EmulatorJS/EmulatorJS/tree/v4.2.3).
- Core binaries are from the official `@emulatorjs/core-*` 4.2.3 packages. Individual terms are in `licenses/cores` and the core archives. This release modifies the PPSSPP WASM allocation constant for 64 MiB PSP RAM. See [EmulatorJS core packages](https://www.npmjs.com/search?q=%40emulatorjs%2Fcore-) and [EmulatorJS PPSSPP](https://github.com/EmulatorJS/ppsspp).
- This release adapts the EmulatorJS recording menu to use `app/player/recording.js`. EmulatorJS also includes nipplejs, Socket.IO and compression helpers. Their notices remain in the runtime files.
- RomM 5.4.1 (commit `9c74d0143fbb876f2f62260b91c6fd0b3f590226`) is provided under AGPL-3.0-only. This release adapts its frontend to ReaWebAPI. See `licenses/romm/LICENSE`, `licenses/frontend-dependencies.txt` and [RomM 5.4.1](https://github.com/rommapp/romm/tree/5.4.1).
- `vendor/reawebapi/browser-files.mjs` is from ReaWebAPI 0.3.9.44 and is provided under LGPL-3.0-or-later. See `licenses/reawebapi/COPYING`, `licenses/reawebapi/COPYING.LESSER` and [ReaWebAPI](https://github.com/zaibuyidao/ReaWebAPI).
