import {preferences, savePreferences} from './preferences.mjs';
import english from '../locales/en.json' with {type:'json'};
import backendMessages from './backend-messages.json' with {type:'json'};
export const languages = [
  {code:'en', name:'English'}, {code:'zh-CN', name:'简体中文'},
  {code:'zh-TW', name:'繁體中文'}, {code:'ja', name:'日本語'}, {code:'ko', name:'한국어'},
];
let locale = {}, request = 0;
const cache = new Map([['en', Promise.resolve(english)]]);
async function load(code) {
  if (!cache.has(code)) cache.set(code, fetch(new URL(`../locales/${code}.json`, import.meta.url)).then(async response => {
    if (!response.ok) throw Error('Unable to load language: ' + code);
    return response.json();
  }));
  return cache.get(code);
}
export const t = (key, values = {}) => (locale[key] ?? english[key] ?? key).replace(/\{(\w+)\}/g, (_, name) => values[name] ?? `{${name}}`);
export function translatePage() {
  for (const node of document.querySelectorAll('[data-i18n]')) node.textContent = t(node.dataset.i18n);
  for (const node of document.querySelectorAll('[data-i18n-label]')) node.setAttribute('aria-label', t(node.dataset.i18nLabel));
}
export async function setLanguage(code, persist = true) {
  const sequence = ++request;
  code = languages.some(item => item.code === code) ? code : 'en';
  const next = await load(code);
  if (sequence !== request) return;
  if (persist) savePreferences({language:code});
  locale = next;
  document.documentElement.lang = code;
  document.querySelector('#language').value = code;
  translatePage();
  dispatchEvent(new Event('languagechange'));
}
export async function initializeLanguage() {
  const select = document.querySelector('#language');
  select.replaceChildren(...languages.map(({code,name}) => new Option(name,code)));
  await setLanguage(preferences.language, false);
}
// Keep backend source strings independent of editable translations so changing
// terminology does not break error matching. Preserve paths and technical details.
export function localizeMessage(message) {
  let result = String(message);
  for (const [key, source] of Object.entries(backendMessages).sort((a,b) => b[1].length-a[1].length)) {
    if (!source.includes('{') && source.length > 5) result = result.split(source).join(t(key));
  }
  const cleanupPrefix = backendMessages.cleanupError.split('{message}')[0];
  if (cleanupPrefix && result.includes(cleanupPrefix)) result = result.replace(cleanupPrefix, t('cleanupError', {message:''}));
  return result;
}
