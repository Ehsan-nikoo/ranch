## Collapses a node's direct primitive-mesh children (boxes, cylinders...) into one mesh per material:
## far fewer draw calls on mobile. Moving parts must live under a child node to stay separate.
class_name MeshMerge


static func boxes(root: Node3D) -> void:
	var groups := {}  # material -> SurfaceTool
	for c in root.get_children():
		if c is MeshInstance3D and c.mesh is PrimitiveMesh:
			var st: SurfaceTool = groups.get(c.material_override)
			if st == null:
				st = SurfaceTool.new()
				groups[c.material_override] = st
			st.append_from(c.mesh, 0, c.transform)
			c.free()
	for m in groups:
		var mi := MeshInstance3D.new()
		mi.mesh = groups[m].commit()
		mi.material_override = m
		root.add_child(mi)
