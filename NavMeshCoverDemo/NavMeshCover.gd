extends Spatial

export(NodePath) var navmesh_path
onready var navmesh = get_node(navmesh_path).navmesh
onready var raycast = get_node("RayCast")

export(bool) var visualize_covers = false
export(float) var min_cover_height = 0.8
export(float) var min_edge_length = 1.0

const MAX_HEIGHT = 1000.0

var cover_spots = {}

func _ready() -> void:
	bake()

func bake_normals():
	# Find open-edges and calculate the "normals" of them
	for i in navmesh.get_polygon_count():
		calculate_normals(i)

func bake_heights():
	for spot in cover_spots.keys():
		
		var current_check_height = spot.y
		
		# Repeate raycasting in reversed direction of the normal of the edge to identify the height of the cover
		while current_check_height < MAX_HEIGHT:
			raycast.global_translation = Vector3(spot.x, current_check_height, spot.z)
			raycast.cast_to = -cover_spots[spot]["normal"] * 1.5
			raycast.force_raycast_update()
			if !raycast.is_colliding():
				break;
			current_check_height += 0.1
		cover_spots[spot]["height"] = current_check_height - spot.y
		
		# Remove covers with underqualified heights
		if cover_spots[spot]["height"] < min_cover_height:
			cover_spots.erase(spot)

func calculate_normals(p_index : int):
	# Get vertices from a triangle (when navmesh's "polygon_verts_per_poly" was set to 3)
	var a_index = navmesh.get_polygon(p_index)[0]
	var b_index = navmesh.get_polygon(p_index)[1]
	var c_index = navmesh.get_polygon(p_index)[2]
	
	var a = navmesh.vertices[a_index]
	var b = navmesh.vertices[b_index]
	var c = navmesh.vertices[c_index]
	
	# Calculate sides (AB, AC, BC) of the triangle
	var ab = Vector2((b - a).x, (b - a).z)
	var ac = Vector2((c - a).x, (c - a).z)
	var bc = Vector2((c - b).x, (c - b).z)
	
	
	## Calculate a normal vector of the side AB pointing outwards
	
	# Way to get a normal vector of AB in 2D place, we do not know if it points inwards or outwards of the triangle
	var nab = Vector2(-ab.y, ab.x).normalized()
	
	# The dot product of the normal of AB and the vector AC will be negative if the normal is pointing inward and positive otherwise
	# So we reverse the current normal if it is pointing inwards by multiplier the sign of the dot product
	var nab_f = (Vector3(nab.x, 0.0, nab.y) * sign(nab.dot(ac))).normalized()
	
	# Add the edge represented by its center to the collection, remove duplicates
	var cen_ab = (a + b) / 2.0
	if  cover_spots.has(cen_ab):
		cover_spots.erase(cen_ab)
	else:
		cover_spots[cen_ab] = {}
		cover_spots[cen_ab]["normal"] = nab_f
	
	## Same for AC, BC
	
	var nac = Vector2(-ac.y, ac.x).normalized()
	var cen_ac = (a + c) / 2.0
	var nac_f =  (Vector3(nac.x, 0.0, nac.y) * sign(nac.dot(ab))).normalized()
	if cover_spots.has(cen_ac):
		cover_spots.erase(cen_ac)
	else:
		cover_spots[cen_ac] = {}
		cover_spots[cen_ac]["normal"] = nac_f

	var nbc = Vector2(-bc.y, bc.x).normalized()
	var cen_bc = (b + c) / 2.0
	var nbc_f = (Vector3(nbc.x, 0.0, nbc.y) * sign(nbc.dot(-ab))).normalized()
	if cover_spots.has(cen_bc):
		cover_spots.erase(cen_bc)
	else:
		cover_spots[cen_bc] = {}
		cover_spots[cen_bc]["normal"] = nbc_f

func bake():
	bake_normals()
	bake_heights()

func draw_covers():
	for spot in cover_spots.keys():
		DebugDraw.draw_arrow_ray(spot, cover_spots[spot]["normal"], cover_spots[spot]["normal"].length(), Color.green, 0.1)
		DebugDraw.draw_ray(spot, Vector3.UP, cover_spots[spot]["height"], Color.blue)

func _process(delta: float) -> void:
	if visualize_covers:
		draw_covers()
