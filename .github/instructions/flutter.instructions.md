---
description: "Use when editing Flutter mobile or desktop code, Drift models, Riverpod state, UI screens, routing, sync flows, or generated-code-adjacent files in frontend_flutter/sao_windows/ or desktop_flutter/sao_desktop/. Covers build_runner, design tokens, backend-derived states, and client-specific boundaries."
name: "SAO Flutter Guidelines"
applyTo: "frontend_flutter/sao_windows/**, desktop_flutter/sao_desktop/**"
---
# SAO Flutter Guidelines

- Treat `frontend_flutter/sao_windows/` and `desktop_flutter/sao_desktop/` as separate clients. Do not assume shared widgets, shared routes, or identical local models unless the code already proves it.
- Before editing generated-code-adjacent areas such as Drift tables, DTOs, or serializable models, identify whether `dart run build_runner build --delete-conflicting-outputs` will be required and run it after relevant changes.
- Validate mobile changes with `flutter analyze` and `flutter test` in `frontend_flutter/sao_windows/`.
- Validate desktop changes with `flutter test` in `desktop_flutter/sao_desktop/`; use `flutter run -d macos --dart-define=SAO_BACKEND_URL=<url>` when interactive verification is needed.
- Never point desktop to `localhost` or `127.0.0.1` through `SAO_BACKEND_URL`; use Cloud Run or a LAN IP.
- Follow `docs/STATE_BEST_PRACTICES.md`: trust backend-derived states and avoid recomputing operational, review, or sync status in the client unless implementing an explicit offline fallback.
- Follow `docs/DESIGN_SYSTEM.md` and `docs/DESIGN_TOKENS.md`: use `SaoColors` and semantic tokens, avoid direct color literals, and on desktop prefer theme-aware surface helpers over raw neutral colors.
- Keep domain behavior catalog-driven. If a screen or workflow needs new rules, first verify whether the catalog or backend contract is the right place for the change.
- If a doc conflicts with live code, prefer the current client implementation, CI workflows, and `STATUS.md`.
