# Spike findings: live simulator playground feasibility

Status: the maintainer confirmed the "Go" verdict. Decisions are recorded in ADR 0001 and ADR 0002.

## Environment

- macOS 27.0.1, Xcode 27.1 (27A9275), CoreSimulator 1174.9.2
- Simulator runtimes tested: iOS 27.0 (iPhone 17e) and iOS 18.0 (iPhone 16), both freshly created throwaway devices
- Device Hub (`DeviceHub.app`) was running on the host, and `com.apple.coredevice.dtuhidd.active` read `1` on a fresh boot

## Results

| Question | Result |
| --- | --- |
| Probe on this machine | `supported`; `degraded` once a booted simulator is checked, because the Device Hub flag is `1` |
| DTUHID tap, iOS 27.0 | 5/5 delivered (screen changed, no dropped-event log lines) |
| DTUHID tap, iOS 18.0 | 5/5 delivered |
| Legacy Indigo tap, iOS 27.0 | 0/5 after a reboot; one success earlier in the session before the reboot, unexplained |
| Legacy Indigo tap, iOS 18.0 | 0/5 |
| Frames, private framebuffer | 59.8 fps over 40 s, longest gap 26 ms, about 91 KB per JPEG at quality 0.6, 1170x2532 (native size) |
| Frames, `simctl io recordVideo` baseline | 60.1 fps, but written to a file, not a live stream |
| Memory during a 40 s capture | flat at 149 MB (`footprint`) |
| Click to first changed frame in the browser viewer | 79 to 596 ms over 7 samples, median 297 ms; includes a 60 ms touch hold and the app's own navigation animation |
| Ctrl-C | stops the HTTP and WebSocket listeners and the session |

The animation used for the frame-rate numbers was a CSS rotation served from localhost and opened in the simulator's
Safari, because the Clock app is not installed in the simulator image.

## What worked

- Input goes through `dtuhidd`: look up the guest service `com.apple.coredevice.feature.remote.hid.digitizer`, build an
  XPC connection with the private `_4sim` libxpc symbols, send dictionary messages, and wait for a barrier reply before
  the first event. No SimulatorKit is needed for this path.
- Frame capture: register screen callbacks on the `com.apple.framebuffer.display` descriptors, cache the IOSurface,
  coalesce callbacks onto one serial queue, skip surfaces 7680 pixels wide (Device Hub's presentation surface).
- A tap is only counted delivered when the screen changed and the guest log has no "No active service ... dropping
  event" line. The status-bar clock can change the screen digest once a minute, so a lone success is weak evidence.

## Known gaps (not tested)

- Rotation (no public way to rotate a simulator from the CLI; needs Device Hub)
- iPad, foldables (multiple displays), tvOS, visionOS
- Keyboard, buttons, swipes and drags
- A real app component (the spike streamed Settings and Safari)
- Latency under H.264; only JPEG was measured
- Behaviour with Device Hub closed
- The `simulatorKitFound` probe fact only reports that the framework loaded, not that its classes are usable; a missing
  class at runtime surfaces as a thrown error, not a probe issue
- The memory check ran 40 s, not the 60 s the ticket asked for
- The simulator is chosen with an explicit `--udid`; the `.nsassets.json` lookup and the booted-simulator fallback from the
  spec are not implemented, so the spike cannot touch a simulator you did not name
- `start()` boots the named simulator if it is shut down

## Verdict

Go. Streaming and tapping both work on Xcode 27.1 with the DTUHID path, at a frame rate and memory footprint that do not
need H.264 for a first version. Treat legacy Indigo as unavailable. Click latency of a few hundred milliseconds is
acceptable for a playground but should be remeasured with a real component.

## Prior art consulted

Reimplemented from reading, nothing vendored:

- facebook/idb (MIT): the DTUHID connection, message shapes and timings
- EvanBacon/serve-sim (Apache-2.0): framebuffer callbacks, surface selection, Indigo call shapes
- tddworks/baguette (Apache-2.0): framebuffer port enumeration
- Issue-tracker research summarized in issue #1 (cameroncooke/AXe, jo-duchan/tapflow and others)

## Housekeeping done during the spike

Throwaway simulators were created for verification and removed afterwards. No existing simulator was touched.
