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

baseline="$root_dir/testdata/baseline/base.fields.jsonl"

# no drift => exit 0
set +e
"$jd" drift --baseline "$baseline" < "$root_dir/testdata/baseline/current_no_drift.jsonl" > "$tmp_dir/out"
rc=$?
set -e
[ "$rc" -eq 0 ] || exit 1
grep -q '"type":"summary"' "$tmp_dir/out"
if grep -q '"type":"type_changed"' "$tmp_dir/out"; then exit 1; fi
if grep -q '"type":"field_appeared"' "$tmp_dir/out"; then exit 1; fi
if grep -q '"type":"field_disappeared"' "$tmp_dir/out"; then exit 1; fi

# drift (add field) => exit 1, events + summary
set +e
"$jd" drift --baseline "$baseline" < "$root_dir/testdata/baseline/current_add_field.jsonl" > "$tmp_dir/out"
rc=$?
set -e
[ "$rc" -eq 1 ] || exit 1
grep -q '"type":"field_appeared"' "$tmp_dir/out"
grep -q '"type":"summary"' "$tmp_dir/out"

# drift (type change) => exit 1, type_changed + summary
set +e
"$jd" drift --baseline "$baseline" < "$root_dir/testdata/baseline/current_type_change.jsonl" > "$tmp_dir/out"
rc=$?
set -e
[ "$rc" -eq 1 ] || exit 1
grep -q '"type":"type_changed"' "$tmp_dir/out"
grep -q '"type":"summary"' "$tmp_dir/out"

# invalid baseline file => exit 2
set +e
"$jd" drift --baseline "$root_dir/testdata/baseline/invalid.fields.jsonl" < "$root_dir/testdata/baseline/current_no_drift.jsonl" > "$tmp_dir/out"
rc=$?
set -e
[ "$rc" -eq 2 ] || exit 1

# baseline missing => exit 2
set +e
"$jd" drift --baseline "$root_dir/testdata/baseline/does-not-exist.jsonl" < "$root_dir/testdata/baseline/current_no_drift.jsonl" > "$tmp_dir/out"
rc=$?
set -e
[ "$rc" -eq 2 ] || exit 1

