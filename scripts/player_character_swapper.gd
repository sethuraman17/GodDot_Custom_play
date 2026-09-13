extends Node
class_name PlayerCharacterSwapper

## Swaps the player's visual character (and its matching physique) at run
## start. Each preset carries the full set of values that differ between
## characters: model scene, SkinPivot scale, skin material, collision capsule,
## camera aim height, and sun-exposure head height. The rest of the player
## (movement, survival systems) is shared. Most characters retarget the robot
## locomotion clips; Srini uses its own idle / sprint / punch / dance set.

const CHARACTERS: Dictionary = {
	"robot": {
		"label": "ROBOT",
		"scene": "res://assets/third_person_adventure/characters/player_robot/player_robot.fbx",
		"skin_scale": 0.7,
		"capsule_height": 1.26,
		"capsule_radius": 0.245,
		"capsule_y": 0.63,
		"camera_height": 1.1,
		"head_height": 1.26,
	},
	"wanderer": {
		"label": "WANDERER",
		"scene": "res://assets/Player/3d_1782992307143.glb",
		"skin_scale": 1.101,
		"capsule_height": 1.8,
		"capsule_radius": 0.35,
		"capsule_y": 0.9,
		"camera_height": 1.9,
		"head_height": 1.7,
	},
	"srini": {
		"label": "SRINI",
		"scene": "res://assets/third_person_adventure/characters/player_custom/srini_idle.glb",
		"skin_scale": 1.85,
		"capsule_height": 1.8,
		"capsule_radius": 0.35,
		"capsule_y": 0.9,
		"camera_height": 1.7,
		"head_height": 1.7,
		"can_jump": false,
		"action_profile": "srini",
		"freeze_idle_head": false,
		"rescale_positions": false,
		"clips": {
			"idle": "res://assets/third_person_adventure/characters/player_custom/srini_idle.glb",
			"walk": "",
			"run": "res://assets/third_person_adventure/characters/player_custom/srini_walking.glb",
			"jump": "",
			"fall": "",
			"land": "",
			"long_idle": "",
			"punch": "res://assets/third_person_adventure/characters/player_custom/srini_punch.glb",
			"dance": "res://assets/third_person_adventure/characters/player_custom/srini_dance.glb",
		},
	},
}
const DEFAULT_CHARACTER := "robot"
const WANDERER_TEXTURE := "res://assets/Player/3d_1782992307143_texture_0.png"

@export var skin_pivot_path: NodePath = ^"../SkinPivot"
@export var collision_shape_path: NodePath = ^"../CollisionShape3D"
@export var animator_path: NodePath = ^"../Animator"
@export var sun_exposure_path: NodePath = ^"../SunExposure"
@export var camera_path: NodePath = ^"../../CameraRig"

var _current_id: String = ""
var _materials: Dictionary = {}


func _ready() -> void:
	# Defer so the whole player subtree (animator included) is ready before the
	# first swap rebinds the animation player — child ready-order then doesn't
	# matter. The scene ships with the wanderer model baked in; the robot is
	# the gameplay default.
	apply_character.call_deferred(DEFAULT_CHARACTER)


func apply_character(id: String) -> void:
	if id == _current_id or not CHARACTERS.has(id):
		return
	var preset: Dictionary = CHARACTERS[id]

	var skin_pivot := get_node_or_null(skin_pivot_path) as Node3D
	if skin_pivot == null:
		push_warning("PlayerCharacterSwapper: SkinPivot not found.")
		return

	var scene := load(String(preset["scene"])) as PackedScene
	if scene == null:
		push_warning("PlayerCharacterSwapper: could not load %s" % preset["scene"])
		return

	var old := skin_pivot.get_node_or_null("player_robot")
	if old != null:
		skin_pivot.remove_child(old)
		old.queue_free()

	var inst := scene.instantiate() as Node3D
	inst.name = "player_robot"
	inst.rotation = Vector3(0.0, PI, 0.0)
	skin_pivot.add_child(inst)

	skin_pivot.scale = Vector3.ONE * float(preset["skin_scale"])
	skin_pivot.position = Vector3.ZERO
	var skin_material := _material_for(id)
	if skin_material != null:
		if "material" in skin_pivot:
			skin_pivot.set("material", skin_material)
			if skin_pivot.has_method("apply_material"):
				skin_pivot.call("apply_material")
	else:
		_clear_mesh_overrides(inst)

	var collision := get_node_or_null(collision_shape_path) as CollisionShape3D
	if collision != null:
		collision.position = Vector3(0.0, float(preset["capsule_y"]), 0.0)
		var capsule := collision.shape as CapsuleShape3D
		if capsule != null:
			capsule.height = float(preset["capsule_height"])
			capsule.radius = float(preset["capsule_radius"])

	var camera := get_node_or_null(camera_path)
	if camera != null and "height_offset" in camera:
		camera.set("height_offset", float(preset["camera_height"]))

	var sun_exposure := get_node_or_null(sun_exposure_path)
	if sun_exposure != null and "head_height" in sun_exposure:
		sun_exposure.set("head_height", float(preset["head_height"]))

	var animator := get_node_or_null(animator_path) as HumanoidLocomotionAnimator
	if animator != null:
		var clips: Dictionary = preset.get("clips", {})
		animator.configure_clips(clips, bool(preset.get("freeze_idle_head", true)), bool(preset.get("rescale_positions", true)))
		animator.rebind()

	var player := get_parent()
	if player != null and player.has_method("recapture_skin_scale"):
		player.call("recapture_skin_scale")
	if player != null and "jump_enabled" in player:
		player.set("jump_enabled", bool(preset.get("can_jump", true)))

	var mobile := get_node_or_null(^"../../MobileControls")
	if mobile != null and mobile.has_method("set_action_profile"):
		mobile.call("set_action_profile", String(preset.get("action_profile", "default")))

	_current_id = id


func _clear_mesh_overrides(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				mesh_instance.set_surface_override_material(surface_index, null)
	for child in node.get_children():
		_clear_mesh_overrides(child)


func _material_for(id: String) -> Material:
	if _materials.has(id):
		return _materials[id]
	var material: Material = null
	match id:
		"robot":
			material = load("res://assets/third_person_adventure/characters/player_robot/materials/player_robot_material.tres") as Material
		"wanderer":
			# The glb's own material doesn't survive import; rebuild the
			# intended look — its texture blended through both the base-color
			# and a full-strength emissive channel.
			var texture := load(WANDERER_TEXTURE) as Texture2D
			var standard := StandardMaterial3D.new()
			standard.albedo_texture = texture
			standard.emission_enabled = true
			standard.emission_texture = texture
			material = standard
	_materials[id] = material
	return material
