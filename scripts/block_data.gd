class_name BlockData

enum BlockType { EMPTY, DIRT, STONE, GRANITE, GOLD, DIAMOND, LAVA }

var type: BlockType = BlockType.EMPTY
var hardness: int = 0
var heat_value: int = 0
var wear_value: int = 0
var coin_value: int = 0
var color: Color = Color.TRANSPARENT

static func get_block_data(type: BlockType) -> BlockData:
    var data = BlockData.new()
    data.type = type
    match type:
        BlockType.EMPTY:
            data.color = Color(0, 0, 0, 0)
        BlockType.DIRT:
            data.hardness = 1
            data.heat_value = 1
            data.wear_value = 1
            data.coin_value = 1
            data.color = Color("8B6914")
        BlockType.STONE:
            data.hardness = 3
            data.heat_value = 3
            data.wear_value = 2
            data.coin_value = 3
            data.color = Color("808080")
        BlockType.GRANITE:
            data.hardness = 5
            data.heat_value = 5
            data.wear_value = 4
            data.coin_value = 5
            data.color = Color("4A4A4A")
        BlockType.GOLD:
            data.hardness = 2
            data.heat_value = 2
            data.wear_value = 1
            data.coin_value = 15
            data.color = Color("FFD700")
        BlockType.DIAMOND:
            data.hardness = 4
            data.heat_value = 6
            data.wear_value = 3
            data.coin_value = 50
            data.color = Color("00FFFF")
        BlockType.LAVA:
            data.hardness = 0
            data.heat_value = 25
            data.wear_value = 0
            data.coin_value = 0
            data.color = Color("FF4500")
    return data