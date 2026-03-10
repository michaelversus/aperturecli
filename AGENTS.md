# AGENTS.md

## Project Overview
ApertureCLI is a bridge CLI between Aperture Studio, a macOS snapshot test assets viewer app, and Xcode.
ApertureCLI is responsible for the config that defines the environment that snapshot tests require to execute properly.
ApertureCLI reads metadata when the user executes snapshot tests and communicates with the Aperture Studio macOS app.

## Build Commands
- Build: `swift build`

- Run: `swift run ApertureCLI`

- Test: `swift test`

## Git
- Commits: Conventional Commits (feat|fix|refactor|build|ci|chore|docs|style|perf|test)

## Critical Thinking
- Fix root cause (not band-aid).
- Unsure: read more code; if still stuck, ask w/ short options.
- Conflicts: call out; pick safer path.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.
- Leave breadcrumb notes in thread.

## Best Practices

#### DO:
- Use property wrappers as intended by Apple
- Test logic in isolation
- Use Swift's type system for safety
- When creating a new struct/class/enum prefer also creating a dedicated file and avoid adding multiple structures into the same file
- Do not add header comment files Created by

#### DON'T:
- Add abstraction layers without clear benefit
- Use Combine for simple async operations
- Overcomplicate simple features
- Leave unused code everywhere

### Testing Strategy

- Unit test business logic in services/clients
- Keep tests simple and focused
- Don't sacrifice code clarity for testability
- Use the same file structure with the main app also for test files

### Code Style When Editing

- Prefer composition over inheritance
- Use descriptive names for state enums
