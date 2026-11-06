// Word/WPS put mixed content in HTML, with pictures in local files or RTF.
// Keep the HTML order and import every picture through the normal attachment store.
const IMAGE_LIMIT = 8 * 1024 * 1024;
const invalidImage = () => Object.assign(new Error('IMAGE_UNSUPPORTED'), {code: 'IMAGE_UNSUPPORTED'});

export function localImagePath(source) {
  if (!/^file:/i.test(source)) return null;
  const url = new URL(source);
  if (url.hostname && url.hostname !== 'localhost') throw invalidImage();
  let path = decodeURIComponent(url.pathname);
  if (/^\/[a-z]:\//i.test(path)) path = path.slice(1);
  if (/[\x00-\x1f]/.test(path)) throw invalidImage();
  return path;
}

// Read one \pict group, ignoring metadata subgroups (notably \blipuid).
function readPicture(rtf, start, number) {
  let depth = 0, mime, extension, hex = '', binary;
  for (let index = start; index < rtf.length;) {
    const char = rtf[index++];
    if (char === '{') { depth++; continue; }
    if (char === '}') {
      if (depth) { depth--; continue; }
      if (!mime) return {end: index, file: null};
      if (!binary && (!hex.length || hex.length % 2)) throw invalidImage();
      const bytes = binary || Uint8Array.from({length: hex.length / 2}, (_, i) => parseInt(hex.slice(i * 2, i * 2 + 2), 16));
      return {end: index, file: new File([bytes], `word-image-${number}.${extension}`, {type: mime})};
    }
    if (char === '\\') {
      const control = /^([a-z]+)(-?\d+)? ?/i.exec(rtf.slice(index, index + 80));
      if (!control) { index++; continue; }
      index += control[0].length;
      if (control[1] === 'bin') {
        const length = Number(control[2]);
        if (!Number.isSafeInteger(length) || length < 0 || index + length > rtf.length) throw invalidImage();
        if (!depth && mime) {
          if (length > IMAGE_LIMIT) throw Object.assign(new Error('IMAGE_TOO_LARGE'), {code: 'IMAGE_TOO_LARGE'});
          binary = Uint8Array.from(rtf.slice(index, index + length), c => c.charCodeAt(0) & 255);
        }
        index += length;
      } else if (!depth && control[1] === 'pngblip') { mime = 'image/png'; extension = 'png'; }
      else if (!depth && control[1] === 'jpegblip') { mime = 'image/jpeg'; extension = 'jpg'; }
      continue;
    }
    if (!depth && mime && /[0-9a-f]/i.test(char)) {
      // Consume long hex runs together instead of allocating one string per byte.
      const begin = index - 1;
      while (index < rtf.length && /[0-9a-f\s]/i.test(rtf[index])) index++;
      hex += rtf.slice(begin, index).replace(/\s/g, '');
      if (hex.length > IMAGE_LIMIT * 2) throw Object.assign(new Error('IMAGE_TOO_LARGE'), {code: 'IMAGE_TOO_LARGE'});
    }
  }
  throw invalidImage();
}

export function extractRtfImages(rtf = '') {
  const images = [], fallback = [false];
  for (let index = 0; index < rtf.length;) {
    const char = rtf[index++];
    if (char === '{') fallback.push(fallback.at(-1));
    else if (char === '}') fallback.pop();
    else if (char === '\\') {
      const control = /^([a-z]+)(-?\d+)? ?/i.exec(rtf.slice(index, index + 80));
      if (!control) { index++; continue; }
      index += control[0].length;
      if (control[1] === 'nonshppict') fallback[fallback.length - 1] = true;
      else if (control[1] === 'bin') index += Math.max(0, Number(control[2]) || 0);
      else if (control[1] === 'pict') {
        const picture = readPicture(rtf, index, images.length + 1);
        if (!fallback.at(-1)) images.push(picture.file);
        fallback.pop();
        index = picture.end;
      }
    }
  }
  return images;
}

function clipboardDocument(html) {
  // CF_HTML offsets count UTF-8 bytes, not JavaScript characters. Use its markers.
  const fragment = /<!--StartFragment-->([\s\S]*?)<!--EndFragment-->/i.exec(html);
  const doc = new DOMParser().parseFromString(fragment ? fragment[1] : html, 'text/html');
  if (!doc.querySelector('img')) {
    // Some Word versions supply only VML inside an Office conditional comment.
    const comments = doc.createTreeWalker(doc.body, NodeFilter.SHOW_COMMENT);
    const replacements = [];
    while (comments.nextNode()) {
      const comment = comments.currentNode;
      if (/<v:imagedata\b/i.test(comment.data)) replacements.push(comment);
    }
    for (const comment of replacements) {
      const holder = doc.createElement('span');
      holder.innerHTML = comment.data.replace(/^\[if[^\]]*\]>/i, '').replace(/<!\[endif\]$/i, '');
      comment.replaceWith(holder);
    }
  }
  for (const node of [...doc.getElementsByTagName('*')]) {
    if (node.localName.toLowerCase() !== 'v:imagedata') continue;
    const image = doc.createElement('img');
    image.setAttribute('src', node.getAttribute('src') || node.getAttribute('o:href') || '');
    image.alt = node.getAttribute('o:title') || '';
    node.replaceWith(image);
  }
  return doc;
}

