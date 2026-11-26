## Browser-native file download, file upload, and IndexedDB sync bridge for Web
## HTML5 exports. Safe no-op / false fallback on desktop & headless platforms.
class_name SmaWebIo
extends RefCounted

static var _upload_cb: Variant = null
static var _pending_handler: Callable = Callable()


static func is_web() -> bool:
	return OS.has_feature("web")


static func flush_idb() -> void:
	if not is_web():
		return
	JavaScriptBridge.eval(
		"if (typeof FS !== 'undefined' && FS.syncfs) { FS.syncfs(false, function(_err){}); }",
		true
	)


static func download_bytes(bytes: PackedByteArray, filename: String, mime: String) -> bool:
	if not is_web() or bytes.is_empty():
		return false
	JavaScriptBridge.download_buffer(bytes, filename, mime)
	return true


static func download_json(payload: Dictionary, filename: String) -> bool:
	if not is_web() or payload.is_empty():
		return false
	var encoded := JSON.stringify(payload, "  ").to_utf8_buffer()
	return download_bytes(encoded, filename, "application/json")


static func prompt_json_upload(handler: Callable) -> bool:
	if not is_web() or not handler.is_valid():
		return false
	_pending_handler = handler
	if _upload_cb == null:
		_upload_cb = JavaScriptBridge.create_callback(_on_js_file_loaded)
	var win := JavaScriptBridge.get_interface("window")
	if win == null:
		return false
	win._smaOnJsonUpload = _upload_cb
	JavaScriptBridge.eval("""
		(function() {
			var inp = document.createElement('input');
			inp.type = 'file';
			inp.accept = '.json,application/json';
			inp.style.display = 'none';
			inp.onchange = function(ev) {
				var file = ev.target.files && ev.target.files[0];
				if (!file) { inp.remove(); return; }
				var reader = new FileReader();
				reader.onload = function() {
					if (window._smaOnJsonUpload) {
						window._smaOnJsonUpload(String(reader.result || ''));
					}
					inp.remove();
				};
				reader.readAsText(file);
			};
			document.body.appendChild(inp);
			inp.click();
		})();
	""", true)
	return true


static func _on_js_file_loaded(args: Array) -> void:
	if args.is_empty() or not _pending_handler.is_valid():
		return
	var text := String(args[0])
	var cb := _pending_handler
	_pending_handler = Callable()
	cb.call(text)
