// PLAYER — first-person controller: pointer-lock look, WASD, sprint/stamina,
// crouch, head-bob, axis-separated AABB collision (no tunneling through corners).
import * as THREE from 'three';
import { CFG } from './config.js';

export class Player {
  constructor(camera, audio, settings) {
    this.cam = camera; this.audio = audio; this.set = settings;
    this.pos = new THREE.Vector3(0, CFG.eye, 7.2); // start on porch
    this.vel = new THREE.Vector3();
    this.yaw = Math.PI; this.pitch = 0; // facing the house (north = -Z)
    this.keys = {};
    this.stamina = CFG.staminaMax;
    this.crouch = false; this.sprint = false; this.moving = false;
    this.locked = false; this.frozen = true; // frozen until game starts / while UI open
    this.hidden = null;  // 'bed' | 'closet' | 'pcloset' | null
    this.sitting = false;
    this.bobT = 0; this.stepT = 0; this.noise = 0;
    this.eyeCur = CFG.eye;
    this.onStep = null;
  }
  setLook(yaw, pitch) { this.yaw = yaw; this.pitch = pitch; }
  lookAt(from, to) {
    this.pos.set(from[0], from[1], from[2]);
    const d = new THREE.Vector3(to[0] - from[0], to[1] - from[1], to[2] - from[2]);
    this.yaw = Math.atan2(-d.x, -d.z); this.pitch = Math.atan2(d.y, Math.hypot(d.x, d.z));
  }
  key(e, down) {
    const k = e.code;
    this.keys[k] = down;
    if (down && (k === 'KeyC' || k === 'ControlLeft')) this.crouch = !this.crouch;
    if (k === 'ShiftLeft' || k === 'ShiftRight') this.sprint = down;
  }
  mouse(dx, dy) {
    if (!this.locked || this.frozen) return;
    const s = 0.0023 * (this.set.sens ?? 1);
    this.yaw -= dx * s; this.pitch -= dy * s;
    this.pitch = Math.max(-1.45, Math.min(1.45, this.pitch));
  }
  collide(colliders) {
    const r = CFG.radius;
    // X axis
    this.pos.x += this.vel.x;
    for (const c of colliders) {
      if (!c.on) continue;
      if (this.pos.x + r > c.x0 && this.pos.x - r < c.x1 && this.pos.z + r > c.z0 && this.pos.z - r < c.z1) {
        this.pos.x = this.vel.x > 0 ? c.x0 - r : c.x1 + r;
      }
    }
    // Z axis
    this.pos.z += this.vel.z;
    for (const c of colliders) {
      if (!c.on) continue;
      if (this.pos.x + r > c.x0 && this.pos.x - r < c.x1 && this.pos.z + r > c.z0 && this.pos.z - r < c.z1) {
        this.pos.z = this.vel.z > 0 ? c.z0 - r : c.z1 + r;
      }
    }
    // world bounds
    this.pos.x = Math.max(-26, Math.min(26, this.pos.x));
    this.pos.z = Math.max(-7.6, Math.min(16.4, this.pos.z));
  }
  update(dt, colliders, indoor) {
    // inertia-free but smoothed
    let ix = 0, iz = 0;
    if (!this.frozen && !this.hidden && !this.sitting) {
      if (this.keys['KeyW'] || this.keys['ArrowUp']) iz -= 1;
      if (this.keys['KeyS'] || this.keys['ArrowDown']) iz += 1;
      if (this.keys['KeyA'] || this.keys['ArrowLeft']) ix -= 1;
      if (this.keys['KeyD'] || this.keys['ArrowRight']) ix += 1;
    }
    this.moving = (ix !== 0 || iz !== 0);
    const wantSprint = this.sprint && this.moving && iz < 0 && !this.crouch && this.stamina > CFG.sprintMin;
    if (wantSprint) this.stamina = Math.max(0, this.stamina - CFG.staminaDrain * dt);
    else this.stamina = Math.min(CFG.staminaMax, this.stamina + CFG.staminaRegen * dt);
    const speed = this.crouch ? CFG.crouch : wantSprint ? CFG.sprint : CFG.walk;
    this.isSprinting = wantSprint;
    // forward is -Z rotated by yaw; right is perpendicular
    const fx = -Math.sin(this.yaw), fz = -Math.cos(this.yaw);
    const rx = Math.cos(this.yaw), rz = -Math.sin(this.yaw);
    this.vel.set((fx * -iz + rx * ix) * speed * dt, 0, (fz * -iz + rz * ix) * speed * dt);
    this.collide(colliders);

    // eye height + head bob
    const targetEye = this.crouch ? CFG.eyeCrouch : CFG.eye;
    this.eyeCur += (targetEye - this.eyeCur) * Math.min(1, dt * 8);
    let bobY = 0;
    if (this.moving && !this.hidden && !this.sitting) {
      this.bobT += dt * (wantSprint ? 11 : 7.5);
      const amp = this.set.headbob === false ? 0 : wantSprint ? 0.055 : 0.032;
      bobY = Math.abs(Math.sin(this.bobT)) * amp;
      this.stepT -= dt;
      if (this.stepT <= 0) {
        this.stepT = wantSprint ? 0.32 : this.crouch ? 0.62 : 0.46;
        this.audio.footstep(wantSprint, this.crouch, indoor);
        const n = wantSprint ? 34 : this.crouch ? 2 : 9;
        this.noise = Math.min(100, this.noise + n);
        if (this.onStep) this.onStep(wantSprint ? 'run' : 'walk');
      }
    }
    // hidden: tiny tremble
    if (this.hidden) bobY = Math.sin(performance.now() * 0.02) * 0.004;
    this.noise = Math.max(0, this.noise - CFG.noiseDecay * dt * (this.moving ? 0.4 : 1));
    this.cam.position.set(this.pos.x, this.eyeCur + bobY, this.pos.z);
    this.cam.rotation.order = 'YXZ';
    this.cam.rotation.y = this.yaw; this.cam.rotation.x = this.pitch; this.cam.rotation.z = 0;
  }
}
