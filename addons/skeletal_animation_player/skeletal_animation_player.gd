@tool
extends EditorPlugin


var dock
var eds
var buffer_bp_list: Array[BonePose]


class BonePose:
	var index: int
	var bone_name: String
	var position: Vector3
	var rotation_q: Quaternion
	var scale: Vector3
	
	func _to_string():
		return "[{bone_name}: {index}] p: {position}, r: {rotation_q}, s: {scale}".format(
			{
				"bone_name": bone_name,
				"index": index,
				"position": position,
				"rotation_q": rotation_q,
				"scale": scale
			}
		)
		
	func clone():
		var bone_pose = BonePose.new()
		bone_pose.index = index
		bone_pose.bone_name = bone_name
		bone_pose.position = position
		bone_pose.rotation_q = rotation_q
		bone_pose.scale = scale
		return bone_pose
		
func _get_bp_list_rest():
	var sap = _get_selected_sap()
	var skeleton: Skeleton3D = sap.get_node(sap.skeleton_path)
	
	if not skeleton:
		return
		
	var bp_list: Array[BonePose] = []
	
	for index in range(skeleton.get_bone_count()):
		var bone_pose = BonePose.new()
		bone_pose.index = index
		bone_pose.bone_name = skeleton.get_bone_name(index)
		bone_pose.position = skeleton.get_bone_rest(index).origin
		bone_pose.rotation_q = skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
		bone_pose.scale = skeleton.get_bone_rest(index).basis.get_scale()
		bp_list.append(bone_pose)
		
	return bp_list
	

func _get_animation_tracks(animation: Animation):
	for track_idx in range(0, animation.get_track_count(), 3):
		print(track_idx)
		print(animation.track_get_path(track_idx).get_concatenated_subnames())
		print(animation.track_get_type(track_idx))
		

func _get_bp_list_from_animation(animation: Animation, key_time: float):
	var bp_list: Array[BonePose] = []
	for track_idx in range(0, animation.get_track_count(), 3):
		var bone_pose = BonePose.new()
		bone_pose.index = track_idx / 3
		bone_pose.bone_name = animation.track_get_path(track_idx).get_concatenated_subnames()
		var key_idx = animation.track_find_key(track_idx, key_time)
		bone_pose.position = animation.track_get_key_value(track_idx, animation.track_find_key(track_idx, key_time))
		bone_pose.rotation_q = animation.track_get_key_value(track_idx + 1, animation.track_find_key(track_idx + 1, key_time))
		bone_pose.scale = animation.track_get_key_value(track_idx + 2, animation.track_find_key(track_idx + 2, key_time))
		bp_list.append(bone_pose)
	
	return bp_list
	
	
func _delete_animation_keys(animation: Animation, key_time: float):
	for track_idx in animation.get_track_count():
		animation.track_remove_key_at_time(track_idx, key_time)
		
		

func _calculate_local_transform(skeleton: Skeleton3D, index: int) -> BonePose:
	var bone_transform = skeleton.get_bone_global_pose(index)
	var bone_local_transform = bone_transform
	var parent_idx = skeleton.get_bone_parent(index)
	
	if parent_idx > -1:
		var parent_transform = skeleton.get_bone_global_pose(parent_idx)
		bone_local_transform = parent_transform.affine_inverse() * bone_transform
		
	var bone_pose = BonePose.new()
	bone_pose.index = index
	bone_pose.bone_name = skeleton.get_bone_name(index)
	bone_pose.position = bone_local_transform.origin
	bone_pose.rotation_q = bone_local_transform.basis.get_rotation_quaternion()
	bone_pose.scale = bone_local_transform.basis.get_scale()
	
	return bone_pose
	
	
func _get_bp_list_current():
	var sap = _get_selected_sap()
	var skeleton: Skeleton3D = sap.get_node(sap.skeleton_path)
	
	if not skeleton:
		return
		
	var bp_list: Array[BonePose] = []
	
	for index in range(skeleton.get_bone_count()):
		bp_list.append(_calculate_local_transform(skeleton, index))
		
	return bp_list

