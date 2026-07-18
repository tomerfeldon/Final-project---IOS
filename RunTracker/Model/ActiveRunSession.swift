//
//  ActiveRunSession.swift
//  RunTracker
//
//  A run that is happening right now. This lives in the Realtime Database and
//  is deleted the moment the run ends - it is throwaway state, not history.
//

import Foundation

struct ActiveRunSession {

    // MARK: - Properties

    let isActive: Bool
    let elapsedSeconds: Int
    let distanceMeters: Double
    let startTimestamp: Double   // seconds since 1970

    // MARK: - Derived Values

    var startDate: Date {
        return Date(timeIntervalSince1970: startTimestamp)
    }
}

// MARK: - Firebase Conversion

extension ActiveRunSession {

    /// The Realtime Database hands numbers back as NSNumber, and it does not
    /// preserve Int vs Double - a distance of exactly 0.0 comes back as an Int.
    /// Reading through NSNumber avoids a cast that silently fails on round trips.
    init?(dictionary: [String: Any]) {
        guard let isActiveNumber = dictionary["isActive"] as? NSNumber else {
            return nil
        }

        self.isActive = isActiveNumber.boolValue
        self.elapsedSeconds = (dictionary["elapsedSeconds"] as? NSNumber)?.intValue ?? 0
        self.distanceMeters = (dictionary["distanceMeters"] as? NSNumber)?.doubleValue ?? 0
        self.startTimestamp = (dictionary["startTimestamp"] as? NSNumber)?.doubleValue
            ?? Date().timeIntervalSince1970
    }

    func toDictionary() -> [String: Any] {
        return [
            "isActive": isActive,
            "elapsedSeconds": elapsedSeconds,
            "distanceMeters": distanceMeters,
            "startTimestamp": startTimestamp
        ]
    }
}
