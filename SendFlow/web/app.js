"use strict";
(() => {
  const $ = id => document.getElementById(id);
  const tracks = new Map(), sends = new Map(), pending = new Map(), staged = new Map();
  const sendModeEdits = new Map();
  const canonicalSendMode = value => value === 2 ? 3 : value;
  const validSendMode = value => [0, 3, 1, 8].includes(value);
  let routingInfo = new Map(), language = "en", docked = false, lastChangeCount = 0;
  try { language = SendFlowLocale(localStorage.getItem("sendflow.language")); } catch (_) {}
  const tr = (key, values = {}) => SendFlowTranslate(language, key, values);
  let levelFormat = new Intl.NumberFormat(language, {minimumFractionDigits:1, maximumFractionDigits:1, useGrouping:false});
  function errorText(message) {
    const aliases = {"State changed; wait for the next state update":"stale", "Stale project/routing context; refresh and retry":"stale"};
    const key = aliases[message] || Object.keys(SendFlowI18n.en).find(key => SendFlowI18n.en[key] === message);
    return key ? tr(key) : message;
  }
  const trackElements = new Map(), nodeElements = new Map(), edgeElements = new Map(), edgeHitElements = new Map(), positions = new Map();
  const collapsedFolders = new Set(), movedNodes = new Set();
  const receiverLayouts = new Map();
  let activeReceiverLayout = null;
  const draftReceivers = new Map();
  const receiverTargets = new Map();
  let receiverCategory = "send";
  const receiverCategoryLabel = category => tr({outgoing:"sendTracks", send:"receiveSend", sidechain:"sidechain", muted:"muted", parent:"parentCategory"}[category]);
  const isSendView = () => filter === "receive" && receiverCategory === "outgoing";
  let draftSerial = 0, sourceMenu = null, connectionOperation = null;
  const displayTrack = id => tracks.get(id) || draftReceivers.get(id);
  const isReceiver = id => !!displayTrack(id) && ((routingInfo.get(id)?.receiveCount || 0) > 0 || draftReceivers.has(id));
  let receiverTarget = "";
  let allFocusLayoutKey = "", allCanvasTarget = "", selectionAnchor = "", batchOperation = null;
  const selectedTracks = new Set();
  let draggingTracks = [];
  let allCanvasChain = SendFlowRouting.focusedChain(tracks, routingInfo, "");
  let receiverChain = SendFlowRouting.receiveChain(tracks, routingInfo, "");
  const receiverLayoutId = (category, target) => JSON.stringify([category, target]);
  function receiverLayout() {
    // Each category overview and sidebar focus owns its layout for this project session.
    const key = receiverLayoutId(receiverCategory, receiverTarget);
    if (!receiverLayouts.has(key)) receiverLayouts.set(key, {category:receiverCategory, target:receiverTarget,
      positions:new Map(), movedNodes:new Set(), signature:"", pan:null});
    return receiverLayouts.get(key);
  }
  const graphPositions = () => filter === "receive" ? receiverLayout().positions : positions;
  const demo = new URLSearchParams(location.search).get("demo") === "1";
  let project = "", epoch = 0, requestId = 0, selected = "", filter = "all", mode = "matrix";
  let frame = 0, flushTimer = 0, toastTimer = 0, matrixHover = null, activeControl = "";
  let receivedState = false, demoState;
  const transport = window.chrome?.webview ? data => window.chrome.webview.postMessage(data)
    : window.webkit?.messageHandlers?.sendflow ? data => window.webkit.messageHandlers.sendflow.postMessage(data)
    : null;
  function renderStatus() {
    $("connection").textContent = tr(demo ? "demo" : receivedState ? "connected" : transport ? "connecting" : "preview");
    $("route-summary").textContent = receivedState ? tr("summary", {tracks: tracks.size, sends: sends.size, sc: [...sends.values()].filter(isSC).length}) : tr("waiting");
    $("state-label").textContent = receivedState ? `${tr(demo ? "demo" : "sync")} / ${lastChangeCount} · ${tr("stateRevision", {n:epoch})}` : tr("native");
    $("view-hint").textContent = tr(isSendView() ? "sendHint" : filter === "receive" ? "receiveHint" : mode === "matrix" ? "matrixHint" : "graphHint");
    $("dock-toggle").textContent = tr(docked ? "undock" : "dock");
    $("dock-toggle").title = tr(docked ? "undockTip" : "dockTip");
    $("dock-toggle").setAttribute("aria-pressed", String(docked));
  }
  function setLanguage(value) {
    language = SendFlowLocale(value);
    levelFormat = new Intl.NumberFormat(language, {minimumFractionDigits:1, maximumFractionDigits:1, useGrouping:false});
    try { localStorage.setItem("sendflow.language", language); } catch (_) {}
    document.documentElement.lang = language; document.title = `${tr("appName")} · ${tr("workspace")}`; $("language").value = language;
    for (const element of document.querySelectorAll("[data-i18n]")) element.textContent = tr(element.dataset.i18n);
    for (const attr of ["title", "aria-label", "placeholder"]) for (const element of document.querySelectorAll(`[data-i18n-${attr}]`)) element.setAttribute(attr, tr(element.getAttribute(`data-i18n-${attr}`)));
    if (!transport && !demo) {
      $("empty-state").querySelector("h2").textContent = tr("previewTitle");
      $("empty-state").querySelector("p").textContent = tr("previewBody");
    }
    renderStatus(); renderTracks(); renderInspector(); renderGraph(); scheduleDraw();
    if (sourceMenu) renderSourceOptions();
    matrixHover = null; $("matrix-tooltip").hidden = true;
  }
  function notify(text, error = false) {
    $("toast").textContent = text; $("toast").classList.toggle("error", error); $("toast").hidden = false;
    clearTimeout(toastTimer); toastTimer = setTimeout(() => { $("toast").hidden = true; }, 4200);
  }
  function request(action, args = {}, context = null) {
    const id = ++requestId;
    const command = {id, action, ...(context || (project ? {project, epoch} : {})), ...args};
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => { pending.delete(id); reject(new Error(tr("timeout"))); }, 8000);
      pending.set(id, {resolve, reject, timeout});
      try {
        if (demo) demoCommand(command);
        else if (transport) transport(command);
        else throw new Error(tr("browserOnly"));
      } catch (error) { clearTimeout(timeout); pending.delete(id); reject(error); }
    });
  }
  async function perform(action, args = {}, context = null) {
    try { return await request(action, args, context); }
    catch (error) { notify(errorText(error.message), true); return null; }
  }
  window.SendFlowReceive = data => {
    try {
      const message = typeof data === "string" ? JSON.parse(data) : data;
      if (message.type === "result") {
        const promise = pending.get(message.id);
        if (promise) {
          clearTimeout(promise.timeout); pending.delete(message.id);
          if (message.ok) promise.resolve(message.result);
          else promise.reject(new Error(message.error));
        }
      } else if (message.type === "state") applyState(message);
      else if (message.type === "window_state") {
        docked = message.docked; $("dock-toggle").hidden = false;
        setLanguage(message.language);
      } else if (message.type === "error") notify(errorText(message.error), true);
    } catch (error) { notify(tr("messageError", {error: error.message}), true); }
  };
  window.chrome?.webview?.addEventListener("message", event => window.SendFlowReceive(event.data));

  const orderedTracks = () => [...tracks.values()].sort((a,b) => a.index - b.index);
  const isSC = SendFlowRouting.isSC;
  function kind(track) {
    if (/reverb|delay|echo|\bfx\b|混响|延迟/i.test(track.name)) return "FX";
    if (routingInfo.get(track.id)?.bus) return "BUS";
    return "TRACK";
  }
  function visibleTracks() {
    if (filter === "receive") return [...orderedTracks(), ...draftReceivers.values()].filter(t => receiverChain.trackIds.has(t.id))
      .sort((a,b) => receiverChain.distance.get(a.id) - receiverChain.distance.get(b.id) || a.index - b.index);
    const list = [...orderedTracks(), ...draftReceivers.values()];
    if (allCanvasTarget) return list.filter(t => allCanvasChain.trackIds.has(t.id));
    return SendFlowRouting.visibleHierarchy(list.filter(t => routingInfo.get(t.id)?.sendCount || routingInfo.get(t.id)?.receiveCount), routingInfo, collapsedFolders, false);
  }
  function sidebarTracks() {
    const query = $("search").value.trim().toLocaleLowerCase();
    return foldTracks([...orderedTracks(), ...draftReceivers.values()].filter(t => !query || t.name.toLocaleLowerCase().includes(query)));
  }
  function refreshAllCanvas() {
    if (!displayTrack(allCanvasTarget)) allCanvasTarget = "";
    allCanvasChain = SendFlowRouting.focusedChain(tracks, routingInfo, allCanvasTarget);
    if (draftReceivers.has(allCanvasTarget)) allCanvasChain.trackIds.add(allCanvasTarget);
  }
  const canvasSend = id => filter !== "all" || !allCanvasTarget || allCanvasChain.sendIds.has(id);
  const canvasParent = id => filter !== "all" || !allCanvasTarget || allCanvasChain.parentIds.has(id);
  function focusAllTrack(id) {
    allCanvasTarget = id; allFocusLayoutKey = ""; refreshAllCanvas();
    $("matrix-scroll").scrollTo(0, 0);
  }
  function foldTracks(list) {
    return SendFlowRouting.visibleHierarchy(list, routingInfo, collapsedFolders, !!$("search").value.trim());
  }
  function folderCollapsed(id) { return filter !== "receive" && collapsedFolders.has(id) && !$("search").value.trim(); }
  function folderTip(t) {
    if (filter === "receive") return tr(isSendView() ? "sendExpanded" : "chainExpanded");
    return $("search").value.trim() ? tr("searchExpanded") : tr(folderCollapsed(t.id) ? "expandFolder" : "collapseFolder", {name: t.name, n: routingInfo.get(t.id).descendants});
  }
  function toggleFolder(id) {
    if (!tracks.get(id)?.folder || $("search").value.trim() || filter === "receive") return;
    if (collapsedFolders.has(id)) collapsedFolders.delete(id); else collapsedFolders.add(id);
    // Compact automatic positions, preserving nodes the user has placed by hand.
    for (const key of positions.keys()) if (!movedNodes.has(key)) positions.delete(key);
    matrixHover = null; $("matrix-tooltip").hidden = true;
    renderTracks(); resizeMatrix(); renderGraph();
  }
  function setReceiverTarget(id) {
    if (id) receiverTargets.set(filter === "receive" ? receiverCategory : "all", id);
    if (receiverTarget === id) return;
    closeSourceMenu();
    receiverTarget = id;
    if (filter === "receive") { $("track-list").scrollTo(0, 0); $("matrix-scroll").scrollTo(0, 0); }
  }
  function receiverInCategory(id, category = receiverCategory) {
    const info = routingInfo.get(id);
    if (category === "outgoing") return (info?.sends.length || 0) > 0;
    return (info?.receiveCategories[category] || 0) > 0 || (category === "send" && draftReceivers.has(id));
  }
  function receiverChoices(searching = true) {
    const query = $("search").value.trim().toLocaleLowerCase();
    return [...orderedTracks(), ...draftReceivers.values()].filter(t => receiverInCategory(t.id))
      .filter(t => !searching || !query || t.name.toLocaleLowerCase().includes(query) || String(t.index) === query);
  }
  const receiverRoots = () => receiverTarget ? [receiverTarget] : receiverChoices(false).map(t => t.id);
  function setReceiverCategory(category) {
    flushControls(); closeSourceMenu();
    filter = "receive"; receiverCategory = category;
    // Every category click returns to its overview; only a sidebar track click focuses a chain.
    setReceiverTarget(""); selected = ""; activeControl = "";
    $("matrix-scroll").scrollTo(0, 0);
    $("track-list").scrollTo(0, 0); matrixHover = null; $("matrix-tooltip").hidden = true;
    renderStatus(); renderTracks(); renderInspector(); resizeMatrix(); renderGraph();
  }
  function renderReceiverControl() {
    refreshAllCanvas();
    const enabled = filter === "receive";
    $("track-list").classList.toggle("receive-chain", enabled);
    for (const button of $("track-filters").children) {
      const active = button.dataset.filter === "all" ? !enabled : enabled && button.dataset.receiverFilter === receiverCategory;
      button.classList.toggle("active", active); button.setAttribute("aria-pressed", String(active));
    }
    document.querySelector(".sidebar > .section-head > span:first-child").textContent = tr(isSendView() ? "sendChain" : enabled ? "receiveChain" : "tracks");
    document.querySelector(".sidebar-foot small").textContent = tr(isSendView() ? "sendHint" : enabled ? "receiveHint" : "allReceiveHint");
    $("search").placeholder = tr("search");
    $("search").setAttribute("aria-label", $("search").placeholder);
    $("no-matches").textContent = isSendView() ? tr("noSenders") : enabled && !$("search").value.trim()
      ? tr("noCategoryReceivers", {category:receiverCategoryLabel(receiverCategory)}) : tr(enabled ? "noReceivers" : "noMatches");
    $("empty-state").hidden = enabled || tracks.size > 0 || draftReceivers.size > 0;
    if (enabled) {
      // Searching the sidebar never switches or hides the active editing canvas.
      if (receiverTarget && !receiverInCategory(receiverTarget)) setReceiverTarget("");
    } else {
      const previous = receiverTargets.get("all");
      const choices = allCanvasTarget ? visibleTracks() : [...orderedTracks(), ...draftReceivers.values()];
      const available = id => isReceiver(id) && choices.some(t => t.id === id);
      setReceiverTarget(available(previous) ? previous : available(receiverTarget) ? receiverTarget : choices.find(t => isReceiver(t.id))?.id || "");
    }
    const roots = enabled ? receiverRoots() : receiverTarget;
    receiverChain = isSendView() ? SendFlowRouting.sendChain(tracks, routingInfo, roots) : SendFlowRouting.receiveChain(new Map([...tracks, ...draftReceivers]), routingInfo, roots);
    refreshAllCanvas();
    if (!enabled) return;
    if (selected && !receiverChain.sendIds.has(selected)) { flushControls(); selected = ""; activeControl = ""; }
  }
  function chooseReceiver(id) {
    flushControls(); setReceiverTarget(id);
    if (filter === "all") { focusAllTrack(id); selectedTracks.clear(); selectedTracks.add(id); selectionAnchor = id; }
    if (filter === "all" && sends.get(selected)?.destination !== id) { selected = ""; activeControl = ""; }
    renderTracks(); renderInspector(); resizeMatrix(); renderGraph();
  }
  function chooseTrack(id, event = {}) {
    if (filter !== "all") { $("new-source").value = id; selectFirstSend(id); return; }
    const list = sidebarTracks().map(t => t.id), anchor = list.indexOf(selectionAnchor), current = list.indexOf(id);
    if (event.shiftKey && anchor >= 0 && current >= 0) {
      if (!event.ctrlKey && !event.metaKey) selectedTracks.clear();
      for (const track of list.slice(Math.min(anchor,current),Math.max(anchor,current)+1)) selectedTracks.add(track);
    } else {
      if (event.ctrlKey || event.metaKey) { if (selectedTracks.has(id)) selectedTracks.delete(id); else selectedTracks.add(id); }
      else { selectedTracks.clear(); selectedTracks.add(id); }
      selectionAnchor = id;
    }
    flushControls(); selected = ""; activeControl = ""; focusAllTrack(id);
    if (isReceiver(id)) setReceiverTarget(id);
    $("new-source").value = id;
    selectFirstSend(id);
    if (isReceiver(id)) setReceiverTarget(id);
    renderTracks(); renderInspector(); resizeMatrix(); renderGraph();
  }
  function renderReceiverList() {
    const choices = receiverChoices(), keep = new Set(choices.map(t => t.id));
    for (const [id, element] of trackElements) if (!keep.has(id) || !element.classList.contains("receiver-item")) { element.remove(); trackElements.delete(id); }
    $("track-count").textContent = String(choices.length);
    $("no-matches").hidden = choices.length > 0;
    let previous = null;
    for (const t of choices) {
      let element = trackElements.get(t.id);
      if (!element) {
        element = make("div", "track-item receiver-item"); element.dataset.track = t.id;
        const button = make("button", "track-select"); button.type = "button";
        button.append(make("span", "track-stripe"), make("span", "track-number"), make("span", "track-content"));
        button.children[2].append(make("span", "track-name"), make("span", "track-detail"));
        button.addEventListener("click", () => chooseReceiver(t.id));
        element.append(button); trackElements.set(t.id, element);
      }
      const button = element.firstChild, draft = draftReceivers.has(t.id);
      button.children[0].style.background = color(t);
      button.children[1].textContent = draft ? "+" : String(t.index).padStart(2,"0");
      button.children[2].children[0].textContent = t.name;
      const count = isSendView() ? routingInfo.get(t.id)?.sends.length || 0 : routingInfo.get(t.id)?.receiveCategories[receiverCategory] || 0;
      button.children[2].children[1].textContent = isSendView() ? tr("senderCount", {n:count}) : draft || !count ? tr("draftReceiver") : tr(receiverCategory === "send" ? "ordinaryReceiveCount" : "categoryReceiveCount", {category:receiverCategoryLabel(receiverCategory), n:count});
      element.classList.toggle("sender-item", isSendView());
      button.title = t.name; button.setAttribute("aria-pressed", String(t.id === receiverTarget));
      element.classList.toggle("receiver-target", t.id === receiverTarget);
      const expected = previous ? previous.nextSibling : $("track-list").firstChild;
      if (expected !== element) $("track-list").insertBefore(element, expected);
      previous = element;
    }
    renderAddReceiverButton();
  }
  function renderAddReceiverButton() {
    addReceiverButton.textContent = tr("addReceiver"); addReceiverButton.title = tr("addReceiver");
    if ($("track-list").lastChild !== addReceiverButton) $("track-list").append(addReceiverButton);
    addReceiverButton.hidden = false;
  }
  const color = track => /^#[0-9a-f]{6}$/i.test(track?.color) ? track.color : "#7f91a8";
  const db = value => value <= 0 ? -60 : Math.max(-60, Math.min(12, 20 * Math.log10(value)));
  const linear = value => value <= -60 ? 0 : Math.pow(10, value / 20);
  const gainText = value => value <= 0 ? "−∞ dB" : `${levelFormat.format(20 * Math.log10(value))} dB`;
  function applyState(message) {
    receivedState = true;
    const changedContext = project !== message.project || epoch !== message.epoch;
    if (changedContext) { staged.clear(); sendModeEdits.clear(); clearTimeout(flushTimer); flushTimer = 0; }
    const changedProject = project !== message.project;
    if (changedProject && connectionOperation) settleConnection(connectionOperation, null);
    if (changedProject) { for (const map of [nodeElements, edgeElements, edgeHitElements]) { for (const element of map.values()) element.remove(); map.clear(); } parentLayer.replaceChildren(); draftReceivers.clear(); receiverTargets.clear(); receiverCategory = "send"; connectionOperation = null; closeSourceMenu(); $("receiver-dialog").close(); setReceiverTarget(""); receiverLayouts.clear(); activeReceiverLayout = null; }
    if (message.full) { tracks.clear(); sends.clear(); }
    if (changedProject) { selected = ""; allCanvasTarget = ""; allFocusLayoutKey = ""; selectedTracks.clear(); selectionAnchor = ""; draggingTracks = []; batchOperation = null; positions.clear(); collapsedFolders.clear(); movedNodes.clear(); activeControl = ""; graphPan.x = graphPan.y = 0; graphPan.scale = 1; updateGraphPan(); $("matrix-scroll").scrollTo(0, 0); }
    project = message.project; epoch = message.epoch;
    for (const id of message.removed_tracks || []) tracks.delete(id);
    for (const id of message.removed_sends || []) sends.delete(id);
    for (const t of message.tracks || []) tracks.set(t.id, t);
    for (const s of message.sends || []) sends.set(s.id, s);
    routingInfo = SendFlowRouting.analyze(tracks, sends);
    for (const id of selectedTracks) if (!displayTrack(id)) selectedTracks.delete(id);
    finishConnection();
    for (const id of collapsedFolders) if (!tracks.get(id)?.folder) collapsedFolders.delete(id);
    for (const id of positions.keys()) if (!displayTrack(id)) { positions.delete(id); movedNodes.delete(id); }
    for (const [key, layout] of receiverLayouts) {
      if (layout.target && !displayTrack(layout.target)) { receiverLayouts.delete(key); continue; }
      for (const id of layout.positions.keys()) if (!displayTrack(id)) { layout.positions.delete(id); layout.movedNodes.delete(id); }
    }
    if (!sends.has(selected)) selected = "";
    lastChangeCount = message.change_count; renderStatus();
    $("empty-state").hidden = tracks.size > 0;
    renderTracks();
    if (message.full || message.tracks?.length || message.removed_tracks?.length) renderTrackSelects();
    renderInspector(); resizeMatrix(); renderGraph(); scheduleDraw();
    if (sourceMenu) renderSourceOptions();
  }
  function make(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined) element.textContent = text;
    return element;
  }
  function renderTracks() {
    renderReceiverControl();
    if (filter === "receive") { renderReceiverList(); return; }
    for (const [id, element] of trackElements) if (element.classList.contains("receiver-item")) { element.remove(); trackElements.delete(id); }
    const visible = sidebarTracks(); const keep = new Set(visible.map(t => t.id));
    const total = tracks.size + draftReceivers.size;
    $("track-count").textContent = visible.length === total ? total : `${visible.length} / ${total}`;
    $("no-matches").hidden = visible.length > 0 || tracks.size === 0;
    for (const [id, element] of trackElements) if (!keep.has(id)) { element.remove(); trackElements.delete(id); }
    let previous = null;
    for (const t of visible) {
      let element = trackElements.get(t.id);
      if (!element) {
        element = make("div", "track-item"); element.dataset.track = t.id;
        const toggle = make("button", "folder-toggle"); toggle.type = "button";
        toggle.addEventListener("click", () => toggleFolder(t.id));
        const select = make("button", "track-select"); select.type = "button"; select.draggable = !draftReceivers.has(t.id);
        const content = make("span", "track-content"); content.append(make("span", "track-name"), make("span", "track-detail"));
        select.append(make("span","track-stripe"), make("span","track-number"), make("span","track-icon"), content);
        element.append(make("span","track-guides"), toggle, select);
        select.addEventListener("click", event => chooseTrack(t.id, event));
        element.addEventListener("dragstart", event => {
          if (!tracks.has(t.id) || batchOperation || connectionOperation) { event.preventDefault(); return; }
          if (!selectedTracks.has(t.id)) { selectedTracks.clear(); selectedTracks.add(t.id); selectionAnchor = t.id; }
          draggingTracks = sidebarTracks().filter(track => selectedTracks.has(track.id)).map(track => track.id);
          event.dataTransfer.setData("text/plain", draggingTracks.join("\n")); event.dataTransfer.effectAllowed = "link";
          renderTracks();
        });
        element.addEventListener("dragend", clearTrackDrag);
        attachTrackDrop(element, t.id);
        trackElements.set(t.id, element);
      }
      const info = routingInfo.get(t.id) || {ancestors:[], depth:0, descendants:0}, ancestors = info.ancestors.map(id => tracks.get(id).name);
      const receiver = isReceiver(t.id), draft = draftReceivers.has(t.id), sender = info.sendCount > 0;

      const signature = JSON.stringify([t, info.depth, info.descendants, ancestors, receiver, sender, folderCollapsed(t.id), !!$("search").value.trim(), language]);
      if (element.dataset.signature !== signature) {
        element.dataset.signature = signature;
        element.style.setProperty("--depth", info.depth);
        element.children[0].style.width = `${(info.depth) * 14}px`;
        const toggle = element.children[1], select = element.children[2], content = select.children[3];
        toggle.style.visibility = t.folder ? "visible" : "hidden"; toggle.tabIndex = t.folder ? 0 : -1;
        toggle.disabled = !t.folder || !!$("search").value.trim();
        toggle.textContent = folderCollapsed(t.id) ? "▸" : "▾";
        if (t.folder) { toggle.setAttribute("aria-expanded", String(!folderCollapsed(t.id))); toggle.title = folderTip(t); toggle.setAttribute("aria-label", toggle.title); }
        else { toggle.removeAttribute("aria-expanded"); toggle.removeAttribute("aria-label"); toggle.title = ""; }
        select.children[0].style.background = color(t);
        select.children[1].textContent = draft ? "+" : String(t.index).padStart(2,"0");
        select.children[2].classList.toggle("folder-icon", t.folder);
        select.children[2].textContent = t.folder ? "" : "·";
        select.children[2].title = tr(t.folder ? "folder" : "track");
        content.children[0].textContent = t.name;
        const details = [];
        if (t.folder) details.push(folderCollapsed(t.id) ? tr("foldedTracks", {n: info.descendants}) : tr("folder"));
        if (kind(t) === "FX") details.push("FX");
        content.children[1].textContent = details.join(" · ");
        if (receiver) content.children[1].append(make("span", "receiver-role", tr(draft ? "draftReceiver" : "receiverTarget")));
        if (sender) content.children[1].append(make("span", "sender-role", tr("senderTarget")));
        content.children[1].hidden = !details.length && !receiver && !sender;
        const tips = [`${t.index}. ${t.name}`, tr("channels", {n: t.channels}), `${t.fx_count} FX`];
        if (ancestors.length) tips.push(tr("parent", {name: ancestors.join(" / ")}));
        select.title = tips.join(" · "); select.setAttribute("aria-label", select.title);
      }
      element.classList.toggle("receiver-target", t.id === allCanvasTarget);
      element.classList.toggle("track-selected", selectedTracks.has(t.id));
      element.querySelector(".track-select").setAttribute("aria-pressed", String(selectedTracks.has(t.id)));
      const expected = previous ? previous.nextSibling : $("track-list").firstChild;
      if (expected !== element) $("track-list").insertBefore(element, expected);
      previous = element;
    }
    renderAddReceiverButton();
  }
  function fillSelect(select, entries, selectedValue) {
    select.replaceChildren(...entries.map(([value, text]) => new Option(text, value)));
    if (entries.some(([value]) => String(value) === String(selectedValue))) select.value = selectedValue;
  }
  function clearTrackDrag() {
    draggingTracks = [];
    for (const element of document.querySelectorAll(".drop-target, .drop-invalid")) element.classList.remove("drop-target", "drop-invalid");
  }
  function eligibleDrop(sources, destination) {
    const all = new Map([...tracks, ...draftReceivers]);
    return !!sources.length && !!displayTrack(destination) && sources.every(id => tracks.has(id) && SendFlowRouting.canAddSource(all, routingInfo, id, destination));
  }
  function attachTrackDrop(element, target) {
    const destination = event => typeof target === "function" ? target(event) : target;
    element.addEventListener("dragover", event => {
      if (!draggingTracks.length) return;
      event.preventDefault(); event.stopPropagation();
      const valid = !connectionOperation && !batchOperation && eligibleDrop(draggingTracks, destination(event));
      event.dataTransfer.dropEffect = valid ? "link" : "none";
      element.classList.toggle("drop-target", valid); element.classList.toggle("drop-invalid", !valid);
    });
    element.addEventListener("dragleave", event => { if (!element.contains(event.relatedTarget)) element.classList.remove("drop-target", "drop-invalid"); });
    element.addEventListener("drop", event => {
      if (!draggingTracks.length) return;
      event.preventDefault(); event.stopPropagation();
      const sources = [...draggingTracks], id = destination(event); clearTrackDrag(); connectTracks(sources, id);
    });
  }
  async function connectTracks(sources, destination) {
    if (connectionOperation || batchOperation) { notify(tr("connectingSource")); return; }
    if (!eligibleDrop(sources, destination)) { notify(tr("invalidTrackDrop"), true); return; }
    const batch = {project}; batchOperation = batch;
    if (filter === "all") { if (!allCanvasTarget) focusAllTrack(selectionAnchor || sources[0]); renderTracks(); renderInspector(); resizeMatrix(); renderGraph(); }
    let target = destination, count = 0;
    try {
      for (const source of sources) {
        if (batchOperation !== batch || project !== batch.project) return;
        if (!eligibleDrop([source], target)) { notify(tr("batchStopped", {n:count}), true); return; }
        const result = await connect(source, target, batch);
        if (!result) { if (project === batch.project && count) notify(tr("batchStopped", {n:count}), true); return; }
        target = result.track_id || target; count++;
      }
      if (project === batch.project) notify(tr("batchCreated", {n:count}));
    } finally { if (batchOperation === batch) batchOperation = null; }
  }
  function renderTrackSelects() {
    const entries = orderedTracks().map(t => [t.id, `${t.index}. ${t.name}`]);
    for (const id of ["new-source","new-destination"]) fillSelect($(id), entries, $(id).value);
    if ($("new-source").value === $("new-destination").value && entries.length > 1) $("new-destination").selectedIndex = 1;
    $("create-send").disabled = entries.length < 2;
  }
  function selectFirstSend(id) {
    const available = [...sends.values()].filter(s => (filter !== "receive" || receiverChain.sendIds.has(s.id)) && canvasSend(s.id));
    const found = available.find(s => s.source === id) || available.find(s => s.destination === id);
    if (found) selectSend(found.id);
  }
  function selectCanvasTrack(id) { $("new-source").value = id; selectFirstSend(id); }
  function selectSend(id) { flushControls(); selected = id; activeControl = ""; renderInspector(); renderTracks(); renderGraph(); scheduleDraw(); }
  async function deleteSend(id) {
    if (!sends.has(id)) return;
    flushControls();
    const targetProject = project, result = await perform("delete_send", {send_id: id});
    if (result && project === targetProject && selected === id) {
      selected = ""; renderInspector(); renderTracks(); renderGraph(); scheduleDraw();
    }
  }
  function settleConnection(operation, result) {
    clearTimeout(operation.stateTimeout);
    if (connectionOperation === operation) connectionOperation = null;
    operation.resolve?.(result);
  }
  function finishConnection() {
    const operation = connectionOperation;
    if (!operation?.result || operation.project !== project) return;
    const {send_id, track_id} = operation.result;
    const target = track_id || operation.destination, send = sends.get(send_id);
    if (!tracks.has(target) || !send || send.source !== operation.source || send.destination !== target) {
      if (epoch > operation.epoch) { settleConnection(operation, null); notify(tr("stale"), true); }
      return;
    }
    if (operation.draft) {
      draftReceivers.delete(operation.destination);
      if (allCanvasTarget === operation.destination) allCanvasTarget = track_id;
      if (selectedTracks.delete(operation.destination)) selectedTracks.add(track_id);
      if (selectionAnchor === operation.destination) selectionAnchor = track_id;
      for (const [category, id] of receiverTargets) if (id === operation.destination) receiverTargets.set(category, track_id);
      if (positions.has(operation.destination)) positions.set(track_id, positions.get(operation.destination));
      if (movedNodes.has(operation.destination)) movedNodes.add(track_id);
      positions.delete(operation.destination); movedNodes.delete(operation.destination);
      for (const [key, layout] of [...receiverLayouts]) {
        if (layout.positions.has(operation.destination)) layout.positions.set(track_id, layout.positions.get(operation.destination));
        if (layout.movedNodes.delete(operation.destination)) layout.movedNodes.add(track_id);
        layout.positions.delete(operation.destination);
        if (layout.target === operation.destination) {
          receiverLayouts.delete(key); layout.target = track_id;
          receiverLayouts.set(receiverLayoutId(layout.category, track_id), layout);
        }
      }
      nodeElements.get(operation.destination)?.remove(); nodeElements.delete(operation.destination);
      if (receiverTarget === operation.destination) setReceiverTarget(track_id);
    }
    if (filter === "all") setReceiverTarget(target);
    if (filter !== "receive" || (isSendView() ? receiverTarget === operation.source : receiverTarget === (track_id || operation.destination))) selected = send_id;
    settleConnection(operation, operation.result);
    if (!operation.batch) notify(tr("created"));
  }
  async function connect(source, destination, batch = null) {
    if (!source || !destination || source === destination || !tracks.has(source) || !displayTrack(destination)) return;
    if (connectionOperation || (batchOperation && batchOperation !== batch)) { notify(tr("connectingSource")); return; }
    const existing = [...sends.values()].find(s => s.source === source && s.destination === destination);
    if (existing) { selectSend(existing.id); return; }
    const draft = draftReceivers.get(destination);
    const operation = {project, epoch, source, destination, draft, batch}; connectionOperation = operation;
    const completion = new Promise(resolve => { operation.resolve = resolve; });
    const result = await perform(draft ? "create_receiver" : "create_send", draft ? {source_track:source, name:draft.name} : {source_track:source, destination_track:destination});
    if (project !== operation.project || connectionOperation !== operation) return;
    if (!result?.send_id) { settleConnection(operation, null); return null; }
    operation.result = result; finishConnection();
    if (connectionOperation === operation) operation.stateTimeout = setTimeout(() => {
      if (connectionOperation === operation) { settleConnection(operation, null); notify(tr("stale"), true); }
    }, 8000);
    renderTracks(); renderInspector(); resizeMatrix(); renderGraph();
    return completion;
  }

  const addReceiverButton = make("button", "receiver-add");
  addReceiverButton.id = "add-receiver"; addReceiverButton.type = "button";
  addReceiverButton.addEventListener("click", () => {
    closeSourceMenu();
    let n = 1; const names = new Set([...tracks.values(), ...draftReceivers.values()].map(t => t.name));
    while (names.has(tr("defaultReceiver", {n}))) n++;
    $("receiver-name").value = tr("defaultReceiver", {n});
    $("receiver-dialog").showModal(); $("receiver-name").select();
  });
  $("cancel-receiver").addEventListener("click", () => $("receiver-dialog").close());
  $("receiver-form").addEventListener("submit", event => {
    event.preventDefault();
    const name = $("receiver-name").value.trim(); if (!name) { $("receiver-name").focus(); return; }
    const id = `draft:${++draftSerial}`;
    draftReceivers.set(id, {id, name, index:0, color:"#9dbbff", channels:2, folder:false, fx_count:0, parent:"", main_send:true, depth:0});
    $("receiver-dialog").close(); $("search").value = "";
    if (filter === "receive") receiverCategory = "send";
    if (filter === "all" && mode === "graph") {
      const graph = $("graph");
      positions.set(id, {x:(graph.clientWidth / 2 - graphPan.x) / graphPan.scale - 85, y:(graph.clientHeight / 2 - graphPan.y) / graphPan.scale - 34});
    }
    renderStatus(); chooseReceiver(id);
    trackElements.get(id)?.scrollIntoView({block:"nearest"});
    trackElements.get(id)?.querySelector(".track-select").focus();
    if (filter === "all" && mode === "matrix") $("matrix-scroll").scrollLeft = $("matrix-scroll").scrollWidth;
  });
  function closeSourceMenu(restoreFocus = false) {
    const previous = sourceMenu; sourceMenu = null; $("source-menu").hidden = true;
    if (restoreFocus && previous?.focus?.isConnected) previous.focus.focus();
  }
  function renderSourceOptions() {
    if (!sourceMenu || sourceMenu.project !== project || sourceMenu.outgoing !== isSendView() || !displayTrack(sourceMenu.target)) { closeSourceMenu(); return; }
    const {target, outgoing} = sourceMenu;
    // Menu candidates belong to the chosen node, even when the canvas shows several chains.
    const chain = outgoing ? SendFlowRouting.sendChain(tracks, routingInfo, target)
      : SendFlowRouting.receiveChain(new Map([...tracks, ...draftReceivers]), routingInfo, target);
    const query = $("source-search").value.trim().toLocaleLowerCase();
    const all = orderedTracks().filter(t => !chain.trackIds.has(t.id) && (!outgoing || SendFlowRouting.canAddSource(tracks, routingInfo, target, t.id)));
    const candidates = all.filter(t => !query || t.name.toLocaleLowerCase().includes(query) || String(t.index).includes(query));
    const focused = document.activeElement?.dataset.source;
    $("source-menu-title").textContent = tr(outgoing ? "addDestination" : "addSource", {name:displayTrack(target).name});
    $("source-search").placeholder = tr(isSendView() ? "searchDestination" : "searchSource");
    $("source-search").setAttribute("aria-label", $("source-search").placeholder);
    $("source-options").replaceChildren(...candidates.map(t => {
      const button = make("button", "source-option"); button.type = "button"; button.dataset.source = t.id;
      const number = make("span", "source-number", String(t.index).padStart(2,"0")); number.style.color = color(t);
      button.append(number, make("span", "source-name", t.name)); button.title = `${t.index}. ${t.name}`;
      button.addEventListener("click", () => {
        if (!sourceMenu || chain.trackIds.has(t.id) || !tracks.has(t.id)) return;
        const target = sourceMenu.target, outgoing = sourceMenu.outgoing;
        if (outgoing && !SendFlowRouting.canAddSource(tracks, routingInfo, target, t.id)) return;
        closeSourceMenu(true); if (outgoing) connect(target, t.id); else connect(t.id, target);
      });
      return button;
    }));
    $("source-menu-empty").hidden = candidates.length > 0;
    $("source-menu-empty").textContent = tr(isSendView() ? all.length ? "noDestinationMatches" : "noDestinations" : all.length ? "noSourceMatches" : "noSources");
    if (focused) [...$("source-options").children].find(el => el.dataset.source === focused)?.focus();
    const menu = $("source-menu"), rect = menu.getBoundingClientRect();
    menu.style.left = `${Math.max(8,Math.min(sourceMenu.x,innerWidth-rect.width-8))}px`;
    menu.style.top = `${Math.max(8,Math.min(sourceMenu.y,innerHeight-rect.height-8))}px`;
  }
  function openSourceMenu(event) {
    event.preventDefault();
    let clicked = event.target?.closest(".graph-node, .track-item")?.dataset.track;
    if (!event.keyboard && event.currentTarget === $("matrix-scroll")) {
      const rect = event.currentTarget.getBoundingClientRect(), x = event.clientX - rect.left, y = event.clientY - rect.top;
      if (isSendView()) {
        if (y >= colLabel && y < event.currentTarget.clientHeight && x >= 0 && (x < rowLabel || matrixCell(event)))
          clicked = matrixTracks().rows[Math.floor((y - colLabel + event.currentTarget.scrollTop) / cell)]?.id;
      } else if (x >= rowLabel && x < event.currentTarget.clientWidth && y >= 0 && (y < colLabel || matrixCell(event))) {
        clicked = matrixTracks().columns[Math.floor((x - rowLabel + event.currentTarget.scrollLeft) / cell)]?.id;
      }
    }
    const eligible = isSendView() ? tracks.has(clicked) : isReceiver(clicked);
    const target = eligible ? clicked : receiverTarget || (filter === "receive" ? receiverRoots()[0] : "");
    if (!displayTrack(target)) { notify(tr(isSendView() ? "chooseSender" : "chooseReceiver")); return; }
    if (filter === "all" && eligible) {
      setReceiverTarget(target);
      receiverChain = SendFlowRouting.receiveChain(new Map([...tracks, ...draftReceivers]), routingInfo, target);
    }
    if (connectionOperation) { notify(tr("connectingSource")); return; }
    matrixHover = null; $("matrix-tooltip").hidden = true;
    sourceMenu = {target, outgoing:isSendView(), project, focus:event.currentTarget, x:event.clientX, y:event.clientY};
    $("source-search").value = ""; $("source-menu").hidden = false;
    renderSourceOptions();
    $("source-search").focus();
  }
  for (const id of ["matrix-scroll", "graph-view", "track-list"]) {
    $(id).addEventListener("contextmenu", openSourceMenu);
    $(id).tabIndex = 0;
    $(id).addEventListener("keydown", event => {
      if (event.key === "ContextMenu" || (event.shiftKey && event.key === "F10")) {
        const rect = event.currentTarget.getBoundingClientRect();
        openSourceMenu({preventDefault:()=>event.preventDefault(),currentTarget:event.currentTarget,target:event.target,keyboard:true,clientX:rect.x+24,clientY:rect.y+24});
      }
    });
  }
  $("source-search").addEventListener("input", renderSourceOptions);
  $("close-source-menu").addEventListener("click", () => closeSourceMenu(true));
  $("source-menu").addEventListener("keydown", event => {
    if (event.isComposing) return;
    const items = [...$("source-options").children], index = items.indexOf(document.activeElement);
    if (event.key === "Escape") { event.preventDefault(); event.stopPropagation(); closeSourceMenu(true); }
    else if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault(); const next = event.key === "ArrowDown" ? index+1 : index < 0 ? items.length-1 : index-1;
      if (next < 0) $("source-search").focus(); else items[Math.min(items.length-1,next)]?.focus();
    } else if (event.key === "Enter" && document.activeElement === $("source-search") && items.length) { event.preventDefault(); items[0].click(); }
  });
  document.addEventListener("pointerdown", event => { if (sourceMenu && !$("source-menu").contains(event.target)) closeSourceMenu(); });
  document.addEventListener("focusin", event => { if (sourceMenu && !$("source-menu").contains(event.target)) closeSourceMenu(); });
  window.addEventListener("resize", () => closeSourceMenu());

  // Canvas draws only visible cells: O(visible rows × columns), not O(project tracks²) DOM.
  const cell = 44, rowLabel = 142, colLabel = 112;
  const matrixTracks = () => {
    const visible = visibleTracks();
    if (filter === "receive") {
      const roots = receiverRoots();
      const sources = new Set(isSendView() ? roots : []), destinations = new Set(isSendView() ? [] : roots);
      for (const id of receiverChain.sendIds) { const s = sends.get(id); sources.add(s.source); destinations.add(s.destination); }
      for (const id of receiverChain.parentIds) { sources.add(id); destinations.add(tracks.get(id).parent); }
      return {rows: visible.filter(t => sources.has(t.id)), columns: visible.filter(t => destinations.has(t.id))};
    }
    return {rows: visible.filter(t => !draftReceivers.has(t.id)), columns: visible};
  };
  function resizeMatrix() {
    const {rows,columns} = matrixTracks(), viewport = $("matrix-scroll");
    $("matrix-space").style.width = `${rowLabel + columns.length * cell}px`;
    $("matrix-space").style.height = `${colLabel + rows.length * cell}px`;
    const ratio = window.devicePixelRatio || 1, width = viewport.clientWidth, height = viewport.clientHeight;
    const canvas = $("matrix");
    if (canvas.width !== Math.round(width * ratio) || canvas.height !== Math.round(height * ratio)) {
      canvas.width = Math.round(width * ratio); canvas.height = Math.round(height * ratio);
      canvas.style.width = `${width}px`; canvas.style.height = `${height}px`;
    }
    scheduleDraw();
  }
  function scheduleDraw() { if (!frame) frame = requestAnimationFrame(() => { frame = 0; drawMatrix(); }); }
  function drawMatrix() {
    if (mode !== "matrix") return;
    const canvas = $("matrix"), ctx = canvas.getContext("2d"), ratio = window.devicePixelRatio || 1;
    const width = canvas.width / ratio, height = canvas.height / ratio;
    ctx.setTransform(ratio,0,0,ratio,0,0); ctx.clearRect(0,0,width,height);
    ctx.fillStyle = "#14181e"; ctx.fillRect(0,0,width,height);
    const {rows,columns} = matrixTracks(), sx = $("matrix-scroll").scrollLeft, sy = $("matrix-scroll").scrollTop;
    const c0 = Math.max(0,Math.floor(sx/cell)), c1 = Math.min(columns.length,Math.ceil((sx+width-rowLabel)/cell));
    const r0 = Math.max(0,Math.floor(sy/cell)), r1 = Math.min(rows.length,Math.ceil((sy+height-colLabel)/cell));
    const routes = new Map();
    for (const s of sends.values()) { if (!canvasSend(s.id)) continue; const key = `${s.source}|${s.destination}`; if (!routes.has(key)) routes.set(key,[]); routes.get(key).push(s); }
    ctx.save(); ctx.beginPath(); ctx.rect(rowLabel,colLabel,width-rowLabel,height-colLabel); ctx.clip();
    for (let r=r0;r<r1;r++) for (let c=c0;c<c1;c++) {
      const x = rowLabel+c*cell-sx, y = colLabel+r*cell-sy;
      const items = routes.get(`${rows[r].id}|${columns[c].id}`) || [], s = items.find(item => item.id === selected) || items[0];
      const hover = matrixHover?.r === r && matrixHover?.c === c;
      ctx.fillStyle = rows[r].id === columns[c].id ? "#11151a" : hover ? "#25352f" : r%2 ? "#161c22" : "#191f26";
      ctx.fillRect(x+1,y+1,cell-2,cell-2);
      if (rows[r].id === columns[c].id) { ctx.strokeStyle="#2b323b";ctx.beginPath();ctx.moveTo(x+18,y+26);ctx.lineTo(x+26,y+18);ctx.stroke(); }
      else if (s) {
        const accent = isSC(s) ? "#b89aff" : "#66e3bc";
        if (s.id === selected) { ctx.strokeStyle=accent;ctx.lineWidth=1;ctx.strokeRect(x+2,y+2,cell-4,cell-4); }
        ctx.strokeStyle = s.mute ? "#687383" : accent; ctx.fillStyle = s.mute ? "#242b34" : accent;
        ctx.beginPath(); ctx.roundRect(x+15,y+14,14,14,3); ctx.fill(); ctx.stroke();
        if (items.length > 1) { ctx.font="8px sans-serif";ctx.fillStyle="#cbd4df";ctx.fillText(items.length,x+32,y+12); }
        ctx.fillStyle = s.mute ? "#606c7c" : accent; ctx.globalAlpha=.65;
        ctx.fillRect(x+9,y+35,26*Math.max(0,(db(s.volume)+60)/72),2);ctx.globalAlpha=1;
      } else if (canvasParent(rows[r].id) && rows[r].main_send && rows[r].parent === columns[c].id) {ctx.strokeStyle="#cfb982";ctx.setLineDash([3,3]);ctx.strokeRect(x+14,y+14,16,16);ctx.setLineDash([]);
      } else if (hover) {ctx.fillStyle="#6d9987";ctx.font="18px sans-serif";ctx.fillText("+",x+16,y+27);}
    }
    ctx.restore();
    ctx.fillStyle="#1b2129";ctx.fillRect(0,0,width,colLabel);ctx.fillRect(0,colLabel,rowLabel,height-colLabel);
    ctx.save();ctx.beginPath();ctx.rect(rowLabel,0,width-rowLabel,colLabel);ctx.clip();
    for(let c=c0;c<c1;c++) {
      const x=rowLabel+c*cell-sx;
      ctx.fillStyle=color(columns[c]);ctx.fillRect(x+12,colLabel-5,20,2);
      ctx.save();ctx.translate(x+22,colLabel-18);ctx.rotate(-Math.PI/2.8);ctx.font="10px sans-serif";ctx.fillStyle="#b7c2cf";
      ctx.fillText(`${String(columns[c].index).padStart(2,"0")}  ${columns[c].name}`,0,0,100);ctx.restore();
    }ctx.restore();
    ctx.save();ctx.beginPath();ctx.rect(0,colLabel,rowLabel,height-colLabel);ctx.clip();
    for(let r=r0;r<r1;r++) {
      const y=colLabel+r*cell-sy;
      ctx.fillStyle=r%2?"#1a2028":"#1d242c";ctx.fillRect(0,y,rowLabel,cell-1);
      ctx.fillStyle=color(rows[r]);ctx.fillRect(12,y+15,3,14);
      ctx.font="9px sans-serif";ctx.fillStyle=rows[r].folder?"#cfb982":"#667586";ctx.fillText(rows[r].folder?(folderCollapsed(rows[r].id)?"▸":"▾"):String(rows[r].index).padStart(2,"0"),24,y+26);
      ctx.font="10px sans-serif";ctx.fillStyle="#bbc6d2";ctx.fillText(rows[r].name,46,y+26,88);
    }ctx.restore();
    ctx.fillStyle="#1b2129";ctx.fillRect(0,0,rowLabel,colLabel);
    ctx.fillStyle="#627386";ctx.font="8px sans-serif";ctx.fillText(`${tr("destination")}  ↗`,17,35);ctx.fillText(`${tr("source")}  ↓`,17,colLabel-19);
    ctx.strokeStyle="#303945";ctx.beginPath();ctx.moveTo(rowLabel,0);ctx.lineTo(rowLabel,height);ctx.moveTo(0,colLabel);ctx.lineTo(width,colLabel);ctx.stroke();
  }
  function matrixCell(event) {
    const rect=$("matrix-view").getBoundingClientRect(), x=event.clientX-rect.left, y=event.clientY-rect.top;
    if(x<rowLabel||y<colLabel||x>=$("matrix-scroll").clientWidth||y>=$("matrix-scroll").clientHeight) return null;
    const c=Math.floor((x-rowLabel+$("matrix-scroll").scrollLeft)/cell),r=Math.floor((y-colLabel+$("matrix-scroll").scrollTop)/cell), {rows,columns}=matrixTracks();
    return rows[r]&&columns[c]?{r,c,source:rows[r],destination:columns[c],x,y}:null;
  }
  function matrixFolder(event) {
    const scroll = $("matrix-scroll"), rect = scroll.getBoundingClientRect(), x = event.clientX - rect.left, y = event.clientY - rect.top;
    if (x < 18 || x > 43 || y < colLabel || y >= scroll.clientHeight) return null;
    const track = matrixTracks().rows[Math.floor((y - colLabel + scroll.scrollTop) / cell)];
    return track?.folder ? track : null;
  }
  $("matrix-scroll").addEventListener("scroll",()=>{matrixHover=null;$("matrix-tooltip").hidden=true;scheduleDraw();});
  // Some browsers report Shift+wheel on deltaX, while others keep it on deltaY.
  const horizontalWheelDelta = (event, width) => {
    const delta = Math.abs(event.deltaX) > Math.abs(event.deltaY) ? event.deltaX : event.deltaY;
    return delta * (event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? width : 1);
  };
  $("matrix-scroll").addEventListener("wheel", event => {
    if (!event.shiftKey || event.ctrlKey || event.metaKey) return;
    event.preventDefault(); event.stopPropagation();
    event.currentTarget.scrollLeft += horizontalWheelDelta(event, event.currentTarget.clientWidth);
    matrixHover=null;$("matrix-tooltip").hidden=true;scheduleDraw();
  }, {passive:false});
  let matrixPan = null, suppressMatrixClick = false;
  $("matrix-scroll").addEventListener("pointerdown", event => {
    suppressMatrixClick = false;
    if (event.button !== 0) return;
    const scroll = event.currentTarget, rect = scroll.getBoundingClientRect();
    if (event.clientX - rect.left >= scroll.clientWidth || event.clientY - rect.top >= scroll.clientHeight) return;
    const hit = matrixCell(event);
    if (hit && ((hit.source.main_send && hit.source.parent === hit.destination.id) || [...sends.values()].some(s => s.source === hit.source.id && s.destination === hit.destination.id))) return;
    matrixPan = {id: event.pointerId, x: event.clientX, y: event.clientY, left: scroll.scrollLeft, top: scroll.scrollTop, moved: false};
  });
  $("matrix-scroll").addEventListener("pointermove", event => {
    if (!matrixPan || matrixPan.id !== event.pointerId) return;
    const dx = event.clientX - matrixPan.x, dy = event.clientY - matrixPan.y;
    if (!matrixPan.moved && Math.hypot(dx, dy) < 5) return;
    matrixPan.moved = true; event.currentTarget.setPointerCapture(event.pointerId);
    event.currentTarget.classList.add("panning"); event.preventDefault();
    event.currentTarget.scrollLeft = matrixPan.left - dx; event.currentTarget.scrollTop = matrixPan.top - dy;
    matrixHover = null; $("matrix-tooltip").hidden = true; scheduleDraw();
  });
  for (const type of ["pointerup", "pointercancel", "lostpointercapture"]) $("matrix-scroll").addEventListener(type, event => {
    if (!matrixPan || event.pointerId !== matrixPan.id) return;
    suppressMatrixClick = matrixPan.moved; matrixPan = null; event.currentTarget.classList.remove("panning");
    if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId);
  });
  $("matrix-scroll").addEventListener("click",event=>{if(suppressMatrixClick){suppressMatrixClick=false;return;}const folder=matrixFolder(event);if(folder){toggleFolder(folder.id);return;}const hit=matrixCell(event);if(hit){const explicit=[...sends.values()].some(s=>s.source===hit.source.id&&s.destination===hit.destination.id);if(!explicit&&hit.source.main_send&&hit.source.parent===hit.destination.id)notify(tr("parentRouteInfo"));else connect(hit.source.id,hit.destination.id);}});
  $("matrix-scroll").addEventListener("mousemove",event=>{
    if (matrixPan?.moved) return;
    const folder=matrixFolder(event);event.currentTarget.style.cursor=folder?"pointer":"";event.currentTarget.title=folder?folderTip(folder):"";
    matrixHover=matrixCell(event);scheduleDraw();const tip=$("matrix-tooltip");
    if(!matrixHover||matrixHover.source.id===matrixHover.destination.id){tip.hidden=true;return;}
    const {source,destination,x,y}=matrixHover,s=[...sends.values()].find(s=>s.source===source.id&&s.destination===destination.id);
    tip.textContent=`${source.name} → ${destination.name}${s?` · ${gainText(s.volume)}`:` · ${tr(source.main_send&&source.parent===destination.id?"parentSend":"createTip")}`}`;
    tip.hidden=false;tip.style.left=`${Math.max(4,Math.min(x+12,$("matrix-view").clientWidth-tip.offsetWidth-8))}px`;tip.style.top=`${Math.max(4,y-35)}px`;
  });
  $("matrix-scroll").addEventListener("mouseleave",()=>{matrixHover=null;$("matrix-tooltip").hidden=true;scheduleDraw();});
  attachTrackDrop($("matrix-scroll"), event => {
    const rect = $("matrix-scroll").getBoundingClientRect(), x = event.clientX - rect.left;
    if (x < rowLabel || x >= $("matrix-scroll").clientWidth) return "";
    return matrixTracks().columns[Math.floor((x - rowLabel + $("matrix-scroll").scrollLeft) / cell)]?.id || "";
  });

  const svgNS="http://www.w3.org/2000/svg";
  function svg(tag,attrs={}) {const element=document.createElementNS(svgNS,tag);for(const [key,value] of Object.entries(attrs))element.setAttribute(key,value);return element;}
  const world=svg("g"),parentLayer=svg("g"),edgeHitLayer=svg("g"),edgeLayer=svg("g"),nodeLayer=svg("g");world.append(parentLayer,edgeHitLayer,edgeLayer,nodeLayer);$("graph").append(world);
  const graphPan = {x: 0, y: 0, scale: 1};
  function updateGraphPan() {
    if (activeReceiverLayout) activeReceiverLayout.pan = {...graphPan};
    world.setAttribute("transform", `translate(${graphPan.x},${graphPan.y}) scale(${graphPan.scale})`);
    $("graph-view").style.backgroundPosition = `${graphPan.x}px ${graphPan.y}px`;
    $("graph-view").style.backgroundSize = `${22 * graphPan.scale}px ${22 * graphPan.scale}px`;
  }
  let panDrag = null;
  $("graph").addEventListener("pointerdown", event => {
    if (event.button !== 0 || event.target.closest(".graph-node, .graph-link, .graph-link-hit")) return;
    event.preventDefault();
    panDrag = {id: event.pointerId, x: event.clientX, y: event.clientY, panX: graphPan.x, panY: graphPan.y};
    event.currentTarget.setPointerCapture(event.pointerId); event.currentTarget.classList.add("panning");
  });
  $("graph").addEventListener("pointermove", event => {
    if (!panDrag || panDrag.id !== event.pointerId) return;
    graphPan.x = panDrag.panX + event.clientX - panDrag.x; graphPan.y = panDrag.panY + event.clientY - panDrag.y; updateGraphPan();
  });
  for (const type of ["pointerup", "pointercancel", "lostpointercapture"]) $("graph").addEventListener(type, event => {
    if (!panDrag || panDrag.id !== event.pointerId) return;
    panDrag = null; event.currentTarget.classList.remove("panning");
    if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId);
  });
  $("graph-view").addEventListener("wheel", event => {
    // Cancel the browser's Ctrl+wheel zoom before updating only the SVG content group.
    event.preventDefault(); event.stopPropagation();
    if (panDrag || graphDrag) return;
    const unit = event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? $("graph").clientHeight : 1;
    if (event.ctrlKey) {
      const rect = $("graph").getBoundingClientRect(), x = event.clientX - rect.left, y = event.clientY - rect.top;
      const scale = Math.max(.25, Math.min(3, graphPan.scale * Math.exp(-event.deltaY * unit * .0015)));
      const ratio = scale / graphPan.scale;
      // Keep the point under the cursor fixed while the nodes and edges scale together.
      graphPan.x = x - (x - graphPan.x) * ratio;
      graphPan.y = y - (y - graphPan.y) * ratio;
      graphPan.scale = scale;
    } else if (event.shiftKey) {
      graphPan.x -= horizontalWheelDelta(event, $("graph").clientWidth);
    } else {
      graphPan.x -= event.deltaX * unit; graphPan.y -= event.deltaY * unit;
    }
    updateGraphPan();
  }, {passive:false});
  let graphDrag=null;
  function renderGraph() {
    if(mode!=="graph") return;
    const savedLayout=filter==="receive"?receiverLayout():null;
    if(activeReceiverLayout!==savedLayout){
      activeReceiverLayout=savedLayout;
      if(savedLayout?.pan){Object.assign(graphPan,savedLayout.pan);updateGraphPan();}
    }
    const list=visibleTracks(),visible=new Set(list.map(t=>t.id)),layout=graphPositions();
    const chainRows=new Map(),maxDistance=filter==="receive"?Math.max(0,...receiverChain.distance.values()):0;
    for(const [id,node]of nodeElements)if(!visible.has(id)){node.remove();nodeElements.delete(id);}
    let regular=0,buses=0,fx=0;
    for(const t of list){
      const type=kind(t),row=type==="BUS"?buses++:type==="FX"?fx++:regular++;
      if(filter==="receive"){
        const depth=receiverChain.distance.get(t.id),chainRow=chainRows.get(depth)||0;chainRows.set(depth,chainRow+1);
        if(!savedLayout.movedNodes.has(t.id))layout.set(t.id,{x:35+(isSendView()?depth:maxDistance-depth)*255,y:35+chainRow*108});
      }else if(!layout.has(t.id))layout.set(t.id,{x:type==="BUS"?300:type==="FX"?560:35,y:35+row*108+(type==="BUS"?54:0)});
      const p=layout.get(t.id);
      let node=nodeElements.get(t.id);
      if(!node){
        node=svg("g",{class:"graph-node","data-track":t.id,tabindex:0,role:"button"});
        const rect=svg("rect",{width:170,height:68,rx:8}),label=svg("text",{x:18,y:28}),sub=svg("text",{x:18,y:47,class:"node-sub"});
        node.append(rect,label,sub,svg("circle",{cx:0,cy:34,r:6,class:"port input"}),svg("circle",{cx:170,cy:34,r:7,class:"port output"}));
        const toggle=svg("g",{class:"node-folder-toggle",role:"button",tabindex:0});
        toggle.append(svg("rect",{x:140,y:8,width:24,height:24,rx:4}),svg("text",{x:152,y:25,"text-anchor":"middle"}));
        toggle.addEventListener("pointerdown",event=>event.stopPropagation());
        toggle.addEventListener("click",event=>{event.stopPropagation();toggleFolder(t.id);});
        toggle.addEventListener("keydown",event=>{if(event.key==="Enter"||event.key===" "){event.preventDefault();event.stopPropagation();toggleFolder(t.id);}});
        node.append(toggle);
        node.addEventListener("pointerdown",event=>{
          if(event.button!==0)return;event.preventDefault();const port=event.target.classList.contains("output");
          graphDrag={id:t.id,pointerId:event.pointerId,port,startX:event.clientX,startY:event.clientY,x:graphPositions().get(t.id).x,y:graphPositions().get(t.id).y};
          node.setPointerCapture(event.pointerId);
        });
        node.addEventListener("keydown",event=>{if(event.key==="Enter")selectCanvasTrack(t.id);});
        attachTrackDrop(node,t.id);
        nodeLayer.append(node);nodeElements.set(t.id,node);
      }
      const typeLabel=kind(t)==="TRACK"?tr(t.folder?"folder":"track"):kind(t)==="BUS"?tr("bus"):"FX";
      node.setAttribute("transform",`translate(${p.x},${p.y})`);node.setAttribute("aria-label",`${t.name}, ${typeLabel}`);
      const nameLimit=t.folder?15:19;
      node.children[1].textContent=t.name.length>nameLimit?`${t.name.slice(0,nameLimit-1)}…`:t.name;
      node.children[2].textContent=`${String(t.index).padStart(2,"0")}  /  ${filter==="receive"&&t.id===receiverTarget?tr(isSendView()?"chainSource":draftReceivers.has(t.id)?"draftReceiver":"chainTarget"):`${typeLabel}  /  ${tr("channels",{n:t.channels})}`}`;
      node.children[3].setAttribute("fill",color(t));node.children[4].setAttribute("fill",color(t));
      const toggle=node.children[5];toggle.style.display=t.folder?"":"none";
      if(t.folder){toggle.children[1].textContent=folderCollapsed(t.id)?"▸":"▾";toggle.setAttribute("aria-label",folderTip(t));toggle.setAttribute("aria-expanded",String(!folderCollapsed(t.id)));toggle.setAttribute("aria-disabled",String(!!$("search").value.trim()||filter==="receive"));}
      node.classList.toggle("selected",sends.get(selected)?.source===t.id||sends.get(selected)?.destination===t.id);
      node.classList.toggle("receiver-target",t.id===(filter==="all"?allCanvasTarget:receiverTarget));
    }
    const keep=new Set();
    for(const s of sends.values()){
      if(!canvasSend(s.id)||!visible.has(s.source)||!visible.has(s.destination))continue;
      keep.add(s.id);let path=edgeElements.get(s.id);
      if(!path){
        path=svg("g",{class:"graph-link",tabindex:0,role:"button","data-send":s.id});
        path.append(svg("title"),svg("path",{class:"graph-link-line"}));
        // Hit regions sit below every visible stroke so parallel sends remain individually clickable.
        const hit=svg("path",{class:"graph-link-hit","data-send":s.id,"aria-hidden":"true"});hit.append(svg("title"));
        const activate=event=>{if(event.button!==0)return;event.preventDefault();event.stopPropagation();selectSend(s.id);if(event.altKey)deleteSend(s.id);};
        path.addEventListener("click",activate);hit.addEventListener("click",activate);
        hit.addEventListener("pointerenter",()=>path.classList.add("hovered"));hit.addEventListener("pointerleave",()=>path.classList.remove("hovered"));
        path.addEventListener("keydown",event=>{if(event.key==="Enter"||event.key===" "){event.preventDefault();selectSend(s.id);}});
        edgeHitLayer.append(hit);edgeHitElements.set(s.id,hit);edgeLayer.append(path);edgeElements.set(s.id,path);
      }
      const a=layout.get(s.source),b=layout.get(s.destination),offset=s.index*4,x=a.x+170,y=a.y+34+offset,tx=b.x,ty=b.y+34+offset;
      const bend=Math.max(65,Math.abs(tx-x)*.5);
      const curve=`M ${x} ${y} C ${x+bend} ${y},${tx-bend} ${ty},${tx} ${ty}`, line=path.children[1], hit=edgeHitElements.get(s.id);
      hit.setAttribute("d",curve);line.setAttribute("d",curve);
      line.setAttribute("stroke",s.mute?"#616a76":isSC(s)?"#b89aff":"#66e3bc");
      line.setAttribute("stroke-dasharray",s.mute?"5 5":"none");path.classList.toggle("selected",s.id===selected);
      const label=`${tracks.get(s.source)?.name} → ${tracks.get(s.destination)?.name} · ${gainText(s.volume)}`;
      path.firstChild.textContent=`${label} · ${tr("deleteLinkTip")}`;path.setAttribute("aria-label",path.firstChild.textContent);
      hit.firstChild.textContent=path.firstChild.textContent;
    }
    for(const [id,path]of edgeElements)if(!keep.has(id)){path.remove();edgeElements.delete(id);edgeHitElements.get(id).remove();edgeHitElements.delete(id);}
    parentLayer.replaceChildren();
    for (const t of list) if (canvasParent(t.id) && t.main_send && visible.has(t.parent)) {
      const a=layout.get(t.id),b=layout.get(t.parent),x=a.x+170,y=a.y+34,tx=b.x,ty=b.y+34,bend=Math.max(65,Math.abs(tx-x)*.5);
      const path=svg("path",{class:"parent-link",d:`M ${x} ${y} C ${x+bend} ${y},${tx-bend} ${ty},${tx} ${ty}`});
      const title=svg("title");title.textContent=`${t.name} → ${tracks.get(t.parent).name} · ${tr("parentSend")}`;path.append(title);parentLayer.append(path);
    }
    const searchKey=filter==="all"&&allCanvasTarget?JSON.stringify([project,allCanvasTarget,[...visible]]):"";
    const searchNeedsFit=!!searchKey&&searchKey!==allFocusLayoutKey;allFocusLayoutKey=searchKey;
    const receiverSignature=savedLayout?JSON.stringify([[...receiverChain.distance],$("graph").clientWidth,$("graph").clientHeight]):"";
    if(((savedLayout&&savedLayout.signature!==receiverSignature)||searchNeedsFit)&&list.length){
      const points=list.map(t=>layout.get(t.id)),left=Math.min(...points.map(p=>p.x)),top=Math.min(...points.map(p=>p.y));
      const width=Math.max(...points.map(p=>p.x))+170-left,height=Math.max(...points.map(p=>p.y))+68-top;
      graphPan.scale=Math.max(.25,Math.min(1,($("graph").clientWidth-48)/width,($("graph").clientHeight-72)/height));
      graphPan.x=24-left*graphPan.scale;graphPan.y=24-top*graphPan.scale;updateGraphPan();
    }
    if(savedLayout)savedLayout.signature=receiverSignature;
  }
  $("graph").addEventListener("pointermove",event=>{
    if(!graphDrag)return;
    if(!graphDrag.port){if(Math.hypot(event.clientX-graphDrag.startX,event.clientY-graphDrag.startY)>3)(filter==="receive"?receiverLayout().movedNodes:movedNodes).add(graphDrag.id);graphPositions().set(graphDrag.id,{x:graphDrag.x+(event.clientX-graphDrag.startX)/graphPan.scale,y:graphDrag.y+(event.clientY-graphDrag.startY)/graphPan.scale});renderGraph();}
  });
  $("graph").addEventListener("pointerup",event=>{
    if(!graphDrag)return;const drag=graphDrag;graphDrag=null;
    if(drag.port){const hit=document.elementFromPoint(event.clientX,event.clientY)?.closest(".graph-node");if(hit)connect(drag.id,hit.dataset.track);}
    else if(Math.abs(event.clientX-drag.startX)+Math.abs(event.clientY-drag.startY)<4)selectCanvasTrack(drag.id);
  });
  $("graph").addEventListener("pointercancel",()=>{graphDrag=null;});
  $("graph").addEventListener("lostpointercapture",()=>{graphDrag=null;});

  function renderInspector() {
    const s=sends.get(selected),source=tracks.get(s?.source),destination=tracks.get(s?.destination);
    $("send-editor").hidden=!s||!source||!destination;$("inspector-empty").hidden=!!s;
    if(!s||!source||!destination)return;
    $("source-name").textContent=source.name;$("source-name").style.color=color(source);
    $("destination-name").textContent=destination.name;$("destination-name").style.color=color(destination);
    $("route-kind").textContent=tr(isSC(s)?"scSend":kind(destination)==="FX"?"fxSend":"audioSend");
    const parallel=[...sends.values()].filter(item=>item.source===s.source&&item.destination===s.destination);
    $("parallel-label").hidden=parallel.length<2;
    fillSelect($("parallel-send"),parallel.map(item=>[item.id,`Send ${item.index+1} · ${gainText(item.volume)}`]),s.id);
    const edit=sendModeEdits.get(s.id),sendMode=canonicalSendMode(edit ? edit.value : s.mode);
    $("send-mode").value=validSendMode(sendMode)?String(sendMode):"";
    $("send-mode").disabled=!!edit||!validSendMode(sendMode);
    $("send-mode").title=$("send-mode").selectedOptions[0]?.textContent||tr("sendModeUnavailable");
    if(activeControl!=="volume"&&!staged.has("volume"))setVolumeDisplay(s.volume);
    if(activeControl!=="pan"&&!staged.has("pan"))setPanDisplay(s.pan);
    $("mute").setAttribute("aria-pressed",String(s.mute));
    if(!["channel-mode","source-channel","destination-channel"].includes(document.activeElement?.id)){
      $("channel-mode").value=s.source_channel>=0&&(s.source_channel>>10)===1?"mono":"stereo";
      fillChannels(source.channels,s.source_channel&1023,s.destination_channel&1023);
      const width=s.source_channel<0?0:(s.source_channel>>10)===0?2:(s.source_channel>>10)===1?1:(s.source_channel>>10)*2;
      $("mapping-note").textContent=width>2||width===0?tr("mappingExisting", {width: width===0?tr("noAudio"):tr("channels", {n:width})}) : tr("mappingNote");
    }
  }
  function fillChannels(count,sourceValue,destValue){
    const mono=$("channel-mode").value==="mono",step=mono?1:2;
    const values=max=>{const out=[];for(let i=0;i+step<=max;i+=step)out.push([i,mono?String(i+1):`${i+1} / ${i+2}`]);return out;};
    fillSelect($("source-channel"),values(count),sourceValue);
    fillSelect($("destination-channel"),values(128),destValue);
  }
  function setVolumeDisplay(value){const valueDB=db(value);$("volume").value=valueDB;$("volume-value").textContent=gainText(value);$("volume-knob").style.setProperty("--angle",`${-135+(valueDB+60)/72*270}deg`);$("volume-knob").setAttribute("aria-valuenow",valueDB.toFixed(1));$("volume-knob").setAttribute("aria-valuetext",gainText(value));}
  function setPanDisplay(value){$("pan").value=value;$("pan-value").textContent=Math.abs(value)<.005?tr("center"):`${Math.round(Math.abs(value)*100)} ${tr(value<0?"left":"right")}`;}
  function stageControl(key,value){
    if(!sends.has(selected))return;
    if(key==="volume")setVolumeDisplay(value);else setPanDisplay(value);
    staged.set(key,{action:`set_send_${key}`,args:{send_id:selected,[key]:value},context:{project,epoch}});
    if(!flushTimer)flushTimer=setTimeout(flushControls,33);
  }
  function flushControls(){clearTimeout(flushTimer);flushTimer=0;for(const item of staged.values())if(item.context.project===project&&item.context.epoch===epoch)perform(item.action,item.args,item.context);staged.clear();}
  for(const key of ["volume","pan"]){
    $(key).addEventListener("pointerdown",()=>{activeControl=key;});
    $(key).addEventListener("input",()=>stageControl(key,key==="volume"?linear(Number($(key).value)):Number($(key).value)));
    $(key).addEventListener("change",()=>{activeControl="";flushControls();});
    $(key).addEventListener("blur",()=>{activeControl="";flushControls();});
  }
  let knobDrag=null;
  $("volume-knob").addEventListener("pointerdown",event=>{if(event.button!==0)return;activeControl="volume";knobDrag={y:event.clientY,value:Number($("volume").value)};event.currentTarget.setPointerCapture(event.pointerId);});
  $("volume-knob").addEventListener("pointermove",event=>{if(knobDrag)stageControl("volume",linear(Math.max(-60,Math.min(12,knobDrag.value+(knobDrag.y-event.clientY)*.3))));});
  for(const type of ["pointerup","pointercancel"])$("volume-knob").addEventListener(type,()=>{knobDrag=null;activeControl="";flushControls();});
  $("volume-knob").addEventListener("keydown",event=>{if(["ArrowUp","ArrowRight","ArrowDown","ArrowLeft","Home","End"].includes(event.key)){event.preventDefault();const value=event.key==="Home"?-60:event.key==="End"?12:Math.max(-60,Math.min(12,Number($("volume").value)+(["ArrowUp","ArrowRight"].includes(event.key)?1:-1)));stageControl("volume",linear(value));flushControls();}});
  $("volume-knob").addEventListener("dblclick",()=>{stageControl("volume",1);flushControls();});
  $("pan").addEventListener("dblclick",()=>{stageControl("pan",0);flushControls();});
  $("mute").addEventListener("click",()=>{const s=sends.get(selected);if(s)perform("set_send_mute",{send_id:s.id,mute:!s.mute});});
  $("send-mode").addEventListener("change",async()=>{
    const s=sends.get(selected),value=Number($("send-mode").value);
    if(!s||$("send-mode").disabled||!validSendMode(value))return;
    if(canonicalSendMode(s.mode)===value)return;
    flushControls();
    const edit={value,project,epoch};sendModeEdits.set(s.id,edit);renderInspector();
    const result=await perform("set_send_mode",{send_id:s.id,mode:value},{project:edit.project,epoch:edit.epoch});
    if(sendModeEdits.get(s.id)!==edit)return;
    sendModeEdits.delete(s.id);
    // A later native snapshot (including a project switch or reindexed send) wins over this acknowledgement.
    if(result!==null&&sends.get(s.id)===s)s.mode=value;
    renderInspector();
  });
  $("delete-send").addEventListener("click",()=>deleteSend(selected));
  $("parallel-send").addEventListener("change",()=>selectSend($("parallel-send").value));
  $("channel-mode").addEventListener("change",()=>{const s=sends.get(selected);if(s)fillChannels(tracks.get(s.source).channels,Number($("source-channel").value),Number($("destination-channel").value));});
  $("apply-mapping").addEventListener("click",()=>{if(selected)perform("set_send_channel_mapping",{send_id:selected,source_channel:Number($("source-channel").value),destination_channel:Number($("destination-channel").value),mono:$("channel-mode").value==="mono"});});
  $("create-send").addEventListener("click",()=>connect($("new-source").value,$("new-destination").value));
  $("language").addEventListener("change",()=>{setLanguage($("language").value);if(transport&&!demo)perform("set_language",{language});});
  $("dock-toggle").addEventListener("click",async()=>{const button=$("dock-toggle");button.disabled=true;await perform("set_docked",{docked:!docked});button.disabled=false;});
  $("refresh").addEventListener("click",()=>perform("get_state"));
  $("search").addEventListener("input",()=>{renderTracks();if(filter==="receive"){renderInspector();resizeMatrix();renderGraph();}});
  for (const button of document.querySelectorAll("[data-receiver-filter]")) button.addEventListener("click", () => setReceiverCategory(button.dataset.receiverFilter));
  for(const button of document.querySelectorAll("[data-filter]"))button.addEventListener("click",()=>{
    flushControls();closeSourceMenu();
    const previous=filter;filter=button.dataset.filter;
    if(filter==="all"){activeReceiverLayout=null;allCanvasTarget="";allFocusLayoutKey="";selectedTracks.clear();selectionAnchor="";selected="";activeControl="";graphPan.x=graphPan.y=0;graphPan.scale=1;updateGraphPan();$("matrix-scroll").scrollTo(0,0);}
    if(previous!==filter&&(previous==="receive"||filter==="receive")){
      $("track-list").scrollTo(0,0);$("matrix-scroll").scrollTo(0,0);
      closeSourceMenu();
    }
    matrixHover=null;$("matrix-tooltip").hidden=true;renderStatus();renderTracks();renderInspector();resizeMatrix();renderGraph();
  });
  function setMode(value){closeSourceMenu();mode=value;$("matrix-view").hidden=mode!=="matrix";$("graph-view").hidden=mode!=="graph";$("matrix-tab").classList.toggle("active",mode==="matrix");$("graph-tab").classList.toggle("active",mode==="graph");$("view-hint").textContent=tr(isSendView()?"sendHint":filter==="receive"?"receiveHint":mode==="matrix"?"matrixHint":"graphHint");resizeMatrix();renderGraph();}
  $("matrix-tab").addEventListener("click",()=>setMode("matrix"));$("graph-tab").addEventListener("click",()=>setMode("graph"));
  document.addEventListener("keydown",event=>{if(event.key==="Delete"&&selected&&!sourceMenu&&!$("receiver-dialog").open&&!["INPUT","SELECT","TEXTAREA"].includes(document.activeElement.tagName)){event.preventDefault();deleteSend(selected);}});
  new ResizeObserver(resizeMatrix).observe($("matrix-scroll"));
  new ResizeObserver(()=>{if(filter==="receive")renderGraph();}).observe($("graph-view"));
  $("demo-button").addEventListener("click",()=>{location.search="?demo=1";});

  // Explicit browser-only demo; never presented as a live REAPER session.
  function createDemo(){
    const names=["Drum Bus","Kick","Percussion","Snare","Hi-Hats","Bass","Keys","Lead Synth","Plate Reverb","Stereo Delay"];
    const colors=["#e1c092","#e0ae73","#e0ae73","#e0ae73","#e0ae73","#83bba5","#8fb2db","#8fb2db","#b59adc","#b59adc"];
    demoState={type:"state",full:true,project:"demo",epoch:1,change_count:1,tracks:names.map((name,i)=>({id:`t${i+1}`,index:i+1,name,color:colors[i],channels:i===5?4:2,fx_count:i>7?1:0,folder:i===0||i===2,parent:i===1||i===2?"t1":i===3||i===4?"t3":"",depth:i===1||i===2?1:i===3||i===4?2:0,main_send:true})),sends:[],removed_tracks:[],removed_sends:[]};
    for(const [src,dst,volume,sc]of [[4,9,.28,0],[7,9,.34,0],[8,10,.23,0],[2,6,.75,2]]){
      const index=demoState.sends.filter(s=>s.source===`t${src}`).length;
      demoState.sends.push({id:`t${src}:${index}`,source:`t${src}`,destination:`t${dst}`,index,volume,pan:0,mute:false,mode:0,source_channel:0,destination_channel:sc});
    }
  }
  function demoCommand(c){setTimeout(()=>{
    let result={},error="";
    try{
      if(c.action!=="get_state"&&c.action!=="get_tracks"&&(c.project!==demoState.project||c.epoch!==demoState.epoch))throw new Error(tr("stale"));
      const s=demoState.sends.find(item=>item.id===c.send_id);
      if(c.action==="create_send"||c.action==="create_receiver"){
        const src=c.source_track;
        if(!demoState.tracks.some(t=>t.id===src))throw new Error(tr("missingTrack"));
        let dst=c.destination_track;
        if(c.action==="create_receiver"){
          dst=`t${Math.max(0,...demoState.tracks.map(t=>Number(t.id.slice(1))))+1}`;
          demoState.tracks.push({id:dst,index:demoState.tracks.length+1,name:c.name,color:"#9dbbff",channels:2,fx_count:0,folder:false,parent:"",depth:0,main_send:true});
          result.track_id=dst;
        }
        if(!demoState.tracks.some(t=>t.id===dst))throw new Error(tr("missingTrack"));
        const walk=[dst],seen=new Set();while(walk.length){const id=walk.pop();if(id===src)throw new Error(tr("cycle"));if(seen.has(id))continue;seen.add(id);demoState.sends.filter(s=>s.source===id).forEach(s=>walk.push(s.destination));const t=demoState.tracks.find(t=>t.id===id);if(t?.main_send&&t.parent)walk.push(t.parent);}
        if(demoState.sends.some(s=>s.source===src&&s.destination===dst))throw new Error(tr("exists"));
        const index=demoState.sends.filter(s=>s.source===src).length;
        const item={id:`${src}:${index}`,source:src,destination:dst,index,volume:1,pan:0,mute:false,mode:0,source_channel:0,destination_channel:0};demoState.sends.push(item);result.send_id=item.id;demoState.epoch++;
      }else if(c.action==="delete_send"){
        if(!s)throw new Error(tr("missingSend"));demoState.sends=demoState.sends.filter(item=>item!==s);let index=0;for(const item of demoState.sends)if(item.source===s.source){item.index=index++;item.id=`${item.source}:${item.index}`;}demoState.epoch++;
      }else if(c.action.startsWith("set_send_")){
        if(!s)throw new Error(tr("missingSend"));
        if(c.action==="set_send_mode"&&!validSendMode(c.mode))throw new Error(tr("invalidSendMode"));
        if(c.action==="set_send_channel_mapping"){s.source_channel=c.source_channel|(c.mono?1024:0);s.destination_channel=c.destination_channel|(c.mono?1024:0);const t=demoState.tracks.find(t=>t.id===s.destination);t.channels=Math.max(t.channels,(c.destination_channel+(c.mono?1:2)+1)&~1);demoState.epoch++;}
        else{const key=c.action.slice(9);s[key]=c[key];}
      }
      demoState.change_count++;
    }catch(e){error=e.message;}
    window.SendFlowReceive({type:"result",id:c.id,ok:!error,...(error?{error}:{result})});
    setTimeout(()=>window.SendFlowReceive(structuredClone(demoState)),0);
  },10);}
  $("language").replaceChildren(...Object.entries(SendFlowLanguages).map(([id, name]) => {
    const option = new Option(name, id); option.lang = id; return option;
  }));
  setLanguage(language);
  if(transport && !demo) perform("get_window_state");
  if(demo)createDemo();
  if(transport||demo)perform("get_state");
  else{$("empty-state").hidden=false;$("demo-button").hidden=false;}
  // Re-request until the first native snapshot arrives; no polling after handshake.
  const handshake=setInterval(()=>{if(receivedState||(!transport&&!demo)){clearInterval(handshake);return;}perform("get_state");},2500);
  resizeMatrix();
})();
