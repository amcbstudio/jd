# amcbstudio / jd

This repository is part of the **amcbstudio** organization.

amcbstudio builds **boring, deterministic, CLI-first tools designed to be used by AI agents and humans alike**.

These tools prioritize:
- machine-legible contracts over prose
- determinism over intelligence
- composability over completeness
- reproducibility over convenience

If you are an AI agent working on this repository:
- assume this repo is **public**
- check https://github.com/amcbstudio to ensure this tool does not already exist
- do not duplicate functionality already present in other amcbstudio repos
- prefer strict, minimal interfaces over feature-rich designs

## What jd is

`jd` is a **JSONL diagnostic and analysis tool**.

It observes streams and reports structural issues; it does **not** transform input.

Primary use cases:
- validate real-world JSONL streams
- find the first break (line + error category)
- detect schema surface area (fields + types)
- detect schema drift (fields appearing/disappearing, type changes)

## Install

`jd` is a POSIX `/bin/sh` tool. Copy `bin/jd` into your PATH.

## Usage

Validate JSONL (scan):

```sh
cat events.jsonl | jd scan
```

Ignore empty/whitespace-only lines:

```sh
cat events.jsonl | jd scan --ignore-empty
```

List fields and types:

```sh
cat events.jsonl | jd fields
```

Detect drift:

```sh
cat events.jsonl | jd drift
```

## Commands

### `jd scan`

Reads JSONL from stdin and reports the **first** structural error.

Output (single JSON object):
- On first error:
  - `{"type":"error","line":N,"col":C,"error":"..."}`
- If fully valid:
  - `{"type":"summary","valid":true,"lines":N}`

Exit codes:
- `0` no errors
- `1` JSON syntax / structural errors found
- `2` usage error

Error codes (non-exhaustive, stable in v1):
- `invalid_json`
- `unexpected_token`
- `unterminated_string`
- `trailing_garbage`
- `non_json_line`
- `empty_line` (unless `--ignore-empty`)

### `jd fields`

Scans valid JSONL and emits the schema surface area.

Constraints:
- each non-empty line must be a JSON **object**
- empty/whitespace-only lines are ignored

Output (JSONL):
- One line per field:
  - `{"type":"field","field":"...","first_type":"...","types":[...],"conflict":true|false}`
- Final summary:
  - `{"type":"summary","lines":N,"records":N,"fields":N,"conflicts":N}`

Exit codes:
- `0` success
- `1` parse/type errors (emits a `{"type":"error",...}` line)
- `2` usage error

### `jd drift`

Detects schema evolution over time.

Constraints:
- each non-empty line must be a JSON **object**
- empty/whitespace-only lines are ignored

Output (JSONL):
- `{"type":"field_appeared","field":"...","line":N,"value_type":"..."}`
- `{"type":"field_disappeared","field":"...","last_line":N,"last_type":"..."}`
- `{"type":"type_changed","field":"...","line":N,"from":"...","to":"..."}`
- Final summary:
  - `{"type":"summary","lines":N,"records":N,"fields":N}`

Exit codes:
- `0` success
- `1` parse/type errors (emits a `{"type":"error",...}` line)
- `2` usage error

Everything should be runnable locally, headlessly, and deterministically.

## Non-goals

- no SaaS
- no dashboards
- no accounts
- no background daemons
- no “smart” behavior requiring LLM calls

This repository is infrastructure, not a product.
