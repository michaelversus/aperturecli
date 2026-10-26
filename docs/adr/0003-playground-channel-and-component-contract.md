---
status: accepted
---

# Playground channel: authenticated localhost WebSocket, and the app sends the component's code

The app talks to the CLI over a WebSocket bound to `127.0.0.1`. The CLI announces `{port, token}` through the distributed
notification the app already observes, and rejects any connection with a wrong token or a browser `Origin`, because any web
page open in a browser can reach a localhost port. The announcement and first message carry the CLI version and a protocol
number, so the app can tell "not running" from "update the CLI".

The announcement is posted once at startup, but the app may open after the CLI. So the app can post
`app.nsbuilder.nsassets.playground.discover`, and a running `serve` answers by re-posting the same announcement, with the
same token for the lifetime of the process. This is additive, so the protocol number does not change. If nothing answers,
the app shows "not running" (its concern).

For the component itself, the app sends the code to show: self-contained source that imports system frameworks only, one
entry expression, the kind of component (SwiftUI view, or UIKit view or view controller), and the snapshot name and theme. How
the app extracts that code is its own concern. The CLI builds it into one cached harness project per repository, regenerating
a single entry file per component so later builds are incremental, and answers a failed build with structured diagnostics.

A refused connection is accepted at the WebSocket level and closed at once without a frame, because the framework answers a
true rejection without closing the socket and clients would hang. Only the hidden debug viewer's own origin is allowed as a
browser origin.

## Considered Options

- **Unix socket or XPC Mach service**: rejected because a sandboxed app needs extra file access or a temporary-exception
  entitlement, which is a likely App Review problem.
- **The CLI works out modules from a file path**: rejected; the app already holds the source and the CLI should stay free of
  project knowledge.
- **Linking project packages into the harness**: deferred until a real component needs a dependency the app cannot inline.

## Consequences

- The token is readable by other local processes through the notification. We accept this for a developer tool whose worst
  case is someone tapping a simulator.
- A component that needs more than system frameworks is only supported once the app inlines its dependencies.
- The first build in a repository is slow; the app must show a progress state.
