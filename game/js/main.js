// MAIN — boots the renderer, owns all DOM/UI, wires systems, runs the loop.
import * as THREE from 'three';
import { CFG, ENDINGS } from './config.js';
import { AudioSys } from './audio.js';
import { World } from './world.js';
import { Player } from './player.js';
import { Interact } from './interact.js';
import { Phone } from './phone.js';
import { Story } from './story.js';
import { Enemy } from './enemy.js';
import { saveGame, loadGame, hasSave, clearSave, getEndings, unlockEnding, getSettings, saveSettings } from './save.js';

const $ = (id) => document.getElementById(id);
const canvas = $('game');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setSize(innerWidth, innerHeight);
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x030304);
scene.fog = new THREE.FogExp2(0x05060a, 0.03);
const camera = new THREE.PerspectiveCamera(CFG.fov, innerWidth / innerHeight, 0.05, 120);

const settings = getSettings();
const audio = new AudioSys();
audio.vol = settings.vol;
const world = new World(scene);
const player = new Player(camera, audio, settings);
const enemy = new Enemy(scene, audio);
const story = new Story({ audio, world, enemy, player, scene });
const phone = new Phone(audio, story);
story.phone = phone;
const interact = new Interact(camera, scene);

// flashlight (spot follows camera)
const flash = new THREE.SpotLight(0xfff2d9, 0, 22, 0.42, 0.45, 1.2);
scene.add(flash); scene.add(flash.target);
// faint moon fill so outdoors is never pitch black
scene.add(new THREE.AmbientLight(0x11141f, 0.6));

let state = 'menu'; // menu|playing|paused|ending
let rainOn = true, lastRoom = '', shakeT = 0;
let subTimer = null, roomToastT = null;

// ================= UI object (story's window into the DOM) =================
const ui = {
  toast(msg) {
    const d = document.createElement('div'); d.className = 'toast'; d.textContent = msg;
    $('toast-wrap').appendChild(d);
    setTimeout(() => { d.style.opacity = '0'; setTimeout(() => d.remove(), 400); }, 4200);
  },
  subtitle(text, dur = 4) {
    if (!settings.subs) return;
    const s = $('subtitle'); s.textContent = text; s.classList.remove('hidden');
    clearTimeout(subTimer); subTimer = setTimeout(() => s.classList.add('hidden'), dur * 1000);
  },
  objectives(list) {
    $('obj-list').innerHTML = list.map((o) => `<li class="${o.done ? 'done' : ''}">${o.text}</li>`).join('');
    $('pause-obj').innerHTML = '<b>OBJECTIVES</b><br>' + list.map((o) => `${o.done ? '✓' : '▸'} ${o.text}`).join('<br>');
  },
  chapterCard(kicker, name, sub) {
    const c = $('chapter-card');
    $('chapter-kicker').textContent = kicker; $('chapter-name').textContent = name; $('chapter-sub').textContent = sub;
    c.classList.remove('hidden'); requestAnimationFrame(() => c.classList.add('show'));
    setTimeout(() => { c.classList.remove('show'); setTimeout(() => c.classList.add('hidden'), 900); }, 3400);
  },
  dialog(sp, text, opts) {
    document.exitPointerLock?.();
    $('dialog-speaker').textContent = sp; $('dialog-text').textContent = text;
    const box = $('dialog-options'); box.innerHTML = '';
    opts.forEach((o, i) => {
      const b = document.createElement('button'); b.textContent = `${i + 1}. ${o.text}`;
      b.onclick = () => { audio.uiClick(); o.cb(); tryLock(); };
      box.appendChild(b);
    });
    $('dialog').classList.remove('hidden');
  },
  closeDialog() { $('dialog').classList.add('hidden'); },
  note(title, body) {
    document.exitPointerLock?.();
    $('note-title').textContent = title; $('note-body').textContent = body;
    $('note').classList.remove('hidden');
  },
  closeNote() { $('note').classList.add('hidden'); },
  peephole(html) {
    document.exitPointerLock?.();
    $('peephole-view').innerHTML = html;
    $('peephole').classList.remove('hidden');
  },
  closePeephole() { $('peephole').classList.add('hidden'); },
  call(name, onA, onD) {
    document.exitPointerLock?.();
    $('caller-name').textContent = name;
    $('call-overlay').classList.remove('hidden');
    $('call-accept').onclick = () => { audio.uiClick(); onA(); tryLock(); };
    $('call-decline').onclick = () => { audio.uiClick(); onD(); tryLock(); };
  },
  closeCall() { $('call-overlay').classList.add('hidden'); },
  flash() { const f = $('damage-flash'); f.style.opacity = '1'; setTimeout(() => (f.style.opacity = '0'), 180); },
  flashHide(text) { ui.subtitle(text, 5); },
  vhs(s) { $('vhs-time').textContent = s; },
  roomToast(name) {
    clearTimeout(roomToastT);
    const v = $('vhs-cam'); v.textContent = ' ▸ ' + name;
  },
  rain(on) { rainOn = on; },
  autosave() { if (state === 'playing' && story.chapter >= 0) saveGame(story.serialize()); },
  jumpscare(cb) {
    audio.sting(); shakeT = 1.2;
    $('scare').classList.remove('hidden');
    ui.flash();
    setTimeout(() => { $('scare').classList.add('hidden'); cb(); }, 1100);
  },
  ending(id, text, subtext, stats) {
    unlockEnding(id);
    state = 'ending';
    document.exitPointerLock?.();
    $('hud').classList.add('hidden'); phone.toggle(false);
    $('ending-kicker').textContent = subtext;
    $('ending-title').textContent = ENDINGS[id].name + (ENDINGS[id].good ? ' ✓' : ' ✗');
    $('ending-title').style.color = ENDINGS[id].good ? '#7fb069' : '#c1121f';
    $('ending-text').textContent = text;
    $('ending-stats').textContent = stats + `\nEndings found: ${Object.keys(getEndings()).length}/4`;
    $('btn-again').textContent = id === 'D' ? '↺ Rewind to 11:24 PM' : '▶ Play again';
    $('ending').classList.remove('hidden');
    if (id !== 'D') clearSave();
    refreshEndings();
  },
};
story.ui = ui;
story.register(interact);
interact.ctx = { story, audio, player, world, enemy, ui, uiBlocked: () => story.uiBusy() || state !== 'playing' };