function cleanHTML(doc) {
  doc.querySelectorAll('script,style,meta,link,iframe,object,embed,svg,math,form,input,button,textarea,select').forEach(node => node.remove());
  const allowed = new Set('p div span br hr h1 h2 h3 h4 h5 h6 b strong i em u s del strike sub sup blockquote pre code ul ol li table thead tbody tfoot tr th td a img'.split(' '));
  for (const node of [...doc.body.querySelectorAll('*')].reverse()) {
    if (!allowed.has(node.localName)) { node.replaceWith(...node.childNodes); continue; }
    for (const attr of [...node.attributes]) {
      if (!['src', 'alt', 'href', 'title', 'colspan', 'rowspan', 'start', 'style'].includes(attr.name)) node.removeAttribute(attr.name);
    }
    if (node.hasAttribute('href') && !/^(https?:|mailto:|#)/i.test(node.getAttribute('href'))) node.removeAttribute('href');
    if (node.hasAttribute('style')) {
      const style = node.style;
      const safe = ['font-weight', 'font-style', 'text-decoration', 'text-align'].map(key => {
        const value = style.getPropertyValue(key);
        return /^[a-z0-9 -]+$/i.test(value) ? `${key}:${value}` : '';
      }).filter(Boolean).join(';');
      node.removeAttribute('style');
      if (safe) node.setAttribute('style', safe);
    }
  }
  return doc.body.innerHTML;
}

async function imageFile(source, host, index) {
  const path = localImagePath(source);
  if (path !== null) {
    const stat = await host.fs.stat(path);
    if (stat.size > IMAGE_LIMIT) throw Object.assign(new Error('IMAGE_TOO_LARGE'), {code: 'IMAGE_TOO_LARGE'});
    const bytes = await host.fs.readBinary(path);
    return new File([bytes], path.split(/[\\/]/).at(-1) || `word-image-${index}.png`);
  }
  const data = /^data:image\/(png|jpe?g|gif|webp|bmp);base64,([\s\S]*)$/i.exec(source);
  if (!data) throw invalidImage();
  if (data[2].length > Math.ceil(IMAGE_LIMIT / 3) * 4 + 1024) throw Object.assign(new Error('IMAGE_TOO_LARGE'), {code: 'IMAGE_TOO_LARGE'});
  const bytes = Uint8Array.from(atob(data[2].replace(/\s/g, '')), c => c.charCodeAt(0));
  return new File([bytes], `word-image-${index}.${data[1].replace('jpeg', 'jpg')}`, {type: `image/${data[1]}`});
}

export async function prepareWordPaste({html, rtf = '', files = [], host, importImage}) {
  const doc = clipboardDocument(html);
  const images = [...doc.querySelectorAll('img')];
  const imported = new Map();
  let rtfImages;
  for (const [index, image] of images.entries()) {
    const source = image.getAttribute('src') || '';
    const key = source || `missing-image-${index}`;
    let attachment = imported.get(key);
    if (!attachment) {
      try { attachment = await importImage(await imageFile(source, host, index + 1)); }
      catch (error) {
        // A Word file:// URL can name a file that was never materialized.
        rtfImages ??= extractRtfImages(rtf);
        const file = rtfImages[index] || (files.length === images.length ? files[index] : null);
        if (!file) throw error;
        attachment = await importImage(file);
      }
      imported.set(key, attachment);
    }
    image.setAttribute('src', attachment.path);
    image.removeAttribute('srcset');
    if (!image.alt) image.alt = attachment.alt;
  }
  return cleanHTML(doc);
}

export function installWordPaste({element, editor, host, runPaste, toMarkdown, separateHistory}) {
  let active = true;
  function paste(event) {
    const data = event.clipboardData;
    const html = data?.getData('text/html') || '';
    if (!/<(?:img|v:imagedata)\b/i.test(html)) return;
    // Snapshot clipboard data synchronously; the native event expires after dispatch.
    const rtf = data.getData('text/rtf') || data.getData('text/richtext') || '';
    const text = data.getData('text/plain') || '';
    const files = Array.from(data.files || []).filter(file => file.type.startsWith('image/'));
    // Leave existing note-to-note and ordinary web HTML pastes to the editor.
    if (!rtf && !files.length && !/file:|data:image\/|v:imagedata/i.test(html)) return;
    const mode = editor.getCurrentModeEditor();
    const original = mode.view.state.doc;
    const selection = editor.getSelection();
    const current = () => active && editor.getCurrentModeEditor() === mode && mode.view.state.doc === original;
    event.preventDefault();
    event.stopImmediatePropagation();
    runPaste(async ({importImage, isActive}) => {
      let prepared;
      try { prepared = await prepareWordPaste({html, rtf, files, host, importImage}); }
      catch (error) {
        if (isActive() && current() && text) {
          editor.setSelection(...selection);
          separateHistory?.();
          editor.insertText(text);
          separateHistory?.();
        }
        throw error;
      }
      if (!isActive() || !active) return;
      // Never replace text typed while an asynchronous attachment was being saved.
      if (!current()) throw Object.assign(new Error('BUSY'), {code: 'BUSY'});
      editor.setSelection(...selection);
      separateHistory?.();
      if (editor.isMarkdownMode()) editor.insertText(toMarkdown(prepared));
      else mode.view.pasteHTML(prepared);
      separateHistory?.();
      editor.focus();
    });
  }
  element.addEventListener('paste', paste, true);
  return () => { active = false; element.removeEventListener('paste', paste, true); };
}
