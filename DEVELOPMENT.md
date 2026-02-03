# Development Notes (for humans and AI agents)

Before implementing a new tool or feature:

1. Check https://github.com/amcbstudio for existing repositories.
2. Do not duplicate functionality.
3. Prefer extending an existing tool only if it does not break its contract.

## Style guidelines

- Small tools > large tools
- One responsibility per tool
- Clear input/output boundaries
- Avoid cleverness
- Prefer clarity over brevity if forced to choose

## Testing

- Include simple, reproducible test cases.
- Tests should be runnable locally without external services.
- Golden-file tests are preferred where applicable.

## Documentation

- Documentation should explain **what the tool does**, not why it is interesting.
- Examples must be copy-pasteable.
- Do not include long explanations or narratives.