// ================= pointer lock =================
function tryLock() {
  if (state !== 'playing' || story.uiBusy()) return;
  canvas.requestPointerLock?.();
}
document.addEventListener('pointerlockchange', () => {
  player.locked = document.pointerLockElement === canvas;
  if (!player.locked && state === 'playing' && !story.uiBusy() && !phone.visible) pauseGame();
});
document.addEventListener('mousemove', (e) => { if (player.locked) player.mouse(e.movementX, e.movementY); });
canvas.addEventListener('click', () => {
  if (state === 'playing' && !story.uiBusy()) {
    if (phone.visible) phone.toggle(false);
    tryLock();
  }
});

// ================= input =================
document.addEventListener('keydown', (e) => {
  if (state !== 'playing') return;
  if (e.code === 'Tab') { e.preventDefault(); if (!story.uiBusy()) { audio.uiClick(); phone.toggle(); } return; }
  if (phone.visible && ['Digit1', 'Digit2', 'Digit3'].includes(e.code)) {
    const btns = $('phone-replies').querySelectorAll('button');
    const b = btns[Number(e.code.slice(5)) - 1]; if (b) b.click(); return;
  }
  if (story.noteOpen && (e.code === 'KeyE' || e.code === 'Escape')) { story.closeNote(); tryLock(); return; }
  if (story.peepOpen && (e.code === 'KeyE' || e.code === 'Escape')) { story.closePeep(); tryLock(); return; }
  if ($('dialog').classList.contains('hidden') === false && ['Digit1', 'Digit2', 'Digit3'].includes(e.code)) {
    const btns = $('dialog-options').querySelectorAll('button');
    const b = btns[Number(e.code.slice(5)) - 1]; if (b) b.click(); return;
  }
  if (story.uiBusy()) return;
  player.key(e, true);
  if (e.code === 'KeyE') {
    if (story.noteOpen) { story.closeNote(); tryLock(); }
    else interact.press();
  }
  if (e.code === 'KeyF') story.toggleFlash();
  if (e.code === 'Escape') pauseGame();
});
document.addEventListener('keyup', (e) => {
  player.key(e, false);
  if (e.code === 'KeyE') interact.release();
});
$('note').addEventListener('click', () => { if (story.noteOpen) { story.closeNote(); tryLock(); } });
$('peephole').addEventListener('click', () => { if (story.peepOpen) { story.closePeep(); tryLock(); } });

