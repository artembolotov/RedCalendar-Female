//
//  APNSToken.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 09.06.2025.
//

struct APNSToken {
    let value: String
    let isSynced: Bool
    
    init(value: String, isSynced: Bool = false) {
        self.value = value
        self.isSynced = isSynced
    }
}
