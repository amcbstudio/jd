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

"$jd" drift < "$root_dir/fixtures/drift_basic.jsonl" > "$tmp_dir/out"
cat > "$tmp_dir/exp" <<'EOF'
{"type":"field_appeared","field":"c","line":2,"value_type":"bool"}
{"type":"field_disappeared","field":"b","last_line":1,"last_type":"string"}
{"type":"field_disappeared","field":"c","last_line":2,"last_type":"bool"}
{"type":"type_changed","field":"a","line":2,"from":"number","to":"string"}
{"type":"type_changed","field":"a","line":3,"from":"string","to":"number"}
{"type":"summary","lines":4,"records":4,"fields":3}
EOF
assert_diff "$tmp_dir/exp" "$tmp_dir/out"

