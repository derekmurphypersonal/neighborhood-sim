extends RefCounted
## The "Large" text size setting: the side panel, the feed and the sheets get
## a copy of the interface theme with every font size raised, and font sizes
## set on single controls are raised by the same factor. Each control keeps
## its normal size in a meta value, so switching back is exact. Presentation
## only.

## How much larger "Large" text is than "Normal".
const LARGE_FACTOR: float = 1.14
## The font-size names a control may override (Label, Button, RichTextLabel).
const SIZE_NAMES: Array[String] = [
	"font_size", "normal_font_size", "bold_font_size", "italics_font_size",
	"bold_italics_font_size", "mono_font_size",
]


static func factor(large: bool) -> float:
	return LARGE_FACTOR if large else 1.0


## A copy of base with its default font size and every font size raised.
static func scaled_theme(base: Theme, by: float) -> Theme:
	var copy: Theme = base.duplicate(true) as Theme
	copy.default_font_size = roundi(float(base.default_font_size) * by)
	for type_name: String in base.get_font_size_type_list():
		for size_name: String in base.get_font_size_list(type_name):
			copy.set_font_size(size_name, type_name, roundi(float(base.get_font_size(size_name, type_name)) * by))
	return copy


## Controls with this meta set to true keep their size (for rows laid out to
## an exact width, such as the household tabs).
const FIXED_META: String = "text_size_fixed"


## Raises (or restores) the font sizes set on root and every control under it.
static func scale_overrides(root: Node, by: float) -> void:
	if root is Control and bool(root.get_meta(FIXED_META, false)):
		var fixed: Control = root as Control
		# Pinned at the theme's normal size, whatever theme it sits under.
		for size_name: String in SIZE_NAMES:
			if fixed.has_meta("normal_" + size_name):
				fixed.add_theme_font_size_override(size_name, int(fixed.get_meta("normal_" + size_name)))
	elif root is Control:
		var control: Control = root as Control
		for size_name: String in SIZE_NAMES:
			var key: String = "normal_" + size_name
			if not control.has_meta(key):
				if not control.has_theme_font_size_override(size_name):
					continue
				control.set_meta(key, control.get_theme_font_size(size_name))
			control.add_theme_font_size_override(size_name, roundi(float(int(control.get_meta(key))) * by))
	for child: Node in root.get_children():
		scale_overrides(child, by)
