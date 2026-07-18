//
//  Run.swift
//  RunTracker
//
//  One completed run. This is what lives in Firestore, permanently.
//

import Foundation
import FirebaseFirestore

struct Run {

    // MARK: - Properties

    let id: String              // Firestore document id
    let date: Date              // when the run happened
    let distanceMeters: Double
    let durationSeconds: Int
    let startLat: Double
    let startLng: Double
    let endLat: Double
    let endLng: Double
    var note: String?

    // MARK: - Constants

    /// Below this, pace is meaningless - a run that never moved would divide by
    /// something near zero and render as "inf".
    private static let minimumDistanceForPace: Double = 10

    /// DateFormatter is expensive to build. Cell reuse would create one per row
    /// per scroll, so it is made once and shared.
    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - Derived Values

    /// Average pace in seconds per kilometre, computed rather than stored so it
    /// can never disagree with the distance and duration it comes from.
    /// Returns 0 when there is not enough distance to be meaningful.
    var averagePaceSecPerKm: Double {
        guard distanceMeters >= Run.minimumDistanceForPace else { return 0 }
        return Double(durationSeconds) / (distanceMeters / 1000.0)
    }

    // MARK: - Display Formatting

    /// "17 Jul 2026 at 3:07 PM"
    var formattedDate: String {
        return Run.displayDateFormatter.string(from: date)
    }

    /// "5.2 km", or "840 m" under a kilometre.
    var formattedDistance: String {
        if distanceMeters < 1000 {
            return String(format: "%.0f m", distanceMeters)
        }
        return String(format: "%.1f km", distanceMeters / 1000.0)
    }

    /// "32:15"
    var formattedDuration: String {
        return durationSeconds.asClockString
    }

    /// "5:48 /km", or "--:-- /km" when the run was too short to have a pace.
    var formattedPace: String {
        guard averagePaceSecPerKm > 0 else { return "--:-- /km" }
        return "\(Int(averagePaceSecPerKm.rounded()).asClockString) /km"
    }
}

// MARK: - Firebase Conversion

extension Run {

    /// Builds a Run from a Firestore document's data.
    /// Fails only when the fields that define a run are unusable; coordinates
    /// and note are treated as optional so one bad field cannot hide a run.
    init?(id: String, dictionary: [String: Any]) {
        guard let distanceMeters = dictionary["distanceMeters"] as? Double,
              let durationSeconds = dictionary["durationSeconds"] as? Int,
              let date = Run.parseDate(from: dictionary["date"]) else {
            return nil
        }

        self.id = id
        self.date = date
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.startLat = dictionary["startLat"] as? Double ?? 0
        self.startLng = dictionary["startLng"] as? Double ?? 0
        self.endLat = dictionary["endLat"] as? Double ?? 0
        self.endLng = dictionary["endLng"] as? Double ?? 0
        self.note = (dictionary["note"] as? String)?.nilIfBlank
    }

    /// The payload written to Firestore. `id` is left out on purpose - it is the
    /// document's own name, not a field inside it.
    func toDictionary() -> [String: Any] {
        return [
            "date": Timestamp(date: date),
            "distanceMeters": distanceMeters,
            "durationSeconds": durationSeconds,
            "averagePaceSecPerKm": averagePaceSecPerKm,
            "startLat": startLat,
            "startLng": startLng,
            "endLat": endLat,
            "endLng": endLng,
            "note": note ?? ""
        ]
    }

    /// Firestore hands dates back as Timestamp, not Date. A raw number is also
    /// accepted so a document written by hand in the console still loads.
    private static func parseDate(from value: Any?) -> Date? {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        if let seconds = value as? Double {
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }
}
