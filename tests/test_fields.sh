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

"$jd" fields < "$root_dir/fixtures/fields_basic.jsonl" > "$tmp_dir/out"
cat > "$tmp_dir/exp" <<'EOF'
{"type":"field","field":"a","first_type":"number","types":["string","number"],"conflict":true}
{"type":"field","field":"b","first_type":"string","types":["string","bool"],"conflict":true}
{"type":"field","field":"c","first_type":"null","types":["null"],"conflict":false}
{"type":"field","field":"d","first_type":"object","types":["object"],"conflict":false}
{"type":"field","field":"e","first_type":"array","types":["array"],"conflict":false}
{"type":"summary","lines":3,"records":3,"fields":5,"conflicts":2}
EOF
assert_diff "$tmp_dir/exp" "$tmp_dir/out"

# not-object line => error
set +e
"$jd" fields < "$root_dir/fixtures/fields_not_object.jsonl" > "$tmp_dir/out"
rc=$?
set -e
[ "$rc" -eq 1 ] || exit 1
cat > "$tmp_dir/exp" <<'EOF'
{"type":"error","line":2,"col":1,"error":"not_object"}
EOF
assert_diff "$tmp_dir/exp" "$tmp_dir/out"

