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

// Keep source spelling when the visual document has not changed. For actual
// edits, reuse unchanged source blocks only after checking the parsed result.
export function installMarkdownPreservation(editor, initialMarkdown = '') {
  const converter = editor.convertor;
  const toVisual = converter.toWysiwygModel.bind(converter);
  const toMarkdown = converter.toMarkdownText.bind(converter);
  const getMarkdown = editor.getMarkdown.bind(editor);
  const Parser = editor.toastMark.constructor;
  const normalize = text => text.replace(/\r\n?/g, '\n');
  const parse = text => new Parser(normalize(text), editor.toastMark.parser.options).getRootNode();
  let snapshot, cachedModel, cachedText;

  function blocks(text, root) {
    const offsets = [0];
    for (let i = 0; i < text.length; i++) if (text[i] === '\n') offsets.push(i + 1);
    const result = [];
    for (let node = root.firstChild; node; node = node.next) {
      if (!node.sourcepos) continue;
      const [[startLine, startColumn], [endLine, endColumn]] = node.sourcepos;
      const start = offsets[startLine - 1] + startColumn - 1;
      let end = Math.min(text.length, offsets[endLine - 1] + endColumn);
      if (!Number.isFinite(start) || !Number.isFinite(end) || end < start) continue;
      while (end > start && text[end - 1] === '\n') end--;
      const content = toVisual(node).toJSON().content || [];
      // The converter inserts an empty paragraph between adjacent paragraphs.
      if (node.type === 'paragraph' && node.prev?.type === 'paragraph' &&
          content[0]?.type === 'paragraph' && !content[0].content) content.shift();
      result.push({start, end, type: node.type, key: JSON.stringify(content), text: text.slice(start, end)});
    }
    return result;
  }

  function capture(source, model, root) {
    snapshot = {source, model, blocks: null};
    cachedModel = null;
  }

  function currentSource() {
    const text = editor.mdEditor.getMarkdown();
    return snapshot && normalize(snapshot.source) === text ? snapshot.source : text;
  }

  converter.toWysiwygModel = function(root) {
    const model = toVisual(root);
    if (root === editor.toastMark.getRootNode()) capture(currentSource(), model, root);
    return model;
  };

  function preserveUnchangedBlocks(generated) {
    const root = parse(generated);
    const expected = toVisual(root);
    if (!snapshot.blocks) {
      const source = normalize(snapshot.source);
      // Parse a separate tree: the editor mutates its own tree while typing.
      snapshot.blocks = blocks(source, parse(source));
    }
    const originals = new Map();
    for (const block of snapshot.blocks) {
      if (!originals.has(block.key)) originals.set(block.key, []);
      originals.get(block.key).push(block);
    }
    const generatedBlocks = blocks(generated, root);
    const sameStructure = generatedBlocks.length === snapshot.blocks.length &&
      generatedBlocks.every((block, index) => block.type === snapshot.blocks[index].type);
    const source = normalize(snapshot.source);
    let candidate = '', cursor = 0, previousOriginal;
    for (const [index, block] of generatedBlocks.entries()) {
      const original = originals.get(block.key)?.shift();
      let gap = generated.slice(cursor, block.start);
      if (sameStructure) {
        gap = source.slice(index ? snapshot.blocks[index - 1].end : 0, snapshot.blocks[index].start);
      } else if (original && previousOriginal &&
          snapshot.blocks.indexOf(original) === snapshot.blocks.indexOf(previousOriginal) + 1) {
        gap = source.slice(previousOriginal.end, original.start);
      }
      // Numbered headings are not list items. Only simplify newly serialized
      // headings; never touch intentional source escapes or code blocks.
      const serialized = block.type === 'heading'
        ? block.text.replace(/^(#{1,6}[ \t]+\d+)\\([.)])(?=[ \t])/gm, '$1$2') : block.text;
      candidate += gap + (original?.text ?? serialized);
      cursor = block.end;
      previousOriginal = original;
    }
    candidate += sameStructure && snapshot.blocks.length
      ? source.slice(snapshot.blocks.at(-1).end) : generated.slice(cursor);
    const trailing = normalize(snapshot.source).match(/\n*$/)[0];
    candidate = candidate.replace(/\n*$/, trailing);
    // Never remove a necessary escape or change list/table/code semantics.
    if (!toVisual(parse(candidate)).eq(expected)) return generated;
    return candidate;
  }

  function restorePosition(generated, result, mapped) {
    if (!Array.isArray(mapped) || !editor.isMarkdownMode()) return;
    const before = normalize(generated).split('\n');
    const after = normalize(result).split('\n');
    let line = Math.min(Math.max(mapped[0] - 1, 0), after.length - 1);
    let column = mapped[1] - 1;
    try {
      const sourceBlocks = blocks(normalize(result), parse(result));
      const destinations = new Map();
      for (const block of sourceBlocks) {
        if (!destinations.has(block.key)) destinations.set(block.key, []);
        destinations.get(block.key).push(block);
      }
      const offset = before.slice(0, mapped[0] - 1).reduce((n, text) => n + text.length + 1, 0) + column;
      for (const block of blocks(generated, parse(generated))) {
        const destination = destinations.get(block.key)?.shift();
        if (!destination || offset < block.start || offset > block.end) continue;
        const relativeLine = generated.slice(block.start, offset).split('\n').length - 1;
        const startLine = normalize(result).slice(0, destination.start).split('\n').length - 1;
        line = Math.min(startLine + relativeLine, after.length - 1);
        const oldLine = before[mapped[0] - 1] || '';
        const newLine = after[line];
        let prefix = 0, suffix = 0;
        while (prefix < Math.min(oldLine.length, newLine.length) && oldLine[prefix] === newLine[prefix]) prefix++;
        while (suffix < Math.min(oldLine.length, newLine.length) - prefix && oldLine.at(-suffix - 1) === newLine.at(-suffix - 1)) suffix++;
        if (column >= oldLine.length - suffix) column += newLine.length - oldLine.length;
        else if (column > prefix) column = Math.min(column, newLine.length - suffix);
        break;
      }
    } catch {
      // Clamp the selection if a plugin does not provide source positions.
    } finally {
      converter.setMappedPos([line + 1, Math.max(0, Math.min(column, after[line].length)) + 1]);
    }
  }

  converter.toMarkdownText = function(model) {
    // HTML pasted by WordPaste also uses this converter. Only preserve source
    // for the active document, never for a separately parsed paste fragment.
    if (!snapshot || model !== editor.wwEditor.getModel()) return toMarkdown(model);
    const generated = toMarkdown(model);
    const mapped = converter.getMappedPos();
    let result;
    try {
      if (model.eq(snapshot.model)) result = snapshot.source;
      else if (model === cachedModel) result = cachedText;
      else {
        result = preserveUnchangedBlocks(generated);
        if (snapshot.source.includes('\r\n')) result = result.replace(/\n/g, '\r\n');
      }
    } catch {
      // Unsupported custom syntax must not prevent saving or switching modes.
      result = generated;
    } finally {
      converter.setMappedPos(mapped);
    }
    restorePosition(generated, result, mapped);
    if (editor.isMarkdownMode()) capture(result, model);
    cachedModel = model;
    cachedText = result;
    return result;
  };

  editor.getMarkdown = function() {
    return editor.isMarkdownMode() ? currentSource() : getMarkdown();
  };

  const root = editor.toastMark.getRootNode();
  const source = normalize(initialMarkdown) === editor.mdEditor.getMarkdown()
    ? initialMarkdown : editor.mdEditor.getMarkdown();
  const mapped = converter.getMappedPos();
  capture(source, toVisual(root), root);
  converter.setMappedPos(mapped);
}
