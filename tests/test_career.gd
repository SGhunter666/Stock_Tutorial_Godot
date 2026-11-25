## Career ranks, tasks, reports, evaluations, certificates and salary.
extends "res://tests/test_base.gd"


func _academy(completed: Array) -> Dictionary:
	var state := SmaAcademy.create_state()
	for unit_id in completed:
		SmaAcademy.ensure_unit(state, String(unit_id))["completed"] = true
	return state


func _make_context(academy: Dictionary, equity_value: float = 120000.0,
		day: int = 0) -> Dictionary:
	return {
		"academy": academy, "day": day, "equity": equity_value,
		"initialCash": 100000.0, "careerIncome": 0.0,
		"trades": 12, "optionTrades": 1, "futuresTrades": 1,
		"equityHistory": [{"day": 0, "equity": 100000.0},
			{"day": 21, "equity": equity_value}],
		"challengesCompleted": [], "tickers": ["APLA", "MSFY", "NVDO"],
	}


func run() -> void:
	describe("career-init")
	var career := SmaCareer.create_state(0)
	eq(int(career["rank"]), 1, "career starts at retail")
	var academy := _academy([])
	var data := SmaCareer.progress(career, _make_context(academy))
	eq(data["requirements"].size(), 3, "rank one has three requirements")
	eq(bool(data["ready"]), false, "rank one is not ready immediately")

	describe("career-promotion")
	academy = _academy(["u4"])
	academy["inspectedTickers"] = ["APLA", "MSFY", "NVDO"]
	data = SmaCareer.progress(career, _make_context(academy))
	eq(bool(data["ready"]), true, "requirements satisfied")
	var promoted := SmaCareer.promote(career, _make_context(academy), 0)
	eq(bool(promoted.get("ok", false)), true, "promotion succeeds")
	eq(int(career["rank"]), 2, "rank advances to trader")
	check(int(academy["xp"]) >= 100, "promotion awards XP")
	var tasks := SmaCareer.refresh_tasks(career, 1, ["APLA", "MSFY", "NVDO"])
	var available := 0
	for task in tasks["tasks"]:
		if String(task["status"]) == "available":
			available += 1
	eq(available, 2, "two research tasks are offered")

	describe("career-task")
	var first_task_id := ""
	for task in career["tasks"]:
		if String(task["status"]) == "available":
			first_task_id = String(task["id"])
			break
	var accepted := SmaCareer.accept_task(career, first_task_id, 2)
	eq(bool(accepted.get("ok", false)), true, "task can be accepted")
	eq(String(accepted["task"]["status"]), "active", "task becomes active")

	describe("career-report")
	var summary := "APLA trades at a premium to its sector average. Revenue growth is 12 percent, "
	summary += "margins expanded by 180 basis points and free cash flow covers the dividend twice. "
	summary += "The 20-day trend is positive and the balance sheet carries 2.1 billion of net cash. "
	summary += "I expect the multiple to re-rate towards peers over the next two quarters."
	var graded := SmaCareer.grade_report({
		"summary": summary, "targetPrice": 105.0, "thesis": "bull",
		"conviction": 4, "last": 100.0, "trend": "up", "inspected": true,
		"financialsDone": true,
	}, {})
	eq(int(graded["score"]), 100, "complete report scores full marks")
	eq(String(graded["grade"]), "A", "full marks grade A")
	var submitted := SmaCareer.submit_report(career, {
		"taskId": first_task_id, "thesis": "bull", "conviction": 4,
		"targetPrice": 105.0, "summary": summary,
	}, {
		"academy": academy, "last": 100.0, "trend": "up", "inspected": true,
		"financialsDone": true,
	}, 3)
	eq(bool(submitted.get("ok", false)), true, "report accepted")
	eq(career["reports"].size(), 1, "report recorded")
	eq(String(career["tasks"][0]["status"]), "completed", "task completed by report")
	check(float(submitted["cash"]) > 0.0, "passing report pays a cash reward")

	describe("career-evaluation")
	var evaluation := SmaCareer.evaluate(career, _make_context(academy, 130000.0, 21), 21)
	eq(bool(evaluation.get("due", false)), true, "review is due after 21 days")
	eq(career["evaluations"].size(), 1, "evaluation recorded")
	check(int(evaluation["xp"]) > 0, "evaluation awards XP")

	describe("career-salary")
	var account := {"cash": 1000.0, "careerIncome": 0.0}
	var salary := SmaCareer.apply_salary(account, career, 63)
	eq(bool(salary.get("paid", false)), true, "salary due after the interval")
	approx(float(account["cash"]), 1500.0, 0.01, "recalibrated salary credited")
	eq(int(career["salaryPaidDay"]), 21, "salary day advances")

	describe("career-equity-recalibration")
	var rank2 := SmaCareer.create_state(0)
	rank2["rank"] = 2
	var flat_progress := SmaCareer.progress(rank2, _make_context(_academy(["u8"]), 100000.0))
	eq(bool(flat_progress["ready"]), false, "starting 100k equity does not satisfy rank 2 equity target")
	var pass_progress := SmaCareer.progress(rank2, _make_context(_academy(["u8"]), 103000.0))
	eq(bool(pass_progress["ready"]), true, "103k equity satisfies rank 2 equity target")
	var rank6 := SmaCareer.create_state(0)
	rank6["rank"] = 6
	var r6_low := SmaCareer.progress(rank6, _make_context(_academy(["u32"]), 110000.0))
	var r6_eq_done := false
	for req in r6_low["requirements"]:
		if String(req.get("kind", "")) == "equity":
			r6_eq_done = bool(req.get("done", false))
	eq(r6_eq_done, false, "110k equity does not satisfy rank 6 125k equity target")
	var r6_high := SmaCareer.progress(rank6, _make_context(_academy(["u32"]), 125000.0))
	for req in r6_high["requirements"]:
		if String(req.get("kind", "")) == "equity":
			r6_eq_done = bool(req.get("done", false))
	eq(r6_eq_done, true, "125k equity satisfies rank 6 equity target")

	describe("career-certificates")
	var cert_academy := _academy(["u1", "u2", "u3", "u4"])
	var cert_career := SmaCareer.create_state(0)
	var certificates := SmaCareer.certificate_progress(cert_career, {
		"academy": cert_academy,
	})
	eq(certificates.size(), 5, "five certificates exposed")
	var foundation: Dictionary = certificates[0]
	eq(bool(foundation["done"]), true, "foundation certificate complete")
	var synced := SmaCareer.sync_certificates(cert_career, {"academy": cert_academy}, 5)
	eq(synced["newlyEarned"].size(), 1, "new certificate recorded once")
