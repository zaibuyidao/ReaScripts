# Native Events and Host Service

Run `reawebapi-native-service.lua` in REAPER. The launcher returns immediately. Change track selection, transport, project tabs, markers, regions, loop points or time selection and inspect the native events.

`runtime.getInfo` is built in. To exercise `test`, build the `native_service_extension` target and place its `reaper_zz_reaweb_service_test` binary in a test REAPER installation's `UserPlugins`. Restart REAPER. The extension must load after ReaWebAPI. Use ping, send, pending and unregister. After unregister, calls reject until the extension registers again. Subscribe again after registration.

Run `Coexist.lua` to keep a Lua echo backend active while using the same native features. Lua echo uses the unchanged `host.send(message)` and `message` event path. Also check the existing Lua Backend Demo, docking, undocking, closing and reopening.

The log retains 100 entries. Transport positions update at a bounded native cadence, without browser polling. Unsubscribe disables the native monitors when no other window needs them.
