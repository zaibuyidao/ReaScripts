// Versioned Markdown targets. Parsing and encoding are shared by the menu,
// renderer and click handler; rendering never invokes REAPER or opens a file.
const internalKinds = new Set(['action', 'time', 'marker', 'region', 'track', 'item', 'selection']);
const guidPattern = /^\{[\da-f]{8}(?:-[\da-f]{4}){3}-[\da-f]{12}\}$/i;
const badText = /[\x00-\x1f\x7f]/;
export const linkError = code => Object.assign(new Error(code), {code: 'LINK_' + code});
const check = (condition, code = 'INVALID') => {if (!condition) throw linkError(code);};
const clean = value => {check(typeof value === 'string' && value.length <= 32768 && !badText.test(value)); return value;};
const numeric = value => {
  check(/^(?:0|[1-9]\d*)(?:\.\d+)?(?:e[+-]?\d+)?$/i.test(String(value)));
  const number = Number(value); check(Number.isFinite(number) && number >= 0); return number;
};
// Keep Unicode names and path/GUID punctuation readable in Markdown. Escape
// URL delimiters, literal percent signs and Markdown delimiters exactly once.
const encode = value => Array.from(value, char => /[\p{L}\p{N}\p{M}:/{\}]/u.test(char) ? char :
  encodeURIComponent(char).replace(/[!'()*]/g, c => '%' + c.charCodeAt(0).toString(16).toUpperCase())).join('');
const decode = value => {
  try {return value.replace(/(?:%[\da-f]{2})+/gi, run => decodeURIComponent(run));}
  catch {throw linkError('INVALID');}
};

export function isIntegrationTarget(value) {
  if (typeof value !== 'string' || !value || value.startsWith('#')) return false;
  return /^(?:reafolio:|file:|[a-z]:[\\/])/i.test(value) || !/^[a-z][\w+.-]*:/i.test(value);
}

export function normalizePath(value) {
  value = clean(value).replace(/\\/g, '/');
  let prefix, rest;
  if (/^[a-z]:\//i.test(value)) {prefix = value.slice(0, 3); rest = value.slice(3);}
  else if (value.startsWith('//')) {
    const match = /^\/\/([^/]+)\/([^/]+)(?:\/|$)/.exec(value);
    check(match); prefix = '//' + match[1] + '/' + match[2] + '/'; rest = value.slice(match[0].length);
  } else {check(value.startsWith('/')); prefix = '/'; rest = value.slice(1);}
  const segments = [];
  for (const part of rest.split('/')) {
    if (!part || part === '.') continue;
    if (part === '..') {check(segments.length > 0); segments.pop();}
    else segments.push(part);
  }
  return prefix + segments.join('/');
}

export function resolveLocalPath(value, context = {}) {
  clean(value);
  let local;
  if (/^file:/i.test(value)) {
    let url; try {url = new URL(value);} catch {throw linkError('INVALID');}
    check(!url.search && !url.hash && !url.username && !url.password && !url.port);
    local = decode(url.pathname);
    if (url.hostname && url.hostname !== 'localhost') local = '//' + url.hostname + local;
    else if (/^\/[a-z]:\//i.test(local)) local = local.slice(1);
  } else {
    check(isIntegrationTarget(value) && !/^reafolio:/i.test(value));
    local = decode(value).replace(/\\/g, '/');
    if (!/^(?:[a-z]:\/|\/)/i.test(local)) {
      check(context.filename && context.root, 'SAVE_NOTE');
      const note = normalizePath(context.root + '/' + context.filename);
      local = note.slice(0, note.lastIndexOf('/') + 1) + local;
    }
  }
  return normalizePath(local);
}

export function localFileHref(path, context = {}, relative = false) {
  path = normalizePath(path);
  if (relative) {
    check(context.filename && context.root, 'SAVE_NOTE');
    const note = normalizePath(context.root + '/' + context.filename);
    const base = note.slice(0, note.lastIndexOf('/')).split('/');
    const target = path.split('/');
    const windows = /^[a-z]:/i.test(path) || path.startsWith('//');
    const equal = (a, b) => windows ? a?.toLowerCase() === b?.toLowerCase() : a === b;
    // Different drives/UNC shares require an absolute link.
    check(equal(base[0], target[0]) && (!path.startsWith('//') ||
      equal(base[2], target[2]) && equal(base[3], target[3])), 'RELATIVE_ROOT');
    let common = 0; while (common < Math.min(base.length, target.length) && equal(base[common], target[common])) common++;
    const result = [...base.slice(common).map(() => '..'), ...target.slice(common)].map(encode).join('/');
    return result.startsWith('../') ? result : './' + result;
  }
  if (path.startsWith('//')) return 'file://' + path.slice(2).split('/').map(encode).join('/');
  if (/^[a-z]:\//i.test(path)) return 'file:///' + path.slice(0, 2) + path.slice(2).split('/').map(encode).join('/');
  return 'file://' + path.split('/').map(encode).join('/');
}

export function parseIntegrationLink(href, context = {}) {
  clean(href);
  if (!/^reafolio:/i.test(href)) {
    check(isIntegrationTarget(href));
    const path = resolveLocalPath(href, context);
    return /\.rpp$/i.test(path) ? {kind: 'project', project: path} : {kind: 'file', path};
  }
  let url; try {url = new URL(href);} catch {throw linkError('INVALID');}
  const kind = url.pathname.slice(1);
  check(url.hostname === 'v1' && !url.port && !url.hash && !url.username && !url.password && internalKinds.has(kind));
  const values = Object.create(null);
  for (const [key, value] of url.searchParams) {check(!(key in values)); values[key] = clean(value);}
  const allowed = kind === 'action' ? ['section', 'command'] : ['project', ...(
    kind === 'time' ? ['start'] : kind === 'selection' ? ['start', 'finish'] :
      kind === 'track' || kind === 'item' || values.guid !== undefined ? ['guid'] : ['id', 'start', 'finish', 'name'])];
  check(Object.keys(values).every(key => allowed.includes(key)));
  const target = {kind};
  if (kind === 'action') {
    check(values.section === 'main', 'SECTION');
    check(/^(?:[1-9]\d*|_[\w&.-]+)$/.test(values.command || ''));
    return {...target, section: 'main', command: values.command};
  }
  target.project = normalizePath(values.project);
  check(/\.rpp$/i.test(target.project));
  if (kind === 'time' || kind === 'selection') {
    target.start = numeric(values.start);
    if (kind === 'selection') {target.finish = numeric(values.finish); check(target.finish > target.start);}
  } else if (kind === 'track' || kind === 'item') {
    check(guidPattern.test(values.guid)); target.guid = values.guid.toUpperCase();
  } else {
    if (values.guid !== undefined) {check(guidPattern.test(values.guid)); target.guid = values.guid.toUpperCase();}
    if (!target.guid) {
      target.id = numeric(values.id); check(Number.isSafeInteger(target.id));
      target.start = numeric(values.start); target.finish = numeric(values.finish); target.name = clean(values.name);
    }
  }
  return target;
}

export function integrationHref(target) {
  check(internalKinds.has(target.kind));
  // A marker/region GUID already identifies the object after moves/renames.
  // REAPER versions without marker GUIDs need the complete fallback identity.
  const compact = (target.kind === 'marker' || target.kind === 'region') && target.guid
    ? {kind: target.kind, project: target.project, guid: target.guid} : target;
  const query = Object.entries(compact).filter(([key, value]) => key !== 'kind' && value != null)
    .map(([key, value]) => encode(key) + '=' + encode(String(value))).join('&');
  const href = `reafolio://v1/${target.kind}?${query}`;
  parseIntegrationLink(href);
  return href;
}
export function markdownLink(label, href) {
  return '[' + clean(label).replace(/[\\[\]`*_<>]/g, '\\$&') + '](' + href + ')';
}
export function integrationLinkAttributes(href) {
  return isIntegrationTarget(href) ? {href: '#', 'data-reafolio-link': href} : {};
}
export function renderIntegrationLink(node, rendered) {
  if (!isIntegrationTarget(node.destination)) return false;
  rendered.attributes = {...rendered.attributes, ...integrationLinkAttributes(node.destination)};
  return true;
}

export function createLinkClient(host) {
  const pending = new Map();
  let closed = false;
  const ready = host.events.on('message', message => {
    let reply; try {reply = JSON.parse(message);} catch {return;}
    if (reply?.type !== 'reafolio-link-reply') return;
    const entry = pending.get(reply.id); if (!entry) return;
    clearTimeout(entry.timer); pending.delete(reply.id);
    reply.error ? entry.reject(Object.assign(new Error(reply.error), {code: reply.error})) : entry.resolve(reply.value);
  });
  return {
    async request(payload) {
      await ready; check(!closed, 'CLOSED');
      const id = crypto.randomUUID();
      return new Promise((resolve, reject) => {
        const timer = setTimeout(() => {pending.delete(id); reject(linkError('TIMEOUT'));}, 120000);
        pending.set(id, {resolve, reject, timer});
        host.host.send({type: 'reafolio-link', id, ...payload}).catch(error => {
          clearTimeout(timer); pending.delete(id); reject(error);
        });
      });
    },
    dispose() {
      closed = true;
      ready.then(off => off()).catch(() => {});
      for (const entry of pending.values()) {clearTimeout(entry.timer); entry.reject(linkError('CLOSED'));}
      pending.clear();
    },
  };
}

export async function activateIntegrationLink(href, {host, client, context, confirmOpen}) {
  let target = parseIntegrationLink(href, context);
  if (target.kind === 'file' || target.kind === 'project') {
    const stat = await host.fs.stat(target.path || target.project);
    check(stat.exists, 'FILE_MISSING');
    // A folder may happen to have an .rpp suffix; its filesystem type wins.
    if (target.kind === 'project' && stat.type === 'directory') target = {kind: 'file', path: target.project};
    else if (target.kind === 'project') check(stat.type === 'file');
  }
  const request = {operation: 'execute', target, allowOpen: target.kind === 'project'};
  let result = await client.request(request);
  if (result.needsOpen && await confirmOpen(result.project)) {
    result = await client.request({...request, allowOpen: true});
  }
  return result;
}

function markdownTargetAtEvent(editor, event) {
  if (!editor?.isMarkdownMode() || !editor.mdEditor.view.dom.contains(event.target)) return null;
  const view = editor.mdEditor.view;
  const hit = view.posAtCoords({left: event.clientX, top: event.clientY});
  if (!hit) return null;
  const pos = view.state.doc.resolve(hit.pos);
  if (!pos.depth) return null;
  let node = editor.toastMark.findNodeAtPosition([pos.index(0) + 1, pos.pos - pos.start(1) + 1]);
  while (node && node.type !== 'link') node = node.parent;
  return node?.destination;
}

export function listenForIntegrationLinks(element, {editor, getContext, activate, report}) {
  const click = event => {
    if (event.button !== 0) return;
    const anchor = event.target.closest('a');
    let href = anchor?.getAttribute('data-reafolio-link') || anchor?.getAttribute('href');
    if (!href && (event.ctrlKey || event.metaKey)) href = markdownTargetAtEvent(editor, event);
    if (!isIntegrationTarget(href)) return;
    event.preventDefault();
    // The editor's rendered preview is read-only, even while Edit is enabled.
    const inPreview = anchor?.closest('.toastui-editor-md-preview');
    if (editor && !inPreview && !(event.ctrlKey || event.metaKey)) return;
    event.stopImmediatePropagation();
    const context = {...getContext()};
    Promise.resolve().then(() => activate(href, context)).catch(report);
  };
  // Middle-click must not fall through to WebView navigation for native links.
  const auxiliary = event => {
    const anchor = event.target.closest('a');
    if (isIntegrationTarget(anchor?.getAttribute('data-reafolio-link') || anchor?.getAttribute('href'))) event.preventDefault();
  };
  element.addEventListener('click', click, true);
  element.addEventListener('auxclick', auxiliary, true);
  return () => {element.removeEventListener('click', click, true); element.removeEventListener('auxclick', auxiliary, true);};
}
