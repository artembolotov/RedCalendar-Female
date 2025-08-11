//
//  CalendarController.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 09.08.2025.
//

class CalendarController {
    private var scrollAction: (() -> Void)?
    
    func setScrollAction(_ action: @escaping () -> Void) {
        scrollAction = action
    }
    
    func scrollToToday() {
       scrollAction?()
    }
}