func _get_selected_sap():
	eds = get_editor_interface().get_selection()
	
	if len(eds.get_selected_nodes()) != 1:
		return null
	
	if eds.get_selected_nodes()[0].get("is_sap"):
		return eds.get_selected_nodes()[0]
		
	return null
	
	
func _get_or_create_track(animation: Animation, attr_path: String, track_type: int):
	var track_pos = animation.find_track(attr_path, track_type)
	if track_pos == -1:
		track_pos = animation.add_track(track_type)
	animation.track_set_path(track_pos, attr_path)
	return track_pos


func _enter_tree():
	dock = preload("res://addons/skeletal_animation_player/sap_dock.tscn").instantiate()
	
	var ui_list = dock.get_children()[0].get_children()
	for ui_element in ui_list:
		if ui_element.name == "ButtonCreateReset":
			ui_element.pressed.connect(_on_create_reset)
			
		if ui_element.name == "ButtonInsert":
			ui_element.pressed.connect(_on_insert_keys)
			
		if ui_element.name == "ButtonCut":
			ui_element.pressed.connect(_on_cut)
			
		if ui_element.name == "ButtonDelete":
			ui_element.pressed.connect(_on_delete)
			
		if ui_element.name == "ButtonCopy":
			ui_element.pressed.connect(_on_copy)
			
		if ui_element.name == "ButtonPaste":
			ui_element.pressed.connect(_on_paste)
			
		if ui_element.name == "ButtonPasteFlipped":
			ui_element.pressed.connect(_on_paste_flipped)
	
	var eds = get_editor_interface().get_selection()
	eds.connect("selection_changed", _selection_changed)
	
	
	add_custom_type("SkeletalAnimationPlayer", "AnimationPlayer", preload("sap_node.gd"), preload("skeleton-inside.png"))
	_selection_changed()


func _on_delete():
	var sap: SkeletalAnimationPlayer = _get_selected_sap()
	_delete_animation_keys(sap.get_animation(sap.assigned_animation), snapped(sap.current_animation_position, 0.001))


func _on_cut():
	var sap: SkeletalAnimationPlayer = _get_selected_sap()
	var skeleton: Skeleton3D = sap.get_node(sap.skeleton_path)
	
	if not skeleton:
		return
		
	var animation = sap.get_animation(sap.assigned_animation)
	var animation_pos = snapped(sap.current_animation_position, 0.001)
	buffer_bp_list = _get_bp_list_from_animation(animation, animation_pos)
	_delete_animation_keys(sap.get_animation(sap.assigned_animation), animation_pos)
	
func _on_copy():
	var sap: SkeletalAnimationPlayer = _get_selected_sap()
	var skeleton: Skeleton3D = sap.get_node(sap.skeleton_path)
	var animation = sap.get_animation(sap.assigned_animation)
	
	if not skeleton:
		return
	
	buffer_bp_list = _get_bp_list_from_animation(animation, snapped(sap.current_animation_position, 0.001))
	
	
func _on_paste():
	print("paste")
	var sap: SkeletalAnimationPlayer = _get_selected_sap()
	var skeleton: Skeleton3D = sap.get_node(sap.skeleton_path)
	
	if not skeleton:
		return
		
	var current_pos = snapped(sap.current_animation_position, 0.001)
	_create_keys_from_bp_list(buffer_bp_list, sap.get_animation(sap.assigned_animation), snapped(sap.current_animation_position, 0.001))
	
	
func _on_paste_flipped():
	print("paste flipped")
	var sap: SkeletalAnimationPlayer = _get_selected_sap()
	var skeleton: Skeleton3D = sap.get_node(sap.skeleton_path)
	
	if not skeleton:
		return
		
	var current_pos = snapped(sap.current_animation_position, 0.001)
	var flipped_bp_list = _flip_bp_list(buffer_bp_list)
	_create_keys_from_bp_list(flipped_bp_list, sap.get_animation(sap.assigned_animation), snapped(sap.current_animation_position, 0.001))


