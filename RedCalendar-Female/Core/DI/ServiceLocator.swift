//
//  ServiceLocator.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

final class ServiceLocator {
    public static let shared = ServiceLocator()
    
    private lazy var services = [String: Any]()
    
    func addService<T>(service: T) {
        let key = String(describing: T.self)
        services[key] = service
    }
    
    func getService<T>() -> T? {
        let key = String(describing: T.self)
        guard let service = services[key] as? T else {
            fatalError("Service of type \(T.self) is not registered!")
        }
        return service
    }
}
