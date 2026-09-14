// WORLD — floorplan-first construction. The house is NOT random boxes: every wall
// is an intentional room boundary from the plan below, and every door is a named
// entity with a purpose, hinge, lock state and collider. Colliders derive from the
// same wall data, so visuals and collision can never disagree ("random walls" bug).
//
// PLAN (meters, X east / Z south, walls 0.2 thick, 2.8 high):
//   Z -5.5 ┌──────────┬─────────────┬───────┬───────┐
//          │ BEDROOM  │ PARENTS RM  │ BATH  │ UTILITY│  (fuse box in utility)
//   Z -1.5 │  (you)   │  (locked)   │       │       │  doors D_BED D_PAR D_BATH D_UTIL
//          ├──────────┴─────────────┴───────┴───────┤
//          │            HALLWAY (thermostat, photos) │
//   Z  0.5 ├──────────┐               ┌─────────────┤  arches (always open)
//          │ LIVING   │               │ KITCHEN     │
//          │ (TV etc) │               │ (food etc)  │  divider X=0 w/ wide opening
//   Z  5.5 └───w──────┴───[FRONT]─────┴───w─────────┘  door D_FRONT + 2 windows
//   Z  5.5..8: PORCH (mailbox, trash) → yard → street → neighbor (escape)
import * as THREE from 'three';

const H = 2.8, T = 0.2;
const X0 = -8, X1 = 8, ZN = -5.5, ZS = 5.5;

function mat(color, rough = 0.85, extra = {}) {
  return new THREE.MeshStandardMaterial({ color, roughness: rough, metalness: 0.02, ...extra });
}

export class World {
  constructor(scene) {
    this.scene = scene;
    this.colliders = [];   // {x0,z0,x1,z1,sight,on}
    this.doors = new Map();// id -> door record
    this.roomLights = {};  // room -> {lights:[], on:true}
    this.power = true;
    this.rainPts = null; this.rainVel = null;
    this.tvOn = false;
    this.build();
  }

