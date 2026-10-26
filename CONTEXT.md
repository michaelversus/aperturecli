# NSAssetsCLI

The bridge between NSAssets Studio, a macOS viewer for snapshot test assets, and Xcode. It prepares the environment
snapshot tests need, reports test results to the app, and hosts the live playground.

## Language

**NSAssets Studio**:
The macOS app that shows snapshot test assets and the playground; the CLI's only client.
_Avoid_: the app (when ambiguous), viewer

**Playground**:
A live, interactive view of a component running in a simulator, reached from the component's snapshot.
_Avoid_: preview, live preview

**Harness**:
The small generated app that hosts one component in the simulator, rebuilt from the code the app sends.
_Avoid_: host app, preview app

**Playground channel**:
The authenticated connection over which NSAssets Studio receives a simulator's frames and sends taps to the CLI.
_Avoid_: socket, stream, link

**Announcement**:
The notification through which the CLI tells NSAssets Studio where and how to connect to the playground channel.
_Avoid_: broadcast, handshake (the handshake is the first exchange on the channel)

**CLI marker**:
The `nsassets-artifacts/cli.json` file every project-touching command writes, so NSAssets Studio can read the CLI and
protocol versions without launching a process.
_Avoid_: version file, manifest

**Simulator session**:
One live connection to one explicitly chosen simulator, through which frames arrive and input is sent.
_Avoid_: stream, connection

**Probe**:
The check that classifies a machine, and optionally a booted simulator, as supported, degraded or unsupported for the
playground, with the reasons.
_Avoid_: health check, doctor

**Input transport**:
The route by which touches reach the simulator's guest: DTUHID (current) or Indigo (legacy, unreliable).
_Avoid_: HID mode, driver

**Verified tap**:
A tap counted as delivered only if the screen changed and the guest dropped no events.
_Avoid_: successful tap, sent tap

**Device Hub**:
The Xcode 27 app that replaced Simulator.app; its being attached is a probe caveat.
_Avoid_: Simulator app
