import {g as translate, yt as h} from './constants.js';

const general = [
  ['save', ['Ctrl+Enter', 'Ctrl+S']],
  ['newNote', ['Ctrl+N']],
  ['shortcutSearch', ['/']],
  ['options', ['Ctrl+,']],
  ['shortcutHome', ['Ctrl+Alt+H']],
  ['shortcutEdit', ['E']],
];

const markdown = [
  ['shortcutBold', ['Ctrl+B']],
  ['shortcutItalic', ['Ctrl+I']],
  ['shortcutInlineCode', ['Ctrl+Shift+C']],
  ['shortcutCodeBlock', ['Ctrl+Shift+P']],
  ['shortcutBulletList', ['Ctrl+U']],
  ['shortcutOrderedList', ['Ctrl+O']],
  ['shortcutTaskList', ['Alt+T']],
  ['shortcutToggleTask', ['Ctrl+Shift+X']],
  ['shortcutQuote', ['Alt+Q']],
  ['shortcutRule', ['Ctrl+L']],
  ['shortcutIndent', ['Tab', 'Shift+Tab']],
  ['shortcutDeleteLine', ['Ctrl+D']],
  ['shortcutMoveLine', ['Alt+↑', 'Alt+↓']],
  ['shortcutUndoRedo', ['Ctrl+Z', 'Ctrl+Shift+Z']],
];

function section(title, rows) {
  return h('section', {class: 'shortcuts-section'}, [
    h('h2', null, translate(title)),
    h('table', {class: 'shortcuts-table', 'aria-label': translate(title)}, [
      h('tbody', null, rows.map(([label, keys]) => h('tr', {key: label}, [
        h('th', {scope: 'row'}, translate(label)),
        h('td', null, [h('div', {class: 'shortcuts-keys'}, keys.flatMap((key, index) => [
          index ? h('span', {class: 'shortcuts-key-separator', 'aria-hidden': 'true'}, '/') : null,
          h('kbd', null, key),
        ]))]),
      ]))),
    ]),
  ]);
}

export default {
  __name: 'Shortcuts',
  setup() {
    return () => h('article', {class: 'shortcuts-page', 'data-reaweb-no-drag': ''}, [
      h('h1', {class: 'shortcuts-title'}, translate('shortcuts')),
      section('shortcutsGeneral', general),
      section('shortcutsMarkdown', markdown),
    ]);
  },
};
