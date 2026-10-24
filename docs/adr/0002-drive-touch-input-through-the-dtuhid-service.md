---
status: accepted
---

# Drive simulator input through the DTUHID service, not the legacy Indigo client

Measured on Xcode 27.1 (CoreSimulator 1174.9.2): a tap sent to the guest's `dtuhidd` digitizer service over XPC landed 5/5
on both iOS 27.0 and iOS 18.0, while the legacy Indigo client landed 0/5 on both. We use DTUHID. The connection must stay
open for the whole session and wait for a barrier reply before the first event, because the daemon activates only once it
has a peer and silently drops earlier events.

Frames come from the framebuffer surface of the native-size display, cached and read on one serial queue; the public
`simctl recordVideo` matched the frame rate but writes a file, so it cannot feed a live view.

## Considered Options

- **Legacy Indigo input**: not carried into production. CoreSimulator 1155.4 and later drop most of it in the guest, and
  it landed 0/5 here. The comparison code remains on the unmerged spike branch.
- **Shelling out to `idb` or `AXe`**: rejected for the product, because it adds an installed dependency; the approach was
  studied and reimplemented instead.

## Consequences

- Both paths rely on private, undocumented APIs, so every Xcode update can break them. A probe reports `supported`,
  `degraded` or `unsupported` with the CoreSimulator version, and the feature must degrade rather than crash.
- The result is silent-failure prone, so a tap is only trusted when the screen changed and the guest log shows no
  dropped events.
- A CoreSimulator older than 1155.4 does not ship the DTUHID daemon, so the probe reports it as unsupported.
- Device Hub being attached did not stop DTUHID input here; the repair for legacy input kills running apps and is only
  ever printed, never run.
