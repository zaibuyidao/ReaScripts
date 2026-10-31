'use strict';
// Acknowledgements are Lua results, not the host.send queue acknowledgement.
window.KeymapBridge = class {
  constructor(onChange,onTheme) { this.onTheme=onTheme; this.pending = new Map(); this.serial = 0; this.onChange = onChange; this.connected = false; }
  async start() {
    if (!window.reaper?.host || !window.reaper?.events) return false;
    await window.reaper.events.on('message', raw => {
      let message; try { message = typeof raw === 'string' ? JSON.parse(raw) : raw; } catch { return; }
      if (message.type === 'theme') { this.onTheme?.(message.theme); return; }
      if (message.type === 'changed') { this.onChange(); return; }
      const task = this.pending.get(message.id);
      if (!task) return;
      if (message.type === 'chunk') {
        task.chunks ||= [];
        task.chunks[message.part - 1] = message.data;
        task.received = (task.received || 0) + 1;
        if (task.received < message.total) return;
        try { message = JSON.parse(task.chunks.join('')); }
        catch { clearTimeout(task.timer); this.pending.delete(message.id); task.reject(new Error('列表数据接收失败，请刷新重试。')); return; }
      }
      clearTimeout(task.timer); this.pending.delete(message.id);
      if (message.ok) task.resolve(message.result); else task.reject(new Error(message.error || '操作失败。'));
    });
    this.connected = true;
    return true;
  }
  call(method, params = {}) {
    const id = ++this.serial;
    return new Promise((resolve, reject) => {
      // Native shortcut/file dialogs can stay open while the user is working.
      const timer = setTimeout(() => { this.pending.delete(id); reject(new Error('后端未响应。请检查 REAPER 中的窗口，关闭后刷新；请勿重复提交修改。')); }, 600000);
      this.pending.set(id, {resolve, reject, timer});
      window.reaper.host.send(JSON.stringify({id, method, params})).catch(error => {
        clearTimeout(timer); this.pending.delete(id); reject(error);
      });
    });
  }
};
