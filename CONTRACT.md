# Contract

This document defines non-negotiable constraints for tools in amcbstudio repositories.

## Interface

- The primary interface MUST be a command-line interface.
- Tools MUST support reading from stdin and writing to stdout.
- Tools MUST NOT require interactive input.

## Output

- Default output MUST be deterministic.
- Default output MUST be machine-parseable.
- JSON Lines (JSONL) is the preferred format.
- Output ordering MUST be stable.

Optional flags may enable:
- pretty printing
- timestamps (opt-in only)

## Errors

- Errors MUST be explicit.
- Exit codes MUST be meaningful.
- Error messages MUST be concise and actionable.

Silent failure is unacceptable.

## Dependencies

- Minimize dependencies.
- Avoid network access unless explicitly required.
- Avoid runtime downloads or installers.

## Portability

- Prefer POSIX-compatible shell behavior.
- Do not assume GNU-only extensions unless clearly documented.
- Do not assume macOS- or Linux-specific features unless unavoidable.

## Security

- No secrets are handled.
- No credentials are stored.
- No environment inspection beyond what is strictly necessary.

If a tool cannot be run safely in a sandbox, it does not belong here.
