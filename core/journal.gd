## Pure logic for Personal Trading Journal & Setup-Tag PnL Attribution.
## Lets players tag executed trades by setup hypothesis (Breakout, Dip Buy,
## Earnings Play, Trend Ride, Hedge/Stop, FOMO Tilt) plus a 1-line note, then
## aggregates which setups make money and which leak capital.
## Zero UI dependencies.
class_name SmaJournal
extends RefCounted

const TAGS := [
	{"id": "breakout", "labelKey": "journal.tag.breakout", "tone": "accent"},
	{"id": "dip_buy", "labelKey": "journal.tag.dip_buy", "tone": "positive"},
	{"id": "earnings", "labelKey": "journal.tag.earnings", "tone": "gold"},
	{"id": "trend", "labelKey": "journal.tag.trend", "tone": "positive"},
	{"id": "hedge", "labelKey": "journal.tag.hedge", "tone": "muted"},
	{"id": "fomo", "labelKey": "journal.tag.fomo", "tone": "negative"},
]


static func tag_ids() -> Array[String]:
	var out: Array[String] = []
	for t in TAGS:
		out.append(String(t["id"]))
	return out


static func fill_key(fill: Dictionary, fallback_index: int = 0) -> String:
	var oid := String(fill.get("orderId", ""))
	var tk := String(fill.get("ticker", ""))
	var day := int(fill.get("day", 0))
	var sec := int(fill.get("second", fallback_index))
	return "%d:%s:%s:%d" % [day, oid, tk, sec]


static func normalize_store(saved: Variant) -> Dictionary:
	var out := {}
	if typeof(saved) != TYPE_DICTIONARY:
		return out
	var valid := tag_ids()
	for k in saved.keys():
		var entry: Variant = saved[k]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var tag := String(entry.get("tag", ""))
		if tag != "" and not valid.has(tag):
			tag = ""
		var note := String(entry.get("note", "")).strip_edges().substr(0, 120)
		if tag != "" or note != "":
			out[String(k)] = {"tag": tag, "note": note}
	return out


static func set_entry(store: Dictionary, key: String, tag: String, note: String) -> Dictionary:
	var norm := normalize_store(store)
	var clean_tag := tag if tag_ids().has(tag) else ""
	var clean_note := note.strip_edges().substr(0, 120)
	if clean_tag == "" and clean_note == "":
		norm.erase(key)
	else:
		norm[key] = {"tag": clean_tag, "note": clean_note}
	return norm


## Aggregates tagged fills by setup tag. Uses realized PnL directly on closing
## fills; for entry fills that don't yet have realizedPnl, pairs by ticker if a
## later closing fill exists, or counts as open tagged setups.
static func summarize_by_tag(fills: Array, store: Dictionary) -> Dictionary:
	var norm := normalize_store(store)
	var buckets := {}
	for t in TAGS:
		var tid := String(t["id"])
		buckets[tid] = {
			"id": tid,
			"labelKey": String(t["labelKey"]),
			"tone": String(t["tone"]),
			"count": 0,
			"closedCount": 0,
			"wins": 0,
			"realizedPnl": 0.0,
		}
	var tagged_total := 0
	var last_entry_tag_by_ticker := {}

	for idx in fills.size():
		var fill: Dictionary = fills[idx]
		var fk := fill_key(fill, idx)
		var entry: Dictionary = norm.get(fk, {})
		var tag := String(entry.get("tag", ""))
		var tk := String(fill.get("ticker", ""))
		var action := String(fill.get("action", fill.get("side", "")))
		var is_close := action in ["sell", "cover", "closeLong", "closeShort"]
		var pnl := float(fill.get("realized", fill.get("realizedPnl", 0.0)))

		if tag != "":
			tagged_total += 1
			if not is_close:
				last_entry_tag_by_ticker[tk] = tag
		elif is_close and last_entry_tag_by_ticker.has(tk):
			# Inherit entry setup tag when closing a tagged trade so P&L attributes accurately.
			tag = String(last_entry_tag_by_ticker[tk])

		if tag != "" and buckets.has(tag):
			var b: Dictionary = buckets[tag]
			b["count"] = int(b["count"]) + 1
			if is_close or not is_zero_approx(pnl):
				b["closedCount"] = int(b["closedCount"]) + 1
				b["realizedPnl"] = SmaFormat.round_to(float(b["realizedPnl"]) + pnl, 2)
				if pnl > 0.0:
					b["wins"] = int(b["wins"]) + 1
			buckets[tag] = b

	var rows: Array = []
	var best_tag := {}
	var worst_tag := {}
	for t in TAGS:
		var b: Dictionary = buckets[String(t["id"])]
		var closed := int(b["closedCount"])
		b["winRatePct"] = SmaFormat.round_to(float(b["wins"]) / float(closed) * 100.0, 1) if closed > 0 else 0.0
		if int(b["count"]) > 0:
			rows.append(b)
			if closed > 0:
				if best_tag.is_empty() or float(b["realizedPnl"]) > float(best_tag["realizedPnl"]):
					best_tag = b
				if worst_tag.is_empty() or float(b["realizedPnl"]) < float(worst_tag["realizedPnl"]):
					worst_tag = b
	rows.sort_custom(func(a, b): return float(a["realizedPnl"]) > float(b["realizedPnl"]))
	return {
		"taggedCount": tagged_total,
		"rows": rows,
		"bestTag": best_tag if (not best_tag.is_empty() and float(best_tag.get("realizedPnl", 0.0)) > 0.0) else {},
		"worstTag": worst_tag if (not worst_tag.is_empty() and float(worst_tag.get("realizedPnl", 0.0)) < 0.0) else {},
	}
