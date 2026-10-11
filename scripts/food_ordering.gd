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

func _ready() -> void:
	_player = get_parent().get_node_or_null("Player") as CharacterBody3D
	_food_service = Node.new()
	_food_service.name = "FoodService"
	_food_service.set_script(load("res://scripts/food_service.gd"))
	add_child(_food_service)
	_build_ui()
	_food_service.delivery_started.connect(_on_delivery_started)
	_food_service.delivery_completed.connect(_on_delivery_completed)

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

	var shade := ColorRect.new()
	shade.name = "OrderBackdrop"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.05, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)
	shade.visible = false

	var panel := PanelContainer.new()
	panel.name = "OrderPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-350, -300)
	panel.size = Vector2(700, 600)
	panel.custom_minimum_size = Vector2(700, 600)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.055, 0.09, 0.98)
	panel_style.border_color = Color("4fcdf5")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(22)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

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

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	content.add_child(columns)

	var list_panel := PanelContainer.new()
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
	cart_panel.custom_minimum_size.x = 220
	var cart_style := StyleBoxFlat.new()
	cart_style.bg_color = Color(0.07, 0.10, 0.15, 1)
	cart_style.set_corner_radius_all(12)
	cart_panel.add_theme_stylebox_override("panel", cart_style)
	columns.add_child(cart_panel)
	var cart_box := VBoxContainer.new()
	cart_box.add_theme_constant_override("separation", 10)
	cart_panel.add_child(cart_box)
	var cart_heading := Label.new()
	cart_heading.text = "ТВОЯ КОРЗИНА"
	cart_heading.add_theme_color_override("font_color", Color("8ceaff"))
	cart_box.add_child(cart_heading)
	_cart_label = Label.new()
	_cart_label.custom_minimum_size = Vector2(190, 180)
	_cart_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cart_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	cart_box.add_child(_cart_label)
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

	# Store references to the shade and panel for toggling visibility.
	set_meta("order_shade", shade)
	set_meta("order_panel", panel)
	_refresh_products()
	_refresh_cart()

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

func _refresh_products() -> void:
	for child in _items_box.get_children():
		child.queue_free()
	var categories := ["КУРОЧКА", "РОЛЛЫ", "ФАСТФУД", "НАПИТКИ", "ДЕСЕРТЫ"]
	for category in categories:
		var category_label := Label.new()
		category_label.text = "— " + category + " —"
		category_label.add_theme_color_override("font_color", Color("67d9ff"))
		category_label.add_theme_font_size_override("font_size", 15)
		_items_box.add_child(category_label)
		for i in range(PRODUCTS.size()):
			var item: Dictionary = PRODUCTS[i]
			if item["category"] != category:
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_items_box.add_child(row)
			var label := Label.new()
			label.text = str(item["emoji"]) + "  " + str(item["name"]) + "  •  " + str(item["price"]) + " ₽"
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.add_theme_font_size_override("font_size", 13)
			row.add_child(label)
			var add_button := Button.new()
			add_button.text = "+ ДОБАВИТЬ"
			add_button.custom_minimum_size = Vector2(105, 34)
			_style_button(add_button, false)
			add_button.pressed.connect(_add_to_cart.bind(i))
			row.add_child(add_button)

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
	get_meta("order_shade").visible = true
	get_meta("order_panel").visible = true
	_mobile_order_button.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _player != null:
		_player.set_physics_process(false)
	_status_label.text = ""
	_refresh_cart()

func _close_menu() -> void:
	_menu_open = false
	get_meta("order_shade").visible = false
	get_meta("order_panel").visible = false
	_hint.visible = _near_kiosk
	_mobile_order_button.visible = false
	if _player != null:
		_player.set_physics_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if _menu_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_menu()
