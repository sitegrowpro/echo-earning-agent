extends RefCounted
## Procedural low-fi surface textures (F2F/PS1 recipe: 64-128px diffuse detail,
## point-filtered, tiled in world space). Fully deterministic: fixed seeds, so
## the art direction is identical on every run and every machine.
##
## Patterns are light-gray luminance detail (average ~0.85-1.0); the material's
## albedo_color tint carries the hue. Periodic patterns tile by construction;
## noise patterns are made tileable with a wrapped-offset blend.

const TILE_METERS := {
	"planks": 2.0, "tile": 1.0, "carpet": 2.0, "drywall": 2.0,
	"concrete": 2.0, "asphalt": 4.0, "grass": 4.0, "deck": 2.0,
	"ceiling": 1.2, "brick": 2.0, "stucco": 2.0,
	"wallpaper": 2.0, "bathtile": 1.0, "lace": 1.0,
	"wooddoor": 2.0, "shrub": 1.0, "grave": 2.0, "gravedirt": 1.0,
	"pinefloor": 4.0, "bark": 1.5,
	"block": 2.0, "cellar": 3.0,
	"porch": 2.0, "lino": 2.0, "asphalt2": 4.0,
	"siding": 2.0, "shingles": 2.0,
}

const PHOTO := {
	"drywall": "drywall", "planks": "woodfloor", "deck": "deck",
	"tile": "tile", "ceiling": "ceiling", "carpet": "carpet",
	"concrete": "sidewalk", "asphalt": "asphalt", "grass": "grass",
	"brick": "brick", "stucco": "drywall",
	"wallpaper": "wallpaper", "bathtile": "bathtile", "lace": "lace",
	"wooddoor": "wooddoor", "shrub": "shrub", "grave": "grave", "gravedirt": "gravedirt",
	"pinefloor": "pinefloor", "bark": "bark",
	"block": "block", "cellar": "cellar",
	"porch": "porch", "lino": "lino", "asphalt2": "asphalt2",
	"siding": "siding", "shingles": "shingles",
}


static var _tex_cache := {}
static var _mat_cache := {}
static var _grain_nrm: ImageTexture = null


