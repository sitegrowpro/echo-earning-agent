// ENEMY — "The Stranger". Scripted perches early (seen through windows / peephole),
// then a real hunter AI: patrol → investigate noise → chase on sight → search → lose.
// Kill on touch unless the player is properly hidden (dark + still + enclosed).
import * as THREE from 'three';
import { CFG } from './config.js';

function segHitsCol(x0, z0, x1, z1, c) {
  // segment vs AABB (slab test), 2D
  const dx = x1 - x0, dz = z1 - z0;
  let tmin = 0, tmax = 1;
  if (Math.abs(dx) < 1e-8) { if (x0 < c.x0 || x0 > c.x1) return false; }
  else {
    let t1 = (c.x0 - x0) / dx, t2 = (c.x1 - x0) / dx;
    if (t1 > t2) [t1, t2] = [t2, t1];
    tmin = Math.max(tmin, t1); tmax = Math.min(tmax, t2);
    if (tmin > tmax) return false;
  }
  if (Math.abs(dz) < 1e-8) { if (z0 < c.z0 || z0 > c.z1) return false; }
  else {
    let t1 = (c.z0 - z0) / dz, t2 = (c.z1 - z0) / dz;
    if (t1 > t2) [t1, t2] = [t2, t1];
    tmin = Math.max(tmin, t1); tmax = Math.min(tmax, t2);
    if (tmin > tmax) return false;
  }
  return true;
}

