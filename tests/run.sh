#!/bin/sh
set -eu

root_dir=$(
	# shellcheck disable=SC2164
	CDPATH= cd "$(dirname "$0")/.." && pwd
)

fail=0
for t in "$root_dir"/tests/test_*.sh; do
	[ -f "$t" ] || continue
	if sh "$t"; then
		printf '%s\n' "ok  $(basename "$t")"
	else
		printf '%s\n' "ERR $(basename "$t")" >&2
		fail=1
	fi
done

exit "$fail"

