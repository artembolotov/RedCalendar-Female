//
//  Bundle+AppInfo.swift
//  RedCalendar-Female
//

import Foundation

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "–"
    }
    var versionString: String { "\(appVersion) (\(buildNumber))" }
}
