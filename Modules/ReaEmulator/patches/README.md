# Included upstream modifications

The EmulatorJS 4.2.3 PPSSPP threaded core includes a pinned one-byte WASM allocation-constant correction, extending its PSP address arena from 160 MiB to 192 MiB for the 64 MiB RAM path. ppsspp-memory-arena.patch contains the corresponding source diff. ppsspp-memory-arena.json records the original and modified hashes, instruction guard, and exact JavaScript changes for interrupted audio recovery and rejected optional wake locks. Threading and core APIs remain unchanged.

recording.json records the exact frontend replacements and hashes for the recording adaptation. The installed frontend source and bundle route recording to recording.js, which uses sequential native file writes. No core binary is changed by the recording adaptation.

These modifications are already applied. End users do not need to run patch or build tools. Upstream package provenance is retained in vendor-lock.json and the core package manifests. Installed file hashes are in SHA256SUMS.json.