// ================= menus =================
function refreshEndings() {
  const e = getEndings();
  $('endings-count').textContent = `(${Object.keys(e).length}/4)`;
  $('endings-list').innerHTML = Object.entries(ENDINGS)
    .map(([id, d]) => `<li>${e[id] ? '✓' : '✗'} ${d.name}${e[id] > 1 ? ` ×${e[id]}` : ''}</li>`).join('');
}
function wirePanel(btn, panel) {
  $(btn).onclick = () => {
    audio.init(); audio.uiClick();
    ['panel-how', 'panel-endings', 'panel-settings'].forEach((p) => { if (p !== panel) $(p).classList.add('hidden'); });
    $(panel).classList.toggle('hidden');
  };
}
wirePanel('btn-how', 'panel-how'); wirePanel('btn-endings', 'panel-endings'); wirePanel('btn-settings', 'panel-settings');
function applySettings() {
  $('grain').style.display = settings.grain ? '' : 'none';
  $('scanlines').style.display = settings.grain ? '' : 'none';
  $('set-sens').value = settings.sens; $('set-sens2').value = settings.sens;
  $('set-vol').value = settings.vol; $('set-vol2').value = settings.vol;
  $('set-subs').checked = settings.subs; $('set-grain').checked = settings.grain; $('set-headbob').checked = settings.headbob;
}
for (const id of ['set-sens', 'set-sens2']) $(id).oninput = (e) => { settings.sens = +e.target.value; saveSettings(settings); applySettings(); };
for (const id of ['set-vol', 'set-vol2']) $(id).oninput = (e) => { settings.vol = +e.target.value; audio.setVol(settings.vol); saveSettings(settings); };
$('set-subs').onchange = (e) => { settings.subs = e.target.checked; saveSettings(settings); };
$('set-grain').onchange = (e) => { settings.grain = e.target.checked; saveSettings(settings); applySettings(); };
$('set-headbob').onchange = (e) => { settings.headbob = e.target.checked; saveSettings(settings); };

function startGame(fresh) {
  audio.init(); audio.uiClick();
  audio.startAmbience(); audio.startRain();
  $('menu').classList.add('hidden'); $('ending').classList.add('hidden'); $('pause').classList.add('hidden');
  $('hud').classList.remove('hidden');
  $('fade-black').style.opacity = '0';
  state = 'playing';
  player.frozen = false; player.hidden = null; player.sitting = false;
  document.getElementById('tab-unknown').classList.add('hidden');
  if (fresh) { clearSave(); story.newGame(); }
  else { const s = loadGame(); if (s) story.load(s); else story.newGame(); }
  refreshContinue();
  tryLock();
}
function pauseGame() {
  if (state !== 'playing' || story.uiBusy()) return;
  state = 'paused';
  saveGame(story.serialize());
  $('pause').classList.remove('hidden');
  document.exitPointerLock?.();
}
function resumeGame() {
  if (state !== 'paused') return;
  state = 'playing';
  $('pause').classList.add('hidden');
  tryLock();
}
function quitToMenu() {
  saveGame(story.serialize());
  state = 'menu';
  $('pause').classList.add('hidden'); $('hud').classList.add('hidden'); $('ending').classList.add('hidden');
  $('menu').classList.remove('hidden');
  phone.toggle(false);
  refreshContinue(); refreshEndings();
}
function rewind5() {
  // bad-end mercy: restart chapter 5 with chapter-appropriate gear
  $('ending').classList.add('hidden'); $('hud').classList.remove('hidden');
  state = 'playing';
  story.finished = false;
  story.flags = { deadbolt: true, batteries: true, masonNote: true, invitedMason: story.flags.invitedMason };
  story.items = { flash: true, flashOn: false, battery: 100, batteries: 1, parentsKey: false, carKeys: false, food: null, trash: false };
  story.micro = { state: 'idle', t: 0 }; story.newsT = 0; story.newsSeg = 0;
  story.policeT = -1; story.fuseN = 3;
  if (story.policeLight) { scene.remove(story.policeLight); story.policeLight = null; }
  world.setPower(true);
  world.setTV(false); audio.setTV(false);
  world.escapeWinCol.on = true;
  for (const [id, d] of world.doors) { d.open = id === 'bed' || id === 'bath'; d.target = d.open ? d.swing : 0; d.angle = d.target; d.hinge.rotation.y = d.angle; d.col.on = !d.open; d.locked = id === 'parents'; }
  enemy.state = 'dormant'; enemy.setVisible(false); enemy.speedMul = 1;
  enemy.aggression = Math.min(enemy.aggression, 2); // death shouldn't soft-lock difficulty
  player.hidden = null; player.sitting = false; player.frozen = false; player.noise = 0;
  player.pos.set(-5.5, CFG.eye, -3.5); player.setLook(0.3, 0);
  story.gotoChapter(5);
  tryLock();
}
$('btn-new').onclick = () => startGame(true);
$('btn-continue').onclick = () => startGame(false);
$('btn-resume').onclick = resumeGame;
$('btn-save').onclick = () => { saveGame(story.serialize()); audio.uiClick(); ui.toast('💾 Saved.'); };
$('btn-quit').onclick = quitToMenu;
$('btn-again').onclick = () => {
  const wasDeath = $('ending-title').textContent.includes('Taken');
  audio.uiClick();
  if (wasDeath) rewind5(); else startGame(true);
};
$('btn-tomenu').onclick = quitToMenu;
function refreshContinue() { $('btn-continue').disabled = !hasSave(); }

