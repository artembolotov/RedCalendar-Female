//
//  Injected.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

@propertyWrapper
struct Injected<Service> {
    private lazy var service: Service = ServiceLocator.shared.getService()
    
    public var wrappedValue: Service {
        mutating get { service }
    }
    
    public var projectedValue: Injected<Service> {
        get { self }
        set { self = newValue }
    }
}