## Finished, cached, world-triplanar material for a surface kind.
static func mat_for(kind: String, tint: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%f|%f" % [kind, tint.to_html(), rough, metal]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = get_tex(kind)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = rough
	m.metallic = metal
	# World-space triplanar: one material keeps correct texel density on every
	# box/plane regardless of size, and wall segments share continuous texture.
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	var s := 1.0 / float(TILE_METERS.get(kind, 2.0))
	m.uv1_scale = Vector3(s, s, s)
	m.uv1_triplanar_sharpness = 12.0
	m.normal_map = _grain_normal()
	_mat_cache[key] = m
	return m


static func get_tex(kind: String) -> ImageTexture:
	if _tex_cache.has(kind):
		return _tex_cache[kind]
	if PHOTO.has(kind):
		var pt := _photo(kind)
		if pt != null:
			_tex_cache[kind] = pt
			return pt
	var img: Image
	match kind:
		"planks":
			img = _planks(128, 16, 1, 11)
		"deck":
			img = _planks(128, 16, 2, 77)
		"tile":
			img = _tile_grid(64, 16, 101)
		"ceiling":
			img = _ceiling_grid(64, 32, 202)
		"carpet":
			img = _speckle(64, 0.85, 0.10, 0.10, 303)
		"drywall":
			img = _blotch(64, 0.95, 0.09, 404)
		"concrete":
			img = _speckle(64, 0.80, 0.12, 0.06, 505)
		"asphalt":
			img = _speckle(64, 0.80, 0.15, 0.10, 606)
		"grass":
			img = _grass(64, 707)
		_:
			img = Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
			img.fill(Color(1, 1, 1))
	_tex_cache[kind] = ImageTexture.create_from_image(img)
	return _tex_cache[kind]


static func _photo(kind: String) -> ImageTexture:
	var p := "res://assets/tex/" + String(PHOTO[kind]) + ".jpg"
	if not ResourceLoader.exists(p):
		return null
	var t := ResourceLoader.load(p) as Texture2D
	if t == null:
		return null
	var img := t.get_image()
	img.resize(256, 256) # R5: 128 crushed the photographic detail; 256 keeps the PSX soul
	img.adjust_bcs(1.0, 1.0, 0.0)
	var avg := 0.0
	for y in 256:
		for x in 256:
			avg += img.get_pixel(x, y).r
	avg /= 65536.0
	if avg > 0.01:
		img.adjust_bcs(0.9 / avg, 1.0, 0.0)
	return ImageTexture.create_from_image(_tileable(img))


## Full-color prop art (posters, photos, rugs): NOT tile-blended, NOT re-leveled.
static func art(name: String, max_px := 512) -> ImageTexture:
	var key := "art:" + name
	if _tex_cache.has(key):
		return _tex_cache[key]
	var p := "res://assets/tex/" + name + ".jpg"
	if not ResourceLoader.exists(p):
		return null
	var t := ResourceLoader.load(p) as Texture2D
	if t == null:
		return null
	var img := t.get_image()
	if img.get_width() > max_px or img.get_height() > max_px:
		img.resize(max_px, int(max_px * float(img.get_height()) / float(maxi(1, img.get_width()))))
	var out := ImageTexture.create_from_image(img)
	_tex_cache[key] = out
	return out


static func _noise(octaves: int, freq: float, seed_v: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_octaves = octaves
	n.frequency = freq
	n.seed = seed_v
	return n


static func _row_hash(i: int, salt: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(salt) * 78.233) * 43758.5453, 1.0)


## Horizontal wood planks. plank_h must divide `size` so the tile wraps.
static func _planks(size: int, plank_h: int, gap_px: int, seed_v: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var n := _noise(3, 0.9, seed_v)
	for y in size:
		var row := floori(float(y) / float(plank_h))
		var tone := 0.92 + (_row_hash(row, seed_v) - 0.5) * 0.12
		for x in size:
			var v := tone + n.get_noise_2d(float(x) * 0.22, float(row) * 2.7) * 0.09
			if y % plank_h < gap_px:
				v = 0.38
			elif x == (row * 47 + 20) % size:
				v *= 0.82 # plank-end seam, fixed position so it tiles
			img.set_pixel(x, y, Color(v, v, v))
	return img


## Ceramic-style grid: cells with grout lines + per-cell jitter.
static func _tile_grid(size: int, cell: int, seed_v: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var n := _noise(2, 1.2, seed_v)
	for y in size:
		for x in size:
			var cx := floori(float(x) / float(cell))
			var cy := floori(float(y) / float(cell))
			var v := 0.96 + (_row_hash(cx * 31 + cy, seed_v) - 0.5) * 0.09
			v += n.get_noise_2d(float(x), float(y)) * 0.03
			if x % cell == 0 or y % cell == 0:
				v = 0.55
			img.set_pixel(x, y, Color(v, v, v))
	return img


## Acoustic ceiling tile: large grid + pin-dot perforations + speckle.
static func _ceiling_grid(size: int, cell: int, seed_v: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var n := _noise(2, 1.5, seed_v)
	for y in size:
		for x in size:
			var v := 0.97 + n.get_noise_2d(float(x), float(y)) * 0.04
			if x % cell == 0 or y % cell == 0:
				v = 0.60
			elif x % 8 == 4 and y % 8 == 4:
				v = 0.72
			img.set_pixel(x, y, Color(v, v, v))
	return img


## Generic speckle surface (carpet / concrete / asphalt): noise + grain.
static func _speckle(size: int, base: float, noise_amp: float, grain_amp: float, seed_v: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var n := _noise(3, 0.8, seed_v)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for y in size:
		for x in size:
			var v := base + n.get_noise_2d(float(x), float(y)) * noise_amp
			v += (rng.randf() - 0.5) * 2.0 * grain_amp
			img.set_pixel(x, y, Color(v, v, v))
	return _tileable(img)


## Faint large blotches for painted drywall.
static func _blotch(size: int, base: float, amp: float, seed_v: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var n := _noise(2, 0.25, seed_v)
	for y in size:
		for x in size:
			var v := base + n.get_noise_2d(float(x), float(y)) * amp
			img.set_pixel(x, y, Color(v, v, v))
	return _tileable(img)


## Vertical grass-blade streaks (stretched noise on x, fine on y).
static func _grass(size: int, seed_v: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var n := _noise(3, 1.0, seed_v)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for y in size:
		for x in size:
			var v := 0.85 + n.get_noise_2d(float(x) * 0.55, float(y) * 0.08) * 0.15
			v += (rng.randf() - 0.5) * 0.08
			img.set_pixel(x, y, Color(v, v, v))
	return _tileable(img)


## Wrapped-offset blend: averages each pixel with its half-tile offsets,
## guaranteeing the result wraps seamlessly in both axes.
static func _grain_normal() -> ImageTexture:
	# R7b: one shared high-frequency normal map — drywall bumps, wood grain
	# teeth. Flashlights catch it; flat shading dies. Wrapped sampling tiles.
	if _grain_nrm != null:
		return _grain_nrm
	var n := _noise(2, 2.2, 808)
	var s := 64
	var h := Image.create_empty(s, s, false, Image.FORMAT_RF)
	for y in s:
		for x in s:
			h.set_pixel(x, y, Color(n.get_noise_2d(float(x), float(y)), 0, 0))
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var dx := h.get_pixel((x + 1) % s, y).r - h.get_pixel((x - 1 + s) % s, y).r
			var dy := h.get_pixel(x, (y + 1) % s).r - h.get_pixel(x, (y - 1 + s) % s).r
			var nv := Vector3(-dx * 1.4, -dy * 1.4, 1.0).normalized()
			img.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5))
	_grain_nrm = ImageTexture.create_from_image(img)
	return _grain_nrm


static func _tileable(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var hw := w >> 1
	var hh := h >> 1
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			c += img.get_pixel((x + hw) % w, y)
			c += img.get_pixel(x, (y + hh) % h)
			c += img.get_pixel((x + hw) % w, (y + hh) % h)
			out.set_pixel(x, y, c / 4.0)
	return out
