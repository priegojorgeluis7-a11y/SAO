---
description: "Run local SAO validation on macOS for backend, mobile, desktop, or all three using the repo's recommended sequence and commands."
name: "Run Local Validation"
argument-hint: "Scope to validate: backend | mobile | desktop | all"
agent: "agent"
---
Run local validation for SAO on macOS.

Interpret the user argument as one of: `backend`, `mobile`, `desktop`, or `all`. If no scope is provided, default to `all`.

Use [docs/VALIDACION_LOCAL_MAC.md](../../docs/VALIDACION_LOCAL_MAC.md), [docs/README.md](../../docs/README.md), and the current CI workflows as the command source of truth.

Requirements:
- Confirm the selected scope before executing commands.
- Run only the checks relevant to the selected scope.
- For `backend`: use `backend/`, install with `requirements.txt` if needed, and run `pytest tests -q`.
- For `mobile`: use `frontend_flutter/sao_windows/`, run `flutter pub get`, `flutter analyze`, and `flutter test`. Run `build_runner` only if the touched files require regenerated code.
- For `desktop`: use `desktop_flutter/sao_desktop/`, run `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, and `flutter test`. Mention that runtime verification requires `SAO_BACKEND_URL` with Cloud Run or a LAN IP.
- For `all`: execute backend, mobile, and desktop validation in that order.
- If a required tool is missing, stop that scope, explain the blocker briefly, and continue with the remaining scopes when possible.
- Summarize results by scope, include failing commands, and call out environment-specific blockers separately from code failures.

Do not modify source files unless the user explicitly asks for fixes after validation.