# Third-party components

- EmulatorJS 4.2.3: https://github.com/EmulatorJS/EmulatorJS/tree/v4.2.3
  Tag commit: `e150dc0491ae747028919fb82d6598954976ede6`. GPL-3.0, see `LICENSE`.
- Core binaries and WASM: official `@emulatorjs/core-*` npm packages, exact versions and integrity values in `vendor-lock.json`. Upstream package manifests and source repository links are retained under `vendor/emulatorjs/data/cores/metadata`. Embedded licenses are also extracted into `licenses/cores`. Individual core terms apply.
- ReaWebAPI `browser-files.mjs`: copied from the local ReaWebAPI 0.3.9.44 source tree. LGPL-3.0-or-later. License texts are in `vendor/ReaWebAPI-COPYING*`.
- EmulatorJS includes nipplejs, Socket.IO and compression helpers. Their upstream source headers are retained.

The PPSSPP core has one local WASM allocation-constant correction for 64 MiB PSP RAM. The source-equivalent diff and input/output hashes are documented in `patches/README.md`. All other core archives remain unmodified. A pinned frontend-only recording adaptation routes the recording menu to the local `recording.js` module. `patches/recording.json` records exact replacements and input/output hashes. The loader bundle is regenerated from these frontend sources.

Public redistribution must comply with each bundled core's license, including corresponding-source obligations where applicable. This package retains source links and license notices but does not contain all core build source trees. No ROM or BIOS images are distributed.
