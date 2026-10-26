import {
  At as onMounted,
  Bt as watch,
  Qt as ref,
  T as useToast,
  g as translate,
  n as searchSortOptions,
  u as workspaceState,
  yt as h,
} from './constants.js';
import {
  _ as RouterLink,
  a as apiErrorHandler,
  c as Logo,
  d as moreIcon,
  i as SearchInput,
  l as CustomButton,
  n as useGlobalStore,
  o as getNotes,
  r as preferences,
} from './index.js';
import {t as LoadingIndicator} from './LoadingIndicator.js';

const Home = {
  __name: 'Home',
  setup() {
    const store = useGlobalStore();
    const loadingIndicator = ref();
    const notes = ref([]);
    const searchTerm = ref('');
    const toast = useToast();
    const defaultTerm = () => preferences.homeFilter || store.config.quickAccessTerm || '*';
    const defaultSort = () => preferences.homeSort || store.config.quickAccessSort || 'lastModified';

    function refresh() {
      const term = searchTerm.value.trim();
      if (store.config.quickAccessHide && !term) {
        notes.value = [];
        loadingIndicator.value?.setLoaded();
        return;
      }
      try {
        notes.value = getNotes(
          term || defaultTerm(),
          term ? 'score' : defaultSort(),
          !term && defaultSort() === 'title' ? 'asc' : 'desc',
          term ? undefined : preferences.recentNotesLimit + 1,
        );
        if ((term || preferences.homeFilter) && !notes.value.length) {
          loadingIndicator.value?.setFailed(translate('noResults'));
        } else {
          loadingIndicator.value?.setLoaded();
        }
      } catch (error) {
        loadingIndicator.value?.setFailed();
        apiErrorHandler(error, toast);
      }
    }

    watch([
      () => workspaceState.revision,
      searchTerm,
      () => preferences.recentNotesLimit,
      () => preferences.homeFilter,
      () => preferences.homeSort,
      () => store.config.quickAccessHide,
      () => store.config.quickAccessTerm,
      () => store.config.quickAccessSort,
    ], refresh);
    onMounted(refresh);

    return () => {
      const searching = !!searchTerm.value.trim();
      const heading = searching ? translate('search') : preferences.homeFilter
        ? translate('homeFilteredNotes') + ': ' + preferences.homeFilter
        : translate(defaultSort() === 'lastModified' ? 'recent' : 'allNotes');
      const visibleNotes = searching ? notes.value : notes.value.slice(0, preferences.recentNotesLimit);
      return h('div', {class: 'home-page flex h-full justify-center'}, [
        h('div', {class: 'flex w-full max-w-[500px] flex-1 flex-col items-center pt-[25vh]'}, [
          h(Logo, {class: 'mb-5'}),
          h(SearchInput, {
            class: 'mb-5 shadow-[0_0_20px] shadow-theme-shadow',
            'onUpdate:searchTerm': value => {searchTerm.value = value;},
          }),
          h(LoadingIndicator, {
            ref: loadingIndicator,
            class: 'home-recent flex min-h-0 flex-col items-center',
            hideLoader: '',
          }, {default: () => [
            notes.value.length ? h('p', {
              class: 'mb-2 max-w-full break-words text-xs font-bold uppercase text-theme-text-very-muted',
            }, heading) : null,
            ...visibleNotes.map(note => h(RouterLink, {
              key: note.title,
              to: {name: 'note', params: {title: note.title}},
              class: 'mb-1',
            }, {default: () => [h(CustomButton, {label: note.title})]})),
            !searching && notes.value.length > preferences.recentNotesLimit ? h(RouterLink, {
              to: {name: 'search', query: {term: defaultTerm(), sortBy: searchSortOptions[defaultSort()]}},
              title: translate('showMore'),
            }, {default: () => [h(CustomButton, {iconPath: moreIcon})]}) : null,
          ]}),
        ]),
      ]);
    };
  },
};

export {Home as default};
