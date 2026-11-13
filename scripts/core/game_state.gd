class_name GameStateData
extends RefCounted

## 全局游戏状态（静态变量，跨场景切换保留）
## 不用 autoload：headless --script 测试里 autoload 尚未注册，静态变量两种模式都能用

static var selected_char := "mage"


static func reset() -> void:
	selected_char = "mage"
