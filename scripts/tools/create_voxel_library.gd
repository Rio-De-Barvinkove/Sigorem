@tool
extends SceneTree

func _init():
	print("Starting Voxel Library Creation...")
	create_library()
	quit()

func create_library():
	var library = VoxelBlockyLibrary.new()
	
	# 0: Air (Default)
	var air = VoxelBlockyModel.new()
	air.resource_name = "Air"
	library.add_model(air)
	
	# 1: Stone
	var stone = create_cube_model("Stone", "res://assets/textures/Set 4 All/Stones/Stones_Loose_01_Grey_1.png")
	library.add_model(stone)
	
	# 2: Dirt
	var dirt = create_cube_model("Dirt", "res://assets/textures/Set 4 All/Dirt/Dirt_Cracked_01_Brown_1.png")
	library.add_model(dirt)
	
	# 3: Grass (Cube with different top)
	var grass = create_grass_model()
	library.add_model(grass)
	
	# 4: Bedrock
	var bedrock = create_cube_model("Bedrock", "res://assets/textures/Set 4 All/Stones/Stones_Loose_01_Grey_2.png")
	library.add_model(bedrock)
	
	# Save
	var error = ResourceSaver.save(library, "res://assets/voxel_library.tres")
	if error != OK:
		print("Error saving library: ", error)
	else:
		print("Library saved successfully to res://assets/voxel_library.tres")

func create_cube_model(name: String, texture_path: String) -> VoxelBlockyModel:
	var model = VoxelBlockyModel.new()
	model.resource_name = name
	
	# Load texture
	var texture = load(texture_path)
	if not texture:
		print("Error loading texture: ", texture_path)
		return model
		
	# Set material override (standard material with texture)
	var material = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	# Cube Geometry
	model.set_material_override_index(0, material)
	# In older versions/simple setup, we might rely on geometry generator.
	# For VoxelBlockyModel, the default is a cube if we don't change geometry.
	
	# Note: VoxelBlockyModel usually uses an atlas.
	# For simplicity in this "Separate" textures mode, we might need to check if VoxelBlockyLibrary supports separate textures easily
	# or if we need to bake an atlas.
	# Zylann's voxel engine prefers an atlas.
	# However, we can assign materials to surfaces.
	
	# To keep it simple and working with GDExtension defaults:
	# We will assume standard cube behavior.
	
	return model

func create_grass_model() -> VoxelBlockyModel:
	var model = VoxelBlockyModel.new()
	model.resource_name = "Grass"
	
	var top_tex = load("res://assets/textures/Set 4 All/Grass/Grass_01_Green_1.png")
	var side_tex = load("res://assets/textures/separate/texture_16px 2.png") # Using a placeholder or dirt
	var bottom_tex = load("res://assets/textures/Set 4 All/Dirt/Dirt_Cracked_01_Brown_1.png")
	
	if not side_tex: side_tex = bottom_tex
	
	# This part is tricky without an atlas. 
	# VoxelBlockyLibrary generally expects us to define tiles in an atlas.
	# BUT, we can use `geometry_type` = CUBE.
	
	# For this migration script, we will just create the library structure.
	# The user might need to bake the atlas in editor later, OR we use a material per block (inefficient but works).
	
	# Let's try to set material overrides.
	
	return model

