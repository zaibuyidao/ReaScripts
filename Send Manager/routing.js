"use strict";
// Structural parents remain available even when their audio route is disabled.
const SendPlusRouting = {
  hasAudio: send => send.source_channel >= 0,
  isSC: send => send.source_channel >= 0 && (send.destination_channel & 1023) >= 2,
  receiveCategory(send) { return send.mute ? "muted" : this.isSC(send) ? "sidechain" : "send"; },
  analyze(tracks, sends) {
    const result = new Map([...tracks.keys()].map(id => [id, {sends: [], incoming: [], receives: [], children: [], ancestors: [], descendants: 0}]));
    for (const send of sends.values()) {
      if (!tracks.has(send.source) || !tracks.has(send.destination)) continue;
      result.get(send.source).sends.push(send);
      result.get(send.destination).incoming.push(send);
      if (this.hasAudio(send) && tracks.has(send.source)) result.get(send.destination)?.receives.push(send);
    }
    for (const track of tracks.values()) {
      if (track.main_send && track.parent) result.get(track.parent)?.children.push(track.id);
      const info = result.get(track.id), seen = new Set([track.id]);
      let parent = tracks.get(track.parent);
      while (parent && !seen.has(parent.id)) {
        seen.add(parent.id); info.ancestors.unshift(parent.id); result.get(parent.id).descendants++; parent = tracks.get(parent.parent);
      }
      info.depth = Number.isInteger(track.depth) ? Math.max(0, track.depth) : info.ancestors.length;
      info.sendCount = info.sends.length + (track.main_send && tracks.has(track.parent) ? 1 : 0);
    }
    for (const info of result.values()) {
      info.bus = info.receives.length > 0 || info.children.length > 0;
      info.receiveCount = info.incoming.length + info.children.length;
      info.receiveCategories = {send:0, sidechain:0, muted:0, parent:info.children.length};
      for (const send of info.incoming) info.receiveCategories[this.receiveCategory(send)]++;
    }
    return result;
  },
  receiveChain(tracks, info, target) {
    const trackIds = new Set(), sendIds = new Set(), parentIds = new Set(), distance = new Map();
    // Multiple roots combine category chains in one traversal, with shared nodes visited once.
    const queue = [...new Set(Array.isArray(target) ? target : [target])].filter(id => tracks.has(id));
    for (const id of queue) { trackIds.add(id); distance.set(id, 0); }
    for (let cursor = 0; cursor < queue.length; cursor++) {
      const id = queue[cursor], entry = info.get(id);
      const visit = source => {
        if (!tracks.has(source) || trackIds.has(source)) return;
        trackIds.add(source); distance.set(source, distance.get(id) + 1); queue.push(source);
      };
      for (const send of entry?.incoming || []) { sendIds.add(send.id); visit(send.source); }
      for (const child of entry?.children || []) { parentIds.add(child); visit(child); }
    }
    return {trackIds, sendIds, parentIds, distance};
  },
  sendChain(tracks, info, source) {
    const trackIds = new Set(), sendIds = new Set(), parentIds = new Set(), distance = new Map();
    const queue = [...new Set(Array.isArray(source) ? source : [source])].filter(id => tracks.has(id));
    for (const id of queue) { trackIds.add(id); distance.set(id, 0); }
    for (let cursor = 0; cursor < queue.length; cursor++) {
      const id = queue[cursor], entry = info.get(id), track = tracks.get(id);
      const visit = destination => {
        if (!tracks.has(destination) || trackIds.has(destination)) return;
        trackIds.add(destination); distance.set(destination, distance.get(id) + 1); queue.push(destination);
      };
      for (const send of entry?.sends || []) { sendIds.add(send.id); visit(send.destination); }
      if (track.main_send && tracks.has(track.parent)) { parentIds.add(id); visit(track.parent); }
    }
    return {trackIds, sendIds, parentIds, distance};
  },
  linkedTracks(tracks, info, matches) {
    // Follow actual routing in both directions, including branches and parent sends.
    const linked = new Set(), queue = [];
    const visit = id => {
      const entry = info.get(id);
      if (!tracks.has(id) || linked.has(id) || !(entry?.sendCount || entry?.receiveCount)) return;
      linked.add(id); queue.push(id);
    };
    for (const id of matches) visit(id);
    for (let cursor = 0; cursor < queue.length; cursor++) {
      const id = queue[cursor], entry = info.get(id), track = tracks.get(id);
      for (const send of entry.incoming) visit(send.source);
      for (const send of entry.sends) visit(send.destination);
      for (const child of entry.children) visit(child);
      if (track.main_send) visit(track.parent);
    }
    return linked;
  },
  focusedChain(tracks, info, target) {
    const trackIds = new Set(), sendIds = new Set(), parentIds = new Set();
    if (!tracks.has(target) || !(info.get(target)?.sendCount || info.get(target)?.receiveCount)) return {trackIds, sendIds, parentIds};
    // Keep paths to and from the target separate: shared destinations do not pull in sibling sources.
    for (const upstream of [true, false]) {
      const seen = new Set([target]), queue = [target]; trackIds.add(target);
      const visit = id => { if (tracks.has(id) && !seen.has(id)) { seen.add(id); trackIds.add(id); queue.push(id); } };
      for (let cursor = 0; cursor < queue.length; cursor++) {
        const id = queue[cursor], entry = info.get(id), track = tracks.get(id);
        for (const send of upstream ? entry.incoming : entry.sends) { sendIds.add(send.id); visit(upstream ? send.source : send.destination); }
        if (upstream) for (const child of entry.children) { parentIds.add(child); visit(child); }
        else if (track.main_send && tracks.has(track.parent)) { parentIds.add(id); visit(track.parent); }
      }
    }
    return {trackIds, sendIds, parentIds};
  },
  canAddSource(tracks, info, source, destination) {
    if (!tracks.has(source) || !tracks.has(destination) || source === destination) return false;
    const receiver = info.get(destination);
    if (receiver?.incoming.some(send => send.source === source)) return false;
    // A route from the destination back to the source would close a feedback loop.
    return !this.receiveChain(tracks, info, source).trackIds.has(destination);
  },
  visibleHierarchy(list, info, collapsed, searching = false) {
    if (searching || !collapsed.size) return list;
    const included = new Set(list.map(t => t.id));
    // A filtered-out folder must not hide matching tracks with no visible way to expand it.
    return list.filter(t => !info.get(t.id)?.ancestors.some(id => included.has(id) && collapsed.has(id)));
  }
};
if (typeof module !== "undefined") module.exports = SendPlusRouting;
