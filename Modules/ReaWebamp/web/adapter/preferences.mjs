const KEY = 'reawebamp.ui.v1';
let saved;
try { saved = JSON.parse(localStorage.getItem(KEY)); } catch {}
export const preferences = {
  language: ['en','zh-CN','zh-TW','ja','ko'].includes(saved?.language) ? saved.language : 'en',
  initialized: saved?.initialized === true,
};
export function savePreferences(changes) {
  const next = {...preferences, ...changes};
  localStorage.setItem(KEY, JSON.stringify(next));
  Object.assign(preferences, next);
}
