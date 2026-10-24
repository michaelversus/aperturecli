import Foundation
import XPC

/// Delivers touches to the simulator's `dtuhidd` digitizer service as plain-XPC dictionaries.
/// The wire shape (envelope keys, uint64 enums, normalized top-left coordinates) follows what
/// facebook/idb (MIT) documents for Xcode 27.
final class DTUHIDTouchSender: @unchecked Sendable {
    static let serviceName = "com.apple.coredevice.feature.remote.hid.digitizer"

    /// `dtuhidd` activates its virtual services only once it has a peer and drops earlier events,
    /// so a connection must see a barrier reply, plus a device-open tail, before the first event.
    private static let livenessTimeout = Duration.seconds(4)
    private static let livenessAttempts = 3
    private static let livenessBackoff = Duration.seconds(4)
    private static let replyTail = Duration.milliseconds(200)
    private static let drain = Duration.milliseconds(80)

    private let connection: XPCServiceConnection

    private init(connection: XPCServiceConnection) {
        self.connection = connection
    }

    static func connect(to device: SimulatorDeviceHandle) async throws -> DTUHIDTouchSender {
        for attempt in 1...livenessAttempts {
            // A cancelled XPC connection cannot be resumed, so each attempt builds its own.
            let connection = try XPCServiceConnection(
                port: try device.lookup(service: serviceName),
                service: serviceName,
                queue: DispatchQueue(label: "nsassets.spike.dtuhid")
            )
            do {
                try await connection.request(barrierMessage(), timeout: livenessTimeout)
                try await Task.sleep(for: replyTail)
                return DTUHIDTouchSender(connection: connection)
            } catch {
                connection.cancel()
                if attempt < livenessAttempts { try await Task.sleep(for: livenessBackoff) }
            }
        }
        throw PlaygroundError.hidDaemonUnresponsive(attempts: livenessAttempts)
    }

    func send(_ phase: SimulatorTouchPhase, at point: NormalizedPoint) async throws {
        let pointOne = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_double(pointOne, "x", point.horizontal)
        xpc_dictionary_set_double(pointOne, "y", point.vertical)

        let payload = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_value(payload, "pointOne", pointOne)
        xpc_dictionary_set_uint64(payload, "eventType", phase.rawValue)
        xpc_dictionary_set_uint64(payload, "edge", 0)
        xpc_dictionary_set_uint64(payload, "target", 0)

        connection.send(Self.message(type: "IndigoDigitizerEvent", barrier: false, payload: payload))
        await connection.sendBarrier()
    }

    func disconnect() async {
        try? await Task.sleep(for: Self.drain)
        connection.cancel()
    }

    // MARK: - Messages

    /// A keyboard event with usage 0 ("no key") so the daemon answers without the guest seeing a keypress.
    private static func barrierMessage() -> xpc_object_t {
        let payload = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_uint64(payload, "usageCode", 0)
        xpc_dictionary_set_uint64(payload, "state", 2)
        return message(type: "IndigoKeyboardButtonEvent", barrier: true, payload: payload)
    }

    private static func message(type: String, barrier: Bool, payload: xpc_object_t) -> xpc_object_t {
        let message = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_string(message, "messageType", type)
        xpc_dictionary_set_bool(message, "isBarrier", barrier)
        xpc_dictionary_set_string(message, "featureIdentifier", serviceName)
        xpc_dictionary_set_value(message, "payload", payload)
        return message
    }
}
