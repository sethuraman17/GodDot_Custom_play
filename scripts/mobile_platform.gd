extends Object
class_name MobilePlatform

## True on Android/iOS exports (and the dedicated mobile feature tag).
## Intentionally ignores laptop touchscreens so Windows keeps mouse/keyboard UI.
static func is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")
