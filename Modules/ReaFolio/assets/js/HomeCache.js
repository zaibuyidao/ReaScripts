// Presentation snapshots only. Never use cached titles as file or editor state.
const storageKey = 'reafolio.home.cache.v1';
const startupKey = 'reafolio.home.startup.v1';
const maxSnapshots = 16;

export function readHomeStartup() {
  try {
    const startup = JSON.parse(globalThis.localStorage?.getItem(startupKey) || 'null');
    if (!['global', 'project'].includes(startup?.scope) ||
        typeof startup.workspace !== 'string' || typeof startup.projectName !== 'string') return null;
    if (startup.workspace) {
      const identity = JSON.parse(startup.workspace);
      if (!Array.isArray(identity) || identity.length !== 2 || identity[0] !== startup.scope ||
          typeof identity[1] !== 'string' || !identity[1]) return null;
    }
    return startup;
  } catch { return null; }
}

export function writeHomeStartup(scope, workspace, projectName) {
  try {
    const value = JSON.stringify({scope, workspace, projectName});
    if (globalThis.localStorage?.getItem(startupKey) !== value)
      globalThis.localStorage?.setItem(startupKey, value);
  } catch { /* Startup hints are optional and never authorize storage access. */ }
}

function readSnapshots() {
  try {
    const snapshots = JSON.parse(globalThis.localStorage?.getItem(storageKey) || '[]');
    return Array.isArray(snapshots) ? snapshots.slice(-maxSnapshots) : [];
  } catch { return []; }
}

export function readHomeCache(workspace, view) {
  if (!workspace) return null;
  const snapshot = readSnapshots().find(entry => entry?.workspace === workspace && entry.view === view);
  if (!Array.isArray(snapshot?.titles) || snapshot.titles.length > 101 ||
      snapshot.titles.some(title => typeof title !== 'string' || !title)) return null;
  return snapshot.titles.map(title => ({title}));
}

export function writeHomeCache(workspace, view, notes) {
  if (!workspace) return;
  try {
    const titles = notes.slice(0, 101).map(note => note.title);
    const snapshots = readSnapshots();
    const previous = snapshots.find(entry => entry?.workspace === workspace);
    if (previous?.view === view && JSON.stringify(previous.titles) === JSON.stringify(titles)) return;
    const remaining = snapshots.filter(entry => entry?.workspace !== workspace).slice(1 - maxSnapshots);
    remaining.push({workspace, view, titles});
    globalThis.localStorage?.setItem(storageKey, JSON.stringify(remaining));
  } catch { /* An unavailable or full cache must not prevent opening notes. */ }
}
