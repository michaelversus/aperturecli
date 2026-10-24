import Foundation
import XPC
import os

/// A host-side XPC connection to a service inside a booted simulator.
///
/// The service's Mach port is looked up in the simulator's bootstrap namespace, wrapped in an endpoint
/// with the private `xpc_endpoint_create_mach_port_4sim`, and marked simulator-to-host with
/// `xpc_connection_enable_sim2host_4sim`; without that last call the service sees the peer but never a payload.
/// Approach studied from facebook/idb (MIT), reimplemented here.
final class XPCServiceConnection: @unchecked Sendable {
    private typealias EndpointFromPort = @convention(c) (UInt32, UInt64, UInt64) -> Unmanaged<AnyObject>?
    private typealias ConnectionFromEndpoint = @convention(c) (xpc_object_t) -> Unmanaged<AnyObject>?
    private typealias EnableSimToHost = @convention(c) (xpc_connection_t) -> Void

    private let connection: xpc_connection_t
    private let queue: DispatchQueue

    init(port: UInt32, service: String, queue: DispatchQueue) throws {
        guard let handle = dlopen(nil, RTLD_NOW),
              let endpointSymbol = dlsym(handle, "xpc_endpoint_create_mach_port_4sim"),
              let connectionSymbol = dlsym(handle, "xpc_connection_create_from_endpoint"),
              let enableSymbol = dlsym(handle, "xpc_connection_enable_sim2host_4sim")
        else { throw PlaygroundError.symbolMissing("xpc _4sim symbols") }

        let endpointFromPort = unsafeBitCast(endpointSymbol, to: EndpointFromPort.self)
        let connectionFromEndpoint = unsafeBitCast(connectionSymbol, to: ConnectionFromEndpoint.self)
        let enableSimToHost = unsafeBitCast(enableSymbol, to: EnableSimToHost.self)

        // Both create functions return +1 references.
        guard let endpoint = endpointFromPort(port, 0, 0)?.takeRetainedValue() as? xpc_object_t,
              let connection = connectionFromEndpoint(endpoint)?.takeRetainedValue() as? xpc_connection_t
        else { throw PlaygroundError.connectionFailed(service: service) }

        enableSimToHost(connection)
        xpc_connection_set_target_queue(connection, queue)
        xpc_connection_set_event_handler(connection) { _ in }
        xpc_connection_resume(connection)
        self.connection = connection
        self.queue = queue
    }

    func send(_ message: xpc_object_t) {
        xpc_connection_send_message(connection, message)
    }

    /// Resolves when XPC has handed everything sent so far to the connection.
    func sendBarrier() async {
        await withCheckedContinuation { continuation in
            xpc_connection_send_barrier(connection) { continuation.resume() }
        }
    }

    /// Sends a message and waits for its reply, failing on an XPC error reply or after `timeout`.
    func request(_ message: xpc_object_t, timeout: Duration) async throws {
        let finished = OSAllocatedUnfairLock(initialState: false)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            @Sendable func finish(_ result: Result<Void, Error>) {
                let alreadyFinished = finished.withLock { done -> Bool in
                    defer { done = true }
                    return done
                }
                if !alreadyFinished { continuation.resume(with: result) }
            }

            xpc_connection_send_message_with_reply(connection, message, queue) { reply in
                if xpc_get_type(reply) == XPC_TYPE_ERROR {
                    finish(.failure(PlaygroundError.connectionFailed(service: "reply was an XPC error")))
                } else {
                    finish(.success(()))
                }
            }
            queue.asyncAfter(deadline: .now() + .nanoseconds(Int(timeout.components.seconds * 1_000_000_000))) {
                finish(.failure(PlaygroundError.connectionFailed(service: "no reply before timeout")))
            }
        }
    }

    func cancel() {
        xpc_connection_cancel(connection)
    }
}
