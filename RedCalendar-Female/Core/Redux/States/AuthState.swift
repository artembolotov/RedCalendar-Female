//
//  AuthState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 09.06.2025.
//

enum AuthState {
    case notAuthenticated
    case authenticated(deviceId: String, userDetails: UserDetails?)
    case migrating(userId: String, error: Error? = nil)
    case authenticating(AuthenticationMethod)
}

// Manual Equatable: `migrating` carries an untyped Error, compared by description —
// the UI only ever shows the description, so this is the observable identity.
extension AuthState: Equatable {
    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthenticated, .notAuthenticated):
            return true
        case (.authenticated(let lId, let lUser), .authenticated(let rId, let rUser)):
            return lId == rId && lUser == rUser
        case (.migrating(let lId, let lError), .migrating(let rId, let rError)):
            return lId == rId
                && lError?.localizedDescription == rError?.localizedDescription
        case (.authenticating(let lMethod), .authenticating(let rMethod)):
            return lMethod == rMethod
        default:
            return false
        }
    }
}
