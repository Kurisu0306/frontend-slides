#!/usr/bin/env bash
# Regression for #106: a relative output path must be absolute before
# export-pdf.sh cd's into the temp directory it later deletes.
# EXPORT_PDF_RESOLVE_ONLY stops the real script after that resolution.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT/scripts/export-pdf.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
mkdir -p "$WORKDIR/deck" "$WORKDIR/start"
printf '<html><body>slide</body></html>\n' > "$WORKDIR/deck/index.html"

cd "$WORKDIR/start"
RESOLVED=$(EXPORT_PDF_RESOLVE_ONLY=1 bash "$SCRIPT" "$WORKDIR/deck/index.html" ./out.pdf)
case "$RESOLVED" in
    /*) ;;
    *) fail "resolved path is not absolute: $RESOLVED" ;;
esac
[[ "$RESOLVED" == "$WORKDIR/start/out.pdf" ]] || fail "expected $WORKDIR/start/out.pdf, got $RESOLVED"

# Same write the exporter does after cd, then the same cleanup.
TEMP_DIR=$(mktemp -d "$WORKDIR/tmp.XXXX")
(
    cd "$TEMP_DIR"
    printf '%%PDF-1.4\n' > "$RESOLVED"
)
rm -rf "$TEMP_DIR"
test -f "$WORKDIR/start/out.pdf" || fail "PDF was removed with the temp directory"

# A relative path with a new parent directory, which is the documented example shape.
cd "$WORKDIR/start"
NESTED=$(EXPORT_PDF_RESOLVE_ONLY=1 bash "$SCRIPT" ../deck/index.html ../exports/deck.pdf)
[[ "$NESTED" == "$WORKDIR/exports/deck.pdf" ]] || fail "expected nested path, got $NESTED"
test -d "$WORKDIR/exports" || fail "output directory was not created"

# No explicit output: derived beside the already-absolute input, and still absolute.
DERIVED=$(EXPORT_PDF_RESOLVE_ONLY=1 bash "$SCRIPT" "$WORKDIR/deck/index.html")
[[ "$DERIVED" == "$WORKDIR/deck/index.pdf" ]] || fail "expected derived path, got $DERIVED"

echo "ok: relative output paths are absolute before the temp-dir cleanup"
