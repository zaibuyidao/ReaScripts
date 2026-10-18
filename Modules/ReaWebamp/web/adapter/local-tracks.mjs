import {t} from './i18n.mjs';
import { saveBlob } from './browser-files.mjs';

export function chooseFiles(label, { multiple = false, accept = '' } = {}) {
  const dialog = document.querySelector('#picker'), input = document.querySelector('#picker-input');
  if (dialog.open) return Promise.reject(new Error(t('pickerBusy')));
  document.querySelector('#picker-label').textContent = label;
  input.value = ''; input.multiple = multiple; input.accept = accept;
  dialog.returnValue = 'cancel';
  return new Promise(resolve => {
    dialog.addEventListener('close', () => resolve(dialog.returnValue === 'ok' ? [...input.files] : []), { once:true });
    dialog.showModal();
  });
}

export function playlistManifest(tracks, blobs) {
  return { format:'reawebamp-playlist', version:1, tracks:tracks.map(track => {
    const file = blobs.get(String(track.url));
    if (!(file instanceof File)) throw new Error(t('saveLocalOnly'));
    return { name:file.name, size:file.size, lastModified:file.lastModified };
  }) };
}

export function resolvePlaylist(manifest, files) {
  if (manifest?.format !== 'reawebamp-playlist' || manifest.version !== 1 || !Array.isArray(manifest.tracks) || manifest.tracks.length > 10000)
    throw new Error(t('invalidManifest'));
  return manifest.tracks.map(track => {
    if (typeof track.name !== 'string' || !Number.isSafeInteger(track.size) || track.size < 0 || !Number.isSafeInteger(track.lastModified))
      throw new Error(t('invalidListReference'));
    const matches = files.filter(file => file.name === track.name && file.size === track.size && file.lastModified === track.lastModified);
    if (matches.length !== 1) throw new Error(t('missingFile',{name:track.name}));
    return { blob:matches[0], defaultName:matches[0].name };
  });
}

export async function savePlaylist(tracks, blobs) {
  const manifest = playlistManifest(tracks, blobs);
  await saveBlob(new Blob([JSON.stringify(manifest, null, 2)], { type:'application/json' }), 'ReaWebamp.playlist.json');
  return null;
}

export async function loadPlaylist() {
  const [file] = await chooseFiles(t('choosePlaylist'), { accept:'.json' });
  if (!file) return null;
  if (file.size > 1024 * 1024) throw new Error(t('listLarge'));
  const manifest = JSON.parse(await file.text());
  if (!Array.isArray(manifest.tracks)) throw new Error(t('invalidPlaylist'));
  if (!manifest.tracks.length) return resolvePlaylist(manifest, []);
  const files = await chooseFiles(t('chooseOriginals'), { multiple:true });
  if (!files.length) return null;
  return resolvePlaylist(manifest, files);
}
