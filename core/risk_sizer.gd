## Pure logic for Position Risk Sizing ("Fixed Fractional Risk / R:R Calculator").
## Computes exact share quantity from account equity, risk % tolerance, entry,
## stop-loss, and take-profit prices for both Long and Short setups.
## Zero UI dependencies.
class_name SmaRiskSizer
extends RefCounted

const RISK_PRESETS := [0.5, 1.0, 2.0, 3.0]


static func calculate(entry_price: float, stop_price: float, target_price: float,
		equity: float, risk_pct: float, side: String = "buy",
		buying_power: float = -1.0) -> Dictionary:
	var is_short := side in ["short", "sell"]
	var ep := maxf(0.01, entry_price)
	var sp := maxf(0.01, stop_price)
	var tp := maxf(0.01, target_price)
	var eq := maxf(0.0, equity)
	var r_pct := clampf(risk_pct, 0.1, 20.0)
	var risk_budget := SmaFormat.round_to(eq * (r_pct / 100.0), 2)

	var per_share_risk := (sp - ep) if is_short else (ep - sp)
	var reward_per_share := (ep - tp) if is_short else (tp - ep)
	var valid_stop := per_share_risk > 0.005
	var valid_target := reward_per_share > 0.005

	var stop_pct := (per_share_risk / ep * 100.0) if valid_stop else 0.0
	var target_pct := (reward_per_share / ep * 100.0) if valid_target else 0.0
	var rr_ratio := (reward_per_share / per_share_risk) if (valid_stop and valid_target) else 0.0

	var qty := 0
	var capped_by_bp := false
	if valid_stop and risk_budget > 0.0:
		qty = int(floor(risk_budget / per_share_risk))
		if buying_power >= 0.0:
			var max_bp_qty := int(floor(buying_power / (ep * 1.003)))
			if qty > max_bp_qty:
				qty = maxi(0, max_bp_qty)
				capped_by_bp = true
		qty = maxi(0, qty)

	var notional := SmaFormat.round_to(float(qty) * ep, 2)
	var weight_pct := SmaFormat.round_to(notional / eq * 100.0, 1) if eq > 0.0 else 0.0
	var expected_loss := SmaFormat.round_to(float(qty) * maxf(0.0, per_share_risk), 2)
	var expected_profit := SmaFormat.round_to(float(qty) * maxf(0.0, reward_per_share), 2)

	return {
		"ok": valid_stop and qty > 0,
		"side": "short" if is_short else "buy",
		"entry": SmaFormat.round_to(ep, 2),
		"stop": SmaFormat.round_to(sp, 2),
		"target": SmaFormat.round_to(tp, 2),
		"riskPct": SmaFormat.round_to(r_pct, 2),
		"riskBudget": risk_budget,
		"perShareRisk": SmaFormat.round_to(maxf(0.0, per_share_risk), 2),
		"rewardPerShare": SmaFormat.round_to(maxf(0.0, reward_per_share), 2),
		"stopPct": SmaFormat.round_to(stop_pct, 2),
		"targetPct": SmaFormat.round_to(target_pct, 2),
		"rrRatio": SmaFormat.round_to(rr_ratio, 2),
		"qty": qty,
		"notional": notional,
		"weightPct": weight_pct,
		"expectedLoss": expected_loss,
		"expectedProfit": expected_profit,
		"validStop": valid_stop,
		"validTarget": valid_target,
		"cappedByBuyingPower": capped_by_bp,
	}


static func default_levels(entry_price: float, side: String = "buy") -> Dictionary:
	var ep := maxf(0.05, entry_price)
	var is_short := side in ["short", "sell"]
	if is_short:
		return {
			"stop": SmaFormat.round_to(ep * 1.05, 2),
			"target": SmaFormat.round_to(maxf(0.01, ep * 0.88), 2),
		}
	return {
		"stop": SmaFormat.round_to(maxf(0.01, ep * 0.95), 2),
		"target": SmaFormat.round_to(ep * 1.12, 2),
	}
