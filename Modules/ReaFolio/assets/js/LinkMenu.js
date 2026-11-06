import {
  activateIntegrationLink, createLinkClient, integrationHref, linkError,
  listenForIntegrationLinks, localFileHref, markdownLink,
} from './ReaperLinks.js';

const words = {
  menu: ['Quick links', '快捷链接'],
  insert: ['Insert', '插入'], cancel: ['Cancel', '取消'], close: ['Close', '关闭'], choose: ['Choose…', '选择…'],
  noPath: ['No target selected', '尚未选择目标'],
  kind: ['Link type', '链接类型'], label: ['Display text (optional)', '显示文字（可选）'],
  file: ['Local file', '本地文件'], folder: ['Folder', '文件夹'], project: ['REAPER project (.rpp)', 'REAPER 工程（.rpp）'],
  action: ['REAPER Action (Main)', 'REAPER Action（Main）'], time: ['Current edit cursor', '当前编辑光标'],
  track: ['Selected tracks', '选中的轨道'], item: ['Selected media items', '选中的媒体项'],
  marker: ['Marker', 'Marker 标记'], region: ['Region', 'Region 区域'], selection: ['Current time selection', '当前时间选区'],
  relative: ['Use a path relative to this saved note', '使用相对于这篇已保存笔记的路径'],
  command: ['Command ID or named command, e.g. 40001 / _RS…', '命令 ID 或命名命令，例如 40001 / _RS…'],
  actionHint: ['Actions run in the project active when the link is clicked. Main section only.', 'Action 作用于点击链接时的当前活动工程，仅支持 Main Section。'],
  hint: ['Click a link in reading mode or the preview pane to activate it. While editing text, hold Ctrl (Windows) or Cmd (macOS) and click. Save the project before creating a project location link.', '在阅读状态或预览区域中，单击链接即可触发。编辑正文时，请按住 Ctrl（Windows）或 Cmd（macOS）再单击。创建工程定位链接前，请先保存工程。'],
  multi: ['Multiple selected objects produce one link each. Leave display text empty to use their names.', '选中多个对象时每个对象生成一条链接；显示文字留空时使用各对象的名称。'],
  open: ['Open project and locate', '打开工程并定位'],
  unopened: ['The target project is not open. Open it in a new tab?', '目标工程尚未打开，是否在新工程标签页打开后定位？'],
  INVALID: ['The link or its parameters are invalid.', '链接类型或参数无效。'],
  SECTION: ['Only the Main Action section is supported. Nothing was executed.', '仅支持 Main Action Section，未执行其他 Section 的命令。'],
  ACTION_MISSING: ['Action not found. Check the script or extension is installed and registered.', '找不到 Action，请检查相应脚本或扩展是否已安装并注册。'],
  ACTION_NAMED: ['This is a custom/script Action. Reinsert it to save its stable named command.', '这是自定义或脚本 Action，请重新插入以保存稳定的命名命令。'],
  SAVE_PROJECT: ['Save the REAPER project before creating a location link.', '请先保存 REAPER 工程，再生成定位链接。'],
  SAVE_NOTE: ['Save this note first, or use an absolute file path.', '请先保存笔记，或使用绝对文件路径。'],
  RELATIVE_ROOT: ['Different drives/shares require an absolute path. Disable the relative-path option.', '跨磁盘或共享目录请使用绝对路径，取消相对路径选项即可。'],
  NO_SELECTION: ['There is no non-empty time selection.', '当前没有有效的时间选区。'],
  NO_TARGET: ['No matching selected object, marker or region was found.', '没有有效的选中对象、Marker 或 Region。'],
  TARGET_MISSING: ['The linked object no longer matches or has been deleted. Edit or reinsert the link.', '目标对象已删除或不再匹配，请编辑或重新插入链接。'],
  PROJECT_MISSING: ['The project file was moved or cannot be found. Correct the link.', '找不到所属工程，文件可能已移动或另存，请修正链接。'],
  PROJECT_AMBIGUOUS: ['This project path is open in multiple tabs. Close duplicate tabs first.', '同一工程路径在多个标签页中打开，请先关闭重复标签页。'],
  FILE_MISSING: ['The local file or folder does not exist.', '本地文件或文件夹不存在。'],
  SWS_REQUIRED: ['Install SWS to open local files/folders with the system default application.', '使用系统关联程序打开文件或文件夹需要安装 SWS 扩展。'],
  OPEN_FAILED: ['Could not open the target. Check permissions and the system file association.', '无法打开目标，请检查权限及系统文件关联。'],
  NOTE_CHANGED: ['The note/editor changed. Reopen Quick links and try again.', '笔记或编辑位置已变化，请重新打开“快捷链接”。'],
  TIMEOUT: ['REAPER did not reply. The operation was not retried; check its state before clicking again.', 'REAPER 未及时响应，未自动重试；再次点击前请检查操作是否已完成。'],
  CLOSED: ['The note was closed.', '笔记已关闭。'],
  failed: ['The operation failed.', '操作失败。'],
};
function translator(language) {
  const index = /^zh/i.test(language?.() || document.documentElement.lang) ? 1 : 0;
  return key => (words[key] || words.failed)[index];
}
export const linkMenuLabel = () => translator()('menu');
export const linkMenuIcon = 'M14 3V5H17.59L7.76 14.83L9.17 16.24L19 6.41V10H21V3M19 19H5V5H12V3H5C3.89 3 3 3.9 3 5V19A2 2 0 0 0 5 21H19A2 2 0 0 0 21 19V12H19V19Z';
const element = (tag, text, attrs = {}) => {
  const node = document.createElement(tag);
  if (text) node.textContent = text;
  for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value);
  return node;
};

