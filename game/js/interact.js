// INTERACT — registry of every usable thing. Raycast from screen center against
// registered meshes; nearest in range wins. Supports instant + hold-to-complete.
import * as THREE from 'three';
import { CFG } from './config.js';

export class Interact {
  constructor(camera, scene) {
    this.cam = camera; this.scene = scene;
    this.items = []; // {id, meshes[], prompt(ctx)->string|null, hold->sec|0, onUse(ctx)}
    this.ray = new THREE.Raycaster(); this.ray.far = CFG.interactRange + 0.6;
    this.current = null;
    this.holding = false; this.holdT = 0; this.holdNeed = 0;
    this.ctx = null; // set by main: {story, audio, player, world, ui...}
    this.meshMap = new Map();
  }
  add(def) {
    this.items.push(def);
    for (const m of def.meshes || []) this.meshMap.set(m.uuid, def);
    return def;
  }
  byId(id) { return this.items.find((i) => i.id === id); }
  // invisible sphere trigger helper (doors, windows, zones w/o exact mesh)
  halo(x, y, z, r = 0.55) {
    const m = new THREE.Mesh(new THREE.SphereGeometry(r, 8, 8),
      new THREE.MeshBasicMaterial({ visible: false }));
    m.position.set(x, y, z); this.scene.add(m); return m;
  }
  update(dt) {
    this.current = null;
    if (!this.ctx || this.ctx.uiBlocked()) { this.setHold(false); return null; }
    this.ray.setFromCamera(new THREE.Vector2(0, 0), this.cam);
    const meshes = [];
    for (const it of this.items) if (it.meshes) meshes.push(...it.meshes);
    const hits = this.ray.intersectObjects(meshes, false);
    for (const h of hits) {
      if (h.distance > CFG.interactRange) continue;
      const it = this.meshMap.get(h.object.uuid);
      if (!it) continue;
      const p = it.prompt ? it.prompt(this.ctx) : 'Use';
      if (p == null) continue;
      this.current = { def: it, text: p, hold: it.hold ? it.hold(this.ctx) : 0 };
      break;
    }
    // hold progress
    if (this.holding && this.current && this.current.hold > 0) {
      this.holdT += dt;
      if (this.holdT >= this.current.hold) {
        const c = this.current; this.setHold(false);
        c.def.onUse(this.ctx);
      }
    } else if (!this.holding) this.holdT = 0;
    return this.current;
  }
  setHold(h) {
    if (!h) { this.holding = false; this.holdT = 0; this.holdNeed = 0; return; }
    this.holding = true; this.holdT = 0;
    this.holdNeed = this.current ? this.current.hold : 0;
  }
  press() { // E pressed
    if (!this.current || !this.ctx || this.ctx.uiBlocked()) return;
    if (this.current.hold > 0) this.setHold(true);
    else this.current.def.onUse(this.ctx);
  }
  release() { this.setHold(false); }
}
