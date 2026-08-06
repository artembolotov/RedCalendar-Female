//
//  ServiceLocator.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

/// Registration happens once, from `Configurator.setup()` at launch; resolution happens from
/// anywhere, on any thread — middleware bodies run on the cooperative pool.
///
/// Those two have never overlapped in practice, which is how an unsynchronised dictionary
/// survived here. But that was a property of the call order rather than of this type: a single
/// service registered after launch would put a dictionary write next to concurrent reads, and a
/// `Dictionary` torn that way corrupts the heap exactly like the observation tokens in
/// `DatabaseMiddleware` did. The lock makes it a property of the type instead.
///
/// The key is the **static** type the service is registered and resolved under, which is why
/// `Configurator` registers everything as its protocol type. `ObjectIdentifier` rather than a
/// type name: it cannot collide across modules, and it costs nothing to compute, which matters
/// now that `@Injected` resolves on every read instead of caching.
final class ServiceLocator: @unchecked Sendable {
    static let shared = ServiceLocator()

    private let lock = NSLock()
    private var services = [ObjectIdentifier: Any]()

    private init() {}

    func addService<T>(service: T) {
        lock.lock()
        defer { lock.unlock() }
        services[ObjectIdentifier(T.self)] = service
    }

    func getService<T>() -> T {
        lock.lock()
        defer { lock.unlock() }
        guard let service = services[ObjectIdentifier(T.self)] as? T else {
            fatalError("Service of type \(T.self) is not registered!")
        }
        return service
    }
}
