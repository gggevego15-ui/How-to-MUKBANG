extends Node
## Interactive self-service ordering for the mall kiosks.

const PRODUCTS := [
	{"name": "Хрустящая курочка", "category": "КУРОЧКА", "price": 249, "emoji": "🍗"},
	{"name": "Острая курочка", "category": "КУРОЧКА", "price": 279, "emoji": "🌶"},
	{"name": "Куриные крылышки", "category": "КУРОЧКА", "price": 229, "emoji": "🍗"},
	{"name": "Наггетсы", "category": "КУРОЧКА", "price": 179, "emoji": "🍗"},
	{"name": "Ролл с лососем", "category": "РОЛЛЫ", "price": 329, "emoji": "🍣"},
	{"name": "Калифорния", "category": "РОЛЛЫ", "price": 289, "emoji": "🍣"},
	{"name": "Филадельфия", "category": "РОЛЛЫ", "price": 349, "emoji": "🍣"},
	{"name": "Запечённые роллы", "category": "РОЛЛЫ", "price": 319, "emoji": "🍱"},
	{"name": "Бургер", "category": "ФАСТФУД", "price": 259, "emoji": "🍔"},
	{"name": "Картошка фри", "category": "ФАСТФУД", "price": 129, "emoji": "🍟"},
	{"name": "Пицца пепперони", "category": "ФАСТФУД", "price": 399, "emoji": "🍕"},
	{"name": "Лапша вок", "category": "ФАСТФУД", "price": 299, "emoji": "🍜"},
	{"name": "Кола", "category": "НАПИТКИ", "price": 99, "emoji": "🥤"},
	{"name": "Лимонад", "category": "НАПИТКИ", "price": 119, "emoji": "🍋"},
	{"name": "Молочный коктейль", "category": "НАПИТКИ", "price": 179, "emoji": "🥤"},
	{"name": "Холодный чай", "category": "НАПИТКИ", "price": 109, "emoji": "🧋"},
	{"name": "Пончик", "category": "ДЕСЕРТЫ", "price": 139, "emoji": "🍩"},
	{"name": "Чизкейк", "category": "ДЕСЕРТЫ", "price": 199, "emoji": "🍰"}
]

var _player: CharacterBody3D
var _near_kiosk := false
var _menu_open := false
var _cart: Dictionary = {}
var _balance := 5000
var _root: Control
var _hint: Label
var _balance_label: Label
var _cart_label: Label
var _items_box: VBoxContainer
var _mobile_order_button: Button
var _status_label: Label
var _food_service: Node
var _panel: PanelContainer
var _shade: ColorRect
var _columns: HBoxContainer
var _list_panel: PanelContainer
var _cart_panel: PanelContainer
var _category_bar: HBoxContainer
var _active_category := "ВСЁ"
var _product_count_label: Label

