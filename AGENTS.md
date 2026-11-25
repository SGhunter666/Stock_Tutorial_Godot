# Project Agent Guidelines

## Testing & Quality Gates
- Always run both headless test suites before finishing any code or data change:
  - Unit tests: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_tests.gd`
  - Integration test: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/integration.tscn`
- Maintain 100% key parity between `locales/zh_CN.json` and `locales/en.json`.
- Keep `core/` free of UI dependencies and preserve save backward compatibility.

## Git Workflow (User Authorized)
- Once development is complete and all automated tests pass, automatically run `git add`, create a clear `git commit`, and `git push` directly to the remote (`origin/main`) without waiting to ask first.
