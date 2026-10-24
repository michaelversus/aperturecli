---
status: accepted
---

# Host the simulator playground in the CLI, with the app as a client

The playground needs private SimulatorKit and CoreSimulator APIs to stream a simulator's screen and inject touches. We
put that code in the unsandboxed CLI (`nsassetscli`), which the user starts themselves, and make the sandboxed NSAssets
Studio app a client that connects over localhost. This keeps private-API code out of the app (which is sandboxed and
distributed through the App Store), at the cost that the app cannot start the process and the user must run a command.

## Considered Options

- **Private APIs inside the app**: rejected because a sandboxed App Store app cannot use them.
- **The app spawns the CLI**: rejected because a sandboxed app cannot launch an arbitrary installed binary.
- **A background agent started at login**: deferred, since it adds install, upgrade and uninstall work before the
  feature has proven its value.

## Consequences

- The app shows a "not running" state and the command to run; it needs only the outgoing-network entitlement it already has.
- The transport, discovery and authentication are decided in ADR 0003. The spike's hardcoded, tokenless localhost
  WebSocket was only for the spike.
- Reviewers may question an app feature that depends on a separately installed CLI; the optional, explained "not
  running" state is the mitigation.
