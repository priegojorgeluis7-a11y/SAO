#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/tools/reports"
TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
REPORT_FILE="$REPORT_DIR/production_readiness_${TIMESTAMP}.txt"
STRICT_ANALYZE="${STRICT_ANALYZE:-0}"

mkdir -p "$REPORT_DIR"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

print_header() {
  local title="$1"
  echo "" | tee -a "$REPORT_FILE"
  echo "============================================================" | tee -a "$REPORT_FILE"
  echo "$title" | tee -a "$REPORT_FILE"
  echo "============================================================" | tee -a "$REPORT_FILE"
}

run_check() {
  local name="$1"
  local cmd="$2"
  local on_fail="${3:-fail}"

  echo "" | tee -a "$REPORT_FILE"
  echo "> $name" | tee -a "$REPORT_FILE"
  echo "  cmd: $cmd" | tee -a "$REPORT_FILE"

  if bash -lc "$cmd" >>"$REPORT_FILE" 2>&1; then
    echo "  result: PASS" | tee -a "$REPORT_FILE"
    PASS_COUNT=$((PASS_COUNT + 1))
    return 0
  fi

  if [[ "$on_fail" == "warn" ]]; then
    echo "  result: WARN" | tee -a "$REPORT_FILE"
    WARN_COUNT=$((WARN_COUNT + 1))
    return 0
  fi

  echo "  result: FAIL" | tee -a "$REPORT_FILE"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  return 1
}

echo "SAO Production Readiness Local Check" | tee "$REPORT_FILE"
echo "Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" | tee -a "$REPORT_FILE"
echo "Root: $ROOT_DIR" | tee -a "$REPORT_FILE"
echo "Host OS: $(uname -s) $(uname -m)" | tee -a "$REPORT_FILE"
echo "STRICT_ANALYZE=$STRICT_ANALYZE" | tee -a "$REPORT_FILE"

print_header "1) CI Workflow Integrity"
run_check "Workflow YAML parse: flutter-platform-builds" \
  "cd '$ROOT_DIR' && ruby -e \"require 'yaml'; YAML.load_file('.github/workflows/flutter-platform-builds.yml'); puts 'YAML_OK'\""

print_header "2) Backend (Python 3.11 + pytest)"
run_check "Python 3.11 available" \
  "command -v python3.11 && python3.11 --version"
run_check "Bootstrap pip for Python 3.11" \
  "python3.11 -m ensurepip --upgrade"
run_check "Backend deps install" \
  "cd '$ROOT_DIR/backend' && python3.11 -m pip install -r requirements.txt"
run_check "Backend tests" \
  "cd '$ROOT_DIR/backend' && python3.11 -m pytest tests -q"

print_header "3) Mobile Flutter (iOS + Android)"
run_check "Flutter SDK available" \
  "command -v flutter && flutter --version"
run_check "Mobile pub get" \
  "cd '$ROOT_DIR/frontend_flutter/sao_windows' && flutter pub get"

if [[ "$STRICT_ANALYZE" == "1" ]]; then
  run_check "Mobile analyze (strict)" \
    "cd '$ROOT_DIR/frontend_flutter/sao_windows' && flutter analyze"
else
  run_check "Mobile analyze (non-blocking)" \
    "cd '$ROOT_DIR/frontend_flutter/sao_windows' && flutter analyze" "warn"
fi

run_check "Mobile tests" \
  "cd '$ROOT_DIR/frontend_flutter/sao_windows' && flutter test"
run_check "Build iOS simulator" \
  "cd '$ROOT_DIR/frontend_flutter/sao_windows' && flutter build ios --simulator --no-codesign"
run_check "Build Android debug APK" \
  "cd '$ROOT_DIR/frontend_flutter/sao_windows' && flutter build apk --debug"

print_header "4) Desktop Flutter (macOS)"
run_check "Desktop pub get" \
  "cd '$ROOT_DIR/desktop_flutter/sao_desktop' && flutter pub get"
run_check "Desktop build_runner" \
  "cd '$ROOT_DIR/desktop_flutter/sao_desktop' && dart run build_runner build --delete-conflicting-outputs"
run_check "Desktop tests" \
  "cd '$ROOT_DIR/desktop_flutter/sao_desktop' && flutter test"
run_check "Build desktop macOS" \
  "cd '$ROOT_DIR/desktop_flutter/sao_desktop' && flutter build macos --dart-define=SAO_BACKEND_URL=https://sao-api-fjzra25vya-uc.a.run.app"

print_header "5) Windows Build Note"
if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "Windows local build skipped: flutter build windows only runs on Windows hosts." | tee -a "$REPORT_FILE"
  WARN_COUNT=$((WARN_COUNT + 1))
else
  run_check "Build desktop Windows" \
    "cd '$ROOT_DIR/desktop_flutter/sao_desktop' && flutter build windows"
fi

print_header "Summary"
echo "PASS: $PASS_COUNT" | tee -a "$REPORT_FILE"
echo "WARN: $WARN_COUNT" | tee -a "$REPORT_FILE"
echo "FAIL: $FAIL_COUNT" | tee -a "$REPORT_FILE"
echo "Report: $REPORT_FILE" | tee -a "$REPORT_FILE"

if [[ $FAIL_COUNT -gt 0 ]]; then
  echo "OVERALL: NO-GO (blocking failures detected)" | tee -a "$REPORT_FILE"
  exit 1
fi

if [[ $WARN_COUNT -gt 0 ]]; then
  echo "OVERALL: CONDITIONAL GO (warnings detected)" | tee -a "$REPORT_FILE"
  exit 0
fi

echo "OVERALL: GO" | tee -a "$REPORT_FILE"
exit 0
