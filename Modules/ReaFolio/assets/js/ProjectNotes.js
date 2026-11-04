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
export async function isAllowedNotesRoot(host, config, root, pathKey) {
  if (typeof root !== 'string') return false;
  if (typeof config.root === 'string' && pathKey(root) === pathKey(config.root)) return true;
  const folder = validateProjectFolder(config.projectFolder ?? '.reafolio');
  for (let index = 0; ; index++) {
    const [project, filename] = await host.EnumProjects(index);
    if (!project) return false;
    const candidate = projectNotesRoot(filename, folder);
    if (candidate && pathKey(root) === pathKey(candidate)) return true;
  }
}

export class ProjectNotes {
  constructor({repo, state, defaultRoot, beforeChange, isBlocked, formatError}) {
    Object.assign(this, {repo, state, defaultRoot, beforeChange, isBlocked, formatError});
    this.projectKey = null;
    this.stopped = false;
  }

  async currentProject() {
    const [project, filename] = await this.repo.host.EnumProjects(-1);
    return {key: JSON.stringify([project, filename]), filename: filename || ''};
  }

  async directory(path, create = false, strict = false) {
    const {host} = this.repo;
    let info = await host.fs.stat(path);
    if (!info.exists && create) {
      try { await host.fs.makeDirectory(path); }
      catch (error) { if (error.code !== 'FILE_EXISTS') throw error; }
      info = await host.fs.stat(path);
    }
    if (!info.exists || info.type !== 'directory') throw failure('WORKSPACE_UNAVAILABLE');
    if (strict && this.repo.pathKey(info.path) !== this.repo.pathKey(path)) throw failure('UNSAFE_PATH');
    await host.fs.readDirectory(info.path);
    return info.path;
  }

  async target(config, scope, project) {
    if (scope === 'global') return this.directory(config.root);
    const root = projectNotesRoot(project.filename, config.projectFolder);
    if (!root) return '';
    const file = await this.repo.host.fs.stat(project.filename);
    if (!file.exists || file.type !== 'file') return '';
    return this.directory(root, true, true);
  }

  async persist(config) {
    await this.repo.host.fs.writeText(this.repo.dataPath + '/settings.json', JSON.stringify(config), {overwrite: true});
    this.repo.config = config;
  }

  publish(config, project) {
    this.state.scope = config.notesScope;
    this.state.globalRoot = config.root;
    this.state.projectFolder = config.projectFolder;
    this.state.projectName = project?.filename.replaceAll('\\', '/').split('/').pop() || '';
    this.projectKey = project?.key ?? null;
  }

  async activate(root) {
    // Stop readers/watchers and drain drafts/attachments before rebinding the
    // shared repository. Even failure must not leave the old editor writable.
    await this.repo.clearRoot();
    if (root) await this.repo.setRoot(root, false);
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
      await this.activate(await this.target(config, config.notesScope, project));
    } catch (error) {
      this.publish(config, project);
      this.state.error = this.formatError(error);
    }
    this.timer = setInterval(() => this.refresh().catch(error => this.report(error)), 1000);
    try {
      this.unsubscribe = await this.repo.host.events.on('projectChanged', () => {
        this.refresh().catch(error => this.report(error));
      });
    } catch { /* Older hosts still follow tab switches and Save As by polling. */ }
  }

  blocked(automatic = false) {
    return this.stopped || this.state.busy || this.state.refreshing || this.repo.busy ||
      this.repo.images.pending || this.isBlocked?.(automatic);
  }

  report(error) { if (!this.stopped) this.state.error = this.formatError(error); }

  async change(scope, changes = {}, automatic = false, observedProject) {
    if (this.blocked(automatic)) return false;
    this.state.busy = true;
    const previous = {...this.repo.config}, previousRoot = this.repo.root;
    let persisted = false, activated = false;
    try {
      if (!['global', 'project'].includes(scope)) throw failure('INVALID_REQUEST');
      const config = {...previous, ...changes, notesScope: scope};
      validateProjectFolder(config.projectFolder);
      // Validate all Settings fields before asking the editor to leave.
      if (config.root !== previous.root) config.root = await this.directory(config.root);
      let project = scope === 'project' ? await this.currentProject() : undefined;
      const affectsActive = automatic || scope !== this.state.scope || !this.repo.root ||
        (scope === 'project' && project.key !== this.projectKey) ||
        (scope === 'global' ? config.root !== previous.root : config.projectFolder !== previous.projectFolder);
      if (affectsActive && this.beforeChange && !await this.beforeChange(automatic)) return false;
      if (this.repo.busy || this.repo.images.pending) return false;
      this.state.switching = affectsActive;
      // Re-read after a save/discard dialog: the user may have changed tabs.
      if (scope === 'project') project = await this.currentProject();
      const root = affectsActive ? await this.target(config, scope, project) : previousRoot;
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
        if (persisted) await this.persist(previous).catch(restoreError => this.report(restoreError));
        if (activated) await this.activate(previousRoot).catch(() => {});
      }
      this.report(error);
      return false;
    } finally {
      this.state.switching = false;
      this.state.busy = false;
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
  }
}
