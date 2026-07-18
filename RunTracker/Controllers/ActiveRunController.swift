//
//  ActiveRunController.swift
//  RunTracker
//
//  The screen where a run actually happens: a clock, a distance, and three
//  buttons. Time comes from a Timer, distance comes from GPS, and the pair is
//  mirrored into the Realtime Database once a second so the run survives the
//  app being killed.
//

import UIKit
import CoreLocation

class ActiveRunController: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var paceLabel: UILabel!
    @IBOutlet weak var statsStackView: UIStackView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var startPauseButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!

    // MARK: - Types

    private enum RunState {
        case idle
        case running
        case paused
    }

    // MARK: - Properties

    /// Set by RunsListController when the user chooses to resume a session that
    /// was found in the Realtime Database. nil for a fresh run.
    var sessionToResume: ActiveRunSession?

    private var state: RunState = .idle
    private let tracker = RunLocationTracker()
    private var timer: Timer?

    /// When the current running segment began. nil whenever the run is paused.
    private var segmentStartDate: Date?

    /// Seconds banked from segments that already ended at a pause.
    private var accumulatedSeconds: TimeInterval = 0

    /// When the run as a whole began - saved as the Run's date.
    private var runStartDate: Date?

    private var isSaving = false

    // MARK: - Derived Values

    /// The clock is derived from dates, never from counting timer ticks.
    /// Timer makes no real-time guarantees - ticks get delayed and coalesced,
    /// so `elapsed += 1` would drift over a long run. The timer's only job is to
    /// tell us to look at the clock again.
    private var elapsedSeconds: Int {
        var total = accumulatedSeconds
        if let segmentStartDate = segmentStartDate {
            total += Date().timeIntervalSince(segmentStartDate)
        }
        return Int(total)
    }

    /// The run exactly as it stands right now. Used both to draw the labels and,
    /// on Stop, as the thing that gets saved - so what you see is what is stored.
    private var currentRunSnapshot: Run {
        return Run(id: "",
                   date: runStartDate ?? Date(),
                   distanceMeters: tracker.totalDistanceMeters,
                   durationSeconds: elapsedSeconds,
                   startLat: tracker.startLocation?.coordinate.latitude ?? 0,
                   startLng: tracker.startLocation?.coordinate.longitude ?? 0,
                   endLat: tracker.lastLocation?.coordinate.latitude ?? 0,
                   endLng: tracker.lastLocation?.coordinate.longitude ?? 0,
                   note: nil)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        tracker.delegate = self
        configureAppearance()
        restoreSessionIfNeeded()

        if tracker.authorizationStatus == .notDetermined {
            tracker.requestPermission()
        }

        refreshUI()
    }

    // MARK: - Appearance

    private func configureAppearance() {
        // Monospaced digits keep the numbers from shuffling sideways every time
        // a digit changes width - very visible on a clock ticking once a second.
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 44, weight: .semibold)
        distanceLabel.font = .monospacedDigitSystemFont(ofSize: 26, weight: .semibold)
        paceLabel.font = .monospacedDigitSystemFont(ofSize: 26, weight: .semibold)

        // AccentGreen is a Color Set in the asset catalog with its own Dark
        // variant, so the button stays legible in both appearances.
        startPauseButton.backgroundColor = UIColor(named: "AccentGreen") ?? .systemGreen
        startPauseButton.setTitleColor(.white, for: .normal)
        startPauseButton.layer.cornerRadius = 12

        stopButton.backgroundColor = .systemRed
        stopButton.setTitleColor(.white, for: .normal)
        stopButton.layer.cornerRadius = 12
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateStatsAxis(for: view.bounds.size)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Backed out mid-run. Bank the time and stop the clock, but leave the
        // live session in the Realtime Database so the list screen can offer to
        // pick the run back up.
        if isMovingFromParent && state == .running {
            pauseRun()
        }
    }

    deinit {
        stopTimer()
        tracker.stop()
    }

    // MARK: - Rotation

    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.updateStatsAxis(for: size)
        })
    }

    /// In landscape there is width to spare and no height, so the three stats
    /// sit side by side instead of stacked.
    private func updateStatsAxis(for size: CGSize) {
        statsStackView.axis = size.width > size.height ? .horizontal : .vertical
    }

    // MARK: - Resume

    private func restoreSessionIfNeeded() {
        guard let session = sessionToResume else { return }

        runStartDate = session.startDate
        accumulatedSeconds = TimeInterval(session.elapsedSeconds)
        tracker.seedDistance(session.distanceMeters)

        // Come back paused rather than running. The user decides when to pick it
        // up again, and nothing is recorded for the time the app was closed.
        state = .paused
    }

    // MARK: - Actions

    @IBAction func startPauseButtonTapped(_ sender: UIButton) {
        if state == .running {
            pauseRun()
            return
        }

        // Starting and resuming both need GPS - without it the clock would run
        // while the distance sat at zero, which is worse than refusing outright.
        guard tracker.isAuthorized else {
            showPermissionAlert()
            return
        }

        if state == .idle {
            startRun()
        } else {
            beginSegment()
        }
    }

    @IBAction func stopButtonTapped(_ sender: UIButton) {
        guard !isSaving else { return }

        // Freeze the run while the user decides, so no time or distance is
        // recorded during the prompt.
        if state == .running {
            pauseRun()
        }

        let alert = UIAlertController(title: "Finish run?",
                                      message: "Save this run to your history?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Save Run", style: .default) { [weak self] _ in
            self?.finishRun()
        })
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
            self?.discardRun()
        })
        alert.addAction(UIAlertAction(title: "Keep Running", style: .cancel) { [weak self] _ in
            // A mistaken Stop - pick the run back up exactly where it froze.
            self?.beginSegment()
        })
        present(alert, animated: true)
    }

    /// Saves the run, or discards it if nothing was actually recorded.
    private func finishRun() {
        let run = currentRunSnapshot
        guard run.durationSeconds > 0 else {
            discardRun()
            return
        }
        saveRun(run)
    }

    // MARK: - Run Control

    /// Permission is already checked by the caller.
    private func startRun() {
        runStartDate = Date()
        accumulatedSeconds = 0
        tracker.reset()
        beginSegment()
    }

    /// Starts or restarts the clock. Shared by Start and Resume - the only
    /// difference between them is whether any time was banked beforehand.
    private func beginSegment() {
        segmentStartDate = Date()
        state = .running
        tracker.start()
        startTimer()
        refreshUI()
    }

    private func pauseRun() {
        if let segmentStartDate = segmentStartDate {
            accumulatedSeconds += Date().timeIntervalSince(segmentStartDate)
        }
        segmentStartDate = nil

        stopTimer()
        tracker.stop()
        state = .paused
        refreshUI()
    }

    private func saveRun(_ run: Run) {
        isSaving = true
        setControlsEnabled(false)

        RunStore.shared.add(run) { [weak self] error in
            guard let self = self else { return }
            self.isSaving = false

            if let error = error {
                self.setControlsEnabled(true)
                self.refreshUI()
                self.showAlert(title: "Could not save run",
                               message: error.localizedDescription)
                return
            }

            // Only clear the live session once the run is safely in Firestore.
            ActiveRunStore.shared.clear()
            self.state = .idle
            self.finish(withMessage: "Run saved")
        }
    }

    private func discardRun() {
        ActiveRunStore.shared.clear()
        state = .idle
        finish(withMessage: "Nothing to save - run discarded")
    }

    private func finish(withMessage message: String) {
        // The toast belongs to the screen the user lands on, not this one.
        let listController = navigationController?.viewControllers.first as? RunsListController
        navigationController?.popToRootViewController(animated: true)
        listController?.showToast(message: message)
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common keeps the clock running while the user is dragging something
        // on screen. The default run loop mode would quietly stall it.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        updateLabels()
        writeLiveSession()
    }

    // MARK: - Realtime Database

    private func writeLiveSession() {
        guard state == .running, let runStartDate = runStartDate else { return }

        let session = ActiveRunSession(isActive: true,
                                       elapsedSeconds: elapsedSeconds,
                                       distanceMeters: tracker.totalDistanceMeters,
                                       startTimestamp: runStartDate.timeIntervalSince1970)
        ActiveRunStore.shared.write(session)
    }

    // MARK: - UI Updates

    private func refreshUI() {
        updateLabels()
        updateControls()
        updateStatusLabel()
    }

    private func updateLabels() {
        let snapshot = currentRunSnapshot
        timeLabel.text = snapshot.formattedDuration
        distanceLabel.text = snapshot.formattedDistance
        paceLabel.text = snapshot.formattedPace
    }

    private func updateControls() {
        switch state {
        case .idle:
            startPauseButton.setTitle("Start", for: .normal)
            stopButton.isEnabled = false
        case .running:
            startPauseButton.setTitle("Pause", for: .normal)
            stopButton.isEnabled = true
        case .paused:
            startPauseButton.setTitle("Resume", for: .normal)
            stopButton.isEnabled = true
        }

        // Without location there is no distance, so starting a run would only
        // record a stopwatch. Better to block it than to save a useless run.
        startPauseButton.isEnabled = tracker.isAuthorized || state != .idle

        // A plain background colour does not dim on its own when the button is
        // disabled, so a disabled button would still look tappable.
        startPauseButton.alpha = startPauseButton.isEnabled ? 1.0 : 0.4
        stopButton.alpha = stopButton.isEnabled ? 1.0 : 0.4
    }

    private func updateStatusLabel() {
        switch tracker.authorizationStatus {
        case .notDetermined:
            statusLabel.text = "Waiting for location permission…"
        case .denied, .restricted:
            statusLabel.text = "Location is off. Enable it in Settings to measure distance."
        default:
            switch state {
            case .idle:
                statusLabel.text = "Ready when you are."
            case .running:
                statusLabel.text = "Recording…"
            case .paused:
                statusLabel.text = "Paused"
            }
        }
    }

    private func setControlsEnabled(_ isEnabled: Bool) {
        startPauseButton.isEnabled = isEnabled
        stopButton.isEnabled = isEnabled
    }

    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "Location access needed",
            message: "RunTracker measures your distance with GPS. Turn on location access in Settings to record a run.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Not now", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        })
        present(alert, animated: true)
    }
}

// MARK: - RunLocationTrackerDelegate

extension ActiveRunController: RunLocationTrackerDelegate {

    func locationTracker(_ tracker: RunLocationTracker, didUpdateDistance meters: Double) {
        // Distance arrives on its own schedule, independent of the clock.
        updateLabels()
    }

    func locationTracker(_ tracker: RunLocationTracker,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        updateControls()
        updateStatusLabel()
    }
}
