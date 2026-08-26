//
//  JSONValue.swift
//  RedCalendar-Female
//

import Foundation

/// Arbitrary JSON, carried through without being understood.
///
/// One user: `settings` on the sync profile (SYNC.md §4.1, §4.5). The server keeps it in `JSONB`
/// and checks its shape rather than its contents, precisely so a later build can put something
/// new in it — and a client that round-tripped it through `UserSettings` would delete whatever it
/// did not model, on every device, the first time it pushed the profile back. What is stored in
/// `user_profile.settings_json` is therefore what the server said, character for character in
/// meaning if not in whitespace.
///
/// Integers have a case of their own rather than riding in `double`, because they have to come
/// back out as integers: `UserSettings.CycleSettings` decodes `default_length` into an `Int`, and
/// a JSON `28.0` does not fit one — the decode throws and the user's cycle length silently falls
/// back to 28.
enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrepresentable JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

extension JSONValue {
    /// Both directions go through a top-level array wrapper, because `JSONSerialization` — which
    /// `JSONDecoder` is built on — refuses a bare scalar as a whole document on iOS 15. Settings
    /// are an object in practice, but a scalar is exactly the case §4.5 warns the client has to
    /// survive rather than crash on.
    init?(jsonString: String?) {
        guard let jsonString, let data = "[\(jsonString)]".data(using: .utf8) else { return nil }
        guard let wrapped = try? JSONDecoder().decode([JSONValue].self, from: data),
              let value = wrapped.first else { return nil }
        self = value
    }

    var jsonString: String? {
        guard let data = try? JSONEncoder().encode([self]),
              let wrapped = String(data: data, encoding: .utf8) else { return nil }
        return String(wrapped.dropFirst().dropLast())
    }
}
