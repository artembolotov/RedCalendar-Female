//
//  UIRectCorner+Shape.swift
//  RedCalendar-Female
//

import SwiftUI

struct RoundedCorners: InsettableShape {
    var radius: CGFloat
    var corners: UIRectCorner
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect.insetBy(dx: insetAmount, dy: insetAmount),
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }

    func inset(by amount: CGFloat) -> RoundedCorners {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}
