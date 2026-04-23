extends Control

@onready var avatar_rect: TextureRect = $HBoxContainer/AvatarContainer/AvatarRect
@onready var name_label: Label        = $HBoxContainer/VBoxContainer/NameLabel
@onready var status_dot: Panel        = $HBoxContainer/VBoxContainer/StatusRow/StatusDot
@onready var status_label: Label      = $HBoxContainer/VBoxContainer/StatusRow/StatusLabel

var _steam_id: int = 0

const CIRCLE_SHADER = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	float alpha = 1.0 - smoothstep(0.48, 0.5, dist);
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= alpha;
}
"""

func _ready() -> void:
	# Apply circle shader to avatar
	var shader = Shader.new()
	shader.code = CIRCLE_SHADER
	var mat = ShaderMaterial.new()
	mat.shader = shader
	avatar_rect.material = mat

	if not SteamManager.steam_available:
		SteamManager.steam_initialized.connect(_populate)
	else:
		_populate()

func _populate() -> void:
	_steam_id = Steam.getSteamID()
	name_label.text = Steam.getFriendPersonaName(_steam_id)
	var state = Steam.getFriendPersonaState(_steam_id)
	_set_status(state)
	Steam.avatar_loaded.connect(_on_avatar_loaded)
	Steam.getPlayerAvatar(Steam.AVATAR_MEDIUM, _steam_id)

func _set_status(state: int) -> void:
	if state > 0:
		status_label.text = "Online"
		status_dot.add_theme_stylebox_override("panel", _make_dot(Color(0.3, 0.85, 0.45, 1)))
	else:
		status_label.text = "Offline"
		status_dot.add_theme_stylebox_override("panel", _make_dot(Color(0.55, 0.55, 0.55, 1)))

func _make_dot(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_right = 8
	s.corner_radius_bottom_left = 8
	return s

func _on_avatar_loaded(id: int, img_size: int, buffer: PackedByteArray) -> void:
	if id != _steam_id:
		return
	var img := Image.create_from_data(img_size, img_size, false, Image.FORMAT_RGBA8, buffer)
	avatar_rect.texture = ImageTexture.create_from_image(img)
