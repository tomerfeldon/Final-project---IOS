//
//  RunLocationTracker.swift
//  RunTracker
//
//  Wraps CLLocationManager and turns a stream of GPS fixes into one number:
//  how far the runner has actually travelled.
//

import Foundation
import CoreLocation

// MARK: - RunLocationTrackerDelegate

protocol RunLocationTrackerDelegate: AnyObject {
    func locationTracker(_ tracker: RunLocationTracker, didUpdateDistance meters: Double)
    func locationTracker(_ tracker: RunLocationTracker, didChangeAuthorization status: CLAuthorizationStatus)
}

// MARK: - RunLocationTracker

class RunLocationTracker: NSObject {

    // MARK: - Constants

    /// A fix reporting worse than this many metres of accuracy is thrown away.
    /// Without it, GPS noise indoors invents hundreds of metres of "running".
    private static let maxAcceptableAccuracy: CLLocationAccuracy = 20

    /// Core Location replays cached fixes when it starts. Anything older than
    /// this is stale and would produce a phantom jump.
    private static let maxLocationAge: TimeInterval = 5

    /// Movement smaller than this is treated as jitter, not progress.
    private static let minimumMovement: CLLocationDistance = 3

    // MARK: - Properties

    weak var delegate: RunLocationTrackerDelegate?

    private let manager = CLLocationManager()

    private(set) var totalDistanceMeters: Double = 0
    private(set) var startLocation: CLLocation?
    private(set) var lastLocation: CLLocation?

    var authorizationStatus: CLAuthorizationStatus {
        return manager.authorizationStatus
    }

    var isAuthorized: Bool {
        return authorizationStatus == .authorizedWhenInUse
            || authorizationStatus == .authorizedAlways
    }

    // MARK: - Init

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
        manager.activityType = .fitness
    }

    // MARK: - Control

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func reset() {
        totalDistanceMeters = 0
        startLocation = nil
        lastLocation = nil
    }

    /// Restores the distance total when a run is resumed from a saved session.
    /// Only the total survives - the individual GPS points were never stored,
    /// so tracking picks up fresh from wherever the runner is now.
    func seedDistance(_ meters: Double) {
        totalDistanceMeters = meters
    }

    // MARK: - Filtering

    private func isAcceptable(_ location: CLLocation) -> Bool {
        // Negative accuracy means the fix is invalid.
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy < RunLocationTracker.maxAcceptableAccuracy else {
            return false
        }

        guard abs(location.timestamp.timeIntervalSinceNow) < RunLocationTracker.maxLocationAge else {
            return false
        }

        if let lastLocation = lastLocation,
           location.distance(from: lastLocation) < RunLocationTracker.minimumMovement {
            return false
        }

        return true
    }
}

// MARK: - CLLocationManagerDelegate

extension RunLocationTracker: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        var distanceChanged = false

        for location in locations where isAcceptable(location) {
            if startLocation == nil {
                startLocation = location
            }

            if let lastLocation = lastLocation {
                totalDistanceMeters += location.distance(from: lastLocation)
                distanceChanged = true
            }

            lastLocation = location
        }

        if distanceChanged {
            delegate?.locationTracker(self, didUpdateDistance: totalDistanceMeters)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        delegate?.locationTracker(self, didChangeAuthorization: manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // A transient failure (no fix yet) is normal and not worth interrupting
        // the run over. The distance simply stops climbing until fixes resume.
        print("RunTracker: location error - \(error.localizedDescription)")
    }
}