func _on_insert_keys():
	var sap: SkeletalAnimationPlayer = _get_selected_sap()
	var skeleton: Skeleton3D = sap.get_node(sap.skeleton_path)
	
	if not skeleton:
		return
	
	_create_keys_from_bp_list(_get_bp_list_current(), sap.get_animation(sap.assigned_animation), snapped(sap.current_animation_position, 0.001))


func _on_create_reset():
	var sap: SkeletalAnimationPlayer = _get_selected_sap()
	var skeleton: Skeleton3D = sap.get_node(sap.skeleton_path)
	
	if not skeleton:
		return
	
	if not sap.has_animation("RESET"):
		if not sap.get_animation_library(""):
			sap.add_animation_library("", AnimationLibrary.new())
		sap.get_animation_library("").add_animation("RESET", Animation.new())
	
	var animation: Animation = sap.get_animation("RESET")
	animation.clear()
	_create_keys_from_bp_list(_get_bp_list_rest(), animation, 0.0)


func _selection_changed():
	if _get_selected_sap():
		add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)
	else:
		remove_control_from_docks(dock)
		
		
func _get_bone_by_name(bp_list: Array[BonePose], name: String):
	for b in bp_list:
		if b.bone_name.to_lower() == name.to_lower():
			return b


func _flip_bp_list(bp_list: Array[BonePose]):
	var sap = _get_selected_sap()
	var skeleton: Skeleton3D = sap.get_node(sap.skeleton_path)
	
	if not skeleton:
		return
	
	var flipped_bp_list: Array[BonePose] = []
	for fbp in bp_list:
		flipped_bp_list.append(fbp.clone())
	
	var mirrors = [[".r", ".l"], [".l", ".r"]]
	
	for bone in flipped_bp_list:
		if not bone.bone_name.to_lower().ends_with(".r") and not bone.bone_name.to_lower().ends_with(".l"):
			var rbone_euler = bone.rotation_q.get_euler()
			rbone_euler.y = -rbone_euler.y
			rbone_euler.z = -rbone_euler.z
			bone.rotation_q = Quaternion.from_euler(rbone_euler)
		
		for m in mirrors:
			if bone.bone_name.to_lower().ends_with(m[0]):
				var pair_name = bone.bone_name.to_lower().replace(m[0], m[1])
				var pair_bone = _get_bone_by_name(bp_list, pair_name)
				if pair_bone:
					var rbone_euler = pair_bone.rotation_q.get_euler()
					rbone_euler.y = -rbone_euler.y
					rbone_euler.z = -rbone_euler.z
					
					bone.rotation_q = Quaternion.from_euler(rbone_euler)
					bone.position.y = pair_bone.position.y
					bone.position.z = pair_bone.position.z
	
	return flipped_bp_list


func _create_keys_from_bp_list(bp_list: Array[BonePose], animation: Animation, key_time: float):
	var sap = _get_selected_sap()
	
	for bp in bp_list:
		var attr_path = str(sap.skeleton_path).right(-3) + ":" + bp.bone_name
		
		var track_pos = _get_or_create_track(animation, attr_path, Animation.TYPE_POSITION_3D)
		animation.position_track_insert_key(track_pos, key_time, bp.position)
		var track_rot = _get_or_create_track(animation, attr_path, Animation.TYPE_ROTATION_3D)
		animation.rotation_track_insert_key(track_rot, key_time, bp.rotation_q)
		var track_sca =_get_or_create_track(animation, attr_path, Animation.TYPE_SCALE_3D)
		animation.scale_track_insert_key(track_sca, key_time, bp.scale)


func _process(delta):
	pass


func _exit_tree():
	remove_custom_type("SkeletalAnimationPlayer")
	remove_control_from_docks(dock)
	dock.free()
