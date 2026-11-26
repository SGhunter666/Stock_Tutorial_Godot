## Runtime theme and layout switches.
extends "res://tests/test_base.gd"


func run() -> void:
	describe("theme-light")
	SmaUiTheme.set_theme_mode("light")
	eq(SmaUiTheme.mode, "light", "light mode selected")
	eq(SmaUiTheme.is_pixel(), true, "light mode remains 100% pixel art")
	check(SmaUiTheme.BG.r > 0.8, "light background is bright")
	check(SmaUiTheme.TEXT.r < 0.3, "light text is dark")
	check(SmaUiTheme.ACCENT_DARK.v > 0.0, "accent remains defined")
	check(SmaUiTheme.INFO.b > 0.5 and SmaUiTheme.INFO.r < 0.3,
		"info colour keeps contrast on light panels")

	describe("theme-dark")
	SmaUiTheme.set_theme_mode("dark")
	eq(SmaUiTheme.mode, "dark", "dark mode restored")
	eq(SmaUiTheme.is_pixel(), true, "dark mode remains 100% pixel art")
	check(SmaUiTheme.BG.r < 0.2, "dark background is dark")
	check(SmaUiTheme.TEXT.r > 0.8, "dark text is bright")

	describe("theme-invalid")
	SmaUiTheme.set_theme_mode("unknown")
	eq(SmaUiTheme.mode, "dark", "unknown theme falls back to dark")

	describe("layout-density")
	SmaUiTheme.set_density(0.88)
	approx(SmaUiTheme.density, 0.88, 0.001, "advanced density applied")
	SmaUiTheme.set_density(9.0)
	approx(SmaUiTheme.density, 1.0, 0.001, "density is clamped")

	describe("color-scheme")
	SmaUiTheme.set_theme_mode("dark")
	SmaUiTheme.set_color_scheme("intl")
	eq(SmaUiTheme.color_scheme, "intl", "intl scheme applied")
	check(SmaUiTheme.POSITIVE.g > SmaUiTheme.POSITIVE.r, "intl positive is green")
	check(SmaUiTheme.NEGATIVE.r > SmaUiTheme.NEGATIVE.g, "intl negative is red")
	SmaUiTheme.set_color_scheme("cn")
	eq(SmaUiTheme.color_scheme, "cn", "cn scheme applied")
	check(SmaUiTheme.POSITIVE.r > SmaUiTheme.POSITIVE.g, "cn positive is red")
	check(SmaUiTheme.NEGATIVE.g > SmaUiTheme.NEGATIVE.r, "cn negative is green")
	SmaUiTheme.set_theme_mode("light")
	check(SmaUiTheme.POSITIVE.r > SmaUiTheme.POSITIVE.g, "cn positive persists in light theme")
	SmaUiTheme.set_color_scheme("colorblind")
	eq(SmaUiTheme.color_scheme, "colorblind", "colorblind scheme applied")
	check(SmaUiTheme.POSITIVE.b > SmaUiTheme.POSITIVE.r, "colorblind positive is blue")
	check(SmaUiTheme.NEGATIVE.r > SmaUiTheme.NEGATIVE.b, "colorblind negative is orange")
	SmaUiTheme.set_color_scheme("invalid-scheme")
	eq(SmaUiTheme.color_scheme, "intl", "invalid color scheme falls back to intl")
	SmaUiTheme.set_theme_mode("pixel")
	eq(SmaUiTheme.mode, "pixel", "pixel theme selected")
	eq(SmaUiTheme.is_pixel(), true, "is_pixel flag active")
	eq(SmaUiTheme.card_radius(), 0, "pixel theme uses sharp zero-radius corners")
	var btn_box := SmaUiTheme.beveled_button_box(SmaUiTheme.PANEL_ALT, SmaUiTheme.BORDER, 8, false)
	eq(btn_box.corner_radius_top_left, 0, "beveled pixel button has sharp corners")
	check(btn_box.border_width_bottom > btn_box.border_width_top, "beveled button has thicker bottom shadow")
	var nine_card := SmaUiTheme.panel_style(SmaUiTheme.PANEL, SmaUiTheme.BORDER, 10, true)
	check(nine_card is StyleBoxTexture, "pixel theme cards use 9-slice StyleBoxTexture")
	var snap12 := SmaUiTheme.pixel_snap_font(13)
	eq(int(snap12["size"]), 12, "13px snaps to exact 12px bitmap grid")
	var snap20 := SmaUiTheme.pixel_snap_font(16)
	eq(int(snap20["size"]), 20, "16px snaps to exact 2x 20px 10x10 bitmap grid")
	var snap24 := SmaUiTheme.pixel_snap_font(18)
	eq(int(snap24["size"]), 24, "18px snaps to exact 2x 24px 12x12 bitmap grid")
	var snap30 := SmaUiTheme.pixel_snap_font(30)
	eq(int(snap30["size"]), 30, "30px snaps to exact 3x 30px 10x10 bitmap grid")
	check(SmaPixelArt.icon("logo") != null, "pixel logo icon generated")
	for nav_icon in ["screener", "etf", "options", "futures", "multiasset", "news",
			"earnings", "macro", "statements", "history", "replay", "tax",
			"sandbox", "glossary", "boundaries", "roadmap", "opt_arrow", "spin_updown"]:
		check(SmaPixelArt.icon(nav_icon) != null, "pixel icon generated: %s" % nav_icon)
	check(SmaPixelArt.ticker_badge("MSFY", "technology", false) != null, "pixel ticker badge generated")

	describe("pixel-beta10-enhancements")
	var audio_script: GDScript = load("res://app/audio.gd")
	eq(String(audio_script.resolve_mood(false, true, false, false, "trade")), "ambient",
		"non-pixel theme resolves ambient BGM")
	eq(String(audio_script.resolve_mood(true, false, true, false, "market")), "pixel_calm",
		"pixel start/paused resolves calm FM lounge BGM")
	eq(String(audio_script.resolve_mood(true, true, false, false, "trade")), "pixel_session",
		"active pixel trading resolves upbeat session BGM")
	eq(String(audio_script.resolve_mood(true, true, false, false, "academy")), "pixel_calm",
		"pixel academy resolves calm study BGM")
	eq(String(audio_script.resolve_mood(true, true, false, true, "trade")), "pixel_crisis",
		"crisis overrides pixel BGM to urgent ostinato")

	describe("pixel-beta12-office-daily-portrait-poster")
	for prop_icon in ["prop_espresso", "prop_cat", "prop_bloomberg", "prop_clocks", "prop_server", "prop_bull"]:
		check(SmaPixelArt.icon(prop_icon) != null, "pixel prop icon generated: %s" % prop_icon)

	var off_state := SmaOffice.create_state()
	var mock_acad := {"xp": 40, "achievements": ["first_trade"]}
	var mock_career := {"rank": 1, "certificates": []}
	var start_rp := SmaOffice.available_rp(off_state, mock_acad, mock_career, 2)
	eq(start_rp, 160 + 40 + 30 + 80, "deterministic RP formula sums starter + xp + trades + achievements")
	var rank_fail := SmaOffice.purchase(off_state, "bull_statue", mock_acad, mock_career, 2)
	eq(bool(rank_fail["ok"]), false, "rank-3 bull statue blocked at rank 1")
	eq(String(rank_fail["error"]), "office.errorRank", "rank gate returns office.errorRank")
	var buy_esp := SmaOffice.purchase(off_state, "espresso_bar", mock_acad, mock_career, 2)
	eq(bool(buy_esp["ok"]), true, "espresso_bar purchased cleanly")
	eq(SmaOffice.is_owned(off_state, "espresso_bar"), true, "espresso_bar marked owned")
	eq(SmaOffice.is_displayed(off_state, "espresso_bar"), true, "espresso_bar displayed by default")
	eq(SmaOffice.toggle_visibility(off_state, "espresso_bar"), false, "toggle hides espresso_bar")
	eq(SmaOffice.is_displayed(off_state, "espresso_bar"), false, "espresso_bar hidden after toggle")
	eq(SmaOffice.toggle_visibility(off_state, "espresso_bar"), true, "second toggle shows espresso_bar")
	var norm_off := SmaOffice.normalize_state({"owned": ["espresso_bar", "bogus_id", "espresso_bar"], "hidden": []})
	eq((norm_off["owned"] as Array).size(), 1, "normalize_state deduplicates and strips unknown items")

	eq(SmaDailyChallenge.sanitize_code(" 2026-11-26!! "), "2026-11-26", "daily code sanitizer strips punctuation")
	eq(SmaDailyChallenge.seed_for_code("2026-11-26"), "daily-2026-11-26", "daily seed deterministic prefix")
	var ev_zero := SmaDailyChallenge.evaluate(100000.0, 100000.0, [], 0, 10)
	check(int(ev_zero["score"]) <= 950, "zero-trade passive run capped at <= 950")
	var ev_s := SmaDailyChallenge.evaluate(100000.0, 108000.0, [{"equity": 100000.0}, {"equity": 104000.0}], 6, 10)
	eq(String(ev_s["grade"]), "S", "+8% zero-drawdown sprint earns Grade S")
	eq(bool(ev_s["completed"]), true, "10-day sprint marked completed")
	var recs: Array = []
	recs = SmaDailyChallenge.record_result(recs, {"code": "2026-11-26", "score": 1100, "grade": "B"})
	recs = SmaDailyChallenge.record_result(recs, {"code": "2026-11-26", "score": 980, "grade": "C"})
	eq(int(recs[0]["score"]), 1100, "lower retry score does not overwrite personal best")
	recs = SmaDailyChallenge.record_result(recs, {"code": "2026-11-26", "score": 1520, "grade": "S"})
	eq(int(recs[0]["score"]), 1520, "higher retry score updates personal best")

	eq(SmaPortraitAnimator.RIGS.size(), 7, "all 7 character portraits rigged for pixel blink & lip-sync")
	eq(SmaPortraitAnimator.resolve_mood("black_friday", "Calm text"), "crisis", "crisis story resolves crisis mood")
	eq(SmaPortraitAnimator.resolve_mood("opening", "恭喜你稳健通关"), "praise", "praise text resolves praise mood")
	eq(SmaPortraitAnimator.resolve_mood("opening", "你的止损计划是什么？"), "focus", "question resolves focus mood")
