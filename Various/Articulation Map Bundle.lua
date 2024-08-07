-- @description Articulation Map Bundle
-- @author zaibuyidao
-- @version 1.0.45
-- @changelog
--   # Fixed an issue where Mode switching was not working.
--   + Added the "Mapping Bank LSB" feature, which allows the original bank LSB to be mapped to a specified value. This enables more flexible definition of both bank MSB and LSB.
-- @links
--   Forum Thread https://forum.cockos.com/showthread.php?t=289373
--   GitHub repository https://github.com/zaibuyidao/ReaScripts
-- @metapackage
-- @provides
--  [jsfx] Articulation Map/jsfx/articulation_map.jsfx > Articulation Map/articulation_map.jsfx
--  [jsfx] Articulation Map/jsfx/pre_trigger_events.jsfx > Articulation Map/pre_trigger_events.jsfx
--  [data] Articulation Map/jsfx/zaibuyidao_articulation_map/simul-arts.txt > zaibuyidao_articulation_map/simul-arts.txt
--   [main=midi_editor] Articulation Map/zaibuyidao_Articulation Map - No GUI.lua
--   [main=midi_editor] Articulation Map/zaibuyidao_Articulation Map - CC to PC.lua
--   [main=midi_editor] Articulation Map/zaibuyidao_Articulation Map - PC to CC.lua
--   [main=midi_editor] Articulation Map/zaibuyidao_Articulation Map - Toggle PC to CC.lua
--   [main=midi_editor] Articulation Map/zaibuyidao_Articulation Map - Toggle PC to Note.lua
--   [main=midi_editor] Articulation Map/zaibuyidao_Articulation Map - Note to PC.lua
--   [main=midi_editor] Articulation Map/zaibuyidao_Articulation Map - PC to Note.lua
--   [main=midi_editor] Articulation Map/zaibuyidao_Articulation Map.lua
--   [nomain] Articulation Map/lib/*.lua
--   Articulation Map/banks/*.reabank
--   Articulation Map/articulation_map_factory.reabank
-- @donation http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

-- Licensed under the GNU GPL v3