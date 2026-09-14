extends RefCounted
## Central tuning. Every magic number lives here.

const EYE := 1.62
const EYE_CROUCH := 1.02
const WALK := 2.7
const SPRINT := 4.5
const CROUCH := 1.45
const GRAVITY := 20.0
const STAM_MAX := 100.0
const STAM_DRAIN := 22.0
const STAM_REGEN := 16.0
const STAM_MIN := 8.0
const INTERACT_RANGE := 2.4
const FLASH_DRAIN := 100.0 / 300.0
const NOISE_DECAY := 55.0
const MICRO_TIME := 75.0
const HOMEWORK_HOLD := 8.0
const POLICE_WAIT := 150.0
const NEWS_TIME := 130.0
const MIC_STREAK := 0.45
const MIC_COOL := 4.0
const EGGS_TOTAL := 2
const MARKET_CHAPTER := 1

const ENEMY := {
	"patrol": 1.5,
	"investigate": 2.2,
	"chase": 3.9,
	"sight_range": 13.0,
	"sight_fov": 0.62,
	"hear_radius": 11.0,
	"catch_dist": 1.15,
	"lose_time": 7.0,
}

const ENDINGS := {
	"A": {"name": "A — The Neighbor's Porch", "good": true},
	"B": {"name": "B — Out the Window", "good": true},
	"C": {"name": "C — Under the Bed", "good": true},
	"D": {"name": "D — Taken", "good": false},
}
