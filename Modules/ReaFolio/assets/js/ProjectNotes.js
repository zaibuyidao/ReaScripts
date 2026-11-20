import {invalidateHomeCache, writeHomeStartup} from './HomeCache.js';

// Storage scope is independent of the global folder and of REAPER project state.
const failure = code => Object.assign(new Error(code), {code});

export function validateProjectFolder(folder) {
  if (typeof folder !== 'string' || !folder || folder.length > 120 ||
      folder !== folder.trim() || folder === '.' || folder === '..' ||
      /[<>:"/\\|?*\x00-\x1f\x7f]/.test(folder) || /[. ]$/.test(folder) ||
      /^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(folder)) {
    throw failure('INVALID_PROJECT_FOLDER');
  }
  return folder;
}

export function projectNotesRoot(filename, folder = '.reafolio') {
  validateProjectFolder(folder);
  if (typeof filename !== 'string' || !filename) return '';
  const path = filename.replaceAll('\\', '/');
  // An unsaved project must never fall back to REAPER's last-used directory.
  if (!/^(?:[a-z]:\/|\/)/i.test(path) || !/\/[^/]+$/.test(path)) return '';
  return path.slice(0, path.lastIndexOf('/') + 1) + folder;
}

// Rename/delete recovery may operate only in the global folder or a saved,
// open project's configured folder. Never trust a root supplied by a request.
export async function isAllowedNotesRoot(backend, config, root, pathKey) {
  if (typeof root !== 'string') return false;
  if (typeof config.root === 'string' && pathKey(root) === pathKey(config.root)) return true;
  const folder = validateProjectFolder(config.projectFolder ?? '.reafolio');
  const files = await backend.request('open-project-files');
  return files.some(filename => {
    const candidate = projectNotesRoot(filename, folder);
    return candidate && pathKey(root) === pathKey(candidate);
  });
}

export class ProjectNotes {
  constructor({repo, backend, state, defaultRoot, beforeChange, isBlocked, formatError}) {
    Object.assign(this, {repo, backend, state, defaultRoot, beforeChange, isBlocked, formatError});
    this.projectKey = null;
    this.scopeRequest = null;
    this.selectionTask = null;
    this.stopped = false;
  }

  async currentProject() {
    const {id, filename} = await this.backend.request('current-project');
    return this.projectHint = {key: JSON.stringify([id, filename]), filename};
  }

  async directory(path, create = false, strict = false, checkReadable = true) {
    const {host} = this.repo;
    let info = await host.fs.stat(path);
    if (!info.exists && create) {
      try { await host.fs.makeDirectory(path); }
      catch (error) { if (error.code !== 'FILE_EXISTS') throw error; }
      info = await host.fs.stat(path);
    }
    if (!info.exists || info.type !== 'directory') throw failure('WORKSPACE_UNAVAILABLE');
    if (strict && this.repo.pathKey(info.path) !== this.repo.pathKey(path)) throw failure('UNSAFE_PATH');
    if (checkReadable) await host.fs.readDirectory(info.path);
    return info.path.replaceAll('\\', '/');
  }

  async target(config, scope, project, checkReadable = true) {
    if (scope === 'global') {
      // The default folder may be absent on a fresh install or after reinstalling.
      // Recreate it automatically, while keeping custom-folder errors explicit.
      const isDefault = this.repo.pathKey(config.root) === this.repo.pathKey(this.defaultRoot);
      return this.directory(config.root, isDefault, isDefault, checkReadable);
    }
    const root = projectNotesRoot(project.filename, config.projectFolder);
    if (!root) return '';
    const file = await this.repo.host.fs.stat(project.filename);
    if (!file.exists || file.type !== 'file') return '';
    return this.directory(root, true, true, checkReadable);
  }

  async persist(config) {
    await this.repo.host.fs.writeText(this.repo.dataPath + '/settings.json', JSON.stringify(config), {overwrite: true});
    this.repo.config = config;
  }

  presentation(config, project) {
    const root = config.notesScope === 'project'
      ? projectNotesRoot(project?.filename, config.projectFolder) : config.root;
    return {
      scope: config.notesScope,
      projectName: project?.filename.replaceAll('\\', '/').split('/').pop() || '',
      homeCacheKey: root ? JSON.stringify([config.notesScope, this.repo.pathKey(root)]) : '',
    };
  }

  publish(config, project) {
    const view = this.presentation(config, project);
    Object.assign(this.state, view, {globalRoot: config.root, projectFolder: config.projectFolder});
    if (this.activeSelection && this.activeSelection === this.scopeRequest)
      this.state.scopeSelection = view;
    const visible = this.state.scopeSelection || view;
    writeHomeStartup(visible.scope, visible.homeCacheKey, visible.projectName);
    this.project = project;
    this.projectKey = project?.key ?? null;
  }

  async activate(root) {
    // Stop readers/watchers and drain drafts/attachments before rebinding the
    // shared repository. Even failure must not leave the old editor writable.
    await this.repo.clearRoot();
    if (root) await this.repo.setRoot(root, false, {backgroundScan: true});
    this.state.root = this.repo.root;
    this.state.revision++;
  }

  async init() {
    const config = {...this.repo.config,
      root: this.repo.config.root || await this.directory(this.defaultRoot, true, true),
      projectFolder: this.repo.config.projectFolder ?? '.reafolio',
      notesScope: this.repo.config.notesScope === 'project' ? 'project' : 'global'};
    validateProjectFolder(config.projectFolder);
    await this.persist(config);
    let project;
    try {
      if (config.notesScope === 'project') project = await this.currentProject();
      this.publish(config, project);
      await this.activate(await this.target(config, config.notesScope, project, false));
    } catch (error) {
      this.publish(config, project);
      this.state.homeCacheKey = '';
      this.state.error = this.formatError(error);
    }
    this.timer = setInterval(() => this.refresh().catch(error => this.report(error)), 1000);
    try {
      this.unsubscribe = await this.repo.host.events.on('projectChanged', () => {
        this.refresh().catch(error => this.report(error));
      });
    } catch { /* Older hosts still follow tab switches and Save As by polling. */ }
  }

  blocked(automatic = false, selecting = false) {
    return this.stopped || ((this.state.busy || this.scopeRequest) && !selecting) || this.state.refreshing || this.repo.busy ||
      this.repo.images.pending || this.isBlocked?.(automatic);
  }

  report(error) { if (!this.stopped) this.state.error = this.formatError(error); }

  select(scope) {
    if (!['global', 'project'].includes(scope) || this.stopped ||
        (this.scopeRequest?.scope ?? this.state.scope) === scope ||
        (this.state.busy && !this.scopeRequest) || this.state.refreshing ||
        (this.repo.busy && !this.repo.images.syncTask) || this.repo.images.pending || this.isBlocked?.(false))
      return Promise.resolve(false);
    const request = {scope, config: {...this.repo.config, notesScope: scope}};
    this.state.scopeVersion = (this.state.scopeVersion || 0) + 1;
    this.scopeRequest = request;
    this.state.busy = true;
    this.previewSelection(request, scope === 'project' ? this.projectHint : undefined);
    // Resolve project identity independently of the active disk operation. Only
    // the latest request may update the visible cache; repository work stays serial.
    request.ready = (scope === 'project' ? this.currentProject() : Promise.resolve(undefined))
      .then(project => {
        if (this.scopeRequest === request) this.previewSelection(request, project);
        return {project};
      }, error => ({error}));
    if (!this.selectionTask) {
      this.selectionTask = this.drainSelections().finally(() => {
        this.selectionTask = null;
        this.activeSelection = null;
        this.scopeRequest = null;
        this.state.scopeSelection = null;
        this.state.busy = false;
        const view = this.presentation(this.repo.config, this.project);
        writeHomeStartup(view.scope, view.homeCacheKey, view.projectName);
      });
    }
    return this.selectionTask;
  }

  previewSelection(request, project) {
    const view = this.presentation(request.config, project);
    this.state.scopeSelection = view;
    writeHomeStartup(view.scope, view.homeCacheKey, view.projectName);
  }

  async drainSelections() {
    let result = false;
    while (!this.stopped && this.scopeRequest) {
      const request = this.scopeRequest;
      const resolved = await request.ready;
      if (request !== this.scopeRequest) continue;
      if (resolved.error) {
        this.report(resolved.error);
        return false;
      }
      await this.repo.pauseImageSync();
      if (request !== this.scopeRequest) continue;
      this.activeSelection = request;
      result = await this.change(request.scope, {}, false, resolved.project, true);
      this.activeSelection = null;
      if (request === this.scopeRequest) {
        this.scopeRequest = null;
        const view = this.presentation(this.repo.config, this.project);
        writeHomeStartup(view.scope, view.homeCacheKey, view.projectName);
      }
    }
    return result;
  }

  change(...args) {
    if (this.blocked(args[2], args[4])) return Promise.resolve(false);
    const task = this.performChange(...args);
    this.changeTask = task;
    return task.finally(() => { if (this.changeTask === task) this.changeTask = null; });
  }

  async whenReady(expectedKey, scopeVersion) {
    await (this.selectionTask || this.changeTask);
    return !this.stopped && !this.state.switching && !this.state.scopeSelection && !!this.repo.root &&
      (!expectedKey || expectedKey === this.state.homeCacheKey) &&
      (scopeVersion === undefined || scopeVersion === this.state.scopeVersion);
  }

  async performChange(scope, changes = {}, automatic = false, observedProject, selecting = false) {
    if (this.blocked(automatic, selecting)) return false;
    this.state.busy = true;
    const previous = {...this.repo.config}, previousRoot = this.repo.root;
    const previousProject = this.project;
    let persisted = false, activated = false, previewed = false;
    try {
      if (!['global', 'project'].includes(scope)) throw failure('INVALID_REQUEST');
      const config = {...previous, ...changes, notesScope: scope};
      validateProjectFolder(config.projectFolder);
      // Validate all Settings fields before asking the editor to leave.
      if (config.root !== previous.root) config.root = await this.directory(config.root);
      let project = scope === 'project' ? observedProject ?? await this.currentProject() : undefined;
      const affectsActive = automatic || scope !== this.state.scope || !this.repo.root ||
        (scope === 'project' && project.key !== this.projectKey) ||
        (scope === 'global' ? config.root !== previous.root : config.projectFolder !== previous.projectFolder);
      if (affectsActive && this.beforeChange && !await this.beforeChange(automatic)) return false;
      if (selecting) await this.repo.pauseImageSync();
      if (this.repo.busy || this.repo.images.pending) return false;
      this.state.switching = affectsActive;
      // Re-read after a save/discard dialog: the user may have changed tabs.
      if (scope === 'project') project = await this.currentProject();
      const root = affectsActive ? await this.target(config, scope, project, false) : previousRoot;
      if (selecting && this.activeSelection !== this.scopeRequest) return false;
      if (affectsActive) {
        // Publish presentation state before directory checks, recovery and scanning.
        // The repository remains unavailable to readers until switching finishes.
        this.publish(config, project);
        previewed = true;
        this.state.error = '';
      }
      if (!automatic) { await this.persist(config); persisted = true; }
      if (affectsActive) { activated = true; await this.activate(root); }
      this.publish(config, project);
      this.state.error = '';
      return true;
    } catch (error) {
      if (automatic) {
        // The old project has already left. Keep its draft, never its editor.
        await this.activate('').catch(() => {});
        this.publish(previous, observedProject);
        // Retry unavailable storage on the next event/poll.
        this.projectKey = null;
      } else {
        if (previewed) this.publish(previous, previousProject);
        if (persisted) await this.persist(previous).catch(restoreError => this.report(restoreError));
        if (activated) await this.activate(previousRoot).catch(() => {});
      }
      this.report(error);
      return false;
    } finally {
      this.state.switching = false;
      this.state.busy = !!this.scopeRequest;
    }
  }

  moveNote(...args) {
    if (this.moveTask) return Promise.reject(failure('BUSY'));
    const task = this.performMoveNote(...args);
    this.moveTask = task;
    return task.finally(() => { if (this.moveTask === task) this.moveTask = null; });
  }

  async performMoveNote(title, {rename, beforeActivate, destinations} = {}) {
    if (this.stopped || this.state.busy || this.state.switching || this.scopeRequest || this.state.refreshing ||
        this.repo.images.pending || !this.repo.root) throw failure('BUSY');
    this.state.busy = true;
    let moved, resumeIndex;
    try {
      await this.repo.images.syncTask;
      const sourceRoot = this.repo.root, config = {...this.repo.config};
      const sourceScope = this.state.scope, scope = sourceScope === 'global' ? 'project' : 'global';
      const project = await this.currentProject();
      if (!project.filename) throw failure('TRANSFER_SAVE_PROJECT');
      if (sourceScope === 'project' && this.repo.pathKey(projectNotesRoot(project.filename, config.projectFolder)) !== this.repo.pathKey(sourceRoot))
        throw failure('TRANSFER_PROJECT_CHANGED');
      const targetRoot = await this.target(config, scope, project);
      if (!targetRoot) throw failure('TRANSFER_SAVE_PROJECT');
      if (this.repo.pathKey(sourceRoot) === this.repo.pathKey(targetRoot)) throw failure('TRANSFER_SAME_ROOT');
      const note = this.repo.baselines.get(title.normalize('NFC').toLowerCase());
      if (!note) throw failure('CONFLICT');
      let destination = title;
      while (!await this.repo.transfers.available(targetRoot, destination)) {
        destination = await rename?.(destination);
        if (destination === false || destination == null) return null;
      }
      const assertCurrent = async () => {
        if (this.stopped) throw failure('BACKEND_CLOSED');
        if (this.repo.root !== sourceRoot || (await this.currentProject()).key !== project.key)
          throw failure('TRANSFER_PROJECT_CHANGED');
      };
      await assertCurrent();
      resumeIndex = this.repo.pauseIndex();
      moved = await this.repo.transfers.move({sourceRoot, targetRoot, note, title: destination, assertCurrent, destinations});
      await beforeActivate?.();
      this.state.switching = true;
      const draftKey = this.repo.draftKey(title);
      delete this.repo.drafts[draftKey];
      globalThis.localStorage?.removeItem('reafolio.draft:' + draftKey);
      await this.repo.flushDrafts();
      invalidateHomeCache([JSON.stringify([sourceScope, this.repo.pathKey(sourceRoot)]), JSON.stringify([scope, this.repo.pathKey(targetRoot)])]);
      const next = {...config, notesScope: scope};
      await this.persist(next);
      await this.activate(targetRoot);
      this.publish(next, scope === 'project' ? project : undefined);
      this.state.error = '';
      return {...moved, scope, activated: true};
    } catch (error) {
      if (moved) {
        this.report(failure('TRANSFER_OPEN_FAILED'));
        return {...moved, activated: false};
      }
      throw error;
    } finally {
      this.state.switching = false;
      this.state.busy = false;
      resumeIndex?.();
    }
  }

  async refresh() {
    if (this.state.scope !== 'project' || this.blocked(true) || this.checking) return;
    this.checking = true;
    try {
      const project = await this.currentProject();
      if (!this.stopped && this.state.scope === 'project' && project.key !== this.projectKey)
        await this.change('project', {}, true, project);
    } finally { this.checking = false; }
  }

  async dispose() {
    this.stopped = true;
    clearInterval(this.timer);
    await this.unsubscribe?.();
    await this.selectionTask;
    await this.moveTask?.catch(() => {});
  }
}