  addCol(x0, z0, x1, z1, sight = true) {
    const c = { x0: Math.min(x0, x1), z0: Math.min(z0, z1), x1: Math.max(x0, x1), z1: Math.max(z0, z1), sight, on: true };
    this.colliders.push(c); return c;
  }
  box(w, h, d, m, x, y, z, ry = 0, collide = false, sight = false) {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m);
    mesh.position.set(x, y, z); mesh.rotation.y = ry;
    mesh.castShadow = false; mesh.receiveShadow = true;
    this.scene.add(mesh);
    if (collide) {
      const hw = (ry ? d : w) / 2, hd = (ry ? w : d) / 2;
      this.addCol(x - hw, z - hd, x + hw, z + hd, sight);
    }
    return mesh;
  }

  // ---- wall runs with intentional holes ----
  runH(z, x1, x2, holes = [], material) {
    holes = [...holes].sort((a, b) => a.at - b.at);
    let cx = x1;
    const segs = [];
    for (const h of holes) {
      const hx0 = x1 + h.at - h.w / 2, hx1 = x1 + h.at + h.w / 2;
      segs.push([cx, hx0]);
      this.finishHoleH(z, hx0, hx1, h, material);
      cx = hx1;
    }
    segs.push([cx, x2]);
    for (const [a, b] of segs) {
      if (b - a < 0.01) continue;
      this.box(b - a, H, T, material, (a + b) / 2, H / 2, z);
      this.addCol(a, z - T / 2, b, z + T / 2, true);
    }
  }
  finishHoleH(z, hx0, hx1, h, material) {
    const y0 = h.y0 ?? 0, y1 = h.y1 ?? 2.15, w = hx1 - hx0, cx = (hx0 + hx1) / 2;
    if (y1 < H - 0.01) { // lintel
      this.box(w, H - y1, T, material, cx, (H + y1) / 2, z);
      this.addCol(hx0, z - T / 2, hx1, z + T / 2, true); // lintel => sight blocked above, but keep simple: hole sides handle it
      this.colliders.pop(); // don't block: lintel is overhead. (Doors/windows add their own colliders.)
    }
    if (y0 > 0.01) { // sill wall
      this.box(w, y0, T, material, cx, y0 / 2, z);
      this.addCol(hx0, z - T / 2, hx1, z + T / 2, false);
    }
    this.trimH(z, hx0, hx1, y0, y1);
    if (h.kind === 'window' || h.kind === 'escape-window') this.windowGlass(cx, (y0 + y1) / 2, z, w, y1 - y0, 'H');
  }
  runV(x, z1, z2, holes = [], material) {
    holes = [...holes].sort((a, b) => a.at - b.at);
    let cz = z1;
    const segs = [];
    for (const h of holes) {
      const hz0 = z1 + h.at - h.w / 2, hz1 = z1 + h.at + h.w / 2;
      segs.push([cz, hz0]);
      const y0 = h.y0 ?? 0, y1 = h.y1 ?? 2.15, w = hz1 - hz0, czz = (hz0 + hz1) / 2;
      if (y1 < H - 0.01) this.box(T, H - y1, w, material, x, (H + y1) / 2, czz);
      if (y0 > 0.01) { this.box(T, y0, w, material, x, y0 / 2, czz); this.addCol(x - T / 2, hz0, x + T / 2, hz1, false); }
      this.trimV(x, hz0, hz1, y0, y1);
      if (h.kind === 'window') this.windowGlass(x, (y0 + y1) / 2, czz, w, y1 - y0, 'V');
      cz = hz1;
    }
    segs.push([cz, z2]);
    for (const [a, b] of segs) {
      if (b - a < 0.01) continue;
      this.box(T, H, b - a, material, x, H / 2, (a + b) / 2);
      this.addCol(x - T / 2, a, x + T / 2, b, true);
    }
  }
  trimH(z, hx0, hx1, y0, y1) {
    const tm = mat(0x4a3524, 0.7), w = 0.09;
    this.box(w, y1 - y0, T + 0.06, tm, hx0 + w / 2, (y0 + y1) / 2, z);
    this.box(w, y1 - y0, T + 0.06, tm, hx1 - w / 2, (y0 + y1) / 2, z);
    this.box(hx1 - hx0 + w, w, T + 0.06, tm, (hx0 + hx1) / 2, y1 - w / 2, z);
  }
  trimV(x, hz0, hz1, y0, y1) {
    const tm = mat(0x4a3524, 0.7), w = 0.09;
    this.box(T + 0.06, y1 - y0, w, tm, x, (y0 + y1) / 2, hz0 + w / 2);
    this.box(T + 0.06, y1 - y0, w, tm, x, (y0 + y1) / 2, hz1 - w / 2);
    this.box(T + 0.06, w, hz1 - hz0 + w, tm, x, y1 - w / 2, (hz0 + hz1) / 2);
  }
  windowGlass(cx, cy, cz, w, h, orient) {
    const g = new THREE.Mesh(
      new THREE.PlaneGeometry(w - 0.1, h - 0.1),
      new THREE.MeshStandardMaterial({ color: 0x8fa8c8, transparent: true, opacity: 0.16, roughness: 0.1, metalness: 0.4, side: THREE.DoubleSide })
    );
    g.position.set(cx, cy, cz);
    if (orient === 'V') g.rotation.y = Math.PI / 2;
    this.scene.add(g);
    // cross frame
    const fm = mat(0x2c2c34, 0.6);
    if (orient === 'H') {
      this.box(w - 0.1, 0.05, 0.05, fm, cx, cy, cz);
      this.box(0.05, h - 0.1, 0.05, fm, cx, cy, cz);
      this.box(w + 0.1, 0.07, 0.3, mat(0x6b5b45, 0.8), cx, cy - h / 2, cz); // sill
    } else {
      this.box(0.05, 0.05, w - 0.1, fm, cx, cy, cz);
      this.box(0.05, h - 0.1, 0.05, fm, cx, cy, cz);
      this.box(0.3, 0.07, w + 0.1, mat(0x6b5b45, 0.8), cx, cy - h / 2, cz);
    }
  }

  // ---- doors: hinge group + animated panel + dynamic collider ----
  addDoor(id, x, z, w, swing, opts = {}) {
    // panel spans +X from hinge when closed; swing rotates about Y.
    const hinge = new THREE.Group(); hinge.position.set(x, 0, z);
    const panelMat = mat(opts.color ?? 0x5d4630, 0.65);
    const panel = new THREE.Mesh(new THREE.BoxGeometry(w, 2.06, 0.07), panelMat);
    panel.position.set(w / 2, 1.05, 0); panel.castShadow = true;
    hinge.add(panel);
    // inset panels + knob for craft
    const inset = mat(0x4e3a27, 0.7);
    for (const [iy, ih] of [[1.45, 0.7], [0.55, 0.7]]) {
      const p = new THREE.Mesh(new THREE.BoxGeometry(w - 0.3, ih, 0.02), inset);
      p.position.set(w / 2, iy, 0.045); hinge.add(p);
      const p2 = p.clone(); p2.position.z = -0.045; hinge.add(p2);
    }
    const knob = new THREE.Mesh(new THREE.SphereGeometry(0.045, 12, 10), mat(0xc9a227, 0.35, { metalness: 0.7 }));
    knob.position.set(w - 0.16, 1.02, 0.08); hinge.add(knob);
    const knob2 = knob.clone(); knob2.position.z = -0.08; hinge.add(knob2);
    this.scene.add(hinge);
    // closed-door collider spans the opening
    const col = this.addCol(x - 0.05, z - T / 2 - 0.05, x + w + 0.05, z + T / 2 + 0.05, true);
    const door = {
      id, hinge, w, swing, angle: 0, target: 0,
      locked: !!opts.locked, col,
      open: opts.open ?? false,
      label: opts.label ?? id,
    };
    if (door.open) { door.angle = swing; door.target = swing; col.on = false; }
    this.doors.set(id, door);
    return door;
  }
  updateDoors(dt) {
    for (const d of this.doors.values()) {
      if (Math.abs(d.target - d.angle) < 0.001) continue;
      const dir = Math.sign(d.target - d.angle);
      d.angle += dir * Math.min(Math.abs(d.target - d.angle), dt * 2.6);
      d.hinge.rotation.y = d.angle;
      // collider live only when nearly closed
      d.col.on = Math.abs(d.angle) < 0.25 && !d.open ? true : Math.abs(d.angle) < 0.25;
      if (d.open && Math.abs(d.angle) < 0.25 && d.target !== 0) d.col.on = false;
    }
  }

  roomLight(room, light) {
    (this.roomLights[room] ??= { lights: [], on: true }).lights.push(light);
  }
  setRoomLight(room, on) {
    const r = this.roomLights[room]; if (!r) return;
    r.on = on; this.applyLights();
  }
  setPower(on) {
    this.power = on; this.applyLights();
    if (!on) this.setTV(false);
  }
  applyLights() {
    for (const r of Object.values(this.roomLights))
      for (const l of r.lights) l.visible = this.power && r.on;
    if (this.porchLight) this.porchLight.visible = this.power && this.porchOn;
  }
  setTV(on) {
    this.tvOn = on;
    if (this.tvScreen) this.tvScreen.material.emissiveIntensity = on ? 1.6 : 0.02;
    if (this.tvGlow) this.tvGlow.visible = on && this.power;
  }

  build() {
    const wallIn = mat(0xb8ab90, 0.9), wallOut = mat(0x6e6a63, 0.95);
    const ceilM = mat(0xd8d2c2, 0.95);

    // ===== floors (per room, intentional) =====
    const floor = (x0, z0, x1, z1, m) => {
      const f = new THREE.Mesh(new THREE.PlaneGeometry(x1 - x0, z1 - z0), m);
      f.rotation.x = -Math.PI / 2; f.position.set((x0 + x1) / 2, 0.01, (z0 + z1) / 2);
      f.receiveShadow = true; this.scene.add(f);
    };
    const wood = mat(0x7a5c3d, 0.7), tile = mat(0x9aa0a3, 0.4), carpet = mat(0x4c4458, 1), conc = mat(0x5b5b60, 0.95);
    floor(X0, 0.5, 0, ZS, wood);        // living
    floor(0, 0.5, X1, ZS, tile);        // kitchen
    floor(X0, -1.5, X1, 0.5, wood);     // hall
    floor(X0, ZN, -2, -1.5, carpet);    // bedroom
    floor(-2, ZN, 4, -1.5, carpet);     // parents
    floor(4, ZN, 6.5, -1.5, tile);      // bath
    floor(6.5, ZN, X1, -1.5, conc);     // utility
    // ceiling + roof
    const ceil = new THREE.Mesh(new THREE.PlaneGeometry(X1 - X0 + 1, ZS - ZN + 1), ceilM);
    ceil.rotation.x = Math.PI / 2; ceil.position.set(0, H, 0); this.scene.add(ceil);
    this.box(X1 - X0 + 1.6, 0.25, ZS - ZN + 1.6, mat(0x1a1a20, 1), 0, H + 0.2, 0);

    // ===== walls (exterior) =====
    // south: front door at X=0 (at=8), living window (at=3.5), kitchen window (at=12.5)
    this.runH(ZS, X0, X1, [
      { at: 3.5, w: 1.9, y0: 0.95, y1: 2.25, kind: 'window' },
      { at: 8, w: 1.15, y0: 0, y1: 2.15, kind: 'door' },
      { at: 12.5, w: 1.9, y0: 0.95, y1: 2.25, kind: 'window' },
    ], wallOut);
    // north: bedroom escape window, parents window, bath high window
    this.runH(ZN, X0, X1, [
      { at: 2.5, w: 1.5, y0: 0.9, y1: 2.2, kind: 'escape-window' },
      { at: 9.5, w: 1.5, y0: 0.95, y1: 2.25, kind: 'window' },
      { at: 13.2, w: 0.8, y0: 1.5, y1: 2.25, kind: 'window' },
    ], wallOut);
    // west: living side window at Z=3 (at=8.5)
    this.runV(X0, ZN, ZS, [{ at: 8.5, w: 1.6, y0: 0.95, y1: 2.25, kind: 'window' }], wallOut);
    // east: kitchen side window at Z=3
    this.runV(X1, ZN, ZS, [{ at: 8.5, w: 1.4, y0: 0.95, y1: 2.25, kind: 'window' }], wallOut);

    // ===== walls (interior) =====
    this.runH(0.5, X0, X1, [ // hall south wall: two arches
      { at: 3.5, w: 1.7, y0: 0, y1: 2.3, kind: 'arch' },
      { at: 12.5, w: 1.7, y0: 0, y1: 2.3, kind: 'arch' },
    ], wallIn);
    this.runH(-1.5, X0, X1, [ // hall north wall: 4 doors
      { at: 2.5, w: 1.0, kind: 'door' },   // bedroom
      { at: 9.5, w: 1.0, kind: 'door' },   // parents
      { at: 13.2, w: 0.9, kind: 'door' },  // bath
      { at: 15.25, w: 0.85, kind: 'door' },// utility
    ], wallIn);
    this.runV(0, 0.5, ZS, [{ at: 2.5, w: 2.1, y0: 0, y1: 2.3, kind: 'arch' }], wallIn); // living|kitchen
    this.runV(-2, ZN, -1.5, [], wallIn);   // bedroom|parents
    this.runV(4, ZN, -1.5, [], wallIn);    // parents|bath
    this.runV(6.5, ZN, -1.5, [], wallIn);  // bath|utility

    // window passage blockers (glass you can't walk through, but sight passes)
    const winBlock = (x0, z0, x1, z1) => this.addCol(x0, z0, x1, z1, false);
    winBlock(-5.45, ZS - 0.15, -3.55, ZS + 0.15); // living front
    winBlock(3.55, ZS - 0.15, 5.45, ZS + 0.15);   // kitchen front
    winBlock(-6.25, ZN - 0.15, -4.75, ZN + 0.15); // bedroom escape
    winBlock(0.75, ZN - 0.15, 2.25, ZN + 0.15);   // parents
    winBlock(4.8, ZN - 0.15, 5.6, ZN + 0.15);     // bath
    winBlock(X0 - 0.15, 2.2, X0 + 0.15, 3.8);
    winBlock(X1 - 0.15, 2.3, X1 + 0.15, 3.7);
    this.escapeWinCol = this.colliders[this.colliders.length - 5]; // bedroom window blocker (removed on escape)

    // ===== doors (named, purposeful) =====
    this.addDoor('front', -0.575, ZS, 1.09, +1.92, { label: 'Front door', color: 0x6e2f26 });
    this.addDoor('bed', -6.0, -1.5, 0.94, +1.92, { label: 'Bedroom door', open: true });
    this.addDoor('parents', 1.0, -1.5, 0.94, +1.92, { label: 'Parents’ door', locked: true });
    this.addDoor('bath', 4.75, -1.5, 0.84, +1.92, { label: 'Bathroom door', open: true });
    this.addDoor('util', 6.825, -1.5, 0.79, +1.92, { label: 'Utility door' });

    this.furnish();
    this.lightRig();
    this.outside();
  }

  furnish() {
    const woodD = mat(0x4f3a26, 0.7), fabric = mat(0x37455c, 1), fabric2 = mat(0x5c3737, 1);
    const white = mat(0xd9d9d9, 0.6), steel = mat(0x8a8f94, 0.35, { metalness: 0.5 });
    // ---- LIVING (TV on hall wall X=-2 segment... free span; couch faces north) ----
    // TV stand + TV at (-2, z 0.75)
    this.box(1.5, 0.45, 0.45, woodD, -2, 0.22, 0.85, 0, true);
    const tv = this.box(1.35, 0.78, 0.08, mat(0x0a0a0c, 0.4), -2, 0.9, 0.78);
    this.tvScreen = new THREE.Mesh(new THREE.PlaneGeometry(1.24, 0.68),
      new THREE.MeshStandardMaterial({ color: 0x050507, emissive: 0x8fb4ff, emissiveIntensity: 0.02 }));
    this.tvScreen.position.set(-2, 0.9, 0.83); this.scene.add(this.tvScreen);
    this.tvGlow = new THREE.PointLight(0x8fb4ff, 0, 7); this.tvGlow.position.set(-2, 1.1, 1.6); this.scene.add(this.tvGlow);
    // couch + coffee table + rug
    this.box(2.2, 0.5, 0.95, fabric, -2, 0.35, 3.3, 0, true);          // seat
    this.box(2.2, 0.65, 0.28, fabric, -2, 0.75, 3.75, 0, true);        // backrest
    this.box(0.28, 0.65, 0.95, fabric, -3.0, 0.5, 3.3, 0, false);      // arms
    this.box(0.28, 0.65, 0.95, fabric, -1.0, 0.5, 3.3, 0, false);
    this.box(1.2, 0.4, 0.6, woodD, -2, 0.2, 2.1, 0, true);             // coffee table
    this.box(3.0, 0.03, 2.2, mat(0x6e3b3b, 1), -2, 0.03, 2.9);         // rug
    // bookshelf west wall + floor lamp + photo table
    this.box(0.4, 1.9, 2.4, woodD, -7.7, 0.95, 2.6, 0, true);
    for (let i = 0; i < 3; i++) this.box(0.34, 0.28, 2.1, [mat(0x7a2e2e, 1), mat(0x2e4a7a, 1), mat(0x3f7a2e, 1)][i], -7.7, 0.6 + i * 0.5, 2.6);
    this.box(0.35, 1.6, 0.35, mat(0x222226, 0.6), -7.3, 0.8, 4.9, 0, true); // lamp stand
    this.box(0.55, 0.4, 0.55, mat(0xf3e3b3, 0.9, { emissive: 0xffe6a3, emissiveIntensity: 0.4 }), -7.3, 1.75, 4.9);
    this.box(0.9, 0.75, 0.45, woodD, -7.6, 0.37, 0.95, 0, true);       // side table (photo note)
    // ---- KITCHEN ----
    this.box(0.7, 0.9, 3.4, mat(0xcfc8b8, 0.6), 7.55, 0.45, 3.3, 0, true);  // counter run
    this.box(0.75, 0.06, 3.5, mat(0x3d3d44, 0.4), 7.55, 0.93, 3.3);         // countertop
    this.box(0.6, 0.5, 0.9, mat(0x222226, 0.5), 7.5, 1.2, 1.9, 0, false);   // microwave body
    this.microDoor = this.box(0.05, 0.36, 0.7, mat(0x111114, 0.2), 7.18, 1.2, 1.9);
    this.microLight = new THREE.PointLight(0xffd489, 0, 3); this.microLight.position.set(7.2, 1.3, 1.9); this.scene.add(this.microLight);
    this.box(0.7, 0.9, 0.8, white, 7.55, 0.45, 5.0, 0, true);               // stove
    this.box(0.5, 0.1, 0.6, mat(0x1c1c20, 0.5), 7.55, 0.93, 5.0);           // burners
    this.box(0.9, 1.9, 0.9, steel, 7.4, 0.95, 1.0, 0, true, true);          // fridge (tall: sight blocker)
    // island with drawer (key!) + groceries
    this.box(1.8, 0.9, 0.9, mat(0x8a7a5f, 0.7), 4.2, 0.45, 3.3, 0, true);
    this.box(1.9, 0.06, 1.0, mat(0x3d3d44, 0.4), 4.2, 0.93, 3.3);
    this.box(0.5, 0.35, 0.4, mat(0xb08945, 0.9), 3.7, 1.13, 3.2);           // grocery bag
    this.box(0.4, 0.3, 0.35, mat(0x9db87f, 0.9), 4.6, 1.1, 3.45);           // grocery box
    // dinette
    this.box(1.1, 0.75, 1.1, woodD, 1.8, 0.37, 4.6, 0, true);
    this.box(0.45, 0.8, 0.45, woodD, 1.8, 0.4, 3.8, 0, true);
    this.box(0.45, 0.8, 0.45, woodD, 2.6, 0.4, 4.6, 0, true);
    // ---- HALL ----
    this.box(1.4, 0.8, 0.35, woodD, -3.5, 0.4, -1.25, 0, true);             // console
    this.box(3.5, 0.03, 0.9, mat(0x54432f, 1), -1, 0.03, -0.5);            // runner
    // ---- BEDROOM (yours) ----
    this.box(1.7, 0.55, 2.2, mat(0x2e3a5c, 1), -6.4, 0.32, -4.2, 0, true); // bed base
    this.box(1.7, 0.18, 2.2, mat(0x7a8bb0, 1), -6.4, 0.65, -4.2);          // mattress... blanket
    this.box(1.7, 0.9, 0.15, woodD, -6.4, 0.6, -5.35, 0, true);            // headboard
    this.box(0.7, 0.15, 0.45, white, -6.7, 0.78, -4.9);                    // pillow
    this.box(0.7, 0.15, 0.45, white, -6.1, 0.78, -4.9);
    this.box(0.5, 0.55, 0.5, woodD, -7.5, 0.27, -5.1, 0, true);            // nightstand
    this.box(1.4, 0.75, 0.6, woodD, -3.0, 0.37, -5.05, 0, true);           // desk
    this.box(0.5, 0.5, 0.5, fabric2, -3.0, 0.25, -4.3, 0, true);           // chair
    this.box(0.5, 0.06, 0.35, mat(0x3a3f4a, 0.5), -3.2, 0.78, -5.05);      // laptop(closed)/books
    this.box(0.35, 0.12, 0.28, mat(0xa33c3c, 0.8), -2.7, 0.8, -5.1);       // homework stack
    this.box(1.3, 2.0, 0.6, woodD, -2.7, 1.0, -2.0, 0, true, true);        // wardrobe (hide!) tall
    this.box(0.04, 1.7, 0.5, mat(0x33261a, 0.7), -3.36, 1.0, -2.0);        // wardrobe door face
    // posters
    const poster = (x, z, c) => {
      const p = new THREE.Mesh(new THREE.PlaneGeometry(0.7, 0.95), mat(c, 0.9));
      p.position.set(x, 1.7, z); this.scene.add(p);
    };
    poster(-5.2, -5.38, 0x24406b); poster(-4.3, -5.38, 0x6b2424);
    // ---- PARENTS ----
    this.box(1.9, 0.55, 2.2, mat(0x5c4a6e, 1), 0.6, 0.32, -4.2, 0, true);
    this.box(1.9, 0.18, 2.2, mat(0x9a8bb0, 1), 0.6, 0.65, -4.2);
    this.box(1.9, 0.9, 0.15, woodD, 0.6, 0.6, -5.35, 0, true);
    this.box(1.5, 0.85, 0.5, woodD, 3.3, 0.42, -5.1, 0, true);             // dresser (car keys!)
    this.box(1.3, 2.0, 0.6, woodD, 3.2, 1.0, -2.0, 0, true, true);         // parents wardrobe (hide!)
    this.box(0.5, 0.55, 0.5, woodD, -0.7, 0.27, -5.1, 0, true);            // nightstand
    // ---- BATH ----
    this.box(0.85, 0.6, 1.7, white, 4.6, 0.3, -4.5, 0, true);              // tub
    this.box(0.5, 0.45, 0.6, white, 5.9, 0.22, -4.9, 0, true);             // toilet
    this.box(0.6, 0.8, 0.5, white, 5.2, 0.4, -2.0, 0, true);               // sink vanity
    // mirror (scare device)
    const mir = new THREE.Mesh(new THREE.PlaneGeometry(0.55, 0.75),
      new THREE.MeshStandardMaterial({ color: 0x1a2028, roughness: 0.05, metalness: 0.9 }));
    mir.position.set(5.2, 1.65, -1.62); mir.rotation.y = Math.PI; this.scene.add(mir);
    this.mirror = mir;
    // ---- UTILITY ----
    this.box(0.65, 0.95, 0.65, white, 6.95, 0.47, -5.0, 0, true);          // washer
    this.box(0.65, 0.95, 0.65, white, 7.6, 0.47, -5.0, 0, true);           // dryer
    this.box(0.35, 1.8, 1.4, mat(0x555560, 0.8), 7.8, 0.9, -3.4, 0, true); // shelf
    this.box(0.3, 0.25, 0.4, mat(0xd8b93c, 0.6), 7.8, 1.25, -3.6);         // flashlight box (pickup visual)
    // fuse box on east wall
    this.box(0.12, 0.6, 0.45, mat(0x3a3f45, 0.5, { metalness: 0.4 }), 7.9, 1.55, -2.6);
    this.box(0.04, 0.4, 0.3, mat(0xc1121f, 0.5), 7.83, 1.55, -2.6);        // red switch plate
  }

  lightRig() {
    this.scene.add(new THREE.HemisphereLight(0x2a3450, 0x0a0a0c, 0.55));
    const moon = new THREE.DirectionalLight(0x8fa8ff, 0.25); moon.position.set(-12, 18, 6); this.scene.add(moon);
    const P = (room, color, i, d, x, y, z) => {
      const l = new THREE.PointLight(color, i, d); l.position.set(x, y, z); this.scene.add(l);
      this.roomLight(room, l); return l;
    };
    P('living', 0xffd9a0, 14, 11, -4, 2.3, 3);
    P('living', 0xffe6a3, 6, 6, -7.3, 1.9, 4.9);
    P('kitchen', 0xfff2d9, 14, 11, 4, 2.4, 3);
    P('hall', 0xffe9c4, 10, 9, 0, 2.4, -0.5);
    P('bed', 0xffd9a0, 8, 7, -4.5, 2.0, -3.5);
    P('bed', 0xcfe0ff, 4, 4, -3.0, 1.3, -5.0);
    P('parents', 0xffe9c4, 10, 9, 1, 2.4, -3.5);
    P('bath', 0xd6ecff, 8, 6, 5.2, 2.3, -3.5);
    P('util', 0xfff6da, 9, 7, 7.2, 2.3, -3.5);
    // porch
    this.porchOn = true;
    this.porchLight = new THREE.PointLight(0xffd9a0, 18, 14); this.porchLight.position.set(0, 2.9, 6.8); this.scene.add(this.porchLight);
    const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.09, 10, 8),
      new THREE.MeshStandardMaterial({ color: 0xffe6a3, emissive: 0xffd489, emissiveIntensity: 2 }));
    bulb.position.set(0, 2.9, 6.7); this.scene.add(bulb); this.porchBulb = bulb;
  }

  outside() {
    // ground, path, road
    const gnd = new THREE.Mesh(new THREE.PlaneGeometry(90, 60), mat(0x141a16, 1));
    gnd.rotation.x = -Math.PI / 2; gnd.position.set(0, -0.02, 4); this.scene.add(gnd);
    const pathM = mat(0x3f3b34, 1);
    const path = new THREE.Mesh(new THREE.PlaneGeometry(1.6, 8.5), pathM);
    path.rotation.x = -Math.PI / 2; path.position.set(0, 0.0, 9.5); this.scene.add(path);
    const road = new THREE.Mesh(new THREE.PlaneGeometry(90, 3.4), mat(0x0c0c0e, 1));
    road.rotation.x = -Math.PI / 2; road.position.set(0, 0.0, 15); this.scene.add(road);
    // porch deck + posts + roof + steps
    this.box(6.4, 0.18, 2.6, mat(0x5a4632, 0.9), 0, 0.09, 6.8);
    this.box(0.18, 3.0, 0.18, mat(0x3a2d1f, 0.9), -2.9, 1.5, 7.9);
    this.box(0.18, 3.0, 0.18, mat(0x3a2d1f, 0.9), 2.9, 1.5, 7.9);
    this.box(6.8, 0.15, 3.0, mat(0x141417, 1), 0, 3.05, 6.8);
    this.box(2.0, 0.12, 0.6, mat(0x5a4632, 0.9), 0, 0.06, 8.35);
    this.box(1.6, 0.03, 1.0, mat(0x6e3b3b, 1), 0, 0.2, 6.1); // doormat
    // mailbox + trash bin
    this.box(0.12, 1.1, 0.12, woodDark(), 2.2, 0.55, 9.0, 0, true);
    this.box(0.55, 0.3, 0.35, mat(0x2e4a7a, 0.6), 2.2, 1.2, 9.0);
    function woodDark() { return new THREE.MeshStandardMaterial({ color: 0x3a2d1f, roughness: 0.9 }); }
    this.box(0.6, 0.95, 0.6, mat(0x2b2f36, 0.8), -2.6, 0.47, 6.3, 0, true); // trash bin
    this.box(0.66, 0.1, 0.66, mat(0x1d2025, 0.8), -2.6, 0.98, 6.3);
    // streetlamp
    this.box(0.16, 5.2, 0.16, mat(0x222228, 0.6, { metalness: 0.5 }), 8, 2.6, 12.5, 0, true);
    const lampHead = new THREE.Mesh(new THREE.SphereGeometry(0.16, 10, 8),
      new THREE.MeshStandardMaterial({ color: 0xfff2c9, emissive: 0xffe9a3, emissiveIntensity: 3 }));
    lampHead.position.set(8, 5.2, 12.5); this.scene.add(lampHead);
    const sl = new THREE.PointLight(0xffe9a3, 30, 20); sl.position.set(8, 5.0, 12.5); this.scene.add(sl);
    // neighbor house (escape A)
    this.box(7, 3.6, 5.5, mat(0x232028, 1), -17, 1.8, 10);
    this.box(7.6, 0.4, 6.1, mat(0x101014, 1), -17, 3.8, 10);
    const nwin = new THREE.Mesh(new THREE.PlaneGeometry(1.4, 1.0),
      new THREE.MeshStandardMaterial({ color: 0x111111, emissive: 0xffd489, emissiveIntensity: 1.8 }));
    nwin.position.set(-15.5, 1.7, 7.24); nwin.rotation.y = Math.PI; this.scene.add(nwin);
    this.box(1.1, 2.1, 0.1, mat(0x6e2f26, 0.7), -18.2, 1.05, 7.25);
    const nl = new THREE.PointLight(0xffd9a0, 25, 16); nl.position.set(-17, 3.0, 7.0); this.scene.add(nl);
    // trees
    const tree = (x, z, s = 1) => {
      this.box(0.3 * s, 1.6 * s, 0.3 * s, mat(0x2e2118, 1), x, 0.8 * s, z);
      const c = new THREE.Mesh(new THREE.ConeGeometry(1.3 * s, 3.2 * s, 7), mat(0x0f1a12, 1));
      c.position.set(x, 2.8 * s, z); this.scene.add(c);
    };
    tree(-11, 2); tree(11.5, 1, 1.2); tree(-12, -7, 1.3); tree(12, -7); tree(5, -9, 1.1); tree(-5, -9); tree(14, 9, 1.2); tree(-10, 13);
    // yard fence (low, with gaps) + colliders to keep player in play area
    const fenceM = mat(0x2e2620, 1);
    for (const [x, z, w, d] of [[-11, 2, 0.15, 22], [11, 2, 0.15, 22], [0, -8, 22, 0.15]]) {
      this.box(w === 0.15 ? 0.15 : w, 1.1, d === 0.15 ? 0.15 : d, fenceM, x, 0.55, z);
      this.addCol(x - Math.max(w, 0.4) / 2, z - Math.max(d, 0.4) / 2, x + Math.max(w, 0.4) / 2, z + Math.max(d, 0.4) / 2, false);
    }
    // rain
    const N = 1300, pos = new Float32Array(N * 3);
    for (let i = 0; i < N; i++) { pos[i * 3] = (Math.random() - 0.5) * 60; pos[i * 3 + 1] = Math.random() * 10; pos[i * 3 + 2] = -10 + Math.random() * 28; }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    this.rainPts = new THREE.Points(geo, new THREE.PointsMaterial({ color: 0x8fa8c8, size: 0.055, transparent: true, opacity: 0.55 }));
    this.scene.add(this.rainPts);
  }
  updateRain(dt, on) {
    if (!this.rainPts) return;
    this.rainPts.visible = on;
    if (!on) return;
    const p = this.rainPts.geometry.attributes.position.array;
    for (let i = 0; i < p.length; i += 3) {
      p[i + 1] -= 11 * dt;
      if (p[i + 1] < 0) {
        p[i] = (Math.random() - 0.5) * 60; p[i + 1] = 9 + Math.random(); p[i + 2] = -10 + Math.random() * 28;
      }
      // keep rain out of the house interior
      if (p[i] > -8.4 && p[i] < 8.4 && p[i + 2] > -5.9 && p[i + 2] < 5.9) p[i] = p[i] < 0 ? -9.5 : 9.5;
    }
    this.rainPts.geometry.attributes.position.needsUpdate = true;
  }
  roomAt(x, z) {
    if (z >= 5.5) return 'porch';
    if (z >= 0.5) return x < 0 ? 'living' : 'kitchen';
    if (z >= -1.5) return 'hall';
    if (x < -2) return 'bed'; if (x < 4) return 'parents'; if (x < 6.5) return 'bath'; return 'util';
  }
  roomName(r) {
    return { living: 'LIVING ROOM', kitchen: 'KITCHEN', hall: 'HALLWAY', bed: 'YOUR BEDROOM', parents: 'PARENTS’ ROOM', bath: 'BATHROOM', util: 'UTILITY ROOM', porch: 'FRONT PORCH', yard: 'YARD', street: 'STREET' }[r] || r.toUpperCase();
  }
}

export const PERCHES = {
  porch: { x: 0, z: 7.2, face: Math.PI },       // facing the house (north)
  livingWin: { x: -4.5, z: 6.4, face: Math.PI },
  kitchenWin: { x: 4.5, z: 6.4, face: Math.PI },
  parentsWin: { x: 1.5, z: -6.4, face: 0 },
  lamp: { x: 7.2, z: 11.8, face: Math.PI * 0.75 },
};
export const HIDE = {
  bed: { pos: [-6.4, 0.42, -3.6], look: [-5.5, 1.0, -1.4] },
  closet: { pos: [-2.7, 1.45, -2.0], look: [-6.0, 1.1, -2.2] },
  pcloset: { pos: [3.2, 1.45, -2.0], look: [0.5, 1.1, -2.4] },
  couch: { pos: [-2, 1.18, 3.35], look: [-2, 0.95, 0.7] },
};