func _ready() -> void:
	_player = get_parent().get_node_or_null("Player") as CharacterBody3D
	_food_service = Node.new()
	_food_service.name = "FoodService"
	_food_service.set_script(load("res://scripts/food_service.gd"))
	add_child(_food_service)
	_build_ui()
	_food_service.delivery_started.connect(_on_delivery_started)
	_food_service.delivery_completed.connect(_on_delivery_completed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_layout_order_ui")

func _layout_order_ui() -> void:
	if _panel == null or _columns == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 1050.0 or viewport_size.y < 700.0
	var margin := 18.0
	_panel.position = Vector2(margin, margin)
	_panel.size = Vector2(maxf(320.0, viewport_size.x - margin * 2.0), maxf(280.0, viewport_size.y - margin * 2.0))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(margin, margin)
	_panel.size = Vector2(maxf(320.0, viewport_size.x - margin * 2.0), maxf(280.0, viewport_size.y - margin * 2.0))
	_columns.vertical = compact
	if compact:
		_list_panel.custom_minimum_size = Vector2(0, maxf(125.0, viewport_size.y * 0.31))
		_cart_panel.custom_minimum_size = Vector2(0, 0)
		_cart_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_cart_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	else:
		_list_panel.custom_minimum_size = Vector2(0, 0)
		_cart_panel.custom_minimum_size = Vector2(230, 0)
		_cart_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
		_cart_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _category_bar != null:
		_category_bar.add_theme_constant_override("separation", 6 if compact else 10)

func _process(_delta: float) -> void:
	if _player == null:
		return
	var nearest := 9999.0
	for i in range(6):
		var kiosk_pos := Vector3(-17.5 + float(i) * 7.0, 0.0, -32.0)
		nearest = minf(nearest, Vector2(_player.global_position.x - kiosk_pos.x, _player.global_position.z - kiosk_pos.z).length())
	_near_kiosk = nearest < 3.4
	_hint.visible = _near_kiosk and not _menu_open
	_mobile_order_button.visible = false
	if _near_kiosk and Input.is_key_pressed(KEY_E) and not _menu_open:
		_open_menu()
		await get_tree().create_timer(0.25).timeout

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FoodOrderingLayer"
	layer.layer = 180
	add_child(layer)
	_root = Control.new()
	_root.name = "FoodOrderingUI"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_root)

	_hint = Label.new()
	_hint.text = "E  •  ОТКРЫТЬ МЕНЮ ЗАКАЗА"
	_hint.visible = false
	_hint.position = Vector2(0, 90)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.position.x = -155
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color("8ceaff"))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hint.add_theme_constant_override("shadow_offset_x", 2)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	_root.add_child(_hint)

	_mobile_order_button = Button.new()
	_mobile_order_button.text = "ЗАКАЗАТЬ"
	_mobile_order_button.visible = false
	_mobile_order_button.size = Vector2(170, 58)
	_mobile_order_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_mobile_order_button.position = Vector2(-190, -150)
	_style_button(_mobile_order_button, true)
	_mobile_order_button.pressed.connect(_open_menu)
	_root.add_child(_mobile_order_button)

	_shade = ColorRect.new()
	_shade.name = "OrderBackdrop"
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.015, 0.025, 0.05, 0.82)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_shade)
	_shade.visible = false

	_panel = PanelContainer.new()
	_panel.name = "OrderPanel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(18, 18)
	_panel.size = Vector2(900, 700)
	_panel.custom_minimum_size = Vector2(0, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.045, 0.075, 0.99)
	panel_style.border_color = Color(0.22, 0.78, 0.96, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(24)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	_panel.add_child(content)

	var top := HBoxContainer.new()
	content.add_child(top)
	var heading := Label.new()
	heading.text = "NIGHT BITES  /  МЕНЮ"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("f2f8ff"))
	top.add_child(heading)
	_balance_label = Label.new()
	_balance_label.add_theme_font_size_override("font_size", 18)
	_balance_label.add_theme_color_override("font_color", Color("8ceaff"))
	top.add_child(_balance_label)
	var subtitle := Label.new()
	subtitle.text = "Добавляй любимую еду в корзину и оформляй заказ"
	subtitle.add_theme_color_override("font_color", Color("a9bbd0"))
	content.add_child(subtitle)

	_category_bar = HBoxContainer.new()
	_category_bar.add_theme_constant_override("separation", 8)
	content.add_child(_category_bar)
	for category_name in ["ВСЁ", "КУРОЧКА", "РОЛЛЫ", "ФАСТФУД", "НАПИТКИ", "ДЕСЕРТЫ"]:
		var category_button := Button.new()
		category_button.text = str(category_name)
		category_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category_button.custom_minimum_size.y = 38
		_style_button(category_button, category_name == _active_category)
		category_button.pressed.connect(_select_category.bind(str(category_name)))
		_category_bar.add_child(category_button)

	var columns := HBoxContainer.new()
	_columns = columns
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)

	var list_panel := PanelContainer.new()
	_list_panel = list_panel
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list_style := StyleBoxFlat.new()
	list_style.bg_color = Color(0.055, 0.08, 0.12, 1)
	list_style.set_corner_radius_all(12)
	list_panel.add_theme_stylebox_override("panel", list_style)
	columns.add_child(list_panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_child(scroll)
	_items_box = VBoxContainer.new()
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_items_box)

	var cart_panel := PanelContainer.new()
	_cart_panel = cart_panel
	cart_panel.custom_minimum_size.x = 230
	var cart_style := StyleBoxFlat.new()
	cart_style.bg_color = Color(0.07, 0.10, 0.15, 1)
	cart_style.set_corner_radius_all(12)
	cart_panel.add_theme_stylebox_override("panel", cart_style)
	columns.add_child(cart_panel)
	var cart_box := VBoxContainer.new()
	cart_box.add_theme_constant_override("separation", 10)
	cart_panel.add_child(cart_box)
	var cart_heading := Label.new()
	cart_heading.text = "🛒  ТВОЯ КОРЗИНА"
	cart_heading.add_theme_color_override("font_color", Color("8ceaff"))
	cart_box.add_child(cart_heading)
	_cart_label = Label.new()
	_cart_label.custom_minimum_size = Vector2(190, 120)
	_cart_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cart_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	cart_box.add_child(_cart_label)
	_product_count_label = Label.new()
	_product_count_label.text = "18 позиций в меню"
	_product_count_label.add_theme_color_override("font_color", Color("8da6bf"))
	cart_box.add_child(_product_count_label)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color("9ef0bc"))
	cart_box.add_child(_status_label)
	var order_button := Button.new()
	order_button.text = "ОФОРМИТЬ ЗАКАЗ"
	order_button.custom_minimum_size.y = 48
	_style_button(order_button, true)
	order_button.pressed.connect(_place_order)
	cart_box.add_child(order_button)
	var clear_button := Button.new()
	clear_button.text = "ОЧИСТИТЬ"
	clear_button.custom_minimum_size.y = 38
	_style_button(clear_button, false)
	clear_button.pressed.connect(func() -> void:
		_cart.clear()
		_status_label.text = ""
		_refresh_cart()
	)
	cart_box.add_child(clear_button)
	var close_button := Button.new()
	close_button.text = "ЗАКРЫТЬ  [ESC]"
	close_button.custom_minimum_size.y = 38
	_style_button(close_button, false)
	close_button.pressed.connect(_close_menu)
	cart_box.add_child(close_button)

	# Keep direct references for reliable visibility and responsive layout.
	set_meta("order_shade", _shade)
	set_meta("order_panel", _panel)
	_refresh_products()
	_refresh_cart()
	_layout_order_ui()

