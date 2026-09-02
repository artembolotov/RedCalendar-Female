//
//  DeviceModel.swift
//  RedCalendar-Female
//

import Foundation

/// The hardware identifier of this phone — `iPhone17,4`, not a marketing name.
///
/// It goes to the server at sign-in and, since SYNC.md §19.5, on every sync run: a restore
/// carries the keychain onto a new phone, so the session outlives the hardware and a model
/// written once would name the sold phone in the device list forever. The name a person reads is
/// resolved on the server, from this string, when the list is read — the table behind it ages
/// every September, and a deploy is the only way to keep it current for builds nobody updates.
///
/// `static let`, so `uname` is parsed once per launch rather than per request: two call sites
/// send it now, and the sync one sends it on every run.
enum DeviceModel {
    static let identifier: String = {
        var systemInfo = utsname()
        uname(&systemInfo)

        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }()
}
