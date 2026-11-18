// ReaWebAPI keeps the entry document fixed. Select a view, then reload that entry.
const VIEW_KEY = 'ReaEmulator.activeView.v1';
const ROUTE_KEY = 'ReaEmulator.rommRoute.v1';

export function setPlayerView(view) {
  if (view) sessionStorage.setItem(VIEW_KEY, JSON.stringify(view));
  else sessionStorage.removeItem(VIEW_KEY);
}

export function currentView() {
  try {
    const view = JSON.parse(sessionStorage.getItem(VIEW_KEY));
    return view?.type === 'player' && (view.gameId === undefined || typeof view.gameId === 'string') ? view : null;
  } catch { return null; }
}

export async function reloadView(view) {
  const previous = sessionStorage.getItem(VIEW_KEY);
  const target = view ? null : currentView()?.returnRoute;
  const restoreRoute = typeof target === 'string' && /^\/rom\/\d+$/.test(target);
  const previousRoute = restoreRoute ? sessionStorage.getItem(ROUTE_KEY) : null;
  const previousUrl = restoreRoute ? location.href : null;
  setPlayerView(view);
  try {
    if (restoreRoute) {
      sessionStorage.setItem(ROUTE_KEY, target);
      history.replaceState(history.state, '', '#' + target);
    }
    const accepted = await reaper.window.reload();
    if (accepted === false) throw new Error('宿主未接受启动请求，请重新打开应用后重试。');
  } catch (error) {
    if (previous === null) sessionStorage.removeItem(VIEW_KEY);
    else sessionStorage.setItem(VIEW_KEY, previous);
    if (restoreRoute) {
      if (previousRoute === null) sessionStorage.removeItem(ROUTE_KEY);
      else sessionStorage.setItem(ROUTE_KEY, previousRoute);
      history.replaceState(history.state, '', previousUrl);
    }
    throw error;
  }
}
