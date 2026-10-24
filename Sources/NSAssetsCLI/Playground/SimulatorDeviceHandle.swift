import Foundation

/// A `SimDevice` found through the Objective-C runtime, with only the calls the playground needs.
/// CoreSimulator objects are used from the session's actor, so the handle is marked sendable.
struct SimulatorDeviceHandle: @unchecked Sendable {
    private static let bootedState: UInt64 = 3

    private typealias ErrorOut = UnsafeMutablePointer<Unmanaged<AnyObject>?>?
    private typealias ContextFunction = @convention(c) (AnyObject, Selector, NSString, ErrorOut) -> AnyObject?
    private typealias DeviceSetFunction = @convention(c) (AnyObject, Selector, ErrorOut) -> AnyObject?
    private typealias ObjectFunction = @convention(c) (AnyObject, Selector) -> AnyObject?
    private typealias StateFunction = @convention(c) (AnyObject, Selector) -> UInt64
    private typealias LookupFunction = @convention(c) (AnyObject, Selector, NSString, ErrorOut) -> UInt32

    /// The underlying `SimDevice`, for APIs that take it as an argument.
    let device: AnyObject

    static func find(udid: String, developerDirectory: String) throws -> SimulatorDeviceHandle {
        guard let contextClass = NSClassFromString("SimServiceContext") else {
            throw PlaygroundError.symbolMissing("SimServiceContext")
        }
        let contextSelector = "sharedServiceContextForDeveloperDir:error:"
        let context = try call(ContextFunction.self, contextSelector) { function, selector, error in
            function(contextClass, selector, developerDirectory as NSString, error)
        }
        let deviceSet = try call(DeviceSetFunction.self, "defaultDeviceSetWithError:") { function, selector, error in
            function(context, selector, error)
        }
        let devices = try send("devices", to: deviceSet) as? [AnyObject] ?? []
        for device in devices {
            let identifier = try send("UDID", to: device) as? UUID
            if identifier?.uuidString.caseInsensitiveCompare(udid) == .orderedSame {
                return SimulatorDeviceHandle(device: device)
            }
        }
        throw PlaygroundError.deviceNotFound(udid)
    }

    var isBooted: Bool {
        Self.stateFunction()(device, Selector(("state"))) == Self.bootedState
    }

    /// Looks a guest Mach service up in the simulator's bootstrap namespace. Only works while booted.
    func lookup(service: String) throws -> UInt32 {
        var error: Unmanaged<AnyObject>?
        let function = try Self.function(LookupFunction.self)
        let port = function(device, Selector(("lookup:error:")), service as NSString, &error)
        if port == 0 {
            let reason = error?.takeUnretainedValue().description ?? "no port returned"
            throw PlaygroundError.serviceLookupFailed(service: service, reason: reason)
        }
        return port
    }

    /// The device's IO client (SimulatorKit's, once it is loaded), which owns the framebuffer ports.
    func ioClient() throws -> NSObject {
        guard let client = try Self.send("io", to: device) as? NSObject else {
            throw PlaygroundError.symbolMissing("SimDevice.io")
        }
        return client
    }

    // MARK: - Objective-C messaging

    private static func function<T>(_ type: T.Type) throws -> T {
        guard let handle = dlopen(nil, RTLD_NOW), let symbol = dlsym(handle, "objc_msgSend") else {
            throw PlaygroundError.symbolMissing("objc_msgSend")
        }
        return unsafeBitCast(symbol, to: type)
    }

    private static func stateFunction() -> StateFunction {
        // objc_msgSend always resolves; a failure here would already have thrown in `find`.
        (try? function(StateFunction.self)) ?? { _, _ in 0 }
    }

    private static func send(_ name: String, to object: AnyObject) throws -> AnyObject? {
        let function = try function(ObjectFunction.self)
        return function(object, Selector((name)))
    }

    private static func call<F, R>(
        _ type: F.Type,
        _ name: String,
        _ invoke: (F, Selector, ErrorOut) -> R?
    ) throws -> R {
        var error: Unmanaged<AnyObject>?
        let result = invoke(try function(type), Selector((name)), &error)
        guard let result else {
            let reason = error?.takeUnretainedValue().description ?? "returned nil"
            throw PlaygroundError.serviceContextUnavailable("\(name): \(reason)")
        }
        return result
    }
}
