#!/bin/sh
set -eu

root_dir=$(
	# shellcheck disable=SC2164
	CDPATH= cd "$(dirname "$0")/.." && pwd
)
jd="$root_dir/bin/jd"

tmp_dir="${TMPDIR:-/tmp}/jd-test.$$"
mkdir -p "$tmp_dir"
trap 'rm -rf "$tmp_dir"' EXIT

assert_diff() {
	exp_file="$1"
	got_file="$2"
	if diff -u "$exp_file" "$got_file" >/dev/null 2>&1; then
		return 0
	fi
	diff -u "$exp_file" "$got_file" >&2 || true
	exit 1
}

# --- valid JSONL ---
"$jd" scan < "$root_dir/fixtures/scan_valid.jsonl" > "$tmp_dir/out"
cat > "$tmp_dir/exp" <<'EOF'
{"type":"summary","valid":true,"lines":8}
EOF
assert_diff "$tmp_dir/exp" "$tmp_dir/out"

# --- unterminated string ---
set +e
"$jd" scan < "$root_dir/fixtures/scan_invalid_unterminated_string.jsonl" > "$tmp_dir/out"
rc=$?
set -e
[ "$rc" -eq 1 ] || exit 1
cat > "$tmp_dir/exp" <<'EOF'
{"type":"error","line":3,"col":19,"error":"unterminated_string"}
EOF
assert_diff "$tmp_dir/exp" "$tmp_dir/out"

# --- non-JSON line ---
set +e
"$jd" scan < "$root_dir/fixtures/scan_invalid_non_json_line.jsonl" > "$tmp_dir/out"
rc=$?
set -e
[ "$rc" -eq 1 ] || exit 1
cat > "$tmp_dir/exp" <<'EOF'
{"type":"error","line":2,"col":1,"error":"non_json_line"}
EOF
assert_diff "$tmp_dir/exp" "$tmp_dir/out"

# --- empty line (default: error) ---
set +e
"$jd" scan < "$root_dir/fixtures/scan_empty_line.jsonl" > "$tmp_dir/out"
rc=$?
set -e
[ "$rc" -eq 1 ] || exit 1
cat > "$tmp_dir/exp" <<'EOF'
{"type":"error","line":2,"col":1,"error":"empty_line"}
EOF
assert_diff "$tmp_dir/exp" "$tmp_dir/out"

# --- ignore empty lines ---
"$jd" scan --ignore-empty < "$root_dir/fixtures/scan_empty_line.jsonl" > "$tmp_dir/out"
cat > "$tmp_dir/exp" <<'EOF'
{"type":"summary","valid":true,"lines":3}
EOF
assert_diff "$tmp_dir/exp" "$tmp_dir/out"

