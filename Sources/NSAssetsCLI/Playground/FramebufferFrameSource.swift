import CoreImage
import Foundation
import IOSurface

/// Streams JPEG frames of a booted simulator's main display from its framebuffer IOSurface.
///
/// Registering screen callbacks on a framebuffer descriptor is what makes SimulatorKit populate its
/// surface. Everything runs on one serial queue, callbacks are coalesced onto a single pending capture,
/// and the surface is cached, because reading `framebufferSurface` is a synchronous XPC round trip.
/// Approach studied from EvanBacon/serve-sim and tddworks/baguette (both Apache-2.0), reimplemented here.
final class FramebufferFrameSource: @unchecked Sendable {
    private static let framebufferPortIdentifier = "com.apple.framebuffer.display"
    /// Device Hub's resize mode adds a presentation surface this large next to the native one.
    private static let presentationSurfaceWidth = 7680
    private static let idleInterval = DispatchTimeInterval.milliseconds(200)

    private let ioClient: NSObject
    private let queue = DispatchQueue(label: "nsassets.spike.framebuffer", qos: .userInteractive)
    private let ciContext = CIContext()
    private let jpegQuality: Double

    // All state below is touched only on `queue`.
    private var descriptors: [NSObject] = []
    private var callbackIdentifiers: [ObjectIdentifier: UUID] = [:]
    private var cachedSurface: IOSurface?
    private var lastFrame: SimulatorFrame?
    private var captureScheduled = false
    private var idleTimer: DispatchSourceTimer?
    private var continuation: AsyncThrowingStream<SimulatorFrame, Error>.Continuation?

    init(ioClient: NSObject, jpegQuality: Double = 0.6) {
        self.ioClient = ioClient
        self.jpegQuality = jpegQuality
    }