export function insertEditorLinks(editor, links) {
  if (editor.isMarkdownMode()) {
    editor.replaceSelection(links.map(link => markdownLink(link.label, link.href)).join('\n'));
  } else {
    // Use the editor's link command, not raw HTML or a whole-document rewrite.
    editor.replaceSelection('');
    links.forEach((link, index) => {
      if (index) editor.insertText('\n');
      editor.exec('addLink', {linkText: link.label, linkUrl: link.href});
    });
  }
}

export function installNoteLinks({element: hostElement, editor, host, getContext, language, notify, runTask}) {
  const t = translator(language);
  const client = createLinkClient(host);
  let disposed = false, dialog, executing = false, closeDialog;
  const report = error => {
    if (disposed || error?.code === 'LINK_CLOSED') return;
    const code = (error?.code || '').replace(/^LINK_/, '');
    notify?.(t(words[code] ? code : 'failed') + (words[code] ? '' : ` (${error?.code || 'UNKNOWN'})`));
  };
  function dismiss() {closeDialog?.();}
  function makeDialog(title) {
    dismiss();
    const previous = document.activeElement;
    dialog = element('dialog', '', {class: 'reafolio-link-dialog', 'data-reafolio-modal': '', 'aria-label': title, 'data-reaweb-no-drag': ''});
    const header = element('div', '', {class: 'reafolio-link-header'});
    const close = element('button', '×', {type: 'button', class: 'reafolio-link-close', 'aria-label': t('close'), title: t('close')});
    close.onclick = dismiss;
    header.append(element('h2', title), close); dialog.append(header);
    document.body.append(dialog);
    const current = dialog;
    let onDismiss;
    closeDialog = () => {
      if (!current.isConnected) return;
      current.close(); current.remove(); if (dialog === current) dialog = null;
      previous?.focus?.(); onDismiss?.();
    };
    current.addEventListener('cancel', event => {event.preventDefault(); closeDialog();});
    current.addEventListener('click', event => {
      const rect = current.getBoundingClientRect();
      if (event.target === current && (event.clientX < rect.left || event.clientX > rect.right ||
          event.clientY < rect.top || event.clientY > rect.bottom)) closeDialog();
    });
    return {node: current, show: () => current.showModal(), onDismiss: callback => {onDismiss = callback;}};
  }
  function confirmOpen(project) {
    return new Promise(resolve => {
      const modal = makeDialog(t('open'));
      modal.node.append(element('p', t('unopened')), element('p', project, {class: 'reafolio-link-path'}));
      const cancel = element('button', t('cancel'), {type: 'button'});
      const open = element('button', t('open'), {type: 'button', class: 'reafolio-link-primary'});
      const controls = element('div', '', {class: 'reafolio-link-controls'}); controls.append(cancel, open); modal.node.append(controls);
      modal.onDismiss(() => resolve(false));
      cancel.onclick = dismiss;
      open.onclick = () => {resolve(true); dismiss();};
      modal.show(); cancel.focus();
    });
  }
  const removeClick = listenForIntegrationLinks(hostElement, {
    editor, getContext, report,
    async activate(href, context) {
      if (disposed || executing) return;
      executing = true;
      try {await activateIntegrationLink(href, {host, client, context, confirmOpen});}
      finally {executing = false;}
    },
  });

  function showMenu() {
    if (disposed || dialog) return;
    const context = {...getContext()};
    const mode = editor.isMarkdownMode();
    const selection = editor.getSelection();
    const originalDoc = editor.getCurrentModeEditor().view.state.doc;
    const modal = makeDialog(t('menu'));
    const form = element('form'); form.method = 'dialog';
    const field = (caption, input) => {const label = element('label', caption); label.append(input); form.append(label);};
    const kind = element('select', '', {'aria-label': t('kind')});
    for (const value of ['file', 'folder', 'project', 'action', 'time', 'track', 'item', 'marker', 'region', 'selection']) {
      kind.append(element('option', t(value), {value}));
    }
    field(t('kind'), kind);
    const label = element('input', '', {type: 'text', 'aria-label': t('label'), maxlength: '500'});
    field(t('label'), label);
    const details = element('div', '', {class: 'reafolio-link-details'});
    const hint = element('p', t('hint'), {class: 'reafolio-link-hint'});
    const error = element('p', '', {role: 'alert', class: 'reafolio-link-error'});
    const controls = element('div', '', {class: 'reafolio-link-controls'});
    const cancel = element('button', t('cancel'), {type: 'button'});
    const submit = element('button', t('insert'), {type: 'submit', class: 'reafolio-link-primary'});
    controls.append(cancel, submit); form.append(details, hint, error, controls); modal.node.append(form);
    let path, relative, command, choices, entries = [], generation = 0, busy = false;
    const active = () => !disposed && modal.node.isConnected;
    const showError = problem => {error.textContent = t((problem?.code || '').replace(/^LINK_/, '')) + (problem?.code ? '' : ' ' + String(problem));};
    cancel.onclick = dismiss;
    async function refresh() {
      const current = ++generation;
      details.replaceChildren(); error.textContent = ''; entries = []; path = null;
      submit.disabled = false;
      if (['file', 'folder', 'project'].includes(kind.value)) {
        const browse = element('button', t('choose'), {type: 'button', class: 'reafolio-link-browse'});
        const pathText = element('p', t('noPath'), {class: 'reafolio-link-path', 'aria-live': 'polite'});
        const pathRow = element('div', '', {class: 'reafolio-link-target'}); pathRow.append(pathText, browse);
        relative = element('input', '', {type: 'checkbox'});
        relative.checked = Boolean(context.filename); relative.disabled = !context.filename;
        const relativeLabel = element('label', t('relative'), {class: 'reafolio-link-checkbox'}); relativeLabel.prepend(relative);
        details.append(pathRow, relativeLabel);
        browse.onclick = async () => {
          browse.disabled = true;
          try {
            const options = {title: t(kind.value), initialPath: context.root || ''};
            if (kind.value === 'project') options.filters = [{name: 'REAPER project', extensions: ['rpp']}];
            const chosen = await (kind.value === 'folder' ? host.dialog.selectFolder(options) : host.dialog.openFile(options));
            if (active() && current === generation && chosen) {path = chosen; pathText.textContent = chosen;}
          } catch (problem) {if (active()) showError(problem);}
          finally {browse.disabled = false;}
        };
      } else if (kind.value === 'action') {
        command = element('input', '', {type: 'text', placeholder: t('command'), 'aria-label': t('command'), maxlength: '256'});
        details.append(command, element('p', t('actionHint'), {class: 'reafolio-link-hint'}));
      } else if (kind.value === 'marker' || kind.value === 'region') {
        choices = element('select', '', {'aria-label': t(kind.value)}); details.append(choices); submit.disabled = true;
        try {
          const result = await client.request({operation: 'capture', kind: kind.value});
          if (!active() || current !== generation) return;
          entries = result.links;
          choices.append(element('option', t('choose'), {value: ''}));
          entries.forEach((entry, index) => choices.append(element('option', entry.label, {value: String(index)})));
          choices.onchange = () => {submit.disabled = choices.value === '';};
        } catch (problem) {if (active() && current === generation) showError(problem);}
      } else if (kind.value === 'track' || kind.value === 'item') details.append(element('p', t('multi'), {class: 'reafolio-link-hint'}));
    }
    kind.onchange = refresh;
    form.onsubmit = event => {
      event.preventDefault(); if (busy) return;
      busy = true; submit.disabled = true;
      const task = async ({isActive = () => true} = {}) => {
        try {
          let links;
          if (['file', 'folder', 'project'].includes(kind.value)) {
            if (!path) throw linkError('NO_TARGET');
            const stat = await host.fs.stat(path);
            if (!stat.exists) throw linkError('FILE_MISSING');
            if (kind.value === 'project' && !/\.rpp$/i.test(path)) throw linkError('INVALID');
            links = [{label: label.value.trim() || path.replace(/[\\/]+$/, '').split(/[\\/]/).at(-1), href: localFileHref(path, context, relative.checked)}];
          } else {
            let captured;
            if (kind.value === 'marker' || kind.value === 'region') {
              if (choices.value === '' || !entries[Number(choices.value)]) throw linkError('NO_TARGET');
              captured = [entries[Number(choices.value)]];
            } else captured = (await client.request({operation: 'capture', kind: kind.value,
              ...(kind.value === 'action' ? {command: command.value.trim(), section: 'main'} : {})})).links;
            links = captured.map(entry => ({label: label.value.trim() ? (captured.length > 1 ? label.value.trim() + ' — ' + entry.label : label.value.trim()) : entry.label,
              href: integrationHref(entry.target)}));
          }
          if (!active() || !isActive()) return;
          const now = getContext();
          if (now.root !== context.root || now.filename !== context.filename ||
              editor.isMarkdownMode() !== mode || editor.getCurrentModeEditor().view.state.doc !== originalDoc) throw linkError('NOTE_CHANGED');
          editor.setSelection(...selection);
          insertEditorLinks(editor, links);
          dismiss(); editor.focus();
        } catch (problem) {if (active()) showError(problem);}
        finally {busy = false; submit.disabled = false;}
      };
      if (runTask) runTask(task); else void task();
    };
    void refresh(); modal.show(); kind.focus();
  }
  // The existing note action bar owns the button; do not alter the editor's
  // toolbar renderer or its asynchronous resize/destruction lifecycle.
  const dispose = () => {disposed = true; dismiss(); removeClick(); client.dispose();};
  dispose.openMenu = showMenu;
  return dispose;
}
