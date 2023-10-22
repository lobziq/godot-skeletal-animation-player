@tool
extends AnimationPlayer

class_name SkeletalAnimationPlayer

@export var skeleton_path: NodePath
@export var is_sap: bool = true
@export var IK_playing: bool = false
@export var IK_reverse_x: bool = false : set = _reverse_x


func _process(delta):
	if not Engine.is_editor_hint():
		return
	
	for child in get_node(skeleton_path).get_children():
		if child.get_class() == "SkeletonIK3D":
			if self.IK_playing and not child.is_running():
				child.start()

			if not self.IK_playing and child.is_running():
				child.stop()

func _get_marker_match(marker_name: String, marker_list):
	var mirror_name = ""
	if marker_name.to_lower().ends_with("r"):
		mirror_name = marker_name.to_lower().left(-1) + "l"
	else:
		mirror_name = marker_name.to_lower().left(-1) + "r"
		
	for marker in marker_list:
		if marker.name.to_lower() == mirror_name:
			return marker
	
	


func _reverse_x(value: bool):
	var markers = Array()
	IK_reverse_x = value
	for child in get_node(skeleton_path).get_children():
		if child.get_class() == "SkeletonIK3D":
			for marker_child in child.get_children():
				if marker_child.name.to_lower().ends_with("l") or marker_child.name.to_lower().ends_with("r"):
					markers.append(marker_child)
	
	for marker in markers:
		var match_marker = _get_marker_match(marker.name, markers)
		marker.position.y = match_marker.position.y
		marker.position.z = match_marker.position.z
		print(marker)
		print(match_marker)