// ================= loop =================
const clock = new THREE.Clock();
function roomOf(p) {
  if (p.z >= 5.5) {
    if (Math.abs(p.x) < 3.4 && p.z < 8.4) return 'porch';
    return p.z >= 13.4 ? 'street' : 'yard';
  }
  return world.roomAt(p.x, p.z);
}
function animate() {
  requestAnimationFrame(animate);
  const dt = Math.min(clock.getDelta(), 0.05);
  if (state === 'playing') {
    const room = roomOf(player.pos);
    if (room !== lastRoom) { lastRoom = room; if (!story.finished) story.onRoom(room); }
    const indoor = !['porch', 'yard', 'street'].includes(room);
    player.update(dt, world.colliders, indoor);
    world.updateDoors(dt);
    world.updateRain(dt, rainOn && !indoor ? true : rainOn);
    story.update(dt);
    // flashlight follows view
    const on = story.flashOn;
    flash.intensity += ((on ? 55 : 0) - flash.intensity) * Math.min(1, dt * 10);
    flash.position.copy(camera.position);
    const dir = new THREE.Vector3(); camera.getWorldDirection(dir);
    flash.target.position.copy(camera.position).addScaledVector(dir, 9);
    // enemy
    const res = enemy.update(dt, player, world.colliders, story);
    if (res === 'caught' && !story.finished) {
      ui.jumpscare(() => story.finish('D', 'He was faster. He is always faster.'));
    }
    // escape B trigger: reached the street in chapter 6
    if (story.chapter === 6 && !story.finished && room === 'street') story.finish('B');
    // HUD meters
    $('stamina-fill').style.width = player.stamina + '%';
    $('noise-fill').style.width = Math.min(100, player.noise) + '%';
    $('battery').classList.toggle('hidden', !story.items.flash);
    $('battery-fill').style.width = story.items.battery + '%';
    // interact prompt
    const cur = interact.update(dt);
    if (cur) {
      $('prompt').classList.remove('hidden');
      $('prompt-key').textContent = cur.hold > 0 ? 'HOLD E' : 'E';
      $('prompt-text').textContent = cur.text;
      if (interact.holding && interact.holdNeed > 0) {
        $('holdbar').classList.remove('hidden');
        $('holdfill').style.width = Math.min(100, (interact.holdT / interact.holdNeed) * 100) + '%';
      } else $('holdbar').classList.add('hidden');
    } else { $('prompt').classList.add('hidden'); $('holdbar').classList.add('hidden'); }
    // camera shake
    if (shakeT > 0) {
      shakeT -= dt;
      camera.position.x += (Math.random() - 0.5) * 0.06;
      camera.position.y += (Math.random() - 0.5) * 0.06;
    }
    if (enemy.state === 'chase' && !story.finished) {
      camera.position.x += (Math.random() - 0.5) * 0.012;
    }
  }
  renderer.render(scene, camera);
}
addEventListener('resize', () => {
  camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
});

// boot
applySettings(); refreshEndings(); refreshContinue();
$('fade-black').style.opacity = '0';
animate();