func _style_button(button: Button, primary: bool) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1689b0") if primary else Color("111e30")
	style.border_color = Color("62d9ff") if primary else Color("354c63")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("26a7d4") if primary else Color("1a2c40")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", Color("f4f9ff"))

func _select_category(category_name: String) -> void:
	_active_category = category_name
	for child in _category_bar.get_children():
		if child is Button:
			_style_button(child, child.text == _active_category)
	_refresh_products()

func _refresh_products() -> void:
	for child in _items_box.get_children():
		child.queue_free()
	var shown := 0
	for i in range(PRODUCTS.size()):
		var item: Dictionary = PRODUCTS[i]
		if _active_category != "ВСЁ" and item["category"] != _active_category:
			continue
		shown += 1
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.07, 0.105, 0.15, 1.0)
		card_style.border_color = Color(0.15, 0.27, 0.36, 1.0)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(12)
		card_style.content_margin_left = 12
		card_style.content_margin_right = 12
		card_style.content_margin_top = 8
		card_style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", card_style)
		_items_box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var emoji := Label.new()
		emoji.text = str(item["emoji"])
		emoji.custom_minimum_size = Vector2(42, 42)
		emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emoji.add_theme_font_size_override("font_size", 27)
		row.add_child(emoji)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_theme_constant_override("separation", 2)
		row.add_child(details)
		var label := Label.new()
		label.text = str(item["name"])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color("f2f7ff"))
		details.add_child(label)
		var price := Label.new()
		price.text = str(item["price"]) + " ₽  ·  " + str(item["category"])
		price.add_theme_font_size_override("font_size", 12)
		price.add_theme_color_override("font_color", Color("8ba9c3"))
		details.add_child(price)
		var add_button := Button.new()
		add_button.text = "+"
		add_button.custom_minimum_size = Vector2(48, 44)
		add_button.add_theme_font_size_override("font_size", 24)
		_style_button(add_button, true)
		add_button.pressed.connect(_add_to_cart.bind(i))
		row.add_child(add_button)
	if _product_count_label != null:
		_product_count_label.text = str(shown) + (" позиций" if shown != 1 else " позиция")

func _add_to_cart(index: int) -> void:
	var item: Dictionary = PRODUCTS[index]
	_cart[index] = int(_cart.get(index, 0)) + 1
	_status_label.text = "Добавлено: " + str(item["name"])
	_refresh_cart()

func _refresh_cart() -> void:
	if _cart_label == null:
		return
	var lines: Array[String] = []
	var total := 0
	for key in _cart.keys():
		var index := int(key)
		var item: Dictionary = PRODUCTS[index]
		var count := int(_cart[key])
		total += int(item["price"]) * count
		lines.append(str(item["name"]) + " ×" + str(count))
	_cart_label.text = "\n".join(lines) if not lines.is_empty() else "Пока пусто —\nдобавь что-нибудь вкусное!"
	_cart_label.text += "\n\nИТОГО: " + str(total) + " ₽"
	_balance_label.text = "Баланс: " + str(_balance) + " ₽"

func _place_order() -> void:
	if _cart.is_empty():
		_status_label.text = "Сначала добавь еду в корзину."
		return
	var total := 0
	for key in _cart.keys():
		var item: Dictionary = PRODUCTS[int(key)]
		total += int(item["price"]) * int(_cart[key])
	if total > _balance:
		_status_label.text = "Не хватает денег! Баланс: " + str(_balance) + " ₽"
		return
	_balance -= total
	var ordered_items: Array[Dictionary] = []
	for key in _cart.keys():
		ordered_items.append({"index": int(key), "count": int(_cart[key])})
	_status_label.text = "Заказ принят! Готовим свежую еду 🍗"
	_cart.clear()
	_refresh_cart()
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	if _food_service != null:
		_food_service.call("serve", ordered_items, PRODUCTS, _player)
	if is_instance_valid(_status_label) and _menu_open:
		_status_label.text = "Официант несёт твой заказ к столу… 🚶🍱"

func _on_delivery_started() -> void:
	if is_instance_valid(_status_label):
		_status_label.text = "Официант несёт твой заказ к столу… 🚶🍱"

func _on_delivery_completed() -> void:
	if is_instance_valid(_status_label):
		_status_label.text = "Заказ доставлен! Приятного аппетита 🍽"

func _open_menu() -> void:
	_menu_open = true
	_shade.visible = true
	_panel.visible = true
	_layout_order_ui()
	_mobile_order_button.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _player != null:
		_player.set_physics_process(false)
	_status_label.text = ""
	_refresh_cart()

func _close_menu() -> void:
	_menu_open = false
	_shade.visible = false
	_panel.visible = false
	_hint.visible = _near_kiosk
	_mobile_order_button.visible = false
	if _player != null:
		_player.set_physics_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if _menu_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_menu()
