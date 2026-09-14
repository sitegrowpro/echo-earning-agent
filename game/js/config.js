// Central tuning. Every magic number lives here so balance passes touch one file.
export const CFG = {
  eye: 1.62, eyeCrouch: 1.02,
  walk: 2.7, sprint: 4.5, crouch: 1.45,
  accel: 14, friction: 10, radius: 0.34,
  staminaMax: 100, staminaDrain: 22, staminaRegen: 16, sprintMin: 8,
  interactRange: 2.4, fov: 72,
  flashDrain: 100 / 300, // full battery ≈ 5 min of light
  noiseDecay: 55, // noise meter points/sec decay
  enemy: {
    patrol: 1.5, investigate: 2.2, chase: 3.9, search: 1.2,
    sightRange: 13, sightFov: 0.62, // cos(half-angle) ≈ 52°
    hearRadius: 11, catchDist: 1.15, loseTime: 7,
  },
  times: { microwave: 75, homeworkSeg: 25, policeWait: 150, tvNews: 150 },
};
export const ENDINGS = {
  A: { name: 'A — The Neighbor’s Porch', good: true },
  B: { name: 'B — Out the Window', good: true },
  C: { name: 'C — Under the Bed', good: true },
  D: { name: 'D — Taken', good: false },
};
export const SAVE_KEY = 'echos-night-save-v1';
export const END_KEY = 'echos-endings-v1';
export const SET_KEY = 'echos-settings-v1';
