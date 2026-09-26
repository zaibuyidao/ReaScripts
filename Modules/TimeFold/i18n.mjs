export class I18n {
  locale = 'en';
  strings = {};
  fallback = {};
  async load(locale = 'en') {
    if (!/^[\w-]+$/.test(locale)) locale = 'en';
    if (!Object.keys(this.fallback).length) {
      const response = await fetch('./locales/en.json');
      if (!response.ok) throw new Error('en.json');
      this.fallback = (await response.json()).strings;
    }
    let strings = this.fallback;
    if (locale !== 'en') {
      const response = await fetch(`./locales/${locale}.json`);
      if (!response.ok) throw new Error(locale);
      strings = (await response.json()).strings;
    }
    this.locale = locale;
    this.strings = { ...this.fallback, ...strings };
    this.numbers = new Intl.NumberFormat(locale, { maximumFractionDigits: 0 });
    document.documentElement.lang = locale;
    this.apply();
  }
  t(key, values = {}) {
    return (this.strings[key] ?? this.fallback[key] ?? key).replace(/\{(\w+)\}/g, (_, name) => String(values[name] ?? `{${name}}`));
  }
  apply(root = document) {
    for (const node of root.querySelectorAll('[data-i18n]')) node.textContent = this.t(node.dataset.i18n);
    for (const node of root.querySelectorAll('[data-title]')) node.title = this.t(node.dataset.title);
    for (const node of root.querySelectorAll('[data-aria]')) node.setAttribute('aria-label', this.t(node.dataset.aria));
    document.title = this.t('appTitle');
  }
  time(seconds, precise = false) {
    const raw = Math.max(0, Number.isFinite(seconds) ? seconds : 0);
    const value = precise ? Math.round(raw * 1000) / 1000 : Math.floor(raw);
    const minutes = Math.floor(value / 60), remainder = value % 60;
    return `${String(minutes).padStart(2, '0')}:${remainder.toFixed(precise ? 3 : 0).padStart(precise ? 6 : 2, '0')}`;
  }
}
