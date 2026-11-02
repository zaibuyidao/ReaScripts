// Capture Ctrl/Cmd+Enter before the editor handles Enter; Ctrl+S remains strikethrough.
export function handleSaveShortcut(event, save) {
  if (event.isComposing || event.altKey || !(event.ctrlKey || event.metaKey) ||
      event.key !== 'Enter') return;
  event.preventDefault();
  event.stopImmediatePropagation();
  if (!event.repeat) save();
}

export function installMarkdownDrop({
  target = window, getWorkspace, workspaceState, editorState, toast, translate, formatError,
}) {
  const notify = (severity, detail) => toast.add({severity, detail, life: 5000});
  const isMarkdown = file => /\.md$/i.test(file.name);

  function dragover(event) {
    if (!Array.from(event.dataTransfer?.types || []).includes('Files')) return;
    event.preventDefault();
    event.dataTransfer.dropEffect = 'copy';
  }

  async function importFiles(files) {
    if (!workspaceState.initialized || !workspaceState.root) {
      notify('error', translate('noWorkspace'));
      return;
    }
    if (workspaceState.busy || editorState.busy) {
      notify('warn', translate('error_BUSY'));
      return;
    }
    workspaceState.busy = true;
    let imported = 0;
    try {
      const workspace = getWorkspace();
      for (const file of files) {
        try {
          // Match the repository's text limit before reading a potentially large file.
          if (file.size > 16777213) throw Object.assign(new Error(), {code: 'BUFFER_LIMIT'});
          const content = await file.text();
          // A new-note save checks for existing names and never overwrites them.
          await workspace.save(file.name.slice(0, -3), content);
          imported++;
        } catch (error) {
          notify('error', file.name + ': ' + formatError(error));
        }
      }
      if (imported) notify('success', translate('notesImported').replace('{count}', imported));
    } catch (error) {
      notify('error', formatError(error));
    } finally {
      workspaceState.busy = false;
    }
  }

  function drop(event) {
    const files = Array.from(event.dataTransfer?.files || []);
    if (!files.length) return;
    const markdown = files.filter(isMarkdown);
    // Leave image-only drops in the editor to its existing attachment handler.
    if (!markdown.length && event.target?.closest?.('.toast-editor-host')) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    if (markdown.length !== files.length) notify('warn', translate('dropMarkdownOnly'));
    if (markdown.length) void importFiles(markdown);
  }

  target.addEventListener('dragover', dragover, true);
  target.addEventListener('drop', drop, true);
  return () => {
    target.removeEventListener('dragover', dragover, true);
    target.removeEventListener('drop', drop, true);
  };
}
