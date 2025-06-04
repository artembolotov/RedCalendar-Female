//
//  Injected.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

@propertyWrapper
struct Injected<Service> {
    private var service: Service?
    
    public var wrappedValue: Service {
        mutating get {
            if service == nil {
                service = ServiceLocator.shared.getService()
            }
            return service!
        }
    }
    
    public var projectedValue: Injected<Service> {
        mutating set {
            self = newValue
        }
        get {
            return self
        }
    }
}
