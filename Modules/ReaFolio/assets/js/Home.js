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
  openNotesRoute,
} from './index.js';
import {t as LoadingIndicator} from './LoadingIndicator.js';
import {readHomeCache, writeHomeCache} from './HomeCache.js';

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
    const cacheView = () => JSON.stringify([defaultTerm(), defaultSort(), preferences.recentNotesLimit]);
    const cacheKey = () => workspaceState.scopeSelection?.homeCacheKey ?? workspaceState.homeCacheKey;
    const pending = () => !workspaceState.initialized || workspaceState.switching ||
      !!workspaceState.scopeSelection || workspaceState.indexing;
    let activeCacheKey = cacheKey();
    const ready = () => !pending() && !!workspaceState.root;

    function refresh() {
      if (activeCacheKey !== cacheKey()) {
        activeCacheKey = cacheKey();
        if (workspaceState.switching || workspaceState.scopeSelection) searchTerm.value = '';
      }
      const term = searchTerm.value.trim();
      if (store.config.quickAccessHide && !term) {
        notes.value = [];
        loadingIndicator.value?.setLoaded();
        return;
      }
      // Startup and scope switches share the same presentation-only snapshots.
      if (!ready()) {
        const cached = pending() && !term && readHomeCache(cacheKey(), cacheView());
        notes.value = cached || [];
        if (cached || !pending()) loadingIndicator.value?.setLoaded();
        else loadingIndicator.value?.setLoading();
        return;
      }
      try {
        notes.value = getNotes(
          term || defaultTerm(),
          term ? 'score' : defaultSort(),
          !term && defaultSort() === 'title' ? 'asc' : 'desc',
          term ? undefined : preferences.recentNotesLimit + 1,
        );
        if (!term) writeHomeCache(cacheKey(), cacheView(), notes.value);
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
      () => workspaceState.initialized,
      () => workspaceState.switching,
      () => workspaceState.scopeSelection,
      () => workspaceState.indexing,
      () => workspaceState.homeCacheKey,
      searchTerm,
      () => preferences.recentNotesLimit,
      () => preferences.homeFilter,
      () => preferences.homeSort,
      () => store.config.quickAccessHide,
      () => store.config.quickAccessTerm,
      () => store.config.quickAccessSort,
    ], refresh);
    onMounted(refresh);
    refresh();

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
            initialSearchTerm: searchTerm.value,
            navigateOnEnter: ready(),
            'onUpdate:searchTerm': value => {searchTerm.value = value;},
          }),
          h(LoadingIndicator, {
            ref: loadingIndicator,
            initialLoaded: notes.value.length > 0,
            class: 'home-recent flex min-h-0 flex-col items-center',
            hideLoader: '',
          }, {default: () => [
            notes.value.length ? h('p', {
              class: 'mb-2 max-w-full break-words text-xs font-bold uppercase text-theme-text-very-muted',
            }, heading) : null,
            ...visibleNotes.map(note => h(RouterLink, {
              key: note.title,
              to: {name: 'note', params: {title: note.title}},
              onClickCapture: event => openNotesRoute(event, {name: 'note', params: {title: note.title}}),
              class: 'mb-1',
            }, {default: () => [h(CustomButton, {label: note.title})]})),
            !searching && notes.value.length > preferences.recentNotesLimit ? h(RouterLink, {
              to: {name: 'search', query: {term: defaultTerm(), sortBy: searchSortOptions[defaultSort()]}},
              onClickCapture: event => openNotesRoute(event, {
                name: 'search', query: {term: defaultTerm(), sortBy: searchSortOptions[defaultSort()]},
              }),
              title: translate('showMore'),
            }, {default: () => [h(CustomButton, {iconPath: moreIcon})]}) : null,
          ]}),
        ]),
      ]);
    };
  },
};

export {Home as default};
