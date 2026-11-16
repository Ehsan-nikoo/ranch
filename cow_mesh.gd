## The herd cow: "Farm Cow Animated Dairy cattle" by Rukh3D (CC-BY 4.0), see models/farm_cow/license.txt.
## tools/cow_bake.gd turns its skeleton animations into a vertex-animation texture (VAT) so the whole
## herd draws as one MultiMesh. This class loads the baked results for the herd and the menus.
class_name CowMesh

const WIDTH := 1024        # VAT texture width; each frame takes ceil(vertex_count / WIDTH) rows
const LENGTH := 2.3        # nose-to-tail length after baking, meters
# clip name -> [first frame, frame count]; walk and graze loop, death plays once
const CLIPS := {idle = [0, 24], walk = [24, 16], graze = [40, 8], death = [48, 12]}
const FRAMES := 60
const DIR := "res://models/"

static var _mat: ShaderMaterial


static func mesh() -> ArrayMesh:
	return load(DIR + "cow_mesh.res")


static func material() -> ShaderMaterial:
	if _mat == null:
		var pos: Texture2D = load(DIR + "cow_vat_pos.res")
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://cow.gdshader")
		_mat.set_shader_parameter("vat_pos", pos)
		_mat.set_shader_parameter("vat_nrm", load(DIR + "cow_vat_nrm.res"))
		_mat.set_shader_parameter("body_tex", load(DIR + "farm_cow/textures/material_baseColor.jpeg"))
		_mat.set_shader_parameter("eye_tex", load(DIR + "farm_cow/textures/eyes_baseColor.jpeg"))
		_mat.set_shader_parameter("rows", pos.get_height() / FRAMES)
		for c in CLIPS:
			_mat.set_shader_parameter(c + "_clip", Vector2i(CLIPS[c][0], CLIPS[c][1]))
	return _mat
