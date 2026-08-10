extends SceneTree

const CUSTOMER_QUEUE_SERVICE_SCRIPT := preload("res://scripts/services/customer_queue_service.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_run()


func _run() -> void:
	_test_two_sided_cooking_and_two_sauces()
	_test_beginner_heat_window()
	_test_egg_spreading_and_score()
	_test_egg_spread_performance()
	_test_order_and_session_guards()
	_test_unflipped_sauce_and_toppings_skip_flip()
	_test_customer_reaction_persists_after_handoff()
	_test_customer_queue_rotation()
	_test_every_order_combination()
	_test_ingredients_affect_fold_and_score()
	_test_repair_tags_and_score_caps()
	_finish()


func _test_two_sided_cooking_and_two_sauces() -> void:
	var model := _uniform_pancake(48, 0.42)
	model.advance_cooking(4.0, 0.8)
	var first_side := model.mean_side_doneness(false)
	_check(first_side > 0.0 and is_zero_approx(model.mean_side_doneness(true)), "cooking initially advances only the first side")
	model.flip()
	model.advance_cooking(3.0, 0.8)
	_check(model.is_flipped and model.mean_side_doneness(true) > 0.0, "flip exposes and cooks the independent second side")
	var center := Vector2(24, 24)
	var sweet_stroke := model.begin_sauce_stroke()
	model.apply_sauce_sample(center, 0.35, 6.0, sweet_stroke, 9999, OrderService.SAUCE_SWEET)
	var sweet_total := model.total_sauce(OrderService.SAUCE_SWEET)
	var chili_stroke := model.begin_sauce_stroke()
	model.apply_sauce_sample(center, 0.35, 6.0, chili_stroke, 9999, OrderService.SAUCE_CHILI)
	_check(sweet_total > 0.0 and model.total_sauce(OrderService.SAUCE_CHILI) > 0.0, "sweet and chili sauce write independent concentration fields")
	model.reset()
	_check(model.total_sauce(OrderService.SAUCE_SWEET) == 0.0 and model.total_sauce(OrderService.SAUCE_CHILI) == 0.0 and not model.is_flipped, "reset clears both sauces and flip state")


func _test_beginner_heat_window() -> void:
	var minimum_heat_model := _uniform_pancake(48, 0.42)
	for step in 1200:
		minimum_heat_model.advance_cooking(0.05, 0.20)
	var minimum_heat_doneness := minimum_heat_model.mean_side_doneness(false)
	_check(minimum_heat_doneness >= 0.30, "minimum heat still cooks a normal pancake within one novice minute")
	_check(minimum_heat_doneness < 0.72, "minimum heat leaves a safe non-charred novice window after one minute")
	var default_heat_model := _uniform_pancake(48, 0.42)
	for step in 700:
		default_heat_model.advance_cooking(0.05, 0.50)
	_check(default_heat_model.mean_side_doneness(false) < 0.86, "default heat does not make a normal pancake brittle during a 35-second learning window")


func _test_egg_spreading_and_score() -> void:
	var post_flip_model := _uniform_pancake(64, 0.42)
	post_flip_model.flip()
	var post_flip_center := Vector2(32, 32)
	_check(bool(post_flip_model.crack_egg(post_flip_center).get("success", false)) and post_flip_model.egg_is_on_visible_side(), "an egg can be cracked onto the visible side after flipping")
	for step in 48:
		var angle := TAU * float(step) / 48.0
		post_flip_model.apply_egg_spreader_sample(post_flip_center + Vector2.from_angle(angle) * 8.0, Vector2.from_angle(angle), 70.0)
	_check(post_flip_model.yolk_broken and post_flip_model.egg_is_on_visible_side(), "a post-flip egg can be spread on its visible side")
	post_flip_model.flip()
	_check(not post_flip_model.egg_is_on_visible_side(), "turning away from the egg side hides that egg layer")

	var multi_egg_model := _uniform_pancake(128, 0.42)
	_check(bool(multi_egg_model.crack_egg(Vector2(54, 64)).success), "the first egg can be cracked onto the pancake")
	var first_egg_mass := multi_egg_model.total_egg_amount()
	_check(
		bool(multi_egg_model.crack_egg(Vector2(74, 64)).success)
		and multi_egg_model.total_egg_amount() > first_egg_mass,
		"the pancake simulation accepts and accumulates a second egg"
	)
	var model := _uniform_pancake(128, 0.42)
	var center := Vector2(64, 64)
	var crack_result := model.crack_egg(center)
	_check(bool(crack_result.success) and model.egg_state == PancakeModel.EggState.CRACKED, "cracking an egg creates a model-backed liquid layer")
	var initial_summary := model.calculate_egg_spread_summary()
	var initial_mass := model.total_egg_amount()
	# Four widening circles model a hesitant first-time player, not a perfect long automation trace.
	for ring in 4:
		var radius := 6.0 + float(ring) * 9.0
		for step in 36:
			var angle := TAU * float(step) / 36.0
			var radial := Vector2(cos(angle), sin(angle) * model.parameters.pan_height_ratio)
			var sample := center + radial * radius
			model.apply_egg_spreader_sample(sample, Vector2.from_angle(angle), 70.0)
	var spread_summary := model.calculate_egg_spread_summary()
	_check(model.yolk_broken and model.egg_state == PancakeModel.EggState.SPREADING, "T-spreader contact breaks the yolk and enters the spreading state")
	_check(float(spread_summary.coverage_ratio) > float(initial_summary.coverage_ratio), "continuous circular samples expand egg coverage")
	_check(float(spread_summary.coverage_ratio) >= model.parameters.egg_minimum_spread_coverage, "four beginner circles reach the minimum egg-spread gate")
	_check(
		float(spread_summary.coverage_ratio) >= 0.55,
		"four beginner circles visibly spread egg across most of the pancake (actual %.1f percent)" % (float(spread_summary.coverage_ratio) * 100.0)
	)
	_check(float(spread_summary.score) > float(initial_summary.score), "expanded, broken-yolk egg receives a higher spread score")
	_check(model.total_egg_amount() <= initial_mass * 1.001, "egg spreading does not create liquid mass")

	var order := OrderService.new().order_at(0)
	var good_model := _uniform_pancake(64, 0.42)
	var poor_model := _uniform_pancake(64, 0.42)
	_seed_even_egg(good_model)
	_seed_poor_egg(poor_model)
	for scored_model in [good_model, poor_model]:
		scored_model.doneness.fill(0.64)
		scored_model.back_doneness.fill(0.64)
		scored_model.sauce_concentration.fill(0.35)
	var good_ingredients := _classic_ingredients(good_model)
	var poor_ingredients := _classic_ingredients(poor_model)
	var good_fold := PancakeFoldModel.new(good_model, good_ingredients)
	var poor_fold := PancakeFoldModel.new(poor_model, poor_ingredients)
	_fold_both(good_fold)
	_fold_both(poor_fold)
	good_fold.package_with(PancakeFoldModel.PACKAGE_BAG)
	poor_fold.package_with(PancakeFoldModel.PACKAGE_BAG)
	var good_score := PancakeScorer.evaluate_order(good_model, good_ingredients, good_fold, order, 48.0, 0.6)
	var poor_score := PancakeScorer.evaluate_order(poor_model, poor_ingredients, poor_fold, order, 48.0, 0.6)
	_check(float(good_score.dimensions.egg) > float(poor_score.dimensions.egg), "egg coverage and uniformity produce an independent score dimension")
	_check(float(good_score.score) > float(poor_score.score), "egg spreading quality changes the final customer score")
	var stored_product := {"serving_score_basis": Dictionary(good_score.get("serving_score_basis", {})).duplicate(true)}
	var same_order_score := PancakeScorer.evaluate_stored_product(stored_product, order, 48.0, 0.6)
	_check(is_equal_approx(float(same_order_score.get("score", 0.0)), float(good_score.score)), "stored score basis reproduces the fresh-made score for the same order")
	var different_order := OrderService.new().order_at(1)
	var different_order_score := PancakeScorer.evaluate_stored_product(stored_product, different_order, 48.0, 0.6)
	_check(float(different_order_score.get("score", 0.0)) < float(same_order_score.get("score", 0.0)), "stored pancake is rescored against the receiving customer's actual order")


func _test_egg_spread_performance() -> void:
	var model := _uniform_pancake(128, 0.42)
	var center := Vector2(64, 64)
	model.crack_egg(center)
	var frame_times_usec := PackedInt64Array()
	var ring_maximums_usec := PackedInt64Array()
	for ring in 4:
		var samples := PackedVector2Array()
		var radius := 6.0 + float(ring) * 9.0
		for step in 36:
			var angle := TAU * float(step) / 36.0
			var radial := Vector2(cos(angle), sin(angle) * model.parameters.pan_height_ratio)
			samples.append(center + radial * radius)
		var ring_maximum_usec := 0
		for frame_start in range(0, samples.size(), model.parameters.egg_max_samples_per_frame):
			var frame_samples := PackedVector2Array()
			for sample_index in range(frame_start, mini(frame_start + model.parameters.egg_max_samples_per_frame, samples.size())):
				frame_samples.append(samples[sample_index])
			var started := Time.get_ticks_usec()
			model.apply_egg_spreader_path(frame_samples, 70.0)
			var frame_time_usec := Time.get_ticks_usec() - started
			frame_times_usec.append(frame_time_usec)
			ring_maximum_usec = maxi(ring_maximum_usec, frame_time_usec)
		ring_maximums_usec.append(ring_maximum_usec)
	var maximum_frame_usec := 0
	for frame_time_usec in frame_times_usec:
		maximum_frame_usec = maxi(maximum_frame_usec, frame_time_usec)
	var bounded_growth_limit := maxi(ring_maximums_usec[0] * 3, 12000)
	print("Egg spread bounded-frame maxima (usec): %s" % [ring_maximums_usec])
	_check(maximum_frame_usec <= 16000, "the bounded egg frame budget stays below 16 ms")
	_check(ring_maximums_usec[ring_maximums_usec.size() - 1] <= bounded_growth_limit, "egg spreading cost stays bounded as coverage grows")


func _test_order_and_session_guards() -> void:
	var service := OrderService.new()
	var first := service.next_order()
	var second := service.next_order()
	_check(first.id == &"classic" and second.id == &"chili_ham", "order service provides a deterministic playable order sequence")
	var empty_model := PancakeModel.new(48)
	var empty_session := P1Session.new()
	empty_session.start(first)
	_check(not bool(empty_session.confirm_spread(empty_model).success), "spreading cannot finish when no pancake exists")
	var tiny_model := PancakeModel.new(48)
	var tiny_index := tiny_model.index_of(Vector2i(24, 24))
	tiny_model.coverage[tiny_index] = 1.0
	tiny_model.thickness[tiny_index] = 0.42
	var tiny_session := P1Session.new()
	tiny_session.start(first)
	_check(
		bool(tiny_session.confirm_spread(tiny_model).success)
		and tiny_session.phase == P1Session.Phase.FIRST_SIDE,
		"any real pancake shape can finish spreading without a fifty-percent coverage gate"
	)
	var model := _uniform_pancake(48, 0.42)
	var ingredients := IngredientModel.new()
	var session := P1Session.new()
	session.start(first)
	_check(bool(session.confirm_spread(model).success) and session.phase == P1Session.Phase.FIRST_SIDE, "internal spread confirmation advances to first-side cooking")
	var early_model := _uniform_pancake(48, 0.42)
	var early_ingredients := IngredientModel.new()
	var early_session := P1Session.new()
	early_session.start(first)
	early_session.confirm_spread(early_model)
	early_model.doneness.fill(0.05)
	var early_readiness := early_session.flip_readiness(early_model, early_ingredients)
	var early_flip := early_session.request_flip(early_model, early_ingredients)
	_check(
		bool(early_readiness.get("success", false))
		and bool(early_readiness.get("early_flip", false))
		and bool(early_flip.get("success", false))
		and early_model.is_flipped,
		"an undercooked pancake may flip immediately with an explicit quality warning"
	)
	model.doneness.fill(0.50)
	_check(bool(session.flip_readiness(model, ingredients).success), "egg is optional and does not block flip readiness")
	_check(bool(session.request_flip(model, ingredients).success) and session.phase == P1Session.Phase.SAUCE_AND_FILLINGS, "egg-free pancake can flip immediately once the bottom is cooked")
	var early_score := PancakeScorer.evaluate_order(early_model, early_ingredients, PancakeFoldModel.new(early_model, early_ingredients), first, 0.0, 1.0)
	var ready_score := PancakeScorer.evaluate_order(model, ingredients, PancakeFoldModel.new(model, ingredients), first, 0.0, 1.0)
	_check(
		float(Dictionary(early_score.get("dimensions", {})).get("heat", 0.0)) < float(Dictionary(ready_score.get("dimensions", {})).get("heat", 0.0))
		and float(early_score.get("score", 0.0)) < float(ready_score.get("score", 0.0)),
		"early flipping is permitted but produces a lower heat dimension and lower order score"
	)
	var egg_model := _uniform_pancake(48, 0.42)
	var egg_session := P1Session.new()
	egg_session.start(first)
	egg_session.confirm_spread(egg_model)
	var egg_ingredients := IngredientModel.new()
	egg_ingredients.place(IngredientModel.EGG, Vector2(24, 24), 0.0, egg_model)
	egg_model.doneness.fill(0.50)
	var incomplete_egg := egg_model.calculate_egg_spread_summary()
	_check(float(incomplete_egg.coverage_ratio) < egg_model.parameters.egg_minimum_spread_coverage, "unspread egg begins below the quality-coverage target")
	_check(bool(egg_session.request_flip(egg_model, egg_ingredients).success) and egg_session.phase == P1Session.Phase.SAUCE_AND_FILLINGS, "incomplete egg coverage no longer blocks flipping and is left to scoring")
	_check(is_equal_approx(model.mean_side_doneness(true), model.mean_side_doneness(false)), "quick flip settles the second-side heat without a waiting stage")
	_check(bool(session.begin_folding().success) and session.phase == P1Session.Phase.FOLD, "state machine reaches folding without a dead end")
	_check(bool(session.mark_ready_for_package().success) and session.phase == P1Session.Phase.PACKAGE, "state machine reaches packaging without direct phase mutation")
	_check(bool(session.mark_packaged().success) and session.phase == P1Session.Phase.READY_TO_SERVE, "valid packaging reaches the serving phase")
	_check(bool(session.begin_handoff({"score": 80.0}).success) and session.phase == P1Session.Phase.HANDOFF and not session.payment_ready, "clicking the packaged product starts a guarded customer handoff")
	_check(bool(session.begin_payment().success) and session.phase == P1Session.Phase.PAYMENT and not session.payment_ready, "customer acceptance advances to the payment phase")
	_check(bool(session.finish_payment().success) and session.phase == P1Session.Phase.RESULT and session.payment_ready, "coin settlement reaches the completed result")
	var tray_session := P1Session.new()
	tray_session.start(first)
	tray_session.confirm_spread(model)
	tray_session.advance_time(12.0)
	var tray_handoff := tray_session.begin_handoff_from_tray({"score": 74.0})
	_check(bool(tray_handoff.get("success", false)) and tray_session.has_suspended_tray_production() and tray_session.phase == P1Session.Phase.HANDOFF, "tray delivery suspends an in-progress pancake from any production phase")
	_check(not bool(tray_session.begin_handoff_from_tray({"score": 80.0}).get("success", false)), "a tray cannot be delivered twice during the same customer transaction")
	tray_session.begin_payment()
	tray_session.finish_payment()
	var resumed := tray_session.resume_production_for_next_order(second)
	_check(bool(resumed.get("success", false)) and tray_session.phase == P1Session.Phase.FIRST_SIDE and tray_session.order.id == second.id, "payment resumes the exact production phase for the next customer")
	_check(is_zero_approx(tray_session.elapsed_seconds) and is_equal_approx(tray_session.patience_seconds, float(second.time_limit)), "the next customer's patience resets without resetting pancake production")
	for production_phase in [
		P1Session.Phase.SPREAD,
		P1Session.Phase.FIRST_SIDE,
		P1Session.Phase.SECOND_SIDE,
		P1Session.Phase.SAUCE_AND_FILLINGS,
		P1Session.Phase.FOLD,
		P1Session.Phase.PACKAGE,
		P1Session.Phase.READY_TO_SERVE,
	]:
		var phase_session := P1Session.new()
		phase_session.start(first)
		phase_session.phase = production_phase
		var phase_handoff := phase_session.begin_handoff_from_tray({"score": 70.0})
		phase_session.begin_payment()
		phase_session.finish_payment()
		var phase_resume := phase_session.resume_production_for_next_order(second)
		_check(bool(phase_handoff.get("success", false)) and bool(phase_resume.get("success", false)) and phase_session.phase == production_phase, "tray handoff preserves production phase %s" % str(production_phase))


func _test_unflipped_sauce_and_toppings_skip_flip() -> void:
	var order := OrderService.new().order_at(0)
	var sauce_model := _uniform_pancake(48, 0.42)
	var sauce_session := P1Session.new()
	sauce_session.start(order)
	sauce_session.confirm_spread(sauce_model)
	var sauce_result := sauce_session.begin_sauce_and_fillings_without_flip()
	var repeated_sauce_result := sauce_session.begin_sauce_and_fillings_without_flip()
	_check(
		bool(sauce_result.get("success", false))
		and bool(sauce_result.get("without_flip", false))
		and bool(repeated_sauce_result.get("success", false))
		and bool(repeated_sauce_result.get("already_active", false))
		and sauce_session.phase == P1Session.Phase.SAUCE_AND_FILLINGS
		and not sauce_model.is_flipped,
		"starting sauce before flipping enters an idempotent no-flip preparation stage"
	)
	var sauce_flip_result := sauce_session.request_flip(sauce_model, IngredientModel.new())
	_check(not bool(sauce_flip_result.get("success", false)) and not sauce_model.is_flipped, "starting no-flip sauce permanently closes the flip path for this pancake")
	_check(bool(sauce_session.begin_folding().get("success", false)) and sauce_session.phase == P1Session.Phase.FOLD, "no-flip sauce preparation still reaches guarded folding")

	var model := _uniform_pancake(48, 0.42)
	var ingredients := IngredientModel.new()
	var session := P1Session.new()
	session.start(order)
	session.confirm_spread(model)
	ingredients.place(IngredientModel.BAOCUI, Vector2(24, 24), 0.0, model)
	_check(ingredients.has_toppings(), "non-egg ingredients are recognized as toppings")
	var preparation_result := session.begin_folding_after_topping(ingredients)
	_check(
		bool(preparation_result.get("success", false))
		and session.phase == P1Session.Phase.SAUCE_AND_FILLINGS
		and not model.is_flipped,
		"placing a topping before flipping skips the flip but keeps sauce and filling preparation open"
	)
	_check(bool(session.begin_folding().get("success", false)) and session.phase == P1Session.Phase.FOLD, "the first real fold action closes no-flip preparation")
	var guarded_model := _uniform_pancake(48, 0.42)
	var guarded_ingredients := IngredientModel.new()
	var guarded_session := P1Session.new()
	guarded_session.start(order)
	guarded_session.confirm_spread(guarded_model)
	guarded_model.doneness.fill(0.80)
	guarded_ingredients.place(IngredientModel.BAOCUI, Vector2(24, 24), 0.0, guarded_model)
	var flip_result := guarded_session.request_flip(guarded_model, guarded_ingredients)
	_check(
		not bool(flip_result.get("success", false))
		and bool(flip_result.get("requires_folding", false))
		and guarded_session.phase == P1Session.Phase.SAUCE_AND_FILLINGS
		and not guarded_model.is_flipped,
		"the guarded flip action keeps topping-first preparation open without flipping"
	)


func _test_customer_reaction_persists_after_handoff() -> void:
	var order := OrderService.new().order_at(0)
	var waited_satisfied := _ready_session(order)
	waited_satisfied.advance_time(float(order.time_limit) * 0.75)
	_check(waited_satisfied.is_impatient_now(), "customer becomes impatient before receiving the order")
	waited_satisfied.begin_handoff({"score": 82.0})
	_check(
		waited_satisfied.impatient_at_handoff
		and waited_satisfied.post_handoff_reaction() == P1Session.REACTION_IMPATIENT,
		"a good pancake does not erase impatience already reached while waiting"
	)
	var waited_dissatisfied := _ready_session(order)
	waited_dissatisfied.advance_time(float(order.time_limit) * 0.75)
	waited_dissatisfied.begin_handoff({"score": 55.0})
	_check(
		waited_dissatisfied.post_handoff_reaction() == P1Session.REACTION_VERY_UNHAPPY,
		"an impatient customer becomes more unhappy when the pancake is also unsatisfactory"
	)
	var timely_dissatisfied := _ready_session(order)
	timely_dissatisfied.begin_handoff({"score": 55.0})
	_check(
		timely_dissatisfied.post_handoff_reaction() == P1Session.REACTION_IMPATIENT,
		"an on-time but unsatisfactory pancake still produces the ordinary unhappy reaction"
	)


func _ready_session(order: Dictionary) -> P1Session:
	var model := _uniform_pancake(48, 0.42)
	var ingredients := IngredientModel.new()
	var session := P1Session.new()
	session.start(order)
	session.confirm_spread(model)
	ingredients.place(IngredientModel.EGG, Vector2(24, 24), 0.0, model)
	_seed_even_egg(model)
	model.doneness.fill(0.50)
	session.request_flip(model, ingredients)
	session.begin_folding()
	session.mark_ready_for_package()
	session.mark_packaged()
	return session


func _test_customer_queue_rotation() -> void:
	var queue: RefCounted = CUSTOMER_QUEUE_SERVICE_SCRIPT.new(OrderService.new())
	var initial: Array = queue.call("queue_snapshot")
	_check(
		initial.size() == 3
		and initial[0].id == &"customer_01"
		and initial[1].id == &"customer_02"
		and initial[2].id == &"customer_03",
		"customer service starts with one active customer and two visible waiting customers"
	)
	var next_customer: Dictionary = queue.call("advance_queue")
	var waiting: Array = queue.call("waiting_customers")
	_check(
		next_customer.id == &"customer_02"
		and next_customer.order.id == &"chili_ham"
		and waiting.size() == 2
		and waiting[0].id == &"customer_03"
		and waiting[1].id == &"customer_04",
		"completing an order advances the queue and replenishes its tail without a manual accept step"
	)
func _test_every_order_combination() -> void:
	var service := OrderService.new()
	for order_index in OrderService.ORDERS.size():
		var order := service.order_at(order_index)
		var model := _uniform_pancake(64, 0.42)
		_seed_even_egg(model)
		model.doneness.fill(_target_doneness(order.heat_preference))
		model.back_doneness.fill(_target_doneness(order.heat_preference))
		for sauce_type in order.sauces:
			var field: PackedFloat32Array = model.chili_sauce_concentration if sauce_type == OrderService.SAUCE_CHILI else model.sauce_concentration
			field.fill(0.35)
		var ingredients := IngredientModel.new()
		var ingredient_offset := 0
		for ingredient_type in order.ingredients:
			ingredients.place(ingredient_type, Vector2(28 + ingredient_offset * 3, 30 + ingredient_offset * 2), 0.0, model)
			ingredient_offset += 1
		var fold := PancakeFoldModel.new(model, ingredients)
		_fold_both(fold)
		fold.package_with(PancakeFoldModel.PACKAGE_BAG)
		var result := PancakeScorer.evaluate_order(model, ingredients, fold, order, 45.0, 0.7)
		_check(is_equal_approx(float(result.dimensions.order), 100.0) and result.missing_ingredients.is_empty() and result.missing_sauces.is_empty(), "order correctness accepts combination %s" % order.id)


func _test_ingredients_affect_fold_and_score() -> void:
	var order := OrderService.new().order_at(0)
	var model := _uniform_pancake(64, 0.42)
	_seed_even_egg(model)
	model.doneness.fill(0.64)
	model.back_doneness.fill(0.64)
	model.sauce_concentration.fill(0.35)
	var ingredients := IngredientModel.new()
	ingredients.place(IngredientModel.EGG, Vector2(32, 32), 0.0, model)
	ingredients.place(IngredientModel.BAOCUI, Vector2(31, 28), 0.1, model)
	ingredients.place(IngredientModel.SCALLION, Vector2(35, 36), -0.2, model)
	var fold := PancakeFoldModel.new(model, ingredients)
	_fold_both(fold)
	_check(fold.can_use_bag(), "two intact folds expose the normal paper-bag path")
	fold.package_with(PancakeFoldModel.PACKAGE_BAG)
	var complete := PancakeScorer.evaluate_order(model, ingredients, fold, order, 48.0, 0.60)
	var missing_ingredients := IngredientModel.new()
	var missing_fold := PancakeFoldModel.new(model, missing_ingredients)
	_fold_both(missing_fold)
	missing_fold.package_with(PancakeFoldModel.PACKAGE_BAG)
	var incomplete := PancakeScorer.evaluate_order(model, missing_ingredients, missing_fold, order, 48.0, 0.60)
	_check(float(complete.dimensions.order) > float(incomplete.dimensions.order), "missing required ingredients reduce order correctness")
	_check(float(complete.score) > float(incomplete.score) and not str(complete.feedback).is_empty(), "complete product scores above an incomplete order and produces customer feedback")

	var loaded_ingredients := IngredientModel.new()
	loaded_ingredients.place(IngredientModel.BAOCUI, Vector2(10, 32), 0.0, model)
	loaded_ingredients.place(IngredientModel.HAM_SAUSAGE, Vector2(12, 30), 0.0, model)
	var loaded_fold := PancakeFoldModel.new(model, loaded_ingredients)
	var loaded_result := _fold_left(loaded_fold)
	_check(loaded_result.outcome == PancakeFoldModel.OUTCOME_THICK, "heavy fillings in a flap create a visible bulged-fold outcome")


func _test_repair_tags_and_score_caps() -> void:
	var order := OrderService.new().order_at(0)
	var sleeve_model := _uniform_pancake(64, 0.42)
	_seed_even_egg(sleeve_model)
	sleeve_model.doneness.fill(0.64)
	sleeve_model.back_doneness.fill(0.64)
	sleeve_model.sauce_concentration.fill(0.35)
	var sleeve_ingredients := IngredientModel.new()
	sleeve_ingredients.place(IngredientModel.EGG, Vector2(10, 32), 0.0, sleeve_model)
	sleeve_ingredients.place(IngredientModel.BAOCUI, Vector2(12, 30), 0.0, sleeve_model)
	sleeve_ingredients.place(IngredientModel.SCALLION, Vector2(34, 35), 0.0, sleeve_model)
	var sleeve_fold := PancakeFoldModel.new(sleeve_model, sleeve_ingredients)
	_fold_both(sleeve_fold)
	_check(bool(sleeve_fold.package_with(PancakeFoldModel.PACKAGE_SLEEVE).success), "a minor fold issue can select the paper-sleeve repair")
	var sleeve_result := PancakeScorer.evaluate_order(sleeve_model, sleeve_ingredients, sleeve_fold, order, 48.0, 0.6)
	_check(float(sleeve_result.score_caps.fold) == 90.0 and float(sleeve_result.dimensions.fold) <= 90.0 and sleeve_result.tags.has("纸套加固"), "paper-sleeve repair saves its label and 90-point structure cap")

	var tray_model := _uniform_pancake(64, 0.42)
	_seed_even_egg(tray_model)
	tray_model.doneness.fill(0.64)
	tray_model.back_doneness.fill(0.64)
	tray_model.sauce_concentration.fill(0.35)
	tray_model.damage[32 * tray_model.grid_size + 8] = 1.0
	var tray_ingredients := IngredientModel.new()
	var tray_fold := PancakeFoldModel.new(tray_model, tray_ingredients)
	var torn := _fold_left(tray_fold)
	_check(torn.outcome == PancakeFoldModel.OUTCOME_TORN and bool(tray_fold.package_with(PancakeFoldModel.PACKAGE_TRAY).success), "a severe tear can select the tray rescue")
	var tray_result := PancakeScorer.evaluate_order(tray_model, tray_ingredients, tray_fold, order, 48.0, 0.6)
	_check(float(tray_result.score_caps.fold) == 55.0 and float(tray_result.dimensions.fold) <= 55.0 and tray_result.tags.has("托盘挽救"), "tray rescue saves its label and 55-point structure cap")


func _target_doneness(preference: StringName) -> float:
	match preference:
		&"light":
			return 0.48
		&"well_done":
			return 0.76
	return 0.64


func _uniform_pancake(size: int, thickness: float) -> PancakeModel:
	var model := PancakeModel.new(size)
	for y in size:
		for x in size:
			if not model.is_inside_pan(Vector2(x, y), 0.84):
				continue
			var index := y * size + x
			model.coverage[index] = 1.0
			model.thickness[index] = thickness
			model.wetness[index] = 0.25
	return model


func _seed_even_egg(model: PancakeModel) -> void:
	var center := Vector2(model.grid_size - 1, model.grid_size - 1) * 0.5
	var radii := Vector2(float(model.grid_size) * 0.5, float(model.grid_size) * 0.5 * model.parameters.pan_height_ratio)
	for index in model.cell_count:
		if model.coverage[index] <= 0.0:
			continue
		var position := Vector2(index % model.grid_size, index / model.grid_size)
		if ((position - center) / radii).length() > 0.74:
			continue
		model.egg_white[index] = 0.08
		model.egg_yolk[index] = 0.03
		model.egg_doneness[index] = 0.72
	model.egg_state = PancakeModel.EggState.SPREADING
	model.yolk_broken = true


func _seed_poor_egg(model: PancakeModel) -> void:
	var center := Vector2(model.grid_size - 1, model.grid_size - 1) * 0.5
	for index in model.cell_count:
		if model.coverage[index] <= 0.0:
			continue
		var position := Vector2(index % model.grid_size, index / model.grid_size)
		if position.distance_to(center) > float(model.grid_size) * 0.13:
			continue
		model.egg_white[index] = 0.65
		model.egg_yolk[index] = 0.25
		model.egg_doneness[index] = 0.72
	model.egg_state = PancakeModel.EggState.SPREADING
	model.yolk_broken = true


func _classic_ingredients(model: PancakeModel) -> IngredientModel:
	var ingredients := IngredientModel.new()
	ingredients.place(IngredientModel.EGG, Vector2(model.grid_size * 0.50, model.grid_size * 0.50), 0.0, model)
	ingredients.place(IngredientModel.BAOCUI, Vector2(model.grid_size * 0.48, model.grid_size * 0.44), 0.1, model)
	ingredients.place(IngredientModel.SCALLION, Vector2(model.grid_size * 0.55, model.grid_size * 0.56), -0.2, model)
	return ingredients


func _fold_left(fold: PancakeFoldModel) -> Dictionary:
	var size := fold.pancake_model.grid_size
	fold.begin_drag(Vector2(size * 0.12, size * 0.5))
	return fold.release_drag(Vector2(size * 0.54, size * 0.5))


func _fold_both(fold: PancakeFoldModel) -> void:
	var size := fold.pancake_model.grid_size
	fold.begin_drag(Vector2(size * 0.12, size * 0.5))
	fold.release_drag(Vector2(size * 0.54, size * 0.5))
	fold.begin_drag(Vector2(size * 0.88, size * 0.5))
	fold.release_drag(Vector2(size * 0.46, size * 0.5))


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("P1 vertical-slice self-check PASS")
		quit(0)
	else:
		print("P1 vertical-slice self-check FAIL (%d)" % _failures.size())
		quit(1)
