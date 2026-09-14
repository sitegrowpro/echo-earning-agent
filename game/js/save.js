import { SAVE_KEY, END_KEY, SET_KEY } from './config.js';

export function saveGame(data) {
  try { localStorage.setItem(SAVE_KEY, JSON.stringify({ ...data, ts: Date.now() })); return true; }
  catch { return false; }
}
export function loadGame() {
  try { const s = localStorage.getItem(SAVE_KEY); return s ? JSON.parse(s) : null; }
  catch { return null; }
}
export function clearSave() { try { localStorage.removeItem(SAVE_KEY); } catch {} }
export function hasSave() { return !!loadGame(); }

export function getEndings() {
  try { return JSON.parse(localStorage.getItem(END_KEY) || '{}'); } catch { return {}; }
}
export function unlockEnding(id) {
  const e = getEndings(); e[id] = (e[id] || 0) + 1;
  try { localStorage.setItem(END_KEY, JSON.stringify(e)); } catch {}
  return e;
}
export function getSettings() {
  try { return { sens: 1, vol: 0.8, subs: true, grain: true, headbob: true, ...JSON.parse(localStorage.getItem(SET_KEY) || '{}') }; }
  catch { return { sens: 1, vol: 0.8, subs: true, grain: true, headbob: true }; }
}
export function saveSettings(s) { try { localStorage.setItem(SET_KEY, JSON.stringify(s)); } catch {} }
