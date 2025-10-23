@tool
class_name BlockType extends Resource

enum BlockShape { FULL, SLAB, STAIRS, SLOPE, CORNER }

@export var block_name: String
@export var shape: BlockShape = BlockShape.FULL
@export var texture: Texture2D # For simple cases
@export var is_solid: bool = true
@export var transparency: float = 0.0 # 0 = opaque, 1 = fully transparent
