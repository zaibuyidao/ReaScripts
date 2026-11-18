import { startRecording } from '../player/recording.js';
import { connectHost, capabilities, requireCoreSupport, coreOptions } from './host.js';

const settings = fetch('./config/config.json').then(async response => {
  if (!response.ok) throw new Error(`config.json: ${response.status}`);
  const config = await response.json();
  if (!config || Array.isArray(config) || typeof config !== 'object') throw new Error('Invalid config.json');
  for (const key of Object.keys(config)) {
    if (!key.startsWith('EJS_')) throw new Error(`Invalid EmulatorJS option: ${key}`);
  }
  return config;
});
const showError = error => alert(`ReaEmulator: ${error.message || error}`);
window.reaEmulatorHostReady = connectHost(showError);
window.reaEmulatorBeforeStart = async core => {
  await window.reaEmulatorHostReady;
  const config = coreOptions(core, await settings);
  const selected = config.EJS_core || core;
  await requireCoreSupport(selected, config.EJS_threads);
  return config;
};
window.reaEmulatorCapabilities = capabilities;
window.reaEmulatorHostReady.catch(showError);
settings.catch(showError);

let recording;
window.reaEmulatorStartRecording = async emulator => {
  const task = await startRecording(emulator);
  if (task) {
    recording = task;
    task.done.finally(() => { if (recording === task) recording = undefined; }).catch(() => {});
  }
  return task;
};
export async function finishRecording() {
  const task = recording;
  if (task) { task.stop(); await task.done; }
}
