## Deterministic technical indicators based on closes up to the current session.
## No function looks ahead, so the trading desk and lessons cannot leak future
## data.
class_name SmaIndicators
extends RefCounted


static func sma(values: Array, period: int) -> float:
	if period <= 0 or values.size() < period:
		return NAN
	var total := 0.0
	for index in range(values.size() - period, values.size()):
		total += float(values[index])
	return total / float(period)


static func rsi(values: Array, period: int = 14) -> float:
	if values.size() <= period:
		return NAN
	var gains := 0.0
	var losses := 0.0
	for index in range(values.size() - period, values.size()):
		var change := float(values[index]) - float(values[index - 1])
		if change >= 0.0:
			gains += change
		else:
			losses += absf(change)
	if gains + losses == 0.0:
		return 50.0
	if losses == 0.0:
		return 100.0
	return 100.0 - 100.0 / (1.0 + gains / losses)


static func annualized_volatility(values: Array, periods_per_year: int = 252) -> float:
	if values.size() < 3:
		return NAN
	var returns: Array = []
	for index in range(1, values.size()):
		var previous := float(values[index - 1])
		if previous != 0.0:
			returns.append((float(values[index]) - previous) / previous)
	if returns.size() < 2:
		return NAN
	var mean := 0.0
	for value in returns:
		mean += float(value)
	mean /= float(returns.size())
	var variance := 0.0
	for value in returns:
		variance += pow(float(value) - mean, 2.0)
	variance /= float(returns.size())
	return sqrt(variance) * sqrt(float(periods_per_year)) * 100.0


static func max_drawdown(values: Array) -> float:
	if values.size() < 2:
		return NAN
	var peak := float(values[0])
	var worst := 0.0
	for value in values:
		peak = maxf(peak, float(value))
		if peak > 0.0:
			worst = minf(worst, (float(value) - peak) / peak)
	return worst * 100.0


static func snapshot(candles: Array, current_price: float = 0.0) -> Dictionary:
	var closes: Array = []
	for candle in candles:
		closes.append(float(candle.get("c", 0.0)))
	if current_price > 0.0:
		closes.append(current_price)
	if closes.size() < 2:
		return {}
	var sma20 := sma(closes, 20)
	var sma50 := sma(closes, 50)
	var trend := "unknown"
	if not is_nan(sma20) and not is_nan(sma50):
		trend = "up" if sma20 > sma50 else ("down" if sma20 < sma50 else "flat")
	return {
		"sma20": sma20,
		"sma50": sma50,
		"rsi14": rsi(closes, 14),
		"volatility": annualized_volatility(closes.slice(maxi(0, closes.size() - 61))),
		"drawdown": max_drawdown(closes.slice(maxi(0, closes.size() - 90))),
		"trend": trend,
		"last": closes[-1],
	}


static func ema_series(values: Array, period: int) -> Array:
	var n := values.size()
	var out: Array = []
	out.resize(n)
	if period <= 0 or n == 0:
		for i in n:
			out[i] = NAN
		return out
	var k := 2.0 / float(period + 1)
	var ema_val := float(values[0])
	out[0] = ema_val
	for i in range(1, n):
		var v := float(values[i])
		if is_nan(v):
			out[i] = NAN
			continue
		if is_nan(ema_val):
			ema_val = v
		else:
			ema_val = v * k + ema_val * (1.0 - k)
		out[i] = ema_val
	return out


static func macd_series(closes: Array, fast: int = 12, slow: int = 26,
		signal_period: int = 9) -> Dictionary:
	var n := closes.size()
	var dif: Array = []
	var dea: Array = []
	var hist: Array = []
	dif.resize(n)
	dea.resize(n)
	hist.resize(n)
	if n == 0:
		return {"dif": dif, "dea": dea, "hist": hist}
	var ema_fast := ema_series(closes, fast)
	var ema_slow := ema_series(closes, slow)
	for i in n:
		if i < slow - 1:
			dif[i] = NAN
		else:
			dif[i] = float(ema_fast[i]) - float(ema_slow[i])
	var k_sig := 2.0 / float(signal_period + 1)
	var dea_val := NAN
	var valid_count := 0
	var seed_sum := 0.0
	for i in n:
		var d := float(dif[i])
		if is_nan(d):
			dea[i] = NAN
			hist[i] = NAN
			continue
		valid_count += 1
		if valid_count < signal_period:
			seed_sum += d
			dea[i] = NAN
			hist[i] = NAN
		elif valid_count == signal_period:
			seed_sum += d
			dea_val = seed_sum / float(signal_period)
			dea[i] = dea_val
			hist[i] = (d - dea_val) * 2.0
		else:
			dea_val = d * k_sig + dea_val * (1.0 - k_sig)
			dea[i] = dea_val
			hist[i] = (d - dea_val) * 2.0
	return {"dif": dif, "dea": dea, "hist": hist}


static func rsi_series(closes: Array, period: int = 14) -> Array:
	var n := closes.size()
	var out: Array = []
	out.resize(n)
	for i in n:
		out[i] = NAN
	if period <= 0 or n <= period:
		return out
	var avg_gain := 0.0
	var avg_loss := 0.0
	for i in range(1, period + 1):
		var delta := float(closes[i]) - float(closes[i - 1])
		if delta >= 0.0:
			avg_gain += delta
		else:
			avg_loss += -delta
	avg_gain /= float(period)
	avg_loss /= float(period)
	out[period] = 100.0 if avg_loss <= 1e-9 else (100.0 - 100.0 / (1.0 + avg_gain / avg_loss))
	for i in range(period + 1, n):
		var delta := float(closes[i]) - float(closes[i - 1])
		var g := maxf(0.0, delta)
		var l := maxf(0.0, -delta)
		avg_gain = (avg_gain * float(period - 1) + g) / float(period)
		avg_loss = (avg_loss * float(period - 1) + l) / float(period)
		if avg_gain + avg_loss <= 1e-9:
			out[i] = 50.0
		elif avg_loss <= 1e-9:
			out[i] = 100.0
		else:
			out[i] = 100.0 - 100.0 / (1.0 + avg_gain / avg_loss)
	return out
