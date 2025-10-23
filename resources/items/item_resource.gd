@tool
class_name ItemResource extends Resource

@export var id: String
@export var item_name: String # 'name' is a property of Resource
@export var icon: Texture2D
@export var max_stack: int = 64
@export var description: String
