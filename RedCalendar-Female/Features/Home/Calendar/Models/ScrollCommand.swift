//
//  ScrollCommand.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 11.08.2025.
//

/// A request for the calendar to animate itself back to its centre offset.
///
/// The request carries an id so the container can tell a new one from the one it has already
/// acted on. That removes the reset write the sender would otherwise owe, and with it the
/// window where a late reset cancels a request made in the meantime.
enum ScrollCommand: Equatable {
    case none
    case animateToCenter(id: Int)

    mutating func request() {
        if case .animateToCenter(let id) = self {
            self = .animateToCenter(id: id &+ 1)
        } else {
            self = .animateToCenter(id: 1)
        }
    }
}
