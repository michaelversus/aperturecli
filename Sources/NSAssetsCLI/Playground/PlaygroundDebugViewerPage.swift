/// The hidden debug viewer: a canvas showing the stream, with clicks sent back as taps.
/// It speaks the same protocol as the app.
enum PlaygroundDebugViewerPage {
    static func html(webSocketPort: UInt16, token: String) -> String {
        template
            .replacingOccurrences(of: "__WS_URL__", with: "ws://127.0.0.1:\(webSocketPort)")
            .replacingOccurrences(of: "__SUBPROTOCOL__", with: PlaygroundChannel.subprotocol(token: token))
            .replacingOccurrences(of: "__PROTOCOL_VERSION__", with: String(PlaygroundChannel.protocolVersion))
    }

    private static let template = """
    <!doctype html>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>NSAssets playground debug viewer</title>
    <style>
      body { margin: 0; background: #111; color: #ddd; font: 13px -apple-system, sans-serif; text-align: center; }
      canvas { height: 92vh; max-width: 100vw; margin-top: 8px; cursor: pointer; background: #000; }
      #status { padding: 4px; }
    </style>
    <div id="status">connecting…</div>
    <canvas id="screen"></canvas>
    <script>
      const canvas = document.getElementById("screen");
      const context = canvas.getContext("2d");
      const status = document.getElementById("status");
      let frames = 0;
      const socket = new WebSocket("__WS_URL__", ["__SUBPROTOCOL__"]);
      socket.binaryType = "blob";
      socket.onopen = () => { status.textContent = "connected"; };
      socket.onclose = () => { status.textContent = "disconnected"; };
      socket.onmessage = async (event) => {
        if (typeof event.data === "string") {
          const message = JSON.parse(event.data);
          if (message.type === "hello") {
            socket.send(JSON.stringify({ type: "hello", protocolVersion: __PROTOCOL_VERSION__ }));
          } else if (message.type === "incompatible") {
            status.textContent = message.reason;
          }
          return;
        }
        const bitmap = await createImageBitmap(event.data);
        if (canvas.width !== bitmap.width) { canvas.width = bitmap.width; canvas.height = bitmap.height; }
        context.drawImage(bitmap, 0, 0);
        bitmap.close();
        frames += 1;
      };
      canvas.addEventListener("click", (event) => {
        const box = canvas.getBoundingClientRect();
        const x = (event.clientX - box.left) / box.width;
        const y = (event.clientY - box.top) / box.height;
        socket.send(JSON.stringify({ type: "tap", x, y }));
      });
      setInterval(() => {
        if (socket.readyState === 1) status.textContent = `connected, ${frames} fps`;
        frames = 0;
      }, 1000);
    </script>
    """
}