export class Enemy {
  constructor(scene, audio) {
    this.scene = scene; this.audio = audio;
    this.state = 'dormant'; // dormant|perch|patrol|investigate|chase|search|gone
    this.aggression = 0;    // raised by player choices (opening door, inviting Mason...)
    this.pos = new THREE.Vector3(8, 0, 12.5);
    this.face = Math.PI;
    this.target = null; this.loseT = 0; this.searchT = 0; this.scareArmed = true;
    this.speedMul = 1;
    this.buildMesh();
    this.setVisible(false);
    // indoor patrol loop: every leg verified against the floorplan — through door
    // centers and arch openings only, endpoints clear of furniture + enemy radius.
    // Starts outside the parents' door (he spawns in the parents' room).
    this.waypoints = [
      [1.8, -0.5],
      [0, -0.5],
      [-4.5, -0.5], [-4.5, 2.6], [-4.5, -0.5],          // living-room peek via arch
      [-5.5, -0.5], [-5.0, -2.8], [-5.5, -0.5],          // bedroom dip through door
      [0, -0.5],
      [4.5, -0.5], [4.5, 1.5], [2.9, 1.5], [2.9, 4.0], [2.9, 1.5], [4.5, 1.5], [4.5, -0.5], // kitchen dip
      [6.0, -0.5], [5.2, -0.5], [5.2, -2.6], [5.2, -0.5], // bathroom dip through door
      [1.8, -0.5], [2.3, -3.0], [1.8, -0.5],            // parents' dip, ends at start = clean loop
    ];
    this.wp = 0;
  }
  buildMesh() {
    const g = new THREE.Group();
    const cloth = new THREE.MeshStandardMaterial({ color: 0x0d0d10, roughness: 1 });
    const skin = new THREE.MeshStandardMaterial({ color: 0xb9a88f, roughness: 0.9 });
    const torso = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.9, 0.3), cloth); torso.position.y = 1.15; g.add(torso);
    const legs = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.75, 0.26), cloth); legs.position.y = 0.38; g.add(legs);
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.16, 12, 10), skin); head.position.y = 1.78; g.add(head);
    const eyeM = new THREE.MeshStandardMaterial({ color: 0x000000, emissive: 0xffffff, emissiveIntensity: 0.7 });
    for (const sx of [-0.06, 0.06]) {
      const e = new THREE.Mesh(new THREE.SphereGeometry(0.022, 6, 6), eyeM);
      e.position.set(sx, 1.8, 0.14); g.add(e);
    }
    // long arms
    for (const sx of [-0.32, 0.32]) {
      const a = new THREE.Mesh(new THREE.BoxGeometry(0.11, 0.85, 0.11), cloth);
      a.position.set(sx, 1.05, 0); g.add(a);
    }
    g.traverse((o) => { if (o.isMesh) o.castShadow = true; });
    this.mesh = g; this.scene.add(g);
  }
  setVisible(v) { this.mesh.visible = v; }
  place(x, z, face) { this.pos.set(x, 0, z); this.face = face ?? this.face; this.sync(); }
  perch(p) { this.place(p.x, p.z, p.face); this.state = 'perch'; this.setVisible(true); }
  sync() { this.mesh.position.copy(this.pos); this.mesh.rotation.y = this.face; }
  canSee(player, colliders) {
    const dx = player.pos.x - this.pos.x, dz = player.pos.z - this.pos.z;
    const dist = Math.hypot(dx, dz);
    const range = CFG.enemy.sightRange + this.aggression * 1.5;
    if (dist > range) return false;
    // facing check
    const fx = Math.sin(this.face), fz = Math.cos(this.face);
    const dot = (dx * fx + dz * fz) / (dist || 1);
    if (dist > 2.2 && dot < CFG.enemy.sightFov) return false;
    // LOS vs sight-blocking colliders
    const ex = this.pos.x, ez = this.pos.z;
    for (const c of colliders) {
      if (!c.on || !c.sight) continue;
      // ignore the collider the enemy itself stands in (doorways)
      if (ex > c.x0 - 0.3 && ex < c.x1 + 0.3 && ez > c.z0 - 0.3 && ez < c.z1 + 0.3) continue;
      if (segHitsCol(ex, ez, player.pos.x, player.pos.z, c)) return false;
    }
    // darkness + crouch + still = much harder to spot
    if (player.crouch && !player.moving && dist > 3.5) return false;
    return true;
  }
  moveToward(tx, tz, speed, dt, colliders) {
    const dx = tx - this.pos.x, dz = tz - this.pos.z;
    const d = Math.hypot(dx, dz);
    if (d < 0.05) return true;
    const step = Math.min(d, speed * dt);
    const nx = this.pos.x + (dx / d) * step, nz = this.pos.z + (dz / d) * step;
    // collide naively (slide per axis)
    const r = 0.3;
    let bx = nx, bz = nz;
    for (const c of colliders) {
      if (!c.on) continue;
      if (bx + r > c.x0 && bx - r < c.x1 && this.pos.z + r > c.z0 && this.pos.z - r < c.z1) bx = this.pos.x;
      if (this.pos.x + r > c.x0 && this.pos.x - r < c.x1 && bz + r > c.z0 && bz - r < c.z1) bz = this.pos.z;
    }
    this.pos.x = bx; this.pos.z = bz;
    this.face = Math.atan2(dx, dz);
    return d < 0.4;
  }
  update(dt, player, colliders, story) {
    if (this.state === 'dormant' || this.state === 'gone' || this.state === 'perch') { this.sync(); return null; }
    const E = CFG.enemy;
    const seen = this.canSee(player, colliders);
    const heard = player.noise > 45 && Math.hypot(player.pos.x - this.pos.x, player.pos.z - this.pos.z) < E.hearRadius + player.noise * 0.05;

    // hidden players: only found if noisy (moved / light on / big noise recently)
    const hiddenSafe = player.hidden && player.noise < 30 && !story.flashOn;

    if ((seen && !hiddenSafe) || (player.hidden && player.noise > 55)) {
      if (this.state !== 'chase') story.onSpotted();
      this.state = 'chase'; this.loseT = 0;
      this.target = { x: player.pos.x, z: player.pos.z };
    } else if (this.state === 'chase') {
      this.loseT += dt;
      this.target = { x: player.pos.x, z: player.pos.z };
      if (this.loseT > E.loseTime) { this.state = 'search'; this.searchT = 0; }
    } else if (heard && this.state !== 'investigate') {
      this.state = 'investigate';
      this.target = { x: player.pos.x, z: player.pos.z };
    }

    const sp = this.speedMul;
    if (this.state === 'chase') {
      this.moveToward(this.target.x, this.target.z, E.chase * sp, dt, colliders);
      const d = Math.hypot(player.pos.x - this.pos.x, player.pos.z - this.pos.z);
      if (d < E.catchDist) {
        if (hiddenSafe && this.scareArmed) { /* last-second mercy: he lingers */ }
        else return 'caught';
      }
    } else if (this.state === 'investigate') {
      if (this.moveToward(this.target.x, this.target.z, E.investigate * sp, dt, colliders)) {
        this.state = 'search'; this.searchT = 0;
      }
    } else if (this.state === 'search') {
      this.searchT += dt;
      this.face += dt * 1.4;
      if (this.searchT > 6) { this.state = 'patrol'; }
    } else if (this.state === 'patrol') {
      const w = this.waypoints[this.wp];
      if (this.moveToward(w[0], w[1], E.patrol * sp, dt, colliders)) this.wp = (this.wp + 1) % this.waypoints.length;
    }
    // head sway while hunting
    this.mesh.position.y = Math.abs(Math.sin(performance.now() * 0.004)) * 0.03;
    this.sync();
    return this.state;
  }
  vanish() { this.state = 'gone'; this.setVisible(false); }
}