    func frames() -> AsyncThrowingStream<SimulatorFrame, Error> {
        AsyncThrowingStream { continuation in
            queue.async { [self] in
                self.continuation = continuation
                do {
                    try wireUp()
                    startIdleTimer()
                    scheduleCapture()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { [self] _ in queue.async { self.tearDown() } }
        }
    }

    // MARK: - Wiring

    private func wireUp() throws {
        ioClient.perform(NSSelectorFromString("updateIOPorts"))
        let candidates = try framebufferDescriptors()
        descriptors = candidates
        for descriptor in candidates { try register(descriptor) }
    }

    private func framebufferDescriptors() throws -> [NSObject] {
        guard let ports = ioClient.value(forKey: "deviceIOPorts") as? [NSObject] else {
            throw PlaygroundError.symbolMissing("deviceIOPorts")
        }
        let portIdentifier = NSSelectorFromString("portIdentifier")
        let descriptorSelector = NSSelectorFromString("descriptor")
        let surfaceSelector = NSSelectorFromString("framebufferSurface")
        let candidates = ports.compactMap { port -> NSObject? in
            guard port.responds(to: portIdentifier),
                  Self.identifier(of: port) == Self.framebufferPortIdentifier,
                  port.responds(to: descriptorSelector),
                  let descriptor = port.perform(descriptorSelector)?.takeUnretainedValue() as? NSObject,
                  descriptor.responds(to: surfaceSelector)
            else { return nil }
            return descriptor
        }
        guard !candidates.isEmpty else { throw PlaygroundError.symbolMissing("framebuffer display port") }
        return candidates
    }

    private static func identifier(of port: NSObject) -> String {
        let selector = NSSelectorFromString("portIdentifier")
        return "\(port.perform(selector)?.takeUnretainedValue() ?? "" as NSString)"
    }

    private func register(_ descriptor: NSObject) throws {
        let selector = #selector(
            FramebufferDescriptorCallbacks.registerScreenCallbacks(
                uuid:callbackQueue:frameCallback:surfacesChangedCallback:propertiesChangedCallback:
            )
        )
        guard descriptor.responds(to: selector) else {
            throw PlaygroundError.symbolMissing("registerScreenCallbacks")
        }

        let identifier = UUID()
        callbackIdentifiers[ObjectIdentifier(descriptor)] = identifier
        let frameCallback: @convention(block) () -> Void = { [weak self] in self?.scheduleCapture() }
        let surfacesChangedCallback: @convention(block) () -> Void = { [weak self] in
            self?.cachedSurface = nil
            self?.scheduleCapture()
        }
        let propertiesChangedCallback: @convention(block) () -> Void = {}
        (descriptor as AnyObject).registerScreenCallbacks(
            uuid: identifier,
            callbackQueue: queue,
            frameCallback: frameCallback,
            surfacesChangedCallback: surfacesChangedCallback,
            propertiesChangedCallback: propertiesChangedCallback
        )
    }

    private func tearDown() {
        idleTimer?.cancel()
        idleTimer = nil
        let selector = NSSelectorFromString("unregisterScreenCallbacksWithUUID:")
        for descriptor in descriptors {
            if let identifier = callbackIdentifiers[ObjectIdentifier(descriptor)], descriptor.responds(to: selector) {
                descriptor.perform(selector, with: identifier as NSUUID)
            }
        }
        descriptors = []
        callbackIdentifiers = [:]
        cachedSurface = nil
        continuation = nil
    }

    private func startIdleTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Self.idleInterval, repeating: Self.idleInterval)
        timer.setEventHandler { [weak self] in self?.replayLastFrameIfStale() }
        timer.resume()
        idleTimer = timer
    }

    // MARK: - Capture

    /// Many callbacks can arrive while one capture runs; they collapse into a single following capture.
    private func scheduleCapture() {
        guard !captureScheduled else { return }
        captureScheduled = true
        queue.async { [self] in
            captureScheduled = false
            capture()
        }
    }

    private func capture() {
        guard let surface = currentSurface() else { return }
        let image = CIImage(ioSurface: unsafeBitCast(surface, to: IOSurfaceRef.self))
        let qualityKey = CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)
        let options = [qualityKey: jpegQuality]
        guard let data = ciContext.jpegRepresentation(
            of: image,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            options: options
        ) else { return }

        let frame = SimulatorFrame(
            jpegData: data,
            widthInPixels: IOSurfaceGetWidth(unsafeBitCast(surface, to: IOSurfaceRef.self)),
            heightInPixels: IOSurfaceGetHeight(unsafeBitCast(surface, to: IOSurfaceRef.self)),
            timestamp: Date(),
            isReplay: false
        )
        lastFrame = frame
        continuation?.yield(frame)
    }

    /// A static screen produces no callbacks; replaying the last frame keeps consumers from reading that as a stall.
    private func replayLastFrameIfStale() {
        guard let lastFrame, Date().timeIntervalSince(lastFrame.timestamp) >= 0.2 else { return }
        continuation?.yield(
            SimulatorFrame(
                jpegData: lastFrame.jpegData,
                widthInPixels: lastFrame.widthInPixels,
                heightInPixels: lastFrame.heightInPixels,
                timestamp: Date(),
                isReplay: true
            )
        )
    }

    private func currentSurface() -> IOSurface? {
        if let cachedSurface { return cachedSurface }
        let chosen = liveNativeSurfaces().max { Self.area($0) < Self.area($1) }
        cachedSurface = chosen
        return chosen
    }

    /// The live surfaces without Device Hub's presentation surface, or all live ones if only that exists.
    private func liveNativeSurfaces() -> [IOSurface] {
        let selector = NSSelectorFromString("framebufferSurface")
        let surfaces = descriptors.compactMap { descriptor -> IOSurface? in
            guard let object = descriptor.perform(selector)?.takeUnretainedValue() else { return nil }
            return unsafeDowncast(object, to: IOSurface.self)
        }
        let live = surfaces.filter { Self.width($0) > 0 }
        let native = live.filter { Self.width($0) < Self.presentationSurfaceWidth }
        return native.isEmpty ? live : native
    }

    /// How many native displays are live right now; more than one means a foldable or extra planes.
    func nativeDisplayCount() -> Int {
        queue.sync { liveNativeSurfaces().count }
    }

    private static func width(_ surface: IOSurface) -> Int {
        IOSurfaceGetWidth(unsafeBitCast(surface, to: IOSurfaceRef.self))
    }

    private static func area(_ surface: IOSurface) -> Int {
        let ref = unsafeBitCast(surface, to: IOSurfaceRef.self)
        return IOSurfaceGetWidth(ref) * IOSurfaceGetHeight(ref)
    }
}

/// Declares the private SimulatorKit selector so its blocks bridge as escaping.
@objc private protocol FramebufferDescriptorCallbacks {
    @objc(
        registerScreenCallbacksWithUUID:callbackQueue:frameCallback:
        surfacesChangedCallback:propertiesChangedCallback:
    )
    func registerScreenCallbacks(
        uuid: UUID,
        callbackQueue: DispatchQueue,
        frameCallback: @escaping @convention(block) () -> Void,
        surfacesChangedCallback: @escaping @convention(block) () -> Void,
        propertiesChangedCallback: @escaping @convention(block) () -> Void
    )
}
