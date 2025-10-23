extends Node

# This class will hold the data for our world's grid.
# Instead of storing nodes, we store block data in a dictionary
# for better performance with large worlds.

var blocks = {} # Using a Dictionary to store block data {Vector3i: BlockType}

func set_block(pos: Vector3i, block_type: BlockType):
	blocks[pos] = block_type
	# In a real game, this would trigger a chunk update to redraw the mesh.
	print("Set block at %s to type %s" % [pos, block_type.resource_name])

func get_block(pos: Vector3i) -> BlockType:
	if blocks.has(pos):
		return blocks[pos]
	return null

func remove_block(pos: Vector3i):
	if blocks.has(pos):
		blocks.erase(pos)
		# Trigger chunk update
		print("Removed block at %s" % pos)
