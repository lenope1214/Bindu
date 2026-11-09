extends "res://tools/battlefield_load_check.gd"
func snap(label: String) -> void:
	await super.snap(label)
	if label != "inspector-dense": return
	var dock = main.card_dock
	var detail: RichTextLabel = dock.detail
	var font: Font = detail.get_theme_font("normal_font")
	var fs: int = detail.get_theme_font_size("normal_font_size")
	var longest := ""
	var longest_width := 0.0
	var wide: Array = []
	for token: String in detail.text.replace("\n", " ").split(" ", false):
		var width := font.get_string_size(token, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if width > longest_width:
			longest_width = width
			longest = token
		if width > detail.size.x: wide.append({"text":token, "width":width})
	var column: Control = dock.scroll.get_child(0)
	var bar: HScrollBar = dock.scroll.get_h_scroll_bar()
	var data := {"panel":str(dock.side.get_global_rect()), "panel_local_size":str(dock.side.size), "scroll":str(dock.scroll.get_global_rect()), "scroll_local_size":str(dock.scroll.size), "column":str(column.get_global_rect()), "column_minimum":str(column.get_combined_minimum_size()), "detail":str(detail.get_global_rect()), "detail_local_size":str(detail.size), "detail_minimum":str(detail.get_combined_minimum_size()), "content_width":detail.get_content_width(), "content_height":detail.get_content_height(), "font_size":fs, "autowrap":detail.autowrap_mode, "fit_content":detail.fit_content, "horizontal_scroll_max":bar.max_value, "horizontal_scroll_page":bar.page, "longest_token":longest, "longest_token_width":longest_width, "too_wide_tokens":wide, "text":detail.text}
	FileAccess.open(output.path_join("richtext-geometry.json"), FileAccess.WRITE).store_string(JSON.stringify(data, "\t"))
	print("RICHTEXT ", JSON.stringify(data))
