# amcbstudio / <repo-name>

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

## What this repository contains

- a single-purpose command-line tool
- no web UI
- no authentication
- no hidden state
- no background services

Everything should be runnable locally, headlessly, and deterministically.

## Non-goals

- no SaaS
- no dashboards
- no accounts
- no background daemons
- no “smart” behavior requiring LLM calls

This repository is infrastructure, not a product.
